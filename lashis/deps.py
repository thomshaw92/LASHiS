"""Dependency / environment checks (replaces LASHiS.sh:30-63)."""
from __future__ import annotations

import os
import shutil
from pathlib import Path

ANTS_PROGRAMS = (
    "antsApplyTransforms",
    "N4BiasFieldCorrection",
    "ImageMath",
    "LabelGeometryMeasures",
)
ANTS_SCRIPTS = (
    "antsBrainExtraction.sh",
    "antsMultivariateTemplateConstruction2.sh",
    "antsJointLabelFusion.sh",
)
ASHS_BIN_RELATIVE = ("bin/ashs_main.sh",)


class DependencyError(RuntimeError):
    pass


def check_dependencies() -> list[str]:
    """Return a list of human-readable problems. Empty list = all good."""
    problems: list[str] = []

    for prog in (*ANTS_PROGRAMS, *ANTS_SCRIPTS):
        if shutil.which(prog) is None:
            problems.append(f"missing on PATH: {prog} (check ANTSPATH)")

    ashs_root = os.environ.get("ASHS_ROOT")
    if not ashs_root:
        problems.append("ASHS_ROOT environment variable is not set")
    else:
        root = Path(ashs_root)
        if not root.is_dir():
            problems.append(f"ASHS_ROOT is not a directory: {ashs_root}")
        else:
            for rel in ASHS_BIN_RELATIVE:
                if not (root / rel).is_file():
                    problems.append(f"missing inside ASHS_ROOT: {rel}")
            # c3d ships under ext/<Linux|Mac>/bin — accept any platform subdir
            if not list(root.glob("ext/*/bin/c3d")):
                problems.append("missing inside ASHS_ROOT: ext/*/bin/c3d")

    return problems


def assert_dependencies() -> None:
    problems = check_dependencies()
    if problems:
        raise DependencyError("; ".join(problems))
