#!/bin/bash
#Thomas Shaw 29/10/19
#preprocessing of ADNI data (PBS submission)
#skull strip t1/tse, bias correct, normalise, interpolate
#data should be in BIDS format - I only downloaded the T1w and HighResHippo for each participant
#If multiple runs exist I use the second run, majority are repeats due to movement.

subjName=$1
for ss in "ses-01" "ses-02" "ses-03" ; do
    source ~/.bashrc
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4
    export NSLOTS=4
    echo $TMPDIR

    ########################################
    raw_data_dir=/path/to/bids_dir
    ########################################
    ##############################	
    data_dir=/path/to/working/dir
    #############################
    
    cp -r $raw_data_dir/${subjName}/${ss}/anat $TMPDIR
    chmod -R 740 $TMPDIR/anat
    mkdir -p $TMPDIR/derivatives/preprocessing/$subjName
    chmod -R 740 $TMPDIR/derivatives
    rsync -v -r $TMPDIR/anat/${subjName}_${ss}*T2w*.nii.gz $TMPDIR/derivatives/preprocessing/$subjName
    rsync -v -r $TMPDIR/anat/${subjName}_${ss}*T1w*.nii.gz $TMPDIR/derivatives/preprocessing/$subjName
    module load singularity/2.5.1
    singularity="singularity exec --bind $TMPDIR:/TMPDIR --pwd /TMPDIR/ $data_dir/ants_fsl_robex_20180427.simg" #this is the name of the singularity image defined elsewhere
    bidsdir=/TMPDIR
    t1w=$bidsdir/derivatives/preprocessing/$subjName/${subjName}_${ss}_T1w.nii.gz
    tse=$bidsdir/derivatives/preprocessing/$subjName/${subjName}_${ss}*T2w*.nii.gz

    deriv=/$bidsdir/derivatives
    mkdir -p $data_dir/derivatives/preprocessing/${subjName}/

    #initial skull strip
    $singularity runROBEX.sh $t1w $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brain_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz
    #bias correct t1
    $singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $t1w -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz --verbose 1 -s 2
    if [[ ! -e $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz ]] ; then
	$singularity CopyImageHeaderInformation $t1w $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz
	$singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz $t1w
	$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $t1w -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz --verbose 1 -s 2
    fi
    #normalise t1
    t1bc=$deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz
    $singularity ~/scripts/niifti_normalise.sh -i $t1bc -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_preproc.nii.gz
    #skull strip new Bias corrected T1
    $singularity runROBEX.sh $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_brain_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz
    #remove things
    rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T1w_brain_preproc.nii.gz
    rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz
    rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz

    ######TSE#####
    #apply mask to tse - resample like tse - this is just for BC
    $singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $tse -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz

    #Bias correction - use mask created - 
    
    #N4
    $singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i ${tse} -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz --verbose 1 -s 2 
    if [[ ! -e $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz ]] ; then
	#copy header info to make sure bc works
	$singularity CopyImageHeaderInformation ${tse} $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz
	$singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz ${tse} 
	$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i ${tse} -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz --verbose 1 -s 2
    fi
    
    #second pass just in case - mask -to - tse
    if [[ ! -e $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz ]] ; then
	#copy header info to make sure bc works 
	$singularity CopyImageHeaderInformation $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz ${tse} ${tse} 
	$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i  ${tse} -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz --verbose 1 -s 2
    fi 
    #normalise intensities of the BC'd tses
    $singularity ~/scripts/niifti_normalise.sh -i $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_norm_preproc.nii.gz

    #interpolation of TSEs -bring all into the same space while minimising interpolation write steps. -Set to 0.5 iso for ADNI 
    $singularity flirt -v -applyisoxfm 0.5 -interp sinc -sincwidth 8 -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_norm_preproc.nii.gz -ref $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_norm_preproc.nii.gz -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz

    #create new brainmask and brain images. 
    $singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz
    rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_norm_preproc.nii.gz 


    #mask the preprocessed TSE.
    $singularity fslmaths $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz -mul $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_brain_preproc.nii.gz
    if [[ ! -e $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_brain_preproc.nii.gz ]] ; then 
	$singularity CopyImageHeaderInformation $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz
	$singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz
	$singularity fslmaths $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_preproc.nii.gz -mul $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_res-iso.5_N4corrected_norm_brain_preproc.nii.gz
	# rm brainmasks and other crap
	chmod -R 744 $TMPDIR/
	rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_brainmask.nii.gz
	rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_norm_preproc.nii.gz
	rm $TMPDIR/derivatives/preprocessing/$subjName/${subjName}_${ss}_T2w_N4corrected_preproc.nii.gz
    fi

    #ses loop VV
done
#move back out of TMPDIR... (from RDS - the raw files are still included, need to sort this)
cd $TMPDIR/derivatives/preprocessing/
chmod -R 740 $TMPDIR/derivatives/preprocessing
mkdir -p $raw_data_dir/derivatives/preprocessing/$subjName
rsync -c -v -r ./${subjName}/* $raw_data_dir/derivatives/preprocessing/$subjName
rm $raw_data_dir/derivatives/preprocessing/$subjName/*_N4corrected_preproc.nii.gz
rm $raw_data_dir/derivatives/preprocessing/$subjName/*_tse.nii.gz
rm $raw_data_dir/derivatives/preprocessing/$subjName/*T1w.nii.gz
echo "done PP for $subjName"

