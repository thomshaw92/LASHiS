#!/bin/bash
#SBATCH --job-name=long_ashs
#SBATCH -N 1
#SBATCH -n 1             
#SBATCH -c 16 
#SBATCH --partition=wks
#SBATCH --mem=24000
#SBATCH -o slurm.%N.%j.out 
#SBATCH -e slurm.%N.%j.error  
/data/fasttemp/uqtshaw/tomcat/data/4_long_ashs/ashs_JLF_long_script.sh $SUBJNAME

