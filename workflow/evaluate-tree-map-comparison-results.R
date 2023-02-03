library(sf)
library(tidyverse)
library(here)
library(furrr)
library(lubridate)

#### Get data dir ####
# The root of the data directory
data_dir = readLines(here("data-dir.txt"), n=1)

## Conveinence functions ##
# Most importantly, this defines a function 'datadir' that prepends any relative file path with the absolute path to the data directory (specified in data-dir.txt)
source(here("workflow/convenience-functions.R"))

## Read in the table of tree map evals
d = read_csv(datadir("meta200/itd-evals/compiled/ttops-dpfrun01v2.csv"))
d = read_csv(datadir("meta200/itd-evals/compiled/ttops-fullrun02v3.csv"))
#d = read_csv(datadir("meta200/itd-evals/compiled/dpf-ttops-run01.csv"))

# Get the VWF/lmf parameter values
d = d |>
  mutate(method = predicted_tree_dataset_name %>% str_split("_") |> map_vec(12),
         vwf_intercept = predicted_tree_dataset_name %>% str_split("_") |> map_vec(13) |> as.numeric(),
         vwf_slope = predicted_tree_dataset_name %>% str_split("_") |> map_vec(14) |> as.numeric(),
         window_min = predicted_tree_dataset_name %>% str_split("_") |> map_vec(15) |> as.numeric(),
         chm_smooth = predicted_tree_dataset_name %>% str_split("_") |> map_vec(17) |> as.numeric(),
         meta_config = predicted_tree_dataset_name %>% str_split("_") |> map_vec(4),
         sens_prec_diff = abs(sensitivity - precision)) |>
  arrange(vwf_intercept, vwf_slope, chm_smooth)

## Plot F vs parameter vals for all trees, 10+ m, for a specific metashape config, specific smooth

d_fig = d |>
  filter(method == "dpf",
         window_min == 2,
         canopy_position == "all",
         height_cat == "10+", 
         chm_smooth == 0,
         meta_config == "10a") %>%
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



## Metashape paramsets vs processing time

## For each paramset, get max processing time across all VWFs






## Best Metashape paramesets:
# Which one was best, or within 0.01 F of the best, for each height class and canopy position category?

## For each category, what's the highest F?
# Which metashape configs came within 0.01 of it?

canopy_positions = c("overstory") #c("all", "overstory")
height_cats = c("10+") #c("10+", "20+")

best_configs = list()
for(can_pos in canopy_positions) {
  for(ht_cat in height_cats) {
    
    config = paste(can_pos, ht_cat, sep="_")
    
    best_configs[[config]] = d |>
      filter(canopy_position == can_pos,
             height_cat == ht_cat) |>
      group_by(meta_config) |>
      summarize(max_f = max(f_score)) |>
      arrange(-max_f) |>
      filter(max_f > (max(max_f) - 0.01)) |>
      pull(meta_config)
    
  }
}

# Which metashape set comes up the most often across these four scenarios?

set_freq = unlist(best_configs) |> table() |> sort(decreasing = TRUE)
set_freq

## Get the metashape sets that come up as best in at least 2 of the 4 tree height x canopy class scenarios
best_metashape = names(set_freq)[set_freq >= 2]



#### Get run time for each metashape configs

config_files = list.files(datadir("meta200/drone/L1/"), pattern="_log.txt$", full.names=TRUE)

config_file = config_files[1]

durations_df = data.frame()
for(config_file in config_files) {
  
  # get the config name
  file_minus_extension = str_sub(config_file,1,-5)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  file_name = fileparts[length(fileparts)] #take the last part of the path (the filename)
  config_name = str_split(file_name, "_")[[1]][3]
  
  config_descr = str_split(file_name, "_")[[1]][3:8] |> paste(collapse="_")
  
  lines = read_lines(config_file)
  start_time = lines[3] |> str_sub(21,-1)
  end_time = lines[16] |> str_sub(16,-1)
  
  format = '%Y%m%dT%H%M'
  
  start = strptime(start_time, format = format)
  end = strptime(end_time, format = format)
  duration_hrs = interval(as_datetime(start), as_datetime(end)) / hours(1)
  
  ortho1 = str_sub(lines[14], 20, -1) |> as.numeric()
  ortho2 = str_sub(lines[15], 20, -1) |> as.numeric()
  ortho_duration_hrs = (ortho1 + ortho2) / 60 / 60
  duration_excl_ortho = duration_hrs - ortho_duration_hrs
  
  duration_df = data.frame(config = config_name, config_descr = config_descr, duration = duration_excl_ortho)
  
  durations_df = bind_rows(durations_df, duration_df)
}


## Prepare a DF of the meanings of the metashape codes

# get unique metashape IDs
















## To narrow down the VWF sets that are the best, or within 0.01 of the best, across all of the best metashape configs
## For all Metashape set that are within 0.01 of the best F in at least 2 of the 4 tree height / canopy class scenarios, which VWF paramsets are within 0.01 of the best?


# Within that set, get all the VWFs that gave within 0.01 of the best VWF
