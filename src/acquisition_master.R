suppressPackageStartupMessages({

    #we should be able to avoid librarying most or all of these,
    #since we're referring to their functions directly with ::

    # #spatial packages
    # library(terra)  #must load before gstat package (which isn't currently needed)
    # # library(gstat) #must load before raster package (not needed)
    # library(raster)
    # # library(stars) #not needed (yet)
    # library(sf)
    # library(sp)
    # library(mapview)
    # library(elevatr)
    # library(rgee)
    # remotes::install_github("giswqs/whiteboxR")
    # library(whitebox)
    # library(nhdplusTools)

    #everything else
    library(httr)
    library(jsonlite)
    library(tidyr)
    library(plyr)
    library(data.table)
    # library(dtplyr)
    library(tidyverse)
    library(lubridate)
    library(feather)
    library(glue)
    library(logging)
    library(emayili)
    # library(neonUtilities)
    library(tinsel)
    library(PeriodicTable)
    library(imputeTS)
    library(errors)
    # library(foreach) #loaded by doFuture
    library(doParallel) #replaced by doFuture, but still needed on BM1
    library(doFuture)
    # library(googlesheets4)
    # library(rgee) #requires geojsonio package

    # install.packages("BiocManager") #required to get the IRanges package
    # BiocManager::install("IRanges") #required for fuzzyjoin::difference_inner_join
    # library(fuzzyjoin) #nvm. too memory inefficient. implementing rolling join
    #   from data.table instead

})

options(dplyr.summarise.inform = FALSE)

ms_init <- function(use_gpu = FALSE,
                    use_multicore_cpu = TRUE,
                    use_ms_error_handling = TRUE,
                    force_machine_status,
                    config_storage_location = 'remote'){

    #TODO:
    #could add args that override automatically set instance_type, machine_status
    #hook up use_multicore_cpu parameter (changes nothing currently)
    #if we ever find a way to benefit from GPU computing, hook up that param too.

    #use_gpu: logical. leverage GPU for turbo multithreading. not currently connected
    #   to anything, because we don't yet have a way to benefit from GPU in R
    #use_multicore_cpu: logical. if on a multicore machine, use all cores.
    #   not currently hooked up. Update this parameter so that it also allows
    #   HPC on a cluster. currently, we just determine whether the instance is
    #   on DCC with one of the setwd hacks below.
    #use_ms_error_handling. logical. if TRUE, errors are handled and processing
    #   continues. if FALSE, the handle_errors decorator is not invoked, and
    #   standard R error handling ensues.
    #force_machine_status: override the default machine_status for the machine
    #   you're using. options are 'n00b' and '1337'. Among other (future) things,
    #   this determines the granularity of downloaded DEMs for watershed
    #   delineation
    #config_storage_location: either 'local' or 'remote'.
    #   governs whether site_data, variables, ws_delin_specs, etc are searched
    #   for as local CSV files or as google sheets connections.

    #attempts to set working directory for various machines involved in the
    #   macrosheds project. determines from success/failure whether the current
    #   instance is a development instance (interactive) or a server
    #   (production) instance.

    #returns details about the current instance. these details can be
    #   used to tailor run specifications (which code to run, and how to run it)
    #   to the current machine:
    #   "dev" or "server" accordingly

    successes <- 0
    which_machine <- 'unknown'

    res <- try(setwd('~/macrosheds_data_processing'), silent=TRUE) #DCC
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'DCC'
        instance_type <- 'server'
        machine_status <- '1337'
        op_system <- 'linux'
    }

    res <- try(setwd('~/git/macrosheds/data_acquisition'), silent=TRUE) #BM1
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'BM1'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'linux'
    }

    #@Spencer, uncomment this and update it with your path on BM0 ^_^
    # res <- try(setwd('~/git/macrosheds/data_acquisition'), silent=TRUE) #BM0
    # if(! 'try-error' %in% class(res)){
    #     successes <- successes + 1
    #     which_machine <- 'BM0'
    #     instance_type <- 'dev'
    #     machine_status <- '1337'
    # }

    res <- try(setwd('~/desktop/macrosheds/data_acquisition'), silent=TRUE) #spencer
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'Spencer'
        instance_type <- 'dev'
        machine_status <- 'n00b'
        op_system <- 'mac'
    }

    # try(setwd('C:/Users/mrvr/Desktop/mike/data_acquisition/'), silent=TRUE) #matt
    # if(! 'try-error' %in% class(res)){
    #     which_machine <- 'Matt'
    #     successes <- successes + 1
    #     instance_type <- 'dev'
    #     machine_status <- '1337'
    # }

    res <- try(setwd('/home/macrosheds/data_acquisition'), silent=TRUE) #server
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'server'
        instance_type <- 'server'
        machine_status <- '1337'
        op_system <- NA
    }

    res <- try(setwd('C:/Users/sr446/Desktop/macrosheds/data_processing'), silent=TRUE) #BM0
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'windows'
    }

    if(successes > 1){
        stop(glue('more than one working directory was available. must set the ',
                  'correct one manually'))
    } else if(successes == 0){
        stop('failed to set working directory. update ms_setwd() with your wd path')
    }

    if(! missing(force_machine_status)) machine_status <- force_machine_status

    instance_details <- list(which_machine = which_machine,
                             instance_type = instance_type,
                             machine_status = machine_status,
                             use_gpu = use_gpu,
                             use_multicore_cpu = use_multicore_cpu,
                             use_ms_error_handling = use_ms_error_handling,
                             op_system = op_system,
                             config_data_storage = config_storage_location)

    return(instance_details)
}

ms_instance <- ms_init(use_ms_error_handling = FALSE,
                       force_machine_status = 'n00b',
                       config_storage_location = 'local')

#load authorization file for macrosheds google sheets
# googlesheets4::gs4_auth(path = 'googlesheet_service_accnt.json')

#read in secrets
conf <- jsonlite::fromJSON('config.json')

# #connect rgee to earth engine and python
# gee_login <- case_when(
#     ms_instance$which_machine %in% c('Mike', 'BM1') ~ conf$gee_login_mike,
#     ms_instance$which_machine %in% c('Spencer', 'BM0') ~ conf$gee_login_spencer,
#     TRUE ~ 'UNKNOWN')

# try(rgee::ee_Initialize(email = conf[[gee_login]],
#                         drive = TRUE))

#set up global logger. network-domain loggers are set up later
logging::basicConfig()
logging::addHandler(logging::writeToFile,
                    logger = 'ms',
                    file = 'logs/0_ms_master.log')

source('src/global/global_helpers.R')
source('src/dev/dev_helpers.R') #comment before pushing live

if(ms_instance$use_ms_error_handling){
    source_decoratees('src/global/global_helpers.R') #parse decorators
}

#puts ms_vars, site_data, ws_delin_specs, univ_products into the global environment
load_config_datasets(from_where = ms_instance$config_data_storage)

network_domain <- site_data %>%
    filter(as.logical(in_workflow)) %>%
    select(network, domain) %>%
    distinct() %>%
    arrange(network, domain)

ms_globals <- c(ls(all.names=TRUE), 'ms_globals')

dir.create('logs', showWarnings = FALSE)

# dmnrow=3
# for(dmnrow in 1:nrow(network_domain)){
for(dmnrow in 9){
    # drop_automated_entries('.') #use with caution!

    network <- network_domain$network[dmnrow]
    domain <- network_domain$domain[dmnrow]

    # held_data = get_data_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'munge')
    # owrite_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'derive')
    # owrite_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'munge', 'stream_chemistry__10303')
    # owrite_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'derive', 'precip_pchem_pflux__ms004')
    # owrite_tracker(network, domain)

    logger_module <- set_up_logger(network = network,
                                   domain = domain)

    loginfo(logger = logger_module,
            msg = glue('Processing network: {n}, domain: {d}',
                       n = network,
                       d = domain))

    update_product_statuses(network = network,
                            domain = domain)
    get_all_local_helpers(network = network,
                          domain = domain)

    # ms_retrieve(network = network,
    #             domain = domain)
    # ms_munge(network = network,
    #          domain = domain)
    # sw(ms_delineate(network = network,
    #                 domain = domain,
    #                 dev_machine_status = ms_instance$machine_status,
    #                 verbose = TRUE))
    ms_derive(network = network,
              domain = domain)
    # ms_general(network = network,
    #            domain = domain)

    retain_ms_globals(ms_globals)
}

logger_module <- 'ms.module'

# generate_portal_extras(site_data = site_data,
#                        network_domain = network_domain)
#
# if(length(email_err_msgs)){
#     email_err(msgs = email_err_msgs,
#               addrs = conf$report_emails,
#               pw = conf$gmail_pw)
# }

loginfo(msg = 'Run complete',
        logger = logger_module)
