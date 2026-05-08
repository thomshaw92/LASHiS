# LASHiS v2 — TOMCAT cross-session validation

End-to-end reproducibility test for LASHiS v2: download the TOMCAT 7T
data + pre-built per-session T2w templates from OSF, run LASHiS on every
subject with both fusion methods + Jacobian-penalised relabelling, and
report cross-session volume-consistency CSVs.

## What this test is, and what it isn't

**Goal:** confirm LASHiS v2 produces sensible hippocampal-subfield
segmentations on real 7T MRI data, and quantify how *consistent* each of
its segmentation methods is across repeat scans of the same subject.

**Why TOMCAT:** the
[TOMCAT dataset](https://osf.io/bt4ez/overview/TOMCAT_DIB/) is a
test–retest 7T study of seven young, neurologically healthy adults
(`sub-01`…`sub-07`), each scanned three times within a short interval.
True biological volume change between sessions is small, so the
between-session spread for any given subject × subfield is dominated by
**pipeline noise**. A pipeline whose volumes wobble more across scans of
the same person is a noisier pipeline.

**What this is *not*:** the variance-ratio analysis from the original
[LASHiS paper](https://doi.org/10.1016/j.neuroimage.2020.117374) (Stan
hierarchical Bayesian LME on ADNI). That experiment needs ~125 ADNI
subjects across multiple visits and lives in `paper/`. This test is the
pragmatic "does v2 work and is it stable on healthy controls?" check.

## What gets compared

For each (subject, side, subfield), we compute the per-session volume
under five segmentation strategies and report the coefficient of
variation across sessions:

| Method            | What produces it                                                            |
|-------------------|------------------------------------------------------------------------------|
| `ashs_xs`         | Cross-sectional ASHS run independently per timepoint (no longitudinal info) |
| `jlf`             | LASHiS antsJointLabelFusion (Wang & Yushkevich 2013, weighted voting)       |
| `majority`        | LASHiS majority voting (legacy v1 fusion)                                   |
| `jlf_jacpen`      | `jlf` + Jacobian-penalised relabelling (rank-weighted threshold pull)       |
| `majority_jacpen` | `majority` + Jacobian-penalised relabelling                                 |

`ashs_xs` is the natural baseline: it ignores the SST entirely. The
other four are different choices LASHiS v2 offers when fusing the
SST-warped atlases back to each timepoint.

## Prerequisites

You need:

1. **ANTs** ≥ 2.5.x on `PATH` (`antsJointLabelFusion.sh`,
   `antsRegistration`, `antsApplyTransforms`, `c3d`).
2. **ASHS** install — `$ASHS_ROOT/bin/ashs_main.sh` must exist and run.
3. **An ASHS atlas** for the modality you're segmenting. We use the UMC
   Utrecht 7T atlas (`ashs_atlas_umcutrecht_7t_20170810/`), available at
   <https://www.nitrc.org/projects/ashs/>. Drop the unpacked directory
   anywhere and point `$ASHS_ATLAS` at it.
4. **Python venv with LASHiS installed** — from the repo root:
   ```bash
   python3 -m venv .venv
   .venv/bin/pip install -e .
   .venv/bin/pip install certifi   # for the OSF downloader on Python 3.14+
   ```
5. ~30 GB of free disk for the templates + LASHiS intermediates × seven
   subjects.

Set the env vars and you're ready:

```bash
export ASHS_ROOT=/path/to/ashs
export ASHS_ATLAS=/path/to/ashs_atlas_umcutrecht_7t_20170810
```

## Running the pipeline

```bash
tests/validation/run_pipeline.sh --download-templates --lashis --validate
```

That fetches the T1ws + per-session averaged T2w templates from OSF
(named `<sub>_<ses>_acq-tse_desc-template_T2w.nii.gz`), runs LASHiS v2
on every subject, and writes the consistency report. Same command for
the whole pipeline; re-running picks up where any phase stopped.

To restrict to a subject subset, append IDs:

```bash
tests/validation/run_pipeline.sh --download-templates --lashis --validate sub-01 sub-02
```

Per-phase flags exist if you need to run a stage on its own
(`--download-templates`, `--lashis`, `--validate`). Logs land in
`tests/validation/logs/NN_<phase>.<UTC-timestamp>.log`. Validation CSVs
land in `tests/validation/results/`.

> **Note:** The pipeline can also rebuild the templates from raw TSE runs
> (`--download --preprocess --finalize ...`), but the templates have
> already been built and uploaded to OSF, so the fast path above is what
> you want unless you've changed the preprocessing parameters.

## What each phase does

### Phase 1 — download templates + T1ws
[scripts/download_tomcat_osf.py](../../scripts/download_tomcat_osf.py)

Walks the OSF API for project `bt4ez`, fetches the seven subjects from
`TOMCAT_DIB/`, and lays them out in the BIDS structure LASHiS expects:

```
tests/data/tomcat/
└── sub-XX/ses-YY/anat/
    ├── sub-XX_ses-YY_T1w.nii.gz                          # MP2RAGE-style, defaced
    └── sub-XX_ses-YY_acq-tse_desc-template_T2w.nii.gz    # averaged across the 3 TSE runs
```

The OSF source names aren't strictly BIDS — T1ws are
`sub-XX_ses-YY_7T_T1w_defaced.nii.gz` and TSE runs are
`sub-XX_ses-YY_7T_T2w_run-N_tse.nii.gz`. The download script renames on
fetch so the local copy is BIDS-clean. Existing files are skipped, so
the download is restartable.

### Phase 2 — LASHiS v2
[scripts/run_lashis_all_tomcat.sh](../../scripts/run_lashis_all_tomcat.sh)

For every subject with ≥ 2 sessions:

```
lashis -o tests/output/sub-XX -a $ASHS_ATLAS \
    --plugin $PLUGIN --n-procs $NPROCS \
    --fusion both --jacobian-penalise \
    <T1_ses-01> <T2_ses-01> <T1_ses-02> <T2_ses-02> ...
```

`--fusion both` runs JLF twice (joint + majority); `--jacobian-penalise`
adds the rank-weighted relabelling on top of each. End-state per
subject:

```
tests/output/sub-XX/
├── stats/
│   ├── volumes.csv                   long-format jlf + majority volumes
│   ├── jacpen_volumes.csv            same schema, jacpen variants
│   ├── longitudinal.csv              %change vs baseline
│   ├── consistency.csv               seg-vs-Jacobian sanity check
│   └── asymmetry.csv
├── labels/{jlf,majority,jlf_jacpen,majority_jacpen}/tp{NN}_{left,right}.nii.gz
├── posteriors/{jlf,majority}/<side>_<NNNN>.nii.gz
├── qc/                               NiiVue HTML viewers per timepoint × method × side
└── intermediate/
    ├── crosssectional_ashs/tp{NN}/   independent ASHS per timepoint (the ashs_xs baseline)
    ├── sst/                          multimodal SST + SST-ASHS
    ├── chunk_sst/{left,right}/
    └── jlf/{joint,majority}/
```

Tune CPU use with `PLUGIN=MultiProc NPROCS=4 tests/validation/run_pipeline.sh --lashis`.

### Phase 3 — validation
[scripts/validate_volume_consistency.py](../../scripts/validate_volume_consistency.py)

For each subject discovered under `tests/output/`, reads:

- `stats/volumes.csv` → tagged as `jlf` and `majority`
- `stats/jacpen_volumes.csv` → tagged as `jlf_jacpen` and `majority_jacpen`
- `intermediate/crosssectional_ashs/tp*/final/<subject>_<side>_heur_volumes.txt` → `ashs_xs`

…and writes three files into `tests/validation/results/`:

| File                          | Schema                                                                           |
|-------------------------------|----------------------------------------------------------------------------------|
| `all_volumes_long.csv`        | `subject,session_idx,side,subfield,method,volume_mm3` (the unified raw input)     |
| `per_subject_consistency.csv` | one row per (subject × side × subfield × method): `mean_mm3, sd_mm3, cv_pct, max_abs_pct_change` |
| `method_summary.csv`          | mean/median/sd of per-subject CV grouped by method (overall and per-subfield)    |

It also prints the headline number to stdout:

```
=== overall mean cv_pct by method (lower = more stable) ===
  ashs_xs                n= 196  mean cv%=  X.XXX  median cv%=  X.XXX  sd=...
  jlf                    n= 196  mean cv%=  X.XXX  ...
  majority               n= 196  mean cv%=  X.XXX  ...
  jlf_jacpen             n= 196  mean cv%=  X.XXX  ...
  majority_jacpen        n= 196  mean cv%=  X.XXX  ...
```

(`n` = subjects × sides × subfields with at least 2 sessions; here
~7 × 2 × 14 = 196.)

## Interpreting the result

These are healthy, neurologically stable young adults scanned weeks
apart. There is essentially no real volume change to detect. So:

- **Lower mean `cv_pct` is better.** It says the pipeline reproduces
  itself across rescans of the same brain.
- A method that is *higher* than `ashs_xs` is worse than just running
  cross-sectional ASHS three times — i.e. the longitudinal pipeline is
  adding noise rather than removing it. Investigate.
- A method *meaningfully lower* than `ashs_xs` is doing what
  longitudinal segmentation is supposed to do: borrowing strength
  across timepoints to suppress per-session noise.
- The Jacobian-penalised variants should track or beat their non-jacpen
  parents on most subfields; if they're worse, the Jacobian threshold
  is over-pulling and the threshold (`--jacobian-threshold`) needs
  raising.

This is *not* a validity check (we never see ground truth subfield
volumes); it's a stability check. A pipeline can be perfectly stable
and systematically wrong. Pair this with the QC viewers under
`tests/output/<sub>/qc/` to confirm the segmentations look anatomically
plausible.

## Expected runtime

Single workstation, 14-core Apple Silicon, 36 GB RAM, ANTs 2.5.x,
`PLUGIN=MultiProc NPROCS=4`:

| Phase             | All 7 subjects        | Per subject |
|-------------------|-----------------------|-------------|
| 1 download        | ~6 min (~2 GB)        | ~1 min      |
| 2 lashis          | ~24–36 h              | ~3.5–5 h    |
| 3 validate        | seconds               | n/a         |

The LASHiS phase is the long pole — 3× cross-sectional ASHS + SST +
SST-ASHS + 2× chunk SSTs + 2× JLF + reverse warps + Jacobian + stats.
Plan to leave it overnight.

## Files in this directory

| Path                  | Purpose                                                       |
|-----------------------|---------------------------------------------------------------|
| `run_pipeline.sh`     | The single orchestrator described above                       |
| `README.md`           | This file                                                     |
| `logs/`               | Per-phase tee'd logs (created on first run)                   |
| `results/`            | Validation CSVs (created on first `--validate` run)           |

## Troubleshooting

- **`ASHS_ROOT not set`** — export both `ASHS_ROOT` and `ASHS_ATLAS`
  before `--lashis`.
- **OSF download SSL failure on Python 3.14+** —
  `pip install certifi` into the venv (the downloader uses certifi's
  CA bundle when present).
- **A subject's LASHiS run errored mid-way** — the Nipype cache lives
  at `tests/output/sub-XX_nipype/`; re-running `--lashis` with that
  dir intact resumes from the last successful Node. Delete the
  specific Node hashdir to force just that step to rerun.
