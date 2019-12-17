#!/bin/bash
#This script takes all ADNI data from the previous steps and formats it for the LME experiment
#FS Xs and Fs Long, LASHiS, Diet LASHis, and ASHS Xs
#Thomas Shaw 9/12/2019

#set the directory where the data now lives after processing
base_dir="/30days/uqtshaw/ADNI_BIDS/derivatives"

#set the github dir
github_dir="/home/uqtshaw/LASHiS/Experiment_Code/"

ADNI_collection_csv=${github_dir}/R_experiments/Hippo_scans_10_27_2019_reconciled.csv

#first get rid of all the underscores in the subjnames column of the adni collection csv
nounderscores="$(awk '{gsub(/_/,"")}1' $ADNI_collection_csv)"
echo "$nounderscores" > $ADNI_collection_csv

#set up the reconciled files
for var is LASHiS Diet_LASHiS FsLong ASHSXs FsXs ; do 
    echo -e 'IMAGE_ID,ID,DIAGNOSIS,SEX,AGE,VISIT,IMA_FORMAT,EXAM_DATE,L.CA1,L.CA2.3,L.DG,L.SUB,R.CA1,R.CA2.3,R.DG,R.SUB'>>${github_dir}/R_experiments/${var}_reconciled.csv
done

#subjnames are in LASHiS github dir
for subjName in `cat ${github_dir}/ADNI_code/subjnames_2_ses.csv` ; do

    ######################
    ##  LASHiS and Diet  and ASHS#
    ######################
    #copy all the files from ASHS xs to the same name as LASHiS and diet for ease
    mkdir $base_dir/${subjName}_LASHiS/ashs_xs
    for side in left right ; do
	cp ${base_dir}/${subjName}_LASHiS/mprage1_0/mprage1/final/mprage1_${side}_corr_usegray_volumes.txt $base_dir/${subjName}_LASHiS/ashs_xs/mprage1${side}SSTLabelsWarpedToTimePoint0_stats.txt
	cp ${base_dir}/${subjName}_LASHiS/mprage2_1/mprage1/final/mprage2_${side}_corr_usegray_volumes.txt $base_dir/${subjName}_LASHiS/ashs_xs/mprage2${side}SSTLabelsWarpedToTimePoint1_stats.txt
	cp ${base_dir}/${subjName}_LASHiS/mprage3_2/mprage1/final/mprage3_${side}_corr_usegray_volumes.txt $base_dir/${subjName}_LASHiS/ashs_xs/mprage3${side}SSTLabelsWarpedToTimePoint2_stats.txt
    done
    for var in LASHiS Diet_LASHiS ashs_xs ; do
	#first print the lines that contain the demographic variables from ADNI
	if [[ -e $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv ]] ; then 
	    rm $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv 
	fi
	awk -v subjname="${subjName}" '$0~subjname' ${ADNI_collection_csv}>>$base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv
	#remove the ^M newline
	sed -e "s/\r//g" $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv > $base_dir/${subjName}_LASHiS/${subjName}_temp.csv && cat $base_dir/${subjName}_LASHiS/${subjName}_temp.csv > $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv && rm $base_dir/${subjName}_LASHiS/${subjName}_temp.csv
	#then start arranging the various subfield values into variables
	
	#first de-tar the LASHiS
	cd ${base_dir}/LASHiS
	mkdir ${subjName}_LASHiS && tar -xvzf ./${subjName}_LASHIS.tar.gz -C ${subjName}_LASHiS
	
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

	LCA11=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt` 
	LCA231=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt` 
	LDG1=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt` 
	LSUB1=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1leftSSTLabelsWarpedToTimePoint0_stats.txt` 
	RCA11=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt` 
	RCA231=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt` 
	RDG1=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt` 
	RSUB1=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage1rightSSTLabelsWarpedToTimePoint0_stats.txt ` 
	LCA12=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt` 
	LCA232=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt` 
	LDG2=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt` 
	LSUB2=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2leftSSTLabelsWarpedToTimePoint1_stats.txt` 
	RCA12=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt` 
	RCA232=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt` 
	RDG2=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt` 
	RSUB2=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage2rightSSTLabelsWarpedToTimePoint1_stats.txt` 
	LCA13=` awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt` 
	LCA233=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt` 
	LDG3=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt` 
	LSUB3=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3leftSSTLabelsWarpedToTimePoint2_stats.txt` 
	RCA13=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e1)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt` 
	RCA233=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e2+e4)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt` 
	RDG3=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e3)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt` 
	RSUB3=`awk -v x=5 -v a=1 -v b=2 -v c=4 -v d=3 -v s=6 'NR==a{e1=$x} NR==b{e2=$x} NR==c{e3=$x} NR==d{e4=$x} NR==s{e6=$x} END{if (x) print (e6)/(e1+e2+e3+e4+e6)}' $base_dir/${subjName}_LASHiS/${var}/mprage3rightSSTLabelsWarpedToTimePoint2_stats.txt` 
	#concatenate the timepoints into csvs for TP1/2 
	if [[ -z "$LCA11" || -z "$LCA231" || -z "$LDG1" || -z "$LSUB1" || -z "$RCA11" || -z "$RCA231" || -z "$RDG1" || -z "$RSUB1" || -z "$LCA12" || -z "$LCA232" || -z "$LDG2" || -z "$LSUB2" || -z "$RCA12" || -z "$RCA232" || -z "$RDG2" || -z "$RSUB2" || -z ${demo} ]] 
	then 
	    echo "$subjName varibale is empty" >> $base_dir/ADNI_DATA_missing_files.txt
	    echo "skipping participant ${subjName}"
	else 
	    echo "Data is all good" 
	    
	    awk -v lca11=$LCA11 -v lca231=$LCA231 -v ldg1=$LDG1 -v lsub1=$LSUB1 -v rca11=$RCA11 -v rca231=$RCA231 -v rdg1=$RDG1 -v rsub1=$RSUB1 'BEGIN{FS=OFS=","} NR==1 {print $0","lca11","lca231","ldg1","lsub1","rca11","rca231","rdg1","rsub1}1' $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv > $base_dir/${subjName}_LASHiS/temp.csv && cat $base_dir/${subjName}_LASHiS/temp.csv >  $base_dir/${subjName}_LASHiS/${subjName}_${var}_final.csv && rm $base_dir/${subjName}_LASHiS/temp.csv 

	    awk 
-v lca12=$LCA12 -v lca232=$LCA232 -v ldg2=$LDG2 -v lsub2=$LSUB2 -v rca12=$RCA12 -v rca232=$RCA232 -v rdg2=$RDG2 -v rsub2=$RSUB2 'BEGIN{FS=OFS=","} NR==1 {print $0","lca12","lca232","ldg2","lsub2","rca12","rca232","rdg2","rsub2}1' $base_dir/${subjName}_LASHiS/${subjName}_demo_info.csv > $base_dir/${subjName}_LASHiS/temp.csv && cat $base_dir/${subjName}_LASHiS/temp.csv >  $base_dir/${subjName}_LASHiS/${subjName}_${var}_final.csv && rm $base_dir/${subjName}_LASHiS/temp.csv 

	  
	fi
	#then you just have to concatenate all the subjnames and for each var.
	
	


	
  done

  
  #freesurfer results.
#basically the same but with differences in the filenames and the addition of new element and locations in the ugly awk code - aside from that it is the same. 
