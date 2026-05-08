"""argparse entry point for the `lashis` console script.

Mirrors the original LASHiS.sh flag set so existing callers can switch over
with minimal changes. Numeric `-c` codes from the bash script are still
accepted for backwards compatibility.
"""
from __future__ import annotations

import argparse
import datetime
import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

from .config import LashisConfig
from .deps import check_dependencies
from .utils.preflight import run_input_qc
from .utils.validation import InputValidationError, pair_timepoints

PLUGIN_BY_CODE = {
    "0": "Linear",
    "1": "SGE",
    "2": "MultiProc",
    # 3 (XGrid) intentionally absent — rejected below
    "4": "PBS",
    "5": "SLURM",
}
VALID_PLUGINS = {"Linear", "SGE", "MultiProc", "PBS", "SLURM"}


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="lashis",
        description="Longitudinal Automatic Segmentation of Hippocampal Subfields.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("-o", "--output-prefix", type=Path, required=False,
                   help="output prefix; SST and per-timepoint dirs are created relative to this")
    p.add_argument("-a", "--atlas", type=Path, required=False,
                   help="path to the ASHS atlas directory")
    p.add_argument("images", nargs="*", type=Path,
                   help="anatomical images ordered as t1_a t2_a t1_b t2_b ...")

    p.add_argument("-c", "--plugin", default="Linear",
                   help="Nipype plugin: Linear|SGE|MultiProc|PBS|SLURM. "
                        "Legacy numeric codes (0/1/2/4/5) are also accepted.")
    p.add_argument("-d", "--ashs-sge-opts", default=None,
                   help="extra options forwarded to ASHS via -q (requires --plugin SGE)")
    p.add_argument("-e", "--ashs-config", type=Path, default=None,
                   help="ASHS config file; defaults to $ASHS_ROOT/bin/ashs_config.sh")
    p.add_argument("-g", "--denoise", action="store_true",
                   help="denoise anatomical images with DenoiseImage before processing")
    p.add_argument("-n", "--n4", action="store_true",
                   help="apply N4 bias correction before template construction")
    p.add_argument("-j", "--n-procs", type=int, default=2,
                   help="processes for the MultiProc plugin and `-j` of antsMultivariate*")
    p.add_argument("-b", "--keep-tmp", action="store_true",
                   help="keep intermediate files (skip cleanup nodes)")
    p.add_argument("-q", "--quick", type=int, default=0, choices=(0, 1, 2),
                   help="0 fast SST; 1 + fast JLF; 2 + (legacy Diet — capped here)")
    p.add_argument("-z", "--debug", action="store_true",
                   help="set Nipype log level to DEBUG and don't exit on first node failure")
    p.add_argument("-v", "--verbose", action="store_true", help="INFO log level")

    # Removed-but-reported flags (LASHiS.sh -f/-s) so users get a clear error
    p.add_argument("-f", "--diet", default=None,
                   help=argparse.SUPPRESS)
    p.add_argument("-s", "--suffix", default=None,
                   help=argparse.SUPPRESS)

    p.add_argument("--check-deps", action="store_true",
                   help="check ANTs/ASHS dependencies and exit")
    p.add_argument("--skip-qc", action="store_true",
                   help="skip pre-flight input QC (TSE slice direction, voxel size)")
    p.add_argument("--fusion", choices=("majority", "jlf", "both"), default="both",
                   help="JLF voting method: 'majority' (LASHiS legacy), 'jlf' "
                        "(weighted joint label fusion), or 'both' (default; "
                        "runs JLF twice — registrations are not shared).")
    p.add_argument("--no-icv", action="store_true",
                   help="skip the per-timepoint ICV column (read from ASHS's "
                        "final/<basename>_icv.txt; no extra subprocess)")
    p.add_argument("--no-qc", action="store_true",
                   help="skip generation of HTML QC viewers per timepoint")
    p.add_argument("--no-jacobian", action="store_true",
                   help="skip Jacobian-determinant volume estimation + the "
                        "consistency.csv check against segmentation volumes")
    p.add_argument("--jacobian-threshold", type=float, default=0.10,
                   help="flag a (subfield, timepoint) row in consistency.csv "
                        "as unreliable when |seg_change_pct - jacobian_change_pct| "
                        "exceeds this fraction (default 0.10 = 10%%)")
    p.add_argument("--jacobian-penalise", action="store_true",
                   help="produce a Jacobian-penalised label map per (tp, side, "
                        "method): per-label volumes are pulled toward the "
                        "Jacobian's prediction (larger labels penalised more) "
                        "via greedy posterior thresholding. Outputs land at "
                        "labels/<method>_jacpen/")
    p.add_argument("--jacpen-weighting", choices=("linear", "sqrt", "equal"),
                   default="linear",
                   help="how penalty weight scales with label rank-by-size: "
                        "'linear' (default), 'sqrt' (penalty drops faster for "
                        "smaller labels), 'equal' (no ranking, all 50/50)")
    p.add_argument("--no-jacpen-largest-cc", action="store_true",
                   help="skip the largest-connected-component cleanup that "
                        "drops greedy-thresholding fragments")
    return p


def _resolve_plugin(value: str) -> str:
    if value in PLUGIN_BY_CODE:
        return PLUGIN_BY_CODE[value]
    if value == "3":
        raise SystemExit(
            "plugin code 3 (Apple XGrid) is no longer supported; "
            "use --plugin MultiProc, SGE, PBS, or SLURM instead"
        )
    if value not in VALID_PLUGINS:
        raise SystemExit(
            f"unknown plugin {value!r}; expected one of "
            f"{sorted(VALID_PLUGINS)} or a legacy numeric code"
        )
    return value


def parse_args(argv: list[str] | None = None) -> tuple[argparse.Namespace, LashisConfig | None]:
    """Parse argv. Returns (namespace, config-or-None).

    Config is None when the invocation only needs argv (e.g. --check-deps).
    """
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.diet is not None:
        parser.error("the -f/--diet (Diet LASHiS) option has been removed in v2.0")
    if args.suffix is not None:
        parser.error("the -s/--suffix option has been removed; ASHS hard-codes .nii.gz")

    if args.check_deps:
        return args, None

    if args.output_prefix is None or args.atlas is None or not args.images:
        parser.error("-o/--output-prefix, -a/--atlas, and anatomical images are required")

    # Resolve to absolute paths — subprocesses run from Nipype cache dirs and
    # any non-absolute path breaks at the ANTs/ASHS layer.
    args.output_prefix = args.output_prefix.expanduser().resolve()
    args.atlas = args.atlas.expanduser().resolve()
    if args.ashs_config is not None:
        args.ashs_config = args.ashs_config.expanduser().resolve()
    if not args.atlas.is_dir():
        parser.error(f"atlas directory does not exist: {args.atlas}")

    try:
        timepoints = pair_timepoints(args.images)
    except InputValidationError as exc:
        parser.error(str(exc))

    plugin = _resolve_plugin(args.plugin)

    cfg = LashisConfig(
        output_prefix=args.output_prefix,
        atlas=args.atlas,
        timepoints=timepoints,
        plugin=plugin,
        n_procs=args.n_procs,
        denoise=args.denoise,
        n4=args.n4,
        keep_tmp=args.keep_tmp,
        quick=args.quick,
        ashs_config=args.ashs_config,
        ashs_sge_opts=args.ashs_sge_opts,
        debug=args.debug,
        fusion=args.fusion,
        icv=not args.no_icv,
        qc=not args.no_qc,
        jacobian=not args.no_jacobian,
        jacobian_threshold=args.jacobian_threshold,
        jacpen=args.jacobian_penalise,
        jacpen_weighting=args.jacpen_weighting,
        jacpen_largest_cc=not args.no_jacpen_largest_cc,
    )
    return args, cfg


def _setup_logging(args: argparse.Namespace) -> None:
    level = logging.DEBUG if args.debug else logging.INFO if args.verbose else logging.WARNING
    logging.basicConfig(level=level, format="%(asctime)s %(name)s %(levelname)s %(message)s")


def main(argv: list[str] | None = None) -> int:
    args, cfg = parse_args(argv)
    _setup_logging(args)

    if args.check_deps:
        problems = check_dependencies()
        if problems:
            for p in problems:
                print(f"MISSING: {p}", file=sys.stderr)
            return 1
        print("All ANTs/ASHS dependencies look OK.")
        return 0

    assert cfg is not None  # narrowed by check_deps branch
    cfg.output_dir.mkdir(parents=True, exist_ok=True)

    if not args.skip_qc:
        try:
            run_input_qc([tp.t2w for tp in cfg.timepoints])
        except InputValidationError as exc:
            print(f"Input QC failed: {exc}", file=sys.stderr)
            print("Re-run with --skip-qc if you accept this.", file=sys.stderr)
            return 2

    _write_run_manifest(cfg, argv)

    from .workflow import build_workflow
    from .utils.paths import nipype_base_dir

    wf = build_workflow(cfg)
    plugin_args = {"n_procs": cfg.n_procs} if cfg.plugin == "MultiProc" else {}
    started_at = datetime.datetime.now().timestamp()
    try:
        wf.run(plugin=cfg.plugin, plugin_args=plugin_args)
    except Exception as exc:
        _print_failure_summary(cfg, started_at, exc)
        return 1
    return 0


def _print_failure_summary(
    cfg: LashisConfig, started_at: float, exc: Exception
) -> None:
    """Surface the actual stderr / Python traceback from each crashed Node.

    Nipype dumps crash info to ``crash-<ts>-<host>-<node>-<uuid>.txt`` files
    when ``crashfile_format='txt'`` is set on the workflow. We find the ones
    written since this run started and print them inline so the user sees
    'which node failed and why' without having to ``cat`` pickle files.
    """
    from .utils.paths import nipype_base_dir

    crash_dirs = [
        Path.cwd(),
        cfg.output_prefix.parent,
        nipype_base_dir(cfg.output_prefix),
    ]
    crash_files: list[Path] = []
    seen: set[Path] = set()
    for d in crash_dirs:
        if not d.is_dir():
            continue
        for p in d.glob("crash-*.txt"):
            if p in seen or p.stat().st_mtime < started_at - 5:
                continue
            seen.add(p)
            crash_files.append(p)
    crash_files.sort(key=lambda p: p.stat().st_mtime)

    bar = "=" * 78
    print(f"\n{bar}", file=sys.stderr)
    print("LASHiS workflow failed — summary of failed nodes:", file=sys.stderr)
    print(bar, file=sys.stderr)
    if not crash_files:
        print(f"\n  No crash files found. Top-level error:\n    {exc}\n",
              file=sys.stderr)
        return

    for cf in crash_files:
        print(f"\n=== {cf.name} ===", file=sys.stderr)
        text = cf.read_text(errors="replace")
        # Extract Node name + the inner traceback (skip the boilerplate).
        node_line = next(
            (ln for ln in text.splitlines() if ln.startswith("Node:")),
            "Node: <unknown>",
        )
        print(node_line, file=sys.stderr)
        # Heuristic: print the last 60 lines of the crashfile — usually
        # contains the original tool's stderr + the Python traceback.
        tail = text.splitlines()[-60:]
        for ln in tail:
            print("  " + ln, file=sys.stderr)

    print(f"\n{bar}", file=sys.stderr)
    print(f"Top-level workflow error: {exc}", file=sys.stderr)
    print(f"Full crash files: {[str(p) for p in crash_files]}", file=sys.stderr)
    print(f"{bar}\n", file=sys.stderr)


def _capture_version(cmd: list[str]) -> str:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        for stream in (r.stdout, r.stderr):
            if stream and stream.strip():
                return stream.strip().splitlines()[0]
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return "unknown"


def _write_run_manifest(cfg: LashisConfig, argv: list[str] | None) -> None:
    """Write LASHiS/lashis_run.json with version + parameter manifest.

    Captures everything needed to reproduce a run: lashis version, the exact
    CLI invocation, ANTs/ASHS versions, plugin choice, and config flags.
    """
    from . import __version__

    invoked = list(argv) if argv is not None else sys.argv[1:]
    manifest = {
        "lashis_version": __version__,
        "invoked": ["lashis", *invoked],
        "started_at": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "python_version": sys.version.split()[0],
        "platform": sys.platform,
        "config": {
            "output_prefix": str(cfg.output_prefix),
            "atlas": str(cfg.atlas),
            "n_timepoints": len(cfg.timepoints),
            "timepoints": [
                {"index": tp.index, "t1w": str(tp.t1w), "t2w": str(tp.t2w)}
                for tp in cfg.timepoints
            ],
            "plugin": cfg.plugin,
            "n_procs": cfg.n_procs,
            "denoise": cfg.denoise,
            "n4": cfg.n4,
            "quick": cfg.quick,
            "keep_tmp": cfg.keep_tmp,
        },
        "ANTs_version": _capture_version(["antsRegistration", "--version"]),
        "ANTSPATH": os.environ.get("ANTSPATH", ""),
        "ASHS_root": os.environ.get("ASHS_ROOT", ""),
        "FSLDIR": os.environ.get("FSLDIR", ""),
    }
    ashs_root = os.environ.get("ASHS_ROOT")
    if ashs_root and shutil.which("git"):
        try:
            r = subprocess.run(
                ["git", "-C", ashs_root, "rev-parse", "HEAD"],
                capture_output=True, text=True, timeout=5,
            )
            if r.returncode == 0:
                manifest["ASHS_commit"] = r.stdout.strip()
        except subprocess.TimeoutExpired:
            pass

    from .utils.paths import manifest_path
    out_path = manifest_path(cfg.output_prefix)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
