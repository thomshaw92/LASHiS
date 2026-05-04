## Singularity/Docker recipe 

This script is the Singularity recipe for the entire LASHiS pipeline. The actual Docker container is hosted via:

docker pull caid/adni_lashis_simg

or 

singularity build LASHiS.simg docker://caid/adni_lashis_simg:latest
