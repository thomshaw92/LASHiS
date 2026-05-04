"""Render Nipype workflow graphs of the LASHiS pipeline.

Produces three views under docs/:
  workflow_hierarchical.png  — nested workflow boxes; best overview
  workflow_orig.png          — flat node graph (no MapNode expansion)
  workflow_colored.png       — colored by node type (Node/MapNode/JoinNode)

Usage:
    .venv/bin/python scripts/render_workflow_graph.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

from lashis.config import LashisConfig, Timepoint
from lashis.workflow import build_workflow

REPO = Path(__file__).resolve().parent.parent
TOMCAT = REPO / "tests" / "data" / "tomcat" / "sub-06"
ATLAS = REPO / "tests" / "data" / "ashs_atlas_umcutrecht_7t_20170810"
OUT_DIR = REPO / "docs"


def main() -> None:
    timepoints = []
    for i, ses in enumerate(("ses-01", "ses-02")):
        anat = TOMCAT / ses / "anat"
        timepoints.append(
            Timepoint(
                index=i,
                t1w=anat / f"sub-06_{ses}_T1w.nii.gz",
                t2w=anat / f"sub-06_{ses}_T2w.nii.gz",
            )
        )

    cfg = LashisConfig(
        output_prefix=REPO / "docs" / "_graph_only",
        atlas=ATLAS,
        timepoints=timepoints,
        plugin="MultiProc",
        n_procs=2,
        quick=1,
    )
    wf = build_workflow(cfg)
    OUT_DIR.mkdir(exist_ok=True)

    for graph2use in ("hierarchical", "orig", "colored"):
        png = wf.write_graph(
            dotfilename=str(OUT_DIR / f"workflow_{graph2use}.dot"),
            graph2use=graph2use,
            format="png",
            simple_form=True,
        )
        print(f"  {graph2use:14s} → {png}")

    # The base_dir Nipype uses (a side-effect of build_workflow) will have
    # created some bookkeeping; tidy up so the docs folder is clean.
    shutil.rmtree(REPO / "docs" / "_graph_only_nipype", ignore_errors=True)


if __name__ == "__main__":
    main()
