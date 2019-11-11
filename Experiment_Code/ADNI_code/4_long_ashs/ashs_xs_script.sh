#!/bin/bash
#NB This isn't parallelised. But it will run 3 at a time.
for subjName in sub-NM18 ; do
    export ASHS_ROOT=/data/lfs2/software/tools/ASHS/ashs-fastashs_beta
    mkdir -p /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs
	for x in 02 03 ; do
	$ASHS_ROOT/bin/ashs_main.sh -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/ -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-${x}_7T_T1w_N4corrected_norm_brain_preproc.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-${x}_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz -I ${subjName}_ses-${x}_xs_ashs -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-${x}_xs_ashs &
	done
	#$ASHS_ROOT/bin/ashs_main.sh -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_upennpmc_20170810/ -g /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T1w_N4corrected_norm_brain_ses-02-space_preproc.nii.gz -f /data/fasttemp/uqtshaw/tomcat/data/derivatives/preprocessing/${subjName}/${subjName}_ses-01_7T_T2w_NlinMoCo_res-iso.3_N4corrected_denoised_norm_brain_preproc.nii.gz -I ${subjName}_ses-01_xs_ashs -w /data/fasttemp/uqtshaw/tomcat/data/derivatives/2_xs_ashs/${subjName}_ses-01_xs_ashs 
done

