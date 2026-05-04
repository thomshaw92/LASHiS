#!/bin/bash
# Per-session T2w preprocessing for the TOMCAT smoke test.
#
# For each session of sub-06:
#   1. DenoiseImage (Rician) on each T2w run.
#   2. antsMultivariateTemplateConstruction2.sh on the denoised runs
#      (-n 1 → N4 bias correction inside AMTC2, -c 2 -j 4 → pexec on 4 cores)
#      to produce one averaged per-session T2w template.
#
# Outputs go under tests/data/tomcat/derivatives/ following BIDS conventions:
#   derivatives/preprocessed/sub-06/ses-XX/anat/sub-06_ses-XX_run-N_desc-denoised_T2w.nii.gz
#   derivatives/templates/sub-06/ses-XX/anat/sub-06_ses-XX_desc-template_T2w.nii.gz

set -euo pipefail

SUB="${SUB:-sub-06}"
DATA_ROOT="$(cd "$(dirname "$0")/.." && pwd)/tests/data/tomcat"
DENOISED_ROOT="${DATA_ROOT}/derivatives/preprocessed"
TEMPLATE_ROOT="${DATA_ROOT}/derivatives/templates"

# AMTC2 parameters (override via env if needed).
AMTC_CORES="${AMTC_CORES:-4}"
AMTC_PEXEC="${AMTC_PEXEC:-2}"            # -c 2 = pexec on localhost
AMTC_ITERATIONS="${AMTC_ITERATIONS:-4}"
AMTC_GRADIENT_STEP="${AMTC_GRADIENT_STEP:-0.25}"

if ! command -v DenoiseImage >/dev/null; then
    echo "DenoiseImage not on PATH — load ANTs first." >&2
    exit 1
fi
if ! command -v antsMultivariateTemplateConstruction2.sh >/dev/null; then
    echo "antsMultivariateTemplateConstruction2.sh not on PATH — load ANTs first." >&2
    exit 1
fi

for SES_DIR in "${DATA_ROOT}/${SUB}/ses-"*; do
    [[ -d "${SES_DIR}" ]] || continue
    SES_BASE="$(basename "${SES_DIR}")"            # e.g. ses-01
    ANAT_DIR="${SES_DIR}/anat"
    DENOISED_DIR="${DENOISED_ROOT}/${SUB}/${SES_BASE}/anat"
    TEMPLATE_DIR="${TEMPLATE_ROOT}/${SUB}/${SES_BASE}/anat"
    mkdir -p "${DENOISED_DIR}" "${TEMPLATE_DIR}"

    DENOISED_RUNS=()
    echo
    echo "==================== ${SUB} ${SES_BASE} ===================="

    # 1. DenoiseImage per run
    for RUN_PATH in "${ANAT_DIR}/${SUB}_${SES_BASE}_run-"*"_T2w.nii.gz"; do
        RUN_BASE="$(basename "${RUN_PATH}" .nii.gz)"  # sub-06_ses-01_run-1_T2w
        DENOISED_PATH="${DENOISED_DIR}/${RUN_BASE/_T2w/_desc-denoised_T2w}.nii.gz"
        if [[ -f "${DENOISED_PATH}" ]]; then
            echo "  skip (cached): ${DENOISED_PATH}"
        else
            echo "  DenoiseImage  → ${DENOISED_PATH}"
            DenoiseImage -d 3 -n Rician \
                -i "${RUN_PATH}" \
                -o "${DENOISED_PATH}"
        fi
        DENOISED_RUNS+=("${DENOISED_PATH}")
    done

    if [[ ${#DENOISED_RUNS[@]} -eq 0 ]]; then
        echo "  no T2w runs found in ${ANAT_DIR}; skipping" >&2
        continue
    fi

    # 2. AMTC2 across the denoised runs of this session
    OUT_PREFIX="${TEMPLATE_DIR}/${SUB}_${SES_BASE}_desc-template_"
    FINAL_TEMPLATE="${OUT_PREFIX}T2w.nii.gz"
    if [[ -f "${FINAL_TEMPLATE}" ]]; then
        echo "  skip (cached): ${FINAL_TEMPLATE}"
        continue
    fi

    echo "  AMTC2 (-c ${AMTC_PEXEC} -j ${AMTC_CORES} -n 1) → ${OUT_PREFIX}"
    (
        cd "${TEMPLATE_DIR}"
        antsMultivariateTemplateConstruction2.sh \
            -d 3 \
            -o "${OUT_PREFIX}" \
            -i "${AMTC_ITERATIONS}" \
            -g "${AMTC_GRADIENT_STEP}" \
            -k 1 \
            -c "${AMTC_PEXEC}" \
            -j "${AMTC_CORES}" \
            -n 1 \
            -r 1 \
            "${DENOISED_RUNS[@]}"
    )

    # AMTC2 names its output template <prefix>template0.nii.gz; rename to a
    # BIDS-friendly suffix.
    if [[ -f "${OUT_PREFIX}template0.nii.gz" ]]; then
        mv "${OUT_PREFIX}template0.nii.gz" "${FINAL_TEMPLATE}"
        echo "  → ${FINAL_TEMPLATE}"
    else
        echo "  WARNING: AMTC2 did not produce ${OUT_PREFIX}template0.nii.gz" >&2
    fi
done

echo
echo "Done. Per-session templates:"
find "${TEMPLATE_ROOT}" -name '*_desc-template_T2w.nii.gz' | sort
