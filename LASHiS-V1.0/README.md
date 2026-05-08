# LASHiS v1 (legacy bash pipeline)

This directory preserves the **original LASHiS v1.0** as published in
*Shaw et al., NeuroImage 2020* (<https://doi.org/10.1016/j.neuroimage.2020.116798>).

The script `LASHiS.sh` here is exactly what was used in the paper. It is a
single ~1,200-line bash pipeline calling ANTs and ASHS directly. Kept here
so anyone wanting to **reproduce the published methodology** verbatim can
still do so.

> **For new work, use the v2 Python/Nipype pipeline at the repo root.** v2
> has the same scientific intent but with major debuggability and reliability
> improvements, plus new optional outputs (Jacobian-derived volumes,
> Jacobian-penalised segmentation, interactive QC). v2 is **not bit-identical**
> to v1 — see the top-level README for an exhaustive v1↔v2 diff.

## Requirements (v1)

- ANTs ≥ 2.3.0 (https://github.com/ANTsX/ANTs/) — must include
  `antsMultivariateTemplateConstruction.sh` (note: v1 of that script, not v2)
- ASHS (https://sites.google.com/site/hipposubfields/home) and an
  ASHS-compatible atlas (e.g. UMC Utrecht 7T, Penn Memory Center 3T)
- bash, awk
- (Optional) HPC scheduler if running on cluster

Set `ASHS_ROOT` and `ANTSPATH` in your environment.

## Usage

Same flags as the v2 CLI accepts (v2's flag set is backwards-compatible):

```bash
./LASHiS.sh -a /path/to/ashs_atlas \
            -o /path/to/output_prefix \
            [optional flags] \
            t1w_a.nii.gz t2w_a.nii.gz \
            t1w_b.nii.gz t2w_b.nii.gz \
            ...
```

Anatomical images are positional, ordered as T1w/T2w pairs per timepoint.
ASHS expects the TSE slice direction to be z (e.g. 400×400×30, not 400×30×400).

### Original flags

| Flag | Meaning |
| --- | --- |
| `-a` | ASHS atlas directory (required) |
| `-o` | Output prefix (required) |
| `-c` | Parallelisation: 0=serial, 1=SGE qsub, 2=PEXEC, 3=XGrid, 4=PBS qsub, 5=SLURM (default 0) |
| `-d` | SGE qsub options (passed to ASHS) |
| `-e` | ASHS config file (defaults to `$ASHS_ROOT/bin/ashs_config.sh`) |
| `-f` | "Diet LASHiS" mode (reverse-normalise the SST only, then exit) |
| `-g` | Denoise inputs with ANTs `DenoiseImage` (0/1, default 0) |
| `-j` | Number of CPU cores for PEXEC mode (default 2) |
| `-n` | N4 bias correction of inputs (0/1, default 0) |
| `-b` | Keep intermediate files (0/1, default 0) |
| `-q` | "Run quick" mode (0/1/2, default 0) |
| `-z` | Debug mode (0/1, default 0) |

## Output layout (v1)

v1 wrote outputs into the directory specified by `-o` plus a SIBLING
`<output_prefix>SingleSubjectTemplate/` directory. Within `<output_prefix>/`:

```
<output_prefix>/
├── <basename>_0/<basename>/        # cross-sectional ASHS, timepoint 0
├── <basename>_1/<basename>/        # cross-sectional ASHS, timepoint 1
├── ...
├── ChunkSingleSubjectTemplateleft/  # per-side TSE chunk template
├── ChunkSingleSubjectTemplateright/
└── LASHiS/
    ├── leftSSTLabelsWarpedTo0.nii.gz
    ├── leftSSTLabelsWarpedTo1.nii.gz
    ├── rightSSTLabelsWarpedTo0.nii.gz
    ├── rightSSTLabelsWarpedTo1.nii.gz
    ├── snaplabels.txt
    └── <basename>_<side>_TimePoint_<i>_stats.txt
<output_prefix>SingleSubjectTemplate/
├── T_template0.nii.gz, T_template1.nii.gz   # multimodal SST
├── T_template0_rescaled.nii.gz
└── SST_ASHS/
```

## Citation (v1)

If you use v1, please cite the original paper:

> Shaw TB, York A, Ziaei M, Barth M, Bollmann S.
> *Longitudinal Automatic Segmentation of Hippocampal Subfields (LASHiS) using
> multi-contrast MRI*. NeuroImage 218 (2020): 116798.
> https://doi.org/10.1016/j.neuroimage.2020.116798

## Migrating to v2

Most v1 flags are accepted by v2 unchanged. The two removed ones:

- `-f` (Diet LASHiS) — algorithm dropped; was experimental and unmaintained
- `-s` (suffix) — output is always `.nii.gz`; flag was cosmetic anyway
- `-c 3` (XGrid) — Apple deprecated XGrid in 2010; use `--plugin MultiProc`

Otherwise:

```bash
# v1
./LASHiS-V1.0/LASHiS.sh -a $ATLAS -o out -c 2 -j 4 t1a t2a t1b t2b

# v2 (same flags work)
lashis -a $ATLAS -o out -c 2 -j 4 t1a t2a t1b t2b

# v2 with new features
lashis -a $ATLAS -o out --plugin MultiProc --n-procs 4 \
       --fusion both --jacobian-penalise t1a t2a t1b t2b
```
