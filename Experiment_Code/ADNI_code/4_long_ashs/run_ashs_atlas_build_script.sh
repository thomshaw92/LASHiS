#!/bin/bash
subjName=$1
source ~/.bashrc
#ANTS
mkdir /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_atlas/
export ANTSPATH=~/bin/ants/bin/
PATH=$ANTSPATH:$PATH
##Concatenate the names to manifest
#mkdir /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas
#echo "${subjName}_ses-01 /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/mprage.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/tse.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/final/${subjName}_ses-01_xs_ashs_left_lfseg_corr_nogray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/final/${subjName}_ses-01_xs_ashs_right_lfseg_corr_nogray.nii.gz" >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/manifest.txt
#for x in 02 03 ; do
#	echo "${subjName}_ses-${x} /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs/mprage.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs/tse.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs/final/${subjName}_ses-${x}_xs_ashs_left_lfseg_corr_nogray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs/final/${subjName}_ses-${x}_xs_ashs_right_lfseg_corr_nogray.nii.gz" >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/manifest.txt
#done

###TRAIN###
export ASHS_ROOT=/data/lfs2/software/tools/ASHS/ashs-fastashs_beta
$ASHS_ROOT/bin/ashs_train.sh -D /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/manifest.txt -L /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/snap/snaplabels.txt -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas -C /data/fasttemp/uqtshaw/tomcat/data/4_long_ashs/config.txt
###LABEL###

#$ASHS_ROOT/bin/ashs_main.sh -a /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/final -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_template0.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_template1.nii.gz -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/ashs_of_3TP_template_using_atlas -I ${subjName}_long_ashs_atlas

###WARP###
#for TP in 01 02 03 ; do
#for side in left right ; do
	#WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/ashs_of_3TP_template_using_atlas/final/${subjName}_long_ashs_atlas_${side}_lfseg_corr_usegray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/${subjName}_ashs_3TP_SST_${side}_lfseg_corr_usegray_warped_to_ses-${TP}.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-${TP}_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_${subjName}_ses-${TP}*GenericAffine.mat /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_${subjName}_ses-${TP}_*InverseWarp.nii.gz --use-BSpline --use-ML 0.4mm 
	#gather the volumes
#	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-${TP}_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_atlas/${subjName}_ashs_3TP_SST_${side}_lfseg_corr_usegray_warped_to_ses-${TP}.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_atlas/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-${TP}.csv
#done
#done
