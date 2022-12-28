library(dplyr)
library(here)
library(tidyr)

am_dir <- file.path("~", "dev", "ofo", "automate-metashape")
yaml_path <- here::here("configs")
metashape_path <- file.path(am_dir, "python", "metashape_workflow.py")

# Original combinations tested by Young et al., 2022
young2022 <-
  tibble::tribble(~id, ~photo_alignment_qual, ~photo_downscale, 
                  ~dense_cloud_qual, ~cloud_downscale, ~depth_filtering,
                  7,  "low",    4, "medium", 4, "mild",
                  8,  "low",    4, "medium", 4, "moderate", 
                  9,  "medium", 2, "medium", 4, "mild",
                  10, "medium", 2, "medium", 4, "moderate", 
                  11, "high",   1, "medium", 4, "mild",
                  12, "high",   1, "medium", 4, "moderate", 
                  13, "low",    4, "high",   2, "mild",
                  14, "low",    4, "high",   2, "moderate", 
                  15, "medium", 2, "high",   2, "mild",
                  16, "medium", 2, "high",   2, "moderate", 
                  17, "high",   1, "high",   2, "mild",
                  18, "high",   1, "high",   2, "moderate")

# For each of these combinations, we also added three different values of the
# BuildDenseCloud "max_neighbors" parameter

metashape_version_effect_recipe <-
  tidyr::expand_grid(young2022, data.frame(max_neighbors = c(100, 50, 150))) %>% 
  dplyr::mutate(id = dplyr::case_when(max_neighbors == 50 ~ paste0(sprintf("%02d", id), "a"),
                                      max_neighbors == 100 ~ paste0(sprintf("%02d", id), "b"),
                                      max_neighbors == 150 ~ paste0(sprintf("%02d", id), "c"))) %>% 
  dplyr::mutate(run_name = paste("metashape-version-effect_config", 
                                 id, 
                                 photo_downscale,
                                 cloud_downscale,
                                 depth_filtering,
                                 max_neighbors,
                                 sep = "_"))

system2(command = "Rscript", args = paste(file.path(am_dir, "R", "prep_configs.R"), 
                                          here::here("configs"),
                                          metashape_path))
