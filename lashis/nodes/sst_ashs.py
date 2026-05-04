"""Run ASHS on the rescaled multimodal SST (LASHiS.sh:579-589)."""
from __future__ import annotations

from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..interfaces.ashs import ASHS
from ..utils.paths import sst_ashs_dir


def build_sst_ashs(config: LashisConfig) -> pe.Node:
    """Single ASHS Node consuming the two rescaled SST templates."""
    workdir = sst_ashs_dir(config.output_prefix)
    workdir.mkdir(parents=True, exist_ok=True)

    node = pe.Node(ASHS(), name="sst_ashs")
    node.inputs.atlas = str(config.atlas)
    node.inputs.working_dir = str(workdir)
    node.inputs.subject_id = "SST_ASHS"
    node.inputs.use_qsub = config.plugin == "SGE"
    if config.ashs_config is not None:
        node.inputs.config_file = str(config.ashs_config)
    if config.ashs_sge_opts:
        node.inputs.sge_opts = config.ashs_sge_opts
    return node
