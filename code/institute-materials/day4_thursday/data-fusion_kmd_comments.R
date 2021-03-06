## ----load-libraries, warning=FALSE, results='hide', message=FALSE--------
# load libraries
library(raster)
library(rhdf5)
library(rgdal)

# setwd("C:/Users/kdahlin/Dropbox/NEON_WWDI_2016")
setwd("~/Documents/data/1_data-institute-2016")

## ----import-h5-functions-------------------------------------------------

# your file will be in your working directory! This one happens to be in a diff dir
# than our data

# source("C:/Users/kdahlin/Dropbox/NEON_WWDI_2016/hdfcode/import-HSIH5-functions.R")

# new improved - import functions
# this is also an R package!
source("/Users/lwasser/Documents/GitHub/neon-aop-package/neonAOP/R/aop-data.R")

## ----import-lidar--------------------------------------------------------

# note: plotting to look at things as you go is always recommmended!

# first we read in the LiDAR data

# dsm = digital surface model == top of canopy
dsm <- raster("NEONdata/D17-California/TEAK/2013/lidar/Teak_lidarDSM.tif")
# dtm = digital terrain model = elevation
dtm <- raster("NEONdata/D17-California/TEAK/2013/lidar/Teak_lidarDTM.tif")

# rename to CHM
# chm <- dsm - dtm
chm <- raster("NEONdata/D17-California/TEAK/2013/lidar/Teak_lidarCHM.tif")
# assign chm values of 0 to NA
### I actually think we shouldn't do this - by setting all of the zeros to NAs it
### effectively changes this analysis to only consider vegetated pixels, which we
### don't(?) want to do... at least the question I originally had in mind was
### 'Across this landscape, are more pixels tall and green on north-facing than
### south-facing slopes?' EVER so subtly different from saying 'Of the pixels that
### have some vegetation structure, are they more tall and green on northfacing
### slopes?' plus removing it solves the 'very few pixels on south facing' problem
### because having all those zeros changes the s.d. a lot for the 'tall.def' parameter
#chm[chm==0] <- NA

# do the numbers look reasonable? 60 m is tall for a tree, but
# this is Ponderosa pine territory (I think), so not out of the question.
plot(chm,
     main="Canopy Height - Teakettle \nCalifornia")

hist(chm,
     main="Distribution of Canopy Height - Teakettle \nCalifornia",
     xlab="Tree Height (m)",
     col="springgreen")


## ----create-stack--------------------------------------------------------
# for simplicity later let's stack these rasters together
#
# do we need the dtm dsm??
lidar.brick <- brick(dsm, dtm, chm)


## ----read-hsi-data-------------------------------------------------------

# first identify the file of interest
f <- "NEONdata/D17-California/TEAK/2013/spectrometer/reflectance/Subset3NIS1_20130614_100459_atmcor.h5"
# then id the projection code
# define the CRS definition by EPSG code
epsg <- 32611

# create a list of bands
bands <- c(60,83)

# Let's read in a few spectral bands as a stack using a function
ndvi.stack <- create_stack(f,bands = bands,
             epsg=epsg)

# calculate ndvi
ndvi <- (ndvi.stack[[2]]-ndvi.stack[[1]]) / (ndvi.stack[[2]]+ndvi.stack[[1]])
names(ndvi) <- "Teak_hsiNDVI"
# check the extents of the two layers -- if they are different
# crop both datasets
if (extent(chm) == extent(ndvi)){
  } else {
  overlap <- intersect(extent(ndvi), extent(lidar.brick))
  # now let's crop the lidar data to the HSI data
  lidar.brick <- crop(lidar.brick, overlap)
  ndvi <- crop(ndvi, overlap)
  print("Extents are different, cropping data")
  }


# Create a brick from all of the data
all.data <- brick(ndvi, lidar.brick)


## ----import-aspect-------------------------------------------------------

# (1) calculate aspect of cropped DTM
# aspect <- terrain(all.data[[3]], opt = "aspect", unit = "degrees", neighbors = 8)
aspect <- raster("NEONdata/D17-California/TEAK/2013/lidar/Teak_lidarAspect.tif")
# crop the data to the extent of the other rasters we are working with!
aspect <- crop(aspect, extent(ndvi))

# Create a classified intermediate product
# create mask --
# (2) make 'dummy' (1s and 0s) layers for north facing (315 deg to 45 deg) and
# south facing (135 deg to 225 deg) slopes

# the other option is to create a CLASSIFIED RASTER
# if that is classified than you can have a nice intermediate raster

# first create a matrix of values that represent the classification ranges
# North face = 1
# South face = 2
class.m <- c(0, 45, 1, 
             45, 135, NA, 
             135, 225, 2,  
             225 , 315, NA, 
             315, 360, 1)
rcl.m <- matrix(class.m, ncol=3, byrow=TRUE)
asp.ns <- reclassify(aspect, rcl.m)

plot(asp.ns,
     col=c("white","blue","green"),
     axes=F,
     main="North and South Facing Slopes \nTeakettle")

# all values larger than 315 and less than 45 are north facing
# north.facing <- aspect >= 315 | aspect <= 45
# all values bewteen 135 and 225 are south facing
# south.facing <- aspect >= 135 & aspect <= 225
north.facing <- asp.ns==1
south.facing <- asp.ns==2

north.facing[north.facing == 0] <- NA
south.facing[south.facing == 0] <- NA


## ----write-geotiff, eval=FALSE-------------------------------------------
## 
## # export geotiff
## 
## writeRaster(asp.ns,
##             filename="outputs/TEAK/Teak_nsAspect.tif",
##             format="GTiff",
##             options="COMPRESS=LZW",
##             overwrite = TRUE,
##             NAflag = -9999)
## 
## 

## ----id-veg-metrics------------------------------------------------------
# (3) to choose what we mean by 'tall' and 'green' let's look at some histograms
# and descriptive stats(of the whole dataset, we don't want to bias our results
# too much!)

# histogram of tree ht
hist(all.data[[4]],
     main="Distribution of CHM values \nTeakettle")

# it's hard to tell here where the data maxes out, so we can calc the actual max
# but to do that without converting our raster to a vector, we use 'cellStats'

ht.max <- cellStats(all.data[[4]],
                    max)

# and some more exploration - even though this is a very skewed data set...
ht.mean <- cellStats(all.data[[4]],
                     mean)
ht.sd <- cellStats(all.data[[4]],
                   sd)

# so let's be semi-robust and call 'tall' trees those with mean + 1 sd
tall.def <- ht.mean + ht.sd


## ----explore-ndvi--------------------------------------------------------
# now let's look at ndvi
hist(all.data[[1]],
     main="Distribution of NDVI values\n Teakettle")

# this is a nice bimodal data set, so let's just take the top 1/3 of the data
# could take the 3rd quartile
# do this using summary stats
stats <- summary(all.data[[1]])
stats[["3rd Qu.",1]]

# or manually calculate this
green.range <- cellStats(all.data[[1]], max) - cellStats(all.data[[1]], min)
green.def <- cellStats(all.data[[1]], max) - (green.range/3)


# (4) compare fractions of tall & green on north and south facing slopes (since
# our pixels are 1x1 m we can just use counts of pixels and not worry about area)
# remember that N=1 and South facing = 2
north.count <- freq(asp.ns, value =1)
south.count <- freq(asp.ns, value =2)

# note there's way more south facing area in this image than north facing

# create a new layer with pixels that are north facing,
north.tall.green <- asp.ns == 1  & all.data[[1]] >= green.def &
                    all.data[[4]] >= tall.def

north.tall.green.count <- cellStats(north.tall.green, sum)

south.tall.green <- asp.ns == 2 & all.data[[1]] >= green.def &
  all.data[[4]] >= tall.def

south.tall.green.count <- cellStats(south.tall.green, sum)

# divide the number of pixels that are green by the total north or south facing pixels
north.tall.green.frac <- north.tall.green.count/freq(asp.ns, value=1)
south.tall.green.frac <- south.tall.green.count/freq(asp.ns, value=2)
### changed this to value = 2!

# if we look at these fracs, >16% of the pixels on north facing slopes should
# meet our tall and green criteria, while <4% of the pixels on south facing
# slopes do. So that's reassuring. (changed for new dataset, keeping chm zeros)


## ----view-cir------------------------------------------------------------
# before moving on, let's make a map to see what this looks like on the ground
# first read in a green band so we can make a color infrared RGB image - let's
# use ~550 nm here, or band 35


# create a list of bands
bands <- c(83, 60, 35)

# Let's read in a few spectral bands as a stack using a function
cir.stack <- create_stack(file=f,
                          bands = bands,
                          epsg=epsg)

# ignore reflectance values > 1
cir.stack[cir.stack > 1] <- NA

# turn your tall north and south 1/0 layers into 1/NA so NAs are transparent

north.tall.green[north.tall.green == 0] <- NA
south.tall.green[south.tall.green == 0] <- NA


plotRGB(cir.stack, 
        scale = 1, 
        stretch = "lin")

plot(north.tall.green, col = "cyan", add = T, legend = F)
plot(south.tall.green, col = "blue", add = T, legend = F)

# two side notes: I (Kyla) really don't like using R to make maps - I usually
# export tifs and pull them into a real mapping program like Arc or QGIS for
# actual cartography. R is just a bit clunky, especially for legends, etc.
# also, note here that there are clusters where 'south facing' and 'north facing'
# pixels are very close together - this is due to the very fine resolution of the
# topo data. One might want to either smooth this data (low-pass filter) or
# use a larger kernel to calculate slope (not possible with the terrain fxn in
# the raster package)


## ----run-stats-----------------------------------------------------------
# (5) let's do some stats! t-test and boxplots of veg height and greenness
# distributions in north versus south facing parts of scene.

# let's start with NDVI - isolate NDVI on north and south facing slopes

north.NDVI <- all.data[[1]] * north.facing
south.NDVI <- all.data[[1]] * south.facing

# now let's do veg height
north.veght <- all.data[[4]] * north.facing
south.veght <- all.data[[4]] * south.facing

# now to do more complicated non-spatial stats in R we need to convert our
# raster data to vectors - for this example the spatial distribution of the
# data doesn't matter.

north.NDVI.vec <- getValues(north.NDVI)
south.NDVI.vec <- getValues(south.NDVI)

north.veght.vec <- getValues(north.veght)
south.veght.vec <- getValues(south.veght)

# and get rid of NAs for simplicity (the above vectors are all the same length
# and include all the cells in the original dataset)

north.NDVI.vec <- north.NDVI.vec[!is.na(north.NDVI.vec)]
south.NDVI.vec <- south.NDVI.vec[!is.na(south.NDVI.vec)]

# now let's make a data frame with a north versus south column
aspect.NDVI <- c(rep("north", length(north.NDVI.vec)),
                 rep("south", length(south.NDVI.vec)))
aspect.NDVI <- as.factor(aspect.NDVI)

NDVI.vec <- c(north.NDVI.vec, south.NDVI.vec)

# this (below) is clunky - I thought I could use cbind but 'factors' are getting the
# best of me
NDVI.dat <- as.data.frame(matrix(NA, nrow = length(NDVI.vec), ncol = 2))
names(NDVI.dat) <- c("aspect", "NDVI")
NDVI.dat[,1] <- aspect.NDVI
NDVI.dat[,2] <- NDVI.vec
boxplot(NDVI ~ aspect, data = NDVI.dat, col = "cornflowerblue", main = "NDVI
        on North versus South facing slopes")

# and now a t-test - note that since these aren't normally distributed, this
# might not be the best approach, but ok for a quick assessment.
NDVI.ttest <- t.test(north.NDVI.vec, south.NDVI.vec, alternative = "greater")



# and now for veg height
north.veght.vec <- north.veght.vec[!is.na(north.veght.vec)]
south.veght.vec <- south.veght.vec[!is.na(south.veght.vec)]

# now let's make a data frame with a north versus south column
aspect.veght <- c(rep("north", length(north.veght.vec)),
                 rep("south", length(south.veght.vec)))
aspect.veght <- as.factor(aspect.veght)

veght.vec <- c(north.veght.vec, south.veght.vec)

veght.dat <- as.data.frame(matrix(NA, nrow = length(veght.vec), ncol = 2))
names(veght.dat) <- c("aspect", "veght")
veght.dat[,1] <- aspect.veght
veght.dat[,2] <- veght.vec
boxplot(veght ~ aspect, data = veght.dat, col = "aquamarine4", main = "Veg Ht
        on North versus South facing slopes")

# same caution as above!
veght.ttest <- t.test(north.veght.vec, south.veght.vec, alternative = "greater")



