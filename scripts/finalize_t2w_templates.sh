#!/bin/bash
# Promote per-session averaged T2w templates into the canonical BIDS T2w
# location and delete the per-run TSEs to free disk space.
#
# Run AFTER scripts/preprocess_t2w_runs.sh has produced
#   tests/data/tomcat/derivatives/templates/<sub>/<ses>/anat/<sub>_<ses>_desc-template_T2w.nii.gz
# for every session.
#
# Final layout:
#   tests/data/tomcat/<sub>/<ses>/anat/
#       <sub>_<ses>_T1w.nii.gz                              (unchanged)
#       <sub>_<ses>_acq-tse_desc-template_T2w.nii.gz        ← averaged template (raw runs deleted)
#
# Refuses to run if any session is missing a template.

set -euo pipefail

SUB="${SUB:-sub-06}"
DATA_ROOT="$(cd "$(dirname "$0")/.." && pwd)/tests/data/tomcat"
TEMPLATE_ROOT="${DATA_ROOT}/derivatives/templates"

DRY_RUN="${DRY_RUN:-0}"   # set DRY_RUN=1 to print what would happen

# 1. Verify every session has a template before deleting anything.
declare -a sessions
for SES_DIR in "${DATA_ROOT}/${SUB}/ses-"*; do
    [[ -d "${SES_DIR}" ]] || continue
    SES_BASE="$(basename "${SES_DIR}")"
    TEMPLATE="${TEMPLATE_ROOT}/${SUB}/${SES_BASE}/anat/${SUB}_${SES_BASE}_desc-template_T2w.nii.gz"
    if [[ ! -f "${TEMPLATE}" ]]; then
        echo "ABORT: missing template for ${SES_BASE}: ${TEMPLATE}" >&2
        echo "Run scripts/preprocess_t2w_runs.sh first." >&2
        exit 1
    fi
    sessions+=("${SES_BASE}")
done

if [[ ${#sessions[@]} -eq 0 ]]; then
    echo "ABORT: no sessions found under ${DATA_ROOT}/${SUB}/" >&2
    exit 1
fi

# 2. Promote each template, delete the raw runs.
for SES_BASE in "${sessions[@]}"; do
    ANAT="${DATA_ROOT}/${SUB}/${SES_BASE}/anat"
    TEMPLATE="${TEMPLATE_ROOT}/${SUB}/${SES_BASE}/anat/${SUB}_${SES_BASE}_desc-template_T2w.nii.gz"
    DEST="${ANAT}/${SUB}_${SES_BASE}_acq-tse_desc-template_T2w.nii.gz"

    echo "==================== ${SES_BASE} ===================="
    echo "  promote: ${TEMPLATE}"
    echo "       →   ${DEST}"
    if [[ "${DRY_RUN}" != "1" ]]; then
        mv "${TEMPLATE}" "${DEST}"
    fi

    for RUN_PATH in "${ANAT}/${SUB}_${SES_BASE}_run-"*"_T2w.nii.gz"; do
        [[ -f "${RUN_PATH}" ]] || continue
        echo "  delete:  ${RUN_PATH}"
        if [[ "${DRY_RUN}" != "1" ]]; then
            rm "${RUN_PATH}"
        fi
    done
done

# 3. Tidy up empty derivative directories (the templates have moved away;
#    leaving empty parents around is just clutter).
if [[ "${DRY_RUN}" != "1" ]]; then
    find "${DATA_ROOT}/derivatives" -type d -empty -delete 2>/dev/null || true
fi

echo
echo "Done. Final BIDS layout:"
find "${DATA_ROOT}/${SUB}" -type f -name '*.nii.gz' | sort
