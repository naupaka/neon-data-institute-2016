---
layout: post
title: "Calculate NDVI from NEON Hyperspectral Remote Sensing Data in R"
date:   2016-06-17
authors: [Leah A. Wasser, Kyla Dahlin]
instructors: [Leah, Naupaka]
time: "4:45 pm"
contributors: [Edmund Hart]
dateCreated:  2016-05-01
lastModified: 2016-05-17
packagesLibraries: [rhdf5]
categories: [self-paced-tutorial]
mainTag: institute-day1
tags: [R, HDF5]
tutorialSeries: [institute-day1]
description: "Intro to HDF5"
code1: institute-materials/day1_monday/calculate_ndvi_h5.R
image:
  feature: 
  credit: 
  creditlink:
permalink: /R/calculate-ndvi/
comments: false
---

First, let's load the required libraries.


    # load libraries
    library(raster)
    library(rhdf5)
    library(rgdal)

## Load Functions

This is a lot like loading a package in R. Except the functions for this package
are in an R script stored locally on our computers. 

Once we have done the work to build our functions, we can perform routine tasks
over and over using those functions.


    source("/Users/lwasser/Documents/GitHub/neon-aop-package/neonAOP/R/aop-data.R")


## Calculate NDVI

Next we can use the `create_stack` function to create a raster stack of the
red and near-infrared bands that we need to calculate NDVI.


    # set working directory
    setwd("~/Documents/data/1_data-institute-2016")
    # Define the file name to be opened
    f <- "Teakettle/may1_subset/spectrometer/Subset3NIS1_20130614_100459_atmcor.h5"
    
    # define CRS
    epsg=32611
    
    # Calculate NDVI
    # select bands to use in calculation (red, NIR)
    ndvi_bands <- c(58, 90)
    
    #create raster list and then a stack using those two bands
    ndvi_stack <-  create_stack(ndvi_bands,
                                file = f,
                                epsg = epsg)
    
    # calculate NDVI
    NDVI <- function(x) {
    	  (x[,2]-x[,1])/(x[,2]+x[,1])
    }
    
    ndvi_rast <- calc(ndvi_stack, NDVI)
    
    # clear out plots
    # dev.off(dev.list()["RStudioGD"])
    
    plot(ndvi_rast, 
         main="NDVI for the NEON TEAK Field Site")

![ ]({{ site.baseurl }}/images/rfigs/institute-materials/day1_monday/calculate_ndvi_h5/create-NDVI-1.png)

## Export to GeoTiff


    # export as a gtif
    writeRaster(ndvi_rast, 
                file="ndvi_TEAK.tif", 
                format="GTiff", 
                overwrite=TRUE)

## Plot NDVI


    DSM <- raster("Teakettle/may1_subset/lidar/Teak_lidarDSM.tif")  
    
    slope <- terrain(DSM, opt='slope')
    aspect <- terrain(DSM, opt='aspect')
    
    # create hillshade
    hill <- hillShade(slope, aspect, 40, 270)
    
    plot(hill,
         col=grey(1:100/100),
         main="NDVI for the Teakettle Field site",
         legend=FALSE)
    
    plot(ndvi_rast, 
         add=TRUE,
         alpha=.3
         )

![ ]({{ site.baseurl }}/images/rfigs/institute-materials/day1_monday/calculate_ndvi_h5/import-lidar-1.png)


