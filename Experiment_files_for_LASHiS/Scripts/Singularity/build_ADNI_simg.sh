imageName='adni_lashis_simg'
buildDate=`date +%Y%m%d`

#install neurodocker
#pip3 install --no-cache-dir https://github.com/kaczmarj/neurodocker/tarball/master --user

#upgrade neurodocker
pip install --no-cache-dir https://github.com/kaczmarj/neurodocker/tarball/master --upgrade

neurodocker generate docker \
	    --base=neurodebian:stretch-non-free \
	    --pkg-manager apt \
	    --install libxt6 libxext6 libxtst6 libgl1-mesa-glx libc6 libice6 libsm6 libx11-6 \
	    --run="printf '#!/bin/bash\nls -la' > /usr/bin/ll" \
	    --run="chmod +x /usr/bin/ll" \
	    --copy ashs-fastashs_beta /ashs-fastashs_beta \
	    --copy ashs_atlas_upennpmc_20170810 /ashs_atlas_upennpmc_20170810 \
	    --env ASHS_ROOT="/ashs-fastashs_beta" \
	    --freesurfer version=6.0.1 \
	    --ants version=2.3.0 \
	    --copy antsJointLabelFusion2.sh /opt/ants-2.3.0/antsJointLabelFusion2.sh \
	    --copy LASHiS /LASHiS \
	    --workdir /proc_temp \
	    --workdir /90days \
	    --workdir /30days \
	    --workdir /QRISdata \
	    --workdir /RDS \
	    --workdir /data \
	    --workdir /home/neuro \
	    --workdir /TMPDIR \
	    > Dockerfile.${imageName}

#LASHiS is from github repo
#ASHS from NITRC

docker build -t ${imageName}:$buildDate -f  Dockerfile.${imageName} .
#test:
docker run -it ${imageName}:$buildDate

docker tag ${imageName}:$buildDate caid/${imageName}:$buildDate
docker login
docker push caid/${imageName}:$buildDate
docker tag ${imageName}:$buildDate caid/${imageName}:latest
docker push caid/${imageName}:latest

echo "BootStrap:docker" > Singularity.${imageName}
echo "From:caid/${imageName}" >> Singularity.${imageName}

rm ${imageName}_${buildDate}.simg
sudo singularity build ${imageName}_${buildDate}.simg Singularity.${imageName}

#singularity shell --bind $PWD:/data ${imageName}_${buildDate}.simg


