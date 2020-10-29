suppressPackageStartupMessages({

    #we should be able to avoid librarying most or all of these,
    #since we're referring to their functions directly with ::

    # #spatial packages
    # library(gstat) #must load before raster package
    # # library(terra)  #must load before gstat package
    # library(raster) #raster has been replaced by terra (way faster)
    # library(stars)
    # library(sf)
    # library(sp)
    # library(mapview)
    # library(elevatr)
    # library(rgee)
    # remotes::install_github("giswqs/whiteboxR")
    # library(whitebox)

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
    library(foreach)
    library(doParallel)
})

ms_setwd <- function(){

    #attempts to set working directory for various machines involved in the
    #   macrosheds project. determines from success/failure whether the current
    #   instance is a development instance (interactive) or a server
    #   (production) instance.

    #returns details about the current instance. these details can be
    #   used to taylor run specifications (which code to run, and how to run it)
    #   to the current machine:
    #   "dev" or "server" accordingly

    successes <- 0

    res <- try(setwd('~/git/macrosheds/data_acquisition'), silent=TRUE) #mike
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        instance_type <- 'dev'
        machine_status <- 'n00b'
    }

    res <- try(setwd('~/desktop/macrosheds/data_acquisition'), silent=TRUE) #spencer
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        instance_type <- 'dev'
        machine_status <- 'n00b'
    }

    # try(setwd('C:/Users/mrvr/Desktop/mike/data_acquisition/'), silent=TRUE) #matt
    # if(! 'try-error' %in% class(res)){
    #     successes <- successes + 1
    #     instance_type <- 'dev'
    #     machine_status <- '1337'
    # }

    res <- try(setwd('/home/macrosheds/data_acquisition'), silent=TRUE) #server
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        instance_type <- 'server'
        machine_status <- '1337'
    }

    if(successes > 1){
        stop(glue('more than one working directory was available. must set the ',
                  'correct one manually'))
    } else if(successes == 0){
        stop('failed to set working directory. update ms_setwd() with your wd path')
    }

    instance_details <- list(instance_type = instance_type,
                             machine_status = machine_status)

    return(instance_details)
}

ms_instance <- ms_setwd()

#connect rgee to earth engine and python
#try(rgee::ee_Initialize(email = 'spencerrhea41@gmail.com', drive = TRUE))

conf = jsonlite::fromJSON('config.json')

#set up global logger. network-domain loggers are set up later
logging::basicConfig()
logging::addHandler(logging::writeToFile,
                    logger = 'ms',
                    file = 'logs/0_ms_master.log')

source('src/global/global_helpers.R')
source('src/dev/dev_helpers.R') #comment before pushing live
source_decoratees('src/global/global_helpers.R') #parse decorators

ms_vars <- sm(read_csv('data/general/variables.csv'))
network_domain <- sm(read_csv('data/general/site_data.csv')) %>%
    filter(as.logical(in_workflow)) %>%
    select(network, domain) %>%
    distinct() %>%
    arrange(network, domain)

ms_globals = c(ls(all.names=TRUE), 'ms_globals')

dir.create('logs', showWarnings = FALSE)

# dmnrow=2
for(dmnrow in 1:nrow(network_domain)){

    network = network_domain$network[dmnrow]
    domain = network_domain$domain[dmnrow]

    logger_module = set_up_logger(network = network,
                                  domain = domain)
    loginfo(logger = logger_module,
            msg = glue('Processing network: {n}, domain: {d}',
                       n = network,
                       d = domain))

    update_product_statuses(network = network,
                            domain = domain)
    get_all_local_helpers(network = network,
                          domain = domain)

    ms_retrieve(network = network,
                domain = domain)
    ms_munge(network = network,
             domain = domain)
    sw(ms_delineate(network = network, domain = domain,
                    dev_machine_status = ms_instance$machine_status,
                    verbose = TRUE))
    ms_derive(network = network,
              domain = domain)
    ms_general(network = network,
               domain = domain)

    retain_ms_globals(ms_globals)
}


if(length(email_err_msgs)){
    email_err(msgs = email_err_msgs,
              addrs = conf$report_emails,
              pw = conf$gmail_pw)
}

loginfo('Run complete',
        logger = 'ms.module')
