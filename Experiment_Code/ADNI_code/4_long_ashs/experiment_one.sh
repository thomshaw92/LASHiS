#!/bin/bash
#FS Long, FS XS, ASHS XS, LASHiS, and Diet LASHiS Absolute difference between 2/3
#DICE overlaps between them.
#Thomas Shaw
# 7/2/19

eval=/data/lfs2/software/tools/EvaluateSegmentation/EvaluateSegmentation
evals="-use DICE"
base_dir=/data/fasttemp/uqtshaw/tomcat/data/derivatives/
mkdir $base_dir/4_long_ashs/experiment_one
dir=$base_dir/4_long_ashs/experiment_one


for subjName in `cat /data/fasttemp/uqtshaw/tomcat/data/subjnames.csv ` ; do
    #similarity metrics
    #FS

  

    for side in lh rh ; do
	for ses in 02 03 ; do
	    #convert fs files to nifti
	    mri_convert ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21.mgz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii.nii.gz
	    mri_convert	${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21.mgz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii.nii.gz
	    mri_convert	${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/T1.mgz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/T1_mgz2nii.nii.gz 
	    #mri_convert ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/T1.mgz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/T1_mgz2nii.nii.gz 
	done
	#make all images the same size (no optimisation)
	flirt -in ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii.nii.gz -ref ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii.nii.gz -applyxfm -usesqform -out  ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt.nii.gz
	flirt -in ${base_dir}/freesurfer/${subjName}_03_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii.nii.gz -ref ${base_dir}/freesurfer/${subjName}_02_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii.nii.gz -applyxfm -usesqform -out ${base_dir}/freesurfer/${subjName}_03_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt.nii.gz
	
	#register the TP2 to 3 rigidly for Dice overlaps. 
	flirt -dof 8 -in ${base_dir}/freesurfer/${subjName}_03_7T/mri/T1_mgz2nii.nii.gz -ref ${base_dir}/freesurfer/${subjName}_02_7T/mri/T1_mgz2nii.nii.gz -omat ${base_dir}/freesurfer/${subjName}_03_7T/mri/T1_mgz2nii_03_to_02.mat
	flirt -init ${base_dir}/freesurfer/${subjName}_03_7T/mri/T1_mgz2nii_03_to_02.mat -in ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt.nii.gz -ref ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii.nii.gz -out ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid.nii.gz
	
	#change the name so you can be lazy later
	mv ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii.nii.gz ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt.nii.gz
	mv ${base_dir}/freesurfer/${subjName}_02_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii.nii.gz ${base_dir}/freesurfer/${subjName}_02_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt.nii.gz
	cp ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt.nii.gz ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid.nii.gz

	#split out all relevant subfields
	#FS XS
	for ses in 02 03 ; do 
       	    for subf in 233 234 235 236 237 238 239 240 241 242 243 244 ; do
		fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_${subf}.nii.gz
		fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_${subf}.nii.gz
		fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_${subf}.nii.gz
	    done
	    #Freesurfer XS and Long
	    #Combine together the right ones for the 8 subfields (CA1, 2,DG, SUB)  for left and right
	    #CA1
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_237.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_238.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_CA1.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_237.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_238.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_CA1.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_237.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_238.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA1.nii.gz
	    #CA2/3
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_239.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_240.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_CA2.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_239.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_240.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_CA2.nii.gz
	     fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_239.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_240.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA2.nii.gz
	    #DG
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_241.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_242.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_243.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_244.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_DG.nii.gz
	    
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_241.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_242.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_243.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_244.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_DG.nii.gz

	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_241.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_242.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_243.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_244.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_DG.nii.gz
	    #SUB
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_233.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_234.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_235.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_236.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_SUB.nii.gz
	    
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_233.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_234.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_235.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_236.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_SUB.nii.gz 

	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_233.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_234.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_235.nii.gz -add ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_236.nii.gz ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_SUB.nii.gz
	    #binarise the rigid ones for DICE
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA1.nii.gz -bin ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA1.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA2.nii.gz -bin ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_CA2.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_DG.nii.gz -bin ${base_dir}/freesurfer/${subjName}_${ses}_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_DG.nii.gz
	    fslmaths ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_SUB.nii.gz -bin ${base_dir}/freesurfer/${subjName}_${ses}_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_SUB.nii.gz
	done   
	#FS_LONG
	for subf in CA1 CA2 DG SUB ; do 
	    $eval ${base_dir}/freesurfer/${subjName}_02_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_${subf}.nii.gz ${base_dir}/freesurfer/${subjName}_03_7T.long.${subjName}_2TP_2-3/mri/${side}.hippoAmygLabels-T1.long.v21_mgz2nii_flirt_${subf}.nii.gz $evals -xml $dir/${subjName}_FS_Long_${side}_${subf}_test_retest_dice.xml
	    #FS_XS
	    #$eval ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_${subf}.nii.gz ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_${subf}.nii.gz $evals -xml $dir/${subjName}_FS_Xs_${side}_${subf}_test_retest.xml
	    $eval ${base_dir}/freesurfer/${subjName}_02_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_${subf}.nii.gz ${base_dir}/freesurfer/${subjName}_03_7T/mri/${side}.hippoAmygLabels-T1.v21_mgz2nii_flirt_rigid_${subf}.nii.gz $evals -xml $dir/${subjName}_FS_Xs_${side}_${subf}_test_retest_dice.xml
	done
    done

    #ASHS
    for side in left right ; do
	#make all images the same size
	cp ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz 
	cp  ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz
	cp  ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray.nii.gz
	#(no optimisation)
	flirt -in ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -ref ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -applyxfm -usesqform -out ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt.nii.gz
	###
		
	flirt -in ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -ref ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -applyxfm -usesqform -out ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt.nii.gz
	flirt -in ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray.nii.gz -ref ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray.nii.gz -applyxfm -usesqform -out ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray_flirt.nii.gz
	#rigid registration for XS, and for dice of Long and Diet
	flirt -in ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/mprage.nii.gz -ref ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/mprage.nii.gz -omat ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/mprage_03-02_rigid.mat
	flirt -init ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/mprage_03-02_rigid.mat -in ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray.nii.gz -ref ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray.nii.gz -out ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid.nii.gz
	flirt -init  ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/mprage_03-02_rigid.mat -in ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -ref ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -out ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt_rigid.nii.gz
	flirt -init  ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/mprage_03-02_rigid.mat -in ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03.nii.gz -ref ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz -out ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt_rigid.nii.gz 
	#make them all the same name for laziness

	mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz
	mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz
	mv ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt.nii.gz
	cp ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid.nii.gz
	cp ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt_rigid.nii.gz
	cp ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt_rigid.nii.gz 

	#Threshold out the subfields
	for ses in 02 03 ; do
	    for subf in 1 2 3 4 8 ; do 
		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_${subf}.nii.gz  
		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_${subf}.nii.gz
		fslmaths ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_${subf}.nii.gz
		fslmaths ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_${subf}.nii.gz
		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz

		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid.nii.gz -thr ${subf} -uthr ${subf} ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz
		
	    done
	    #CA1
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_1.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_CA1.nii.gz
	     mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_1.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_CA1.nii.gz
	     mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_1.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_CA1.nii.gz
	     mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_1.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_CA1.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_1.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_CA1.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_1.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_CA1.nii.gz
	    #CA23
	    fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_2.nii.gz -add ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_4.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_CA2.nii.gz
	    fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_2.nii.gz -add ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_4.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_CA2.nii.gz
	    fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_2.nii.gz -add ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_4.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_CA2.nii.gz
	    fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_2.nii.gz -add ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_4.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_CA2.nii.gz 
	    fslmaths ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_2.nii.gz -add ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_4.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_CA2.nii.gz
	    fslmaths ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_2.nii.gz -add ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_4.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_CA2.nii.gz
	    #DG
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_3.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_DG.nii.gz
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_3.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_DG.nii.gz
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_3.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_DG.nii.gz
	     mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_3.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_DG.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_3.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_DG.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_3.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_DG.nii.gz
	    #SUB
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_8.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_SUB.nii.gz
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_8.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_SUB.nii.gz
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_8.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_SUB.nii.gz
	    mv ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_8.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_SUB.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_8.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_SUB.nii.gz
	    mv ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_8.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_SUB.nii.gz

	    #binarise the rigid ones so Dice is soft
	    for subf in CA1 CA2 DG SUB ; do
		fslmaths ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_${subf}.nii.gz -bin ${base_dir}/2_xs_ashs/${subjName}_ses-${ses}_xs_ashs/final/${subjName}_ses-${ses}_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_${subf}.nii.gz
		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz -bin ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz
		fslmaths ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz -bin ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-${ses}_flirt_rigid_${subf}.nii.gz
	    done
	done
	for subf in CA1 CA2 DG SUB ; do 	
	    
	    #LASHiS test retest
	    $eval ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt_rigid_${subf}.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_JLF_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt_rigid_${subf}.nii.gz $evals -xml $dir/${subjName}_LASHiS_${side}_${subf}_test_retest_dice.xml 

	    #Diet LASHiS
	    $eval ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-02_flirt_rigid_${subf}.nii.gz ${base_dir}/4_long_ashs/${subjName}_long_ashs_v1_2TP_2-3/${subjName}_ashs_2TP_2-3_SST_${side}_lfseg_corr_usegray_warped_to_ses-03_flirt_rigid_${subf}.nii.gz $evals -xml $dir/${subjName}_Diet_LASHiS_${side}_${subf}_test_retest_dice.xml 

	    #ASHS Xs
	    #$eval ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt_${subf}.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray_flirt_${subf}.nii.gz $evals -xml $dir/${subjName}_ASHS_Xs_${side}_${subf}_test_retest.xml
	    #ASHS_DICE
	    $eval ${base_dir}/2_xs_ashs/${subjName}_ses-02_xs_ashs/final/${subjName}_ses-02_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_${subf}.nii.gz ${base_dir}/2_xs_ashs/${subjName}_ses-03_xs_ashs/final/${subjName}_ses-03_xs_ashs_${side}_lfseg_corr_nogray_flirt_rigid_${subf}.nii.gz $evals -xml $dir/${subjName}_ASHS_Xs_${side}_${subf}_test_retest_dice.xml 
	done
    done
done
#Concat results
for index in "Dice" "Volume" ; do
    #"Volume" ; do
    #FS
    for subjName in `cat /data/fasttemp/uqtshaw/tomcat/data/subjnames.csv ` ; do
	for subf in CA1 CA2 DG SUB ; do
	    cat $dir/${subjName}_FS_Long_lh_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}FS_Long_left_${subf}_concat.txt
	    cat $dir/${subjName}_FS_Xs_lh_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}FS_Xs_left_${subf}_concat.txt
	    cat $dir/${subjName}_FS_Long_rh_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}FS_Long_right_${subf}_concat.txt
	    cat $dir/${subjName}_FS_Xs_rh_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}FS_Xs_right_${subf}_concat.txt
	done
    done

    #ASHS
    for subjName in `cat /data/fasttemp/uqtshaw/tomcat/data/subjnames.csv ` ; do
	for side in left right ; do
	    for subf in CA1 CA2 DG SUB ; do
		cat $dir/${subjName}_LASHiS_${side}_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}LASHiS_${side}_${subf}_concat.txt
		cat $dir/${subjName}_Diet_LASHiS_${side}_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}Diet_LASHiS_${side}_${subf}_concat.txt
		cat $dir/${subjName}_ASHS_Xs_${side}_${subf}_test_retest_dice.xml | grep ${index} | sed 's/[^0-9.]*//g' >> $dir/${index}ASHS_Xs_${side}_${subf}_concat.txt
	    done
	done
    done
    for side in left right ; do
	for subf in CA1 CA2 DG SUB ; do
	    cat $dir/${index}FS_Long_${side}_${subf}_concat.txt >> ${index}ALL_${side}_${subf}.txt
	    cat $dir/${index}FS_Xs_${side}_${subf}_concat.txt >> ${index}ALL_${side}_${subf}.txt
	    cat $dir/${index}LASHiS_${side}_${subf}_concat.txt >> ${index}ALL_${side}_${subf}.txt
	    cat $dir/${index}Diet_LASHiS_${side}_${subf}_concat.txt >> ${index}ALL_${side}_${subf}.txt
	    cat $dir/${index}ASHS_Xs_${side}_${subf}_concat.txt >> ${index}ALL_${side}_${subf}.txt
	done
    done
    #paste ${index}ALL_left_CA1.txt ${index}ALL_left_CA2.txt ${index}ALL_left_DG.txt ${index}ALL_left_SUB.txt ${index}ALL_right_CA1.txt ${index}ALL_right_CA2.txt ${index}ALL_right_DG.txt ${index}ALL_right_SUB.txt | column -s $'\t' -t >> ${index}_final.txt
    paste ${index}ALL_left_CA1.txt ${index}ALL_left_CA2.txt ${index}ALL_left_DG.txt ${index}ALL_left_SUB.txt ${index}ALL_right_CA1.txt ${index}ALL_right_CA2.txt ${index}ALL_right_DG.txt ${index}ALL_right_SUB.txt | column -s $'\t' -t >> $dir/${index}_final.txt
done

