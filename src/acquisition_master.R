warning('in 2025, need to address site arctic: "I-Minus_2_TK_High Side". systemic. adjusted in site data but not elsewhere')
warning('gee now requires the use of a "cloud project". see starred email from 9/16/24 for setup deets')
warning('the grab_sample column in each timeseries dataset AND the ms_recommended column in annual load need to be converted to numeric. this currently happens downstream of the split between packageversion and eml version. ugly')
suppressPackageStartupMessages({


    # #spatial packages
    library(terra)  #must load before gstat package (which isn't currently needed)
    library(sf) #must load here in order to look for sf::sf_use_s2 (below)
    # remotes::install_github("giswqs/whiteboxR")
    #might need the following if you can't get whitebox to install. build from source and
    #   reference the executable like so
    # whitebox::wbt_init(exe_path = '~/git/others_projects/whitebox-tools/target/release/whitebox_tools')
    library(nhdplusTools)
    # library(streamstats)

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
    library(foreach) #loaded by doFuture
    library(doParallel) #replaced by doFuture, but still needed on BM1
    library(doFuture)
    library(googlesheets4)
    library(googledrive)
    library(rgee) #requires geojsonio package and system installation of gcloud (https://cloud.google.com/sdk/docs/install)
    library(osmdata)
    library(RCurl)
    library(rvest)
    library(macrosheds)

    # install.packages("BiocManager") #required to get the IRanges package
    # BiocManager::install("IRanges") #required for fuzzyjoin::difference_inner_join
    # library(fuzzyjoin) #nvm. too memory inefficient. implementing rolling join
    #   from data.table instead
})

#set the dataset version. This is used to name the output dataset and diagnostic
#plots. it will eventually be set automatically at the start of each run.
#(or after each run that results in a change). Starting in 2025, use decimal versioning?
#how would that work with EDI? maybe not.
vsn <- 2

options(dplyr.summarise.inform = FALSE,
        timeout = 12000)

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

    # example dev computer 'registration' code block
    ## res <- try(setwd('~/your/file/path/to/macrosheds/data_processing'), silent=TRUE) # example
    ## if(! 'try-error' %in% class(res)){
    ##     successes <- successes + 1
    ##     which_machine <- 'your_machine') # machine name is completely up to you, does not matter
    ##     instance_type <- 'dev' # instance type is 'dev' for all personal computers
    ##     machine_status <- 'n00b' # unless you have > 32GB of RAM and > 8 CPUS, your 'n00b'
    ##     op_system <- 'mac' # whats your OS?
    ## }

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

    res <- try(setwd('C:/Users/sr446/Desktop/macrosheds/data_processing'), silent=TRUE) #BM0
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'BM0'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'windows'
    }

    res <- try(setwd('/Users/hectorontiveros/Macrosheds/s-data_processing'), silent=TRUE) #Hector
    if(! 'try-error' %in% class(res)){
      successes <- successes + 1
      which_machine <- 'hec'
      instance_type <- 'dev'
      machine_status <- 'n00b'
      op_system <- 'macOS'
    }

    res <- try(setwd('~/desktop/macrosheds/data_acquisition'), silent=TRUE) #spencer
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'Spencer'
        instance_type <- 'dev'
        machine_status <- 'n00b'
        op_system <- 'mac'
    }

    res <- try(setwd('/Users/pranavireddi/Desktop/MacroSheds/data_processing'), silent=TRUE) #pranavi
    if(! 'try-error' %in% class(res)){
      successes <- successes + 1
      which_machine <- 'Pranavi'
      instance_type <- 'dev'
      machine_status <- 'n00b'
      op_system <- 'mac'
    }

    res <- try(setwd('C:/Users/gubbi/Documents/macrosheds/data_processing'), silent=TRUE) #Nick
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'nick'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'windows'
    }

    res <- try(setwd('/home/ws184/science/macrosheds/data_processing'), silent=TRUE) # BM2
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'BM2'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'linux'
    }

    res <- try(setwd('C:/Users/ws184/Documents/Projects/MacroSheds/data_aquisition'), silent=TRUE) #WesBm0
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'BM0'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'windows'
    }

    # try(setwd('C:/Users/mrvr/Desktop/mike/data_acquisition/'), silent=TRUE) #matt
    # if(! 'try-error' %in% class(res)){
    #     which_machine <- 'Matt'
    #     successes <- successes + 1
    #     instance_type <- 'dev'
    #     machine_status <- '1337'
    # }

    res <- try(setwd('/home/weston/science/macrosheds/data_processing'), silent=TRUE) # wes
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'wes'
        instance_type <- 'dev'
        machine_status <- '1337'
        op_system <- 'linux'
    }

    res <- try(setwd('/home/macrosheds/data_acquisition'), silent=TRUE) #server
    if(! 'try-error' %in% class(res)){
        successes <- successes + 1
        which_machine <- 'server'
        instance_type <- 'server'
        machine_status <- '1337'
        op_system <- NA
    }


    res <- try(setwd('C:/Users/Dell/Documents/Projects/data_processing'), silent=TRUE) #server
    if(! 'try-error' %in% class(res)){
      successes <- successes + 1
      which_machine <- 'bini'
      instance_type <- 'dev'
      machine_status <- 'noob'
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
                             config_data_storage = 'remote',
                             op_system = op_system,
                             config_data_storage = config_storage_location)

    return(instance_details)
}

ms_instance <- ms_init(use_ms_error_handling = FALSE,
                    #   force_machine_status = 'n00b',
                       config_storage_location = 'remote')

#load authorization file for macrosheds google sheets
## googlesheets4::gs4_auth(path = 'googlesheet_service_accnt.json')

#read in secrets
conf <- jsonlite::fromJSON('config.json',
                           simplifyDataFrame = FALSE)

#connect rgee to earth engine and python
gee_login <- case_when(
    ms_instance$which_machine %in% c('Mike', 'BM1') ~ conf$gee_login_mike,
    ms_instance$which_machine %in% c('Spencer', 'BM2', 'Nick') ~ conf$gee_login_spencer,
    ms_instance$which_machine %in% c('Hector', 'hec', 'Biniam', 'bini', 'BM0', 'Pranavi', 'Wes') ~conf$gee_login_ms,
    TRUE ~ 'UNKNOWN')

#load authorization file for macrosheds google sheets and drive
#same account must have GEE and GDrive access
#googlesheets4::gs4_deauth()
#googledrive::drive_deauth()

googlesheets4::gs4_auth(email = gee_login)
googledrive::drive_auth(email = gee_login)

#initialize and authorize GEE account
try(rgee::ee_Initialize(user = conf$gee_login_ms,
                        drive = TRUE))

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

#puts google sheets into the global environment: ms_vars, site_data, ws_delin_specs, univ_products.
#if this hangs on "Selection:", enter 1 and authenticate tidyverse. should open your browser.
## load_config_datasets(from_where = ms_instance$config_data_storage)
load_config_datasets(from_where = 'remote')

domain_detection_limits <- standardize_detection_limits(dls = domain_detection_limits,
                                                        vs = ms_vars,
                                                        update_on_gdrive = TRUE)

unknown_detlim_prec_lookup <- make_hdetlim_prec_lookup_table(domain_detection_limits)
superunknowns <- get_superunknowns(special_vars = c('discharge', 'precipitation')) #temperature?

site_data <- filter(site_data,
                    as.logical(in_workflow))

network_domain <- site_data %>%
    select(network, domain) %>%
    distinct() %>%
    arrange(network, domain)

ms_globals <- c(ls(all.names = TRUE), 'ms_globals')

dir.create('logs', showWarnings = FALSE)

run_prechecks()

## change string in line below to find row index of your desired domain
dmnrow <- which(network_domain$domain == 'east_river')

for(dmnrow in 1:nrow(network_domain)){

    # drop_automated_entries('.') #use with caution!
    # drop_automated_entries(glue('data/{network}/{domain}'))

    network <- network_domain$network[dmnrow]
    domain <- network_domain$domain[dmnrow]

    held_data <- get_data_tracker(network, domain)

    ## dangerous lines - use at your own risk!    :0

    # held_data = invalidate_tracked_data(network, domain, 'munge')
    # owrite_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'derive')
    # owrite_tracker(network, domain)

    ## less dangerous version below, clears tracker for just a specified product

    # held_data = invalidate_tracked_data(network, domain, 'munge', 'discharge')
    # owrite_tracker(network, domain)
    # held_data = invalidate_tracked_data(network, domain, 'derive', 'CUSTOMprecipitation')
    # owrite_tracker(network, domain)

    logger_module <- set_up_logger(network = network,
                                   domain = domain)

    loginfo(logger = logger_module,
            msg = glue('Processing network: {n}, domain: {d}',
                       n = network,
                       d = domain))

    # this should only run when you have your producs.csv
    # and processing kernels prod information matching
    update_product_statuses(network = network,
                            domain = domain)

    get_all_local_helpers(network = network,
                          domain = domain)

    # stop here and go to processing_kernels.R to continue
    ms_retrieve(network = network,
                # prodname_filter = c('precipitation'),
                domain = domain)

    if(domain != 'neon'){
        check_for_derelicts(network = network,
                            domain = domain)
    }

    ms_munge(network = network,
             # prodname_filter = c('discharge'),
             domain = domain)

    #build this into ms_delineate and add a new parameter for it.
    #(only useful when rerunning stuff after a fix. otherwise just delineate them all.)
    has_wsbound = get_product_info(network = network,
                     domain = domain,
                     status_level = 'munge',
                     get_statuses = 'ready') %>% pull(prodname) %>% str_detect('ws_boundary') %>% any()
    if(domain != 'mcmurdo' && has_wsbound){
        #might have to specify locatoin to whitebox executable:
        # whitebox::wbt_init(exe_path = '~/git/others_projects/whitebox-tools/target/release/whitebox_tools')
        sw(ms_delineate(network = network,
                        domain = domain,
                        dev_machine_status = ms_instance$machine_status,
                        # overwrite_wb_sites = c('CJ'),
                        verbose = FALSE))
    }

    ms_derive(network = network,
              # prodname_filter = c('CUSTOMprecip_flux_inst'),
              domain = domain,
              precip_pchem_pflux_skip_existing = FALSE)

    #these domains are either widely dispersed, or have both very small (10e1-2) and very large (10e5-6+) sites
    #this might serve better as a domain-prod filter, but also it might not hurt to treat non_bulk_domains the same way for all prods
    #might want to rerun these in full in 2025
    non_bulk_domains <- c('neon', 'baltimore', 'catalina_jemez', 'east_river', 'bonanza', 'shale_hills', #high variation (many)
                          'hjandrews', 'hbef', 'niwot', 'calhoun', 'liquillo') #really small watersheds (tcw)
    if(domain != 'mcmurdo'){
        # whitebox::wbt_init(exe_path = '~/git/others_projects/whitebox-tools/target/release/whitebox_tools')
        ms_general(network = network,
                   domain = domain,
                   get_missing_only = F,
                   general_prod_filter = c('pdsi', 'spei30d', 'et'),
                   bulk_mode = F) #seems reasonable to require this next year
                   # bulk_mode = ifelse(domain %in% non_bulk_domains, FALSE, TRUE)) #daymet is always in bulk mode.
    }

    retain_ms_globals(ms_globals)
}

logger_module <- 'ms.module'

run_postchecks()
# remove_superfluous_files('data') #uncomment and run
# remove_superfluous_files('../portal/data') #uncomment and run

#use this e.g. if someone else ran (part of) the loop above and you downloaded its output
# rebuild_portal_data_before_postprocessing(network_domain = network_domain,
#                                           backup = TRUE)

postprocess_entire_dataset(site_data = site_data,
                           network_domain = network_domain,
                           dataset_version = vsn,
                           thin_portal_data_to_interval = NA, # '1 day',
                           populate_implicit_missing_values = TRUE,
                           generate_csv_for_each_product = FALSE,
                           push_new_version_to_figshare_and_edi = FALSE)

if(length(email_err_msgs)){
    email_err(msgs = email_err_msgs,
              addrs = conf$report_emails,
              pw = conf$gmail_pw)
}

loginfo(msg = 'Run complete',
        logger = logger_module)

