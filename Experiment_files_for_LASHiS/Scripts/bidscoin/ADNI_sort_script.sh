#!/bin/bash
#
ADNI_DATA=/data/fasttemp/uqtshaw/ADNI_data/ADNI/ADNI_data_test/

#mv all the first folders in the MPRAGE (always has Accelerated)  and Hippo (always says Hippo)
#first delete all the sequence folders with only one time point (they aren't needed)
for x in `ls ${ADNI_DATA}` ; do
    cd ${ADNI_DATA}/${x}
    files=( * )
    if [[ ${#files[@]} -lt 2 ]] ; then
	rm -r  ${ADNI_DATA}/${x}
    fi
    #then do the same for both the hippocampus files and mprage folders
    cd ${ADNI_DATA}/${x}/*Accelerated*
    files=( * )
    if [[ ${#files[@]} -lt 2 ]] ; then
	rm -r  ${ADNI_DATA}/${x}
    fi
    cd ${ADNI_DATA}/${x}/*ippo*
    files=( * )
    if [[ ${#files[@]} -lt 2 ]] ; then
	rm -r  ${ADNI_DATA}/${x}
    fi
    #Create session directories for each participant (assume 3, most have 2)
    mkdir ${ADNI_DATA}/${x}/ses-01 ${ADNI_DATA}/${x}/ses-02 ${ADNI_DATA}/${x}/ses-03
    #Then move the first file in the hippo folders to the ses-01 folder and so on
    #then move all the files out of the weird named subdirectory
    cd ${ADNI_DATA}/${x}/*ippo*
    mv `ls ./ | head -n 1 ` ${ADNI_DATA}/${x}/ses-01/hippo_scan
    mv ${ADNI_DATA}/${x}/ses-01/hippo_scan/*/* ${ADNI_DATA}/${x}/ses-01/hippo_scan/
    mv `ls ./ | head -n 1 ` ${ADNI_DATA}/${x}/ses-02/hippo_scan
    mv ${ADNI_DATA}/${x}/ses-02/hippo_scan/*/* ${ADNI_DATA}/${x}/ses-02/hippo_scan/
    if ls ./* 1> /dev/null 2>&1; then
	mv `ls ./` ${ADNI_DATA}/${x}/ses-03/hippo_scan
	mv ${ADNI_DATA}/${x}/ses-03/hippo_scan/*/* ${ADNI_DATA}/${x}/ses-03/hippo_scan/
    else
	echo "no tp 3 for ${x}" >> ${ADNI_DATA}/no_TP3.txt
	rm -r ${ADNI_DATA}/${x}/ses-03/
    fi
    #same for MPRAGE
    cd ${ADNI_DATA}/${x}/*ccelerated*
    mv `ls ./ | head -n 1 ` ${ADNI_DATA}/${x}/ses-01/MPRAGE
    mv ${ADNI_DATA}/${x}/ses-01/MPRAGE/*/* ${ADNI_DATA}/${x}/ses-01/MPRAGE/
    mv `ls ./ | head -n 1 ` ${ADNI_DATA}/${x}/ses-02/MPRAGE
    mv ${ADNI_DATA}/${x}/ses-02/MPRAGE/*/* ${ADNI_DATA}/${x}/ses-02/MPRAGE/
    if ls ./* 1> /dev/null 2>&1; then
	mv `ls ./` ${ADNI_DATA}/${x}/ses-03/MPRAGE
	mv ${ADNI_DATA}/${x}/ses-03/MPRAGE/*/* ${ADNI_DATA}/${x}/ses-03/MPRAGE/
    else
	echo "no tp 3 for ${x}" 
    fi
done
