#!/bin/bash
#This script takes all ADNI data from the previous steps and formats it for the LME experiment
#FS Xs and Fs Long, LASHiS, Diet LASHis, and ASHS Xs
#Thomas Shaw 9/12/2019

#set the directory where the data now lives after processing
base_dir="/30days/uqtshaw/ADNI_BIDS/derivatives"

#set the github dir
github_dir="/home/uqtshaw/LASHiS/Experiment_Code/"

#this should then be correct
ADNI_collection_csv=${github_dir}/R_experiments/Hippo_scans_10_27_2019_reconciled.csv

#first get rid of all the underscores in the subjnames column of the adni collection csv
nounderscores="$(awk '{gsub(/_/,"")}1' $ADNI_collection_csv)"
echo "$nounderscores" > $ADNI_collection_csv
if [[ -e $base_dir/ADNI_DATA_missing_files.txt ]] ; then rm $base_dir/ADNI_DATA_missing_files.txt ; fi
#set up the reconciled files
for var in LASHiS Diet_LASHiS FsLong ashs_xs FsXs ; do    
    rm ${github_dir}/R_experiments/LME_experiment/Data/ADNI_${var}_reconciled.csv
    echo -e 'IMAGE_ID,ID,DIAGNOSIS,SEX,AGE,VISIT,IMA_FORMAT,EXAM_DATE,volume.L.CA1,volume.L.CA2.3,volume.L.DG,volume.L.SUB,volume.R.CA1,volume.R.CA2.3,volume.R.DG,volume.R.SUB'>>${github_dir}/R_experiments/LME_experiment/Data/ADNI_${var}_reconciled.csv
done

#subjnames are in LASHiS github dir
for subjName in `cat ${github_dir}/ADNI_code/subjnames_2_ses.csv` ; do

    ######################
    ##  LASHiS and Diet  and ASHS#
    ######################
    #first de-tar the LASHiS
    cd ${base_dir}/LASHiS
    mkdir ${base_dir}/LASHiS/${subjName}_LASHiS 
    if [ -z "$(ls -A ${base_dir}/LASHiS/${subjName}_LASHiS)" ] ; then
	tar -xzf ${base_dir}/LASHiS/${subjName}_LASHIS.tar.gz -C ${base_dir}/LASHiS/${subjName}_LASHiS
    fi
    #copy all the files from ASHS xs to the same name as LASHiS and diet for ease
    mkdir $base_dir/LASHiS/${subjName}_LASHiS/ashs_xs

    for side in left right ; do
	cp ${base_dir}/LASHiS/${subjName}_LASHiS/mprage1_0/mprage1/final/mprage1_${side}_corr_usegray_volumes.txt $base_dir/LASHiS/${subjName}_LASHiS/ashs_xs/mprage1${side}SSTLabelsWarpedToTimePoint0_stats.txt
	cp ${base_dir}/LASHiS/${subjName}_LASHiS/mprage2_1/mprage2/final/mprage2_${side}_corr_usegray_volumes.txt $base_dir/LASHiS/${subjName}_LASHiS/ashs_xs/mprage2${side}SSTLabelsWarpedToTimePoint1_stats.txt
	cp ${base_dir}/LASHiS/${subjName}_LASHiS/mprage3_2/mprage3/final/mprage3_${side}_corr_usegray_volumes.txt $base_dir/LASHiS/${subjName}_LASHiS/ashs_xs/mprage3${side}SSTLabelsWarpedToTimePoint2_stats.txt
    done
    for var in LASHiS Diet_LASHiS ashs_xs ; do
	#first print the lines that contain the demographic variables from ADNI
	if [[ -e $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv ]] ; then 
	    rm $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv 
	fi
	awk -v subjname="${subjName}" '$0~subjname' ${ADNI_collection_csv}>>$base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv
	#remove the ^M newline
	sed -e "s/\r//g" $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv > $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_temp.csv && cat $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_temp.csv > $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv && rm $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_temp.csv
	
	demo=$base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv
	#then start arranging the various subfield values into variables
	
	
	#then find the values and normalise them by hippocampus volume over the time points using this stupid awk code (not optimised but whatever)
	LCA11=""
	LCA231=""
	LDG1=""
	LSUB1=""
	LCA12=""
	LCA232=""
	LDG2=""
	LSUB2=""
	RCA12=""
	RCA232=""
	RDG2=""
	RSUB2=""
	LCA13=""
	LCA233=""
	LDG3=""
	LSUB3=""
	RCA13=""
	RCA233=""
	RDG3=""
	RSUB3=""
	left_tp1_vols=""
	left_tp1_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt
	right_tp1_vols=""
	right_tp1_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt
	left_tp2_vols=""
	left_tp2_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt
	right_tp2_vols=""
	right_tp2_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt
	left_tp3_vols=""
	left_tp3_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt
	right_tp3_vols=""
	right_tp3_vols=$base_dir/LASHiS/${subjName}_LASHiS/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt
	if [[ -e ${left_tp1_vols} && ${right_tp1_vols} ]] ; then 
	    LCA11="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $left_tp1_vols)" 
	    LCA231="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $left_tp1_vols)"
	    LDG1="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $left_tp1_vols)"
	    LSUB1="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $left_tp1_vols)" 
	    RCA11="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $right_tp1_vols)"  
	    RCA231="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $right_tp1_vols)"
	    RDG1="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $right_tp1_vols)"
	    RSUB1="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $right_tp1_vols)" 
	fi	
	if [[ -e ${left_tp2_vols} && ${right_tp2_vols} ]] ; then 
	    LCA12="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $left_tp2_vols)"
	    LCA232="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $left_tp2_vols)"
	    LDG2="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $left_tp2_vols)"
	    LSUB2="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $left_tp2_vols)"
	    RCA12="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $right_tp2_vols)"
	    RCA232="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $right_tp2_vols)"
	    RDG2="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $right_tp2_vols)"
	    RSUB2="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $right_tp2_vols)"
	fi
	if [[ -e ${left_tp3_vols} && ${right_tp3_vols} ]] ; then 
	    LCA13="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $left_tp3_vols)"
	    LCA233="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $left_tp3_vols)"
	    LDG3="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $left_tp3_vols)"
	    LSUB3="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $left_tp3_vols)"
	    RCA13="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $right_tp3_vols)"
	    RCA233="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $right_tp3_vols)"
	    RDG3="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $right_tp3_vols)"
	    RSUB3="$(awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $right_tp3_vols)" 
	fi         

	#concatenate the timepoints into csvs for TP1/2 
	if [[ -z "$LCA11" || -z "$LCA231" || -z "$LDG1" || -z "$LSUB1" || -z "$RCA11" || -z "$RCA231" || -z "$RDG1" || -z "$RSUB1" || -z "$demo" ]] 
	then 
	    echo "$subjName one or more varibales are empty for TP1" >> $base_dir/ADNI_DATA_missing_files.txt
	    echo "skipping participant ${subjName}"
	else 
	    echo "Data is all good" 
	    
	    awk -v lca11=$LCA11 -v lca231=$LCA231 -v ldg1=$LDG1 -v lsub1=$LSUB1 -v rca11=$RCA11 -v rca231=$RCA231 -v rdg1=$RDG1 -v rsub1=$RSUB1 'BEGIN{FS=OFS=","} NR==1 {print $0","lca11","lca231","ldg1","lsub1","rca11","rca231","rdg1","rsub1}' $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv > $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_${var}_final.csv 


	    if [[ -z "$LCA12" || -z "$LCA232" || -z "$LDG2" || -z "$LSUB2" || -z "$RCA12" || -z "$RCA232" || -z "$RDG2" || -z "$RSUB2" ]] 
	    then
		echo "$subjName one or more varibales are empty for TP2" >> $base_dir/ADNI_DATA_missing_files.txt
	    else	
		awk -v lca12=$LCA12 -v lca232=$LCA232 -v ldg2=$LDG2 -v lsub2=$LSUB2 -v rca12=$RCA12 -v rca232=$RCA232 -v rdg2=$RDG2 -v rsub2=$RSUB2 'BEGIN{FS=OFS=","} NR==2 {print $0","lca12","lca232","ldg2","lsub2","rca12","rca232","rdg2","rsub2}' $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv >> $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_${var}_final.csv 
		
		if [[ -z "$LCA13" || -z "$LCA233" || -z "$LDG3" || -z "$LSUB3" || -z "$RCA13" || -z "$RCA233" || -z "$RDG3" || -z "$RSUB3" || -z "$demo" ]] 
		then
		    echo echo "$subjName one or more varibales are empty for TP3" >> $base_dir/ADNI_DATA_missing_files.txt
		else
		    awk -v lca13=$LCA13 -v lca233=$LCA233 -v ldg3=$LDG3 -v lsub3=$LSUB3 -v rca13=$RCA13 -v rca233=$RCA233 -v rdg3=$RDG3 -v rsub3=$RSUB3 'BEGIN{FS=OFS=","} NR==3 {print $0","lca13","lca233","ldg3","lsub3","rca13","rca233","rdg3","rsub3}' $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_demo_info.csv >> $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_${var}_final.csv 	
		fi
		#then you just have to concatenate all the subjnames and for each var.
		cat $base_dir/LASHiS/${subjName}_LASHiS/${subjName}_${var}_final.csv >> ${github_dir}/R_experiments/LME_experiment/Data/ADNI_${var}_reconciled.csv 
	    fi  
	fi
    done
    
    #de-tar the lashis (remove the folder)
    #rm -rf ${base_dir}/LASHiS/${subjName}_LASHiS



    #freesurfer results.
    #basically the same but with differences in the filenames and the addition of new element and locations in the ugly awk code - aside from that it is the same. 

    ###########################
    ## Freesurfer Xs and Long #
    ###########################

    #coding error left the freesurfer files spread out a bit
    subjects_dir=${base_dir}/Freesurfer
    #/30days/uqtshaw/ADNI_freesurfer/
    #left 
    mkdir -p $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs
    #Xs
    cp ${subjects_dir}/${subjName}_ses-01/mri/lh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt
    cp ${subjects_dir}/${subjName}_ses-02/mri/lh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt
    cp ${subjects_dir}/${subjName}_ses-03/mri/lh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt
    #right
    cp ${subjects_dir}/${subjName}_ses-01/mri/rh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt
    cp ${subjects_dir}/${subjName}_ses-02/mri/rh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt
    cp ${subjects_dir}/${subjName}_ses-03/mri/rh.hippoSfVolumes-T2_Only.v20.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsXs/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt
    #FsLong
    cp ${subjects_dir}/${subjName}_ses-01.long.${subjName}/mri/lh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt
    cp ${subjects_dir}/${subjName}_ses-02.long.${subjName}/mri/lh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt
    cp ${subjects_dir}/${subjName}_ses-03.long.${subjName}/mri/lh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt

    cp ${subjects_dir}/${subjName}_ses-01.long.${subjName}/mri/rh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt
    cp ${subjects_dir}/${subjName}_ses-02.long.${subjName}/mri/rh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt
    cp ${subjects_dir}/${subjName}_ses-03.long.${subjName}/mri/rh.hippoSfVolumes-T1.long.v21.txt $base_dir/Freesurfer/${subjName}_Freesurfer/FsLong/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt



    for var in FsXs FsLong ; do
	#first print the lines that contain the demographic variables from ADNI
	if [[ -e $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv ]] ; then 
	    rm $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv 
	fi
	awk -v subjname="${subjName}" '$0~subjname' ${ADNI_collection_csv}>>$base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv
	#remove the ^M newline
	sed -e "s/\r//g" $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv > $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_temp.csv && cat $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_temp.csv > $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv && rm $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_temp.csv
	
	demo=$base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv
	#then start arranging the various subfield values into variables
	
	#find the values and normalise them by hippocampus volume over the time points using this stupid awk code (not optimised but whatever)
	LCA11=""
	LCA231=""
	LDG1=""
	LSUB1=""
	LCA12=""
	LCA232=""
	LDG2=""
	LSUB2=""
	RCA12=""
	RCA232=""
	RDG2=""
	RSUB2=""
	LCA13=""
	LCA233=""
	LDG3=""
	LSUB3=""
	RCA13=""
	RCA233=""
	RDG3=""
	RSUB3=""
	left_tp1_vols=""
	left_tp1_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt
	right_tp1_vols=""
	right_tp1_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt
	left_tp2_vols=""
	left_tp2_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt
	right_tp2_vols=""
	right_tp2_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt
	left_tp3_vols=""
	left_tp3_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt
	right_tp3_vols=""
	right_tp3_vols=$base_dir/Freesurfer/${subjName}_Freesurfer/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt


	#Ca1= rows 3 and 7
	#ca2/3 = rows 13 18
	#DG = rows 12 14 15 16
	#sub = rows 2 4 6 8
	if [[ -e ${left_tp1_vols} && ${right_tp1_vols} ]] ; then 
	    LCA11="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp1_vols)" 
	    LCA231="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp1_vols)"
	    LDG1="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp1_vols)"
	    LSUB1="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp1_vols)" 

	    RCA11="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp1_vols)"  
	    RCA231="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp1_vols)"
	    RDG1="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp1_vols)"
	    RSUB1="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp1_vols)" 
	fi	
	if [[ -e ${left_tp2_vols} && ${right_tp2_vols} ]] ; then 
	    LCA12="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp2_vols)"
	    LCA232="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp2_vols)"
	    LDG2="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp2_vols)"
	    LSUB2="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp2_vols)"
	    
	    RCA12="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp2_vols)"
	    RCA232="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp2_vols)"
	    RDG2="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp2_vols)"
	    RSUB2="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp2_vols)"
	fi
	if [[ -e ${left_tp3_vols} && ${right_tp3_vols} ]] ; then 
	    LCA13="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp3_vols)"
	    LCA233="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp3_vols)"
	    LDG3="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp3_vols)"
	    LSUB3="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $left_tp3_vols)"
	    
	    RCA13="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e1+e2)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp3_vols)"
	    RCA233="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e3+e4)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp3_vols)"
	    RDG3="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e5+e6+e7+e8)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp3_vols)"
	    RSUB3="$(awk -v x=2 -v a=3 -v b=7 -v c=13 -v d=18 -v f=12 -v g=14 -v h=15 -v i=16 -v j=2 -v k=4 -v l=6 -v m=8 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==f{e5=$x} NR==g{e6=$x} NR==h{e7=$x} NR==i{e8=$x} NR==j{e9=$x} NR==k{e10=$x} NR==l{e11=$x} NR==m{e12=$x} END{if (x) print (e9+e10+e11+e12)/(e1+e2+e3+e4+e5+e6+e7+e8+e9+e10+e11+e12)}' $right_tp3_vols)" 
	fi

	#concatenate the timepoints into csvs for TP1/2 
	if [[ -z "$LCA11" || -z "$LCA231" || -z "$LDG1" || -z "$LSUB1" || -z "$RCA11" || -z "$RCA231" || -z "$RDG1" || -z "$RSUB1" || -z "$demo" ]] 
	then 
	    echo "$subjName one or more varibales are empty for TP1" >> $base_dir/ADNI_DATA_missing_files.txt
	    echo "skipping participant ${subjName}"
	else 
	    echo "Data is all good" 
	    
	    awk -v lca11=$LCA11 -v lca231=$LCA231 -v ldg1=$LDG1 -v lsub1=$LSUB1 -v rca11=$RCA11 -v rca231=$RCA231 -v rdg1=$RDG1 -v rsub1=$RSUB1 'BEGIN{FS=OFS=","} NR==1 {print $0","lca11","lca231","ldg1","lsub1","rca11","rca231","rdg1","rsub1}' $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv > $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_${var}_final.csv 

	    if [[ -z "$LCA12" || -z "$LCA232" || -z "$LDG2" || -z "$LSUB2" || -z "$RCA12" || -z "$RCA232" || -z "$RDG2" || -z "$RSUB2" ]] 
	    then
		echo "$subjName one or more varibales are empty for TP2" >> $base_dir/ADNI_DATA_missing_files.txt
	    else	
		awk -v lca12=$LCA12 -v lca232=$LCA232 -v ldg2=$LDG2 -v lsub2=$LSUB2 -v rca12=$RCA12 -v rca232=$RCA232 -v rdg2=$RDG2 -v rsub2=$RSUB2 'BEGIN{FS=OFS=","} NR==2 {print $0","lca12","lca232","ldg2","lsub2","rca12","rca232","rdg2","rsub2}' $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv >> $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_${var}_final.csv 
		
		if [[ -z "$LCA13" || -z "$LCA233" || -z "$LDG3" || -z "$LSUB3" || -z "$RCA13" || -z "$RCA233" || -z "$RDG3" || -z "$RSUB3" || -z "$demo" ]] 
		then
		    echo echo "$subjName one or more varibales are empty for TP3" >> $base_dir/ADNI_DATA_missing_files.txt
		else
		    awk -v lca13=$LCA13 -v lca233=$LCA233 -v ldg3=$LDG3 -v lsub3=$LSUB3 -v rca13=$RCA13 -v rca233=$RCA233 -v rdg3=$RDG3 -v rsub3=$RSUB3 'BEGIN{FS=OFS=","} NR==3 {print $0","lca13","lca233","ldg3","lsub3","rca13","rca233","rdg3","rsub3}' $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_demo_info.csv >> $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_${var}_final.csv 	
		fi
		#then you just have to concatenate all the subjnames and for each var.
		cat $base_dir/Freesurfer/${subjName}_Freesurfer/${subjName}_${var}_final.csv >> ${github_dir}/R_experiments/LME_experiment/Data/ADNI_${var}_reconciled.csv 
	    fi  
	fi
    done
done

#some additional code for finding demo info
#awk  -F"," '{delta = $5 - avg; avg += delta / NR; mean2 += delta * ($5 - avg); } END { print sqrt(mean2 / NR); }' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_FsLong_reconciled.csv
#8.75705
# awk -F ',' '{print $2,$4,$5}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_FsLong_reconciled.csv  | sort | uniq -c | grep " M " | wc -l
#73
#awk -F ',' '{print $2,$4,$5}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_FsLong_reconciled.csv  | sort | uniq -c | grep " F " | wc -l
#90
#awk -F ',' '{print $2,$3}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_ashs_xs_reconciled.csv  | sort | uniq -c | grep " MCI" | wc -l
#9
#awk -F ',' '{print $2,$3}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_ashs_xs_reconciled.csv  | sort | uniq -c | grep " LMCI" | wc -l
#13
# awk -F ',' '{print $2,$3}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_ashs_xs_reconciled.csv  | sort | uniq -c | grep " EMCI" | wc -l
#20
# awk -F ',' '{print $2,$3}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_ashs_xs_reconciled.csv  | sort | uniq -c | grep " CN" | wc -l
#38
#awk -F ',' '{print $2,$3}' ~/LASHiS/Experiment_Code/R_experiments/LME_experiment/Data/ADNI_ashs_xs_reconciled.csv  | sort | uniq -c | grep "SMC" | wc -l
#11
