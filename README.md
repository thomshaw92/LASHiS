# LASHiS
Longitudinal Automatic Segmentation of Hippocampal Subfields (LASHiS) using multi-contrast MRI.

## Requirements:

 Requires ANTs  https://github.com/ANTsX/ANTs/
 Requires ASHS https://sites.google.com/site/hipposubfields/home 

LASHiS performs a longitudinal estimation of hippoocampus subfields.  The following steps are performed:
  1. Run Cross-sectional ASHS on all timepoints
  2. Create a single-subject template (SST) from all the data, then cross-sectionally run the SST through ASHS.
  3. Using the Cross-sectional inputs as priors, label the hippocampi of the SST.
  4. Segmentation results are reverse normalised to the individual time-point. 
  
## Environment Variables: 

  ASHS_ROOT         Path to the ASHS root directory 
  
  ANTSPATH          Path to the ANTs root directory 
  
## Misc Notes: 
 LASHiS was loosely adapted from the ANTs Longitudinal Cortical Thickness pipeline https://github.com/ANTsX/ANTs/
 The ASHS_TSE image slice direction should be z. In other words, the dimension 
 of ASHS_TSE image should be 400x400x30 or something like that, not 400x30x400 
## Usage: 
	/path/to/LASHiS.sh -a atlas selection for ashs \
        	<OPTARGS> \
		-o outputPrefix \
		\${anatomicalImages[@]} \

## Required arguments:
     
     -o:  Output prefix                         The following subdirectory and images are created for the single
                                                subject template
                                                  * \${OUTPUT_PREFIX}SingleSubjectTemplate/
                                                  * \${OUTPUT_PREFIX}SingleSubjectTemplate/T_template*.nii.gz
     -a: Atlas selection                        Full path for the atlas you would like to use for the Cross-sectional
                                                labelling of ASHS and the SST. Can be made in ASHS_train
     anatomical images                          Set of multimodal (T1w or gradient echo, followed by T2w FSE/TSE input)
                                                data. Data must be in the format specified by ASHS & ordered as follows:
                                                  ${time1_T1w} ${time1_T2w} \
                                                  ${time2_T1w} ${time2_T2w} \
                                                  .
                                                  .
                                                  .
                                                  ${timeN_T1w} ${timeN_T2w} ...
					

## Optional arguments:
    
         
     -c:  control type                          Control for parallel computation for ANTs steps (JLF,SST creation)  (default 0):
                                                  0 = run serially
                                                  1 = SGE qsub
                                                  2 = use PEXEC (localhost) (remember to define cores in -j)
                                                  3 = Apple XGrid
                                                  4 = PBS qsub
                                                  5 = SLURM
     
     -d:  OPTS                                  Pass in additional options to SGE's qsub for ASHS. Requires -c 1
 
     -e:  ASHS file                             ProConfiguration file. If not passed, uses $ASHS_ROOT/bin/ashs_config.sh 
     -f:  Diet LASHiS                           Diet LASHiS (reverse normalise the SST only) then exit.
     
     -g:  denoise anatomical images             Denoise anatomical images (default = 0).
     -j:  number of cpu cores                   Number of cpu cores to use locally for pexec option (default 2; requires "-c 2")
                                           
     -n:  N4 Bias Correction                    If yes, Bias correct the input images before template creation.
                                                0 = No
                                                1 = Yes
     
     -b:  keep temporary files                  Keep brain extraction/segmentation warps, etc (default = 0).

   ## Data structure if you have already created an SST: 

```
project_base_dir   
│
└───SubjectName_LASHiSSingleSubjectTemplate
│   │
│   │   T_subjectname_fiename0Affine.txt
│   │   T_subjectname_fiename0InverseWarp.nii.gz
│   │   T_subjectname_fiename0Warp.nii.gz
│   │   T_subjectname_fiename2Affine.txt
│   │   T_subjectname_fiename2InverseWarp.nii.gz
│   │   T_subjectname_fiename2Warp.nii.gz
│   │   T_template0.nii.gz
│   │   T_template0_rescaled.nii.gz
│   │   T_template1.nii.gz
│   │   T_template1_rescaled.nii.gz #rescaled to have intensity range of 0-1000
│   │   
│   └───SST_ASHS
│   |	| SST ASHS FILES
|   |	| ...
|   |	
|   │   file021.txt
|   │   file022.txt
|    
|    
└───SubjectName_LASHiS
│   │
│   └───Timepoint_1_0
│   |	│
│   |	└───Timepoint_1_XS_ASHS
│   │
│   └───Timepoint_n_0
│   |	│
│   |	└───Timepoint_n_XS_ASHS
│   │
│   └───LASHiS
│       │   stats.txt 
│       │   labels.nii.gz
│       │   ...
  

```
