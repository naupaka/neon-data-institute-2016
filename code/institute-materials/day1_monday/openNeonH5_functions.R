## ----load-libraries, warning=FALSE, results='hide', message=FALSE--------

# load libraries
library(raster)
library(rhdf5)
library(rgdal)

# set wd
# setwd("~/Documents/data/NEONDI-2016") # Mac
# setwd("~/data/NEONDI-2016")  # Windows


## import functions
# install devtools (if you have not previously intalled it)
# install.packages("devtools")
# call devtools library
#library(devtools)

# install from github
# install_github("lwasser/neon-aop-package/neonAOP")
# call library
library(neonAOP)
# source a R script
# source("/Users/lwasser/Documents/GitHub/neon-aop-package/neonAOP/R/aop-data.R")

## ----get-data-dims-------------------------------------------------------

#' Get Data Dimensions ####
#'
#' This function grabs the x,y and z dimemsions of an H5 dataset called "Reflectance"
#' It would be more robust if you could pass it the dataset name / path too
#' @param fileName a path to the H5 file that you'd like to open
#' @keywords hdf5, dimensions
#' @export
#' @examples
#' get_data_dims("filename.h5")

get_data_dims <- function(fileName){
  # make sure everything is closed
  H5close()
  # open the file for viewing
  fid <- H5Fopen(fileName)
  # open the reflectance dataset
  did <- H5Dopen(fid, "Reflectance")
  # grab the dimensions of the object
  sid <- H5Dget_space(did)
  dims <- H5Sget_simple_extent_dims(sid)$size

  # close everything
  H5Sclose(sid)
  H5Dclose(did)
  H5Fclose(fid)
  return(dims)
}



## ----create-function-attrs-----------------------------------------------

#' Create h5 file extent ####
#'
#' This function uses a map tie point for an h5 file and data resolution to
#' create and return an object of class extent.
#' @param filename the path to the h5 file
#' @param res a vector of 2 objects - x resolution, y resolution
#' @keywords hdf5, extent
#' @export
#' @examples
#' create_extent(fileName, res=c(xres, yres))

create_extent <- function(fileName){
  # Grab upper LEFT corner coordinate from map info dataset
  mapInfo <- h5read(fileName, "map info")

  # create object with each value in the map info dataset
  mapInfo<-unlist(strsplit(mapInfo, ","))
  # grab the XY left corner coordinate (xmin,ymax)
  xMin <- as.numeric(mapInfo[4])
  yMax <- as.numeric(mapInfo[5])
  # get the x and y resolution
  res <- as.numeric(c(mapInfo[2], mapInfo[3]))
  # get dims to use to cal xMax, YMin
  dims <- get_data_dims(f)
  # calculate the xMAX value and the YMIN value
  xMax <- xMin + (dims[1]*res[1])
  yMin <- yMax - (dims[2]*res[2])

  # create extent object (left, right, top, bottom)
  rasExt <- extent(xMin, xMax, yMin, yMax)
  # return object of class extent
  return(rasExt)
}



## ----clean-refl-data-fun-------------------------------------------------
## FUNCTION - Clean Reflectance Data ####

#' Clean reflectance data
#'
#' This function reads in data from the "Reflecatnce" dataset, applies the data
#' ignore value, scales the data and returns a properly "projected" raster object.
#' @param filename the path to the h5 file.
#' @param reflMatrix , the matrix read in to be converted to a raster.
#' @param epsg - the epsg code for the CRS used to spatially locate the raster.
#' @keywords hdf5, extent
#' @export
#' @examples
#' clean_refl_data(fileName, reflMatrix, epsg)


clean_refl_data <- function(fileName, reflMatrix, epsg){
  # r  get attributes for the Reflectance dataset
  reflInfo <- h5readAttributes(fileName, "Reflectance")
  # grab noData value
  noData <- as.numeric(reflInfo$`data ignore value`)
  # set all values = 15,000 to NA
  reflMatrix[reflMatrix == noData] <- NA

  # apply the scale factor
  reflMatrix <- reflMatrix/(as.numeric(reflInfo$`Scale Factor`))

  # now we can create a raster and assign its spatial extent
  reflRast <- raster(reflMatrix,
                     crs=CRS(paste0("+init=epsg:", epsg)))

  # return a scaled and "cleaned" raster object
  return(reflRast)
}



## ----read-refl-data------------------------------------------------------

## FUNCTION - Read Band ####
#' read band
#'
#' This function reads in data from the "Reflecatnce" dataset, applies the data
#' ignore value, scales the data and returns a properly "projected" raster object.
#' @param filename the path to the h5 file.
#' @param index a list formated object  e.g. list(1:3, 1:6, bands)
#' @keywords hdf5, extent
#' @export
#' @examples
#' read_band(fileName, index)

read_band <- function(fileName, index){
  # Extract or "slice" data for band 34 from the HDF5 file
  aBand<- h5read(fileName, "Reflectance", index=index)
  # Convert from array to matrix so we can plot and convert to a raster
  aBand <- aBand[,,1]
  # transpose the data to account for columns being read in first
  # but R wants rows first.
  aBand<-t(aBand)
  return(aBand)
}



## ----function-open-band--------------------------------------------------
## FUNCTION - Open Band ####
#'
#' This function opens a band from an NEON H5 file using an input spatial extent. 
#' @param fileName the path to the h5 file that you wish to open. 
#' @param bandNum the band number in the reflectance data that you wish to open
#' @param epsg the epsg code for the CRS that the data are in.
#' @param subsetData, a boolean object. default is FALSE. If set to true, then
#' ... subset a slice out from the h5 file. otherwise take the entire xy extent.
#' @param dims, an optional object used if subsetData = TRUE that specifies the 
#' index extent to slice from the h5 file
#' @keywords hdf5, extent
#' @export
#' @examples
#' open_band(fileName, bandNum, epsg, subsetData=FALSE, dims=NULL)
#' 

open_band <- function(fileName, bandNum, epsg){
  # take the specified dims which may be a subset
  # note subtracting one because R indexes all values 1:3 whereas in a zero based system
  # that would yield one more value -- double check on this but it creates the proper
  # resolution
    dims <- get_data_dims(fileName)
    index <- list(1:dims[1], 1:dims[2], bandNum)
    aBand <- read_band(fileName, index)
    # clean data
    aBand <- clean_refl_data(fileName, aBand, epsg)
    extent(aBand) <- create_extent(fileName)
  
  # return raster object
  return(aBand)
}


## ----define-data-wd, results='hide'--------------------------------------
# set wd - if you haven't done so already
# setwd("~/Documents/data/NEONDI-2016/")

# define the CRS definition by EPSG code
epsg <- 32611

# define the file you want to work with
f <- "NEONdata/D17-California/TEAK/2013/spectrometer/reflectance/Subset3NIS1_20130614_100459_atmcor.h5"

h5ls(f)

## ----import-wavelength---------------------------------------------------
# import the center wavelength in um of each "band"
wavelengths<- h5read(f,"wavelength")


## ----open-plot-band------------------------------------------------------

### final Code ####
# H5close()

# find the dimensions of the data to help determine the slice range
# returns cols, rows, wavelengths
dims <- get_data_dims(fileName = f)

# open band, return cleaned and scaled raster
band <- open_band(fileName=f,
                  bandNum = 56,
                  epsg=epsg)

# plot data
plot(band,
     main="Raster for Lower Teakettle - B56")


## ----extract-many-bands--------------------------------------------------

# extract 3 bands
# create  alist of the bands
bands <- list(58, 34, 19)

# use lapply to run the band function across all three of the bands
rgb_rast <- lapply(bands, open_band,
                   fileName=f,
                   epsg=epsg)

# create a raster stack from the output
rgb_rast <- stack(rgb_rast)

# plot the output, use a linear stretch to make it look nice
plotRGB(rgb_rast,
        stretch='lin')


## ----create-CIR-stack----------------------------------------------------

## FUNCTION - Open Bands, Create Stack ####
#'
#' This function calculates an index based subset to slice out data from an H5 file
#' using an input spatial extent. It returns a rasterStack object of bands.
#' @param fileName the path to the h5 file that you wish to open.
#' @param bandNum the band number in the reflectance data that you wish to open
#' @param epsg the epsg code for the CRS that the data are in.
#' @param subsetData, a boolean object. default is FALSE. If set to true, then
#' ... subset a slice out from the h5 file. otherwise take the entire xy extent.
#' @param dims, an optional object used if subsetData = TRUE that specifies the
#' index extent to slice from the h5 file
#' @keywords hdf5, extent
#' @export
#' @examples
#' open_band(fileName, bandNum, epsg, subsetData=FALSE, dims=NULL)
#'

#
create_stack <- function(file, bands, epsg, subset=FALSE, dims=NULL){
  # use lapply to run the band function across all three of the bands
  rgb_rast <- lapply(bands, open_band,
                     fileName=file,
                     epsg=epsg)

  # create a raster stack from the output
  rgb_rast <- stack(rgb_rast)
  # reassign band names
  names(rgb_rast) <- bands
  return(rgb_rast)
}


plot_stack <- function(aStack, title="3 band RGB Composite", theStretch='lin'){
  # takes a stack and plots it with a title
  # tricker to force the plot title to appear nicely
  # original_par <-par() #original par
  par(col.axis="white", col.lab="white", tck=0)
  # plot the output, use a linear stretch to make it look nice
  plotRGB(aStack,
          stretch=theStretch,
          axes=TRUE,
          main=title)
  box(col="white")
  # par(original_par) # go back to original par
}


## ----plot-band-combos----------------------------------------------------

# CIR create  alist of the bands
bands <- c(90, 34, 19)

CIRStack <- create_stack(f, 
                         bands, 
                         epsg)
plot_stack(CIRStack,
           title="Color Infrared (CIR) Image")

# create a list of the bands
bands <- list(152,90,58)
aStack <- create_stack(f, bands, epsg)
plot_stack(aStack,
           title="another combo")

# FALSE COLOR create a list of the bands
bands <- list(363, 246, 58)
falseStack <- create_stack(f, bands, epsg)
plot_stack(falseStack,
              title="False Color Image")


## ----write-raster, eval=FALSE--------------------------------------------
## 
## # export as a GeoTIFF
## writeRaster(CIRStack,
##             file="Outputs/TEAK/cirImage_2013.tif",
##             format="GTiff",
##             overwrite=TRUE)

