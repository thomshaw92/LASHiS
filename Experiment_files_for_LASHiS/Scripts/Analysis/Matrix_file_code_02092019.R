#install.packages("ggheatmap")
#install.packages("ggplot2",dependencies=TRUE)
#install.packages("ggExtra",dependencies=TRUE)
library(grid)
library(gridExtra)
library(ggsignif)
library(ggplot2)
library(ggExtra)
library(reshape2)
require(reshape2)

# set up directory structure and other things
baseDirectory <- 'C:/Users/uqtshaw/Google\ Drive/Projects/LASHiS/LASHiS_figures_results_etc/supplementary mats/'
ColPurple <- rgb(123,50,148, maxColorValue = 255)
ColGreen <- rgb(0,136,55, maxColorValue = 255)
ColLightGreen <- rgb(166,219,160, maxColorValue = 255)
VolMat <-matrix(c(100,621125.32,509017.38,24559.39,12676.78,37057.82,106607.47,5826.14,62.30,1177.50,89.8,55.3,107.9,444.5,96.9,65.1,12688.91,26833.01,308398.67,5253.889,31001.36,45601.33,151571.36,2786.82,0.95,6.98,1.36,2.94,1.27,3.72,0.80,1.84), byrow=T, nrow=4, ncol=8)
DiceMat <- matrix(c(100,19.67,100,5.86,100,41.29,100,6.07,1.53,23.81,100,6.95,0.72,3.63,100,0.77,4.17,0.91,4.84,1.19,3.39,2.47,6.28,3.88,0.73,0.43,1.69,0.36,0.73,0.48,0.96,0.41), byrow=T, nrow=4, ncol=8)

colnames(VolMat) <- c("Left CA1", "Left CA2", "Left DG", "Left SUB", "Right CA1", "Right CA2", "Right DG", "Right SUB")
rownames(VolMat) <- c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS")
print(VolMat)
colnames(DiceMat) <- c("Left CA1", "Left CA2", "Left DG", "Left SUB", "Right CA1", "Right CA2", "Right DG", "Right SUB")
rownames(DiceMat) <- c("Freesurfer Xs", "ASHS Xs", "Freesurfer Long", "Diet LASHiS")
print(DiceMat)

DiceData<-melt(DiceMat, na.rm = TRUE)
VolumeData<-melt(VolMat, na.rm = TRUE)
VolumeData[4] <-(c(">100",62.3,">100",0.95,">100",">100",">100",6.98,">100",89.80,">100",1.36,">100",55.30,">100",2.94,">100",">100",">100",1.27,">100",">100",">100",3.72,">100",96.90,">100",0.80,">100",65.10,">100",1.84))
print(VolumeData)
DiceData[4] <- (c(">100",1.53,4.17,0.73,19.67,23.81,0.91,0.43,">100",">100",4.84,1.69,5.86,6.95,1.19,0.36,">100",0.72,3.39,0.73,41.29,3.63,2.47,0.48,">100",">100",6.28,0.96,6.07,0.77,3.88,0.41))
print(DiceData)
##VOLUME PLOT
VolumeDataMatrixPlot <- ggplot(VolumeData, aes(Var2,Var1))+
  geom_tile(data=VolumeData, aes(fill=value), color="white")+
  scale_fill_gradient2(low = "White", high = ColPurple, mid = "white", limit = c(0,100), na.value = ColPurple,
                       midpoint = 0, space = "Lab", name=expression (atop("BF"[10],"Significance"))) +
  geom_text(aes(Var2, Var1, label = c(VolumeData$V4)), color = "black", size = 4) +
  labs(x="Subfield", y="Method", title="Volume Similarity Coefficients Bayesian t-test Comparisons with LASHiS") +
  theme_minimal()+
  theme(axis.text.x = element_text(angle = 45, vjust = 1, size = 12, hjust = 1))+
  theme(plot.title=element_text(size=11))
VolumeDataMatrixPlot
ggsave( paste0( baseDirectory, "Volume_data_significance_matrix.pdf" ), VolumeDataMatrixPlot, width = 10, height = 4 )

##DICE
DiceDataMatrixPlot <- ggplot(DiceData, aes(Var2,Var1))+
  geom_tile(data=DiceData, aes(fill=value), color="white")+
  scale_fill_gradient2(low = "white", high = ColPurple, mid = "white", limit = c(0,100), na.value = ColPurple,
                       midpoint = 0, space = "Lab", name=expression (atop("BF"[10],"Significance"))) +
  geom_text(aes(Var2, Var1, label = c(DiceData$V4)), color = "black", size = 4) +
  labs(x="Subfield", y="Method", title="Dice Coefficient Bayesian t-test Comparisons with LASHiS") +
  theme_minimal()+
  theme(axis.text.x = element_text(angle = 45, vjust = 1, size = 12, hjust = 1))+
  theme(plot.title=element_text(size=11))
DiceDataMatrixPlot
ggsave( paste0( baseDirectory, "Dice_data_significance_matrix.pdf" ), DiceDataMatrixPlot, width = 10, height = 4 )
