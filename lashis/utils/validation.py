from __future__ import annotations

from pathlib import Path

from ..config import Timepoint


class InputValidationError(ValueError):
    pass


def pair_timepoints(images: list[str | Path]) -> list[Timepoint]:
    """Group anatomical positionals into (T1w, T2w) timepoints.

    LASHiS expects images ordered as t1_a t2_a t1_b t2_b ... .
    All paths are resolved to absolute — Nipype runs subprocesses from cache
    directories, so relative paths break ANTs/ASHS at the subprocess layer.
    """
    paths = [Path(p).expanduser().resolve() for p in images]
    if not paths:
        raise InputValidationError("no anatomical images specified")
    if len(paths) % 2 != 0:
        raise InputValidationError(
            f"expected an even number of anatomical images (T1w/T2w pairs); got {len(paths)}"
        )
    missing = [p for p in paths if not p.is_file()]
    if missing:
        raise InputValidationError(
            "the following input images do not exist: " + ", ".join(str(p) for p in missing)
        )
    return [
        Timepoint(index=i, t1w=paths[2 * i], t2w=paths[2 * i + 1])
        for i in range(len(paths) // 2)
    ]
