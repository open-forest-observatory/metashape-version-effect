library(lidR)
library(ForestTools)
library(here)
library(terra)
library(tidyverse)
library(sf)
library(furrr)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

# Load convenience functions including 'datadir'#
source(here("workflow/convenience-functions.R"))

### CONSTANTS ###

# Maximum number of detected trees that is at all reasonable. If more than this are detected, the results will not be saved (to save on file storage)
MAX_TREE_COUNT = 10000

## Specify the different sets of VWF parameters as fully factorial combo of the following parameters
# For lidR LMF
method = "lmf"
intercepts = seq(0, 2.5, by = 0.5)
slopes = seq(0,0.12, by = 0.02)
window_mins = c(0.5, 1, 2)
window_maxs = 100
smooths = c(0, 3, 7, 11)

# A lidR LMF set with negative intercepts
neg_method = "lmf"
neg_intercepts = seq(0, -2, by = -0.5)
neg_slopes = seq(0.05,0.24, by = 0.02)
neg_window_mins = c(0.5, 1, 2)
neg_window_maxs = 100
neg_smooths = c(0, 3, 7, 11)

# For ForestTools VWF (a negative slope is the cue that it's supposed to be run through VWF, but in the actual window function it's treated as a postiive slope)
ft_method = "vwf"
ft_intercepts = seq(0, 0.4, by = 0.2)
ft_slopes = seq(0.02, 0.06, by = 0.02)
ft_window_mins = c(0.0001, 1)
ft_window_maxs = 100
ft_smooths = c(0, 3, 7, 11)

# A VWF set with negative intercepts
neg_ft_method = "vwf"
neg_ft_intercepts = seq(0, -0.4, by = -0.2)
neg_ft_slopes = seq(0.04,0.08, by = 0.02)
neg_ft_window_mins = c(0.0001, 1)
neg_ft_window_maxs = 100
neg_ft_smooths = c(0, 3, 7, 11)


# # Param ranges used for initial search:
# intercepts = seq(0, 4, by = 0.5)
# slopes = seq(0,0.2, by = 0.02)
# window_mins = 0.12
# window_maxs = 100
# smooths = c(0, 11)

## Specify output dir
ttops_dir = datadir("meta200/drone/L3/ttops_fullrun02/")

## Get the file listing of the output dir (to determine if a file we aim to produce already exists)
ttops_dir_contents = list.files(ttops_dir, full.names=TRUE)
# remove double slsahes
ttops_dir_contents = str_replace(ttops_dir_contents, fixed("//"), "/")


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



### Busines logic functions ###

# Function to make a vwf with a specified slope and intercept
make_vwf <- function(method, intercept, slope, window_min, window_max) { 
  vwf = function(x) {
    y = intercept + slope*x 
    #if(method == "lmf") { # When running ForestTools::vwf, don't set floor or ceiling
      y = pmax(y, window_min, na.rm=TRUE) # for lidR::lmf, can't go smaller than chm resolution (chm resolution is 0.12 m)
      y = pmin(y, window_max, na.rm=TRUE)
    #}
    return(y)
  }
  return(vwf)
}

# Function (to use with 'walk' or parallel 'future_walk') for detecing trees from one chm file, using all vwf parameter sets
itd_onechm_allvwfs = function(chm_file) {
  
  # Get CHM ID
  file_minus_extension = str_sub(chm_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  chm_name = fileparts[length(fileparts)] #take the last part of the path (the filename)
  
  ## See if it's already been run completely for this CHM, and if so, skip
  # How many output files should there be for this chm?
  n_ttop_output_files_expected = nrow(vwfparams)
  # How many output files exist matching this CHM name?
  n_ttop_output_files_actual = sum(grepl(chm_name, ttops_dir_contents))
  
  if(n_ttop_output_files_actual == n_ttop_output_files_expected) {
    cat("\nCHM already processed:", chm_name, " -- Skipping.")
    return(TRUE)
  }
  
  
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
  itd_onevwfparamset = function(focal_vwfparams) {
    
    # Filename / path to save to
    filename = paste0("ttops_", chm_name, "_", focal_vwfparams$method, "_", focal_vwfparams$intercept |> pad_3dec(), "_", focal_vwfparams$slope |> pad_3dec(), "_", focal_vwfparams$window_min |> pad_3dec(), "_", focal_vwfparams$window_max |> pad_3dec(), "_", focal_vwfparams$smooth |> pad_2dig(), ".gpkg")
    file_path = paste0(ttops_dir, filename)
    filepath_placeholder = str_replace(file_path,".gpkg$", ".txt_placeholder") # this is used instead of writing a gpkg when the tree detection results are unrealistic. save this placeholder so we don't have to run the ITD again when rerunning
    
    ## Does the output exist already? Skip if so
    if((file_path %in% ttops_dir_contents) | (filepath_placeholder %in% ttops_dir_contents)) {
      cat("\nFile", file_path, "already exists. Skipping.")
      return(TRUE)
    }
    
    cat("\nStarting to to process for non-existing file:", filename,"\n")
    
    variable_window_function = make_vwf(method = focal_vwfparams$method, intercept = focal_vwfparams$intercept, slope = focal_vwfparams$slope, window_min = focal_vwfparams$window_min, window_max = focal_vwfparams$window_max)
    
    ## load the right CHM
    chm_foc = chm_smoothed[[as.character(focal_vwfparams$smooth)]]
    
    ## if the slope is positive, that is the flag that we should run lidR::lmf
    if(focal_vwfparams$method == "lmf") {
      ttops = lidR::locate_trees(chm_foc, lmf(variable_window_function, shape="circular", hmin = 5))
    } else if(focal_vwfparams$method == "vwf")  {
    ## if the slope is negative, that is the flag that we should run ForestTools::vwf
      chm_foc = raster::raster(chm_foc)
      ttops = ForestTools::vwf(CHM = chm_foc, winFun = variable_window_function, minHeight = 5, maxWinDiameter = 199)
      ttops = st_as_sf(ttops)
    }
    
    # if there are too many ttops, don't save them, but write a placeholder file so we don't try again
    if(nrow(ttops) > MAX_TREE_COUNT) {
      write(paste0("Dummy placeholder because ttops predicted were unrealistic so not worth saving the file. Ttops detected: ", nrow(ttops)), file = filepath_placeholder)
      return(FALSE)
    }
    
    # save
    st_write(ttops, file_path)
  }
  
  vwfparams_list = split(vwfparams, seq(nrow(vwfparams))) # make into a list of single-row DFs to use in 'walk' function
  walk(vwfparams_list, itd_onevwfparamset) # can't parallelize due to the SpatRaster not in memory (file pointer)

}

### Run the process ###

# Create output dir if doesn't exist
if(!dir.exists(ttops_dir)) dir.create(ttops_dir, recursive=TRUE)

# Create factorial combo of vwf params
vwfparams_lidr = expand.grid(method = method, intercept = intercepts,slope = slopes, window_min = window_mins, window_max = window_maxs, smooth = smooths)
vwfparams_lidr_negintercept = expand.grid(method = neg_method, intercept = neg_intercepts,slope = neg_slopes, window_min = neg_window_mins, window_max = neg_window_maxs, smooth = neg_smooths)
vwfparams_foresttools = expand.grid(method = ft_method, intercept = ft_intercepts,slope = ft_slopes, window_min = ft_window_mins, window_max = ft_window_maxs, smooth = ft_smooths)
vwfparams_foresttools_negintercept = expand.grid(method = neg_ft_method, intercept = neg_ft_intercepts,slope = neg_ft_slopes, window_min = neg_ft_window_mins, window_max = neg_ft_window_maxs, smooth = neg_ft_smooths)
vwfparams = bind_rows(vwfparams_lidr, vwfparams_lidr_negintercept, vwfparams_foresttools, vwfparams_foresttools_negintercept)
vwfparams$id = 1:nrow(vwfparams)

vwfparams = vwfparams[!(vwfparams$intercept == 0 & vwfparams$slope == 0),] # remove ones with intercept and slope both == 0

vwfparams = vwfparams[rev(1:nrow(vwfparams)),] # reverse to do the ForestTools sets first

# Load the CHM files to use for ITD
chm_files = list.files(datadir("meta200/drone/L2"), pattern="chm.tif", full.names=TRUE)
# FOR TESTING: chm_files = chm_files[c(5,37)]
chm_files_list = as.list(chm_files)

set_lidr_threads(2) # Set to 1 because we're going to parallelize across ITD runs, not within them (the latter has more overhead of reading/writing files that isn't parallelized)

# Run in parallel
furrr_options(scheduling = Inf)
plan(multisession)
future_walk(chm_files_list,itd_onechm_allvwfs)
