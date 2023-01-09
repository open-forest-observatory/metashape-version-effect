library(sf)
library(tidyverse)
library(here)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

## Conveinence functions ##
# Most importantly, this defines a function 'datadir' that prepends any relative file path with the absolute path to the data directory (specified in data-dir.txt)
source(here("workflow/convenience-functions.R"))

# Folder with all the stats to compare
eval_stats_dir = datadir("meta200/itd-eval-secondvwfsearch_meta-08a16a/tree_detection_evals")

## Open all the CSVs and merge to one table
eval_stats_files = list.files(eval_stats_dir,full.names=TRUE)

d = read_csv(eval_stats_files)

# Get the VWF parameter values
d = d |>
  mutate(vwf_intercept = predicted_tree_dataset_name %>% str_split("_") |> map_vec(12) |> as.numeric(),
         vwf_slope = predicted_tree_dataset_name %>% str_split("_") |> map_vec(13) |> as.numeric(),
         chm_smooth = predicted_tree_dataset_name %>% str_split("_") |> map_vec(16) |> as.numeric(),
         meta_config = predicted_tree_dataset_name %>% str_split("_") |> map_vec(4),
         sens_prec_diff = abs(sensitivity - precision)) |>
  arrange(vwf_intercept, vwf_slope, chm_smooth)

## Plot F vs parameter vals for all trees, 10+ m

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
  scale_fill_viridis_c(limits = c(0.4,0.7))
ggplot(d_fig, aes(x = vwf_intercept, y = vwf_slope, fill = sens_prec_diff)) +
  geom_tile() +
  scale_fill_viridis_c(direction = -1, limits = c(0,1))
