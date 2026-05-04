library(BayesFactor)
library(ggplot2)
library(grid)
library(gridExtra)
library(ggsignif)

# set up directory structure
baseDirectory <- 'path/to/github/dir/Scripts/Analysis/LASHiS_experiment_one/'
dataDirectory <- paste0( baseDirectory, 'github/dir/LASHiS/Experiment_files_for_LASHiS/Data/test_retest_data')
figuresDirectory <- paste0( baseDirectory, 'Figures')

# set up variables of interest
corticalThicknessPipelineNames <- c( 'Freesurfer XS', 'ASHS XS', 'Freesurfer Long', 'Diet LASHiS', 'LASHiS')
numberOfRegions <- 8
pptIDs <- c('1', '2', '3', '4', '5', '6', '7')
bayesMeans <- read.csv( paste0( dataDirectory, 'bayesMeans.csv' ) )
bayesSDs <- read.csv( paste0( dataDirectory, 'bayesSDs.csv' ) )
SubFieldRegions <- read.csv( paste0( dataDirectory, 'subfields.csv' ) )
SubFieldBrainGraphRegions <- SubFieldRegions$brainGraph[( nrow( SubFieldRegions ) - numberOfRegions + 1 ):nrow( SubFieldRegions )]
SubFieldBrainGraphRegions <- gsub( " ", "", SubFieldBrainGraphRegions ) 

mean_ic <- bayesMeans$mean_ic
mean_mutual <- bayesMeans$mean_mutual
mean_volSim <- bayesMeans$mean_volSim
mean_dice <- bayesMeans$mean_dice
pipelines <- bayesMeans$Pipeline

sd_ic <- bayesSDs$sd_ic
sd_mutual <-  bayesSDs$sd_mutual
sd_volSim <-  bayesSDs$sd_volSim
sd_dice <-  bayesSDs$sd_dice
SubFieldRegion <- bayesMeans$DktRegion
Pipeline <- bayesMeans$Pipeline
positions <- c( "Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS")

# work out the colours
fsXsCol <- rgb(27,158,119, maxColorValue = 255)
ashsXsCol <- rgb(217,95,2, maxColorValue = 255)
fsLongCol <- rgb(117,112,179, maxColorValue = 255)
ashsLongCol <- rgb(231,41,138, maxColorValue = 255)
ashsDiet <- rgb(226,111,170, maxColorValue = 255)
 
###BOXPLOTS
## volSim mean boxplot  
bayesMeansBoxPlotVol <- ggplot (data = bayesMeans, aes(fill = factor(Pipeline, levels=c( "Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS")), x = Pipeline, y = mean_volSim ) ) +
  geom_boxplot(notch = FALSE, show.legend = FALSE) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+
  scale_fill_manual(guide = FALSE, "", values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  scale_colour_manual(guide = FALSE,values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  labs(x = 'Method', y = 'Volume Similarity Coefficient', show.legend = FALSE )+
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) +
  geom_point (aes (shape=SubFieldRegion), na.rm=TRUE, position=position_dodge2(width = .5), size = 4)+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield")
  ggsave( paste0( figuresDirectory, "bayesMeanVolSimBOX.pdf" ), bayesMeansBoxPlotVol, width = 10, height = 4 )
bayesMeansBoxPlotVol
##############
## DICE mean boxplot  
bayesMeansBoxPlotDICE <- ggplot (data = bayesMeans, aes(fill = factor(Pipeline, levels = positions), x = Pipeline, y = mean_dice ) ) +
  geom_boxplot(notch = FALSE, show.legend = FALSE) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+
  scale_fill_manual(guide = FALSE, "", values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  scale_colour_manual(guide = FALSE,values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  labs(x = 'Method', y = 'Dice Coefficient', show.legend = FALSE )+
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) +
  geom_point (aes (shape=SubFieldRegion), na.rm=TRUE, position=position_dodge2(width = .5), size = 4)+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield")
ggsave( paste0( figuresDirectory, "bayesMeanDiceSimBOX.pdf" ), bayesMeansBoxPlotDICE, width = 10, height = 4 )
bayesMeansBoxPlotDICE
##############

allBoxDataResults <- data.frame( Pipeline = rep( bayesMeans$Pipeline, 2 ), 
                              Measurement = factor( c( rep( 1, length( bayesMeans$Pipeline ) ), 
                                                       rep( 2, length( bayesMeans$Pipeline ) ) ) ), 
                              xmeans. = c( bayesMeans$mean_dice, bayesMeans$mean_volSim ) )
levels( allBoxDataResults$Measurement ) <- c( 'Dice Coefficient', 'Volume Similarity Coefficient' )
newDktRegion = factor( c( rep( SubFieldBrainGraphRegions, 10 ) ))

AboxPlot <- ggplot( data = allBoxDataResults, aes( x = Pipeline, y = xmeans., fill = factor(Pipeline, levels=c( "Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS")) ) ) +
  geom_boxplot( notch = FALSE, show.legend = FALSE ) +
  scale_x_discrete(limits=c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS", "LASHiS"))+
  scale_fill_manual(guide = FALSE, "", values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  facet_wrap( ~Measurement, scales = 'free', ncol = 3 ) +
  theme( legend.position='none' ) +
  theme( axis.text.x = element_text( face="bold", size = 10, angle = 45, hjust = 1 ) ) +
  geom_point(aes (shape = newDktRegion), size = 3, position = position_dodge2(width = .5))+
  scale_shape_manual(values = c(15,16,17,18,0,1,2,5))+
  theme( legend.position= 'right') +
  labs(shape = "Hippocampus Subfield") +
  labs( x = '', y = '' )
ggsave( paste0( figuresDirectory, "allBoxData_test-retest.pdf" ), AboxPlot, width = 10, height = 5 )


#############################################################################################################################################################

## volSim mean plot  
bayesMeansPlotVol <- ggplot (data = bayesMeans, aes( fill=factor(Pipeline, levels=positions), y = mean_volSim, x = SubFieldRegion )) +
  scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  ylim(c(0, 1.2))+
  geom_bar(position="dodge", stat="identity")+
  geom_errorbar(aes ( ymin = (bayesMeans$mean_volSim - bayesSDs$sd_volSim), ymax = (bayesMeans$mean_volSim + bayesSDs$sd_volSim)), width = 0.2, position = position_dodge(width = .9) ) +
  theme( axis.text.x = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
  theme( axis.text.y = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
  theme(legend.title = element_blank())+
  labs( x = 'Hippocampus Formation Subfields', y = 'Volume Similarity Coefficient Mean', colour = "", shape = "" )
  bayesMeansPlotVol+geom_path(x=c(1,1,2,2),y=c(.23,.25,.25,.23))+
  geom_path(x=c(.2,.2,.3,.3),y=c(.23,.25,.25,.23))+
  geom_path(x=c(.3,.3,.4,.4),y=c(.23,.25,.25,.23))+
  annotate("text",x=.5,y=.5,label="p=0.012")+
  annotate("text",x=.5,y=.5,label="p<0.0001")+
  annotate("text",x=.5,y=.5,label="p<0.0001")
  ggsave( paste0( figuresDirectory, "bayesMeanVolSim.pdf" ), bayesMeansPlotVol, width = 10, height = 3.5 )
  
  # dioce mean plot  
  bayesMeansPlotdice <- ggplot (data = bayesMeans, aes( fill=factor(Pipeline, levels=positions), y = mean_dice, x = SubFieldRegion )) +
    scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
    scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
    ylim(c(0, 1.2))+
    geom_bar(position="dodge", stat="identity")+
    geom_errorbar(aes ( ymin = (bayesMeans$mean_dice - bayesSDs$sd_dice), ymax = (bayesMeans$mean_dice + bayesSDs$sd_dice)), width = 0.2, position = position_dodge(width = .9) ) +
    theme( axis.text.x = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
    theme( axis.text.y = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
    theme(legend.title = element_blank())+
    labs( x = 'Hippocampus Formation Subfields', y = 'Dice Coefficient Mean', colour = "", shape = "" )
  bayesMeansPlotVol+geom_path(x=c(1,1,2,2),y=c(.23,.25,.25,.23))+
    geom_path(x=c(.2,.2,.3,.3),y=c(.23,.25,.25,.23))+
    geom_path(x=c(.3,.3,.4,.4),y=c(.23,.25,.25,.23))+
    annotate("text",x=.5,y=.5,label="p=0.012")+
    annotate("text",x=.5,y=.5,label="p<0.0001")+
    annotate("text",x=.5,y=.5,label="p<0.0001")
  ggsave( paste0( figuresDirectory, "bayesDice.pdf" ), bayesMeansPlotdice, width = 10, height = 3.5 )
  
  
  ######################################
  #i think this is all garbageVV
  
  df<-data.frame(group=c("A","B","C","D"),numb=c(12,24,36,48))
  g<-ggplot(bayesMeansPlotVol,aes(group,numb))+geom_bar(stat="identity")
  g+geom_path(x=c(1,1,2,2),y=c(25,26,26,25))+
    geom_path(x=c(2,2,3,3),y=c(37,38,38,37))+
    geom_path(x=c(3,3,4,4),y=c(49,50,50,49))+
    annotate("text",x=1.5,y=27,label="p=0.012")+
    annotate("text",x=2.5,y=39,label="p<0.0001")+
    annotate("text",x=3.5,y=51,label="p<0.0001")
  
  
  ## DICE mean plot  
  bayesMeansPlotDice <- ggplot (data = bayesMeans, aes( fill=factor(Pipeline, levels=positions), y = mean_dice, x = SubFieldRegion )) +
    scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
    scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
    ylim(c(0, 1))+
    geom_bar(position="dodge", stat="identity")+
    geom_errorbar(aes ( ymin = (bayesMeans$mean_dice - bayesSDs$sd_dice), ymax = (bayesMeans$mean_dice + bayesSDs$sd_dice)), width = 0.2, position = position_dodge(width = .9) ) +
    geom_signif(y_position=c(0.4, 0.6), xmin=c(0.09, 0.18), xmax=c(0.18, 0.27),
                annotation = c("***"),
                tip_length = 0,
                vjust =0.2) +
   ## geom_sign
  theme( axis.text.x = elemen, text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
    theme( axis.text.y = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
    theme(legend.title = element_blank())+
    labs( x = 'Hippocampus Formation Subfields', y = 'Dice Similarity Coefficient Mean', colour = "", shape = "" ) 
  ggsave( paste0( figuresDirectory, "bayesMeanDice.pdf" ), bayesMeansPlotDice, width = 10, height = 3 )

## DICE mean plot  
bayesMeansPlotDice <- ggplot (data = bayesMeans, aes( fill=factor(Pipeline, levels=positions), y = mean_dice, x = SubFieldRegion )) +
  scale_fill_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) +
  scale_colour_manual(values = c( fsXsCol, ashsXsCol, fsLongCol, ashsDiet , ashsLongCol ) ) + 
  ylim(c(0, 1.2))+
  geom_bar(position="dodge", stat="identity")+
  geom_errorbar(aes ( ymin = (bayesMeans$mean_dice - bayesSDs$sd_dice), ymax = (bayesMeans$mean_dice + bayesSDs$sd_dice)), width = 0.2, position = position_dodge(width = .9) ) +
  #theme( axis.text.x = elemen, text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
  #theme( axis.text.y = element_text( face = "bold", size = 8, angle = 60, hjust = 1 )) +
  #theme(legend.title = element_blank())+
  #labs( x = 'Hippocampus Formation Subfields', y = 'Dice Similarity Coefficient Mean', colour = "", shape = "" ) 
ggsave( paste0( figuresDirectory, "bayesMeanDice.pdf" ), bayesMeansPlotDice, width = 10, height = 3 )


bayesMeansPlotDice + geom_line(data = df1, aes(x = a, y = b)) + annotate("text", x = 2, y = 42, label = "*", size = 8) +
  geom_line(data = df2, aes(x = a, y = b)) + annotate("text", x = 1.5, y = 38, label = "**", size = 8) +
  geom_line(data = df3, aes(x = a, y = b)) + annotate("text", x = 2.5, y = 27, label = "n.s.", size = 8)

