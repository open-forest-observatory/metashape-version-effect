## Takes all the DSM files in the Metashape outputs folder and crops them to project area, converts to CHM, rescales to 0.12 m, and saves

library(sf)
library(here)
library(purrr)
library(tidyverse)
library(terra)
#library(furrr)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

#### Convenience functions and main functions ####
source(here("workflow/convenience-functions.R"))


#### CONSTANTS ####

CHM_DIR = datadir("meta200/drone/L2/")

#### Project area boundary ####
focal_area = st_read(data("study-area-perimeter/ground_map_mask.geojson")) %>% st_transform(32610)


#### DTM

dtm = rast(data("dem_usgs/dem_usgs.tif")) %>% project(y = "epsg:26910")


## get DSM layers from metashape outputs directory
dsm_files = list.files(datadir("meta200/drone/L1"),pattern=".*_dsm\\.tif", full.names=TRUE)  # to filter to ones matching a name: pattern=paste0(las_layer_name,".*\\.las")

## remove those that are "_ortho_dsm"
is_ortho = grepl("_ortho_dsm",dsm_files)
dsm_files = dsm_files[!is_ortho]


crop_and_write_chm = function(dsm_file) {
  
  cat("Starting",dsm_file,"...")
  
  file_minus_extension = str_sub(dsm_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  filename_only = fileparts[length(fileparts)]
  filename_no_dsm = str_replace(filename_only,"_dsm","")
  
  # file to write
  filename = paste0(CHM_DIR,filename_no_dsm,"_chm.tif")
  
  # skip if file aleady exists
  if(file.exists(filename)) {
    cat("Already exists:",filename,". Skipping.\n")
    return(FALSE)
  }
  
  dsm = rast(dsm_file)
  
  # crop and mask DSM to project roi
  
  dsm <- try(
    crop(dsm, focal_area %>% st_transform(crs(dsm)))
    ,silent=TRUE)
  
  if(class(dsm) == "try-error") {
    cat("***** Skipping:", dsm_file, "because bad extent ******\n" )
    return(FALSE)
  }
  
  dsm = mask(dsm,focal_area %>% st_transform(crs(dsm)))
  
  # interpolate the the DEM to the res, extent, etc of the DSM
  dtm_interp = resample(dtm %>% project(y=crs(dsm)),dsm)
  
  
  #### Calculate canopy height model ####
  #### and save to tif
  
  # calculate canopy height model
  chm = dsm - dtm_interp
  
  # downscale to 0.12 m
  chm = project(chm,res=0.12, y = "+proj=utm +zone=10 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs", method="bilinear")
  
  
  # create dir if doesn't exist, then write
  if(!dir.exists(CHM_DIR)) dir.create(CHM_DIR)
  writeRaster(chm,filename) # naming it metashape because it's just based on metashape dsm (and usgs dtm) -- to distinguish from one generated from point cloud
  
  gc()
  
  cat("finished.\n")
  
}

#plan(multiprocess,workers=3)

map(dsm_files %>% sample, crop_and_write_chm)
