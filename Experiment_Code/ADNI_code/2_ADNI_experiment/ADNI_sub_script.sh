#!/bin/bash

for subjName in `cat /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/subjnames_2_ses.csv` ; do 
qsub -v SUBJNAME=$subjName /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/2_ADNI_experiment/ADNI_LASHiS_pbs_script_2_ses.pbs	
qsub -v SUBJNAME=$subjName /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/2_ADNI_experiment/ADNI_freesurfer_script_2_ses.pbs
done
for subjName in `cat /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/subjnames_3_ses.csv` ; do 
qsub -v SUBJNAME=$subjName /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/2_ADNI_experiment/ADNI_LASHiS_pbs_script_3_ses.pbs
qsub -v SUBJNAME=$subjName /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/2_ADNI_experiment/ADNI_freesurfer_script_3_ses.pbs
done
