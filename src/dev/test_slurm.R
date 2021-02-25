library("future.batchtools")

slurm_submitJob = function(reg, jc) {
    assertRegistry(reg, writeable = TRUE)
    assertClass(jc, "JobCollection")
    if (jc$array.jobs) {
        logs = sprintf("%s_%i", fs::path_file(jc$log.file),
                       seq_row(jc$jobs))
        jc$log.file = stri_join(jc$log.file, "_%a")
    }
    outfile = cfBrewTemplate(reg, template, jc)
    res = runOSCommand("sbatch", shQuote(outfile), nodename = nodename)
    output = stri_flatten(stri_trim_both(res$output), "\n")
    if (res$exit.code > 0L) {
        temp.errors = c("Batch job submission failed: Job violates accounting policy (job submit limit, user's size and/or time limits)",
                        "Socket timed out on send/recv operation", "Submission rate too high, suggest using job arrays")
        i = wf(stri_detect_fixed(output, temp.errors))
        if (length(i) == 1L)
            return(makeSubmitJobResult(status = i, batch.id = NA_character_,
                                       msg = temp.errors[i]))
        return(cfHandleUnknownSubmitError("sbatch", res$exit.code,
                                          res$output))
    }
    id = stri_split_fixed(output[1L], " ")[[1L]][4L]
    if (jc$array.jobs) {
        if (!array.jobs)
            stop("Array jobs not supported by cluster function")
        makeSubmitJobResult(status = 0L, batch.id = sprintf("%s_%i",
                                                            id, seq_row(jc$jobs)), log.file = logs)
    }
    else {
        makeSubmitJobResult(status = 0L, batch.id = id)
    }
}
slurm_killJob = function(reg, batch.id) {
    assertRegistry(reg, writeable = TRUE)
    assertString(batch.id)
    cfKillJob(reg, "scancel", c(sprintf("--clusters=%s",
                                        getClusters(reg)), batch.id), nodename = nodename)
}
listJobs = function(reg, args) {
    assertRegistry(reg, writeable = FALSE)
    args = c(args, "--noheader", "--format=%i")
    if (array.jobs)
        args = c(args, "-r")
    clusters = getClusters(reg)
    if (length(clusters))
        args = c(args, sprintf("--clusters=%s", clusters))
    res = runOSCommand("squeue", args, nodename = nodename)
    if (res$exit.code > 0L)
        OSError("Listing of jobs failed", res)
    if (length(clusters))
        tail(res$output, -1L)
    else res$output
}
slurm_listJobsQueued = function(reg) {
    args = c(quote("--user=$USER"), "--states=PD")
    listJobs(reg, args)
}
slurm_listJobsRunning = function(reg) {
    args = c(quote("--user=$USER"), "--states=R,S,CG")
    listJobs(reg, args)
}

clustf = batchtools::makeClusterFunctions(name = 'slurm_custom',
                                          submitJob = slurm_submitJob,
                                          killJob = slurm_killJob,
                                          listJobsQueued = NULL, #disable
                                          listJobsRunning = slurm_listJobsRunning,
                                          scheduler.latency = 1,
                                          fs.latency = 65)
# clustf = batchtools::makeClusterFunctionsSlurm(template = 'slurm',
#                                                scheduler.latency = 1)

future::plan(future.batchtools::batchtools_custom(cluster.functions = clustf))
# future::plan(future.batchtools::batchtools_slurm(cluster.functions = clustf))
x %<-% { Sys.sleep(2); 3.14 }
y %<-% { Sys.sleep(2); 2.71 }
print(x + y)
