library( here )
library( rstan )
library( lubridate )
library( ggplot2 )


options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
Sys.setenv( TZ = 'America/Los_Angeles' )
############################################################################################################
#
#     This is the core script for calculating the point estimates of the LME model
#     for hippoVolume across the different pipelines.  The major steps performed
#     below are as follows:
#
#       1.  Check to see if the results file already exists (called 'stan_ResultsAll.csv').  
#       2.  If the file exists, plot the results.
#       3.  If the file does not exist, perform the following steps using Rstan
#           3a.  Read in the hippoVolume .csv files and reconcile the data, i.e. make sure that 
#                the image IDs are identical and in identical order across the pipeline types.  Also,
#                remove any time points from all pipelines which have NA's in one or more pipeline.
#           3b.  Fit the data using Rstan with the model specified in the file 'stan_hippoVolumeModel.stan'
#           3c.  Calculate the quantiles = c( 0.0, 0.025, 0.25, 0.5, 0.75, 0.975, 1.00 ), for each pipeline 
#                and write to a file (per pipeline).  Also, cbind all the results and write to a file 
#                ('stan_ResultsAll.csv')
#           3d.  Plot results. 
#

baseDirectory <- 'path/to/git/directory/'
dataDirectory <- paste0( baseDirectory, 'Data/TOMCAT/' )
figuresDirectory <- paste0( baseDirectory, 'Figures/TOMCAT/' )
hippoVolumePipelineNames <- c( 'Freesurfer Xs', 'ASHS Xs', 'Freesurfer Long', 'Diet LASHiS', 'LASHiS')
numberOfRegions <- 8


SubFieldRegions <- read.csv( paste0( dataDirectory, 'SubField.csv' ) )
SubFieldBrainGraphRegions <- SubFieldRegions$brainGraph[( nrow( SubFieldRegions ) - numberOfRegions + 1 ):nrow( SubFieldRegions )]
SubFieldBrainGraphRegions <- gsub( " ", "", SubFieldBrainGraphRegions ) 

stanAllResultsFile <- paste0( dataDirectory, 'stan_ResultsAll.csv' )

if( file.exists( stanAllResultsFile ) )
  {

  stanResultsAll <- read.csv( stanAllResultsFile )
  stanResultsAll$Pipeline <- factor( stanResultsAll$Pipeline, levels = 
    hippoVolumePipelineNames )

  } else {

  ##########
  #
  # Read in the reconnciled data
  # 
  ##########

  cat( "Reading reconciled data.\n" )

  hippoVolumeCsvs <- list()
  hippoVolumeData <- list()
  for( i in 1:length( hippoVolumePipelineNames ) )
    {
    hippoVolumeCsvs[[i]] <- paste0( dataDirectory, 'reconciled_', hippoVolumePipelineNames[i], '.csv' )
    hippoVolumeData[[i]] <- read.csv( hippoVolumeCsvs[[i]] )
    }

  # We renormalize the visits based on exam date

  cat( "Renormalizing visit information based on exam date.\n" )
 
  uniqueSubjectIds <- unique( hippoVolumeData[[1]]$ID )
  volumeColumns <- grep( "volume", colnames( hippoVolumeData[[1]] ) )

  pb <- txtProgressBar( min = 0, max = length( uniqueSubjectIds ), style = 3 )

  multipleTimePointSubjectsIds <- c()
  isMultipleTimePointSubject <- rep( 1, nrow( hippoVolumeData[[1]] ) )

  for( j in 1:length( uniqueSubjectIds ) )
    {
    for( i in 1:length( hippoVolumeData ) )
      {
      hippoVolumeDataSubject <- hippoVolumeData[[i]][which( hippoVolumeData[[i]]$ID == uniqueSubjectIds[j] ),]
      hippoVolumeDataSubject <- hippoVolumeDataSubject[order( hippoVolumeDataSubject$VISIT ),]

      if( nrow( hippoVolumeDataSubject ) > 1 )
        {
        for( k in 2:nrow( hippoVolumeDataSubject ) )
          {
          # span <- interval( dmy( hippoVolumeDataSubject$EXAM_DATE[1] ), dmy( hippoVolumeDataSubject$EXAM_DATE[k] ) )
          span <- interval( mdy( hippoVolumeDataSubject$EXAM_DATE[1] ), mdy( hippoVolumeDataSubject$EXAM_DATE[k] ) )
          hippoVolumeDataSubject$VISIT[k] <- as.numeric( as.period( span ), "months" )
          }
        if( i == 1 )
          {  
          multipleTimePointSubjectsIds <- append( multipleTimePointSubjectsIds, hippoVolumeDataSubject$ID[1])  
          isMultipleTimePointSubject[j] <-  1
          # isMultipleTimePointSubject[j] <- append( isMultipleTimePointSubject, rep( 1, nrow( hippoVolumeDataSubject ) ) )
          }
        } else {
        if( i == 1 )
          {  
          multipleTimePointSubjectsIds <- append( multipleTimePointSubjectsIds, hippoVolumeDataSubject$ID[1] )  
          isMultipleTimePointSubject[j] <- append( isMultipleTimePointSubject, rep( 0, nrow( hippoVolumeDataSubject ) ) )
          }
        }
      hippoVolumeDataSubject$VISIT[1] <- 0
      hippoVolumeData[[i]][which( hippoVolumeData[[i]]$ID == uniqueSubjectIds[j] ),] <- hippoVolumeDataSubject  
      }
    setTxtProgressBar( pb, j )  
    }

  ##########
  #
  # Calculate the LME and point estimates using Rstan.
  # Compute the quantiles and write results to file.
  # 
  ##########

  stanResultsFiles <- c()
  for( i in 1:length( hippoVolumeCsvs ) )
    {
    stanResultsFiles[i] <- paste0( dataDirectory, 'stan_', hippoVolumePipelineNames[i], '_Results.csv' )   
    }  

  stanModelFile <- paste0( dataDirectory, 'stan_hippoVolumeModel.stan' )

  stanResults <- list()
  for( i in 1:length( hippoVolumeData ) )
    {
    if( file.exists( stanResultsFiles[i] ) )
      {
      cat( "Reading stan:  ", hippoVolumePipelineNames[i], "\n" )
      stanResults[[i]] <- read.csv( stanResultsFiles[i] )
      } else {
      cat( "Fitting stan:  ", hippoVolumePipelineNames[i], "\n" )

      Ni <- length( unique( hippoVolumeData[[i]]$ID ) )
      Nij <- nrow( hippoVolumeData[[i]] )
      Nk <- numberOfRegions
      Na1 <- length( multipleTimePointSubjectsIds )

      Y <- scale( as.matrix( hippoVolumeData[[i]][, volumeColumns] ) )
      timePoints <- hippoVolumeData[[1]]$VISIT	
      m <- isMultipleTimePointSubject

      ids <- as.numeric( as.factor( hippoVolumeData[[i]]$ID ) )
      slopeIds <- as.numeric( as.factor( multipleTimePointSubjectsIds ) )

      stanData <- list( Ni, Nij, Nk, Na1, Y, timePoints, m, ids, slopeIds ) 
      # fitStan <- stan( file = stanModelFile, data = stanData, cores = 1, verbose = TRUE)
      fitStan <- stan( file = stanModelFile, data = c( "Ni", "Nij", "Nk", "Na1", "Y", "timePoints", "m", "ids", "slopeIds"), 
        cores = 4, verbose = TRUE )

      fitStanExtracted <- extract( fitStan, permuted = TRUE )
 
      probs = c( 0.0, 0.025, 0.25, 0.5, 0.75, 0.975, 1.00 )

      sigma <- t( apply( fitStanExtracted$sigma, 2, quantile, probs ) )
      colnames( sigma ) <- paste0( 'sigma.', colnames( sigma ) )
      sigmaSd <- apply( fitStanExtracted$sigma, 2, sd )

      tau_0 <- t( apply( fitStanExtracted$tau_0, 2, quantile, probs ) )
      colnames( tau_0 ) <- paste0( 'tau0.', colnames( tau_0 ) )
      tau_0Sd <- apply( fitStanExtracted$tau_0, 2, sd )

      tau_1 <- t( apply( fitStanExtracted$tau_1, 2, quantile, probs ) )
      colnames( tau_1 ) <- paste0( 'tau1.', colnames( tau_1 ) )
      tau_1Sd <- apply( fitStanExtracted$tau_1, 2, sd )

      varianceRatio <- t( apply( fitStanExtracted$var_ratio, 2, quantile, probs ) )
      colnames( varianceRatio ) <- paste0( 'variance.ratio.', colnames( varianceRatio ) )
      varianceRatioSd <- apply( fitStanExtracted$var_ratio, 2, sd )

      varianceRatioExp <- t( apply( fitStanExtracted$var_ratio_experimental, 2, quantile, probs ) )
      colnames( varianceRatioExp ) <- paste0( 'variance.ratio.exp.', colnames( varianceRatioExp ) )
      varianceRatioExpSd <- apply( fitStanExtracted$var_ratio_experimental, 2, sd )

      stanResults[[i]] <- data.frame( SubFieldRegion = as.factor( SubFieldBrainGraphRegions ), 
                                      Pipeline = rep( hippoVolumePipelineNames[i], numberOfRegions ),
                                      sigma, sigma.sd = sigmaSd,
                                      tau_0, tau_0.sd = tau_0Sd,
                                      tau_1, tau_1.sd = tau_1Sd,
                                      varianceRatio, variance.ratio.sd = varianceRatioSd,
                                      varianceRatioExp, variance.ratio.exp.sd = varianceRatioExpSd
                                    )
      write.csv( stanResults[[i]], stanResultsFiles[i], row.names = FALSE )   
      }                              

    if( i == 1 )
      {
      stanResultsAll <- stanResults[[i]]
      } else {
      stanResultsAll <- rbind( stanResultsAll, stanResults[[i]] )
      }                        
    }
  }

write.csv( stanResultsAll, quote = FALSE, row.names = FALSE, 
           file = paste0( dataDirectory, "stan_ResultsAll.csv" ) )  


############################################################################################################
#
#     Plot the results
#
#     work out the colours

fsXsCol <- rgb(27,158,119, maxColorValue = 255)
ashsXsCol <- rgb(217,95,2, maxColorValue = 255)
fsLongCol <- rgb(117,112,179, maxColorValue = 255)
ashsLongCol <- rgb(231,41,138, maxColorValue = 255)
ashsDiet <- rgb(226,111,170, maxColorValue = 255)

# adapted to jitter pipelines per region, points and error bars
sigmaPlot <- ggplot( data = stanResultsAll, aes( y = sigma.50., x = SubFieldRegion, colour = Pipeline, shape = Pipeline ) ) +
              scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
              scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
              geom_errorbar( aes( ymin = sigma.2.5., ymax = sigma.97.5. ), width = 0.5, position = position_dodge2(width = .2) ) +
              geom_point( size = 2, position = position_dodge2(width = .5) ) +
              theme( axis.text.x = element_text( face = "bold", size = 8, angle = 60, hjust = 1 ) ) +
              labs( x = 'Hippocampus Formation Subfields', y = 'Residual variability', colour = "", shape = "" ) +
              theme( legend.position = "right" )
ggsave( paste0( figuresDirectory, "sigma.pdf" ), sigmaPlot, width = 10, height = 3 )


tauPlot <- ggplot( data = stanResultsAll, aes( y = tau0.50., x = SubFieldRegion, colour = Pipeline, shape = Pipeline ) ) +
              scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
              scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
              geom_point( size = 2, position = position_dodge2(width = .5)  ) +
              geom_errorbar( aes( ymin = tau0.2.5., ymax = tau0.97.5. ), width = 0.5, position = position_dodge2(width = .2) ) +
              theme( axis.text.x = element_text( face = "bold", size = 8, angle = 60, hjust = 1 ) ) +
              labs( x = 'Hippocampus Formation Subfields', y = 'Between-subject variability', colour = "", shape = "" ) +
              theme( legend.position = "right" )
ggsave( paste0( figuresDirectory, "tau.pdf" ), tauPlot, width = 10, height = 3 )


variance.ratioPlot <- ggplot ( data = stanResultsAll, aes( y = variance.ratio.50., x = SubFieldRegion, colour = Pipeline, shape = Pipeline) ) +
  scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  geom_point( size = 2, position = position_dodge2(width = .5) ) +
  geom_errorbar( aes( ymin = variance.ratio.2.5., ymax = variance.ratio.97.5. ), width = 0.5,  position = position_dodge2(width = .2) ) +
  theme( axis.text.x = element_text( face = "bold", size = 8, angle = 60, hjust = 1 ) ) +
  labs( x = 'Hippocampus Formation Subfields', y = 'Variance ratio', colour = "", shape = "" ) +
  theme( legend.position = "right" )
ggsave( paste0( figuresDirectory, "variance.ratio.pdf" ), variance.ratioPlot, width = 10, height = 3 )



allDataResults <- data.frame( Pipeline = rep( stanResultsAll$Pipeline, 3 ),
                              Measurement = factor( c( rep( 1, length( stanResultsAll$Pipeline ) ),
                                                       rep( 2, length( stanResultsAll$Pipeline ) ),
                                                       rep( 3, length( stanResultsAll$Pipeline ) ) ) ),
                              X50. = c( stanResultsAll$sigma.50., stanResultsAll$tau0.50., stanResultsAll$variance.ratio.50. ) )
levels( allDataResults$Measurement ) <- c( 'Residual variability', 'Between-subject variability', 'Variance ratio' )
#rep SubField newSubFieldRegion = factor( c( rep( SubFieldRegion, 3 ) ))
newSubFieldRegion = factor( c( rep( SubFieldBrainGraphRegions, 15 ) ))


newSubFieldRegionLevels = as.factor( newSubFieldRegion )

# allDataResults <- transform( allDataResults, Pipeline = reorder( Pipeline, X50. ) )

boxPlot <- ggplot( data = allDataResults, aes( x = Pipeline, y = X50., fill = Pipeline ) ) +
              geom_boxplot( notch = FALSE, show.legend = FALSE, outlier.shape = NA ) +
              # scale_fill_manual( "", values = colorRampPalette( c( "navyblue", "darkred" ) )(3) ) +
              scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+ # mighthave to kill this line
              scale_fill_manual( guide = FALSE, values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
              facet_wrap( ~Measurement, scales = 'free', ncol = 3 ) +
              #theme( legend.position='none' ) +
              theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) + # mighthave to kill this line
              geom_point(aes (shape = newSubFieldRegion), size = 2, position = position_dodge2(width = .5))+
              scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
              theme( legend.position= 'right') +
              labs(shape = "Hippocampus Subfield") +
              labs( x = '', y = '' )
ggsave( paste0( figuresDirectory, "allData.pdf" ), boxPlot, width = 10, height = 4 )

# residual variability
someDataResults <- data.frame( Pipeline = rep( stanResultsAll$Pipeline, 1 ),
                              Measurement = factor( c( rep( 1, length( stanResultsAll$Pipeline ) ))),
                              X50. = c( stanResultsAll$sigma.50.)) #, stanResultsAll$tau0.50., stanResultsAll$variance.ratio.50. ) )
levels( someDataResults$Measurement ) <- c( 'Residual variability')#, 'Between-subject variability', 'Variance ratio' )
someSubFieldRegion = factor( c( rep( SubFieldBrainGraphRegions, 5 ) ))

boxPlotResidualVar <- ggplot( data = someDataResults, aes( x = Pipeline, y =  X50. , fill = Pipeline ) ) +
  geom_boxplot( notch = FALSE, show.legend = FALSE, outlier.shape = NA ) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+ # mighthave to kill this line
  scale_fill_manual( guide = FALSE, values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) + # mighthave to kill this line
  geom_point(aes (shape = someSubFieldRegion), size = 2, position = position_dodge2(width = .5))+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield") +
  labs( x = 'Pipeline', y = 'Residual variability' )
ggsave( paste0( figuresDirectory, "allData_boxResidualVar.pdf" ), boxPlotResidualVar, width = 10, height = 4 )


#between subj var

someDataResults <- data.frame( Pipeline = rep( stanResultsAll$Pipeline, 1 ),
                               Measurement = factor( c( rep( 1, length( stanResultsAll$Pipeline ) ))),
                               X50. = c( stanResultsAll$tau0.50.))
levels( someDataResults$Measurement ) <- c( 'Between-subject variability')
someSubFieldRegion = factor( c( rep( SubFieldBrainGraphRegions, 5 ) ))

boxPlotBetweenVar <- ggplot( data = someDataResults, aes( x = Pipeline, y =  X50. , fill = Pipeline ) ) +
  geom_boxplot( notch = FALSE, show.legend = FALSE, outlier.shape = NA ) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+ # mighthave to kill this line
  scale_fill_manual( guide = FALSE, values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) + # mighthave to kill this line
  geom_point(aes (shape = someSubFieldRegion), size = 2, position = position_dodge2(width = .5))+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield") +
  labs( x = 'Pipeline', y = 'Between-subject variability' )
ggsave( paste0( figuresDirectory, "allData_boxBetweenVar.pdf" ), boxPlotBetweenVar, width = 10, height = 4 )

# variance ratio

someDataResults <- data.frame( Pipeline = rep( stanResultsAll$Pipeline, 1 ),
                               Measurement = factor( c( rep( 1, length( stanResultsAll$Pipeline ) ))),
                               X50. = c( stanResultsAll$variance.ratio.50.))
levels( someDataResults$Measurement ) <- c( 'Variance ratio')
someSubFieldRegion = factor( c( rep( SubFieldBrainGraphRegions, 5 ) ))

boxPlotVarRatio <- ggplot( data = someDataResults, aes( x = Pipeline, y =  X50. , fill = Pipeline ) ) +
  geom_boxplot( notch = FALSE, show.legend = FALSE, outlier.shape = NA ) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+ # mighthave to kill this line
  scale_fill_manual( guide = FALSE, values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) + # mighthave to kill this line
  geom_point(aes (shape = someSubFieldRegion), size = 2, position = position_dodge2(width = .5))+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield") +
  labs( x = 'Pipeline', y = 'Variance ratio' )
ggsave( paste0( figuresDirectory, "allData_boxVarRatio.pdf" ), boxPlotVarRatio, width = 10, height = 4 )
