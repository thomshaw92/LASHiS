"""Joint Label Fusion + reverse normalization to native timepoints.

Mirrors LASHiS.sh:1037-1108. JLF fuses cross-sectional ASHS segmentations
onto the per-side chunk SST; the resulting SST-space labels are then warped
back to each timepoint's native TSE using the per-timepoint affine + inverse
warp that JLF emits during its registration pass.

Supports two voting methods (the ``-x`` flag of ``antsJointLabelFusion.sh``):

  * ``joint``           — weighted joint label fusion (Wang & Yushkevich 2013).
  * ``majorityvoting``  — straight majority vote across registered atlases
                          (the LASHiS-original method).

When ``config.fusion == "both"`` we run JLF twice with separate output
prefixes; registrations are not shared between methods, so ``both`` ~doubles
the JLF stage runtime.

Per-method outputs land under ``LASHiS/<method>/`` so the two runs don't
collide. The ``method`` subdir is one of ``jlf`` or ``majority``
(user-facing names — internally the antsJointLabelFusion ``-x`` values are
``joint`` / ``majorityvoting``).
"""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import (
    jlf_intermediate_dir,
    labels_dir,
    posteriors_dir,
)
from .chunk_sst import SIDES

# ``-x`` value for antsJointLabelFusion.sh ↔ user-facing subdir name
METHOD_TO_SUBDIR = {"joint": "jlf", "majorityvoting": "majority"}


def fusion_methods(config: LashisConfig) -> list[str]:
    """Return the list of antsJointLabelFusion ``-x`` values to run."""
    if config.fusion == "both":
        return ["joint", "majorityvoting"]
    if config.fusion == "jlf":
        return ["joint"]
    if config.fusion == "majority":
        return ["majorityvoting"]
    raise ValueError(f"unknown fusion mode: {config.fusion}")


def _run_jlf(
    side: str,
    method: str,
    chunk_sst_template: str,
    timepoint_chunks: list[str],
    timepoint_segmentations: list[str],
    sst_chunk: str,
    sst_segmentation: str,
    output_dir: str,
    posteriors_out_dir: str,
    n_cores: int,
    plugin_code: int,
) -> dict:
    """Stage atlas inputs, invoke antsJointLabelFusion.sh, return paths.

    Ordering is timepoints[0..N-1] then SST — must match the assumption used
    by the reverse-warp node when picking which transforms belong to which
    timepoint (LASHiS.sh:1097, where TIMEPOINTS_COUNT is the 0-based index).

    ``method`` is the antsJointLabelFusion.sh ``-x`` flag value
    (``joint`` or ``majorityvoting``).

    ``output_dir`` is where JLF emits its transforms + the SST-space label
    file (``intermediate/jlf/<method_subdir>/``). ``posteriors_out_dir`` is
    where the per-label posterior probability maps go (user-facing
    ``posteriors/<method_subdir>/``).
    """
    import shutil
    import subprocess
    from pathlib import Path as _P

    jlf_dir = _P(output_dir)
    posteriors_dst = _P(posteriors_out_dir)
    staging_dir = jlf_dir / f"_staging_{side}"
    for d in (jlf_dir, posteriors_dst, staging_dir):
        d.mkdir(parents=True, exist_ok=True)

    # Stage all atlas inputs under a single directory so JLF's basename-based
    # transform naming becomes predictable. Use a canonical filename so output
    # names match the reverse-warp step's expectations (it globs).
    staged: list[tuple[str, str]] = []
    canonical_name = f"tse_native_chunk_{side}.nii.gz"
    label_name = f"_{side}_lfseg_heur.nii.gz"

    for idx, (chunk, seg) in enumerate(zip(timepoint_chunks, timepoint_segmentations)):
        sub_dir = staging_dir / f"tp{idx}"
        sub_dir.mkdir(parents=True, exist_ok=True)
        chunk_dst = sub_dir / canonical_name
        seg_dst = sub_dir / label_name
        shutil.copy2(chunk, chunk_dst)
        shutil.copy2(seg, seg_dst)
        staged.append((str(chunk_dst), str(seg_dst)))

    sst_sub = staging_dir / "sst"
    sst_sub.mkdir(parents=True, exist_ok=True)
    sst_chunk_dst = sst_sub / canonical_name
    sst_seg_dst = sst_sub / label_name
    shutil.copy2(sst_chunk, sst_chunk_dst)
    shutil.copy2(sst_segmentation, sst_seg_dst)
    staged.append((str(sst_chunk_dst), str(sst_seg_dst)))

    # Per-method output prefix avoids collisions when running both methods.
    out_prefix = jlf_dir / f"{side}_SST_"
    posteriors_prefix = posteriors_dst / f"{side}_%04d.nii.gz"

    cmd = [
        "antsJointLabelFusion.sh",
        "-d", "3",
        "-c", str(plugin_code),
        "-j", str(n_cores),
        "-t", chunk_sst_template,
        "-o", str(out_prefix),
        "-p", str(posteriors_prefix),
        "-k", "1",
        "-x", method,
    ]
    for chunk_path, seg_path in staged:
        cmd += ["-g", chunk_path, "-l", seg_path]

    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        stderr_tail = "\n".join((exc.stderr or "").splitlines()[-50:]) or "<empty>"
        raise RuntimeError(
            f"antsJointLabelFusion.sh failed (exit {exc.returncode}, "
            f"side={side}, method={method})\n"
            f"--- stderr (last 50 lines) ---\n{stderr_tail}"
        ) from exc

    # Discover transforms JLF emitted, in atlas-index order (filename suffix
    # "_<i>_0GenericAffine.mat"). Globbing avoids guessing how the script
    # serializes the per-atlas filename.
    jlf_prefix = f"{side}_SST_"
    affines: list[str] = []
    inverse_warps: list[str] = []
    for i in range(len(staged)):
        aff_matches = sorted(
            jlf_dir.glob(f"{jlf_prefix}*_{i}_0GenericAffine.mat")
        )
        warp_matches = sorted(
            jlf_dir.glob(f"{jlf_prefix}*_{i}_1InverseWarp.nii.gz")
        )
        if not aff_matches:
            raise RuntimeError(
                f"JLF did not produce an affine for atlas {i} "
                f"(side={side}, method={method}) in {jlf_dir}"
            )
        if not warp_matches:
            raise RuntimeError(
                f"JLF did not produce an inverse warp for atlas {i} "
                f"(side={side}, method={method}) in {jlf_dir}"
            )
        affines.append(str(aff_matches[0]))
        inverse_warps.append(str(warp_matches[0]))

    labels_matches = sorted(jlf_dir.glob(f"{jlf_prefix}*Labels.nii.gz"))
    if not labels_matches:
        raise RuntimeError(
            f"JLF did not produce Labels output (side={side}, method={method}) "
            f"in {jlf_dir}"
        )

    posterior_files = sorted(posteriors_dst.glob(f"{side}_*.nii.gz"))

    # Nipype Function wrapper indexes the return positionally against
    # output_names; must be a tuple, not a dict.
    return (
        str(labels_matches[0]),
        affines,
        inverse_warps,
        [str(p) for p in posterior_files],
    )


def build_jlf(config: LashisConfig) -> dict[tuple[str, str], pe.Node]:
    """Build one Function node per (side, method) for antsJointLabelFusion.sh."""
    from .sst import _amtc_plugin_code

    out: dict[tuple[str, str], pe.Node] = {}

    for method in fusion_methods(config):
        method_subdir = METHOD_TO_SUBDIR[method]
        intermed = jlf_intermediate_dir(config.output_prefix, method_subdir)
        post_dir = posteriors_dir(config.output_prefix, method_subdir)
        intermed.mkdir(parents=True, exist_ok=True)
        post_dir.mkdir(parents=True, exist_ok=True)

        for side in SIDES:
            node = pe.Node(
                Function(
                    input_names=[
                        "side", "method", "chunk_sst_template",
                        "timepoint_chunks", "timepoint_segmentations",
                        "sst_chunk", "sst_segmentation",
                        "output_dir", "posteriors_out_dir",
                        "n_cores", "plugin_code",
                    ],
                    output_names=["labels", "affines", "inverse_warps", "posteriors"],
                    function=_run_jlf,
                ),
                name=f"jlf_{side}_{method_subdir}",
            )
            node.inputs.side = side
            node.inputs.method = method
            node.inputs.output_dir = str(intermed)
            node.inputs.posteriors_out_dir = str(post_dir)
            node.inputs.n_cores = config.n_procs
            node.inputs.plugin_code = _amtc_plugin_code(config.plugin)
            out[(side, method)] = node
    return out


def _reverse_warp(
    side: str,
    timepoint_idx: int,
    sst_labels: str,
    reference_tse: str,
    affine: str,
    inverse_warp: str,
    output_dir: str,
) -> str:
    """antsApplyTransforms with the JLF-emitted affine (inverted) + inverse warp.

    Mirrors LASHiS.sh:1092-1099. The per-method directory is set up by
    ``build_reverse_warp`` so each fusion method's outputs land in the right
    ``labels/<method_subdir>/`` folder.
    """
    import subprocess
    from pathlib import Path as _P

    out_dir = _P(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"tp{timepoint_idx:02d}_{side}.nii.gz"
    cmd = [
        "antsApplyTransforms",
        "-d", "3",
        "-i", sst_labels,
        "-o", str(out),
        "-r", reference_tse,
        "-t", f"[{affine},1]",
        "-t", inverse_warp,
        "-n", "GenericLabel[Linear]",
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        stderr_tail = "\n".join((exc.stderr or "").splitlines()[-30:]) or "<empty>"
        raise RuntimeError(
            f"antsApplyTransforms failed (exit {exc.returncode}) "
            f"for {side} tp{timepoint_idx}\n"
            f"--- stderr (last 30 lines) ---\n{stderr_tail}"
        ) from exc
    return str(out)


def build_reverse_warp(config: LashisConfig) -> dict[tuple[str, str], pe.MapNode]:
    """One MapNode per (side, method) iterating over timepoints.

    Each method's warped labels land at ``labels/<method_subdir>/tpXX_<side>.nii.gz``.
    """
    out: dict[tuple[str, str], pe.MapNode] = {}
    n_tp = len(config.timepoints)

    for method in fusion_methods(config):
        method_subdir = METHOD_TO_SUBDIR[method]
        method_labels_dir = labels_dir(config.output_prefix, method_subdir)
        method_labels_dir.mkdir(parents=True, exist_ok=True)
        for side in SIDES:
            node = pe.MapNode(
                Function(
                    input_names=[
                        "side", "timepoint_idx", "sst_labels",
                        "reference_tse", "affine", "inverse_warp", "output_dir",
                    ],
                    output_names=["warped_labels"],
                    function=_reverse_warp,
                ),
                name=f"reverse_warp_{side}_{method_subdir}",
                iterfield=["timepoint_idx", "reference_tse", "affine", "inverse_warp"],
            )
            node.inputs.side = side
            node.inputs.timepoint_idx = list(range(n_tp))
            node.inputs.output_dir = str(method_labels_dir)
            out[(side, method)] = node
    return out


def slice_first_n(items: list, n: int) -> list:
    """Drop the trailing SST entry from a JLF transforms list (helper for wiring)."""
    return items[:n]
