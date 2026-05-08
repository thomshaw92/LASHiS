"""Top-level Nipype workflow that wires every stage of LASHiS together.

Stages, in order:
    A. (optional denoising — not yet ported; LASHiS.sh:406-440)
    B. crosssectional_ashs        (lines 451-509)
    C. sst + rescale templates    (lines 521-573)
    D. sst_ashs                   (lines 579-589)
    E. chunk_sst (per side)       (lines 787-823)
    F. jlf + reverse warp         per (side, fusion_method)
    G. snaplabels + stats         per (side, fusion_method)
    H. aggregate CSVs             volumes / asymmetry / longitudinal
    I. HTML QC viewers            per (side, fusion_method, timepoint)

Diff from the original LASHiS.sh:
- chunk SST inputs are the raw ``tse_native_chunk_*`` files (no rebinarize)
- ``--fusion {majority,jlf,both}`` runs JLF with the user's choice of voting;
  ``both`` runs the script twice with different ``-o`` prefixes (registrations
  are not shared; this ~doubles the JLF stage runtime)
- ICV is read directly from cross-sectional ASHS's emitted ``_icv.txt``
  (no extra FSL bet step), then divided into each subfield volume to give
  ``volume_mm3_norm`` in the CSVs
- Asymmetry index, longitudinal change, HTML QC are new outputs LASHiS.sh
  did not produce
"""
from __future__ import annotations

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from .config import LashisConfig
from .nodes.chunk_sst import (
    SIDES,
    build_chunk_sst,
    collect_chunks,
)
from .nodes.crosssectional import build_crosssectional
from .nodes.jacobian import build_jacobian
from .nodes.jacpen import build_jacpen, build_posteriors_warp
from .nodes.jlf import (
    METHOD_TO_SUBDIR,
    build_jlf,
    build_reverse_warp,
    fusion_methods,
    slice_first_n,
)
from .nodes.qc import build_qc
from .nodes.sst import build_sst
from .nodes.sst_ashs import build_sst_ashs
from .nodes.stats import build_aggregate_stats, build_stats
from .utils.paths import nipype_base_dir


def build_workflow(config: LashisConfig) -> pe.Workflow:
    n_tp = len(config.timepoints)
    methods = fusion_methods(config)
    wf = pe.Workflow(name="lashis", base_dir=str(nipype_base_dir(config.output_prefix)))
    # Human-readable crash files (default is pickled). These are easier to
    # `cat` when a node fails — see lashis.cli for the failure-summary that
    # auto-prints the most recent ones.
    wf.config["execution"]["crashfile_format"] = "txt"
    wf.config["execution"]["crashdump_dir"] = str(nipype_base_dir(config.output_prefix))

    # --- B: cross-sectional ASHS -------------------------------------------
    xs_ashs, xs_cleanup = build_crosssectional(config)
    if not config.keep_tmp:
        wf.connect(xs_ashs, "working_dir", xs_cleanup, "working_dir")

    # --- C: initial multimodal SST -----------------------------------------
    sst, rescale_t0, rescale_t1 = build_sst(config)
    wf.connect(sst, "template0", rescale_t0, "input_image")
    wf.connect(sst, "template1", rescale_t1, "input_image")

    # --- D: ASHS on the rescaled SST ---------------------------------------
    sst_ashs = build_sst_ashs(config)
    wf.connect(rescale_t0, "output_image", sst_ashs, "t1w")
    wf.connect(rescale_t1, "output_image", sst_ashs, "t2w")

    # --- E: per-side chunk SST ---------------------------------------------
    chunk_ssts = build_chunk_sst(config)
    for side in SIDES:
        joiner = pe.Node(
            Function(
                input_names=["per_tp_chunks", "sst_chunk"],
                output_names=["images"],
                function=collect_chunks,
            ),
            name=f"chunk_sst_inputs_{side}",
        )
        wf.connect(xs_ashs, f"tse_native_chunk_{side}", joiner, "per_tp_chunks")
        wf.connect(sst_ashs, f"tse_native_chunk_{side}", joiner, "sst_chunk")
        wf.connect(joiner, "images", chunk_ssts[side], "images")

    # --- F: JLF + reverse warp per (side, method) --------------------------
    jlfs = build_jlf(config)             # dict[(side, method)] -> Node
    rev_warps = build_reverse_warp(config)  # dict[(side, method)] -> MapNode

    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        for side in SIDES:
            jlf = jlfs[(side, method)]
            rev = rev_warps[(side, method)]

            wf.connect(chunk_ssts[side], "template0", jlf, "chunk_sst_template")
            wf.connect(xs_ashs, f"tse_native_chunk_{side}", jlf, "timepoint_chunks")
            wf.connect(xs_ashs, f"segmentation_{side}", jlf, "timepoint_segmentations")
            wf.connect(sst_ashs, f"tse_native_chunk_{side}", jlf, "sst_chunk")
            wf.connect(sst_ashs, f"segmentation_{side}", jlf, "sst_segmentation")

            slicer_aff = pe.Node(
                Function(
                    input_names=["items", "n"],
                    output_names=["items"],
                    function=slice_first_n,
                ),
                name=f"slice_affines_{side}_{method_subdir}",
            )
            slicer_aff.inputs.n = n_tp
            wf.connect(jlf, "affines", slicer_aff, "items")

            slicer_warp = pe.Node(
                Function(
                    input_names=["items", "n"],
                    output_names=["items"],
                    function=slice_first_n,
                ),
                name=f"slice_inverse_warps_{side}_{method_subdir}",
            )
            slicer_warp.inputs.n = n_tp
            wf.connect(jlf, "inverse_warps", slicer_warp, "items")

            wf.connect(jlf, "labels", rev, "sst_labels")
            wf.connect(xs_ashs, "tse", rev, "reference_tse")
            wf.connect(slicer_aff, "items", rev, "affine")
            wf.connect(slicer_warp, "items", rev, "inverse_warp")

    # --- G: stats per (side, method) ---------------------------------------
    snaplabels, stats_nodes = build_stats(config, methods)
    for method in methods:
        for side in SIDES:
            wf.connect(rev_warps[(side, method)], "warped_labels",
                       stats_nodes[(side, method)], "warped_labels")
            wf.connect(snaplabels, "snaplabels_file",
                       stats_nodes[(side, method)], "snaplabels_file")

    # --- H: Jacobian-determinant volume per (side, method, tp) -------------
    # JLF's inverse warps map chunk-SST → tp space. Their Jacobians integrated
    # over each SST-space subfield label give a deformation-implied volume
    # estimate, used for the consistency check vs segmentation volumes.
    jac_nodes: dict[tuple[str, str], pe.MapNode] = {}
    if config.jacobian:
        jac_nodes = build_jacobian(config, methods)
        for method in methods:
            for side in SIDES:
                node = jac_nodes[(side, method)]
                wf.connect(jlfs[(side, method)], "labels", node, "sst_labels")
                wf.connect(snaplabels, "snaplabels_file",
                           node, "snaplabels_file")
                # Use the same per-tp inverse warps that drive reverse-warp;
                # the slicer node already trims off the SST-self entry.
                slicer_warp_name = f"slice_inverse_warps_{side}_{METHOD_TO_SUBDIR[method]}"
                slicer_warp_obj = wf.get_node(slicer_warp_name)
                wf.connect(slicer_warp_obj, "items", node, "inverse_warp")

    # --- I: Jacobian-penalised segmentation (optional, opt-in) -------------
    # Warps SST posteriors into each tp space, then runs greedy
    # posterior-thresholding to pull label volumes toward Jacobian targets.
    # Larger labels are penalised more (rank-weighted); smaller labels keep
    # more of their original seg extent. New labels under
    # labels/<method>_jacpen/; volumes feed into stats/jacpen_volumes.csv.
    jacpen_nodes: dict[tuple[str, str], pe.MapNode] = {}
    jacpen_stats_nodes: dict[tuple[str, str], pe.MapNode] = {}
    if config.jacpen and config.jacobian:
        post_warp = build_posteriors_warp(config, methods)
        jacpen_nodes = build_jacpen(config, methods)
        for method in methods:
            method_subdir = METHOD_TO_SUBDIR[method]
            for side in SIDES:
                pw = post_warp[(side, method)]
                # Posteriors live in chunk-SST space; warp using the same
                # affine + inverse warp pair as the segmentation reverse-warp.
                wf.connect(jlfs[(side, method)], "posteriors", pw, "sst_posteriors")
                wf.connect(xs_ashs, "tse", pw, "reference_tse")
                slicer_aff = wf.get_node(f"slice_affines_{side}_{method_subdir}")
                slicer_warp = wf.get_node(f"slice_inverse_warps_{side}_{method_subdir}")
                wf.connect(slicer_aff, "items", pw, "affine")
                wf.connect(slicer_warp, "items", pw, "inverse_warp")

                jp = jacpen_nodes[(side, method)]
                wf.connect(rev_warps[(side, method)], "warped_labels",
                           jp, "seg_labels")
                wf.connect(pw, "warped_posteriors", jp, "warped_posteriors")
                wf.connect(jac_nodes[(side, method)], "volumes_file",
                           jp, "jacobian_volumes_file")
                wf.connect(snaplabels, "snaplabels_file", jp, "snaplabels_file")

                # Parallel stats branch on the jacpen labels (re-uses the
                # same _stats_for_timepoint Function as the seg branch).
                from .nodes.stats import _stats_for_timepoint
                stats_jp = pe.MapNode(
                    Function(
                        input_names=[
                            "side", "method_subdir", "timepoint_idx",
                            "basename", "warped_labels", "snaplabels_file",
                            "output_dir",
                        ],
                        output_names=["stats_file", "raw_stats_file"],
                        function=_stats_for_timepoint,
                    ),
                    name=f"stats_{side}_{method_subdir}_jacpen",
                    iterfield=["timepoint_idx", "basename", "warped_labels"],
                )
                from .utils.paths import per_timepoint_stats_dir
                stats_jp.inputs.side = side
                stats_jp.inputs.method_subdir = f"{method_subdir}_jacpen"
                stats_jp.inputs.timepoint_idx = list(range(n_tp))
                stats_jp.inputs.basename = [tp.subject_id for tp in config.timepoints]
                stats_jp.inputs.output_dir = str(per_timepoint_stats_dir(config.output_prefix))
                wf.connect(jp, "jacpen_labels", stats_jp, "warped_labels")
                wf.connect(snaplabels, "snaplabels_file", stats_jp, "snaplabels_file")
                jacpen_stats_nodes[(side, method)] = stats_jp

    # --- J: long-format CSV aggregation ------------------------------------
    # ICV is read directly from ASHS's per-timepoint final/<basename>_icv.txt
    # (exposed as the `icv_mm3` output of the cross-sectional ASHS MapNode);
    # no separate FSL bet step needed.
    aggregate = build_aggregate_stats(config)
    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        for side in SIDES:
            wf.connect(stats_nodes[(side, method)], "stats_file",
                       aggregate, f"stats_{side}_{method_subdir}")
            if config.jacobian:
                wf.connect(jac_nodes[(side, method)], "volumes_file",
                           aggregate, f"jac_{side}_{method_subdir}")
            if config.jacpen and (side, method) in jacpen_stats_nodes:
                wf.connect(jacpen_stats_nodes[(side, method)], "stats_file",
                           aggregate, f"jacpen_{side}_{method_subdir}")
    if config.icv:
        wf.connect(xs_ashs, "icv_mm3", aggregate, "icv_volumes")

    # --- K: HTML QC viewer (single NiiVue-based page) ----------------------
    # One qc/index.html that switches between every (tp, side, method) plus
    # any jacpen variants. NIfTI files are loaded relative to the qc/ dir.
    # We use the ORIGINAL BIDS T2w as the underlay (preserves float32 dynamic
    # range) instead of ASHS's int16-quantised tse.nii.gz; the warped labels
    # share the original's affine on standard inputs.
    if config.qc:
        qc = build_qc(config, methods)
        qc.inputs.tse_per_tp = [str(tp.t2w) for tp in config.timepoints]
        for method in methods:
            method_subdir = METHOD_TO_SUBDIR[method]
            for side in SIDES:
                wf.connect(rev_warps[(side, method)], "warped_labels",
                           qc, f"labels_{method_subdir}_{side}")
                if config.jacpen and (side, method) in jacpen_nodes:
                    wf.connect(jacpen_nodes[(side, method)], "jacpen_labels",
                               qc, f"labels_jacpen_{method_subdir}_{side}")

    return wf
