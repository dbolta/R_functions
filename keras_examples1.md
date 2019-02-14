
``` r
library(tidyverse)
```

    ## -- Attaching packages ------------------------------------------------------------------------------ tidyverse 1.2.1 --

    ## v ggplot2 3.1.0     v purrr   0.2.5
    ## v tibble  2.0.1     v dplyr   0.7.8
    ## v tidyr   0.8.2     v stringr 1.3.1
    ## v readr   1.3.1     v forcats 0.3.0

    ## -- Conflicts --------------------------------------------------------------------------------- tidyverse_conflicts() --
    ## x dplyr::filter() masks stats::filter()
    ## x dplyr::lag()    masks stats::lag()

``` r
library(tidymodels)
```

    ## -- Attaching packages ----------------------------------------------------------------------------- tidymodels 0.0.2 --

    ## v broom     0.5.1     v recipes   0.1.4
    ## v dials     0.0.2     v rsample   0.0.4
    ## v infer     0.4.0     v yardstick 0.0.2
    ## v parsnip   0.0.1

    ## -- Conflicts -------------------------------------------------------------------------------- tidymodels_conflicts() --
    ## x scales::discard() masks purrr::discard()
    ## x dplyr::filter()   masks stats::filter()
    ## x recipes::fixed()  masks stringr::fixed()
    ## x dplyr::lag()      masks stats::lag()
    ## x yardstick::spec() masks readr::spec()
    ## x recipes::step()   masks stats::step()

``` r
library(caret)
```

    ## Loading required package: lattice

    ## 
    ## Attaching package: 'caret'

    ## The following objects are masked from 'package:yardstick':
    ## 
    ##     precision, recall

    ## The following object is masked from 'package:purrr':
    ## 
    ##     lift

``` r
library(keras)
```

    ## 
    ## Attaching package: 'keras'

    ## The following object is masked from 'package:yardstick':
    ## 
    ##     get_weights

``` r
install_keras()
```

``` r
### create data
numrows = 1000
set.seed(12345)
data1 = tibble(x1 = rnorm(numrows),
               x2 = rnorm(numrows),
               x3 = rnorm(numrows),
               y = x2 * sin(2 * x1) + x3)

### separate train/test
test_ind = sample(numrows, size = round(0.2 * numrows))

train_df = data1 %>% slice(-test_ind)
test_df = data1 %>% slice(test_ind)

### Use tidymodels to center/scale
recipe_obj = recipe(y ~ ., data = train_df) %>%
  step_center(all_predictors())  %>%
  step_scale(all_predictors()) %>%
  prep(training = train_df)

train_stand = bake(recipe_obj, new_data = train_df)
test_stand = bake(recipe_obj, new_data = test_df)

### Keras needs matrices
train_X = train_stand %>% select(-y) %>% as.matrix()
train_y = train_stand %>% select(y) %>% as.matrix()

test_X = test_stand %>% select(-y) %>% as.matrix()
test_y = test_stand %>% select(y) %>% as.matrix()
```

``` r
### Make sure session is clear
K <- backend()
K$clear_session()

### Set seed in numpy and tensorflow
use_session_with_seed(42)
```

    ## Set session seed to 42 (disabled GPU, CPU parallelism)

1. sequential model
-------------------

``` r
### Build shallow and wide
nnet_model = keras_model_sequential() %>%
  layer_dense(units = 256, activation = NULL,
              use_bias = FALSE,
              kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              input_shape = dim(train_X)[2]) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 4, activation = 'relu',
              use_bias = TRUE) %>%
  layer_dense(units = 1)
```

``` r
nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)

nnet_model %>% summary()
```

    ## ___________________________________________________________________________
    ## Layer (type)                     Output Shape                  Param #     
    ## ===========================================================================
    ## dense_1 (Dense)                  (None, 256)                   768         
    ## ___________________________________________________________________________
    ## batch_normalization_1 (BatchNorm (None, 256)                   1024        
    ## ___________________________________________________________________________
    ## leaky_re_lu_1 (LeakyReLU)        (None, 256)                   0           
    ## ___________________________________________________________________________
    ## dense_2 (Dense)                  (None, 4)                     1028        
    ## ___________________________________________________________________________
    ## dense_3 (Dense)                  (None, 1)                     5           
    ## ===========================================================================
    ## Total params: 2,825
    ## Trainable params: 2,313
    ## Non-trainable params: 512
    ## ___________________________________________________________________________

``` r
### Callback
call_early_stop = callback_early_stopping(#monitor = "val_loss",
  monitor = "loss",
  min_delta = 0,
  patience = 20, verbose = 0, mode = c("auto", "min", "max"),
  baseline = NULL, restore_best_weights = FALSE)

### Change learning rate
k_set_value(nnet_model$optimizer$lr, 0.002)

### Change optimizer
nnet_model$optimizer = optimizer_nadam(#lr = 0.01
)

nnet_model$optimizer = optimizer_adam()
nnet_model$optimizer = optimizer_adamax()
nnet_model$optimizer = optimizer_sgd(
  #lr = 0.0001,
  momentum = 0.1)
nnet_model$optimizer = optimizer_rmsprop()
```

``` r
history = nnet_model %>% fit(
  x = train_X,
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(test_X, test_y),
  verbose = 0
  #, callbacks = list(call_early_stop),
  , view_metrics = FALSE ### can slow down Rstudio
  , shuffle = TRUE
)
```

``` r
### Save model
nnet_model %>%
  save_model_hdf5(filepath = paste0(folder, subfolder, "keras_model_1.h5"),
                  overwrite = TRUE,
                  include_optimizer = TRUE)
```

``` r
layers <- nnet_model$layers
for (i in 1:length(layers)) cat(i, layers[[i]]$name, "\n")
```

    ## 1 dense_1 
    ## 2 batch_normalization_1 
    ## 3 leaky_re_lu_1 
    ## 4 dense_2 
    ## 5 dense_3

2. Transfer learning by stacking layers deeper
----------------------------------------------

<br> 1. Remove layers at output end. <br> 2. Freeze remaining weights. <br> 3. Stack on new, trainable layers.

``` r
### Remove 2 output-side layers
for (i in 1:2) {
  pop_layer(nnet_model)
}

### Sequentially stack new layers on
nnet_model = nnet_model %>%
  layer_dense(units = 8, activation = NULL,
              use_bias = TRUE
  ) %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 4, activation = 'relu',
              use_bias = TRUE,
              kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0)
  ) %>%
  layer_dense(units = 1)

### Freeze or unfreeze desired weights
# unfreeze_weights(nnet_model, 1, 29)
freeze_weights(nnet_model, 1, 1)

### Recompile model
nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)

nnet_model %>% summary()
```

    ## ___________________________________________________________________________
    ## Layer (type)                     Output Shape                  Param #     
    ## ===========================================================================
    ## dense_1 (Dense)                  (None, 256)                   768         
    ## ___________________________________________________________________________
    ## batch_normalization_1 (BatchNorm (None, 256)                   1024        
    ## ___________________________________________________________________________
    ## leaky_re_lu_1 (LeakyReLU)        (None, 256)                   0           
    ## ___________________________________________________________________________
    ## dense_4 (Dense)                  (None, 8)                     2056        
    ## ___________________________________________________________________________
    ## leaky_re_lu_2 (LeakyReLU)        (None, 8)                     0           
    ## ___________________________________________________________________________
    ## dense_5 (Dense)                  (None, 4)                     36          
    ## ___________________________________________________________________________
    ## dense_6 (Dense)                  (None, 1)                     5           
    ## ===========================================================================
    ## Total params: 3,889
    ## Trainable params: 2,609
    ## Non-trainable params: 1,280
    ## ___________________________________________________________________________

``` r
history = nnet_model %>% fit(
  x = train_X,
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(test_X, test_y),
  verbose = 0
  #, callbacks = list(call_early_stop),
  , view_metrics = FALSE ### can slow down Rstudio
  , shuffle = TRUE
)
```

``` r
test_y_pred = predict(nnet_model, x = test_X)

paste0("Test RMSE = ",
       RMSE(pred = test_y_pred,
            obs = test_y))
```

    ## [1] "Test RMSE = 0.410183348885608"

``` r
nnet_results = tibble(source = "train",
                      pred = predict(nnet_model, x = train_X),
                      obs = train_y) %>%
  bind_rows(tibble(source = "test",
                   pred = predict(nnet_model, x = test_X),
                   obs = test_y))

nnet_results %>%
  ggplot(aes(x = obs,
             y = pred,
             color = source)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  theme_bw() +
  coord_cartesian(xlim = c(-3, 3),
                  ylim = c(-3, 3)) +
  ggtitle("Predicted vs. Actual, Stacked Deep") +
  scale_color_brewer(palette = "Set1")
```

![](keras_examples1_files/figure-markdown_github/evaluate%202-1.png)

3. Stack models wide (in parallel)
----------------------------------

Reset to keras functional API

``` r
K <- backend()
K$clear_session()
use_session_with_seed(42)
```

    ## Set session seed to 42 (disabled GPU, CPU parallelism)

Make sure to name the layers with weights. <br>These will be used later to determing which layers to freeze.

``` r
x_in1 = layer_input(shape = dim(train_X)[2])

x1 = x_in1 %>%
  layer_dense(units = 16, activation = NULL,
              use_bias = FALSE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x1_1") %>%
  layer_dropout(rate = 0.2) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 8, activation = NULL,
              use_bias = FALSE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x1_2") %>%
  layer_dropout(rate = 0.4) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 2, activation = NULL,
              use_bias = TRUE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x1_3") %>%
  layer_activation_relu()

x_final = x1 %>%
  layer_dense(units = 1)

nnet_model = keras_model(inputs = c(x_in1), outputs = x_final)
```

``` r
nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)
```

num\_stk is the number of models stacked beside each other

``` r
num_stk = 1

history = nnet_model %>% fit(
  x = map(1:num_stk, function(i) train_X),
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(map(1:num_stk, function(i) test_X), test_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)
```

Add on second parallel model <br>If we wanted to setup residual connections, layer\_add() would be used instead of layer\_concatenate()

``` r
x_in2 = layer_input(shape = dim(train_X)[2])

x2 = x_in2 %>%
  layer_dense(units = 16, activation = NULL,
              use_bias = FALSE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x2_1") %>%
  layer_dropout(rate = 0.2) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 8, activation = NULL,
              use_bias = FALSE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x2_2") %>%
  layer_dropout(rate = 0.4) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.1) %>%
  layer_dense(units = 2, activation = NULL,
              use_bias = TRUE, kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              name = "x2_3") %>%
  layer_activation_relu()

### Use layer concatenate to merge layers
x_final = layer_concatenate(c(x1, x2), axis = -1) %>%
  layer_dense(units = 1)

nnet_model = keras_model(inputs = c(x_in1, x_in2), outputs = x_final)

freeze_weights(nnet_model, "x1_1", "x1_1")
freeze_weights(nnet_model, "x1_2", "x1_2")
freeze_weights(nnet_model, "x1_3", "x1_3")

nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)
```

``` r
num_stk = 2

history = nnet_model %>% fit(
  x = map(1:num_stk, function(i) train_X),
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(map(1:num_stk, function(i) test_X), test_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)
```

``` r
test_y_pred = predict(nnet_model, x = map(1:num_stk, function(i) test_X))

paste0("Test RMSE = ",
       RMSE(pred = test_y_pred,
            obs = test_y))
```

    ## [1] "Test RMSE = 0.409881542114744"

``` r
nnet_results = tibble(source = "train",
                      pred = predict(nnet_model, x = map(1:num_stk, function(i) train_X)),
                      obs = train_y) %>%
  bind_rows(tibble(source = "test",
                   pred = predict(nnet_model, x = map(1:num_stk, function(i) test_X)),
                   obs = test_y))

nnet_results %>%
  ggplot(aes(x = obs,
             y = pred,
             color = source)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  theme_bw() +
  coord_cartesian(xlim = c(-3, 3),
                  ylim = c(-3, 3)) +
  ggtitle("Predicted vs. Actual, Nnet Layers Stacked Wide") +
scale_color_brewer(palette = "Set1")
```

![](keras_examples1_files/figure-markdown_github/evaluate%204-1.png)

4. Custom loss function
-----------------------

Suspect a certain relatinship (eg. y ~ x2) <br>With regression, can't know y exactly but can set custom loss function so that <br> if x2 is increased from initial training set, loss should be less sensitive <br>to predictions above initial y value

``` r
K <- backend()
K$clear_session()
use_session_with_seed(42)
```

    ## Set session seed to 42 (disabled GPU, CPU parallelism)

``` r
### Use the relu operator to ignore over- or underprediction
less_wt_overpredict = function(y_obs, y_pred, alpha = 0.01) {
  K <- backend()
  K$mean(K$pow(alpha * K$relu(y_pred - y_obs) +
                 K$relu(y_obs - y_pred), 2))
}

less_wt_underpredict = function(y_obs, y_pred, alpha = 0.01) {
  K <- backend()
  K$mean(K$pow(K$relu(y_pred - y_obs) +
                 alpha * K$relu(y_obs - y_pred), 2))
}
```

Change x2 up or down. <br>Don't know how much y should move, only know the direction it should change. <br>Use custom loss to handle. Can't just shift y up or down and use MSE loss.

``` r
shift_factor = 1.1

train_hi = train_stand %>%
  mutate(x2 = shift_factor * x2)

train_lo = train_stand %>%
  mutate(x2 = x2 / shift_factor)

train_hi_X = train_hi %>% select(-y) %>% as.matrix()
train_hi_y = train_hi %>% select(y) %>% as.matrix()

test_hi_X = train_hi %>% select(-y) %>% as.matrix()
test_hi_y = train_hi %>% select(y) %>% as.matrix()

train_lo_X = train_lo %>% select(-y) %>% as.matrix()
train_lo_y = train_lo %>% select(y) %>% as.matrix()

test_lo_X = train_lo %>% select(-y) %>% as.matrix()
test_lo_y = train_lo %>% select(y) %>% as.matrix()
```

``` r
nnet_model = keras_model_sequential() %>%
  layer_dense(units = 32, activation = NULL,
              use_bias = FALSE,
              kernel_constraint = constraint_maxnorm(max_value = 5, axis = 0),
              input_shape = dim(train_X)[2]) %>%
  layer_dropout(rate = 0.2) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.05) %>%
  layer_dense(units = 16,
              use_bias = FALSE,
              kernel_constraint = constraint_maxnorm(max_value = 4, axis = 0)
  ) %>%
  layer_dropout(rate = 0.3) %>%
  layer_batch_normalization() %>%
  layer_activation_leaky_relu(alpha = 0.05) %>%
  layer_dense(units = 8,
              use_bias = FALSE,
              kernel_constraint = constraint_maxnorm(max_value = 3, axis = 0)
  ) %>%
  layer_dropout(rate = 0.4) %>%
  layer_activation_leaky_relu(alpha = 0.05) %>%
  layer_dense(units = 4,
              use_bias = FALSE,
              kernel_constraint = constraint_maxnorm(max_value = 3, axis = 0)
  ) %>%
  layer_activation_leaky_relu(alpha = 0.05) %>%
  layer_dense(units = 1)

nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)
```

``` r
history = nnet_model %>% fit(
  x = train_X,
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(test_X, test_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)
```

Can encapsulate in a for loop as needed

``` r
### Recompile with new loss
nnet_model %>% compile(
  loss = less_wt_overpredict,
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)

history = nnet_model %>% fit(
  x = train_hi_X,
  y = train_hi_y,
  batch_size = 512,
  epochs = 50,
  validation_data = list(test_hi_X, test_hi_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)

nnet_model %>% compile(
  loss = less_wt_underpredict
  , optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)

history = nnet_model %>% fit(
  x = train_lo_X,
  y = train_lo_y,
  batch_size = 4,
  epochs = 50,
  validation_data = list(test_lo_X, test_lo_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)
```

``` r
nnet_model %>% compile(
  loss = "mse",
  optimizer = optimizer_nadam(),
  metrics = list("mean_absolute_error")
)

history = nnet_model %>% fit(
  x = train_X,
  y = train_y,
  batch_size = 512,
  epochs = 350,
  validation_data = list(test_X, test_y),
  verbose = 0
  , view_metrics = FALSE
  , shuffle = TRUE
)
```

``` r
test_y_pred = predict(nnet_model, x = test_X)

paste0("Test RMSE = ",
       RMSE(pred = test_y_pred,
            obs = test_y))
```

    ## [1] "Test RMSE = 0.476383114752941"

``` r
nnet_results = tibble(source = "train",
                      pred = predict(nnet_model, x = train_X),
                      obs = train_y) %>%
  bind_rows(tibble(source = "test",
                   pred = predict(nnet_model, x = test_X),
                   obs = test_y))

nnet_results %>%
  ggplot(aes(x = obs,
             y = pred,
             color = source)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  theme_bw() +
  coord_cartesian(xlim = c(-3, 3),
                  ylim = c(-3, 3)) +
  ggtitle("Predicted vs. Actual, Stacked Deep") +
  scale_color_brewer(palette = "Set1")
```

![](keras_examples1_files/figure-markdown_github/Evaluate%204-1.png)
