#!/bin/bash
subjName="$1"
export FREESURFER_HOME=/data/lfs2/software/tools/freesurfer-dev-20181125/freesurfer/
source $FREESURFER_HOME/SetUpFreeSurfer.sh
SUBJECTS_DIR=/data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer
#long proc
#recon-all -base ${subjName:0:8}_3TP -tp ${subjName:0:8}_01_7T -tp ${subjName:0:8}_02_7T -tp ${subjName:0:8}_03_7T -all -cm -no-isrunning
#recon-all -base "${subjName:0:8}_2TP_1-2" -tp ${subjName:0:8}_01_7T -tp ${subjName:0:8}_02_7T -all -cm -no-isrunning
#recon-all -base "${subjName:0:8}_2TP_2-3" -tp ${subjName:0:8}_02_7T -tp ${subjName:0:8}_03_7T -all -cm -no-isrunning
#3tp
#recon-all -long ${subjName:0:8}_01_7T ${subjName:0:8}_3TP -all -cm -no-isrunning
#recon-all -long ${subjName:0:8}_02_7T ${subjName:0:8}_3TP -all -cm -no-isrunning
#recon-all -long ${subjName:0:8}_03_7T ${subjName:0:8}_3TP -all -cm -no-isrunning
#2tp-2-1
#recon-all -long ${subjName:0:8}_01_7T "${subjName:0:8}_2TP_1-2" -all -cm -no-isrunning
#recon-all -long ${subjName:0:8}_02_7T "${subjName:0:8}_2TP_1-2" -all -cm -no-isrunning
#2tp-2-3
#recon-all -long ${subjName:0:8}_02_7T "${subjName:0:8}_2TP_2-3" -all -cm -no-isrunning
#recon-all -long ${subjName:0:8}_03_7T "${subjName:0:8}_2TP_2-3" -all -cm -no-isrunning

#XS HSF
segmentHA_T1.sh ${subjName:0:8}_01_7T $SUBJECTS_DIR
segmentHA_T2.sh ${subjName:0:8}_01_7T /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/$subjName/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz T2_Only 0 $SUBJECTS_DIR
segmentHA_T1.sh ${subjName:0:8}_02_7T $SUBJECTS_DIR
segmentHA_T2.sh ${subjName:0:8}_02_7T /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/$subjName/${subjName}_ses-02_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz T2_Only 0 $SUBJECTS_DIR
segmentHA_T1.sh ${subjName:0:8}_03_7T $SUBJECTS_DIR
segmentHA_T2.sh ${subjName:0:8}_03_7T /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/$subjName/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz T2_Only 0 $SUBJECTS_DIR
#long HSF
segmentHA_T1_long.sh ${subjName:0:8}_3TP $SUBJECTS_DIR
segmentHA_T1_long.sh "${subjName:0:8}_2TP_1-2" $SUBJECTS_DIR
segmentHA_T1_long.sh "${subjName:0:8}_2TP_2-3" $SUBJECTS_DIR
