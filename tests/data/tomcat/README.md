# TOMCAT (LASHiS smoke test + cross-session validation)

7T MRI from the TOMCAT test–retest study (`https://osf.io/bt4ez/`) — seven
healthy young subjects (`sub-01`…`sub-07`), three visits each.

For the cross-session validation pipeline see
[../../validation/README.md](../../validation/README.md). What follows is just
the layout and naming convention this directory uses.

## Two ways to populate this directory

`scripts/download_tomcat_osf.py` has two modes:

| Mode | What it fetches per session | Use when |
|------|------------------------------|----------|
| `--mode runs`      (default) | T1w + 3× raw TSE T2w runs | You want to re-derive the per-session T2w template yourself (exercises AMTC2 + finalize). |
| `--mode templates`           | T1w + the per-session averaged T2w template | You just want to run LASHiS — skips ~2 h of preprocessing per subject. Templates were uploaded to OSF as a derivative for this purpose. |
| `--mode all`                 | Both | When you want the raw runs *and* the canonical template. |

## BIDS layout — raw runs (`--mode runs`)

```
sub-XX/
├── ses-01/anat/
│   ├── sub-XX_ses-01_T1w.nii.gz                # MP2RAGE-style, defaced
│   ├── sub-XX_ses-01_run-1_T2w.nii.gz          # TSE, hippocampal coverage
│   ├── sub-XX_ses-01_run-2_T2w.nii.gz
│   └── sub-XX_ses-01_run-3_T2w.nii.gz
├── ses-02/anat/  (same shape)
└── ses-03/anat/  (same shape)
```

> **Note on OSF source naming.** The TOMCAT files on OSF aren't strictly
> BIDS-compliant — they include a site tag (`_7T`) and a non-BIDS suffix
> (`_defaced`) that documents the privacy step:
>
> ```
> OSF (TOMCAT_DIB/sub-XX/ses-YY_7T/anat/)            local (after download)
> sub-XX_ses-YY_7T_T1w_defaced.nii.gz             →  sub-XX_ses-YY_T1w.nii.gz
> sub-XX_ses-YY_7T_T2w_run-N_tse.nii.gz           →  sub-XX_ses-YY_run-N_T2w.nii.gz
> sub-XX_ses-YY[_7T]_acq-tse_desc-template_T2w.nii.gz → unchanged
> ```
>
> `scripts/download_tomcat_osf.py` does the rename on fetch, so the
> local layout is BIDS-clean even though OSF isn't.

Then run `scripts/preprocess_all_tomcat.sh` (AMTC2 with `-i 1
-q 30x20x4 -f 4x2x1 -s 2x1x0vox -n 1` per session — no separate
denoising; AMTC2's built-in N4 is on) and `scripts/finalize_t2w_templates.sh`
to promote each template into the canonical BIDS location below.

## BIDS layout — post-finalize (or `--mode templates`)

```
sub-XX/
├── ses-01/anat/
│   ├── sub-XX_ses-01_T1w.nii.gz
│   └── sub-XX_ses-01_acq-tse_desc-template_T2w.nii.gz   # averaged across 3 runs
├── ses-02/anat/  (same shape)
└── ses-03/anat/  (same shape)
```

The `acq-tse_desc-template` entities make it explicit that this T2w is a
TSE-derived per-session average rather than a single acquisition. LASHiS
v2 looks for this filename first, then falls back to `<sub>_<ses>_T2w.nii.gz`
for backward compatibility.

## Smoke test

`tests/test_smoke.py` auto-discovers the first `sub-*` directory with at
least two sessions and uses the T2w in this preference order:

1. `sub-XX/ses-YY/anat/sub-XX_ses-YY_acq-tse_desc-template_T2w.nii.gz` (current canonical)
2. `sub-XX/ses-YY/anat/sub-XX_ses-YY_T2w.nii.gz` (legacy)
3. `derivatives/templates/.../sub-XX_ses-YY_desc-template_T2w.nii.gz`
4. `sub-XX/ses-YY/anat/sub-XX_ses-YY_run-1_T2w.nii.gz` (raw fallback)

`pytest -m smoke` is opt-in; default `pytest` skips it. The fast tier
(`pytest`, no marker) runs `tests/test_imports.py` — no atlas/data needed,
~2 seconds.

## Atlas

Both the smoke test and the validation pipeline need an ASHS atlas. Drop
one (e.g. `ashs_atlas_umcutrecht_7t_20170810/` from
<https://www.nitrc.org/projects/ashs/>) at `tests/data/ashs_atlas_*/` and
export `ASHS_ATLAS=/full/path/to/ashs_atlas_*`. The atlas dir is gitignored
(7 GB, license-restricted). The Docker image (`ghcr.io/thomshaw92/lashis:2.0`)
bakes in the UMC Utrecht 7T atlas at `/opt/atlases/utrecht7t`.

## Outputs

Smoke-test outputs land at `tests/output/sub-06/` (gitignored). The
Nipype cache lives at `tests/output/sub-06_nipype/` — re-runs of the same
configuration hit the cache for completed nodes. Cross-session validation
outputs go to `tests/validation/results/` (see
[../../validation/README.md](../../validation/README.md)).
