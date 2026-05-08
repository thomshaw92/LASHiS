#!/usr/bin/env python3
"""Upload per-session T2w templates to OSF project bt4ez (TOMCAT).

For each requested subject, looks for
  tests/data/tomcat/sub-XX/ses-YY/anat/sub-XX_ses-YY_acq-tse_desc-template_T2w.nii.gz
and uploads to OSF at
  TOMCAT_DIB/sub-XX/ses-YY_7T/anat/sub-XX_ses-YY_acq-tse_desc-template_T2w.nii.gz
i.e. alongside the existing T1ws and TSE runs in the BIDS layout.

The actual transfer is done by `curl` because urllib's blocking TLS
write tends to drop mid-upload for files in the hundred-MB range. We
keep urllib for the (small) JSON API calls that resolve folder IDs.

Always runs a preflight pass first that lists each target anat folder,
shows what's already there, and reports the planned action per file
(create/skip/replace). Pass --execute to actually upload.

Auth
----
Generate a personal access token at https://osf.io/settings/tokens with
the `osf.full_write` scope and export:

    export OSF_TOKEN=...

Usage
-----
    scripts/upload_tomcat_templates_osf.py --all                 # preflight only
    scripts/upload_tomcat_templates_osf.py --all --execute       # actually upload
    scripts/upload_tomcat_templates_osf.py --all --execute --replace
    scripts/upload_tomcat_templates_osf.py sub-01 sub-02 --execute
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import certifi
    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl.create_default_context()

OSF_API = "https://api.osf.io/v2"
PROJECT = "bt4ez"
TOMCAT_DIB_FOLDER_ID = "5e9be8914301660669a0ee6c"
ROOT = Path(__file__).resolve().parent.parent / "tests" / "data" / "tomcat"

TEMPLATE_NAME_FMT = "{sub}_{ses}_acq-tse_desc-template_T2w.nii.gz"


def _token() -> str:
    t = os.environ.get("OSF_TOKEN")
    if not t:
        sys.exit(
            "OSF_TOKEN not set.\n"
            "  Create a personal access token at "
            "https://osf.io/settings/tokens with the 'osf.full_write' scope, "
            "then export OSF_TOKEN=<token>."
        )
    return t


def api_get(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.api+json",
            "Authorization": f"Bearer {_token()}",
        },
    )
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


def find_child(parent_id: str, name: str, kind: str | None = None) -> dict | None:
    for child in list_folder(parent_id):
        attrs = child.get("attributes", {})
        if attrs.get("name") == name and (kind is None or attrs.get("kind") == kind):
            return child
    return None


def curl_put(url: str, local_path: Path, *, extra_headers: dict | None = None) -> None:
    """Stream a file as PUT body via curl. Retries are curl's job (--retry)."""
    if shutil.which("curl") is None:
        raise RuntimeError("curl not found on PATH (required for upload transfer)")
    headers = {
        "Authorization": f"Bearer {_token()}",
        "Content-Type": "application/octet-stream",
        **(extra_headers or {}),
    }
    cmd = [
        "curl",
        "--silent",
        "--show-error",
        "--fail-with-body",
        "--retry", "5",
        "--retry-all-errors",
        "--retry-delay", "5",
        "--max-time", "1800",
        "-X", "PUT",
        "--data-binary", f"@{local_path}",
    ]
    for k, v in headers.items():
        cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    proc = subprocess.run(cmd, capture_output=True)
    if proc.returncode != 0:
        body = proc.stdout.decode("utf-8", errors="replace")[:600]
        err = proc.stderr.decode("utf-8", errors="replace")[:600]
        raise RuntimeError(
            f"curl PUT failed (exit {proc.returncode}). stderr={err!r} body={body!r}")


# ---- preflight + upload ----------------------------------------------------

class Plan:
    """One row of the preflight plan."""
    def __init__(self, sub: str, ses: str, local: Path, anat_folder: dict | None,
                 existing: dict | None):
        self.sub = sub
        self.ses = ses
        self.local = local
        self.anat = anat_folder
        self.existing = existing

    @property
    def action(self) -> str:
        if not self.local.is_file():
            return "missing-local"
        if self.anat is None:
            return "missing-remote-anat"
        if self.existing is None:
            return "create"
        return "skip-or-replace"  # decided at execute time by --replace

    def describe(self, replace: bool) -> str:
        if self.action == "missing-local":
            return f"  {self.sub}/{self.ses}: LOCAL MISSING — {self.local.name}"
        if self.action == "missing-remote-anat":
            return f"  {self.sub}/{self.ses}: NO REMOTE anat/ folder on OSF"
        size_mb = self.local.stat().st_size / (1024 * 1024)
        if self.existing is None:
            return f"  {self.sub}/{self.ses}: CREATE   {self.local.name}  ({size_mb:.1f} MB)"
        existing_mb = self.existing["attributes"].get("size", 0) / (1024 * 1024)
        if replace:
            return (f"  {self.sub}/{self.ses}: REPLACE  {self.local.name}  "
                    f"(local {size_mb:.1f} MB ↔ remote {existing_mb:.1f} MB)")
        return (f"  {self.sub}/{self.ses}: SKIP     {self.local.name} already on OSF "
                f"({existing_mb:.1f} MB; pass --replace to overwrite)")


def build_plan(wanted_subs: list[str], by_name: dict[str, dict]) -> list[Plan]:
    plan: list[Plan] = []
    for sub in wanted_subs:
        sub_folder = by_name[sub]
        sessions = list_folder(sub_folder["id"])
        for ses_entry in sessions:
            ses_name_osf = ses_entry["attributes"]["name"]      # e.g. ses-01_7T
            ses_name = ses_name_osf.replace("_7T", "")
            local_path = (ROOT / sub / ses_name / "anat"
                          / TEMPLATE_NAME_FMT.format(sub=sub, ses=ses_name))
            # Find anat folder + existing target
            anat_entries = list_folder(ses_entry["id"])
            anat_folder = next(
                (a for a in anat_entries
                 if a["attributes"]["name"] == "anat"
                 and a["attributes"]["kind"] == "folder"),
                None,
            )
            existing = None
            if anat_folder is not None and local_path.is_file():
                existing = find_child(anat_folder["id"], local_path.name, kind="file")
            plan.append(Plan(sub, ses_name, local_path, anat_folder, existing))
    return plan


def report_plan(plan: list[Plan], replace: bool) -> dict[str, int]:
    print("\n=== preflight plan ===")
    counts = {"create": 0, "skip": 0, "replace": 0,
              "missing-local": 0, "missing-remote-anat": 0}
    for p in plan:
        print(p.describe(replace=replace))
        if p.action == "missing-local":
            counts["missing-local"] += 1
        elif p.action == "missing-remote-anat":
            counts["missing-remote-anat"] += 1
        elif p.action == "create":
            counts["create"] += 1
        elif p.action == "skip-or-replace":
            counts["replace" if replace else "skip"] += 1
    print("\nsummary:")
    for k in ("create", "replace", "skip", "missing-local", "missing-remote-anat"):
        if counts[k]:
            print(f"  {k:>22s}: {counts[k]}")
    return counts


def execute_plan(plan: list[Plan], *, replace: bool) -> dict[str, int]:
    print("\n=== executing ===")
    counts = {"uploaded": 0, "replaced": 0, "skipped": 0,
              "missing-local": 0, "missing-remote-anat": 0, "failed": 0}
    for p in plan:
        if p.action == "missing-local":
            counts["missing-local"] += 1
            continue
        if p.action == "missing-remote-anat":
            counts["missing-remote-anat"] += 1
            continue
        if p.existing is not None and not replace:
            counts["skipped"] += 1
            continue

        size_mb = p.local.stat().st_size / (1024 * 1024)
        verb = "REPLACE" if p.existing is not None else "UPLOAD"
        print(f"  {p.sub}/{p.ses}: {verb}  {p.local.name}  ({size_mb:.1f} MB)", flush=True)

        try:
            if p.existing is None:
                upload_url = p.anat["links"]["upload"] + "?" + urllib.parse.urlencode(
                    {"kind": "file", "name": p.local.name})
                curl_put(upload_url, p.local)
                counts["uploaded"] += 1
            else:
                replace_url = p.existing["links"]["upload"]
                curl_put(replace_url, p.local)
                counts["replaced"] += 1
            print(f"    -> ok")
        except Exception as exc:
            print(f"    !! FAILED: {exc}", file=sys.stderr)
            counts["failed"] += 1
            # Continue with remaining files rather than aborting the whole batch
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                 description=__doc__)
    ap.add_argument("subjects", nargs="*", help="e.g. sub-01 sub-02")
    ap.add_argument("--all", action="store_true", help="all 7 subjects")
    ap.add_argument("--execute", action="store_true",
                    help="actually upload (default = preflight only)")
    ap.add_argument("--replace", action="store_true",
                    help="overwrite remote files that already exist")
    args = ap.parse_args()

    _token()  # fail fast
    print(f"Project:    {PROJECT}", flush=True)
    print(f"Local root: {ROOT}", flush=True)
    print(f"Mode:       {'EXECUTE' if args.execute else 'preflight only'}"
          f"{' (--replace)' if args.replace else ''}", flush=True)

    print("\nresolving folder IDs from OSF...", flush=True)
    all_subs = list_folder(TOMCAT_DIB_FOLDER_ID)
    by_name = {s["attributes"]["name"]: s for s in all_subs
               if s["attributes"]["kind"] == "folder"}

    if args.all:
        wanted = sorted(by_name)
    elif args.subjects:
        wanted = args.subjects
    else:
        ap.error("pass subject IDs or --all")

    missing = [s for s in wanted if s not in by_name]
    if missing:
        print(f"Not on OSF: {missing}", file=sys.stderr)
        return 2

    plan = build_plan(wanted, by_name)
    pf = report_plan(plan, replace=args.replace)
    if pf["missing-local"] or pf["missing-remote-anat"]:
        print("\nABORTING: fix local missing files / remote folder issues "
              "above before --execute.", file=sys.stderr)
        if args.execute:
            return 3

    if not args.execute:
        print("\n(no transfer; pass --execute to upload)")
        return 0

    print()
    res = execute_plan(plan, replace=args.replace)
    print("\nresult:")
    for k in sorted(res):
        if res[k]:
            print(f"  {k:>22s}: {res[k]}")
    return 1 if res.get("failed") else 0


if __name__ == "__main__":
    sys.exit(main())
