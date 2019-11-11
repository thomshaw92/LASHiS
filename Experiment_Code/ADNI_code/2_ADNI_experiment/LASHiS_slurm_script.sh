#!/bin/bash
#SBATCH --job-name=ADNI_LASHIS_script
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8 
#SBATCH --partition=all
#SBATCH --mem=20000
#SBATCH -o LASHiS_slurm.%N.%j.out 
#SBATCH -e LASHiS_slurm.%N.%j.error  

base_dir=/data/fasttemp/uqtshaw/ADNI_data/ADNI_BIDS/derivatives

#set up some stuff
#this should all be singularity
export ANTSPATH=~/bin/ants/bin/
PATH=$ANTSPATH:$PATH
export ASHS_ROOT=/data/lfs2/software/tools/ASHS/ashs-fastashs_beta
export FREESURFER_HOME=/data/lfs2/software/tools/freesurfer-dev-20181125/freesurfer/
source $FREESURFER_HOME/SetUpFreeSurfer.sh

SUBJECTS_DIR=${base_dir}/freesurfer

##################
## LASHiS proc  ##
##################

${base_dir}/LASHiS/LASHiS.sh
#do LASHiS and Diet here.
#this includes Xs ASHS so no need to do it again.
#atlas? Maybe the 3T upenn one.

##############
## FS proc  ##
##############
#loops for each csv
for subjName in `cat subjnames.csv` ; do
    for subjname in `cat subjnames3tp.csv` ; do
    done
done
	       
recon-all -subjid ${subjName}_ses-01 -all -i ${basedir}/${subjName}/ses-01/anat/${subjName}_ses-01_T1w.nii.gz -openmp 4 -3T & 
recon-all -subjid ${subjName}_ses-02 -all -i ${basedir}/${subjName}/ses-02/anat/${subjName}_ses-02_T1w.nii.gz -openmp 4 -3T & 
recon-all -subjid ${subjName}_ses-03 -all -i ${basedir}/${subjName}/ses-03/anat/${subjName}_ses-03_T1w.nii.gz -openmp 4 -3T &


## do that thing where you wait for the ps to finish in a loop here.
#Then start long proc

#long proc
#Base
#3tp
recon-all -base ${subjName}_3TP -tp ${subjName}_ses-01 -tp ${subjName}_ses-02 -tp ${subjName}_ses-03 -all
#2tp
recon-all -base ${subjName}_2TP -tp ${subjName}_ses-01 -tp ${subjName}_ses-02 -all
#Long
#3tp
recon-all -long ${subjName}_01 ${subjName}_3TP -all -cm -no-isrunning
recon-all -long ${subjName}_02 ${subjName}_3TP -all -cm -no-isrunning
recon-all -long ${subjName}_03 ${subjName}_3TP -all -cm -no-isrunning
#2TP
recon-all -long ${subjName}_01 ${subjName}_2TP -all -cm -no-isrunning
recon-all -long ${subjName}_02 ${subjName}_2TP -all -cm -no-isrunning

#XS HSF #this needs to be updated.

segmentHA_T1.sh ${subjName}_ses-01 $SUBJECTS_DIR
segmentHA_T2.sh ${subjName}_ses-01 ${base_dir}/$subjName/${subjName}t2.nii.gz T2_Only 0 $SUBJECTS_DIR
segmentHA_T1.sh ${subjName}_ses-01 $SUBJECTS_DIR
segmentHA_T2.sh ${subjName}_ses-01 T2_image.nii.gz T2_Only 0 $SUBJECTS_DIR
segmentHA_T1.sh ${subjName:0:8}_03_7T $SUBJECTS_DIR
segmentHA_T2.sh ${subjName:0:8}_03_7T /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/$subjName/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz T2_Only 0 $SUBJECTS_DIR
#long HSF
segmentHA_T1_long.sh ${subjName:0:8}_3TP $SUBJECTS_DIR
segmentHA_T1_long.sh "${subjName:0:8}_2TP_1-2" $SUBJECTS_DIR
segmentHA_T1_long.sh "${subjName:0:8}_2TP_2-3" $SUBJECTS_DIR
