"""Per-(timepoint, side, method) Jacobian-determinant volume estimates.

For each timepoint, JLF gives us a deformation that maps the chunk SST →
the timepoint's TSE. The Jacobian determinant of that warp tells us how a
small volume element in SST space scales when mapped to timepoint space.

Integrating the Jacobian over each SST-space subfield label gives a
**deformation-based volume estimate** that is largely independent of the
per-timepoint segmentation drift. Comparing it to the segmentation-derived
volume produces a consistency check (see ``stats/consistency.csv``).

References:
    Yushkevich et al, "Automated Longitudinal Hippocampal Atrophy" (ALOHA)
    https://github.com/ins0mniac2/aloha

Reference frame: the **chunk SST** (not tp0). Every timepoint is symmetric;
for n>2 timepoint studies this avoids privileging the baseline acquisition.
"""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import intermediate_dir
from .chunk_sst import SIDES


def _jacobian_volumes_for_timepoint(
    side: str,
    method_subdir: str,
    timepoint_idx: int,
    inverse_warp: str,
    sst_labels: str,
    snaplabels_file: str,
    output_dir: str,
) -> tuple[str, str]:
    """Compute Jacobian + integrate over each SST-space subfield label.

    Returns (jacobian_image_path, per_subfield_volumes_text_path).
    The text file has one ``<label_id> <name> <volume_mm3>`` line per subfield.
    """
    import subprocess
    from pathlib import Path as _P

    import nibabel as nib
    import numpy as np

    od = _P(output_dir) / method_subdir
    od.mkdir(parents=True, exist_ok=True)
    jac_path = od / f"tp{timepoint_idx:02d}_{side}_jacobian.nii.gz"
    vols_path = od / f"tp{timepoint_idx:02d}_{side}_jacobian_volumes.txt"

    # Compute Jacobian determinant of the SST→tp_i inverse warp
    # (defined on chunk-SST space; values = local volume scaling factor).
    cmd = ["CreateJacobianDeterminantImage", "3", inverse_warp, str(jac_path)]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        stderr_tail = "\n".join((exc.stderr or "").splitlines()[-30:]) or "<empty>"
        raise RuntimeError(
            f"CreateJacobianDeterminantImage failed (exit {exc.returncode})\n"
            f"  inverse_warp={inverse_warp}\n"
            f"--- stderr ---\n{stderr_tail}"
        ) from exc

    # Load Jacobian + SST labels (both in chunk-SST space, same grid).
    jac_img = nib.load(str(jac_path))
    jac = jac_img.get_fdata()
    voxel_vol_mm3 = float(abs(np.linalg.det(jac_img.affine[:3, :3])))

    lab_img = nib.load(sst_labels)
    lab = lab_img.get_fdata().astype(int)

    # Read snaplabels: "<id> <name>" lines.
    pairs: list[tuple[int, str]] = []
    for line in _P(snaplabels_file).read_text().splitlines():
        parts = line.split(None, 1)
        if len(parts) == 2:
            try:
                pairs.append((int(parts[0]), parts[1]))
            except ValueError:
                pass

    out_lines: list[str] = []
    for label_id, name in pairs:
        mask = (lab == label_id)
        if not mask.any():
            continue
        # Integrate Jacobian over the SST-space subfield region.
        # ∫jacobian × voxel_volume_SST = predicted volume in tp space.
        jac_volume_mm3 = float(jac[mask].sum() * voxel_vol_mm3)
        out_lines.append(f"{label_id} {name} {jac_volume_mm3:.4f}")

    vols_path.write_text("\n".join(out_lines) + "\n")
    return str(jac_path), str(vols_path)


def build_jacobian(
    config: LashisConfig, methods: list[str],
) -> dict[tuple[str, str], pe.MapNode]:
    """One MapNode per (side, method) iterating over timepoints.

    Returns dict keyed by (side, antsJointLabelFusion-method) with each
    MapNode emitting list outputs ``jacobian_image`` (paths) and
    ``volumes_file`` (per-subfield Jacobian-volume text files).

    Caller wires:
      - reverse_warp's per-tp ``inverse_warp`` → ``inverse_warp``
      - jlf's per-method ``labels`` → ``sst_labels`` (single, not iterated)
      - snaplabels → ``snaplabels_file`` (single)
    """
    from .jlf import METHOD_TO_SUBDIR

    out: dict[tuple[str, str], pe.MapNode] = {}
    n_tp = len(config.timepoints)
    base = intermediate_dir(config.output_prefix) / "jacobian"
    base.mkdir(parents=True, exist_ok=True)

    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        for side in SIDES:
            node = pe.MapNode(
                Function(
                    input_names=[
                        "side", "method_subdir", "timepoint_idx",
                        "inverse_warp", "sst_labels",
                        "snaplabels_file", "output_dir",
                    ],
                    output_names=["jacobian_image", "volumes_file"],
                    function=_jacobian_volumes_for_timepoint,
                ),
                name=f"jacobian_{side}_{method_subdir}",
                iterfield=["timepoint_idx", "inverse_warp"],
            )
            node.inputs.side = side
            node.inputs.method_subdir = method_subdir
            node.inputs.timepoint_idx = list(range(n_tp))
            node.inputs.output_dir = str(base)
            out[(side, method)] = node
    return out
