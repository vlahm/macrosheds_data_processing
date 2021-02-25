#retrieval kernels ####

#discharge: STATUS=READY
#. handle_errors
process_0_4341 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)

    dir.create(raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    fext <- ifelse(set_details$component %in% c('HF00401', 'HF00407'),
                   '.txt',
                   '.csv')

    download.file(url = set_details$url,
                  destfile = glue(raw_data_dest,
                                  '/',
                                  set_details$component,
                                  '.csv'),
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#precipitation; precip_gauge_locations: STATUS=READY
#. handle_errors
process_0_5482 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)

    dir.create(raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    fext <- ifelse(set_details$component == 'MS00404',
                   '.txt',
                   '.csv')

    if(prodname_from_prodname_ms(set_details$prodname_ms) == 'precipitation'){

        if(! set_details$component %in% c('MS00402', 'MS00403', 'MS00404')){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }

    } else if(prodname_from_prodname_ms(set_details$prodname_ms) == 'precip_gauge_locations'){

        if(! set_details$component == 'MS00401'){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }
    }

    download.file(url = set_details$url,
                  destfile = glue(raw_data_dest,
                                  '/',
                                  set_details$component,
                                  fext),
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_4021 <- function(set_details, network, domain){

    #Stream flux (stream_flux_inst__4021) was removed becuase we are not wanting
    #use theirs as of now and was causing error in ms_derive

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)

    dir.create(raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    if(prodname_from_prodname_ms(set_details$prodname_ms) == 'stream_chemistry'){

        if(! set_details$component %in% c('CF00201', 'CF00202', 'CF00203', 'CF00206')){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }

    } else if(prodname_from_prodname_ms(set_details$prodname_ms) == 'stream_flux_inst'){

        if(! set_details$component %in% c('CF00204', 'CF00205', 'CF00206')){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }
    }

    download.file(url = set_details$url,
                  destfile = glue(raw_data_dest,
                                  '/',
                                  set_details$component,
                                  '.csv'),
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#precip_chemistry; precip_flux_inst: STATUS=READY
#. handle_errors
process_0_4022 <- function(set_details, network, domain){

    #precip_flux_inst__4022 was removed becuase we make our own and it was
    #causing issues for ms_derive

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)

    dir.create(raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    if(prodname_from_prodname_ms(set_details$prodname_ms) == 'precip_chemistry'){

        if(! set_details$component %in% c('CP00201', 'CP00203', 'CP00206')){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }

    } else if(prodname_from_prodname_ms(set_details$prodname_ms) == 'precip_flux_inst'){

        if(! set_details$component %in% c('CP00202', 'CP00206')){
            logwarn('Skipping redundant download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }
    }

    download.file(url = set_details$url,
                  destfile = glue(raw_data_dest,
                                  '/',
                                  set_details$component,
                                  '.csv'),
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#stream_gauge_locations; ws_boundary: STATUS=READY
#. handle_errors
process_0_3239 <- function(set_details, network, domain) {

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)
    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    if(prodname_from_prodname_ms(set_details$prodname_ms) == 'ws_boundary'){

        if(! set_details$component %in% c('hf01402', 'hf01404')){
            logwarn('Skipping redundant or unneeded download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }

    } else if(prodname_from_prodname_ms(set_details$prodname_ms) == 'stream_gauge_locations'){

        if(! set_details$component == 'hf01403'){
            logwarn('Skipping redundant or unneeded download',
                    logger = logger_module)
            return(generate_blacklist_indicator())
        }
    }

    rawfile=glue(raw_data_dest,
                 '/',
                 set_details$component)
    download.file(url = set_details$url,
                  destfile = rawfile,
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#munge kernels ####

#discharge: STATUS=READY
#. handle_errors
process_1_4341 <- function(network, domain, prodname_ms, site_name,
                           components){

    rawfile1 = glue('data/{n}/{d}/raw/{p}/{s}/HF00401.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name)

    #look carefully at warnings from ms_read_raw_csv.
    #they may indicate insufficiencies
    d <- ms_read_raw_csv(filepath = rawfile1,
                         datetime_cols = c(DATE_TIME = '%Y-%m-%d %H:%M:%S'),
                         datetime_tz = 'Etc/GMT-8',
                         site_name_col = 'SITECODE',
                         data_cols =  c(INST_Q = 'discharge'),
                         data_col_pattern = '#V#',
                         is_sensor = TRUE,
                         summary_flagcols = c('ESTCODE', 'EVENT_CODE'))

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA,
                            summary_flags_clean = list(
                                ESTCODE = c('A', 'E'),
                                EVENT_CODE = c(NA, 'WEATHR')),
                            summary_flags_dirty = list(
                                ESTCODE = c('Q', 'S', 'P'),
                                EVENT_CODE = c('INSREM', 'MAINTE')))

    d$val <- d$val * 28.3168 #cfs to L/s

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#precipitation; precip_gauge_locations: STATUS=READY
#. handle_errors
process_1_5482 <- function(network, domain, prodname_ms, site_name,
                           components){

    component <- ifelse(prodname_ms == 'precip_gauge_locations__5482',
                        'MS00401',
                        'MS00403')

    rawfile1 = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    if(prodname_ms == 'precip_gauge_locations__5482'){

        projstring <- choose_projection(unprojected = TRUE)

        d <- sw(read_csv(rawfile1, progress=FALSE,
                         col_types = readr::cols_only(
                             SITECODE = 'c',
                             LATITUDE = 'd',
                             LONGITUDE = 'd'))) %>%
             rename(site_name = SITECODE)

        sp::coordinates(d) <- ~LONGITUDE+LATITUDE
        d <- sf::st_as_sf(d)
        sf::st_crs(d) <- projstring #assuming. geodetic datum not given by lter

    } else if(prodname_ms == 'precipitation__5482'){

        d <- ms_read_raw_csv(filepath = rawfile1,
                             datetime_cols = c(DATE = '%Y-%m-%d'),
                             datetime_tz = 'UTC',
                             site_name_col = 'SITECODE',
                             data_cols =  c(PRECIP_TOT_DAY = 'precipitation'),
                             data_col_pattern = '#V#',
                             is_sensor = FALSE,
                             summary_flagcols = c('PRECIP_TOT_FLAG',
                                                  'EVENT_CODE'))

        d <- ms_cast_and_reflag(d,
                                varflag_col_pattern = NA,
                                summary_flags_clean = list(
                                    PRECIP_TOT_FLAG = c('A', 'E'),
                                    EVENT_CODE = c(NA, 'METHOD')),
                                #METHOD indicates when methods change.
                                summary_flags_dirty = list(
                                    PRECIP_TOT_FLAG = c('Q', 'C', 'U'),
                                    EVENT_CODE = c('INSREM', 'MAINTE')))

        d <- carry_uncertainty(d,
                               network = network,
                               domain = domain,
                               prodname_ms = prodname_ms)

        d <- synchronize_timestep(d)

        d <- apply_detection_limit_t(d, network, domain, prodname_ms)
    }

    return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_4021 <- function(network, domain, prodname_ms, site_name,
                           components){

    #note: blacklisting of components has been superseded by the "component"
    #   column in products.csv. don't copy this chunk.
    if(grepl('chemistry', prodname_ms)){
        component <- 'CF00201'
    } else {
        logwarn('Blacklisting stream flux product CF00204 (for now)')
        return(generate_blacklist_indicator())
    }

    rawfile1 <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    #look carefully at warnings from ms_read_raw_csv.
    #they may indicate insufficiencies
    d <- ms_read_raw_csv(filepath = rawfile1,
                         datetime_cols = c(DATE_TIME = '%Y-%m-%d %H:%M:%S'),
                         datetime_tz = 'Etc/GMT-8',
                         site_name_col = 'SITECODE',
                         data_cols =  c(PH='pH', COND='spCond', ALK='alk',
                             SSED='suspSed', SI='Si', PARTP='TPP', PO4P='PO4_P',
                             PARTN='TPN', NH3N='NH3_N', NO3N='NO3_N', CA='Ca',
                             MG='Mg', SO4S='SO4_S', CL='Cl', ANCA='AnCaR',
                             `NA`='Na', 'UTP', 'TDP', 'UTN', 'TDN', 'DON',
                             'UTKN', 'TKN', 'K', 'DOC'),
                         data_col_pattern = '#V#',
                         is_sensor = FALSE,
                         alt_datacol_pattern = '#V#_OUTPUT',
                         var_flagcol_pattern = '#V#CODE',
                         summary_flagcols = c('TYPE'))

    d <- ms_cast_and_reflag(d,
                            variable_flags_to_drop = 'N',
                            variable_flags_clean =
                                c('A', 'E', 'D', 'DE', '*', 'D*'),
                            summary_flags_to_drop = list(
                                TYPE = c('N', 'S', 'YE', 'QB', 'QS', 'QL', 'QA')),
                            summary_flags_clean = list(TYPE = 'F'))

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#precip_chemistry; precip_flux_inst: STATUS=READY
#. handle_errors
process_1_4022 <- function(network, domain, prodname_ms, site_name,
                           components){

    #note: blacklisting of components has been superseded by the "component"
    #   column in products.csv. don't copy this chunk.
    if(grepl('chemistry', prodname_ms)){
        component <- 'CP00201'
    } else {
        logwarn('Blacklisting precip flux product CP00202 (for now)')
        return(generate_blacklist_indicator())
    }

    rawfile1 <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- ms_read_raw_csv(filepath = rawfile1,
                         datetime_cols = c(DATE_TIME = '%Y-%m-%d %H:%M:%S'),
                         datetime_tz = 'Etc/GMT-8',
                         site_name_col = 'SITECODE',
                         data_cols =  c(PH='pH', COND='spCond', ALK='alk',
                                        SSED='suspSed', SI='Si', PARTP='TPP', PO4P='PO4_P',
                                        PARTN='TPN', NH3N='NH3_N', NO3N='NO3_N', CA='Ca',
                                        MG='Mg', SO4S='SO4_S', CL='Cl', ANCA='AnCaR',
                                        `NA`='Na', 'UTP', 'TDP', 'UTN', 'TDN', 'DON',
                                        'UTKN', 'TKN', 'K', 'DOC'),
                                        # PRECIP_CM='precip_ns'),
                         data_col_pattern = '#V#',
                         is_sensor = FALSE,
                         alt_datacol_pattern = '#V#_INPUT',
                         var_flagcol_pattern = '#V#CODE',
                         summary_flagcols = c('TYPE'))

    d <- ms_cast_and_reflag(d,
                            variable_flags_to_drop = 'N',
                            variable_flags_clean =
                                c('A', 'E', 'D', 'DE', '*', 'D*'),
                            summary_flags_to_drop = list(
                                TYPE = c('N', 'S', 'YE', 'QB', 'QS', 'QL', 'QA')),
                            summary_flags_clean = list(TYPE = c('F', 'DF')))

    #HJAndrews does not collect precip and precip chemistry at the same
    #locations, so we here crudely localize pchem data to the nearest precip
    #gauges. we could do this more gracefully with idw.
    d <- d %>%
        mutate(site_name = case_when(
            site_name == 'RCADMN' ~ 'PRIMET',
            grepl('^RCHI..$', site_name, perl = TRUE) ~ 'CENMET',
            TRUE ~ '_ERR')) #may be tripped if they add a new dry dep gauge

    if(any(d$site_name == '_ERR')){
        stop(glue('hjandrews has added a new pchem gauge that we havent mapped',
                  ' to a location'))
    }

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#ws_boundary; stream_gauge_locations: STATUS=READY
#. handle_errors
process_1_3239 <- function(network, domain, prodname_ms, site_name,
                           components){

    component <- ifelse(prodname_ms == 'stream_gauge_locations__3239',
                        'hf01403',
                        'hf01402')

    rawdir1 = glue('data/{n}/{d}/raw/{p}/{s}',
                   n = network,
                   d = domain,
                   p = prodname_ms,
                   s = site_name)
    rawfile1 <- glue(rawdir1, '/', component)

    zipped_files <- unzip(zipfile = rawfile1,
                          exdir = rawdir1,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    if(prodname_ms == 'stream_gauge_locations__3239'){

        d <- sf::st_read(rawdir1,
                         stringsAsFactors = FALSE,
                         quiet = TRUE) %>%
            select(site_name = SITECODE,
                   geometry = geometry) %>%
            sf::st_transform(projstring) %>%
            arrange(site_name) %>%
            sf::st_zm(drop = TRUE,
                      what = 'ZM')

    } else {

        d <- sf::st_read(rawdir1,
                         stringsAsFactors = FALSE,
                         quiet = TRUE) %>%
            select(site_name = WS_,
                   area = F_AREA,
                   geometry = geometry) %>%
            filter(! grepl('^[0-9][0-9]?a$', site_name)) %>% #remove areas below station
            mutate(  #for consistency with name elsewhere
                site_name = stringr::str_pad(site_name,
                                             width = 2,
                                             pad = '0'),
                site_name = paste0('GSWS', site_name),
                site_name = ifelse(site_name == 'GSWSMACK',
                                   'GSMACK',
                                   site_name),
                site_name = ifelse(site_name == 'GSWS04',
                                   'GSLOOK',
                                   site_name)) %>%
            sf::st_transform(projstring) %>%
            arrange(site_name)
    }

    unlink(zipped_files)

    return(d)
}

#derive kernels ####

# #precipitation: STATUS=PAUSED
# #. handle_errors
# process_2_ms001 <- derive_precip
#
# #precip_chemistry: STATUS=PAUSED
# #. handle_errors
# process_2_ms002 <- derive_precip_chem
#
# #precip_flux_inst: STATUS=PAUSED
# #. handle_errors
# process_2_ms004 <- derive_precip_flux

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms001 <- derive_stream_flux

#precip_pchem_pflux: STATUS=READY
#. handle_errors
process_2_ms002 <- derive_precip_pchem_pflux
