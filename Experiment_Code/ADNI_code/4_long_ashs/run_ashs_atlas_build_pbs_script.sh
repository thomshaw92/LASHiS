#!/bin/bash
#SBATCH --job-name=atlas_long_ashs
#SBATCH -N 1
#SBATCH -n 1             
#SBATCH -c 4 
#SBATCH --partition=all
#SBATCH --exclusive
#SBATCH --mem=12000
#SBATCH -o slurm.%N.%j.out 
#SBATCH -e slurm.%N.%j.error  
/data/fasttemp/uqtshaw/tomcat/data/4_long_ashs/run_ashs_atlas_build_script.sh $SUBJNAME

