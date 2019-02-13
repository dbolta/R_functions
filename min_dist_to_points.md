
Fast min distance calculator
============================

Calculate the min distance between a point and another set of points quickly.

Original use case: <br>Had 1e6 points in grid. <br>Needed min distance for evry point on grid out to set of data collection points.

Result below performed fastest. <br>Other tests included <br>1. Straight dplyr without multiprocessing <br>2. Multidplyr, created memory issues <br>3. Converting to matrix and using matrix operations <br>4. Other flavors of lapply or purrr::map

``` r
library(tidyverse)
library(parallel)

raster_df_list = raster_df %>%
  split((seq(nrow(.)) - 1) %/% 1000)

no_cores = detectCores()
cl = makeCluster(no_cores)

clusterExport(cl, "raster_df_list") %>% invisible()
clusterExport(cl, "source_locations_df") %>% invisible()
clusterEvalQ(cl, library(tidyverse)) %>% invisible()

raster_df_w_min_distance = parLapply(cl,
          raster_df_list,
          function(raster_df_iter){
            raster_df_iter %>%
              mutate(row_num = 1:nrow(.)) %>%
              group_by(row_num) %>%
              mutate(min_distance_to_source = source_locations_df %>%
                       mutate(distance_iter = sqrt((raster_LONGITUDE - source_LONGITUDE)^2 + 
                                                     (raster_LATITUDE - source_LATITUDE)^2)) %>%
                       select(distance_iter) %>%
                       min()) %>% 
              ungroup() %>%
              select(-row_num)
}) %>%
  bind_rows()
stopCluster(cl)
```
