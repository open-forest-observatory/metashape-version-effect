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

CHM_DIR = datadir("meta200/drone/L1/cropped")

OUT_DIR = datadir("meta200/drone/L3/dpf-bboxes_run01")

# Load the ortho files to use for ITD
ortho_files = list.files(CHM_DIR, pattern="ortho.*tif$", full.names=TRUE)

if(!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

window_sizes = c(500, 1000, 1250, 1500, 1750, 2000, 2500, 3000, 4000, 5000) |> rev()



### Convenience functions for formatting numbers in filenames

# Add 2-digit leading zero to integer
pad_2dig = function(x) {
  x = as.numeric(as.character(x))
  str_pad(x, width = 2, side = "left", pad = "0")
}

# Add 3-decimal (thousandths) trailing zeros to a decimal like 1.1 and make the pre-decimal part two digits
pad_3dec = function(x) {
  x = as.numeric(as.character(x))
  x2 = format(round(x, 3), nsmall = 3)
  x3 = str_pad(x2, width = 6, side = "left", pad = "0")
  return(x3)
}


ortho_file = ortho_files[5]

for(ortho_file in ortho_files) {
  
  # get the filename to use for saving
  file_minus_extension = str_sub(ortho_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  filename_only = fileparts[length(fileparts)]
  
  for(window_size in window_sizes) {
    
    bbox_gpkg_out = paste0(OUT_DIR, "/bboxes_", filename_only, "_", "dpf", "_", "00.000", "_", "00.000", "_", "00.000", "_", "00.000", "_", window_size |> pad_3dec(), ".gpkg")

    cat("\nStarting detection for", bbox_gpkg_out, "\n")
    
    # if it already exists, skip
    if(file.exists(bbox_gpkg_out)) {
      cat("Already exists. Skipping.\n")
      next()
    }
    
    # put together the command line call
    
    call = paste("python3 workflow/run-deepforest-tree-det.py", ortho_file, window_size, bbox_gpkg_out, sep = " ")
    
    system(call)
    
  }
  
}