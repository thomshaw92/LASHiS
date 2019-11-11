#!/bin/bash
#this is the ashs longitudinal script for TOMCAT 
#data should be processed to make a SST beforehand. 
#Processing will be completed for participants with 2 time points and then 3.
#Two versions - V1 : label the template and warp to subject space
# V2 : JLF the template with xs labels and warp back
#15/11/18
#Thomas Shaw

subjName=$1
source ~/.bashrc
#ANTS
export ANTSPATH=~/bin/ants/bin/
PATH=$ANTSPATH:$PATH

mkdir -p /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_3TP /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_1-2 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_3TP /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_1-2 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_v1 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_JLF

export ASHS_ROOT=/data/lfs2/software/tools/ASHS/ashs-fastashs_beta

<<EOF

#label the SSTs in the regular fashion and warp back (i.e., ASHS_LONG)
$ASHS_ROOT/bin/ashs_main.sh -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/ -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_template0.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_3TP/${subjName}_3TP_template1.nii.gz -I ${subjName}_ashs_3TP_SST -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_3TP 

$ASHS_ROOT/bin/ashs_main.sh -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/ -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_2TP_1-2/${subjName}_2TP_1-2_template0.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_2TP_1-2/${subjName}_2TP_1-2_template1.nii.gz -I ${subjName}_ashs_2TP_1-2_SST -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_1-2 

$ASHS_ROOT/bin/ashs_main.sh -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/ -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_2TP_2-3/${subjName}_2TP_2-3_template0.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_2TP_2-3/${subjName}_2TP_2-3_template1.nii.gz -I ${subjName}_ashs_2TP_2-3_SST -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3

EOF

#warp the segmentations back to timepoint space.
for TP in "2TP_2-3" "2TP_1-2" "3TP" ; do
    #warp to TP2 (common)
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/final/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-02_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-02*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-02_*InverseWarp.nii.gz --use-NN 
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-02_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_v1/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.csv
    done
done
for TP in "2TP_2-3" "3TP" ; do
    #warp to TP 3
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/final/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-03*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-03_*InverseWarp.nii.gz --use-NN 
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_v1/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.csv
    done
done
for TP in "2TP_1-2" "3TP" ; do
    #warp to TP 1
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/final/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-01*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-01_*InverseWarp.nii.gz --use-NN 
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_v1/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.csv
    done
done

################
##  ASHS_JLF  ##
################
#3TP

for side in left right ; do
    cd /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_3TP
    /data/home/uqtshaw/bin/ants/bin//antsJointLabelFusion2.sh -d 3 \
							      -c 2 \
							      -j 16 \
							      -t /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_3TP/tse_native_chunk_${side}.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/final/${subjName}_ses-01_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-03_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_3TP/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_3TP/final/${subjName}_ashs_3TP_SST_${side}_lfseg_corr_usegray.nii.gz \
							      -o ${subjName}_long_ashs_JLF_3TP_${side} \
							      -p /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_3TP/posterior%04d.nii.gz \
							      -k 1
done
for side in left right ; do
    cd /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_1-2
    /data/home/uqtshaw/bin/ants/bin//antsJointLabelFusion2.sh -d 3 \
							      -c 2 \
							      -j 16 \
							      -t /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_1-2/tse_native_chunk_${side}.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs/final/${subjName}_ses-01_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_1-2/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_1-2/final/${subjName}_ashs_2TP_1-2_SST_${side}_lfseg_corr_usegray.nii.gz \
							      -o ${subjName}_long_ashs_JLF_2TP_1-2_${side} \
							      -p /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_1-2/posterior%04d.nii.gz \
							      -k 1
done
for side in left right ; do
    cd /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3
    /data/home/uqtshaw/bin/ants/bin//antsJointLabelFusion2.sh -d 3 \
							      -c 2 \
							      -j 16 \
							      -t /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/tse_native_chunk_${side}.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-03_xs_ashs/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_usegray.nii.gz \
							      -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/tse_native_chunk_${side}.nii.gz -l /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/final/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray.nii.gz \
							      -o ${subjName}_long_ashs_JLF_2TP_2-3_${side} \
							      -p /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/posterior%04d.nii.gz \
							      -k 1
done

#warp the segmentations back to timepoint space.
for TP in "2TP_2-3" "2TP_1-2" "3TP" ; do
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_long_ashs_JLF_${TP}_${side}Labels.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-02_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-02*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-02_*InverseWarp.nii.gz --use-NN 
	#gather the volumes
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-02_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_JLF/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.csv
    done
done
for TP in "2TP_2-3" "3TP" ; do
    #warp to TP 3
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_long_ashs_JLF_${TP}_${side}Labels.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-03*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-03_*InverseWarp.nii.gz --use-NN 
	#gather the volumes
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-03_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_JLF/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.csv

    done
done
for TP in "2TP_1-2" "3TP" ; do
    #warp to TP 1
    for side in left right ; do
	WarpImageMultiTransform 3 /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_long_ashs_JLF_${TP}_${side}Labels.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.nii.gz -R /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz -i /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-01*Affine.txt /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/SST_creation/${subjName}_${TP}/${subjName}_${TP}_${subjName}_ses-01_*InverseWarp.nii.gz --use-NN 
	#gather the volumes
	$ASHS_ROOT/ext/Linux/bin/c3d /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_brain_preproc.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/${subjName}_long_ashs_JLF_${TP}/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.nii.gz -lstat >> /data/fasttemp/uqtshaw/tomcat/data/derivatives/4_long_ashs/results/long_ashs_JLF/${subjName}_ashs_${TP}_SST_${side}_lfseg_corr_usegray_warped_to_ses-01.csv
    done
done
