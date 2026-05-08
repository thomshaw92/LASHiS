"""Nipype Interface wrapping ``$ASHS_ROOT/bin/ashs_main.sh``.

Mirrors the invocation at LASHiS.sh:487-495 / 581-589.
"""
from __future__ import annotations

import os
from pathlib import Path

from nipype.interfaces.base import (
    CommandLine,
    CommandLineInputSpec,
    Directory,
    File,
    TraitedSpec,
    traits,
)


def _strip_nii(name: str) -> str:
    if name.endswith(".nii.gz"):
        return name[:-7]
    if name.endswith(".nii"):
        return name[:-4]
    return name


class ASHSInputSpec(CommandLineInputSpec):
    atlas = Directory(
        exists=True, mandatory=True, argstr="-a %s",
        desc="ASHS atlas directory",
    )
    t1w = File(
        exists=True, mandatory=True, argstr="-g %s",
        desc="T1w MPRAGE / gradient-echo image (-g of ashs_main.sh)",
    )
    t2w = File(
        exists=True, mandatory=True, argstr="-f %s",
        desc="T2w TSE / FSE image (-f of ashs_main.sh)",
    )
    working_dir = traits.Str(
        mandatory=True, argstr="-w %s",
        desc="ASHS working/output directory; ASHS creates it if missing",
    )
    subject_id = traits.Str(
        argstr="-I %s",
        desc="ASHS subject ID (-I); when unset, ASHS infers from T1w basename",
    )
    config_file = File(
        exists=True, argstr="-C %s",
        desc="ashs_config.sh override; defaults to $ASHS_ROOT/bin/ashs_config.sh",
    )
    use_qsub = traits.Bool(
        False, argstr="-Q", usedefault=True,
        desc="submit ASHS internal jobs via qsub (-Q)",
    )
    sge_opts = traits.Str(
        argstr="-q %s",
        desc="extra options forwarded to qsub via ASHS -q",
    )
    thumbnails = traits.Bool(
        True, argstr="-T", usedefault=True,
        desc="produce thumbnails (-T); LASHiS.sh always sets this",
    )


class ASHSOutputSpec(TraitedSpec):
    segmentation_left = File(exists=True)
    segmentation_right = File(exists=True)
    tse_native_chunk_left = File(exists=True)
    tse_native_chunk_right = File(exists=True)
    mprage = File(exists=True)
    tse = File(exists=True)
    working_dir = Directory(exists=True)
    basename = traits.Str()
    icv_file = File(desc="ASHS-emitted ICV text file: <basename>_icv.txt")
    icv_mm3 = traits.Float(
        desc="Intracranial volume in mm^3, parsed from ASHS's icv.txt"
    )


class ASHS(CommandLine):
    """Run ``ashs_main.sh`` on one (T1w, T2w) pair against an ASHS atlas."""

    input_spec = ASHSInputSpec
    output_spec = ASHSOutputSpec
    _cmd = "ashs_main.sh"  # overridden in __init__ once ASHS_ROOT is known

    def __init__(self, **inputs):
        ashs_root = os.environ.get("ASHS_ROOT")
        if ashs_root:
            candidate = Path(ashs_root) / "bin" / "ashs_main.sh"
            if candidate.is_file():
                self._cmd = str(candidate)
        super().__init__(**inputs)

    def _basename(self) -> str:
        # ASHS uses -I if given, else strips .nii(.gz) from the T1w filename
        if self.inputs.subject_id:
            return self.inputs.subject_id
        return _strip_nii(Path(self.inputs.t1w).name)

    def _list_outputs(self):
        wd = Path(self.inputs.working_dir)
        out = self.output_spec().get()
        out["working_dir"] = str(wd)
        out["basename"] = self._basename()
        # Discover the actual segmentation files via glob — ASHS names them
        # <basename>_<side>_lfseg_heur.nii.gz where <basename> may be the
        # `-I` value or the T1w basename, depending on the ASHS version.
        # Globbing avoids guessing which.
        for side in ("left", "right"):
            matches = sorted((wd / "final").glob(f"*_{side}_lfseg_heur.nii.gz"))
            if matches:
                out[f"segmentation_{side}"] = str(matches[0])
            else:
                # Best-effort prediction so the trait failure message points at
                # somewhere plausible if ASHS exited but produced nothing.
                bn = self._basename()
                out[f"segmentation_{side}"] = str(
                    wd / "final" / f"{bn}_{side}_lfseg_heur.nii.gz"
                )
        out["tse_native_chunk_left"] = str(wd / "tse_native_chunk_left.nii.gz")
        out["tse_native_chunk_right"] = str(wd / "tse_native_chunk_right.nii.gz")
        out["mprage"] = str(wd / "mprage.nii.gz")
        out["tse"] = str(wd / "tse.nii.gz")

        # ASHS emits final/<basename>_icv.txt with one line: "<basename> <icv_mm3>"
        bn = out["basename"]
        icv_path = wd / "final" / f"{bn}_icv.txt"
        out["icv_file"] = str(icv_path)
        if icv_path.is_file():
            try:
                second = icv_path.read_text().strip().split()[-1]
                out["icv_mm3"] = float(second)
            except (ValueError, IndexError):
                pass
        return out


def cleanup_ashs_workdir(working_dir: str) -> str:
    """Replicate the ``rm -rf`` block at LASHiS.sh:498-507. Returns the dir.

    Self-contained: Nipype ships Function-node source to workers as text and
    executes in a fresh namespace, so module-level imports / constants aren't
    visible. All needed names live inside the function body.
    """
    import shutil
    from glob import glob
    from pathlib import Path as _Path

    cleanup_globs = (
        "final/affine_t1_to_template",
        "final/ants_t1_to_temp",
        "final/bootstrap",
        "final/dump",
        "final/flirt_t2_to_t1",
        "final/mprage_raw.nii.gz",
        "final/tse_raw.nii.gz",
        "final/mprage_to_chunk*",
        "final/*regmask",
        "tmpfiles",
    )

    wd = _Path(working_dir)
    for rel in cleanup_globs:
        for match in glob(str(wd / rel)):
            path = _Path(match)
            if path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
            else:
                path.unlink(missing_ok=True)
    return str(wd)
