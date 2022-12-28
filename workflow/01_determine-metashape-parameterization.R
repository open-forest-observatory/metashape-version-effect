library(dplyr)
library(here)

am_dir <- file.path("~", "dev", "ofo", "automate-metashape")
yaml_path <- here::here("configs")
metashape_path <- file.path(am_dir, "python", "metashape_workflow.py")

# Original combinations tested by Young et al., 2022
young2022 <-
  tibble::tribble(~id, ~photo_alignment_qual, ~photo_downscale, 
                  ~dense_cloud_qual, ~cloud_downscale, ~depth_filtering,
                  7,  "Low",    4, "Medium", 4, "Mild",
                  8,  "Low",    4, "Medium", 4, "Moderate", 
                  9,  "Medium", 2, "Medium", 4, "Mild",
                  10, "Medium", 2, "Medium", 4, "Moderate", 
                  11, "High",   1, "Medium", 4, "Mild",
                  12, "High",   1, "Medium", 4, "Moderate", 
                  13, "Low",    4, "High",   2, "Mild",
                  14, "Low",    4, "High",   2, "Moderate", 
                  15, "Medium", 2, "High",   2, "Mild",
                  16, "Medium", 2, "High",   2, "Moderate", 
                  17, "High",   1, "High",   2, "Mild",
                  18, "High",   1, "High",   2, "Moderate")

# For each of these combinations, we also added three different values of the
# BuildDenseCloud "max_neighbors" parameter
system2(command = "Rscript", args = paste(file.path(am_dir, "R", "prep_configs.R"), 
                                          here::here("configs"),
                                          metashape_path))
