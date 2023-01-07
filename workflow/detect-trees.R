library(lidR)
library(here)
library(terra)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data_dir.txt"), n=1)

#### Convenience functions and main functions ####
source(here("workflow/convenience-functions.R"))

set_lidr_threads(2)



chm_files = list.files(datadir("meta200/drone/L2"), pattern="chm.tif", full.names=TRUE)


chm_file = chm_files[1]

chm = rast(chm_file)

# variable window size
f <- function(x) { x * 0.07 + 3 }
ttops <- locate_trees(chm, lmf(f, shape="circular"))


