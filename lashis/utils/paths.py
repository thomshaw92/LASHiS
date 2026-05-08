"""Output-directory layout for a LASHiS run.

User-facing structure (output_prefix is the user's ``-o`` argument)::

    <output_prefix>/
    ├── lashis_run.json
    ├── snaplabels.txt
    ├── stats/
    │   ├── volumes.csv
    │   ├── asymmetry.csv
    │   ├── longitudinal.csv
    │   └── per_timepoint/
    ├── qc/
    │   ├── index.html
    │   └── tp{XX}_{method}_{side}_TimePoint_{i}.html
    ├── labels/{jlf,majority}/tp{XX}_{left,right}.nii.gz
    ├── posteriors/{jlf,majority}/{side}_{NNNN}.nii.gz
    └── intermediate/
        ├── crosssectional_ashs/tp{XX}/
        ├── sst/
        │   └── ashs/                 (= SST_ASHS)
        ├── chunk_sst/{left,right}/
        └── jlf/{joint,majority}/

The Nipype cache is a SIBLING of ``output_prefix`` — ``<output>_nipype/`` —
so it doesn't pollute the clean user output dir.
"""
from __future__ import annotations

from pathlib import Path

# ---- top-level files ------------------------------------------------------

def manifest_path(output_prefix: Path) -> Path:
    return output_prefix / "lashis_run.json"


def snaplabels_path(output_prefix: Path) -> Path:
    return output_prefix / "snaplabels.txt"


# ---- user-facing output subdirs -------------------------------------------

def stats_dir(output_prefix: Path) -> Path:
    return output_prefix / "stats"


def per_timepoint_stats_dir(output_prefix: Path) -> Path:
    return stats_dir(output_prefix) / "per_timepoint"


def qc_dir(output_prefix: Path) -> Path:
    return output_prefix / "qc"


def labels_dir(output_prefix: Path, method_subdir: str | None = None) -> Path:
    base = output_prefix / "labels"
    return base / method_subdir if method_subdir else base


def posteriors_dir(output_prefix: Path, method_subdir: str | None = None) -> Path:
    base = output_prefix / "posteriors"
    return base / method_subdir if method_subdir else base


# ---- intermediate / working dirs ------------------------------------------

def intermediate_dir(output_prefix: Path) -> Path:
    return output_prefix / "intermediate"


def crosssectional_workdir(output_prefix: Path, idx: int) -> Path:
    """ASHS working dir for the given timepoint."""
    return intermediate_dir(output_prefix) / "crosssectional_ashs" / f"tp{idx:02d}"


def sst_dir(output_prefix: Path) -> Path:
    """Directory holding the multimodal SST templates."""
    return intermediate_dir(output_prefix) / "sst"


def sst_ashs_dir(output_prefix: Path) -> Path:
    return sst_dir(output_prefix) / "ashs"


def chunk_sst_dir(output_prefix: Path, side: str) -> Path:
    return intermediate_dir(output_prefix) / "chunk_sst" / side


def jlf_intermediate_dir(output_prefix: Path, method_subdir: str) -> Path:
    """Where antsJointLabelFusion.sh writes its transforms + staging inputs."""
    return intermediate_dir(output_prefix) / "jlf" / method_subdir


# ---- nipype cache (sibling of output_prefix) ------------------------------

def nipype_base_dir(output_prefix: Path) -> Path:
    return output_prefix.parent / f"{output_prefix.name}_nipype"
