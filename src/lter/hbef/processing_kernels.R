#retrieval kernels ####

#discharge: STATUS=READY
#. handle_errors
process_0_1 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name)

    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    download.file(url=set_details$url,
        destfile=glue(raw_data_dest, '/', set_details$component),
        cacheOK=FALSE, method='curl')

    return()
}

#precipitation: STATUS=READY
#. handle_errors
process_0_13 <- function(set_details, network, domain){

    raw_data_dest <- glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                          wd = getwd(),
                          n = network,
                          d = domain,
                          p = set_details$prodname_ms,
                          s = set_details$site_name)

    dir.create(raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    download.file(url = set_details$url,
                  destfile = glue(raw_data_dest,
                                  '/',
                                  set_details$component,
                                  '.csv'),
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#stream_chemistry; precip_chemistry: STATUS=READY
#. handle_errors
process_0_208 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name)
    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    if(set_details$component == 'Analytical Methods'){
        fext <- '.pdf'
    } else {
        l1 <- all(grepl('precip', c(set_details$component,  prodname_ms)))
        l2 <- all(grepl('stream', c(set_details$component,  prodname_ms)))

        if(! sum(l1, l2)){
            loginfo('Skipping redundant download', logger=logger_module)
            return(generate_blacklist_indicator())
        }

        fext <- '.csv'
    }

    download.file(url=set_details$url,
        destfile=glue(raw_data_dest, '/', set_details$component, fext),
        cacheOK=FALSE, method='curl')

    return()
}

#stream_gauge_locations: STATUS=READY
#. handle_errors
process_0_107 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name)

    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    download.file(url=set_details$url,
        destfile=glue(raw_data_dest, '/', set_details$component),
        cacheOK=FALSE, method='curl')

    return()
}

#precip_gauge_locations: STATUS=READY
#. handle_errors
process_0_100 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name)

    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    download.file(url=set_details$url,
        destfile=glue(raw_data_dest, '/', set_details$component),
        cacheOK=FALSE, method='curl')

    return()
}

#ws_boundary: STATUS=READY
#. handle_errors
process_0_94 <- function(set_details, network, domain) {

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd = getwd(),
                         n = network,
                         d = domain,
                         p = set_details$prodname_ms,
                         s = set_details$site_name)
    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    rawfile=glue(raw_data_dest, '/', set_details$component)
    download.file(url = set_details$url,
                  destfile = rawfile,
                  cacheOK = FALSE,
                  method = 'curl')

    return()
}

#munge kernels ####

#discharge: STATUS=READY
#. handle_errors
process_1_1 <- function(network, domain, prodname_ms, site_name,
    component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c(DATETIME = '%Y-%m-%d %H:%M:%S'),
                         datetime_tz = 'US/Eastern',
                         site_name_col = 'WS',
                         alt_site_name = list('w1' = c('1', 'W1'),
                                              'w2' = c('2', 'W2'),
                                              'w3' = c('3', 'W3'),
                                              'w4' = c('4', 'W4'),
                                              'w5' = c('5', 'W5'),
                                              'w6' = c('6', 'W6'),
                                              'w7' = c('7', 'W7'),
                                              'w8' = c('8', 'W8'),
                                              'w9' = c('9', 'W9')),
                         data_cols = c(Discharge_ls = 'discharge'),
                         data_col_pattern = '#V#',
                         is_sensor = TRUE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA)

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d,
                              desired_interval = '1 day', #set to '15 min' when we have server
                              impute_limit = 30)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#precipitation: STATUS=READY
#. handle_errors
process_1_13 <- function(network, domain, prodname_ms, site_name,
    component){

    if(component == 'site info'){
        loginfo('Blacklisting superfluous data component')
        return(generate_blacklist_indicator())
    }

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    # SAMPLE: Sensor (also manual. Use a mix of automatic gauges and standard guages)
    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c(DATE = '%Y-%m-%d'),
                         datetime_tz = 'US/Eastern',
                         site_name_col = 'rainGage',
                         data_cols = c(Precip = 'precipitation'),
                         data_col_pattern = '#V#',
                         is_sensor = FALSE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA)

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d,
                              desired_interval = '1 day', #set to '15 min' when we have server
                              impute_limit = 30)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#stream_chemistry; precip_chemistry: STATUS=READY
#. handle_errors
process_1_208 <- function(network, domain, prodname_ms, site_name,
    component){

    if(component == 'Analytical Methods'){
        loginfo('Blacklisting superfluous data component')
        return(generate_blacklist_indicator())
    }

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c(date = '%Y-%m-%d',
                                           timeEST = '%H:%M'),
                         datetime_tz = 'US/Eastern',
                         site_name_col = 'site',
                         alt_site_name = list('w1' = c('1', 'W1'),
                                              'w2' = c('2', 'W2'),
                                              'w3' = c('3', 'W3'),
                                              'w4' = c('4', 'W4'),
                                              'w5' = c('5', 'W5'),
                                              'w6' = c('6', 'W6'),
                                              'w7' = c('7', 'W7'),
                                              'w8' = c('8', 'W8'),
                                              'w9' = c('9', 'W9')),
                         data_cols = c('pH', 'DIC', 'spCond', 'temp',
                                       'ANC960', 'ANCMet', 'Ca', 'Mg', 'K',
                                       'Na', 'TMAl', 'OMAl', 'Al_ICP', 'NH4',
                                       'SO4', 'NO3', 'Cl',
                                       'PO4', 'DOC', 'TDN', 'DON',
                                       'SiO2', 'Mn', 'Fe', 'F',
                                       'cationCharge', 'anionCharge',
                                       'theoryCond', 'ionError', 'ionBalance',
                                       'pHmetrohm'),
                         data_col_pattern = '#V#',
                         is_sensor = FALSE,
                         summary_flagcols = 'fieldCode')

    d <- ms_cast_and_reflag(d,
                            summary_flags_clean = list(fieldCode = NA),
                            summary_flags_to_drop = list(fieldCode = '#*#'),
                            varflag_col_pattern = NA)

    d <- ms_conversions(d,
                        convert_units_from = c(DIC = 'uM'),
                        convert_units_to = c(DIC = 'mM'))

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d,
                              desired_interval = '1 day', #set to '15 min' when we have server
                              impute_limit = 30)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#ws_boundary: STATUS=READY
#. handle_errors
process_1_94 <- function(network, domain, prodname_ms, site_name,
                         component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}',
                   n=network, d=domain, p=prodname_ms, s=site_name)

    rawfile <- glue(rawdir, '/', component)

    zipped_files <- unzip(zipfile = rawfile,
                          exdir = rawdir,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    wb <- sf::st_read(rawdir, stringsAsFactors = FALSE,
                      quiet = TRUE) %>%
        # mutate(WSHEDS0_ID = ifelse(is.na(WSHEDS0_ID), 0, WSHEDS0_ID)) %>%
        filter(!is.na(WS)) %>% #ignore encompassing, non-experimental watershed
        select(site_name = WSHEDS0_ID,
               area = AREA,
               perimeter = PERIMETER,
               geometry = geometry) %>%
        mutate(site_name = paste0('w', site_name)) %>%
        sf::st_transform(projstring) %>%
        arrange(site_name)

    unlink(zipped_files)

    for(i in 1:nrow(wb)){

        new_wb <- wb[i,]

        site_name <- as_tibble(new_wb) %>%
            pull(site_name)

        write_ms_file(d = new_wb,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = site_name,
                      level = 'munged',
                      shapefile = TRUE,
                      link_to_portal = FALSE)
    }

    return()
}

#precip_gauge_locations: STATUS=READY
#. handle_errors
process_1_100 <- function(network, domain, prodname_ms, site_name,
                          component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}',
                   n=network, d=domain, p=prodname_ms, s=site_name)
    rawfile <- glue(rawdir, '/', component)

    zipped_files <- unzip(zipfile = rawfile,
                          exdir = rawdir,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    rg_all <- sf::st_read(rawdir, stringsAsFactors = FALSE,
                          quiet = TRUE) %>%
        filter(! is.na(GAGE_NUM)) %>%
        select(site_name = ID,
               geometry = geometry) %>%
        sf::st_transform(projstring) %>%
        arrange(site_name)

    unlink(zipped_files)

    for(i in 1:nrow(rg_all)){

        rg <- rg_all[i,] %>%
            sf::st_zm(drop=TRUE, what='ZM') #drop Z dimension

        write_ms_file(d = rg,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = rg$site_name,
                      level = 'munged',
                      shapefile = TRUE,
                      link_to_portal = FALSE)
    }

    return()
}

#stream_gauge_locations: STATUS=READY
#. handle_errors
process_1_107 <- function(network, domain, prodname_ms, site_name,
                          component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}',
                   n=network, d=domain, p=prodname_ms, s=site_name)
    rawfile <- glue(rawdir, '/', component)

    zipped_files <- unzip(zipfile = rawfile,
                          exdir = rawdir,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    weirs_all <- sf::st_read(rawdir, stringsAsFactors = FALSE,
                             quiet = TRUE) %>%
        filter(! is.na(WEIR_NUM)) %>%
        select(site_name = WEIR_NUM,
               geometry = geometry) %>%
        mutate(site_name = paste0('w', site_name)) %>%
        sf::st_transform(projstring) %>%
        arrange(site_name)

    unlink(zipped_files)

    for(i in 1:nrow(weirs_all)){

        w <- weirs_all[i,] %>%
             sf::st_zm(drop=TRUE, what='ZM') #drop Z dimension

        write_ms_file(d = w,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = w$site_name,
                      level = 'munged',
                      shapefile = TRUE,
                      link_to_portal = FALSE)
    }

    return()
}

#derive kernels ####

#precipitation: STATUS=READY
#. handle_errors
process_2_ms001 <- function(network, domain, prodname_ms){

    precip_idw(precip_prodname = 'precipitation__13',
               wb_prodname = 'ws_boundary__94',
               pgauge_prodname = 'precip_gauge_locations__100',
               precip_prodname_out = prodname_ms)

    return()
}

#precip_chemistry: STATUS=READY
#. handle_errors
process_2_ms002 <- function(network, domain, prodname_ms){

    pchem_idw(pchem_prodname = 'precip_chemistry__208',
              precip_prodname = 'precipitation__13',
              wb_prodname = 'ws_boundary__94',
              pgauge_prodname = 'precip_gauge_locations__100',
              pchem_prodname_out = prodname_ms)

    return()
}

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms003 <- function(network, domain, prodname_ms){

    chemprod <- 'stream_chemistry__208'
    qprod <- 'discharge__1'

    chemfiles <- ms_list_files(network = network,
                               domain = domain,
                               level = 'munged',
                               prodname_ms = chemprod)

    qfiles <- ms_list_files(network = network,
                            domain = domain,
                            level = 'munged',
                            prodname_ms = qprod)

    flux_sites <- generics::intersect(
        fname_from_fpath(qfiles, include_fext = FALSE),
        fname_from_fpath(chemfiles, include_fext = FALSE))

    for(s in flux_sites){

        flux <- sw(calc_inst_flux(chemprod = chemprod,
                                  qprod = qprod,
                                  site_name = s))

        write_ms_file(d = flux,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = s,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = FALSE)
    }

    return()
}

#precip_flux_inst: STATUS=READY
#. handle_errors
process_2_ms004 <- function(network, domain, prodname_ms){

    flux_idw(pchem_prodname = 'precip_chemistry__208',
             precip_prodname = 'precipitation__13',
             wb_prodname = 'ws_boundary__94',
             pgauge_prodname = 'precip_gauge_locations__100',
             flux_prodname_out = prodname_ms)

    return()
}
