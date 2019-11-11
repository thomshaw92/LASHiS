#!/bin/bash
#SBATCH --job-name=recon-all
#SBATCH -N 1
#SBATCH -n 1             
#SBATCH -c 16 
#SBATCH --partition=long
#SBATCH --mem=32000
#SBATCH -o slurm.%N.%j.out 
#SBATCH -e slurm.%N.%j.error  

/data/fasttemp/uqtshaw/tomcat/data/5_freesurfer/recon-all_script.sh $SUBJNAME

