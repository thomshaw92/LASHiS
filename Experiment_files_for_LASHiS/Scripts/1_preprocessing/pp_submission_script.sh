#!/bin/bash
for subjName in `cat /RDS/Q0747/ADNI_BIDS/LASHiS/Experiment_Code/ADNI_code/ADNI_SUBJNAMES.csv` ; do 
	qsub -v SUBJNAME=$subjName /RDS/Q0747/ADNI_BIDS/LASHiS/Experiment_Code/ADNI_code/1_preprocessing/pp_pbs_script.pbs
done
