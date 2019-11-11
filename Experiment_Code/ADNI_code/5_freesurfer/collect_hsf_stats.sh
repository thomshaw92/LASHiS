
asegstats2table --statsfile=hipposubfields.lh.T1.v21.stats --tablefile=hipposubfields.lh.T1.v21.dat

quantifyHAsubregions.sh hippoSf <T2_only> /data/fasttemp/uqtshaw/tomcat/
#The first argument specifies whether we want to collect the volumes of the hippocampus (hippoSf) of the amygdala (amygNuc). The second argument is the name of the analysis: for the first mode of operation (only main T1 scans), it is simply T1. For the second mode (additional scan), it would be T1-<analysisID> (for multispectral analysis) or just <analysisID> (for segmentation based only on the additional scan). For longitudinal segmentation, it would just be T1.long. The argument <output_file> corresponds to the text file where the table with the volumes will be written. The fields are separated by spaces. Finally, the fourth argument is optional and overrides the FreeSurfer subjects directory.

