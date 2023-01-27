# metashape-version-effect
What is the effect of Agisoft Metashape version on optimized processing parameters? Detect trees from the Metashape outputs using the CHM (e.g. lidR::lmf) or orthomosaic (e.g. deepforest) using different tree detection parameters, and compare the results against a field-reference stem map.

## Setting up the data directory

- Most scripts source `workflow/convenience_functions.R`, which provides some convenience functions that are useful across multiple scripts, including for accessing the data directory (see next bullets).
- The scripts are set up to use the directory specified in data-dir.txt (in the root repo folder, but not tracked by git) as the root directory for data files to read and/or write. This functionality (provided by the `here` package combined with the `datadir()` function definition in `scripts/convenience_functions.R`) allows you to specify data sub-folders as arguments to the datadir() function, which returns the full absolute system path. This allows the data directory to be anywhere that is accessible by the scrips, including inside the repository as an untracked folder.
- Throughout the workflow description below, `{data}` refers to the root level of the data folder. All data references in the script are appended to that root data folder location.
- For runs on OFO Jetstream, the data folder is mounted at `/ofo-share/metashape-version-effect/data/`.
- Within the data directory, folders named `meta184` contain results from running Metashape v1.8.4 and folders named `meta200` contain results from running Metashape v2.0.0.


## Workflow

### Perform photogrammetry and post-process photogrammetry products

Run a drone photo set from Emerald Point through Metashape photogrammetry using multiple parameterizations to (ultimately) produce a CHM and orthomosaic to use for tree detection. The Metashape runs are performed on the photo set at `/ofo-share/emerald-point-benchmark/` using the OFO [automated metashape workflow](https://github.com/open-forest-observatory/automate-metashape) and the photogrammetry config files in the `configs` directory of this repo. The photogrammetry outputs are saved to `{data}/meta200/L1`. The outpus and all downstream products use the following naming convention: `metashape-version-effect_config_{config_id}_{alignment_downscale}_{dense_cloud_downscale}_{dense_cloud_filtering_aggressiveness}_{max_neighbors}_{usgs_filter}_{run_date_time}_{product_type}.{extension} The following steps are performed for each photogrammetry parameterization. 

**Create a CHM** for the area of the stem map by subtracting an interpolated USGS DEM from the photogrammetry DSM, resampling to 0.12 m, and cropping to the focal area. Used for CHM-based treetop detection. Performed by `workflow/dsm-to-cropped-chm.R`. Output saved to `{data}/meta200/drone/L2`.

**Create an orthomosaic** cropped to the area of the stem map to use for deepforest tree detection. Performed by `workflow/crop-ortho.R`. Output saved to `{data}/meta200/drone/L1/cropped`.

### Detect treetops

**Run CHM-based treetop detection.** Run multiple parameterizations of the lidR::lmf and ForestTools::vwf treetop detection algorithms on each CHM. Performed by `workflow/detect-trees.R`. Uses tree detection parameterizations specified in the script itself (TODO: pull out of script into a separate config file). The parameters for the variable window algorithms are: algorithm (vwf or lmf), min and max window size, slope, intercept, CHM mean smoothing window width. Saves detected treetops in `{data}/meta200/drone/L3/{tree_detection_run_name}/` as `.gpkg`s with the detection parameters in the filename, e.g.: `ttops_{metashape_chm_filename}_{vwf/lmf}_{intercept}_{slope}_{min_window}_{max_window)_{smooth}.gpkg`. The most recent and complete run by Derek has the run name `ttops_fullrun02`. Some parameterizations result in very unreasonable numbers of trees; in some of these cases the script aborts treetop detection and moves to the next parameterization, but it first saves a placeholder file with the same filename but with the extension `.txt_placeholder` so that if the run is restarted, we do not attempt to create those treetops again. **Note:** this script can be run multiple times with different parameter ranges and the results from all runs accumulate in the `L3` folder, so the set of parameters saved in the script is not necessarily the complete set defining all the files in `L3`.

**Run orthomosaic-based treetop detection** using [deepforest](https://deepforest.readthedocs.io/en/latest/index.html#). This is done by `workflow/detect-trees-deepforest.R`, which calls `run-deepforest-tree-det.py`. It repeats tree detection multiple times on each orthomosaic, once for several different `patch_size` parameters. This produces bounding box polygons as `.gpkg`s. The output files go to `{data}/meta200/drone/L3/{tree_detection_run_name}/` with the same file naming as the CHM-based ttops except `{vwf/lmf}` is set to `dpf` and the `{smooth}` element of the filname is used to store the `patch_size` parameter. Note: as currently coded, each deepforest run downloads the neural net model config from the weecology github, and after many downloads, github blocks further pulls, so you have to kill and restart this process multiple times allowing enough time between each. TODO: fix this so the model config only has to be pulled once for all runs. Next, post-process the bounding boxes into ttops by computing the centroid of the bbox and extracting tree height from the CHM within a radius of the ttop. Performed by `workflow/deepforest-bboxes-to-ttops.R` which stores results as ttop `.gpkg`s with the same naming convention as the bboxes to `{data}/meta200/drone/L3/{tree_detection_run_name}/`.

**Note:** Depending on how many tree detection parameter sets are searched, tree detection can produce thousands of ttop .gpkg files. These take up a lot of space, and the many small files are slow to transfer to external storage providers. Therefore, I have been zipping these folders after the outputs are processed by the downstream step (next section).

### Validate treetops and compile validation results

**Compare all the sets of ttops against the Emerald Point stem map** and compute recall (sensitivity), precision, F score, height accuracy, and many other metrics. Performed by `workflow/tree-map-comparison/run-tree-map-comparison.R` with many functions defined in the `lib` subfolder. Saves outputs to `{data}meta200/itd-evals/{evaluation-name}`, as one csv per ttop `.gpkg` file. The most recent and complete run by Derek evaluated the ttops in `ttops_fullrun02` and has the evaluation name `itd-eval-fullrun02`. **Note:** The many small files are slow to transfer to external storage providers. Therefore, I have been zipping these folders after the outputs are processed by the downstream step (next paragraph).

**Compile all the comparison results** (separate csv file for each ttop file) into a single big CSV using `workflow/compile-tree-map-comparison-results.R`.

### Evaluate the validation results

**Evaluate the results** and make inferences regarding the best photogrammetry and tree detection parameters. Performed by `workflow/evaluate-tree-map-comparison-results.R` which is currently only partially functional (intended as a demo of some things that are possible) and meant to be run interactively.
