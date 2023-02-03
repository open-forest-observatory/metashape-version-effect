# Takes all of the individual stats .csv files (one for each metashape run x tree detection parameterization) and compiles them into one large csv (easier to store and transfer)

library(sf)
library(tidyverse)
library(here)
library(furrr)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

## Conveinence functions ##
# Most importantly, this defines a function 'datadir' that prepends any relative file path with the absolute path to the data directory (specified in data-dir.txt)
source(here("workflow/convenience-functions.R"))

# Folder with all the stats to compare
eval_stats_dir = datadir("meta200/itd-evals/itd-eval-dpf-ttops-run01v2/tree_detection_evals")

# Where to save the compiled evals?
compiled_evals_outfile = datadir("meta200/itd-evals/compiled/ttops-dpfrun01v2.csv")  # compiled_evals_outfile = datadir("meta200/itd-evals/compiled/dpf-ttops-run01.csv")

if(!dir.exists(dirname(compiled_evals_outfile))) {
  dir.create(dirname(compiled_evals_outfile))
}


#### Open all the CSVs and merge to one table
eval_stats_files = list.files(eval_stats_dir, pattern="csv$", full.names=TRUE)

## Need to open the CSVs in batches because the OS does not allow to open these thousands of files at once

nfiles = length(eval_stats_files)
max_batchsize = 1000 # number of csv files to open at once
nbatches = ceiling(nfiles/max_batchsize)
batch_idxs = 1:nbatches

open_csvs = function(batch_idx) {
  
  min_idx = (max_batchsize * batch_idx - max_batchsize + 1)
  max_idx = min(c(max_batchsize * batch_idx, nfiles))
  file_idxs = min_idx:max_idx
  eval_stats_files_foc = eval_stats_files[file_idxs]
  
  d_part = read_csv(eval_stats_files_foc)
  
}

plan(multisession)
d = future_map_dfr(batch_idxs, open_csvs)


## Save the files
write_csv(d, compiled_evals_outfile)
