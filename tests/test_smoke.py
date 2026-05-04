"""End-to-end smoke test on a bundled TOMCAT subject (BIDS layout).

Skipped unless:
  * ``ASHS_ROOT`` and ``ASHS_ATLAS`` are set in the environment.
  * ``tests/data/tomcat/sub-*/`` contains at least two sessions with both
    a T1w and a T2w image (preferring the averaged template under
    ``derivatives/templates/`` if preprocessing has been run, otherwise
    falling back to run-1 raw T2w).

Opt in with::

    pytest -m smoke
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

DATA_ROOT = Path(__file__).parent / "data" / "tomcat"
DERIVS_TEMPLATES = DATA_ROOT / "derivatives" / "templates"

# Smoke test exercises the longitudinal path with the minimum number of
# timepoints (2). Adding more sessions roughly linearly increases wall-clock
# time without adding pipeline coverage.
N_SMOKE_SESSIONS = 2


def _discover_subject() -> tuple[str, list[Path], list[Path]] | None:
    """Find a sub-* directory with ≥2 sessions and matching T1w/T2w pairs.

    Returns (subject_id, t1w_paths, t2w_paths) ordered by session, or None if
    nothing usable is present.
    """
    candidates = sorted(p for p in DATA_ROOT.glob("sub-*") if p.is_dir())
    for sub_dir in candidates:
        sub = sub_dir.name
        ses_dirs = sorted(p for p in sub_dir.glob("ses-*") if p.is_dir())
        t1w_paths: list[Path] = []
        t2w_paths: list[Path] = []
        for ses_dir in ses_dirs:
            ses = ses_dir.name
            anat = ses_dir / "anat"
            t1w = anat / f"{sub}_{ses}_T1w.nii.gz"
            if not t1w.is_file():
                continue
            # Preference order:
            #   1. canonical post-finalize BIDS T2w (averaged template moved
            #      back into anat/ and run files deleted).
            #   2. derivative template if preprocessing has run but not been
            #      finalized.
            #   3. raw run-1 (unprocessed; only useful for very-quick smoke
            #      runs, won't exercise multi-run averaging).
            t2w_candidates = [
                anat / f"{sub}_{ses}_T2w.nii.gz",
                DERIVS_TEMPLATES / sub / ses / "anat"
                    / f"{sub}_{ses}_desc-template_T2w.nii.gz",
                anat / f"{sub}_{ses}_run-1_T2w.nii.gz",
            ]
            t2w = next((c for c in t2w_candidates if c.is_file()), None)
            if t2w is None:
                continue
            t1w_paths.append(t1w)
            t2w_paths.append(t2w)
        if len(t1w_paths) >= 2:
            return (
                sub,
                t1w_paths[:N_SMOKE_SESSIONS],
                t2w_paths[:N_SMOKE_SESSIONS],
            )
    return None


@pytest.mark.smoke
@pytest.mark.skipif(_discover_subject() is None,
                    reason="no usable BIDS subject under tests/data/tomcat/")
@pytest.mark.skipif(not os.environ.get("ASHS_ROOT"),
                    reason="ASHS_ROOT not set")
@pytest.mark.skipif(not os.environ.get("ASHS_ATLAS"),
                    reason="ASHS_ATLAS not set")
def test_lashis_smoke(tmp_path: Path) -> None:
    import nibabel as nib

    from lashis.cli import main as lashis_main

    discovered = _discover_subject()
    assert discovered is not None
    sub, t1w_paths, t2w_paths = discovered
    n_tp = len(t1w_paths)

    output_prefix = tmp_path / sub
    images: list[str] = []
    for t1, t2 in zip(t1w_paths, t2w_paths):
        images.extend([str(t1), str(t2)])

    argv = [
        "-o", str(output_prefix),
        "-a", os.environ["ASHS_ATLAS"],
        "--plugin", "MultiProc", "--n-procs", "2",
        # Quick mode: SST already uses -i 1; this also drops chunk SST to -i 1
        # so the smoke test completes in a sane wall-clock time.
        "--quick", "1",
        # Run only majority-voting fusion in the smoke test (cheapest path; the
        # legacy LASHiS method). To exercise the new joint-fusion path or
        # both-method comparison, run lashis directly with --fusion {jlf,both}.
        "--fusion", "majority",
        # Skip the brain-mask + QC stages in the smoke test — the smoke test
        # verifies the core segmentation path, not the optional analytics.
        "--no-icv", "--no-qc",
        *images,
    ]
    rc = lashis_main(argv)
    assert rc == 0, f"lashis CLI exited with {rc}"

    # New layout: stats / qc / labels at the top level of output_prefix.
    labels_majority = output_prefix / "labels" / "majority"
    assert labels_majority.is_dir(), f"missing {labels_majority}"
    for side in ("left", "right"):
        for tp in range(n_tp):
            cand = labels_majority / f"tp{tp:02d}_{side}.nii.gz"
            assert cand.is_file(), f"missing warped labels {cand}"
            data = nib.load(str(cand)).get_fdata()
            assert data.sum() > 0, f"warped labels are empty: {cand}"

    volumes_csv = output_prefix / "stats" / "volumes.csv"
    assert volumes_csv.is_file(), f"missing {volumes_csv}"
    assert volumes_csv.stat().st_size > 0, "volumes.csv is empty"

    manifest = output_prefix / "lashis_run.json"
    assert manifest.is_file() and manifest.stat().st_size > 0, "missing run manifest"
