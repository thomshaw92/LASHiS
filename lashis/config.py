from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Timepoint:
    index: int
    t1w: Path
    t2w: Path

    @property
    def subject_id(self) -> str:
        return f"tp{self.index:02d}"


@dataclass
class LashisConfig:
    output_prefix: Path
    atlas: Path
    timepoints: list[Timepoint]
    plugin: str = "Linear"
    n_procs: int = 2
    denoise: bool = False
    n4: bool = False
    keep_tmp: bool = False
    quick: int = 0
    ashs_config: Path | None = None
    ashs_sge_opts: str | None = None
    debug: bool = False
    fusion: str = "both"  # 'majority', 'jlf', or 'both'
    icv: bool = True      # read ASHS-emitted ICV (final/<basename>_icv.txt)
    qc: bool = True       # generate HTML QC viewers per timepoint
    jacobian: bool = True            # compute Jacobian-predicted volumes
    jacobian_threshold: float = 0.10 # flag rows where seg vs jacobian change diverge by > 10%
    jacpen: bool = False             # opt-IN: produce Jacobian-penalised segmentation
    jacpen_weighting: str = "linear" # 'linear' | 'sqrt' | 'equal' rank → penalty weight
    jacpen_largest_cc: bool = True   # keep largest connected component per label after jacpen
    extra_plugin_args: dict = field(default_factory=dict)

    @property
    def output_dir(self) -> Path:
        parent = self.output_prefix.parent
        return parent if str(parent) not in ("", ".") else Path.cwd()
