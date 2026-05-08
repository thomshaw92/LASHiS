#!/bin/bash
# tests/validation/run_pipeline.sh
#
# End-to-end reproducibility pipeline: download TOMCAT 7T data from OSF,
# (optionally) build per-session T2w templates, run LASHiS v2 on every
# subject with both fusion methods + Jacobian-penalised relabelling, and
# compute the cross-session volume-consistency report.
#
# Idempotent — re-running picks up where a previous invocation stopped.
#
# === Two ways to start ===
#
#   FAST PATH (recommended; skips ~2 h of preprocessing)
#       Pre-built per-session T2w templates are uploaded to OSF as
#       <sub>_<ses>_acq-tse_desc-template_T2w.nii.gz alongside the T1ws.
#       Download those + T1ws, then go straight to LASHiS:
#
#         tests/validation/run_pipeline.sh --download-templates --lashis --validate
#
#   FULL PATH (rebuild templates yourself)
#       Download raw TSE runs, run AMTC2 to average them per session,
#       finalize, then LASHiS:
#
#         tests/validation/run_pipeline.sh --download --preprocess --finalize --lashis --validate
#         tests/validation/run_pipeline.sh           # equivalent (no flags = all phases)
#
# === Phase flags ===
#
#   --download              Phase 1a: fetch T1w + raw TSE runs from OSF (full path)
#   --download-templates    Phase 1b: fetch T1w + per-session templates from OSF (fast path)
#   --preprocess            Phase 2:  AMTC2 per-session template build (full path only)
#   --finalize              Phase 3:  promote templates to canonical BIDS T2w (full path only)
#   --lashis                Phase 4:  run LASHiS v2 with --fusion both --jacobian-penalise
#   --validate              Phase 5:  cross-session %CV report
#   --all                   Phases 1 + 2 + 3 + 4 + 5 (full path)
#
# Optional positional args after the phase flags restrict the run to a
# subset of subjects (e.g. `... --preprocess sub-01 sub-02`).
#
# Required env (phase 4 only):
#   ASHS_ROOT      — root of the ASHS install (contains bin/ashs_main.sh)
#   ASHS_ATLAS     — path to ashs_atlas_*/ for the validation atlas
#
# Optional env:
#   PLUGIN         — Nipype plugin (default MultiProc)
#   NPROCS         — workers/threads (default 4)
#   AMTC_ITERATIONS, AMTC_Q, AMTC_F, AMTC_S — passed to AMTC2 (defaults
#       in scripts/preprocess_t2w_runs.sh: 1 / 30x20x4 / 4x2x1 / 2x1x0vox)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS="${REPO}/scripts"
DATA_ROOT="${REPO}/tests/data/tomcat"
OUT_ROOT="${REPO}/tests/output"
VALIDATION_DIR="${REPO}/tests/validation"
LOG_DIR="${VALIDATION_DIR}/logs"
mkdir -p "${LOG_DIR}"

DO_DOWNLOAD_RUNS=0; DO_DOWNLOAD_TEMPLATES=0
DO_PREPROCESS=0; DO_FINALIZE=0; DO_LASHIS=0; DO_VALIDATE=0
SUBJECTS=()

if [[ $# -eq 0 ]]; then
    DO_DOWNLOAD_RUNS=1; DO_PREPROCESS=1; DO_FINALIZE=1; DO_LASHIS=1; DO_VALIDATE=1
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        --download)              DO_DOWNLOAD_RUNS=1 ;;
        --download-templates)    DO_DOWNLOAD_TEMPLATES=1 ;;
        --preprocess)            DO_PREPROCESS=1 ;;
        --finalize)              DO_FINALIZE=1 ;;
        --lashis)                DO_LASHIS=1 ;;
        --validate)              DO_VALIDATE=1 ;;
        --all)                   DO_DOWNLOAD_RUNS=1; DO_PREPROCESS=1; DO_FINALIZE=1; DO_LASHIS=1; DO_VALIDATE=1 ;;
        --help|-h)
            sed -n '2,/^set -e/p' "$0" | sed 's/^# \?//' | head -60
            exit 0
            ;;
        sub-*)                   SUBJECTS+=("$1") ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

if [[ ${DO_DOWNLOAD_RUNS} -eq 1 && ${DO_DOWNLOAD_TEMPLATES} -eq 1 ]]; then
    DOWNLOAD_MODE="all"
elif [[ ${DO_DOWNLOAD_TEMPLATES} -eq 1 ]]; then
    DOWNLOAD_MODE="templates"
else
    DOWNLOAD_MODE="runs"
fi
DO_DOWNLOAD=$(( DO_DOWNLOAD_RUNS | DO_DOWNLOAD_TEMPLATES ))

# --- helper: dependency probe -------------------------------------------------
require() {
    local cmd="$1" hint="$2"
    if ! command -v "${cmd}" >/dev/null; then
        echo "[fatal] '${cmd}' not on PATH. ${hint}" >&2
        exit 1
    fi
}
PYTHON="${PYTHON:-${REPO}/.venv/bin/python}"
[[ -x "${PYTHON}" ]] || PYTHON="$(command -v python3 || true)"
[[ -n "${PYTHON}" ]] || { echo "[fatal] no python found" >&2; exit 1; }

if [[ ${DO_PREPROCESS} -eq 1 || ${DO_FINALIZE} -eq 1 || ${DO_LASHIS} -eq 1 ]]; then
    require antsMultivariateTemplateConstruction2.sh "Load ANTs (e.g. /opt/ants*/bin)."
fi
if [[ ${DO_LASHIS} -eq 1 ]]; then
    : "${ASHS_ROOT:?set ASHS_ROOT to your ASHS install (must contain bin/ashs_main.sh)}"
    : "${ASHS_ATLAS:?set ASHS_ATLAS to the unpacked ashs_atlas_*/ dir}"
    [[ -x "${ASHS_ROOT}/bin/ashs_main.sh" ]] \
        || { echo "[fatal] ${ASHS_ROOT}/bin/ashs_main.sh not executable" >&2; exit 1; }
fi

stamp() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
banner() {
    printf '\n========================================================================\n'
    printf '== %s\n' "$1"
    printf '========================================================================\n'
}

# --- input verification -------------------------------------------------------

# Resolve the list of subjects to verify: explicit SUBJECTS arg if given,
# otherwise every sub-* directory found locally under tests/data/tomcat/.
_resolve_subjects() {
    local -a subs=()
    if [[ ${#SUBJECTS[@]} -gt 0 ]]; then
        subs=("${SUBJECTS[@]}")
    else
        while IFS= read -r line; do subs+=("$line"); done \
            < <(cd "${DATA_ROOT}" 2>/dev/null && ls -d sub-* 2>/dev/null | sort)
    fi
    printf '%s\n' "${subs[@]+"${subs[@]}"}"
}

# Per-mode expected layout per session under sub-XX/ses-YY/anat/.
# Args:  $1 = mode label for messaging ("templates" | "runs" | "lashis-ready")
# Returns 0 if every subject × session has the required files; otherwise
# prints a per-session breakdown and returns 1.
verify_inputs() {
    local mode="$1"
    local -a subs
    while IFS= read -r line; do
        [[ -n "${line}" ]] && subs+=("${line}")
    done < <(_resolve_subjects)

    if [[ ${#subs[@]} -eq 0 ]]; then
        echo "[verify] no subjects found under ${DATA_ROOT}/" >&2
        return 1
    fi

    local total_ok=0 total_sessions=0 missing=0
    echo "[verify mode=${mode}] checking ${#subs[@]} subjects under ${DATA_ROOT}/"
    for s in "${subs[@]}"; do
        local sub_ok=0 sub_total=0
        local -a issues=()
        for ses_dir in "${DATA_ROOT}/${s}"/ses-*; do
            [[ -d "${ses_dir}" ]] || continue
            local ses="$(basename "${ses_dir}")"
            sub_total=$((sub_total + 1))
            total_sessions=$((total_sessions + 1))

            local anat="${ses_dir}/anat"
            local t1="${anat}/${s}_${ses}_T1w.nii.gz"
            local need=()
            [[ -f "${t1}" ]] || need+=("T1w")

            case "${mode}" in
                templates|lashis-ready)
                    local t2="${anat}/${s}_${ses}_acq-tse_desc-template_T2w.nii.gz"
                    [[ -f "${t2}" || -f "${anat}/${s}_${ses}_T2w.nii.gz" ]] \
                        || need+=("acq-tse_desc-template_T2w")
                    ;;
                runs)
                    local nruns
                    nruns=$(find "${anat}" -maxdepth 1 \
                                -name "${s}_${ses}_run-*_T2w.nii.gz" 2>/dev/null \
                                | wc -l | tr -d ' ')
                    [[ "${nruns}" -ge 3 ]] || need+=("3xrun-N_T2w (have ${nruns})")
                    ;;
                *)
                    echo "[verify] unknown mode: ${mode}" >&2
                    return 2
                    ;;
            esac

            if [[ ${#need[@]} -eq 0 ]]; then
                sub_ok=$((sub_ok + 1))
                total_ok=$((total_ok + 1))
            else
                issues+=("${ses}: missing ${need[*]}")
                missing=$((missing + 1))
            fi
        done
        if [[ ${#issues[@]} -eq 0 ]]; then
            printf "  %s : %d/%d sessions OK\n" "${s}" "${sub_ok}" "${sub_total}"
        else
            printf "  %s : %d/%d sessions OK — issues:\n" "${s}" "${sub_ok}" "${sub_total}"
            for line in "${issues[@]}"; do
                printf "      %s\n" "${line}"
            done
        fi
    done

    echo "[verify] total: ${total_ok}/${total_sessions} sessions complete"
    if [[ ${missing} -gt 0 ]]; then
        echo "[verify] FAIL: ${missing} session(s) missing required files for mode='${mode}'" >&2
        return 1
    fi
    echo "[verify] OK"
    return 0
}

# --- phases -------------------------------------------------------------------

if [[ ${DO_DOWNLOAD} -eq 1 ]]; then
    banner "Phase 1/5  download TOMCAT subjects from OSF (mode=${DOWNLOAD_MODE})"
    LOG="${LOG_DIR}/01_download.$(stamp).log"
    if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
        "${PYTHON}" "${SCRIPTS}/download_tomcat_osf.py" --mode "${DOWNLOAD_MODE}" --all 2>&1 | tee "${LOG}"
    else
        "${PYTHON}" "${SCRIPTS}/download_tomcat_osf.py" --mode "${DOWNLOAD_MODE}" "${SUBJECTS[@]}" 2>&1 | tee "${LOG}"
    fi

    banner "post-download verification (mode=${DOWNLOAD_MODE})"
    if [[ "${DOWNLOAD_MODE}" == "all" ]]; then
        # 'all' mode: both runs and templates were requested. Templates are
        # the lashis-relevant artefact, so verify those; raw runs are a bonus.
        verify_inputs "templates"
    else
        verify_inputs "${DOWNLOAD_MODE}"
    fi
fi

if [[ ${DO_PREPROCESS} -eq 1 ]]; then
    banner "Phase 2/5  AMTC2 per-session T2w template build (no separate denoise)"
    LOG="${LOG_DIR}/02_preprocess.$(stamp).log"
    # ${arr[@]+"${arr[@]}"} is the bash-3.2-safe idiom for "expand array if
    # set, otherwise nothing" — needed because macOS /bin/bash + set -u errors
    # on "${arr[@]}" when arr is empty.
    "${SCRIPTS}/preprocess_all_tomcat.sh" ${SUBJECTS[@]+"${SUBJECTS[@]}"} 2>&1 | tee "${LOG}"
fi

if [[ ${DO_FINALIZE} -eq 1 ]]; then
    banner "Phase 3/5  promote per-session templates → canonical BIDS T2w; drop raw runs"
    LOG="${LOG_DIR}/03_finalize.$(stamp).log"
    if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
        ALL=()
        while IFS= read -r line; do ALL+=("$line"); done < <(cd "${DATA_ROOT}" && ls -d sub-* 2>/dev/null | sort)
    else
        ALL=("${SUBJECTS[@]}")
    fi
    {
        for s in "${ALL[@]}"; do
            echo
            echo "=== finalize ${s} ==="
            # finalize is a no-op once raw runs are gone, so skip then
            if find "${DATA_ROOT}/${s}" -name '*_run-*_T2w.nii.gz' -print -quit 2>/dev/null | grep -q .; then
                SUB="${s}" "${SCRIPTS}/finalize_t2w_templates.sh"
            else
                echo "  ${s} has no per-run T2w files left; already finalized"
            fi
        done
    } 2>&1 | tee "${LOG}"
fi

if [[ ${DO_LASHIS} -eq 1 ]]; then
    banner "pre-LASHiS verification (T1w + per-session T2w required)"
    if ! verify_inputs "lashis-ready"; then
        echo "[fatal] inputs not ready; refusing to start LASHiS." >&2
        exit 1
    fi

    banner "Phase 4/5  run LASHiS v2 (--fusion both --jacobian-penalise)"
    LOG="${LOG_DIR}/04_lashis.$(stamp).log"
    "${SCRIPTS}/run_lashis_all_tomcat.sh" ${SUBJECTS[@]+"${SUBJECTS[@]}"} 2>&1 | tee "${LOG}"
fi

if [[ ${DO_VALIDATE} -eq 1 ]]; then
    banner "Phase 5/5  cross-session volume consistency"
    LOG="${LOG_DIR}/05_validate.$(stamp).log"
    "${PYTHON}" "${SCRIPTS}/validate_volume_consistency.py" \
        --root "${OUT_ROOT}" --auto \
        --out "${VALIDATION_DIR}/results" \
        2>&1 | tee "${LOG}"
fi

echo
echo "Done. Logs: ${LOG_DIR}/"
echo "Validation CSVs: ${VALIDATION_DIR}/results/"
