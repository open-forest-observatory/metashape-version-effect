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

set_lidr_threads(64)

chm_files = list.files(datadir("meta200/drone/L2"), pattern="chm.tif", full.names=TRUE)


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



# Function to make a vwf with a specified slope and intercept
make_vwf <- function(intercept, slope, window_min, window_max) { 
  vwf = function(x) {
    y = intercept + slope*x
    y = pmax(y, window_min, na.rm=TRUE) # for lidR::lmf, can't go smaller than chm resolution (chm resolution is 0.12 m)
    y = pmin(y, window_max, na.rm=TRUE)
    return(y)
  }
  return(vwf)
}

## Create different sets of ttops with many different sets of VWF parameters

# Param ranges for initial search:
intercepts = seq(0, 4, by = 0.5)
slopes = seq(0,0.2, by = 0.02)
window_mins = 0.12
window_maxs = 100
smooths = c(0, 11)

vwfparams = expand.grid(intercept = intercepts,slope = slopes, window_min = window_mins, window_max = window_maxs, smooth = smooths)
vwfparams = vwfparams[!(vwfparams$intercept == 0 & vwfparams$slope == 0),] # remove ones with intercept and slope both == 0


chm_files = chm_files[c(5,37)]


for(chm_file in chm_files) {
  
  # Get CHM ID
  file_minus_extension = str_sub(chm_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  chm_name = fileparts[length(fileparts)] #take the last part of the path (the filename)
  
  chm = rast(chm_file)
  
  ## Create the needed smoothed CHMs so we only do it once per smooth, not once for each parameter set
  chm_smoothed = list()
  for(smooth in unique(vwfparams$smooth)) {
    
    if(smooth == 0) {
      chm_smoothed[["0"]] = chm
    } else {
      chm_smooth = terra::focal(chm, w=smooth, fun="mean")
      chm_smoothed[[as.character(smooth)]] = chm_smooth
    }
    
  }
  
  # Loop through all the sets of VWF tree detection parameters and run ITD for each one on the current CHM
  for(i in 1:nrow(vwfparams)) {
    
    focal_vwfparams = vwfparams[i,]
    vwf = make_vwf(intercept = focal_vwfparams$intercept, slope = focal_vwfparams$slope, window_min = focal_vwfparams$window_min, window_max = focal_vwfparams$window_max)
    
    ## load the right CHM
    chm_foc = chm_smoothed[[as.character(focal_vwfparams$smooth)]]
    
    ttops = locate_trees(chm_foc, lmf(vwf, shape="circular"))
    
    # save these ttops
    ttops_dir = datadir("meta200/drone/L3/ttops_secondvwfsearch_meta-08a16a/")
    filename = paste0("ttops_", chm_name, "_", focal_vwfparams$intercept |> pad_3dec(), "_", focal_vwfparams$slope |> pad_3dec(), "_", focal_vwfparams$window_min |> pad_3dec(), "_", focal_vwfparams$window_max |> pad_3dec(), "_", focal_vwfparams$smooth |> pad_2dig(), ".gpkg")
    file_path = paste0(ttops_dir, filename)
    
    # create dir if doesn't exist, then save
    if(!dir.exists(ttops_dir)) dir.create(ttops_dir, recursive=TRUE)
    st_write(ttops, file_path, delete_dsn = TRUE)
  
  }
}
