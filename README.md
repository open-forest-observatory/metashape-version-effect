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

Run a drone photo set from Emerald Point through Metashape photogrammetry using multiple parameterizations to (ultimately) produce a CHM and orthomosaic to use for tree detection. The Metashape runs are performed on the photo set at `/ofo-share/emerald-point-benchmark/` using the OFO [automated metashape workflow](https://github.com/open-forest-observatory/automate-metashape) and the photogrammetry config files in the `configs` directory of this repo. The photogrammetry outputs are saved to `{data}/meta200/L1`. The following steps are erformed for each photogrammetry parameterization. 

**Create a CHM** for the area of the stem map by subtracting an interpolated USGS DEM from the photogrammetry DSM, resampling to 0.12 m, and cropping to the focal area. Performed by `dsm-to-cropped-chm.R`.

**Create an orthomosaic** cropped to the area of the stem map to use for deepforest tree detection. Performed by `crop-ortho.R`.
