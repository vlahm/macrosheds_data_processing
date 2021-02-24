library("future.batchtools")
future::plan(future.batchtools::batchtools_slurm)
x %<-% { Sys.sleep(2); 3.14 }
y %<-% { Sys.sleep(2); 2.71 }
x + y
