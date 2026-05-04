#!/bin/bash
for subjName in `cat ADNI_SUBJNAMES.csv` ; do 
	qsub -v SUBJNAME=$subjName /path/to/1_preprocessing/pp_pbs_script.pbs
done
