# LASHiS

**Longitudinal Automatic Segmentation of Hippocampal Subfields** — a Nipype
workflow for multi-contrast MRI.

> ⚠️ **This is LASHiS v2 — NOT the version published in the paper.**
> The published methodology (Shaw et al., NeuroImage 2020,
> [doi:10.1016/j.neuroimage.2020.116798](https://doi.org/10.1016/j.neuroimage.2020.116798))
> is preserved in [`LASHiS-V1.0/`](LASHiS-V1.0/) — see that directory's README
> if you need to reproduce the original results bit-for-bit.
>
> v2 has the same scientific intent but is a substantial rewrite. See
> [v1 vs v2](#v1-vs-v2) for what changed and why.

---

## Contents

- [Quick start](#quick-start)
- [Install](#install)
- [Usage](#usage)
- [Algorithm options](#algorithm-options)
  - [Fusion: majority vs JLF](#fusion-majority-vs-jlf)
  - [Jacobian-penalised segmentation (jacpen)](#jacobian-penalised-segmentation-jacpen)
- [Output layout](#output-layout)
- [Tests](#tests)
- [v1 vs v2](#v1-vs-v2)
- [Citation](#citation)

---

## Quick start

```bash
docker pull thomshaw92/lashis:2.0     # bundled ANTs + ASHS + FSL + atlas
docker run --rm -v /your/data:/data thomshaw92/lashis:2.0 \
    lashis -o /data/sub01_out \
           -a /opt/atlases/utrecht7t \
           --plugin MultiProc --n-procs 8 \
           --fusion both --jacobian-penalise \
           /data/sub01_ses01_T1w.nii.gz /data/sub01_ses01_T2w.nii.gz \
           /data/sub01_ses02_T1w.nii.gz /data/sub01_ses02_T2w.nii.gz
```

Open the QC viewer:

```bash
cd /your/data/sub01_out && ./qc/serve.sh
# http://localhost:8765/qc/index.html
```

Inspect numbers:

```bash
cat /your/data/sub01_out/stats/volumes.csv
cat /your/data/sub01_out/stats/jacobian_volumes.csv
cat /your/data/sub01_out/stats/consistency.csv
cat /your/data/sub01_out/stats/longitudinal.csv
```

---

## Install

### Container (recommended)

The Docker image bundles ANTs 2.6.2 + FSL 6.0.7.16 + ASHS v2.0.0 + the UMC
Utrecht 7T atlas + the lashis Python CLI. Built via
[neurodocker](https://github.com/ReproNim/neurodocker) so the recipe matches
Neurodesk conventions; it's intended for future contribution to
[neurocontainers](https://github.com/NeuroDesk/neurocontainers).

```bash
# Pull pre-built (when published)
docker pull thomshaw92/lashis:2.0

# Or build locally (~30 min, ~6 GB image)
docker build --platform linux/amd64 -t thomshaw92/lashis:2.0 .
```

> macOS / Apple Silicon: must pass `--platform linux/amd64` because FSL has
> no native ARM64 binary. The image runs via Docker Desktop's emulation.

### Native install

```bash
pip install -e ".[dev]"

# Plus install separately:
#   ANTs (≥ 2.5)         https://github.com/ANTsX/ANTs/
#   ASHS (v2.0.0)        https://github.com/pyushkevich/ashs
#   FSL                  https://fsl.fmrib.ox.ac.uk/
#   an ASHS atlas        https://www.nitrc.org/projects/ashs/

export ASHS_ROOT=/path/to/ashs
export ANTSPATH=/path/to/ants/bin
export FSLDIR=/path/to/fsl

lashis --check-deps   # confirm everything found
```

---

## Usage

```text
lashis -o <output_prefix> -a <atlas_dir> [options] T1w_a T2w_a T1w_b T2w_b ...
```

Anatomical images are positional, ordered as **T1w/T2w pairs per timepoint**.
ASHS expects the TSE slice direction to be z (e.g. 400×400×30, not 400×30×400).

### CLI flags

| Flag | Meaning |
|---|---|
| `-o`, `--output-prefix` | output directory (created) |
| `-a`, `--atlas` | path to the ASHS atlas directory |
| `-c`, `--plugin` | Nipype plugin: `Linear` (serial), `MultiProc`, `SGE`, `PBS`, `SLURM`. Legacy numeric codes 0/1/2/4/5 also accepted (3 = XGrid is no longer supported). |
| `-j`, `--n-procs` | parallel processes for `MultiProc` (default 2) |
| `-d`, `--ashs-sge-opts` | extra SGE options forwarded to ASHS |
| `-e`, `--ashs-config` | ASHS config file (defaults to `$ASHS_ROOT/bin/ashs_config.sh`) |
| `-g`, `--denoise` | denoise inputs with `DenoiseImage` |
| `-n`, `--n4` | N4 bias correction |
| `-b`, `--keep-tmp` | keep intermediate files (skip cleanup nodes) |
| `-q`, `--quick` | 0 fast SST; 1 + fast JLF; 2 (legacy "Diet") |
| `-z`, `--debug` | DEBUG log level |
| `--check-deps` | check ANTs/ASHS deps and exit |
| `--skip-qc` | skip pre-flight input QC (TSE slice direction, voxel size) |
| `--fusion` | `majority`, `jlf`, or `both` (default both) — see below |
| `--no-icv` | skip the ASHS-emitted ICV column in `volumes.csv` |
| `--no-qc` | skip the HTML QC viewer |
| `--no-jacobian` | skip Jacobian-determinant volumes + `consistency.csv` |
| `--jacobian-threshold` | flag fraction in `consistency.csv` (default 0.10) |
| `--jacobian-penalise` | (opt-in) produce Jacobian-penalised label maps |
| `--jacpen-weighting` | rank → penalty weight: `linear` / `sqrt` / `equal` |
| `--no-jacpen-largest-cc` | skip largest-CC cleanup of jacpen labels |

---

## Algorithm options

### Fusion: majority vs JLF

LASHiS combines per-timepoint cross-sectional ASHS segmentations onto a
per-subject template via [`antsJointLabelFusion.sh`][1]. There are two
voting methods you can pick (or run both for direct comparison):

[1]: https://github.com/ANTsX/ANTs/blob/master/Scripts/antsJointLabelFusion.sh

- **`majority`** — straight majority voting. Each voxel's label is the most
  common label across the registered atlases. Equivalent to what LASHiS v1
  used. Fast, simple, but treats all atlases as equally trustworthy
  regardless of local image similarity.
- **`jlf`** (joint label fusion) — Wang & Yushkevich's weighted fusion
  (Wang et al., IEEE TMI 2013). Each atlas's vote is weighted by its local
  intensity similarity to the target. More accurate when one or more atlas
  registrations are poor in a given region.
- **`both`** (default) — runs JLF twice with separate output prefixes;
  registrations are not shared, so this ~doubles the JLF stage runtime.
  Outputs land at `labels/jlf/` and `labels/majority/`. Useful for direct
  comparison and as a sanity check.

In our 7T TOMCAT validation (sub-06, 2 sessions), JLF and majority agree
within ~1 % on the dominant subfields (CA1, DG, SUB) and diverge by ~7 %
on Tail (the smallest, hardest-to-segment label). JLF tends to be more
self-consistent across timepoints.

### Jacobian-penalised segmentation (jacpen)

A complementary measurement that uses the **deformation field's Jacobian**
to constrain the segmentation. Conceptually similar to ALOHA
(Yushkevich's [Automated Longitudinal Hippocampal Atrophy](https://github.com/ins0mniac2/aloha))
but applied as a per-label posterior re-thresholding, not a separate
volumetric measurement.

**The idea:**

1. JLF already produces `chunk_sst → tp_i` deformation fields per timepoint.
2. The Jacobian determinant of that field tells us how a small SST volume
   element maps to tp-space — i.e. the deformation's prediction of how
   each subfield's volume *should* have changed.
3. For each (timepoint, side, fusion_method), pull each subfield's
   segmentation volume partway toward the Jacobian's prediction. **Larger
   subfields are pulled harder** (rank-weighted penalty); smaller subfields
   keep more of their original segmentation extent (so a small label can
   expand if the Jacobian says so, but won't be crushed by a dominant
   neighbour).

**Per-label algorithm:**

```
sort labels by current segmentation volume, largest first
for each label l (rank r ∈ [0, N-1]):
    w_l = 1 − r / N        # 'linear' weighting (default)
                           # 'sqrt': 1 − √(r/N), penalty drops faster on small labels
                           # 'equal': 0.5 (no rank ordering)
    target_vol(l) = V_seg(l) + w_l × ( V_jac(l) − V_seg(l) )

    # Greedy posterior thresholding: claim the top-K voxels of label l's
    # JLF posterior probability map (warped to tp-space), restricted to
    # voxels not yet claimed by a higher-ranked label.
```

Voxels that remain unclaimed at the end **fall back to their original
segmentation label** (so coverage is never reduced). Optionally the largest
connected component per label is kept (drops greedy-thresholding fragments
— `--no-jacpen-largest-cc` to disable).

**Outputs:**

- `labels/<method>_jacpen/tpXX_<side>.nii.gz` — the corrected label maps
- `stats/jacpen_volumes.csv` — long-format volumes for the corrected labels
- `intermediate/_jacpen_meta/<method>/tpXX_<side>_targets.txt` — log of
  what target volume each label was pulled toward

In our 7T validation, jacpen pulls majority's CA1 / DG up by ~7 % and
crushes spurious Cyst voxels (small atlas-noise label) by ~58 %. JLF
fusion's volumes already align well with the Jacobian, so jacpen's pull
on JLF is < 3 % on most labels.

---

## Output layout

```
<output_prefix>/
├── lashis_run.json                              # version + parameter manifest
├── snaplabels.txt                               # subfield-id → name (from atlas)
├── stats/                                       ★ THE NUMBERS
│   ├── volumes.csv                              # segmentation volumes (long format)
│   ├── jacobian_volumes.csv                     # ALOHA-style Jacobian volumes
│   ├── jacpen_volumes.csv                       # Jacobian-penalised seg volumes
│   ├── consistency.csv                          # seg vs jacobian + flag_unreliable
│   ├── asymmetry.csv                            # L/R asymmetry index
│   ├── longitudinal.csv                         # change vs baseline session
│   └── per_timepoint/<method>/                  # legacy per-(tp,side) text files
├── qc/                                          ★ INTERACTIVE QC
│   ├── index.html                               # NiiVue-based viewer
│   └── serve.sh                                 # ./serve.sh → http://localhost:8765
├── labels/
│   ├── jlf/tp{XX}_{left,right}.nii.gz           # joint-fusion warped labels
│   ├── jlf_jacpen/                              # jacpen variant of jlf
│   ├── majority/                                # majority-vote warped labels
│   └── majority_jacpen/                         # jacpen variant of majority
├── posteriors/{jlf,majority}/<side>_<NNNN>.nii.gz   # per-label posteriors
└── intermediate/                                # working files
    ├── crosssectional_ashs/tp{XX}/              # per-timepoint ASHS
    ├── sst/                                     # multimodal SST + SST_ASHS
    ├── chunk_sst/{left,right}/                  # per-side TSE chunk template
    ├── jlf/<method>/                            # JLF transforms + staging
    ├── jacobian/<method>/                       # Jacobian determinant images
    ├── posteriors_warped/<method>/tpXX_<side>/  # tp-space posteriors (for jacpen)
    └── _jacpen_meta/<method>/                   # jacpen target-volume logs

<output_prefix>_nipype/                          # Nipype's per-Node cache (sibling)
```

### Stats files explained

**`volumes.csv`** — long format, one row per (timepoint × side × method × subfield):
```
subject,session_idx,side,fusion_method,subfield,z_extent,volume_mm3,icv_mm3,volume_mm3_norm
```

**`jacobian_volumes.csv`** — Jacobian-determinant-derived volume estimates.
Computed by integrating `CreateJacobianDeterminantImage` of each chunk-SST→tp
inverse warp over the SST-space subfield label region. Reference frame is
the chunk SST (every timepoint symmetric, no privileged baseline).

**`jacpen_volumes.csv`** — volumes of the Jacobian-penalised label maps in
`labels/<method>_jacpen/`. Same long-format schema as `volumes.csv`.

**`consistency.csv`** — side-by-side `seg_volume_mm3` vs `jacobian_volume_mm3`
per (tp, side, method, subfield), with `seg_change_pct`,
`jacobian_change_pct`, `discrepancy_pct`, and a boolean `flag_unreliable`
(True when |discrepancy| > `--jacobian-threshold`, default 10 %). Use this
for QC: large discrepancy → either segmentation drift or registration
failure for that subfield/timepoint.

**`asymmetry.csv`** — `asymmetry_index = (L − R) / ((L + R) / 2)` per
subfield × timepoint × method. Positive = left larger.

**`longitudinal.csv`** — `delta_vs_baseline` and `percent_change_vs_baseline`
relative to session 0, per (side, method, subfield).

**`lashis_run.json`** — captures lashis version, exact CLI invocation,
ANTs/ASHS/FSL versions, ASHS git commit hash. Sufficient to reproduce a run.

The legacy `per_timepoint/<method>/<basename>_<side>_TimePoint_<i>_stats.txt`
files (5-column whitespace-separated, original LASHiS format) are still
written for compatibility with older analysis scripts.

---

## Tests

Two tiers:

### Fast tests (default `pytest`)

```bash
.venv/bin/pytest
```

Six tests, ~2 seconds, no external deps. Verifies imports, CLI parsing,
workflow assembly with full features, dependency check behaviour, and the
QC HTML generator. Suitable for CI and Docker build-time tests.

### Smoke test (real pipeline, opt-in)

```bash
.venv/bin/pytest -m smoke
```

Runs the full pipeline end-to-end on the bundled TOMCAT subject. Requires:

- `ASHS_ROOT` and `ASHS_ATLAS` set in the environment
- `tests/data/tomcat/sub-06/ses-{01,02,03}/anat/` populated (you fetch and
  drop the data — see `tests/data/tomcat/README.md`)

Run-time on a M-series Mac with `--n-procs 8`: ~1–2 hours including ASHS
runs. The Nipype cache (under `tests/output/<sub>_nipype/`) makes re-runs
near-instant for unchanged code.

Outputs go under `tests/output/sub-06/` — gitignored.

### Inputs / atlas — gitignored

The TOMCAT BIDS data, the ASHS atlas (~7 GB), and Nipype outputs are all
gitignored. The atlas should live at `tests/data/ashs_atlas_*/` (or wherever
you point `ASHS_ATLAS`).

---

## v1 vs v2

LASHiS v1 (the published version, in [`LASHiS-V1.0/`](LASHiS-V1.0/)) is a
single ~1,200-line bash script. v2 is a Nipype Python package with the
same algorithm but several improvements:

| | v1 (paper) | v2 (this repo) |
|---|---|---|
| Implementation | bash script | Python + Nipype DAG |
| Resumability | none — restart from scratch on any failure | per-Node cache; rerun resumes from last completed stage |
| Failure mode | obscure tail of bash output, often silent | dumped text crash files + CLI summary surfacing the actual stderr |
| Per-stage parallelism | yes (via ANTs/ASHS internals) | yes + Nipype-level (`MultiProc` plugin runs independent stages concurrently) |
| Output layout | flat, sibling dirs (`<out>SingleSubjectTemplate/` outside `<out>/`) | clean `<out>/{stats,qc,labels,intermediate}/` |
| Stats output | per-(tp, side) text files | long-format CSVs (volumes / asymmetry / longitudinal / Jacobian / consistency) |
| Run reproducibility | nothing recorded | `lashis_run.json` manifest with exact CLI + ANTs/ASHS/FSL versions |
| QC | none | interactive NiiVue viewer (`qc/index.html`) |
| ICV normalisation | none | reads ASHS-emitted `final/<basename>_icv.txt` |
| Fusion methods | majority voting only | `majority`, `jlf`, or both |
| Jacobian-derived volumes | no | `jacobian_volumes.csv` + `consistency.csv` |
| Jacobian-penalised segmentation | no | optional `labels/<method>_jacpen/` |
| Container | yes (`caid/lashis_1.0`) | yes (`thomshaw92/lashis:2.0`, neurodocker recipe) |
| AMTC2 chunk-template inputs | binarised + cropped chunks (intensity / FOV mismatch with JLF target) | raw `tse_native_chunk_<side>` (matches JLF target) |
| AMTC script version | v1 (`antsMultivariateTemplateConstruction.sh`) | v2 (`…2.sh`) |

**v2 is not bit-identical to v1** — the algorithmic choices that differ
(raw chunks for SST construction, AMTC v2, optional jacpen / weighted
fusion) all flow downstream into the labels. For most subfields the
volumes agree within a few percent. Use v1 for paper reproduction; use v2
for new analyses.

### Removed v1 flags

- `-f` (Diet LASHiS) — algorithm dropped; was experimental and unmaintained
- `-s` (suffix) — output is always `.nii.gz`; flag was cosmetic
- `-c 3` (XGrid) — Apple deprecated XGrid in 2010

---

## Citation

If you use **v1** (the published methodology), please cite:

> Shaw TB, York A, Ziaei M, Barth M, Bollmann S.
> *Longitudinal Automatic Segmentation of Hippocampal Subfields (LASHiS)
> using multi-contrast MRI*. NeuroImage 218 (2020): 116798.
> [doi:10.1016/j.neuroimage.2020.116798](https://doi.org/10.1016/j.neuroimage.2020.116798)

If you use **v2**, cite the same paper PLUS this repository as
"LASHiS v2 (https://github.com/thomshaw92/LASHiS)" (or wherever you've
forked / hosted it).

## License

GPL-3.0. ASHS and FSL have their own licences (FSL is non-commercial-use
without explicit licence).
