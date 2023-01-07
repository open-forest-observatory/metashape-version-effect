library(lidR)
library(here)
library(terra)
library(tidyverse)
library(sf)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

#### Convenience functions and main functions ####
source(here("workflow/convenience-functions.R"))

set_lidr_threads(32)



chm_files = list.files(datadir("meta200/drone/L2"), pattern="chm.tif", full.names=TRUE)


chm_file = chm_files[37]

# Get CHM ID
file_minus_extension = str_sub(chm_file,1,-5)
fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
chm_name = fileparts[length(fileparts)] #take the last part of the path (the filename)

chm = rast(chm_file)


# Function to make a vwf with a specified slope and intercept
make_vwf <- function(intercept, slope) { 
  vwf = function(x) {
    y = intercept + slope*x
    y = pmax(y, 0.12, na.rm=TRUE) # can't go smaller than chm resolution (chm resolution is 0.12 m)
    return(y)
  }
  return(vwf)
}

## Create different sets of ttops with many different sets of VWF parameters

intercepts = seq(0, 10, by = 2)
slopes = seq(0,0.5, by = 0.05)

vwfparams = expand.grid(intercept = intercepts,slope = slopes)
vwfparams = vwfparams[-1,] # remove the first one which makes the window size 0 everywhere


for(i in 1:nrow(vwfparams)) {
  
  focal_vwfparams = vwfparams[i,]
  vwf = make_vwf(intercept = focal_vwfparams$intercept, slope = focal_vwfparams$slope)
  
  ttops = locate_trees(chm, lmf(vwf, shape="circular"))
  
  # save these ttops
  ttops_dir = datadir("meta200/drone/L3/ttops_initialvwfsearch/")
  filename = paste0("ttops_", chm_name, "_", focal_vwfparams$intercept, "_", focal_vwfparams$slope, ".gpkg")
  file_path = paste0(ttops_dir, filename)
  
  # create dir if doesn't exist, then save
  if(!dir.exists(ttops_dir)) dir.create(ttops_dir, recursive=TRUE)
  st_write(ttops, file_path, delete_dsn = TRUE)

}

