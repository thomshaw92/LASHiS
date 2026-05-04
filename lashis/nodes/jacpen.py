"""Jacobian-penalised segmentation.

For each (timepoint, side, fusion_method), produce a *new* label map where
each subfield's volume is pulled partway toward what the Jacobian determinant
predicts. Larger labels are penalised more (pulled closer to the Jacobian),
smaller labels are penalised less (allowed to keep their segmentation extent).

Algorithm
---------
1. Sort labels by current segmentation volume, **largest first**.
2. For each label *l* with rank ``r ∈ [0, N-1]``::

       w_l = 1 − r / N       # 'linear' weighting (default)
                             # 'sqrt': 1 − √(r/N), penalty drops faster for small labels
                             # 'equal': 0.5 (no rank ordering, true halfway)

       target_vol(l) = V_seg(l) + w_l × ( V_jac(l) − V_seg(l) )

3. Greedy posterior thresholding (label by label, sequential):
   - Maintain ``available`` mask (initially all True).
   - For each label *l* (sorted largest-first):
       p_avail = posterior_l × available
       Pick top-K voxels of p_avail, where K = round(target_vol_l / voxel_vol).
       Assign them to *l*, mark them claimed in ``available``.
4. Voxels that remain unclaimed fall back to their original segmentation
   label (preserves coverage; never silently *removes* a labelled voxel).
5. Optional: keep the largest connected component per label (drops greedy-
   thresholding fragments).

Inputs are tp-space — posteriors are reverse-warped from SST space using the
same (affine, inverse warp) pair we use for the segmentation labels.
"""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import intermediate_dir, labels_dir
from .chunk_sst import SIDES


# --- inner helpers (shipped to Nipype workers as text) ---------------------

def _warp_posteriors_to_tp(
    side: str,
    method_subdir: str,
    timepoint_idx: int,
    sst_posteriors: list[str],
    reference_tse: str,
    affine: str,
    inverse_warp: str,
    output_dir: str,
) -> list[str]:
    """Warp every SST-space posterior into a single timepoint's TSE space.

    Returns a list of tp-space posterior paths in the same order as input.
    """
    import subprocess
    from pathlib import Path as _P

    od = _P(output_dir) / method_subdir / f"tp{timepoint_idx:02d}_{side}"
    od.mkdir(parents=True, exist_ok=True)

    out_paths: list[str] = []
    for src in sst_posteriors:
        name = _P(src).name
        dst = od / name
        cmd = [
            "antsApplyTransforms",
            "-d", "3",
            "-i", src,
            "-o", str(dst),
            "-r", reference_tse,
            "-t", f"[{affine},1]",
            "-t", inverse_warp,
            "-n", "Linear",
        ]
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as exc:
            stderr_tail = "\n".join((exc.stderr or "").splitlines()[-20:]) or "<empty>"
            raise RuntimeError(
                f"antsApplyTransforms (posterior warp) failed (exit {exc.returncode})\n"
                f"  src={src}\n"
                f"--- stderr ---\n{stderr_tail}"
            ) from exc
        out_paths.append(str(dst))
    return out_paths


def _apply_jacobian_penalty(
    side: str,
    method_subdir: str,
    timepoint_idx: int,
    seg_labels: str,
    warped_posteriors: list[str],
    jacobian_volumes_file: str,
    snaplabels_file: str,
    weighting: str,
    largest_cc: bool,
    output_dir: str,
) -> tuple[str, str]:
    """Sequential per-label posterior thresholding to enforce target volumes.

    Returns (jacpen_label_path, target_volumes_text_path).
    """
    import re
    from pathlib import Path as _P

    import nibabel as nib
    import numpy as np

    od = _P(output_dir) / method_subdir
    od.mkdir(parents=True, exist_ok=True)
    out_label_path = od / f"tp{timepoint_idx:02d}_{side}.nii.gz"
    out_targets_path = (
        _P(output_dir).parent / "_jacpen_meta" / method_subdir
        / f"tp{timepoint_idx:02d}_{side}_targets.txt"
    )
    out_targets_path.parent.mkdir(parents=True, exist_ok=True)

    # Load segmentation labels
    seg_img = nib.load(seg_labels)
    seg = seg_img.get_fdata().astype(np.int32)
    voxel_vol_mm3 = float(abs(np.linalg.det(seg_img.affine[:3, :3])))

    # Per-label Jacobian-predicted volume from the text file
    # (lines: "<id> <name> <volume_mm3>")
    jac_vol: dict[int, float] = {}
    label_name: dict[int, str] = {}
    for line in _P(jacobian_volumes_file).read_text().splitlines():
        parts = line.split()
        if len(parts) >= 3:
            try:
                lid = int(parts[0])
                jac_vol[lid] = float(parts[-1])
                label_name[lid] = parts[1]
            except ValueError:
                pass

    # Map posterior file → label id by parsing the trailing zero-padded NNNN.
    # JLF emits ``<side>_<NNNN>.nii.gz`` per label.
    post_by_label: dict[int, str] = {}
    for p in warped_posteriors:
        m = re.search(r"(\d+)\.nii(\.gz)?$", _P(p).name)
        if m:
            post_by_label[int(m.group(1))] = p

    # Per-label segmentation volume, used to rank "largest first".
    seg_labels_present = [int(l) for l in np.unique(seg) if l > 0]
    seg_vol = {
        l: float((seg == l).sum() * voxel_vol_mm3)
        for l in seg_labels_present
    }

    # Order largest → smallest so big labels claim voxels first.
    sorted_labels = sorted(seg_vol.keys(), key=lambda l: seg_vol[l], reverse=True)
    n = max(len(sorted_labels), 1)

    def weight_for(rank: int) -> float:
        if weighting == "equal":
            return 0.5
        if weighting == "sqrt":
            return max(0.0, 1.0 - (rank / n) ** 0.5)
        # default: linear
        return max(0.0, 1.0 - rank / n)

    new_labels = np.zeros_like(seg, dtype=np.int32)
    available = np.ones_like(seg, dtype=bool)

    target_log_lines: list[str] = ["label_id,name,rank,weight,seg_vol_mm3,jac_vol_mm3,target_vol_mm3,assigned_voxels"]
    for rank, lid in enumerate(sorted_labels):
        v_seg = seg_vol[lid]
        v_jac = jac_vol.get(lid, v_seg)   # missing → no penalty
        w = weight_for(rank)
        target_vol = v_seg + w * (v_jac - v_seg)
        target_voxels = max(0, int(round(target_vol / voxel_vol_mm3)))

        post_path = post_by_label.get(lid)
        if post_path is None or target_voxels == 0:
            target_log_lines.append(
                f"{lid},{label_name.get(lid, '?')},{rank},{w:.4f},"
                f"{v_seg:.3f},{v_jac:.3f},{target_vol:.3f},0"
            )
            continue
        post_img = nib.load(post_path)
        post = post_img.get_fdata().astype(np.float32)
        # Restrict to still-available voxels.
        p_avail = np.where(available, post, 0.0)
        # Keep the top `target_voxels` voxels by posterior probability.
        flat = p_avail.ravel()
        if target_voxels >= flat.size:
            mask_flat = flat > 0
        else:
            # argpartition gives the top-K efficiently; non-zero filter prevents
            # claiming voxels with zero posterior even if K exceeds positives.
            idx = np.argpartition(flat, -target_voxels)[-target_voxels:]
            mask_flat = np.zeros_like(flat, dtype=bool)
            mask_flat[idx] = True
            mask_flat &= flat > 0
        mask = mask_flat.reshape(post.shape)

        new_labels[mask] = lid
        available[mask] = False
        target_log_lines.append(
            f"{lid},{label_name.get(lid, '?')},{rank},{w:.4f},"
            f"{v_seg:.3f},{v_jac:.3f},{target_vol:.3f},{int(mask.sum())}"
        )

    # Fallback: any voxel still available that had a label in the original
    # segmentation keeps its original label. (Approved caveat #2.)
    fallback = available & (seg > 0)
    new_labels[fallback] = seg[fallback]

    # Optional: keep largest connected component per label. (Approved caveat #1.)
    if largest_cc:
        try:
            from scipy import ndimage
        except ImportError:
            ndimage = None
        if ndimage is not None:
            for lid in np.unique(new_labels):
                if lid == 0:
                    continue
                mask = new_labels == lid
                cc, n_cc = ndimage.label(mask)
                if n_cc <= 1:
                    continue
                sizes = ndimage.sum(mask, cc, index=range(1, n_cc + 1))
                largest = int(np.argmax(sizes)) + 1
                drop = mask & (cc != largest)
                # Dropped fragments fall back to original-seg label
                # (background if 0).
                new_labels[drop] = seg[drop]

    # Write outputs.
    out_img = nib.Nifti1Image(new_labels.astype(np.int32), seg_img.affine, seg_img.header)
    out_img.set_data_dtype(np.int32)
    nib.save(out_img, str(out_label_path))
    out_targets_path.write_text("\n".join(target_log_lines) + "\n")

    return str(out_label_path), str(out_targets_path)


# --- node builders ---------------------------------------------------------

def build_posteriors_warp(
    config: LashisConfig, methods: list[str],
) -> dict[tuple[str, str], pe.MapNode]:
    """One MapNode per (side, method) iterating over timepoints.

    Each iteration warps ALL SST-space posteriors for that (side, method)
    into a single tp-space directory.
    """
    from .jlf import METHOD_TO_SUBDIR

    out: dict[tuple[str, str], pe.MapNode] = {}
    n_tp = len(config.timepoints)
    base = intermediate_dir(config.output_prefix) / "posteriors_warped"
    base.mkdir(parents=True, exist_ok=True)

    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        for side in SIDES:
            node = pe.MapNode(
                Function(
                    input_names=[
                        "side", "method_subdir", "timepoint_idx",
                        "sst_posteriors", "reference_tse",
                        "affine", "inverse_warp", "output_dir",
                    ],
                    output_names=["warped_posteriors"],
                    function=_warp_posteriors_to_tp,
                ),
                name=f"posteriors_warp_{side}_{method_subdir}",
                iterfield=["timepoint_idx", "reference_tse", "affine", "inverse_warp"],
            )
            node.inputs.side = side
            node.inputs.method_subdir = method_subdir
            node.inputs.timepoint_idx = list(range(n_tp))
            node.inputs.output_dir = str(base)
            out[(side, method)] = node
    return out


def build_jacpen(
    config: LashisConfig, methods: list[str],
) -> dict[tuple[str, str], pe.MapNode]:
    """One MapNode per (side, method) iterating over timepoints.

    Outputs the jacpen-corrected label NIfTI under
    ``labels/<method>_jacpen/tpXX_<side>.nii.gz`` and a target-volumes log
    under ``intermediate/_jacpen_meta/<method>/``.
    """
    from .jlf import METHOD_TO_SUBDIR

    out: dict[tuple[str, str], pe.MapNode] = {}
    n_tp = len(config.timepoints)

    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        # New labels dir: alongside the original seg labels.
        jacpen_method_subdir = f"{method_subdir}_jacpen"
        out_dir = labels_dir(config.output_prefix, jacpen_method_subdir)
        out_dir.mkdir(parents=True, exist_ok=True)
        for side in SIDES:
            node = pe.MapNode(
                Function(
                    input_names=[
                        "side", "method_subdir", "timepoint_idx",
                        "seg_labels", "warped_posteriors",
                        "jacobian_volumes_file", "snaplabels_file",
                        "weighting", "largest_cc", "output_dir",
                    ],
                    output_names=["jacpen_labels", "targets_log"],
                    function=_apply_jacobian_penalty,
                ),
                name=f"jacpen_{side}_{method_subdir}",
                iterfield=[
                    "timepoint_idx", "seg_labels", "warped_posteriors",
                    "jacobian_volumes_file",
                ],
            )
            node.inputs.side = side
            node.inputs.method_subdir = jacpen_method_subdir
            node.inputs.timepoint_idx = list(range(n_tp))
            node.inputs.weighting = config.jacpen_weighting
            node.inputs.largest_cc = config.jacpen_largest_cc
            node.inputs.output_dir = str(out_dir.parent)
            out[(side, method)] = node
    return out
