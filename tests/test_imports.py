"""Atlas-free fast tests — verify the package imports, the workflow assembles,
and the CLI parses. These run in seconds and don't need ASHS, FSL, an atlas,
or any real input data — so they're suitable for CI / Docker build-time tests.

Default ``pytest`` runs these. The slow real-data smoke test is gated behind
``-m smoke``.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

import pytest


def test_package_imports():
    """Every top-level module imports cleanly."""
    import lashis
    import lashis.cli
    import lashis.config
    import lashis.deps
    import lashis.workflow
    import lashis.interfaces.ashs
    import lashis.nodes.crosssectional
    import lashis.nodes.sst
    import lashis.nodes.sst_ashs
    import lashis.nodes.chunk_sst
    import lashis.nodes.jlf
    import lashis.nodes.jacobian
    import lashis.nodes.jacpen
    import lashis.nodes.stats
    import lashis.nodes.qc
    import lashis.utils.paths
    import lashis.utils.validation
    import lashis.utils.preflight


def test_cli_help_runs():
    """CLI parser builds without errors and --help exits cleanly."""
    from lashis.cli import _build_parser

    parser = _build_parser()
    # SystemExit is what argparse raises on --help
    with pytest.raises(SystemExit) as exc:
        parser.parse_args(["--help"])
    assert exc.value.code == 0


def test_dep_check_reports_missing_ashs():
    """check_dependencies returns a non-empty list when ASHS_ROOT is unset."""
    import os

    from lashis.deps import check_dependencies

    saved = os.environ.pop("ASHS_ROOT", None)
    try:
        problems = check_dependencies()
        # ASHS_ROOT being unset is one expected problem.
        assert any("ASHS_ROOT" in p for p in problems), problems
    finally:
        if saved is not None:
            os.environ["ASHS_ROOT"] = saved


def test_pair_timepoints_validates_inputs(tmp_path: Path):
    """pair_timepoints groups T1w/T2w correctly and rejects bad inputs."""
    from lashis.utils.validation import InputValidationError, pair_timepoints

    # Make four placeholder files
    files = [tmp_path / f"img{i}.nii.gz" for i in range(4)]
    for f in files:
        f.write_bytes(b"")

    tps = pair_timepoints(files)
    assert len(tps) == 2
    assert tps[0].t1w == files[0].resolve()
    assert tps[0].t2w == files[1].resolve()
    assert tps[1].index == 1

    # Odd count should raise
    with pytest.raises(InputValidationError):
        pair_timepoints(files[:3])

    # Missing file should raise
    bogus = tmp_path / "nonexistent.nii.gz"
    with pytest.raises(InputValidationError):
        pair_timepoints([files[0], bogus])


def test_workflow_assembles_with_full_features(tmp_path: Path):
    """build_workflow constructs a valid Nipype DAG with every feature on."""
    from lashis.config import LashisConfig, Timepoint
    from lashis.workflow import build_workflow

    # Placeholder files just need to exist for File-trait validation
    files = {n: tmp_path / f"{n}.nii.gz" for n in ["t1_a", "t2_a", "t1_b", "t2_b"]}
    for p in files.values():
        p.write_bytes(b"")
    atlas = tmp_path / "atlas"
    atlas.mkdir()
    (atlas / "snap").mkdir()
    (atlas / "snap" / "snaplabels.txt").write_text(
        '1 0 0 0 1 1 1 "CA1"\n'
    )

    cfg = LashisConfig(
        output_prefix=tmp_path / "sub-XX",
        atlas=atlas,
        timepoints=[
            Timepoint(0, files["t1_a"], files["t2_a"]),
            Timepoint(1, files["t1_b"], files["t2_b"]),
        ],
        plugin="Linear",
        n_procs=1,
        quick=1,
        fusion="both",
        icv=True,
        qc=True,
        jacobian=True,
        jacpen=True,
    )
    wf = build_workflow(cfg)
    nodes = wf.list_node_names()
    assert len(nodes) > 0, "no nodes assembled"
    # Spot-check the major stages are present
    must_have = {
        "crosssectional_ashs",
        "sst",
        "sst_ashs",
        "jlf_left_jlf", "jlf_right_majority",
        "jacobian_left_jlf",
        "jacpen_left_jlf",
        "qc_viewer",
        "aggregate_stats_csv",
    }
    missing = must_have - set(nodes)
    assert not missing, f"missing expected nodes: {missing}"


def test_qc_html_template_self_contained(tmp_path: Path):
    """The QC HTML generator runs standalone with placeholder paths."""
    from lashis.nodes.qc import _make_qc_index_html

    qc = tmp_path / "qc"
    qc.mkdir()
    out = qc / "index.html"
    fakes = [tmp_path / f"f{i}.nii.gz" for i in range(2)]
    for f in fakes:
        f.write_bytes(b"")
    res = _make_qc_index_html(
        subject="sub-XX",
        tse_per_tp=[str(f) for f in fakes],
        labels_jlf_left=[str(f) for f in fakes],
        labels_jlf_right=[str(f) for f in fakes],
        labels_majority_left=[],
        labels_majority_right=[],
        labels_jacpen_jlf_left=[],
        labels_jacpen_jlf_right=[],
        labels_jacpen_majority_left=[],
        labels_jacpen_majority_right=[],
        output_path=str(out),
    )
    html = Path(res).read_text()
    # Sanity: the NiiVue CDN reference is present, the manifest is JSON-shaped,
    # and a serve.sh helper got dropped next to the index.
    assert "niivue.umd.js" in html
    assert "MANIFEST = " in html
    assert (qc / "serve.sh").is_file()
