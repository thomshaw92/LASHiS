# TOMCAT (subset for the LASHiS smoke test)

7T MRI from the TOMCAT test–retest study, subset to one subject across three
visits. Originally fetched from <https://osf.io/bt4ez/>.

## BIDS layout

```
sub-06/
├── ses-01/anat/
│   ├── sub-06_ses-01_T1w.nii.gz            # MP2RAGE-style, defaced
│   ├── sub-06_ses-01_run-1_T2w.nii.gz      # TSE, hippocampal coverage
│   ├── sub-06_ses-01_run-2_T2w.nii.gz
│   └── sub-06_ses-01_run-3_T2w.nii.gz
├── ses-02/anat/
│   ├── sub-06_ses-02_T1w.nii.gz
│   ├── sub-06_ses-02_run-1_T2w.nii.gz
│   ├── sub-06_ses-02_run-2_T2w.nii.gz
│   └── sub-06_ses-02_run-3_T2w.nii.gz
└── ses-03/anat/
    ├── sub-06_ses-03_T1w.nii.gz
    ├── sub-06_ses-03_run-1_T2w.nii.gz
    ├── sub-06_ses-03_run-2_T2w.nii.gz
    └── sub-06_ses-03_run-3_T2w.nii.gz
```

## Preprocessing → averaged T2w templates

LASHiS expects one T2w per timepoint. Each session here has three TSE runs.

1. **Run the preprocessing.** `scripts/preprocess_t2w_runs.sh` denoises each
   run with `DenoiseImage -n Rician`, then averages the three denoised runs
   into one per-session template via `antsMultivariateTemplateConstruction2.sh`
   (which N4-corrects internally with `-n 1`). Outputs land at:
   ```
   derivatives/templates/sub-06/ses-{01,02,03}/anat/
       sub-06_ses-XX_desc-template_T2w.nii.gz
   ```
2. **Finalize.** `scripts/finalize_t2w_templates.sh` promotes each template
   into the canonical BIDS T2w location and deletes the raw run files to
   shrink the data on disk. Refuses to run if any session is missing a
   template, so it's safe to run after the long preprocessing job.

After finalize, the layout is:

```
sub-06/
├── ses-01/anat/
│   ├── sub-06_ses-01_T1w.nii.gz
│   └── sub-06_ses-01_T2w.nii.gz       # averaged across 3 runs
├── ses-02/anat/
│   ├── sub-06_ses-02_T1w.nii.gz
│   └── sub-06_ses-02_T2w.nii.gz
└── ses-03/anat/
    ├── sub-06_ses-03_T1w.nii.gz
    └── sub-06_ses-03_T2w.nii.gz
```

## Smoke test

The smoke test auto-discovers the first `sub-*` directory with at least two
sessions and uses the T2w in this preference order:

1. `sub-XX/ses-YY/anat/sub-XX_ses-YY_T2w.nii.gz` (canonical, post-finalize)
2. `derivatives/templates/.../sub-XX_ses-YY_desc-template_T2w.nii.gz`
3. `sub-XX/ses-YY/anat/sub-XX_ses-YY_run-1_T2w.nii.gz` (raw fallback)

`pytest -m smoke` is opt-in; default `pytest` skips it. The fast tier
(`pytest`, no marker) runs `tests/test_imports.py` — no atlas/data needed,
~2 seconds.

## Atlas

The smoke test also needs an ASHS atlas. Drop one (e.g.
`ashs_atlas_umcutrecht_7t_20170810/` from
<https://www.nitrc.org/projects/ashs/>) at `tests/data/ashs_atlas_*/` and
export `ASHS_ATLAS=/full/path/to/ashs_atlas_*`. The atlas dir is gitignored
(7 GB, license-restricted). The Docker image (`ghcr.io/thomshaw92/lashis:2.0`) bakes
in the UMC Utrecht 7T atlas at `/opt/atlases/utrecht7t`.

## Outputs

Smoke-test outputs land at `tests/output/sub-06/` (gitignored). The
Nipype cache lives at `tests/output/sub-06_nipype/` — re-runs of the same
configuration hit the cache for completed nodes.
