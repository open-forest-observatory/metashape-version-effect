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
eval_stats_dir = datadir("meta200/itd-eval-fullrun01/tree_detection_evals")

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


# Get the VWF parameter values
d = d |>
  mutate(vwf_intercept = predicted_tree_dataset_name %>% str_split("_") |> map_vec(12) |> as.numeric(),
         vwf_slope = predicted_tree_dataset_name %>% str_split("_") |> map_vec(13) |> as.numeric(),
         chm_smooth = predicted_tree_dataset_name %>% str_split("_") |> map_vec(16) |> as.numeric(),
         meta_config = predicted_tree_dataset_name %>% str_split("_") |> map_vec(4),
         sens_prec_diff = abs(sensitivity - precision)) |>
  arrange(vwf_intercept, vwf_slope, chm_smooth)

## Plot F vs parameter vals for all trees, 10+ m, for a specific metashape config, specific smooth

d_fig = d |>
  filter(canopy_position == "all",
         height_cat == "10+", 
         chm_smooth == 11,
         meta_config == "16a") %>%
  mutate(f_score = as.numeric(f_score),
         vwf_intercept = as.numeric(vwf_intercept),
         vwf_slope = as.numeric(vwf_slope))

ggplot(d_fig, aes(x = vwf_intercept, y = vwf_slope, fill = f_score)) +
  geom_tile() +
  scale_fill_viridis_c(limits = c(NA,NA))
ggplot(d_fig, aes(x = vwf_intercept, y = vwf_slope, fill = sens_prec_diff)) +
  geom_tile() +
  scale_fill_viridis_c(direction = -1, limits = c(0,1))


## For 10+ m, all trees, get the max F score by metashape config and rank the metashape configs by F score 
d_a = d |>
  filter(canopy_position == "overstory",
         height_cat == "10+")


d_summ = d |>
  filter(canopy_position == "overstory",
         height_cat == "10+") |>
  group_by(meta_config) |>
  summarize(max_f = max(f_score))
