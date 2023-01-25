#!/usr/bin/env python
# coding: utf-8

# In[1]:


from deepforest import main
from deepforest import get_data
from deepforest import utilities
import os
import sys
import rasterio as rio
import numpy as  np
from pathlib import Path


# In[2]:


# Get parameters from command line arguments if running from command line, otherwise use hard-coded testing parameters
in_ortho = sys.argv[1]
patch_size = int(sys.argv[2])
out_boxes_gpkg = sys.argv[3]

# For testing:
# in_ortho = "/ofo-share/metashape-version-effect/data/meta200/drone/L1/metashape-version-effect_config_10b_2_4_moderate_50_usgs-filter_20230104T1912_ortho_dtm.tif"
# patch_size = 1000
# out_boxes_gpkg = "/ofo-share/metashape-version-effect/data/meta200/drone/L3/temp_deepforest_bboxes/bboxes_metashape-version-effect_config_15b_2_2_mild_50_usgs-filter_20230105T0315_ortho_dtm_dpf_0.000_0.000_0.000_0.000_00.gpkg"


# In[3]:


r = rio.open(in_ortho)
df = r.read()
df = df[:3,:,:]


# In[4]:


rolled_df = np.rollaxis(df, 0,3)


# In[5]:


m = main.deepforest()
m.use_release()

boxes = m.predict_tile(image=rolled_df, patch_size=patch_size, patch_overlap = 0.3)


# In[6]:


# It only works if I also run this:
boxes["image_path"] = in_ortho


# In[7]:


Path(out_boxes_gpkg).parent.mkdir(parents=True, exist_ok=True)


# In[ ]:


shp = utilities.boxes_to_shapefile(boxes, root_dir="", projected=True)
shp.to_file(out_boxes_gpkg)

