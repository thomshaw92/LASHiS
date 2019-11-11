#!/bin/bash
for subjName in sub-JH09 sub-RP02 sub-SF01 sub-SB08 sub-SB16 sub-NM18 sub-NF14 ; do 
#`cat /data/fasttemp/uqtshaw/tomcat/data/subjnames.csv` ; do 
    sbatch --export=SUBJNAME=$subjName /data/fasttemp/uqtshaw/tomcat/data/5_freesurfer/recon-all_hsf_and_long_proc_pbs_script.sh 
done
