"""Pre-flight QC checks. Cheap reads on input headers; raises early if a
dataset would silently produce nonsense outputs.
"""
from __future__ import annotations

from pathlib import Path

import nibabel as nib

from .validation import InputValidationError


def check_tse_slice_direction(t2w_path: Path) -> None:
    """Verify the TSE has its smallest spatial dimension along z.

    ASHS pipelines expect the slice direction to be z (e.g. 400×400×30, not
    400×30×400). When violated ASHS still runs but the output segmentations
    are scrambled along the wrong axis. The README documents this; this check
    enforces it programmatically.
    """
    img = nib.load(str(t2w_path))
    shape = img.shape[:3]
    if len(shape) < 3:
        raise InputValidationError(
            f"{t2w_path}: expected a 3D volume, got shape {shape}"
        )
    sx, sy, sz = shape
    if sz >= sx or sz >= sy:
        raise InputValidationError(
            f"{t2w_path}: TSE slice axis must be z (smallest dimension); "
            f"got shape ({sx}, {sy}, {sz}). ASHS will produce wrong outputs."
        )


def check_voxel_resolution(t2w_path: Path, max_inplane_mm: float = 1.0) -> None:
    """Warn if TSE in-plane resolution is coarser than expected for subfields.

    Hippocampal subfields require sub-millimetre in-plane resolution. Looser
    voxels still run but produce volumes that are mostly partial-volume noise.
    """
    img = nib.load(str(t2w_path))
    zooms = img.header.get_zooms()[:3]
    in_plane = max(zooms[0], zooms[1])
    if in_plane > max_inplane_mm:
        raise InputValidationError(
            f"{t2w_path}: in-plane voxel size {zooms[0]:.2f}×{zooms[1]:.2f}mm "
            f"is coarser than {max_inplane_mm}mm. Subfield labels will be "
            f"unreliable. Override with --skip-qc if you accept this."
        )


def run_input_qc(t2w_paths: list[Path]) -> None:
    """Run all pre-flight checks. Raises ``InputValidationError`` on first failure."""
    for p in t2w_paths:
        check_tse_slice_direction(p)
        check_voxel_resolution(p)
