#!/bin/bash
for subjName in `cat /data/fasttemp/uqtshaw/tomcat/data/subjnames.csv` ; do 
    sbatch --export=SUBJNAME=$subjName /data/fasttemp/uqtshaw/tomcat/data/5_freesurfer/recon-all_pbs_script.sh
done
