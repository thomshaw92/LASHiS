#/bin/bash
subjName=$1
export FREESURFER_HOME=/data/lfs2/software/tools/freesurfer-6.0/
source $FREESURFER_HOME/SetUpFreeSurfer.sh
SUBJECTS_DIR=/data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer

#which flirt
#flirt -in /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-01_7T/anat/${subjName}_ses-01_7T_T1w.nii.gz -ref /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-02_7T/anat/${subjName}_ses-02_7T_T1w.nii.gz -applyxfm -usesqform -out /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-01_7T/anat/${subjName}_ses-01_7T_T1w_TP2_space.nii.gz


#recon-all -subjid ${subjName}_01_7T -autorecon1 -i /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-01_7T/anat/${subjName}_ses-01_7T_T1w_TP2_space.nii.gz -openmp 4 -cm 

#recon-all -subjid ${subjName}_02_7T -autorecon1 -i /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-02_7T/anat/${subjName}_ses-02_7T_T1w.nii.gz -openmp 4 -cm 
#recon-all -subjid ${subjName}_03_7T -autorecon1 -i /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-03_7T/anat/${subjName}_ses-03_7T_T1w.nii.gz -openmp 4 -cm
#recon-all -subjid ${subjName}_02_3T -autorecon1 -i /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-02_3T/anat/${subjName}_ses-02_3T_T1w.nii.gz -openmp 4 -t2 /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-02_3T/anat/${subjName}_ses-02_3T_T2w_space.nii.gz -3T 

for ss in 01_7T ; do #02_3T 02_7T 03_7T ; do
	mri_convert /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/orig.mgz /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/orig_mgz2nii.nii.gz
	/data/lfs2/software/tools/ROBEX/ROBEX/runROBEX.sh /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/orig_mgz2nii.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brain_robex.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brainmask_robex.nii.gz
	mri_convert /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brain_robex.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brainmask.mgz
	mri_convert /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brain_robex.nii.gz /data/fasttemp/uqtshaw/tomcat/data/derivatives/freesurfer/${subjName}_${ss}/mri/brain.mgz

done

recon-all -subjid ${subjName}_01_7T -autorecon2 -autorecon3 -cm -no-isrunning  

#nohup recon-all -subjid ${subjName}_02_7T -autorecon2 -autorecon3 -cm -no-isrunning  &
#nohup recon-all -subjid ${subjName}_03_7T -autorecon2 -autorecon3 -cm -no-isrunning  
#nohup recon-all -subjid ${subjName}_02_3T -autorecon2 -autorecon3 -t2 /data/fasttemp/uqtshaw/tomcat/data/${subjName}/ses-02_3T/anat/${subjName}_ses-02_3T_T2w_space.nii.gz -3T -no-isrunning 

  
