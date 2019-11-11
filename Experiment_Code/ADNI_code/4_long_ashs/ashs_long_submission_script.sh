#!/bin/bash
for subjName in `cat /30days/uqtshaw/subjnames_ses-12.csv` ; do 
	qsub -v SUBJNAME=$subjName ~/scripts/OPTIMEX/4_long_ashs/ashs_long_pbs_script.pbs
done
