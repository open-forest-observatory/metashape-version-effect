library(here)
library(terra)
library(tidyverse)
library(sf)

#### Get data dir ####
# The root of the data directoryc
data_dir = readLines(here("data-dir.txt"), n=1)

# Load convenience functions including 'datadir'#
source(here("workflow/convenience-functions.R"))


#### CONSTANTS ####

BBOXES_DIR = datadir("meta200/drone/L3/dpf-bboxes_run01") # where are the predicted deepforest tree bboxes
CHM_DIR = datadir("meta200/drone/L2") # where to get the CHM for assigning heights
OUT_DIR = datadir("meta200/drone/L3/dpf-ttops_run01") # where to store the resulting ttops files

# Load the bboxes files to use for ITD
bboxes_files = list.files(BBOXES_DIR, pattern="^bboxes.*gpkg$", full.names=TRUE)

if(!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}


bboxes_file = bboxes_files[72]

for(bboxes_file in bboxes_files) {
  
  ## get the filename to use for saving
  file_minus_extension = str_sub(bboxes_file,1,-6)
  fileparts = str_split(file_minus_extension,fixed("/"))[[1]]
  filename_only = fileparts[length(fileparts)]
  # make the filename have the same underscore indexing as the chm-based ttops filenames
  filename_only = str_replace(filename_only, fixed("ortho_dsm_cropped"), "ortho-dsm-cropped")
  # change bboxes to ttops
  filename_only = str_replace(filename_only, fixed("bboxes"), "ttops")
  out_filepath = paste0(OUT_DIR, "/", filename_only, ".gpkg")

  cat("\nConverting bboxes to ttops for:", out_filepath, "\n")
  
  # skip if alredy exists
  if(file.exists(out_filepath)) {
    cat("Already exists. Skipping.\n")
    next()
  }
  
  # load bboxes
  bboxes = st_read(bboxes_file)
      
  # get the CHM name to look up the CHM corresponding to the ortho the bboxes were predicted for
  name_parts = str_split(filename_only, fixed("_"))[[1]]
  metashape_run_name = paste(name_parts[2:10], collapse="_")
  chm_filename = paste0(metashape_run_name, "_chm.tif")
  chm_filepath = paste0(CHM_DIR, "/", chm_filename)
  
  # load the CHM
  chm = rast(chm_filepath)
  
  # get bbox centroids (ttops)
  ttops = st_centroid(bboxes)
  
  ### get a buffered zone within which to get canopy height (as max value within zone)
  ## want a circle with a radius equal to the short dimension of the bbox
  
  # get the radius of the largest inscribed circle, then make a new circle centered on the centroid
  inscr_circles = st_inscribed_circle(st_geometry(bboxes), dTolerance = 1)
  inscr_circles = st_as_sf(inscr_circles)
  # for some reason the above creates two sets of inscribed circles, one with empty geometry, so remove thos
  inscr_circles = inscr_circles |> filter(!st_is_empty(inscr_circles))
  circle_areas = st_area(inscr_circles)
  inscr_circles$comp_area = circle_areas
  radii = sqrt(circle_areas/3.14)
  inscr_circles$comp_radius = radii
  circles = st_buffer(ttops, radii)
  
  #### was the prediction a sliver (long skinny rectangular box)?
  bbox_area = st_area(bboxes)
  is_sliver = circle_areas < (bbox_area/3)
  
  #### get the height
  height = terra::extract(chm, circles, fun = "max")
  
  #### save the attributes back to ttops
  ttops$height = height[,2]
  ttops$is_sliver = is_sliver
  
  # remove ttops below 5 m height
  ttops = ttops |>
    filter(height >= 5)
  
  st_write(ttops, out_filepath, delete_dsn=TRUE)

}