#!/bin/bash

# Script for running ASHS training pipeline
export ASHS_ROOT=/data/lfs2/software/ubuntu14/ashs/ashs-1.0.0_20170915_hacked_version

$ASHS_ROOT/bin/ashs_main.sh -a /data/home/uqtshaw/testing_folder/long_ashs_with_atlas/testing/final -g /data/home/uqtshaw/testing_folder/long_ashs_with_atlas/T_template0.nii.gz -f /data/home/uqtshaw/testing_folder/long_ashs_with_atlas/T_template1.nii.gz -w /data/home/uqtshaw/testing_folder/long_ashs_with_atlas/sub-1001DS_long_ashs_unbiased_atlas_hacked_version -I ashs_unbiased_long_hacked_version
