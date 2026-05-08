#!/bin/bash
# Print per-subject progress through the LASHiS pipeline by probing
# tests/output/sub-XX/ for artefacts that mark each phase complete.
#
# Phase markers (each mapped to a presence check):
#   xs:N/3       cross-sectional ASHS per timepoint  (intermediate/crosssectional_ashs/tpNN/final/*_lfseg_heur.nii.gz)
#   sst          multimodal SST built                 (intermediate/sst/sst_T?w.nii.gz)
#   sst_ashs     ASHS run on the SST                  (intermediate/sst/ashs/final/)
#   chunk_L/R    per-side TSE chunk SST built         (intermediate/chunk_sst/{left,right}/T_template0.nii.gz)
#   jlf:N        JLF label maps per timepoint × side  (labels/jlf/tpNN_{left,right}.nii.gz)
#   maj:N        majority-vote label maps per tp×side (labels/majority/tpNN_{left,right}.nii.gz)
#   jacpen_J:N   jacpen JLF label maps                (labels/jlf_jacpen/tpNN_{left,right}.nii.gz)
#   jacpen_M:N   jacpen majority label maps           (labels/majority_jacpen/tpNN_{left,right}.nii.gz)
#   stats        volumes.csv emitted                  (stats/volumes.csv)
#   qc           NiiVue QC index built                (qc/index.html)
#
# Usage:
#   scripts/check_lashis_progress.sh                    # all sub-* under tests/output
#   scripts/check_lashis_progress.sh tests/output       # custom output root
#   scripts/check_lashis_progress.sh tests/output sub-01 sub-02

set -uo pipefail

ROOT="${1:-tests/output}"
shift 2>/dev/null || true

if [[ $# -eq 0 ]]; then
    SUBS=()
    while IFS= read -r line; do SUBS+=("$line"); done \
        < <(cd "${ROOT}" 2>/dev/null && ls -d sub-* 2>/dev/null | grep -v _nipype$ | sort)
else
    SUBS=("$@")
fi

if [[ ${#SUBS[@]} -eq 0 ]]; then
    echo "no subjects under ${ROOT}" >&2
    exit 1
fi

count() { find "$1" -name "$2" 2>/dev/null | wc -l | tr -d ' '; }
exists() { [[ -e "$1" ]] && echo "✓" || echo "·"; }

printf "%-10s %-7s %-3s %-7s %-7s %-7s %-5s %-5s %-9s %-9s %-5s %s\n" \
       "subject" "xs" "sst" "sst_ashs" "chunk_L" "chunk_R" "jlf" "maj" "jacpenJ" "jacpenM" "stats" "qc"

for sub in "${SUBS[@]}"; do
    d="${ROOT}/${sub}"
    [[ -d "$d" ]] || continue
    xs=$(count "$d/intermediate/crosssectional_ashs" "*_lfseg_heur.nii.gz")
    sst=$( [[ -f "$d/intermediate/sst/sst_T1w.nii.gz" || -f "$d/intermediate/sst/sst_T2w.nii.gz" ]] \
           && echo "✓" || echo "·" )
    sst_ashs=$(exists "$d/intermediate/sst/ashs/final")
    cL=$(exists "$d/intermediate/chunk_sst/left/T_template0.nii.gz")
    cR=$(exists "$d/intermediate/chunk_sst/right/T_template0.nii.gz")
    jlf=$(count "$d/labels/jlf" "tp*.nii.gz")
    maj=$(count "$d/labels/majority" "tp*.nii.gz")
    jpj=$(count "$d/labels/jlf_jacpen" "tp*.nii.gz")
    jpm=$(count "$d/labels/majority_jacpen" "tp*.nii.gz")
    stats=$(exists "$d/stats/volumes.csv")
    qc=$(exists "$d/qc/index.html")
    printf "%-10s %d/3      %-3s %-7s %-7s %-7s %-5s %-5s %-9s %-9s %-5s %s\n" \
           "$sub" "$xs" "$sst" "$sst_ashs" "$cL" "$cR" "$jlf" "$maj" "$jpj" "$jpm" "$stats" "$qc"
done
