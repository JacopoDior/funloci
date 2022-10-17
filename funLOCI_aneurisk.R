# Aneurisk Case Study Example -
# Libraries -----
library(parallel)
library(future.apply)
library(Rcpp)
library(cluster)
library(funloci)
library(tidyverse)
library(shiny)


# to install the funloci package (work in progress)
library(devtools)
install_github("JacopoDior/funloci/funloci")
library(funloci)

## Load data ----
# change the path according to the position of the file "50patients.RData" in
# your computer
load("50patients.RData")
mat = cleancurves50
matplot(t(mat), type='l', col='grey60', xlab = "x", ylab = "y")

## Step 1 - Lotting ----
# Set parameters
# set interval
int <- 500
int_step <- 500
# set minimum step
pos_step <- 250
# show first interval
matplot(1:int, t(mat[,1:int]), type='l', col='red', add=TRUE)

sequential = TRUE 
#k <- 1
# create lotting structure
lotting <- funLOCI_lotting(mat, int, sequential, int_step = int_step, pos_step = pos_step)
# create lots (list with starting and ending point)
case_to_consider <- create_lots(lotting, ncol(mat))
length(case_to_consider)

## Step 2 - Flowering ----
# Parallel apply DIANA to every lot
# WARNING! It could be computationally intense
list_hc <- future_lapply(case_to_consider, diana_parallel, mat = cleancurves50)

## Step 3 - Harvesting ----
# Perform harvesting with delta threhsold (delta = 0.04)
plan(multisession)
res = funLOCI_harvesting_delta(list_hc, 0.04, cleancurves50)

## Step 4 - Tasting ----
# apply tasting to reduce the number of candidates as explained in the paper
tasted_res <- funLOCI_tasting(res)
tasted_res <- tasted_res[[2]]
length(tasted_res)

# Ordering the tasted_res
tastedres_info <- getInfo(tasted_res)
tastedres_info  <- cbind.data.frame('num_elem'= unlist(tastedres_info [[1]]),
                               'int_len' = unlist(tastedres_info [[2]]),
                               'a' = unlist(tastedres_info [[3]]),
                               'b' = unlist(tastedres_info [[4]]),
                               'hscore'= unlist(tastedres_info [[5]]),
                               'index'= unlist(tastedres_info [[6]]))

# Reorder according to preferred criterium
resorder <- tastedres_info %>%
  arrange(desc(int_len), desc(num_elem), hscore)  #reordering first by int_len
tasted_res <- tasted_res[resorder$index]

# Exploring the results with the funLOCI explorer
tastingexplorer(tasted_res, mat)

