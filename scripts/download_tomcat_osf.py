#!/usr/bin/env python3
"""Download TOMCAT subjects from OSF project bt4ez into the BIDS layout
LASHiS expects under tests/data/tomcat/.

Two modes — choose by what you want to do downstream:

  --mode runs       Fetch T1w + the three raw TSE T2w runs per session.
                    Use when you want to rebuild the per-session T2w template
                    yourself (i.e. exercise the full pipeline including
                    AMTC2 averaging).
  --mode templates  Fetch T1w + the per-session averaged T2w template that
                    has been uploaded to OSF as a derivative. Skips
                    preprocessing entirely. Fastest path to validate LASHiS.
  --mode all        Both. Useful if you want raw and the canonical template.

OSF naming -> local naming:
  sub-XX/ses-YY_7T/anat/sub-XX_ses-YY_7T_T1w_defaced.nii.gz
      -> sub-XX/ses-YY/anat/sub-XX_ses-YY_T1w.nii.gz
  sub-XX/ses-YY_7T/anat/sub-XX_ses-YY_7T_T2w_run-N_tse.nii.gz
      -> sub-XX/ses-YY/anat/sub-XX_ses-YY_run-N_T2w.nii.gz                (mode=runs)
  sub-XX/ses-YY_7T/anat/sub-XX_ses-YY[_7T]_acq-tse_desc-template_T2w.nii.gz
      -> sub-XX/ses-YY/anat/sub-XX_ses-YY_acq-tse_desc-template_T2w.nii.gz (mode=templates)

Usage:
  scripts/download_tomcat_osf.py --all --mode templates   # fast path
  scripts/download_tomcat_osf.py --all                    # default mode=runs
  scripts/download_tomcat_osf.py sub-01 sub-02 --mode all
"""
from __future__ import annotations

import argparse
import json
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

try:
    import certifi
    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl.create_default_context()

OSF_API = "https://api.osf.io/v2"
PROJECT = "bt4ez"
TOMCAT_DIB_FOLDER_ID = "5e9be8914301660669a0ee6c"  # discovered via API
ROOT = Path(__file__).resolve().parent.parent / "tests" / "data" / "tomcat"


def api_get(url: str) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.api+json"})
    with urllib.request.urlopen(req, timeout=60, context=SSL_CTX) as r:
        return json.loads(r.read())


def list_folder(folder_id: str) -> list[dict]:
    items: list[dict] = []
    url = f"{OSF_API}/nodes/{PROJECT}/files/osfstorage/{folder_id}/?page%5Bsize%5D=200"
    while url:
        d = api_get(url)
        items.extend(d.get("data", []))
        url = d.get("links", {}).get("next")
    return items


def download(file_id: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        print(f"    skip (exists): {dest.name}", flush=True)
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    url = f"https://osf.io/download/{file_id}/"
    print(f"    fetch -> {dest.name}", flush=True)
    for attempt in range(3):
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=300, context=SSL_CTX) as r, open(tmp, "wb") as f:
                while True:
                    chunk = r.read(1 << 20)  # 1 MiB
                    if not chunk:
                        break
                    f.write(chunk)
            tmp.rename(dest)
            return
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            if attempt == 2:
                raise
            print(f"    retry {attempt + 1}/3 after error: {e}", flush=True)
            time.sleep(5 * (attempt + 1))


# Map OSF filename patterns to (local destination name, kind).
# kind is one of: "t1", "run", "template" — used by --mode to filter.
# Each rule: (regex, format string, kind) — first match wins.
# `_7T` is optional in the OSF template filename so that uploads with or
# without the TOMCAT-style site tag are both accepted.
RULES = [
    (re.compile(r"^(?P<sub>sub-\d+)_(?P<ses>ses-\d+)_7T_T1w_defaced\.nii\.gz$"),
     "{sub}_{ses}_T1w.nii.gz", "t1"),
    (re.compile(r"^(?P<sub>sub-\d+)_(?P<ses>ses-\d+)_7T_T2w_run-(?P<run>\d+)_tse\.nii\.gz$"),
     "{sub}_{ses}_run-{run}_T2w.nii.gz", "run"),
    (re.compile(r"^(?P<sub>sub-\d+)_(?P<ses>ses-\d+)(?:_7T)?_acq-tse_desc-template_T2w\.nii\.gz$"),
     "{sub}_{ses}_acq-tse_desc-template_T2w.nii.gz", "template"),
]

KINDS_BY_MODE = {
    "runs":      {"t1", "run"},
    "templates": {"t1", "template"},
    "all":       {"t1", "run", "template"},
}


def map_filename(name: str, allowed_kinds: set[str]) -> str | None:
    for rx, fmt, kind in RULES:
        if kind not in allowed_kinds:
            continue
        m = rx.match(name)
        if m:
            return fmt.format(**m.groupdict())
    return None


def fetch_subject(sub_folder: dict, allowed_kinds: set[str]) -> dict[str, int]:
    """Returns counts of fetched/skipped files keyed by kind for reporting."""
    sub_name = sub_folder["attributes"]["name"]
    print(f"\n=== {sub_name} ===", flush=True)
    counts = {k: 0 for k in allowed_kinds}
    sessions = list_folder(sub_folder["id"])
    for ses in sessions:
        ses_name_osf = ses["attributes"]["name"]            # e.g. ses-01_7T
        ses_name = ses_name_osf.replace("_7T", "")           # ses-01
        print(f"  {sub_name}/{ses_name_osf} -> {ses_name}", flush=True)
        anat_entries = list_folder(ses["id"])
        anat = next((a for a in anat_entries if a["attributes"]["name"] == "anat"), None)
        if anat is None:
            print(f"    no anat/ in {ses_name_osf}; skipping", flush=True)
            continue
        files = list_folder(anat["id"])
        out_dir = ROOT / sub_name / ses_name / "anat"
        for f in files:
            if f["attributes"]["kind"] != "file":
                continue
            local = map_filename(f["attributes"]["name"], allowed_kinds)
            if local is None:
                continue
            # Tally before download (download() handles existing-skip)
            for _rx, _fmt, kind in RULES:
                if local.endswith(_fmt.format(sub="X", ses="Y", run="N").split("_", 2)[-1]) and kind in allowed_kinds:
                    counts[kind] = counts.get(kind, 0) + 1
                    break
            download(f["id"], out_dir / local)
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                 description=__doc__)
    ap.add_argument("subjects", nargs="*", help="e.g. sub-01 sub-02")
    ap.add_argument("--all", action="store_true", help="download all 7 subjects")
    ap.add_argument("--mode", choices=("runs", "templates", "all"), default="runs",
                    help="what to fetch per subject (default: runs)")
    args = ap.parse_args()

    allowed = KINDS_BY_MODE[args.mode]
    print(f"Root:  {ROOT}", flush=True)
    print(f"Mode:  {args.mode}  (kinds: {sorted(allowed)})", flush=True)
    all_subs = list_folder(TOMCAT_DIB_FOLDER_ID)
    by_name = {s["attributes"]["name"]: s for s in all_subs}
    print(f"Found {len(by_name)} subjects on OSF: {sorted(by_name)}", flush=True)

    if args.all:
        wanted = sorted(by_name)
    else:
        if not args.subjects:
            ap.error("pass subject IDs or --all")
        wanted = args.subjects

    missing = [s for s in wanted if s not in by_name]
    if missing:
        print(f"Not on OSF: {missing}", file=sys.stderr)
        return 2

    grand_total: dict[str, int] = {k: 0 for k in allowed}
    for s in wanted:
        cnts = fetch_subject(by_name[s], allowed)
        for k, v in cnts.items():
            grand_total[k] = grand_total.get(k, 0) + v

    print("\nDone. Files matched per kind:")
    for k in sorted(grand_total):
        print(f"  {k:>9s}: {grand_total[k]}")
    if args.mode in ("templates", "all") and grand_total.get("template", 0) == 0:
        print("\nWARNING: --mode={} requested templates but none were found on "
              "OSF. The templates may not be uploaded yet, or they live under "
              "a non-anat subfolder.".format(args.mode), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
