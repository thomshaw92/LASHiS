#!/bin/bash
# Preprocess all TOMCAT subjects under tests/data/tomcat/:
# for each sub-XX, run preprocess_t2w_runs.sh (per-session AMTC2 template,
# 1 iteration as configured here) and then finalize_t2w_templates.sh
# (promote to canonical T2w, delete raw runs).
#
# Idempotent: skips sessions whose template already exists, and skips
# finalize if no per-run T2w files remain.
#
# Subjects: pass as arguments, or default to all sub-* under tests/data/tomcat.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)/tests/data/tomcat"

# 1 iteration as the user requested for the validation run.
export AMTC_ITERATIONS="${AMTC_ITERATIONS:-1}"
export AMTC_CORES="${AMTC_CORES:-4}"
export AMTC_PEXEC="${AMTC_PEXEC:-2}"

if [[ $# -eq 0 ]]; then
    SUBJECTS=()
    while IFS= read -r line; do SUBJECTS+=("$line"); done < <(cd "${DATA_ROOT}" && ls -d sub-* 2>/dev/null | sort)
else
    SUBJECTS=("$@")
fi

if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
    echo "no subjects under ${DATA_ROOT}" >&2
    exit 1
fi

echo "Subjects: ${SUBJECTS[*]}"
echo "AMTC_ITERATIONS=${AMTC_ITERATIONS} AMTC_PEXEC=${AMTC_PEXEC} AMTC_CORES=${AMTC_CORES}"

for SUB in "${SUBJECTS[@]}"; do
    echo
    echo "######################################################################"
    echo "# ${SUB} — preprocess T2w runs"
    echo "######################################################################"

    # Already-finalized subjects have no per-run T2w files, so the inner script
    # logs "no T2w runs found" per session and is a no-op. Skip them up front
    # to keep the log readable.
    if ! find "${DATA_ROOT}/${SUB}" -maxdepth 4 -name '*_run-*_T2w.nii.gz' -print -quit | grep -q .; then
        echo "  no per-run T2w files left under ${SUB}/ — already finalized, skipping"
        continue
    fi

    SUB="${SUB}" "${SCRIPT_DIR}/preprocess_t2w_runs.sh"

    echo
    echo "######################################################################"
    echo "# ${SUB} — finalize templates"
    echo "######################################################################"
    SUB="${SUB}" "${SCRIPT_DIR}/finalize_t2w_templates.sh"
done

echo
echo "All subjects processed."
