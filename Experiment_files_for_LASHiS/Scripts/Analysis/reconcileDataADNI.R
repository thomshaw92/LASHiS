# library( ADNIMERGE )
# 

baseDirectory <- '/path/to/github_dir'
dataDirectory <- paste0( baseDirectory, 'Data/' )
#sandboxDirectory <- paste0( baseDirectory, 'Sandbox/' )
figuresDirectory <- paste0( baseDirectory, 'Figures/' )

numberOfRegions <- 8
hippoVolumePipelineNames <- c( 'FsXs', 'ashs_xs', 'FsLong', 'Diet_LASHiS', 'LASHiS')

hippoVolumeCsvs <- list()
hippoVolumeData <- list()
cat( "Reading unreconciled data.\n" )

for( i in 1:length( hippoVolumePipelineNames ) )
{
  hippoVolumeCsvs[[i]] <- paste0( dataDirectory, 'ADNI_', hippoVolumePipelineNames[i], '_unreconciled.csv' )
  hippoVolumeData[[i]] <- read.csv( hippoVolumeCsvs[[i]] )
}

# find the image IDs that are present in all pipelines
intersectImageIds <- c()
for( i in 1:length( hippoVolumeCsvs ) )
  {
  hippoVolumeData[[i]] <- read.csv( hippoVolumeCsvs[[i]] )
  if( i == 1 )
    {
    intersectImageIds <- hippoVolumeData[[i]]$IMAGE_ID    
    }
  intersectImageIds <- intersect( hippoVolumeData[[i]]$IMAGE_ID, intersectImageIds )
}

# get rid of observations outside of those consistent image IDs
for( i in 1:length( hippoVolumeData ) )
  {
  hippoVolumeData[[i]] <- hippoVolumeData[[i]][which( hippoVolumeData[[i]]$IMAGE_ID %in% intersectImageIds ), ]
  hippoVolumeData[[i]]$IMAGE_ID <- factor( hippoVolumeData[[i]]$IMAGE_ID, levels = intersectImageIds )
  hippoVolumeData[[i]] <- hippoVolumeData[[i]][order( hippoVolumeData[[i]]$IMAGE_ID ), ]

  thicknessColumns <- ( ncol( hippoVolumeData[[i]] ) - numberOfRegions + 1 ):ncol( hippoVolumeData[[i]] )
  }

cat( "\n\nCreating new .csv files\n" )
for( i in 1:length( hippoVolumeData ) )
{
  demographicsColumns <- (1:8)
  thicknessColumns <- ( ncol( hippoVolumeData[[i]] ) - numberOfRegions + 1 ):ncol( hippoVolumeData[[i]] )
  hippoVolumeData[[i]] <- data.frame(
    hippoVolumeData[[i]][,demographicsColumns],
    hippoVolumeData[[i]][,thicknessColumns] )
}

for( i in 1:length( hippoVolumeData ) )
  {
  hippoVolumeData[[i]] <- 
    hippoVolumeData[[i]][order( hippoVolumeData[[i]]$ID, hippoVolumeData[[i]]$VISIT ),]  

  write.csv( hippoVolumeData[[i]], quote = FALSE, row.names = FALSE, 
             file = paste0( dataDirectory, "/fullyReconciledADNI_", hippoVolumePipelineNames[i], ".csv" ) )  
  }





