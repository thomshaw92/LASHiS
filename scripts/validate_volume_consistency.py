#!/usr/bin/env python3
"""Cross-session volume consistency check for LASHiS v2 on TOMCAT.

Per (subject, side, subfield, method), we expect young healthy controls to
have stable hippocampal subfield volumes across sessions. This script
extracts volumes from a LASHiS v2 output dir per subject, plus the
cross-sectional ASHS volumes that LASHiS dropped into intermediate/, and
computes:

  - per-subject %CV across sessions (sd/mean × 100)
  - per-subject max %|change vs baseline|
  - aggregated mean ± sd of those across subjects, per method

Methods compared:
  ashs_xs              (independent per-timepoint cross-sectional ASHS)
  jlf                  (LASHiS joint label fusion)
  majority             (LASHiS majority voting)
  jlf_jacpen           (LASHiS JLF + Jacobian-penalised relabelling)
  majority_jacpen      (LASHiS majority + Jacobian-penalised relabelling)

Usage:
  scripts/validate_volume_consistency.py tests/output/sub-01 tests/output/sub-02
  scripts/validate_volume_consistency.py --root tests/output --auto
"""
from __future__ import annotations

import argparse
import csv
import math
import statistics
import sys
from pathlib import Path

ASHS_VOLUMES_NAME = "_heur_volumes.txt"  # ashs writes <subj>_<side>_heur_volumes.txt


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open() as f:
        return list(csv.DictReader(f))


def load_lashis_volumes(out_dir: Path) -> list[dict[str, str]]:
    """Return long-format rows tagged with method ∈ {jlf, majority,
    jlf_jacpen, majority_jacpen}.

    The 'subject' column inside volumes.csv contains whatever ASHS uses as
    its -I subject ID (e.g. 'tp00') — that is NOT the BIDS subject (e.g.
    'sub-01'). Without the override below, the per-subject grouping in
    write_per_subject_summary collapses every BIDS subject's tp00 into one
    bucket and computes inter-subject CV at each timepoint. We want
    within-subject longitudinal CV, so override with the BIDS subject taken
    from the LASHiS output dir name.
    """
    rows: list[dict[str, str]] = []
    method_map = {"joint": "jlf", "majorityvoting": "majority"}
    subject = out_dir.name

    for fname, jacpen in [("volumes.csv", False), ("jacpen_volumes.csv", True)]:
        for r in read_csv(out_dir / "stats" / fname):
            base_method = method_map.get(r["fusion_method"], r["fusion_method"])
            method = f"{base_method}_jacpen" if jacpen else base_method
            rows.append({
                "subject": subject,
                "session_idx": r["session_idx"],
                "side": r["side"],
                "subfield": r["subfield"],
                "method": method,
                "volume_mm3": r["volume_mm3"],
            })
    return rows


def load_ashs_xs_volumes(out_dir: Path) -> list[dict[str, str]]:
    """Cross-sectional ASHS volumes from intermediate/crosssectional_ashs/.

    See load_lashis_volumes for the reason we use out_dir.name as the
    subject rather than parsing it from the heur_volumes.txt filename.
    """
    rows: list[dict[str, str]] = []
    xs_root = out_dir / "intermediate" / "crosssectional_ashs"
    if not xs_root.exists():
        return rows
    subject = out_dir.name
    for tp_dir in sorted(xs_root.glob("tp*")):
        try:
            tp_idx = int(tp_dir.name[2:])
        except ValueError:
            continue
        final_dir = tp_dir / "final"
        if not final_dir.is_dir():
            continue
        for vol_path in final_dir.glob(f"*{ASHS_VOLUMES_NAME}"):
            # filename: <ashs-id>_<side>_heur_volumes.txt — only used to
            # extract `side`; subject is overridden above.
            stem = vol_path.name[: -len(ASHS_VOLUMES_NAME)]
            if "_left" in stem:
                side = "left"
            elif "_right" in stem:
                side = "right"
            else:
                continue
            for line in vol_path.read_text().splitlines():
                parts = line.split()
                if len(parts) != 5:
                    continue
                _subj, _side, subfield, _z, vol = parts
                rows.append({
                    "subject": subject,
                    "session_idx": str(tp_idx),
                    "side": side,
                    "subfield": subfield,
                    "method": "ashs_xs",
                    "volume_mm3": vol,
                })
    return rows


def percent_cv(values: list[float]) -> float:
    if len(values) < 2:
        return float("nan")
    m = statistics.mean(values)
    if m <= 0:
        return float("nan")
    sd = statistics.stdev(values)
    return sd / m * 100.0


def max_abs_pct_change_vs_baseline(values: list[float]) -> float:
    if not values or values[0] <= 0:
        return float("nan")
    base = values[0]
    return max(abs(v - base) / base * 100.0 for v in values)


def write_long_csv(rows: list[dict[str, str]], path: Path) -> None:
    if not rows:
        path.write_text("")
        return
    cols = ["subject", "session_idx", "side", "subfield", "method", "volume_mm3"]
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)


def write_per_subject_summary(rows: list[dict], path: Path) -> None:
    """One row per (subject × side × subfield × method): cv%, max|Δ%|."""
    grouped: dict[tuple, list[tuple[int, float]]] = {}
    for r in rows:
        key = (r["subject"], r["side"], r["subfield"], r["method"])
        try:
            tp = int(r["session_idx"])
            v = float(r["volume_mm3"])
        except ValueError:
            continue
        grouped.setdefault(key, []).append((tp, v))

    cols = ["subject", "side", "subfield", "method",
            "n_sessions", "mean_mm3", "sd_mm3", "cv_pct", "max_abs_pct_change"]
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for key in sorted(grouped):
            ts = sorted(grouped[key])
            vols = [v for _t, v in ts]
            if len(vols) < 2:
                continue
            m = statistics.mean(vols)
            sd = statistics.stdev(vols)
            cv = (sd / m * 100.0) if m > 0 else float("nan")
            mp = max_abs_pct_change_vs_baseline(vols)
            w.writerow([*key, len(vols), f"{m:.3f}", f"{sd:.3f}",
                        f"{cv:.3f}", f"{mp:.3f}"])


def write_method_summary(per_subject_csv: Path, path: Path) -> None:
    """Aggregate per-subject CVs into mean ± sd across (subjects × subfields × sides)
    per method. Lower CV = pipeline more consistent on stable subjects."""
    rows = read_csv(per_subject_csv)
    by_method: dict[str, list[float]] = {}
    by_method_sf: dict[tuple[str, str], list[float]] = {}
    for r in rows:
        try:
            cv = float(r["cv_pct"])
        except ValueError:
            continue
        if math.isnan(cv):
            continue
        by_method.setdefault(r["method"], []).append(cv)
        by_method_sf.setdefault((r["method"], r["subfield"]), []).append(cv)

    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["scope", "method", "subfield", "n",
                    "mean_cv_pct", "median_cv_pct", "sd_cv_pct"])
        for method in sorted(by_method):
            xs = by_method[method]
            w.writerow(["overall", method, "", len(xs),
                        f"{statistics.mean(xs):.3f}",
                        f"{statistics.median(xs):.3f}",
                        f"{statistics.stdev(xs):.3f}" if len(xs) > 1 else "NaN"])
        for method, sf in sorted(by_method_sf):
            xs = by_method_sf[(method, sf)]
            w.writerow(["per_subfield", method, sf, len(xs),
                        f"{statistics.mean(xs):.3f}",
                        f"{statistics.median(xs):.3f}",
                        f"{statistics.stdev(xs):.3f}" if len(xs) > 1 else "NaN"])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("output_dirs", nargs="*",
                    help="LASHiS output dirs (the dir holding stats/, intermediate/)")
    ap.add_argument("--root", type=Path, default=None,
                    help="With --auto: scan this dir for sub-* output trees")
    ap.add_argument("--auto", action="store_true",
                    help="Auto-discover sub-* under --root")
    ap.add_argument("--out", type=Path, default=Path("validation"),
                    help="Where to write CSVs (default ./validation)")
    ap.add_argument("--exclude-subfield", action="append", default=["Cyst"],
                    help="Drop this subfield from the consistency stats. "
                         "Repeatable. 'Cyst' is excluded by default (it is a "
                         "sparse irregular label essentially absent in healthy "
                         "controls; near-zero volumes give meaningless CV). "
                         "Pass --exclude-subfield '' to disable the default "
                         "exclusion.")
    args = ap.parse_args()
    exclude = {sf for sf in args.exclude_subfield if sf}

    if args.auto:
        if args.root is None:
            ap.error("--auto requires --root")
        dirs = sorted([p for p in args.root.iterdir()
                       if p.is_dir() and p.name.startswith("sub-")
                       and (p / "stats" / "volumes.csv").exists()])
    else:
        dirs = [Path(d) for d in args.output_dirs]

    if not dirs:
        print("no output dirs found", file=sys.stderr)
        return 2

    args.out.mkdir(parents=True, exist_ok=True)
    all_rows: list[dict] = []
    for d in dirs:
        print(f"-> {d}")
        all_rows.extend(load_lashis_volumes(d))
        all_rows.extend(load_ashs_xs_volumes(d))

    if exclude:
        n_before = len(all_rows)
        all_rows = [r for r in all_rows if r["subfield"] not in exclude]
        n_dropped = n_before - len(all_rows)
        if n_dropped:
            print(f"   excluded {n_dropped} rows from subfields: {sorted(exclude)}")

    long_csv = args.out / "all_volumes_long.csv"
    per_subj_csv = args.out / "per_subject_consistency.csv"
    method_csv = args.out / "method_summary.csv"
    write_long_csv(all_rows, long_csv)
    write_per_subject_summary(all_rows, per_subj_csv)
    write_method_summary(per_subj_csv, method_csv)

    print(f"\nLong-format volumes: {long_csv}  ({len(all_rows)} rows)")
    print(f"Per-subject consistency: {per_subj_csv}")
    print(f"Method summary:          {method_csv}")
    print()
    print("=== overall mean cv_pct by method (lower = more stable) ===")
    summary = read_csv(method_csv)
    for r in summary:
        if r["scope"] == "overall":
            print(f"  {r['method']:20s}  n={r['n']:>4}  "
                  f"mean cv%={r['mean_cv_pct']:>7}  "
                  f"median cv%={r['median_cv_pct']:>7}  "
                  f"sd={r['sd_cv_pct']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
