"""Per-timepoint, per-side subfield volume stats (LASHiS.sh:1112-1141).

Runs ``c3d <labels> -dup -lstat`` to extract per-label statistics, then writes
the 5-column ``<basename>_<side>_TimePoint_<i>_stats.txt`` matching the
schema documented in README:

    <basename> <side> <subfield_name> <z_extent> <volume_mm3>

Column indices (7 = volume, 10 = z-extent) are taken verbatim from
LASHiS.sh:1131,1134 — they match the c3d release shipped with ASHS but are
worth flagging if a future c3d changes its lstat output format.
"""
from __future__ import annotations

from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import (
    per_timepoint_stats_dir,
    snaplabels_path,
    stats_dir,
)
from .chunk_sst import SIDES


def _convert_snaplabels(atlas_dir: str, output_path: str) -> str:
    """Replicate the awk one-liner at LASHiS.sh:1028-1030.

    Reads ``<atlas_dir>/snap/snaplabels.txt`` (ITK-SNAP format), drops label 0,
    underscores spaces in the label name, writes ``<id> <name>`` per line.
    """
    from pathlib import Path as _P

    src = _P(atlas_dir) / "snap" / "snaplabels.txt"
    lines: list[str] = []
    for raw in src.read_text().splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        # ITK-SNAP format: id R G B A vis idx_vis "name"
        if '"' not in s:
            continue
        head, _, rest = s.partition('"')
        # rest looks like:  Cornu Ammonis 1"...
        name = rest.split('"', 1)[0]
        try:
            label_id = int(head.split()[0])
        except (IndexError, ValueError):
            continue
        if label_id <= 0:
            continue
        lines.append(f"{label_id} {'_'.join(name.split())}")

    out = _P(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n")
    return str(out)


def _stats_for_timepoint(
    side: str,
    method_subdir: str,
    timepoint_idx: int,
    basename: str,
    warped_labels: str,
    snaplabels_file: str,
    output_dir: str,
) -> tuple[str, str]:
    """Run c3d -lstat and parse → per-(timepoint, side, method) stats file.

    ``output_dir`` is the per_timepoint stats dir; we further subdir by method
    so output paths are ``stats/per_timepoint/<method>/<basename>_<side>_TimePoint_<i>_stats.txt``.
    """
    import os
    import subprocess
    from pathlib import Path as _P

    out_dir = _P(output_dir) / method_subdir
    raw_dir = out_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_stats = raw_dir / (
        f"{basename}_{side}_TimePoint_{timepoint_idx}_lstat_raw.txt"
    )
    final_stats = out_dir / f"{basename}_{side}_TimePoint_{timepoint_idx}_stats.txt"

    import platform
    ashs_root = os.environ.get("ASHS_ROOT", "")
    c3d = "c3d"
    if ashs_root:
        # Prefer ASHS's bundled c3d at ext/<platform>/bin/c3d. ASHS clones
        # may include BOTH Linux and Darwin subdirs; picking the platform's
        # own subdir avoids "Exec format error" from running a Linux binary
        # on macOS (or vice versa). Falls back to PATH if neither is present.
        sysname = platform.system()  # "Darwin" or "Linux"
        preferred = _P(ashs_root) / "ext" / sysname / "bin" / "c3d"
        if preferred.is_file():
            c3d = str(preferred)
        else:
            for cand in _P(ashs_root).glob("ext/*/bin/c3d"):
                if cand.is_file():
                    c3d = str(cand)
                    break

    try:
        raw = subprocess.run(
            [c3d, warped_labels, "-dup", "-lstat"],
            check=True, capture_output=True, text=True,
        ).stdout
    except subprocess.CalledProcessError as exc:
        stderr_tail = "\n".join((exc.stderr or "").splitlines()[-20:]) or "<empty>"
        raise RuntimeError(
            f"c3d -lstat failed on {warped_labels} (exit {exc.returncode})\n"
            f"--- stderr ---\n{stderr_tail}"
        ) from exc
    raw_stats.write_text(raw)

    # Parse "<id> <name>" pairs from the converted snaplabels.
    pairs: list[tuple[int, str]] = []
    for line in _P(snaplabels_file).read_text().splitlines():
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        try:
            pairs.append((int(parts[0]), parts[1]))
        except ValueError:
            continue

    # c3d -lstat produces a header line followed by one line per label.
    # LASHiS uses awk col 7 = volume (mm^3), col 10 = z-axis extent.
    # We follow the same column convention.
    by_id: dict[int, list[str]] = {}
    for line in raw.splitlines():
        parts = line.split()
        if not parts:
            continue
        try:
            lid = int(parts[0])
        except ValueError:
            continue
        by_id[lid] = parts

    out_lines: list[str] = []
    for label_id, name in pairs:
        cols = by_id.get(label_id)
        if not cols or len(cols) < 10:
            continue
        nbody = cols[9]   # awk $10 → 0-indexed 9
        vsub = cols[6]    # awk $7  → 0-indexed 6
        out_lines.append(f"{basename} {side} {name} {nbody} {vsub}")

    final_stats.write_text("\n".join(out_lines) + "\n")
    return str(final_stats), str(raw_stats)


def _aggregate_long_csv(
    stats_left_jlf: list[str],
    stats_right_jlf: list[str],
    stats_left_majority: list[str],
    stats_right_majority: list[str],
    jac_left_jlf: list[str],
    jac_right_jlf: list[str],
    jac_left_majority: list[str],
    jac_right_majority: list[str],
    jacpen_left_jlf: list[str],
    jacpen_right_jlf: list[str],
    jacpen_left_majority: list[str],
    jacpen_right_majority: list[str],
    icv_volumes: list[float],
    consistency_threshold: float,
    output_path: str,
) -> tuple[str, str, str, str, str, str]:
    """Aggregate per-(method, side, timepoint) stats files into CSVs.

    ``stats_*`` lists carry per-tp paths to the c3d-derived stats text
    (``<basename> <side> <subfield> <z_extent> <volume_mm3>``). ``jac_*``
    lists carry per-tp paths to the Jacobian-derived volumes text
    (``<id> <subfield> <volume_mm3>``). Pass [] for methods not requested.

    ``icv_volumes`` is a list aligned with timepoints carrying ICV from
    ASHS's per-tp ``final/<basename>_icv.txt``. Pass [] to skip
    normalization columns.

    Produces (in this order):
        volumes.csv          long-format segmentation volumes
        asymmetry.csv        per-tp L/R asymmetry index
        longitudinal.csv     change vs session 0
        jacobian_volumes.csv long-format Jacobian-predicted volumes
        consistency.csv      side-by-side seg-vs-Jacobian + flag_unreliable
    """
    from pathlib import Path as _P

    icv_enabled = bool(icv_volumes)
    jac_enabled = any((jac_left_jlf, jac_right_jlf,
                       jac_left_majority, jac_right_majority))
    inputs = [
        ("joint", "left", stats_left_jlf),
        ("joint", "right", stats_right_jlf),
        ("majorityvoting", "left", stats_left_majority),
        ("majorityvoting", "right", stats_right_majority),
    ]

    # ---- volumes.csv (long format, one row per tp × side × method × sf) ---
    vol_header = ["subject", "session_idx", "side", "fusion_method",
                  "subfield", "z_extent", "volume_mm3"]
    if icv_enabled:
        vol_header += ["icv_mm3", "volume_mm3_norm"]
    rows: list[str] = [",".join(vol_header)]

    # by_key: (method, tp, side, subfield) -> (subject, volume)
    by_key: dict[tuple[str, int, str, str], tuple[str, float]] = {}
    subject = ""
    for method, side, stats_list in inputs:
        if not stats_list:
            continue
        for tp_idx, fp in enumerate(stats_list):
            icv = icv_volumes[tp_idx] if icv_enabled else float("nan")
            for line in _P(fp).read_text().splitlines():
                parts = line.split()
                if len(parts) != 5:
                    continue
                subject, _side_in_file, subfield, z_extent, vol = parts
                try:
                    vol_f = float(vol)
                except ValueError:
                    continue
                row = [subject, str(tp_idx), side, method, subfield, z_extent, vol]
                if icv_enabled:
                    norm = (vol_f / icv) if icv > 0 else float("nan")
                    norm_str = f"{norm:.6e}" if norm == norm else "NaN"
                    row += [f"{icv:.3f}", norm_str]
                rows.append(",".join(row))
                by_key[(method, tp_idx, side, subfield)] = (subject, vol_f)

    out = _P(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(rows) + "\n")

    # ---- asymmetry.csv ----------------------------------------------------
    asym_rows = [
        "subject,session_idx,fusion_method,subfield,"
        "left_volume_mm3,right_volume_mm3,asymmetry_index"
    ]
    seen_methods = sorted({k[0] for k in by_key})
    seen_subfields = sorted({k[3] for k in by_key})
    seen_tps = sorted({k[1] for k in by_key})
    for method in seen_methods:
        for tp in seen_tps:
            for sf in seen_subfields:
                l = by_key.get((method, tp, "left", sf))
                r = by_key.get((method, tp, "right", sf))
                if l is None or r is None:
                    continue
                lv, rv = l[1], r[1]
                denom = (lv + rv) / 2 if (lv + rv) > 0 else float("nan")
                ai = (lv - rv) / denom if denom == denom else float("nan")
                asym_rows.append(
                    f"{l[0]},{tp},{method},{sf},{lv:.3f},{rv:.3f},{ai:.4f}"
                )
    asym_path = out.with_name("asymmetry.csv")
    asym_path.write_text("\n".join(asym_rows) + "\n")

    # ---- longitudinal.csv -------------------------------------------------
    long_rows = [
        "subject,session_idx,side,fusion_method,subfield,"
        "volume_mm3,delta_vs_baseline,percent_change_vs_baseline"
    ]
    for method in seen_methods:
        for side in ("left", "right"):
            for sf in seen_subfields:
                base = by_key.get((method, 0, side, sf))
                if base is None:
                    continue
                base_v = base[1]
                for tp in seen_tps:
                    rec = by_key.get((method, tp, side, sf))
                    if rec is None:
                        continue
                    v = rec[1]
                    delta = v - base_v
                    pct_str = f"{(delta / base_v * 100.0):.3f}" if base_v > 0 else "NaN"
                    long_rows.append(
                        f"{rec[0]},{tp},{side},{method},{sf},"
                        f"{v:.3f},{delta:.3f},{pct_str}"
                    )
    long_path = out.with_name("longitudinal.csv")
    long_path.write_text("\n".join(long_rows) + "\n")

    # ---- Jacobian-penalised volumes ----------------------------------------
    # jacpen_*.csv: same long format as volumes.csv but for the
    # Jacobian-penalised label maps (labels/<method>_jacpen/).
    jacpen_inputs = [
        ("joint", "left", jacpen_left_jlf),
        ("joint", "right", jacpen_right_jlf),
        ("majorityvoting", "left", jacpen_left_majority),
        ("majorityvoting", "right", jacpen_right_majority),
    ]
    jacpen_enabled = any(p for _, _, p in jacpen_inputs)
    jacpen_path = out.with_name("jacpen_volumes.csv")
    jacpen_rows = ["subject,session_idx,side,fusion_method,subfield,z_extent,volume_mm3"]
    if jacpen_enabled:
        for method, side, paths in jacpen_inputs:
            if not paths:
                continue
            for tp_idx, fp in enumerate(paths):
                for line in _P(fp).read_text().splitlines():
                    parts = line.split()
                    if len(parts) != 5:
                        continue
                    subj, _s, subfield, z_extent, vol = parts
                    jacpen_rows.append(
                        f"{subj},{tp_idx},{side},{method},{subfield},{z_extent},{vol}"
                    )
    jacpen_path.write_text("\n".join(jacpen_rows) + "\n")

    # ---- Jacobian volumes + consistency check ------------------------------
    jac_inputs = [
        ("joint", "left", jac_left_jlf),
        ("joint", "right", jac_right_jlf),
        ("majorityvoting", "left", jac_left_majority),
        ("majorityvoting", "right", jac_right_majority),
    ]
    # Index: (method, tp, side, subfield) -> jacobian_volume_mm3
    jac_by_key: dict[tuple[str, int, str, str], float] = {}
    if jac_enabled:
        for method, side, paths in jac_inputs:
            if not paths:
                continue
            for tp_idx, fp in enumerate(paths):
                for line in _P(fp).read_text().splitlines():
                    parts = line.split()
                    if len(parts) != 3:
                        continue
                    _label_id, name, vol = parts
                    try:
                        jac_by_key[(method, tp_idx, side, name)] = float(vol)
                    except ValueError:
                        pass

    jac_path = out.with_name("jacobian_volumes.csv")
    jac_rows = ["subject,session_idx,side,fusion_method,subfield,jacobian_volume_mm3"]
    for (method, tp, side, sf), vol in sorted(jac_by_key.items()):
        seg = by_key.get((method, tp, side, sf))
        subj = seg[0] if seg else (subject or "")
        jac_rows.append(f"{subj},{tp},{side},{method},{sf},{vol:.3f}")
    jac_path.write_text("\n".join(jac_rows) + "\n")

    # consistency.csv: pair seg + jacobian volumes; flag if change rates diverge
    consistency_path = out.with_name("consistency.csv")
    cons_rows = [
        "subject,session_idx,side,fusion_method,subfield,"
        "seg_volume_mm3,jacobian_volume_mm3,ratio,"
        "seg_change_pct,jacobian_change_pct,discrepancy_pct,flag_unreliable"
    ]
    if jac_enabled:
        # Per (method, side, subfield), gather all timepoints; compute
        # baseline (session 0) for both seg and jacobian, then per-tp deltas.
        keys_by_msf = {}
        for (m, tp, s, sf), _v in by_key.items():
            keys_by_msf.setdefault((m, s, sf), set()).add(tp)
        for (method, side, sf), tps in keys_by_msf.items():
            seg_base = by_key.get((method, 0, side, sf))
            jac_base = jac_by_key.get((method, 0, side, sf))
            for tp in sorted(tps):
                seg = by_key.get((method, tp, side, sf))
                jac = jac_by_key.get((method, tp, side, sf))
                if seg is None or jac is None:
                    continue
                seg_v, jac_v = seg[1], jac
                ratio = (seg_v / jac_v) if jac_v > 0 else float("nan")
                if seg_base and jac_base and seg_base[1] > 0 and jac_base > 0:
                    seg_chg = (seg_v - seg_base[1]) / seg_base[1] * 100.0
                    jac_chg = (jac_v - jac_base) / jac_base * 100.0
                    disc = seg_chg - jac_chg
                    flag = abs(disc) > (consistency_threshold * 100.0)
                else:
                    seg_chg = jac_chg = disc = float("nan")
                    flag = False

                def _f(x):
                    return f"{x:.3f}" if x == x else "NaN"  # NaN check via x!=x

                cons_rows.append(
                    f"{seg[0]},{tp},{side},{method},{sf},"
                    f"{seg_v:.3f},{jac_v:.3f},{_f(ratio)},"
                    f"{_f(seg_chg)},{_f(jac_chg)},{_f(disc)},{int(flag)}"
                )
    consistency_path.write_text("\n".join(cons_rows) + "\n")

    return (str(out), str(asym_path), str(long_path),
            str(jac_path), str(consistency_path), str(jacpen_path))


def build_aggregate_stats(config: LashisConfig) -> pe.Node:
    """Function node aggregating per-(method, side) stats into long-format CSVs.

    Workflow callers populate ``stats_files`` with one MapNode-output list per
    (method, side) combination, paired index-aligned with ``fusion_methods``
    and ``sides`` lists.
    """
    output_dir = stats_dir(config.output_prefix)
    output_dir.mkdir(parents=True, exist_ok=True)

    node = pe.Node(
        Function(
            input_names=[
                "stats_left_jlf", "stats_right_jlf",
                "stats_left_majority", "stats_right_majority",
                "jac_left_jlf", "jac_right_jlf",
                "jac_left_majority", "jac_right_majority",
                "jacpen_left_jlf", "jacpen_right_jlf",
                "jacpen_left_majority", "jacpen_right_majority",
                "icv_volumes", "consistency_threshold", "output_path",
            ],
            output_names=[
                "csv_path", "asymmetry_path", "longitudinal_path",
                "jacobian_csv_path", "consistency_csv_path",
                "jacpen_csv_path",
            ],
            function=_aggregate_long_csv,
        ),
        name="aggregate_stats_csv",
    )
    node.inputs.output_path = str(output_dir / "volumes.csv")
    node.inputs.consistency_threshold = config.jacobian_threshold
    # Default empties so unwired (method, side) inputs don't fail trait check.
    for slot in (
        "stats_left_jlf", "stats_right_jlf",
        "stats_left_majority", "stats_right_majority",
        "jac_left_jlf", "jac_right_jlf",
        "jac_left_majority", "jac_right_majority",
        "jacpen_left_jlf", "jacpen_right_jlf",
        "jacpen_left_majority", "jacpen_right_majority",
    ):
        setattr(node.inputs, slot, [])
    node.inputs.icv_volumes = []
    return node


def build_stats(
    config: LashisConfig, methods: list[str],
) -> tuple[pe.Node, dict[tuple[str, str], pe.MapNode]]:
    """Return (snaplabels_node, {(side, method): stats_mapnode}).

    The snaplabels conversion is done once and shared across all stats nodes.
    ``methods`` is the list of antsJointLabelFusion ``-x`` values being run
    (``joint`` and/or ``majorityvoting``).
    """
    from .jlf import METHOD_TO_SUBDIR

    per_tp_dir = per_timepoint_stats_dir(config.output_prefix)
    per_tp_dir.mkdir(parents=True, exist_ok=True)

    snaplabels_node = pe.Node(
        Function(
            input_names=["atlas_dir", "output_path"],
            output_names=["snaplabels_file"],
            function=_convert_snaplabels,
        ),
        name="convert_snaplabels",
    )
    snaplabels_node.inputs.atlas_dir = str(config.atlas)
    snaplabels_node.inputs.output_path = str(snaplabels_path(config.output_prefix))

    n_tp = len(config.timepoints)
    basenames = [tp.subject_id for tp in config.timepoints]

    nodes: dict[tuple[str, str], pe.MapNode] = {}
    for method in methods:
        method_subdir = METHOD_TO_SUBDIR[method]
        for side in SIDES:
            node = pe.MapNode(
                Function(
                    input_names=[
                        "side", "method_subdir", "timepoint_idx", "basename",
                        "warped_labels", "snaplabels_file", "output_dir",
                    ],
                    output_names=["stats_file", "raw_stats_file"],
                    function=_stats_for_timepoint,
                ),
                name=f"stats_{side}_{method_subdir}",
                iterfield=["timepoint_idx", "basename", "warped_labels"],
            )
            node.inputs.side = side
            node.inputs.method_subdir = method_subdir
            node.inputs.timepoint_idx = list(range(n_tp))
            node.inputs.basename = basenames
            node.inputs.output_dir = str(per_tp_dir)
            nodes[(side, method)] = node
    return snaplabels_node, nodes
