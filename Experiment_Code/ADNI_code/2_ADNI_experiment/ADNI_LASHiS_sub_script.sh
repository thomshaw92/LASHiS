#!/bin/bash
for subjName in `cat /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/subjnames_2_ses.csv` ; do 
	qsub -v SUBJNAME=$subjName /RDS/Q0747/ADNI_BIDS/LASHiS/Experiment_Code/ADNI_code/1_preprocessing/pp_pbs_script.pbs
done
for subjName in `cat /home/uqtshaw/LASHiS/Experiment_Code/ADNI_code/subjnames_3_ses.csv` ; do 
	qsub -v SUBJNAME=$subjName /RDS/Q0747/ADNI_BIDS/LASHiS/Experiment_Code/ADNI_code/1_preprocessing/pp_pbs_script.pbs
done
