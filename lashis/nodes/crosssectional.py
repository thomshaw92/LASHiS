"""Cross-sectional ASHS over all timepoints (LASHiS.sh:451-509)."""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..interfaces.ashs import ASHS, cleanup_ashs_workdir
from ..utils.paths import crosssectional_workdir


def build_crosssectional(config: LashisConfig) -> tuple[pe.MapNode, pe.MapNode]:
    """Return (ashs_mapnode, cleanup_mapnode).

    Working dirs land at ``<output>/intermediate/crosssectional_ashs/tp{XX}/``;
    we pass ``-I tp{XX}`` so ASHS-emitted output filenames are predictable.
    """
    n = len(config.timepoints)
    t1w_list = [str(tp.t1w) for tp in config.timepoints]
    t2w_list = [str(tp.t2w) for tp in config.timepoints]
    workdirs = [
        str(crosssectional_workdir(config.output_prefix, tp.index))
        for tp in config.timepoints
    ]
    subject_ids = [tp.subject_id for tp in config.timepoints]

    ashs_node = pe.MapNode(
        ASHS(),
        name="crosssectional_ashs",
        iterfield=["t1w", "t2w", "working_dir", "subject_id"],
        synchronize=True,
    )
    ashs_node.inputs.atlas = str(config.atlas)
    ashs_node.inputs.t1w = t1w_list
    ashs_node.inputs.t2w = t2w_list
    ashs_node.inputs.working_dir = workdirs
    ashs_node.inputs.subject_id = subject_ids
    ashs_node.inputs.use_qsub = config.plugin == "SGE"
    if config.ashs_config is not None:
        ashs_node.inputs.config_file = str(config.ashs_config)
    if config.ashs_sge_opts:
        ashs_node.inputs.sge_opts = config.ashs_sge_opts

    # Make the ASHS workdirs exist before MapNode iterations launch — Nipype
    # otherwise complains about the working_dir trait pointing at a non-existent
    # path when wiring. We do this once at workflow construction.
    for wd in workdirs:
        Path(wd).mkdir(parents=True, exist_ok=True)

    cleanup_node = pe.MapNode(
        Function(
            input_names=["working_dir"],
            output_names=["working_dir"],
            function=cleanup_ashs_workdir,
        ),
        name="crosssectional_cleanup",
        iterfield=["working_dir"],
    )

    # n is captured here so the workflow knows how many iterations to expect
    cleanup_node._lashis_n = n  # noqa: SLF001 (debugging marker)
    return ashs_node, cleanup_node
