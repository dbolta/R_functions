install_load(
  rgdal,
  maptools,
  
  doParallel,
  parallel,
  foreach,
  
  tidyverse, 
  furrr, # parallel purrr
  data.table,
  tidyr,
  Metrics,
  openxlsx,
  slam, # handle sparse data sets
  
  caret,
  rpart,
  ranger,
  gam, # written by hastie https://multithreaded.stitchfix.com/blog/2015/07/30/gam/
  h2o,
  missRanger,
  
  interp,
  
  ggplot2,
  gridExtra,
  corrplot,
  rpart.plot,
  rattle,
  RColorBrewer,
  mlr,
  raster,
  rgeos,
  
  plotly, # creates function name interference
  rayshader
  
  
  
  , reticulate # for knitting python
)

select = dplyr::select



