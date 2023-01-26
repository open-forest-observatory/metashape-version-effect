library(here)
library(terra)
library(tidyverse)
library(sf)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

# Load convenience functions including 'datadir'#
source(here("workflow/convenience-functions.R"))


#### CONSTANTS ####

CHM_DIR = datadir("meta200/drone/L1")

OUT_DIR = datadir("meta200/drone/L1/cropped")

## Project area boundary ##
focal_area = st_read(datadir("study-area-perimeter/ground_map_mask.geojson")) %>% st_transform(32610)
focal_area_buffer = st_buffer(focal_area, 20)

# Load the ortho files to crop
ortho_files = list.files(CHM_DIR, pattern="ortho.*tif$", full.names=TRUE)

if(!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

for(ortho_file in ortho_files) {
  
  # get the filename to use for saving
  file_minus_extension = str_sub(ortho_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  filename_only = fileparts[length(fileparts)]
  
  cropped_filename = paste0(OUT_DIR, "/", filename_only, "_cropped.tif")
  
  cat("\nCropping", ortho_file, "\n")
  
  if(file.exists(cropped_filename)) {
    cat("Already exists. Skipping.\n")
    next()
  }
  

  
  # crop to focal area
  ortho = rast(ortho_file)
  ortho = crop(ortho, focal_area_buffer)
  

  
  writeRaster(ortho, cropped_filename, overwrite=TRUE)

}