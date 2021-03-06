## ----import-plot-DSM, warning=FALSE--------------------------------------

# Import DSM into R
library(raster)
library(rgdal)
library(ggplot2)
library(dplyr)

options(stringsAsFactors = FALSE)

# set working directory
# setwd("~/Documents/data/NEONDI-2016") # Mac
# setwd("~/data/NEONDI-2016")  # Windows

## ----import-chm----------------------------------------------------------

# import canopy height model (CHM).
SJER_chm <- raster("NEONdata/D17-California/SJER/2013/lidar/SJER_lidarCHM.tif")
SJER_chm

# set values of 0 to NA as these are not trees
SJER_chm[SJER_chm==0] <- NA

# plot the data
hist(SJER_chm,
     main="Histogram of Canopy Height\n NEON SJER Field Site",
     col="springgreen")


## ----read-plot-data------------------------------------------------------

# import plot centroids
SJER_plots <- readOGR("NEONdata/D17-California/SJER/vector_data",
                      "SJER_plot_centroids")


# Overlay the centroid points and the stem locations on the CHM plot
plot(SJER_chm,
     main="Plot Locations",
     col=gray.colors(100, start=.3, end=.9))

# pch 0 = square
plot(SJER_plots,
     pch = 0,
     cex = 2,
     col = 2,
     add=TRUE)


## ----extract-plot-data---------------------------------------------------


# Insitu sampling took place within 40m x 40m square plots, so we use a 20m radius.
# Note that below will return a dataframe containing the max height
# calculated from all pixels in the buffer for each plot
SJER_height <- extract(SJER_chm,
                    SJER_plots,
                    buffer = 20,
                    fun=max,
                    sp=TRUE,
                    stringsAsFactors=FALSE)


## ----explore-data-distribution, eval=FALSE-------------------------------
## 
## # cent_ovrList <- extract(chm,centroid_sp,buffer = 20)
## # create histograms for the first 5 plots of data
## # for (i in 1:5) {
## #  hist(cent_ovrList[[i]], main=(paste("plot",i)))
## #  }
## 

## ----unique-plots--------------------------------------------------------

# import the centroid data and the vegetation structure data
SJER_insitu <- read.csv("NEONdata/D17-California/SJER/2013/insitu/veg_structure/D17_2013_SJER_vegStr.csv",
                        stringsAsFactors = FALSE)

# get list of unique plots
unique(SJER_plots$Plot_ID)


## ----analyze-plot-dplyr--------------------------------------------------

# find the max stem height for each plot
insitu_maxStemHeight <- SJER_insitu %>%
  group_by(plotid) %>%
  summarise(max = max(stemheight))

head(insitu_maxStemHeight)

# let's create better, self documenting column headers
names(insitu_maxStemHeight) <- c("plotid","insituMaxHt")
head(insitu_maxStemHeight)


## ----merge-dataframe-----------------------------------------------------

# merge to create a new spatial df
#SJER_height@data <- data.frame(SJER_height@data,
#                               insitu_maxStemHeight[match(SJER_height@data[,"Plot_ID"], #insitu_maxStemHeight$plotid),])

# the code below is another way to use MERGE however it creates a normal data.frame
# rather than a spatial object. Above, we reassigned the "data" slot to
# a newly merged data frame
# merge the insitu data into the centroids data.frame
SJER_height <- merge(SJER_height,
                     insitu_maxStemHeight,
                   by.x = 'Plot_ID',
                   by.y = 'plotid')

SJER_height@data


## ----plot-w-ggplot-------------------------------------------------------

# create plot
ggplot(SJER_height@data, aes(x=SJER_lidarCHM, y = insituMaxHt)) +
  geom_point() +
  theme_bw() +
  ylab("Maximum measured height") +
  xlab("Maximum LiDAR pixel")+
  geom_abline(intercept = 0, slope=1) +
  ggtitle("Lidar Height Compared to InSitu Measured Height")


## ----ggplot-data---------------------------------------------------------

#plot with regression fit
p <- ggplot(SJER_height@data, aes(x=SJER_lidarCHM, y = insituMaxHt)) +
  geom_point() +
  ylab("Maximum Measured Height") +
  xlab("Maximum LiDAR Height")+
  geom_abline(intercept = 0, slope=1)+
  geom_smooth(method=lm)

p + theme(panel.background = element_rect(colour = "grey")) +
  ggtitle("LiDAR CHM Derived vs Measured Tree Height") +
  theme(plot.title=element_text(family="sans", face="bold", size=20, vjust=1.9)) +
  theme(axis.title.y = element_text(family="sans", face="bold", size=14, angle=90, hjust=0.54, vjust=1)) +
  theme(axis.title.x = element_text(family="sans", face="bold", size=14, angle=00, hjust=0.54, vjust=-.2))


## ----view-diff-----------------------------------------------------------

SJER_height@data$ht_diff <-  (SJER_height@data$SJER_lidarCHM - SJER_height@data$insituMaxHt)

boxplot(SJER_height@data$ht_diff)
barplot(SJER_height@data$ht_diff,
        xlab = SJER_height@data$Plot_ID)


# create bar plot
library(ggplot2)
ggplot(data=SJER_height@data, aes(x=Plot_ID, y=ht_diff, fill=Plot_ID)) +
    geom_bar(stat="identity")


## ----create-plotly, eval=FALSE-------------------------------------------
## 
## library(plotly)
## 
## # setup your plot.ly credentials
## Sys.setenv("plotly_username"="Your-User-Name")
## Sys.setenv("plotly_api_key"="Your-plotly-key")
## 
## # you must be signed into Plot.ly online on the same computer for this code to work.
## # generate the plot
## plotly_POST(p,
##             filename='NEON SJER CHM vs Insitu Tree Height') # let anyone in the world see the plot!
## 
## 

