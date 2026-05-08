"""Initial multimodal single-subject template (LASHiS.sh:521-575).

Wraps ``antsMultivariateTemplateConstruction2.sh -k 2`` (T1w + T2w jointly)
and follows up with two ``ImageMath … RescaleImage 0 1000`` calls — ASHS
won't accept the raw float template output.
"""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.base import (
    CommandLine,
    CommandLineInputSpec,
    File,
    InputMultiPath,
    TraitedSpec,
    traits,
)
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import sst_dir


class _AMTCInputSpec(CommandLineInputSpec):
    """Inputs for ``antsMultivariateTemplateConstruction2.sh``.

    Flag meanings differ from the v1 script (``…Construction.sh``) used by the
    original LASHiS.sh. In v2:
      -m  similarity metric (was -s in v1)
      -q  max iterations per pairwise registration (was -m in v1)
      -s  smoothing kernels (new)
      -f  shrink factors (new)
      -t  SyN/Affine/Rigid (was 'GR' in v1)
    Defaults below preserve the LASHiS algorithmic intent.
    """
    output_prefix = traits.Str(
        mandatory=True, argstr="-o %s", position=0,
        desc="output prefix (e.g. .../T_)",
    )
    dimension = traits.Int(3, usedefault=True, argstr="-d %d")
    n_modalities = traits.Int(2, usedefault=True, argstr="-k %d")
    iterations = traits.Int(1, usedefault=True, argstr="-i %d",
                            desc="template-construction iterations")
    gradient_step = traits.Float(0.25, usedefault=True, argstr="-g %f")
    pairwise_iters = traits.Str(
        "100x70x30x3", usedefault=True, argstr="-q %s",
        desc="-q max iterations per pairwise registration "
             "(LASHiS.sh's old -m argument; renamed to -q in AMTC2)",
    )
    metric = traits.Str("CC", usedefault=True, argstr="-m %s",
                        desc="similarity metric (-m in AMTC2; was -s in v1)")
    transform = traits.Str(
        "SyN", usedefault=True, argstr="-t %s",
        desc="transform model (AMTC2 uses 'SyN' for what v1 called 'GR')",
    )
    update_full_affine = traits.Int(
        1, usedefault=True, argstr="-y %d",
        desc="update template with full affine transform (AMTC2 -y)",
    )
    rigid_init = traits.Int(1, usedefault=True, argstr="-r %d")
    parallel_control = traits.Int(0, usedefault=True, argstr="-c %d")
    n_cores = traits.Int(2, usedefault=True, argstr="-j %d")
    n4_bias = traits.Int(0, usedefault=True, argstr="-n %d")
    backup_iter = traits.Int(0, usedefault=True, argstr="-b %d")
    images = InputMultiPath(
        File(exists=True), mandatory=True, argstr="%s", position=-1,
        desc="anatomical images, interleaved as t1_a t2_a t1_b t2_b ...",
    )


class _AMTCOutputSpec(TraitedSpec):
    template0 = File(desc="T_template0.nii.gz (modality 0)")
    template1 = File(desc="T_template1.nii.gz (modality 1)")
    output_dir = traits.Str()


class _AntsMultivariateTemplateConstruction2(CommandLine):
    """Thin wrapper around ``antsMultivariateTemplateConstruction2.sh``."""

    _cmd = "antsMultivariateTemplateConstruction2.sh"
    input_spec = _AMTCInputSpec
    output_spec = _AMTCOutputSpec

    def _list_outputs(self):
        prefix = Path(self.inputs.output_prefix)
        out_dir = prefix.parent
        out = self.output_spec().get()
        out["output_dir"] = str(out_dir)
        out["template0"] = str(out_dir / f"{prefix.name}template0.nii.gz")
        out["template1"] = str(out_dir / f"{prefix.name}template1.nii.gz")
        return out


def _amtc_plugin_code(plugin: str) -> int:
    """Map a Nipype plugin to the AMTC2 ``-c`` integer."""
    return {
        "Linear": 0,
        "SGE": 1,
        "MultiProc": 2,
        "PBS": 4,
        "SLURM": 5,
    }.get(plugin, 0)


def build_sst(config: LashisConfig) -> tuple[pe.Node, pe.Node, pe.Node]:
    """Return (sst_node, rescale_t0_node, rescale_t1_node).

    Caller wires no upstream — SST consumes the raw anatomical lists from
    config — and connects the rescale nodes' outputs into downstream ASHS.
    """
    out_dir = sst_dir(config.output_prefix)
    out_dir.mkdir(parents=True, exist_ok=True)

    interleaved: list[str] = []
    for tp in config.timepoints:
        interleaved.extend([str(tp.t1w), str(tp.t2w)])

    sst = pe.Node(_AntsMultivariateTemplateConstruction2(), name="sst")
    sst.inputs.output_prefix = str(out_dir / "T_")
    sst.inputs.images = interleaved
    sst.inputs.parallel_control = _amtc_plugin_code(config.plugin)
    sst.inputs.n_cores = config.n_procs
    sst.inputs.n4_bias = int(config.n4)

    rescale_t0 = _build_rescale_node("rescale_t0", out_dir / "T_template0_rescaled.nii.gz")
    rescale_t1 = _build_rescale_node("rescale_t1", out_dir / "T_template1_rescaled.nii.gz")
    return sst, rescale_t0, rescale_t1


class _ImageMathRescaleInputSpec(CommandLineInputSpec):
    dimension = traits.Int(3, usedefault=True, argstr="%d", position=0)
    output_image = traits.Str(mandatory=True, argstr="%s", position=1)
    operation = traits.Str(
        "RescaleImage", usedefault=True, argstr="%s", position=2,
    )
    input_image = File(exists=True, mandatory=True, argstr="%s", position=3)
    out_min = traits.Int(0, usedefault=True, argstr="%d", position=4)
    out_max = traits.Int(1000, usedefault=True, argstr="%d", position=5)


class _ImageMathRescaleOutputSpec(TraitedSpec):
    output_image = File(exists=True)


class _ImageMathRescale(CommandLine):
    """``ImageMath 3 <out> RescaleImage <in> 0 1000`` (LASHiS.sh:572-573)."""

    _cmd = "ImageMath"
    input_spec = _ImageMathRescaleInputSpec
    output_spec = _ImageMathRescaleOutputSpec

    def _list_outputs(self):
        return {"output_image": str(Path(self.inputs.output_image).resolve())}


def _build_rescale_node(name: str, output_path: Path) -> pe.Node:
    node = pe.Node(_ImageMathRescale(), name=name)
    node.inputs.output_image = str(output_path)
    return node
