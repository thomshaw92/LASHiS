#!/bin/bash

VERSION="0.0"

# Check dependencies

PROGRAM_DEPENDENCIES=( 'antsApplyTransforms' 'N4BiasFieldCorrection' )
SCRIPTS_DEPENDENCIES=( 'antsBrainExtraction.sh' 'antsMultivariateTemplateConstruction2.sh' 'antsJointLabelFusion2.sh' )
ASHS_DEPENDENCIES=( '/bin/ashs_main.sh' '/ext/Linux/bin/c3d' )

for D in ${PROGRAM_DEPENDENCIES[@]};
  do
    if [[ ! -s ${ANTSPATH}/${D} ]];
      then
        echo "Error:  we can't find the $D program."
        echo "Perhaps you need to \(re\)define \$ANTSPATH in your environment."
        exit
      fi
  done

for D in ${SCRIPT_DEPENDENCIES[@]};
  do
    if [[ ! -s ${ANTSPATH}/${D} ]];
      then
        echo "We can't find the $D script."
        echo "Perhaps you need to \(re\)define \$ANTSPATH in your environment."
        exit
      fi
  done
for D in ${ASHS_DEPENDENCIES[@]};
  do
    if [[ ! ${ASHS_ROOT}/bin/${D} ]];
      then
        echo "We can't find $D in the ASHS directory ."
        echo "Perhaps you need to \(re\)define \$ASHS_ROOT in your environment."
        exit
      fi
  done
function Usage {
    cat <<USAGE

`basename $0` performs a longitudinal estimation of hippoocampus subfields.  The following steps are performed:
  1. Run Cross-sectional ASHS on all timepoints
  2. Create a single-subject template (SST) from all the data
  3. Using the Cross-sectional inputs as priors, we label the hippocampi of the SST.
  4. Segmentation results are reverse normalised to the individual time-point. 

Usage:

`basename $0` -a atlas selection for ashs
              <OPTARGS>
              -o outputPrefix
              \${anatomicalImages[@]}

Example:

  bash $0 -a ashs_atlas_umcutrecht_7t_20170810/ -o output \${anatomicalImages[@]}

Required arguments:

     
     -o:  Output prefix                         The following subdirectory and images are created for the single
                                                subject template
                                                  * \${OUTPUT_PREFIX}SingleSubjectTemplate/
                                                  * \${OUTPUT_PREFIX}SingleSubjectTemplate/T_template*.nii.gz

     anatomical images                          Set of multimodal (T1w or gradient echo, followed by T2w FSE/TSE input)
                                                data. Data must be in the format specified by ASHS & ordered as follows:
                                                  \${time1_T1w} \${time1_T2w} \\
                                                  \${time2_T1w} \${time2_T2w} ...
                                                  .
                                                  .
                                                  .
                                                   \${timeN_T1w} \${timeN_T2w} ...

					

Optional arguments:

     -s:  image file suffix                     Any of the standard ITK IO formats e.g. nrrd, nii.gz (default), mhd
     -c:  control type                          Control for parallel computation (default 0):
                                                  0 = run serially
                                                  1 = SGE qsub
                                                  2 = use PEXEC (localhost)
                                                  3 = Apple XGrid
                                                  4 = PBS qsub
                                                  5 = SLURM
     
     -g:  denoise anatomical images             Denoise anatomical images (default = 0).
     -j:  number of cpu cores                   Number of cpu cores to use locally for pexec option (default 2; requires "-c 2")
    
     -q:  Use quick ("Diet") LASHiS             If 'yes' then we use antsRegistrationSyNQuick.sh as the basis for registration.
                                                Otherwise use antsRegistrationSyN.sh.  The options are as follows:
                                                '-q 0' = antsRegistrationSyN for everything (default)
                                                '-q 1' = Fast antsCorticalThickness to SST
                                                '-q 2' = Fast JLF cooking
                                                '-q 3' = Fast everything

     -n:  N4 Bias Correction                    If yes, Bias correct the input images before template creation.
                                                0 = No
                                                1 = Yes
     
     -b:  keep temporary files                  Keep brain extraction/segmentation warps, etc (default = 0).
     
     -z:  Test / debug mode                     If > 0, runs a faster version of the script. Only for testing. Implies -u 0
                                                in the antsCorticalThickness.sh script (i.e., no random seeding).
                                                Requires single thread computation for complete reproducibility.
USAGE
    exit 1
}

echoParameters() {
    cat <<PARAMETERS

    Using LASHiS with the following arguments:
      image dimension         = ${DIMENSION}
      anatomical image        = ${ANATOMICAL_IMAGES[@]}
     
      output prefix           = ${OUTPUT_PREFIX}
      output image suffix     = ${OUTPUT_SUFFIX}
     
    Other parameters:
      run quick               = ${RUN_QUICK}
      debug mode              = ${DEBUG_MODE}
      float precision         = ${USE_FLOAT_PRECISION}
      denoise                 = ${DENOISE}
      use random seeding      = ${USE_RANDOM_SEEDING}
      number of modalities    = ${NUMBER_OF_MODALITIES}
      number of cores         = ${CORES}
      control type            = ${DOQSUB}
      rigid alignment to SST  = ${RIGID_ALIGNMENT_TO_SST}
      average rigid component = ${AFFINE_UPDATE_FULL}

PARAMETERS
}

# Echos a command to stdout, then runs it
# Will immediately exit on error unless you set debug flag here
DEBUG_MODE=0

function logCmd() {
  cmd="$*"
  echo "BEGIN >>>>>>>>>>>>>>>>>>>>"
  echo $cmd
  $cmd

  cmdExit=$?

  if [[ $cmdExit -gt 0 ]];
    then
      echo "ERROR: command exited with nonzero status $cmdExit"
      echo "Command: $cmd"
      echo
      if [[ ! $DEBUG_MODE -gt 0 ]];
        then
          exit 1
        fi
    fi

  echo "END   <<<<<<<<<<<<<<<<<<<<"
  echo
  echo

  return $cmdExit
}

################################################################################
#
# Main routine
#
################################################################################

HOSTNAME=`hostname`
DATE=`date`

CURRENT_DIR=`pwd`/
OUTPUT_DIR=${CURRENT_DIR}/tmp$RANDOM/
OUTPUT_PREFIX=${OUTPUT_DIR}/tmp
OUTPUT_SUFFIX="nii.gz"

DIMENSION=3

NUMBER_OF_MODALITIES=2

ANATOMICAL_IMAGES=()
RUN_QUICK=1
USE_RANDOM_SEEDING=1


USE_SST_CORTICAL_THICKNESS_PRIOR=0
REGISTRATION_TEMPLATE=""
DO_REGISTRATION_TO_TEMPLATE=0
DENOISE=0


DOQSUB=0
CORES=2


################################################################################
#
# Programs and their parameters
#
################################################################################

USE_FLOAT_PRECISION=0
KEEP_TMP_IMAGES=0

if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:j:k:l:m:n:o:p:q:r:s:t:u:v:x:w:y:z:" OPT
    do
      case $OPT in
          a)
       ASHS_ATLAS=$OPTARG
       ;;
          b)
       KEEP_TMP_IMAGES=$OPTARG
       ;;
          c)
       DOQSUB=$OPTARG
       if [[ $DOQSUB -gt 5 ]];
         then
           echo " DOQSUB must be an integer value (0=serial, 1=SGE qsub, 2=try pexec, 3=XGrid, 4=PBS qsub, 5=SLURM ) you passed  -c $DOQSUB "
           exit 1
         fi
       ;;
          g) #denoise
       DENOISE=$OPTARG
       ;;
	  n) #N4
       N4_BIAS_CORRECTION=$OPTARG
       ;;
          h) #help
       Usage >&2
       exit 0
       ;;
          j) #number of cpu cores to use (default = 2)
       CORES=$OPTARG
       ;;
          o) #output prefix
       OUTPUT_PREFIX=$OPTARG
       ;;
          q) # run quick
       RUN_QUICK=$OPTARG
       ;;
	  #ASHS PARAMETERS:

	  ###########################
	  ###########################

	  
          z) #debug mode
       DEBUG_MODE=$OPTARG
       ;;
          *) # getopts issues an error message
       echo "ERROR:  unrecognized option -$OPT $OPTARG"
       exit 1
       ;;
      esac
  done
fi

#FORMAT=${SEGMENTATION_PRIOR}
#PREFORMAT=${FORMAT%%\%*}
#POSTFORMAT=${FORMAT##*d}
#FORMAT=${FORMAT#*\%}
#FORMAT=${FORMAT%%d*}

#REPCHARACTER=''
#TOTAL_LENGTH=0
#if [ ${#FORMAT} -eq 2 ]
#  then
#    REPCHARACTER=${FORMAT:0:1}
#    TOTAL_LENGTH=${FORMAT:1:1}
#  fi

# MAXNUMBER=$(( 10 ** $TOTAL_LENGTH ))
MAXNUMBER=1000

#PRIOR_IMAGE_FILENAMES=()
#WARPED_PRIOR_IMAGE_FILENAMES=()
#BRAIN_SEGMENTATION_OUTPUT=${OUTPUT_PREFIX}BrainSegmentation
#SEGMENTATION_WARP_OUTPUT_PREFIX=${BRAIN_SEGMENTATION_OUTPUT}Prior
#SEGMENTATION_PRIOR_WARPED=${SEGMENTATION_WARP_OUTPUT_PREFIX}Warped
############
#for (( i = 1; i < $MAXNUMBER; i++ ))
#  do
#    NUMBER_OF_REPS=$(( $TOTAL_LENGTH - ${#i} ))
#    ROOT='';
#    for(( j=0; j < $NUMBER_OF_REPS; j++ ))
#      do
#        ROOT=${ROOT}${REPCHARACTER}
#      done
#    FILENAME=${PREFORMAT}${ROOT}${i}${POSTFORMAT}
#    WARPED_FILENAME=${SEGMENTATION_PRIOR_WARPED}${ROOT}${i}.${OUTPUT_SUFFIX}
#    if [[ -f $FILENAME ]];
#      then
#        PRIOR_IMAGE_FILENAMES=( ${PRIOR_IMAGE_FILENAMES[@]} $FILENAME )
#        WARPED_PRIOR_IMAGE_FILENAMES=( ${WARPED_PRIOR_IMAGE_FILENAMES[@]} $WARPED_FILENAME )
#      else
#        break 1
#      fi
#  done

#NUMBER_OF_PRIOR_IMAGES=${#WARPED_PRIOR_IMAGE_FILENAMES[*]}

# Shiftsize is calculated because a variable amount of arguments can be used on the command line.
# The shiftsize variable will give the correct number of arguments to skip. Issuing shift $shiftsize will
# result in skipping that number of arguments on the command line, so that only the input images remain.
shiftsize=$(($OPTIND - 1))
shift $shiftsize
# The invocation of $* will now read all remaining arguments into the variable IMAGESETVARIABLE
IMAGESETVARIABLE=$*
NINFILES=$(($nargs - $shiftsize))
IMAGESETARRAY=()

for IMG in $IMAGESETVARIABLE
  do
    ANATOMICAL_IMAGES[${#ANATOMICAL_IMAGES[@]}]=$IMG
done
if [[ ${#ANATOMICAL_IMAGES[@]} -eq 0 ]];
  then
    echo "Error:  no anatomical images specified."
    exit 1
  fi
echo "--------------------------------------------------------------------------------------"
echo " ASHS cross-sectional using the following ${NUMBER_OF_MODALITIES}-tuples:  "
echo "--------------------------------------------------------------------------------------"
for (( i = 0; i < ${#ANATOMICAL_IMAGES[@]}; i+=$NUMBER_OF_MODALITIES ))
do
    IMAGEMETRICSET=""
    for (( j = 0; j < $ANATOMICAL_IMAGES; j++ ))
    do
        k=0
        let k=$i+$j
        IMAGEMETRICSET="$IMAGEMETRICSET ${ANATOMICAL_IMAGES[$k]}"
    done
    echo $IMAGEMETRICSET
   
done
echo "--------------------------------------------------------------------------------------"



# Set up various things related to RUN_QUICK

# Can't do everything fast and still get good results if there is large deformation.
# Initiate levels of fast:

# 0 - Fast SST (old ANTS) but everything else slower for quality
# 1 - + Fast antsct to SST
# 2 - + Fast MALF cooking
# 3 - + Fast everything

RUN_OLD_ANTS_SST_CREATION=1
RUN_ANTSCT_TO_SST_QUICK=0
RUN_FAST_MALF_COOKING=0
RUN_FAST_ANTSCT_TO_GROUP_TEMPLATE=0

if [[ $RUN_QUICK -gt 0 ]];
  then
    RUN_ANTSCT_TO_SST_QUICK=1
  fi

if [[ $RUN_QUICK -gt 1 ]];
  then
    RUN_FAST_MALF_COOKING=1
  fi

if [[ $RUN_QUICK -gt 2 ]];
  then
    RUN_FAST_ANTSCT_TO_GROUP_TEMPLATE=1
  fi

################################################################################
#
# Preliminaries:
#  1. Check existence of inputs
#  2. Figure out output directory and mkdir if necessary
#
################################################################################

for (( i = 0; i < ${#ANATOMICAL_IMAGES[@]}; i++ ))
  do
  if [[ ! -f ${ANATOMICAL_IMAGES[$i]} ]];
    then
      echo "The specified image \"${ANATOMICAL_IMAGES[$i]}\" does not exist."
      exit 1
    fi
  done

OUTPUT_DIR=${OUTPUT_PREFIX%\/*}
if [[ ! -d $OUTPUT_DIR ]];
  then
    echo "The output directory \"$OUTPUT_DIR\" does not exist. Making it."
    mkdir -p $OUTPUT_DIR
  fi

echoParameters >&2

echo "---------------------  Running `basename $0` on $HOSTNAME  ---------------------"

time_start=`date +%s`

################################################################################
#
# Single-subject template creation
#
################################################################################

echo
echo "--------------------------------------------------------------------------------------"
echo " Creating single-subject template                                                     "
echo "--------------------------------------------------------------------------------------"
echo

TEMPLATE_MODALITY_WEIGHT_VECTOR='1'
for(( i=1; i < 2; i++ ))
  do
    TEMPLATE_MODALITY_WEIGHT_VECTOR="${TEMPLATE_MODALITY_WEIGHT_VECTOR}x1"
  done

TEMPLATE_Z_IMAGES=''

OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE="${OUTPUT_PREFIX}SingleSubjectTemplate/"

logCmd mkdir -p ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}

# Pad initial template image to avoid problems with SST drifting out of FOV
for(( i=0; i < '2'; i++ ))
  do
    TEMPLATE_INPUT_IMAGE="${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}initTemplateModality${i}.nii.gz"

    logCmd ${ANTSPATH}/ImageMath 3 ${TEMPLATE_INPUT_IMAGE} PadImage ${ANATOMICAL_IMAGES[$i]} 5

    TEMPLATE_Z_IMAGES="${TEMPLATE_Z_IMAGES} -z ${TEMPLATE_INPUT_IMAGE}"
  done


SINGLE_SUBJECT_TEMPLATE=${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_template0.nii.gz

time_start_sst_creation=`date +%s`

if [[ ! -f $SINGLE_SUBJECT_TEMPLATE ]];
  then
        logCmd ${ANTSPATH}/antsMultivariateTemplateConstruction.sh \
          -d 3 \
          -o ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_ \
          -b 0 \
          -g 0.25 \
          -i 4 \
          -c ${DOQSUB} \
          -j ${CORES} \
          -k '2' \
          -w ${TEMPLATE_MODALITY_WEIGHT_VECTOR} \
          -m 100x70x30x3  \
          -n ${N4_BIAS_CORRECTION} \
          -r 1 \
          -s CC \
          -t GR \
          -y ${AFFINE_UPDATE_FULL} \
          -r 1
          ${ANATOMICAL_IMAGES[@]}
fi

if [[ ! -f ${SINGLE_SUBJECT_TEMPLATE} ]];
  then
    echo "Error:  The single subject template was not created.  Exiting."
    exit 1
  fi

# clean up

SINGLE_SUBJECT_ANTSCT_PREFIX=${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/T_template
###############################
##  Label the SST with ASHS  ##
###############################

logCmd ${ASHS_ROOT}/bin/ashs_main.sh \
       -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_umcutrecht_7t_20170810/ \
       -a ${ASHS_ATLAS} \
       -g ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/T_template0.nii.gz \
       -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/T_template1.nii.gz \
       -w ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/SST_ASHS
#FIXME-other options to be included


logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}job*.sh
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}job*.txt
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}rigid*
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}*Repaired*
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}*WarpedToTemplate*
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_template0warp.nii.gz
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_template0Affine.txt
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_templatewarplog.txt
logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}initTemplateModality*.nii.gz

# Also remove the warp files but we have to be careful to not remove the affine and
# warp files generated in subsequent steps (specifically from running the SST through
# the cortical thickness pipeline if somebody has to re-run the longitudinal pipeline

if [[ -f ${SINGLE_SUBJECT_ANTSCT_PREFIX}SubjectToTemplate1Warp.nii.gz ]];
  then

    logCmd mkdir -p ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/TmpFiles/
    logCmd mv -f ${SINGLE_SUBJECT_ANTSCT_PREFIX}SubjectToTemplate1*Warp.nii.gz \
                 ${SINGLE_SUBJECT_ANTSCT_PREFIX}SubjectToTemplate0GenericAffine.mat \
                 ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/TmpFiles/
    logCmd mv -f ${SINGLE_SUBJECT_ANTSCT_PREFIX}TemplateToSubject0*Warp.nii.gz \
                 ${SINGLE_SUBJECT_ANTSCT_PREFIX}TemplateToSubject1GenericAffine.mat \
                 ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/TmpFiles/

    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*Warp.nii.gz
    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*Affine.txt
    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*GenericAffine*

    logCmd mv -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/TmpFiles/* ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}
    logCmd rm -rf ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}/TmpFiles/

  else

    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*Warp.nii.gz
    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*Affine.txt
    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_*GenericAffine*

  fi


time_end_sst_creation=`date +%s`
time_elapsed_sst_creation=$((time_end_sst_creation - time_start_sst_creation))

echo
echo "--------------------------------------------------------------------------------------"
echo " Done with single subject template:  $(( time_elapsed_sst_creation / 3600 ))h $(( time_elapsed_sst_creation %3600 / 60 ))m $(( time_elapsed_sst_creation % 60 ))s"
echo "--------------------------------------------------------------------------------------"
echo

################################################################################
#
#  Run each individual subject through ASHS
#
################################################################################

echo
echo "--------------------------------------------------------------------------------------"
echo " Run each individual through ASHS                                                     "
echo "--------------------------------------------------------------------------------------"
echo

time_start_ashs=`date +%s`


SUBJECT_COUNT=0
for (( i=0; i < ${#ANATOMICAL_IMAGES[@]}; i+=$NUMBER_OF_MODALITIES )) 
   do
    
    BASENAME_ID=`basename ${ANATOMICAL_IMAGES[$i]}`
    BASENAME_ID=${BASENAME_ID/\.nii\.gz/}
    BASENAME_ID=${BASENAME_ID/\.nii/}

    OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS=${OUTPUT_DIR}/${BASENAME_ID}
    OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS=${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}_${SUBJECT_COUNT}

    echo $OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS

    if [[ ! -d $OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS ]];
      then
        echo "The output directory \"$OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS\" does not exist. Making it."
        mkdir -p $OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS
      fi

    let SUBJECT_COUNT=${SUBJECT_COUNT}+1

    ANATOMICAL_REFERENCE_IMAGE=${ANATOMICAL_IMAGES[$i]}
    
    SUBJECT_ANATOMICAL_IMAGES=''
    #if [[ ${RIGID_ALIGNMENT_TO_SST} -ne 0 ]];
    #  then
    #    logCmd ${ANTSPATH}/antsRegistrationSyN.sh \
    #      -d ${DIMENSION} \
    #      -o ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_ID}RigidToSST \
    #      -m ${ANATOMICAL_IMAGES[$i]} \
    #      -f ${SINGLE_SUBJECT_TEMPLATE} \
    #      -t r
    #    logCmd rm -f ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_ID}RigidToSSTInverseWarped.nii.gz

    #    ANATOMICAL_REFERENCE_IMAGE=${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_ID}RigidToSSTWarped.nii.gz


     #   let k=$i+$NUMBER_OF_MODALITIES
     #   for (( j=$i; j < $k; j++ ))
     #     do
     #       BASENAME_LOCAL_ID=`basename ${ANATOMICAL_IMAGES[$j]}`
     #       BASENAME_LOCAL_ID=${BASENAME_LOCAL_ID/\.nii\.gz/}
     #       BASENAME_LOCAL_ID=${BASENAME_LOCAL_ID/\.nii/}

    #        logCmd ${ANTSPATH}/antsApplyTransforms \
     #         -d ${DIMENSION} \
     #         -i ${ANATOMICAL_IMAGES[$j]} \
     #         -r ${SINGLE_SUBJECT_TEMPLATE} \
     #         -o ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_LOCAL_ID}RigidToSSTWarped.nii.gz \
     #         -n Linear \
     #         -t ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_ID}RigidToSST0GenericAffine.mat

      #      SUBJECT_ANATOMICAL_IMAGES="${SUBJECT_ANATOMICAL_IMAGES} -a ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_LOCAL_ID}RigidToSSTWarped.nii.gz"
      #    done

      #fi
     
    let k=$i+$NUMBER_OF_MODALITIES
    for (( j=$i; j < $k; j++ ))
    do
        SUBJECT_ANATOMICAL_IMAGES="${SUBJECT_ANATOMICAL_IMAGES} -a ${ANATOMICAL_IMAGES[$j]}"
	SUBJECT_TSE=${ANATOMICAL_IMAGES[$j]}
    done
    
   
    OUTPUT_LOCAL_PREFIX=${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS}/${BASENAME_ID}
    
    
    logCmd ${ASHS_ROOT}/bin/ashs_main.sh \
	   -a /data/lfs2/software/ubuntu14/ashs/ashs_atlas_umcutrecht_7t_20170810/ \
	   -a ${ASHS_ATLAS} \
	   -g ${ANATOMICAL_REFERENCE_IMAGE} \
	   -f ${SUBJECT_TSE} \
	   -w ${OUTPUT_LOCAL_PREFIX}
    #-other options to be included
    #NEED TO ALSO LABEL THE SST
done


    if [[ $DO_REGISTRATION_TO_TEMPLATE -eq 1 ]];
      then

        if [[ ! -f ${OUTPUT_LOCAL_PREFIX}SubjectToGroupTemplateWarp.nii.gz ]];
          then
            logCmd ${ANTSPATH}/antsApplyTransforms \
              -d ${DIMENSION} \
              -r ${REGISTRATION_TEMPLATE} \
              -o [${OUTPUT_LOCAL_PREFIX}SubjectToGroupTemplateWarp.nii.gz,1] \
              -t ${SINGLE_SUBJECT_ANTSCT_PREFIX}SubjectToTemplate1Warp.nii.gz \
              -t ${SINGLE_SUBJECT_ANTSCT_PREFIX}SubjectToTemplate0GenericAffine.mat \
              -t ${OUTPUT_LOCAL_PREFIX}SubjectToTemplate1Warp.nii.gz \
              -t ${OUTPUT_LOCAL_PREFIX}SubjectToTemplate0GenericAffine.mat
          fi

        if [[ ! -f ${OUTPUT_LOCAL_PREFIX}GroupTemplateToSubjectWarp.nii.gz ]];
          then
            logCmd ${ANTSPATH}/antsApplyTransforms \
              -d ${DIMENSION} \
              -r ${ANATOMICAL_REFERENCE_IMAGE} \
              -o [${OUTPUT_LOCAL_PREFIX}GroupTemplateToSubjectWarp.nii.gz,1] \
              -t ${OUTPUT_LOCAL_PREFIX}TemplateToSubject1GenericAffine.mat \
              -t ${OUTPUT_LOCAL_PREFIX}TemplateToSubject0Warp.nii.gz \
              -t ${SINGLE_SUBJECT_ANTSCT_PREFIX}TemplateToSubject1GenericAffine.mat \
              -t ${SINGLE_SUBJECT_ANTSCT_PREFIX}TemplateToSubject0Warp.nii.gz
          fi

        if [[ -f ${CORTICAL_LABEL_IMAGE} ]];
          then

            SUBJECT_CORTICAL_LABELS=${OUTPUT_LOCAL_PREFIX}CorticalLabels.${OUTPUT_SUFFIX}
            SUBJECT_ASHS=${OUTPUT_LOCAL_PREFIX}CorticalThickness.${OUTPUT_SUFFIX}
            SUBJECT_TMP=${OUTPUT_LOCAL_PREFIX}Tmp.${OUTPUT_SUFFIX}
            SUBJECT_STATS=${OUTPUT_LOCAL_PREFIX}LabelThickness.csv

            if [[ ! -f ${SUBJECT_CORTICAL_LABELS} ]];
              then
                logCmd ${ANTSPATH}/antsApplyTransforms \
                  -d ${DIMENSION} \
                  -i ${CORTICAL_LABEL_IMAGE} \
                  -r ${ANATOMICAL_REFERENCE_IMAGE} \
                  -o ${SUBJECT_CORTICAL_LABELS} \
                  -n MultiLabel \
                  -t ${OUTPUT_LOCAL_PREFIX}GroupTemplateToSubjectWarp.nii.gz

                logCmd ${ANTSPATH}/ThresholdImage ${DIMENSION} ${OUTPUT_LOCAL_PREFIX}BrainSegmentation.${OUTPUT_SUFFIX} ${SUBJECT_TMP} 2 2 1 0
                logCmd ${ANTSPATH}/ImageMath ${DIMENSION} ${SUBJECT_CORTICAL_LABELS} m ${SUBJECT_TMP} ${SUBJECT_CORTICAL_LABELS}
                logCmd ${ANTSPATH}/ImageMath ${DIMENSION} ${SUBJECT_STATS} LabelStats ${SUBJECT_CORTICAL_LABELS} ${SUBJECT_ASHS}
              fi

            logCmd rm -f $SUBJECT_TMP
          fi
      fi

  done

time_end_ashs=`date +%s`
time_elapsed_ashs=$((time_end_ashs - time_start_ashs))

echo
echo "--------------------------------------------------------------------------------------"
echo " Done with individual ASHS:  $(( time_elapsed_ashs / 3600 ))h $(( time_elapsed_ashs %3600 / 60 ))m $(( time_elapsed_ashs % 60 ))s"
echo "--------------------------------------------------------------------------------------"
echo
################################
## START JLF AND REVERSE NORM  #
################################

echo
echo "--------------------------------------------------------------------------------------"
echo " JLF the ASHS results to the SST                                                      "
echo "--------------------------------------------------------------------------------------"
echo

time_start_jlf=`date +%s`

OUTPUT_DIRECTORY_FOR_JLF="${OUTPUT_PREFIX}_LASHiS/"
XS_ASHS_DIR=$OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_ASHS
logCmd mkdir -p ${OUTPUT_DIRECTORY_FOR_JLF}

for(( i=0; i < '2'; i++ ))
  do
    JLF_step=`date +%s`
    for side in left right ; do
	
	VARIABLE_g_l=""
	for(( i=0; i < (( ${#ANATOMICAL_IMAGES[@]} / 2 | bc )) ; i++ )) ;
	do
	    VARIABLE_g_l="$VARIABLE_g_l -g ${XS_ASHS_DIR}${i}/tse_native_chunk_${side}.nii.gz -l ${XS_ASHS_DIR}${i}/final/*_${side}_lfseg_corr_usegray.nii.gz \ "
	done

	if [[ ! -f #FIXME $SOME_FILE ]];
	then
	    for side in left right ; do
		
		for(( i=0; i < ${#ANATOMICAL_IMAGES}; i++ )) ; do VARIABLE_g_l="$VARIABLE_g_l -g ${XS_ASHS_DIR}${i}/tse_native_chunk_${side}.nii.gz -l ${XS_ASHS_DIR}${i}/final/*_${side}_lfseg_corr_usegray.nii.gz \ "
		done

		echo $VARIABLE_g_l
		
		for side in left right ; do
    		    logCmd $ANTSPATH/antsJointLabelFusion2.sh \
			   -d 3 \
			   -c ${DOQSUB} \
			   -j ${CORES} \
			   -t ${SOMETHING}/tse_native_chunk_${side}.nii.gz \
			   $VARIABLE_g_l \
			   -o #FIXME ${subjName}_long_ashs_JLF_3TP_${side} \
			   -p $OUTPUT_DIRECTORY_FOR_JLF/posterior%04d.nii.gz \
			   -k 1
		    -z $MEMORY_PARAM_jlf
		    -v $registration_memory_limit
		    -u $JLF_walltime_param
		    -w $registration_walltime_param
		done
	    done
	fi


	logCmd ${ANTSPATH}/antsMultivariateTemplateConstruction.sh \
          -d 3 \
          -o ${OUTPUT_DIRECTORY_FOR_SINGLE_SUBJECT_TEMPLATE}T_ \
          -b 0 \
          -g 0.25 \
          -i 4 \
          -c ${DOQSUB} \
          -j ${CORES} \
          -k '2' \
          -w ${TEMPLATE_MODALITY_WEIGHT_VECTOR} \
          -m 100x70x30x3  \
          -n ${N4_BIAS_CORRECTION} \
          -r 1 \
          -s CC \
          -t GR \
          -y ${AFFINE_UPDATE_FULL} \
          -r 1
          ${ANATOMICAL_IMAGES[@]}
fi

if [[ ! -f ${SINGLE_SUBJECT_TEMPLATE} ]];
  then
    echo "Error:  The single subject template was not created.  Exiting."
    exit 1
  fi

# clean up




time_end_jlf=`date +%s`
time_elapsed_jlf=$((time_end_jlf - time_start_jlf))


time_end=`date +%s`
time_elapsed=$((time_end - time_start))

echo
echo "--------------------------------------------------------------------------------------"
echo " Done with LASHiS pipeline! "
echo " Script executed in $time_elapsed seconds"
echo " $(( time_elapsed / 3600 ))h $(( time_elapsed %3600 / 60 ))m $(( time_elapsed % 60 ))s"
echo "--------------------------------------------------------------------------------------"

exit 0
