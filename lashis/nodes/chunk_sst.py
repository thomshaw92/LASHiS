"""Per-hemisphere TSE chunk preprocessing + chunk SST construction.

Covers LASHiS.sh:615-663 (SST-side chunk binarization), 687-760 (per-timepoint
chunk binarization), and 787-823 (per-side chunk SST via AMTC2 -k 1).

Each chunk-binarization pipeline is a linear sequence of ImageMath /
ExtractRegionFromImageByMask / antsApplyTransforms calls; we package each
sequence into a single Function node per (subject_or_timepoint, side) so that
Nipype caching boundaries land at meaningful "all-chunks-extracted" milestones.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import chunk_sst_dir, sst_ashs_dir
from .sst import _AntsMultivariateTemplateConstruction2, _amtc_plugin_code

SIDES = ("left", "right")


# --- inner helpers (copied verbatim into Nipype Function nodes) -------------
# Nipype `Function` ships these to its workers as source strings, so they must
# not depend on closures or locally-defined helpers.

def _binarize_chunk_pipeline(
    tse_chunk: str,
    mprage: str,
    out_dir: str,
    out_prefix: str,
) -> tuple[str, str]:
    """Run the 6-step ImageMath / ExtractRegion / antsApplyTransforms sequence.

    Mirrors LASHiS.sh:615-663 / 713-754. Returns (tse_chunk_out, mprage_chunk_out).
    """
    import subprocess
    from pathlib import Path

    od = Path(out_dir)
    od.mkdir(parents=True, exist_ok=True)
    resliced = od / f"{out_prefix}_tse_resliced.nii.gz"
    mask = od / f"{out_prefix}_tse_resliced_mask.nii.gz"
    tse_out = od / f"{out_prefix}_tse_chunk.nii.gz"
    mprage_resliced = od / f"{out_prefix}_mprage_tse_space.nii.gz"
    mprage_out = od / f"{out_prefix}_mprage_chunk.nii.gz"

    def _run(cmd):
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as exc:
            stderr_tail = "\n".join((exc.stderr or "").splitlines()[-30:]) or "<empty>"
            raise RuntimeError(
                f"Command failed (exit {exc.returncode}):\n  {' '.join(cmd)}\n"
                f"--- stderr (last 30 lines) ---\n{stderr_tail}"
            ) from exc

    # 1. rescale TSE chunk to 0-10000 (gives us a foreground signal to threshold)
    _run(["ImageMath", "3", str(resliced), "RescaleImage", tse_chunk, "0", "10000"])
    # 2. binarize: every voxel >= 0.01 becomes 1
    _run(["ImageMath", "3", str(mask), "ReplaceVoxelValue", str(resliced), "0.01", "10000", "1"])
    # 3. fill holes
    _run(["ImageMath", "3", str(mask), "FillHoles", str(mask), "1"])
    # 4. extract TSE chunk using mask
    _run(["ExtractRegionFromImageByMask", "3", str(resliced), str(tse_out), str(mask), "1", "0"])
    # 5. resample mprage into TSE space
    _run([
        "antsApplyTransforms", "-d", "3",
        "-i", mprage, "-r", str(tse_out), "-o", str(mprage_resliced),
    ])
    # 6. extract mprage chunk
    _run([
        "ExtractRegionFromImageByMask", "3",
        str(mprage_resliced), str(mprage_out), str(mask), "1", "0",
    ])
    return str(tse_out), str(mprage_out)


# --- node builders ----------------------------------------------------------

def build_sst_chunk_preprocess(config: LashisConfig) -> dict[str, pe.Node]:
    """One Function node per side, consuming the SST_ASHS chunk + mprage."""
    nodes: dict[str, pe.Node] = {}
    sst_ashs_path = sst_ashs_dir(config.output_prefix)
    for side in SIDES:
        node = pe.Node(
            Function(
                input_names=["tse_chunk", "mprage", "out_dir", "out_prefix"],
                output_names=["tse_chunk_out", "mprage_chunk_out"],
                function=_binarize_chunk_pipeline,
            ),
            name=f"sst_chunk_{side}",
        )
        node.inputs.out_dir = str(sst_ashs_path)
        node.inputs.out_prefix = f"sst_{side}"
        nodes[side] = node
    return nodes


def build_timepoint_chunk_preprocess(
    config: LashisConfig,
) -> dict[str, pe.MapNode]:
    """One MapNode per side, iterating over timepoints.

    Inputs (`tse_chunk`, `mprage`) come from the cross-sectional ASHS MapNode's
    list outputs (`tse_native_chunk_<side>` and `mprage`).
    """
    nodes: dict[str, pe.MapNode] = {}
    n_tp = len(config.timepoints)
    for side in SIDES:
        node = pe.MapNode(
            Function(
                input_names=["tse_chunk", "mprage", "out_dir", "out_prefix"],
                output_names=["tse_chunk_out", "mprage_chunk_out"],
                function=_binarize_chunk_pipeline,
            ),
            name=f"tp_chunk_{side}",
            iterfield=["tse_chunk", "mprage", "out_dir", "out_prefix"],
        )
        # Per-timepoint output dirs and prefixes.
        out_dirs = [
            str(config.output_prefix / f"chunk_pp_{side}_{i}")
            for i in range(n_tp)
        ]
        node.inputs.out_dir = out_dirs
        node.inputs.out_prefix = [f"tp{i}_{side}" for i in range(n_tp)]
        nodes[side] = node
    return nodes


def build_chunk_sst(config: LashisConfig) -> dict[str, pe.Node]:
    """Per-side AMTC2 node that builds the chunk SST from collected TSE chunks.

    Caller must wire a JoinNode-style list of TSE chunk paths (per-timepoint
    + the SST-side chunk) into ``images`` for each side.
    """
    out: dict[str, pe.Node] = {}
    for side in SIDES:
        out_dir = chunk_sst_dir(config.output_prefix, side)
        out_dir.mkdir(parents=True, exist_ok=True)

        node = pe.Node(_AntsMultivariateTemplateConstruction2(), name=f"chunk_sst_{side}")
        node.inputs.output_prefix = str(out_dir / "T_")
        node.inputs.n_modalities = 1
        # LASHiS.sh:812 used -i 3; --quick drops it to 1 for fast smoke runs.
        node.inputs.iterations = 1 if config.quick > 0 else 3
        node.inputs.gradient_step = 0.15
        node.inputs.parallel_control = _amtc_plugin_code(config.plugin)
        node.inputs.n_cores = config.n_procs
        node.inputs.n4_bias = int(config.n4)
        out[side] = node
    return out


def collect_chunks(per_tp_chunks: list[str], sst_chunk: str) -> list[str]:
    """Concatenate per-timepoint chunks with the SST-side chunk.

    Used as a JoinNode function: matches LASHiS.sh:822 glob behaviour
    (``tse_SST_input_<side>*.nii.gz`` → SST + per-timepoint files).
    """
    return [*per_tp_chunks, sst_chunk]
