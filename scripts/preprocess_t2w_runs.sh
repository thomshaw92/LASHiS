#!/bin/bash
# Per-session T2w preprocessing for TOMCAT subjects.
#
# Per session: hand the three raw T2w TSE runs straight to
# antsMultivariateTemplateConstruction2.sh. AMTC2's own N4 bias correction
# (-n 1) is on; no separate DenoiseImage step is run. Defaults are tuned
# for "low-effort" template construction: SyN nonlinear, 1 template
# iteration, 3 resolution levels with very few iterations per level
# (-q 30x20x4 -f 4x2x1 -s 2x1x0vox), -c 2 -j 4 = pexec on 4 cores.
#
# Outputs land under tests/data/tomcat/derivatives/templates/<sub>/<ses>/anat/.

set -euo pipefail

SUB="${SUB:-sub-06}"
DATA_ROOT="$(cd "$(dirname "$0")/.." && pwd)/tests/data/tomcat"
TEMPLATE_ROOT="${DATA_ROOT}/derivatives/templates"

# AMTC2 parameters (override via env if needed).
AMTC_CORES="${AMTC_CORES:-4}"
AMTC_PEXEC="${AMTC_PEXEC:-2}"               # -c 2 = pexec on localhost
AMTC_ITERATIONS="${AMTC_ITERATIONS:-1}"     # template-update iterations
AMTC_GRADIENT_STEP="${AMTC_GRADIENT_STEP:-0.25}"
AMTC_Q="${AMTC_Q:-30x20x4}"                 # per-level reg iterations
AMTC_F="${AMTC_F:-4x2x1}"                   # shrink factors (3 levels)
AMTC_S="${AMTC_S:-2x1x0vox}"                # smoothing kernels

if ! command -v antsMultivariateTemplateConstruction2.sh >/dev/null; then
    echo "antsMultivariateTemplateConstruction2.sh not on PATH — load ANTs first." >&2
    exit 1
fi

for SES_DIR in "${DATA_ROOT}/${SUB}/ses-"*; do
    [[ -d "${SES_DIR}" ]] || continue
    SES_BASE="$(basename "${SES_DIR}")"            # e.g. ses-01
    ANAT_DIR="${SES_DIR}/anat"
    TEMPLATE_DIR="${TEMPLATE_ROOT}/${SUB}/${SES_BASE}/anat"
    mkdir -p "${TEMPLATE_DIR}"

    RUNS=()
    echo
    echo "==================== ${SUB} ${SES_BASE} ===================="

    for RUN_PATH in "${ANAT_DIR}/${SUB}_${SES_BASE}_run-"*"_T2w.nii.gz"; do
        [[ -f "${RUN_PATH}" ]] || continue
        RUNS+=("${RUN_PATH}")
    done

    if [[ ${#RUNS[@]} -eq 0 ]]; then
        echo "  no T2w runs found in ${ANAT_DIR}; skipping" >&2
        continue
    fi

    OUT_PREFIX="${TEMPLATE_DIR}/${SUB}_${SES_BASE}_desc-template_"
    FINAL_TEMPLATE="${OUT_PREFIX}T2w.nii.gz"
    if [[ -f "${FINAL_TEMPLATE}" ]]; then
        echo "  skip (cached): ${FINAL_TEMPLATE}"
        continue
    fi

    echo "  AMTC2 (-i ${AMTC_ITERATIONS} -q ${AMTC_Q} -f ${AMTC_F} -s ${AMTC_S} -n 1) → ${OUT_PREFIX}"
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
            -m CC \
            -t SyN \
            -q "${AMTC_Q}" \
            -f "${AMTC_F}" \
            -s "${AMTC_S}" \
            "${RUNS[@]}"
    )

    # AMTC2 names its output template <prefix>template0.nii.gz; rename to a
    # BIDS-friendly suffix.
    if [[ -f "${OUT_PREFIX}template0.nii.gz" ]]; then
        mv "${OUT_PREFIX}template0.nii.gz" "${FINAL_TEMPLATE}"
        echo "  → ${FINAL_TEMPLATE}"
    elif [[ -f "${TEMPLATE_DIR}/intermediateTemplates/SyN_iteration0_${SUB}_${SES_BASE}_desc-template_template0.nii.gz" ]]; then
        # AMTC2 sometimes ends with the SyN iteration backup intact but the
        # top-level renamed/moved away (observed on -i 1 runs). The backup is
        # the same iter-0 template, so accept it as the final.
        cp "${TEMPLATE_DIR}/intermediateTemplates/SyN_iteration0_${SUB}_${SES_BASE}_desc-template_template0.nii.gz" "${FINAL_TEMPLATE}"
        echo "  → ${FINAL_TEMPLATE} (recovered from intermediateTemplates backup)"
    else
        echo "  WARNING: AMTC2 did not produce ${OUT_PREFIX}template0.nii.gz" >&2
        continue
    fi

    # Free disk: AMTC2's per-pair warps + intermediates can run ~25 GB per
    # subject at 7T. The final template is safe in ${FINAL_TEMPLATE}; nothing
    # downstream needs the work files. Set KEEP_AMTC2_WORK=1 to opt out.
    if [[ "${KEEP_AMTC2_WORK:-0}" != "1" ]]; then
        find "${TEMPLATE_DIR}" -mindepth 1 \
            ! -name "$(basename "${FINAL_TEMPLATE}")" \
            -print -delete 2>/dev/null | wc -l \
            | xargs -I{} echo "  cleaned {} AMTC2 work entries"
    fi
done

echo
echo "Done. Per-session templates:"
find "${TEMPLATE_ROOT}" -name '*_desc-template_T2w.nii.gz' | sort
