library(lidR)
library(here)
library(terra)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

#### Convenience functions and main functions ####
source(here("workflow/convenience-functions.R"))

set_lidr_threads(2)



chm_files = list.files(datadir("meta200/drone/L2"), pattern="chm.tif", full.names=TRUE)


chm_file = chm_files[1]

chm = rast(chm_file)

# Function to make a vwf with a specific slope and intercept
make_window_size_function <- function(a, b) { 
  vwf = function(x) {
    y = a + b*x
  }
}
  
  
ttops <- locate_trees(chm, lmf(f, shape="circular"))



## Create ttops with many different parameter values





