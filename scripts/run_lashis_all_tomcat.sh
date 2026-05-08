#!/bin/bash
# Run LASHiS v2 on every finalized TOMCAT subject under tests/data/tomcat/
# with --fusion both and --jacobian-penalise, so the validation script
# downstream has all 4 LASHiS variants + cross-sectional ASHS to compare.
#
# Each subject's output goes to tests/output/<sub>/.
#
# Required env: ASHS_ROOT, ASHS_ATLAS  (the validation atlas dir).
#
# Usage:
#   scripts/run_lashis_all_tomcat.sh                    # all sub-* with T1w+T2w
#   scripts/run_lashis_all_tomcat.sh sub-01 sub-02      # specific subjects

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_ROOT="${REPO}/tests/data/tomcat"
OUT_ROOT="${REPO}/tests/output"
LASHIS="${LASHIS:-${REPO}/.venv/bin/lashis}"
# Fall back to whatever 'lashis' is on PATH (conda env, system pip, etc.)
# so people who installed without the project-local venv just work.
if [[ ! -x "${LASHIS}" ]]; then
    LASHIS="$(command -v lashis 2>/dev/null || true)"
fi
if [[ -z "${LASHIS}" || ! -x "${LASHIS}" ]]; then
    echo "[fatal] cannot find 'lashis' executable. Either:" >&2
    echo "  1. Install in project venv: python3 -m venv .venv && .venv/bin/pip install -e ." >&2
    echo "  2. Install in current env:  pip install -e .  (then 'lashis' must be on PATH)" >&2
    echo "  3. Override explicitly:     LASHIS=/abs/path/to/lashis ${0##*/}" >&2
    exit 1
fi
echo "[lashis] using ${LASHIS}"

: "${ASHS_ROOT:?set ASHS_ROOT}"
: "${ASHS_ATLAS:?set ASHS_ATLAS to the atlas dir}"

NPROCS="${NPROCS:-4}"
PLUGIN="${PLUGIN:-MultiProc}"

if [[ $# -eq 0 ]]; then
    SUBJECTS=()
    while IFS= read -r line; do SUBJECTS+=("$line"); done < <(cd "${DATA_ROOT}" && ls -d sub-* 2>/dev/null | sort)
else
    SUBJECTS=("$@")
fi

echo "Subjects: ${SUBJECTS[*]}"
echo "Atlas:    ${ASHS_ATLAS}"
echo "Plugin:   ${PLUGIN} (n_procs=${NPROCS})"

for SUB in "${SUBJECTS[@]}"; do
    SUB_DIR="${DATA_ROOT}/${SUB}"
    OUT="${OUT_ROOT}/${SUB}"

    # Build ordered T1w T2w T1w T2w ... list, sorted by session.
    # T2w preference order:
    #   1. <sub>_<ses>_acq-tse_desc-template_T2w.nii.gz   (canonical post-finalize)
    #   2. <sub>_<ses>_T2w.nii.gz                         (legacy fallback)
    IMAGES=()
    for SES_DIR in "${SUB_DIR}"/ses-*; do
        [[ -d "${SES_DIR}" ]] || continue
        SES="$(basename "${SES_DIR}")"
        T1="${SES_DIR}/anat/${SUB}_${SES}_T1w.nii.gz"
        T2="${SES_DIR}/anat/${SUB}_${SES}_acq-tse_desc-template_T2w.nii.gz"
        [[ -f "${T2}" ]] || T2="${SES_DIR}/anat/${SUB}_${SES}_T2w.nii.gz"
        if [[ ! -f "${T1}" || ! -f "${T2}" ]]; then
            echo "  [skip session] ${SUB}/${SES}: missing T1w or canonical T2w"
            continue
        fi
        IMAGES+=("${T1}" "${T2}")
    done

    if [[ ${#IMAGES[@]} -lt 4 ]]; then
        echo
        echo "### ${SUB}: <2 sessions ready, skipping"
        continue
    fi

    echo
    echo "######################################################################"
    echo "# ${SUB} -> ${OUT}  (n_sessions=$(( ${#IMAGES[@]} / 2 )))"
    echo "######################################################################"

    mkdir -p "${OUT_ROOT}"
    "${LASHIS}" \
        -o "${OUT}" \
        -a "${ASHS_ATLAS}" \
        --plugin "${PLUGIN}" \
        --n-procs "${NPROCS}" \
        --fusion both \
        --jacobian-penalise \
        "${IMAGES[@]}"
done

echo
echo "All LASHiS runs complete. Outputs under ${OUT_ROOT}/"
