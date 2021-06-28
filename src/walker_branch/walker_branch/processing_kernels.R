
#retrieval kernels ####

#precipitation: STATUS=READY
#. handle_errors
process_0_VERSIONLESS001 <- function(set_details, network, domain) {

    raw_data_dest <- glue('data/{n}/{d}/raw/{p}/{s}',
                          n = network,
                          d = domain,
                          p = prodname_ms,
                          s = set_details$site_name)

    dir.create(path = raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    components <- str_split_fixed(set_details$component, '__[|]', n = Inf)[1,]

    for(p in 1:length(components)){

        rawfile <- glue('{rd}/{c}',
                         rd = raw_data_dest,
                         c = components[p])

        url <- glue('https://tes-sfa.ornl.gov/sites/default/files/{c}',
                                c = components[p])

        res1 <- httr::HEAD(url)

        last_mod_dt <- httr::parse_http_date(res1$headers$`last-modified`) %>%
            as.POSIXct() %>%
            with_tz('UTC')

        if(last_mod_dt > set_details$last_mod_dt){

            download.file(url = url,
                          destfile = rawfile,
                          cacheOK = FALSE,
                          method = 'curl')

            loginfo(msg = paste('Updated', components[p]),
                    logger = logger_module)

            next
        }

        loginfo(glue('Nothing to do for {p} {c}',
                     p = set_details$prodname_ms,
                     c = components[p]),
                logger = logger_module)

    }
    return()
}

#discharge: STATUS=READY
#. handle_errors
process_0_VERSIONLESS002 <- function(set_details, network, domain) {
    raw_data_dest <- glue('data/{n}/{d}/raw/{p}/{s}',
                          n = network,
                          d = domain,
                          p = prodname_ms,
                          s = set_details$site_name)

    dir.create(path = raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    components <- str_split_fixed(set_details$component, '__[|]', n = Inf)[1,]

    for(p in 1:length(components)){

        rawfile <- glue('{rd}/{c}',
                        rd = raw_data_dest,
                        c = components[p])

        url <- glue('https://tes-sfa.ornl.gov/sites/default/files/{c}',
                    c = components[p])

        res1 <- httr::HEAD(url)

        last_mod_dt <- httr::parse_http_date(res1$headers$`last-modified`) %>%
            as.POSIXct() %>%
            with_tz('UTC')

        if(last_mod_dt > set_details$last_mod_dt){

            download.file(url = url,
                          destfile = rawfile,
                          cacheOK = FALSE,
                          method = 'curl')

            loginfo(msg = paste('Updated', components[p]),
                    logger = logger_module)

            next
        }

        loginfo(glue('Nothing to do for {p} {c}',
                     p = set_details$prodname_ms,
                     c = components[p]),
                logger = logger_module)

    }
    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_VERSIONLESS003 <- function(set_details, network, domain) {
    raw_data_dest <- glue('data/{n}/{d}/raw/{p}/{s}',
                          n = network,
                          d = domain,
                          p = prodname_ms,
                          s = set_details$site_name)

    dir.create(path = raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    components <- str_split_fixed(set_details$component, '__[|]', n = Inf)[1,]

    for(p in 1:length(components)){

        rawfile <- glue('{rd}/{c}',
                        rd = raw_data_dest,
                        c = components[p])

        url <- glue('https://tes-sfa.ornl.gov/sites/default/files/{c}',
                    c = components[p])

        res1 <- httr::HEAD(url)

        last_mod_dt <- httr::parse_http_date(res1$headers$`last-modified`) %>%
            as.POSIXct() %>%
            with_tz('UTC')

        if(last_mod_dt > set_details$last_mod_dt){

            download.file(url = url,
                          destfile = rawfile,
                          cacheOK = FALSE,
                          method = 'curl')

            loginfo(msg = paste('Updated', components[p]),
                    logger = logger_module)

            next
        }

        loginfo(glue('Nothing to do for {p} {c}',
                     p = set_details$prodname_ms,
                     c = components[p]),
                logger = logger_module)

    }
    return()
}

#munge kernels ####

#precipitation: STATUS=READY
#. handle_errors
process_1_VERSIONLESS001 <- function(network, domain, prodname_ms, site_name, component) {

    files <- str_split_fixed(component, '__[|]', n = Inf)[1,]

    daily_file <- grep('daily', files, value = TRUE)

    raw_file_daily <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                           n = network,
                           d = domain,
                           p = prodname_ms,
                           s = site_name,
                           c = daily_file)

    hourly_file <- grep('hourly', files, value = TRUE)

    raw_file_hourly <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                           n = network,
                           d = domain,
                           p = prodname_ms,
                           s = site_name,
                           c = hourly_file)

    daily_dat <- read.csv(raw_file_daily, colClasses = 'character') %>%
        mutate(site = 'combined_gauges')

    daily_dat <- ms_read_raw_csv(preprocessed_tibble = daily_dat,
                                 datetime_cols = list('Date' = '%Y%m%d'),
                                 datetime_tz = 'US/Eastern',
                                 site_name_col = 'site',
                                 data_cols =  c('PRECIP' = 'precipitation'),
                                 data_col_pattern = '#V#',
                                 is_sensor = TRUE)

    daily_dat <- ms_cast_and_reflag(daily_dat,
                                    varflag_col_pattern = NA)

    daily_dat <- carry_uncertainty(daily_dat,
                                   network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms)

    daily_dat <- synchronize_timestep(daily_dat)

    daily_dat <- daily_dat %>%
        filter(datetime > '1997-01-01',
               datetime < '1998-12-30')

    hourly_dat <- read.csv(raw_file_hourly, colClasses = 'character') %>%
        mutate(site = 'combined_gauges')

    hourly_dat <- ms_read_raw_csv(preprocessed_tibble = hourly_dat,
                                 datetime_cols = list('DATE' = '%Y%m%d',
                                                      'TIME' = '%H:%M'),
                                 datetime_tz = 'US/Eastern',
                                 site_name_col = 'site',
                                 data_cols =  c('PRECIP' = 'precipitation'),
                                 summary_flagcols = 'FLAG',
                                 data_col_pattern = '#V#',
                                 set_to_NA = '-9999',
                                 is_sensor = TRUE)

    hourly_dat <- ms_cast_and_reflag(hourly_dat,
                                     varflag_col_pattern = NA,
                                     summary_flags_to_drop = list('FLAG' = 'DROP'),
                                     summary_flags_dirty = list('FLAG' = 'FLAGGED'))

    hourly_dat <- carry_uncertainty(hourly_dat,
                                    network = network,
                                    domain = domain,
                                    prodname_ms = prodname_ms)

    hourly_dat <- synchronize_timestep(hourly_dat)

    d <- rbind(daily_dat, hourly_dat) %>%
        arrange(datetime)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    sites <- unique(d$site_name)

    for(s in 1:length(sites)){

        d_site <- d %>%
            filter(site_name == !!sites[s])

        write_ms_file(d = d_site,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = sites[s],
                      level = 'munged',
                      shapefile = FALSE)
    }
    return()
}

#discharge: STATUS=READY
#. handle_errors
process_1_VERSIONLESS002 <- function(network, domain, prodname_ms, site_name, component) {

    files <- str_split_fixed(component, '__[|]', n = Inf)[1,]

    daily_file <- grep('daily', files, value = TRUE)

    raw_file_daily <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                           n = network,
                           d = domain,
                           p = prodname_ms,
                           s = site_name,
                           c = daily_file)

    min_file <- grep('minute', files, value = TRUE)

    raw_file_min <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                            n = network,
                            d = domain,
                            p = prodname_ms,
                            s = site_name,
                            c = min_file)

    daily_dat <- read.csv(raw_file_daily, colClasses = 'character') %>%
        pivot_longer(cols = c('EF_DISCHARGE', 'WF_DISCHARGE'))

    daily_dat <- ms_read_raw_csv(preprocessed_tibble = daily_dat,
                                 datetime_cols = list('DATE' = '%Y%m%d'),
                                 datetime_tz = 'US/Eastern',
                                 site_name_col = 'name',
                                 data_cols =  c('value' = 'discharge'),
                                 alt_site_name = list(east_fork = 'EF_DISCHARGE',
                                                      west_fork = 'WF_DISCHARGE'),
                                 data_col_pattern = '#V#',
                                 summary_flagcols = 'CODE',
                                 set_to_NA = '-9999',
                                 is_sensor = TRUE)

    daily_dat <- ms_cast_and_reflag(daily_dat,
                                    varflag_col_pattern = NA,
                                    summary_flags_to_drop = list('CODE' = 'DROP'),
                                    summary_flags_dirty = list('CODE' = c('EFWF_EST',
                                                                          'WF_EST',
                                                                          'EF_EST',
                                                                          'EFWT_EST',
                                                                          'WF_REG',
                                                                          'EF_REG',
                                                                          'WF_REG2',
                                                                          'EFWF_ISCO')))

    daily_dat <- carry_uncertainty(daily_dat,
                                   network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms)

    daily_dat <- synchronize_timestep(daily_dat)

     daily_dat <- daily_dat %>%
         filter(datetime < '1994-01-01')

    min_dat <- read.csv(raw_file_min, colClasses = 'character') %>%
        pivot_longer(cols = c('EF_DISCHARGE', 'WF_DISCHARGE'))

    min_dat <- ms_read_raw_csv(preprocessed_tibble = min_dat,
                               datetime_cols = list('DATE' = '%Y%m%d'),
                               datetime_tz = 'US/Eastern',
                               site_name_col = 'name',
                               data_cols =  c('value' = 'discharge'),
                               alt_site_name = list(east_fork = 'EF_DISCHARGE',
                                                    west_fork = 'WF_DISCHARGE'),
                               data_col_pattern = '#V#',
                               summary_flagcols = 'CODE',
                               set_to_NA = '-9999',
                               is_sensor = TRUE)

    min_dat <- ms_cast_and_reflag(min_dat,
                                    varflag_col_pattern = NA,
                                    summary_flags_to_drop = list('CODE' = 'DROP'),
                                    summary_flags_dirty = list('CODE' = c('EFWF_EST',
                                                                          'WF_EST',
                                                                          'EF_EST',
                                                                          'EFWT_EST',
                                                                          'WF_REG',
                                                                          'EF_REG',
                                                                          'WF_REG2',
                                                                          'EFWF_ISCO')))

    min_dat <- carry_uncertainty(min_dat,
                                   network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms)

    min_dat <- synchronize_timestep(min_dat)



    d <- rbind(daily_dat, min_dat) %>%
        arrange(datetime)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    sites <- unique(d$site_name)

    for(s in 1:length(sites)){

        d_site <- d %>%
            filter(site_name == !!sites[s])

        write_ms_file(d = d_site,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = sites[s],
                      level = 'munged',
                      shapefile = FALSE)
    }
    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_VERSIONLESS003 <- function(network, domain, prodname_ms, site_name, component) {

    files <- str_split_fixed(component, '__[|]', n = Inf)[1,]

    east_file <- grep('east', files, value = TRUE)

    raw_file_east <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                           n = network,
                           d = domain,
                           p = prodname_ms,
                           s = site_name,
                           c = east_file)

    west_file <- grep('west', files, value = TRUE)

    raw_file_west <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                         n = network,
                         d = domain,
                         p = prodname_ms,
                         s = site_name,
                         c = west_file)

    west_dat <- read.csv(raw_file_west, colClasses = 'character') %>%
        mutate(site = 'west_fork')

    west_dat <- ms_read_raw_csv(preprocessed_tibble = west_dat,
                                datetime_cols = list('DATE' = '%Y%m%d'),
                                datetime_tz = 'US/Eastern',
                                site_name_col = 'site',
                                data_cols =  c('TEMP' = 'temp',
                                               'SP_COND' = 'spCond',
                                               'PH' = 'pH',
                                               'ALK' = 'alk',
                                               'DOC_CONC' = 'DOC',
                                               'SRP_CONC' = 'SRP',
                                               'TDP_CONC' = 'TDP',
                                               'NH4_N_CONC' = 'NH4_N',
                                               'NO3_N_CONC' = 'NO3_NO2_N',
                                               'TDN_CONC' = 'TDN',
                                               'CL_CONC' = 'Cl',
                                               'SO4_CONC' = 'SO4',
                                               'CA_CONC' = 'Ca',
                                               'MG_CONC' = 'Mg',
                                               'NA_CONC' = 'Na',
                                               'K_CONC' = 'K',
                                               'FE_CONC' = 'Fe',
                                               'MN_CONC' = 'Mn',
                                               'SI_CONC' = 'Si',
                                               'AL_CONC' = 'Al',
                                               'BA_CONC' = 'Ba',
                                               'CD_CONC' = 'Cd',
                                               'NI_CONC' = 'Ni',
                                               'PB_CONC' = 'Pb',
                                               'SR_CONC' = 'Sr',
                                               'ZN_CONC' = 'Zn',
                                               'CU_CONC' = 'Cu',
                                               'MO_CONC' = 'Mo'),
                                data_col_pattern = '#V#',
                                var_flagcol_pattern = '#V#_FL',
                                set_to_NA = '-9999',
                                is_sensor = FALSE)

    west_dat <- ms_cast_and_reflag(west_dat,
                                   variable_flags_dirty = c('V2', 'V4', 'V5', 'V6',
                                                            'V7'),
                                   variable_flags_to_drop = 'DROP')

    west_dat <- ms_conversions(west_dat,
                               convert_units_from = c('SRP' = 'ug/l',
                                                      'TDP' = 'ug/l',
                                                      'NH4_N' = 'ug/l',
                                                      'NO3_NO2_N' = 'ug/l',
                                                      'TDN' = 'ug/l'),
                               convert_units_to = c('SRP' = 'mg/l',
                                                    'TDP' = 'mg/l',
                                                    'NH4_N' = 'mg/l',
                                                    'NO3_NO2_N' = 'mg/l',
                                                    'TDN' = 'mg/l'))

    east_dat <- read.csv(raw_file_east, colClasses = 'character') %>%
        mutate(site = 'east_fork')

    east_dat <- ms_read_raw_csv(preprocessed_tibble = east_dat,
                                datetime_cols = list('DATE' = '%Y%m%d'),
                                datetime_tz = 'US/Eastern',
                                site_name_col = 'site',
                                data_cols =  c('TEMP' = 'temp',
                                               'SP_COND' = 'spCond',
                                               'PH' = 'pH',
                                               'ALK' = 'alk',
                                               'DOC_CONC' = 'DOC',
                                               'SRP_CONC' = 'SRP',
                                               'TDP_CONC' = 'TDP',
                                               'NH4_N_CONC' = 'NH4_N',
                                               'NO3_N_CONC' = 'NO3_NO2_N',
                                               'TDN_CONC' = 'TDN',
                                               'CL_CONC' = 'Cl',
                                               'SO4_CONC' = 'SO4',
                                               'CA_CONC' = 'Ca',
                                               'MG_CONC' = 'Mg',
                                               'NA_CONC' = 'Na',
                                               'K_CONC' = 'K',
                                               'FE_CONC' = 'Fe',
                                               'MN_CONC' = 'Mn',
                                               'SI_CONC' = 'Si',
                                               'AL_CONC' = 'Al',
                                               'BA_CONC' = 'Ba',
                                               'CD_CONC' = 'Cd',
                                               'NI_CONC' = 'Ni',
                                               'PB_CONC' = 'Pb',
                                               'SR_CONC' = 'Sr',
                                               'ZN_CONC' = 'Zn',
                                               'CU_CONC' = 'Cu',
                                               'MO_CONC' = 'Mo'),
                                data_col_pattern = '#V#',
                                var_flagcol_pattern = '#V#_FL',
                                set_to_NA = '-9999',
                                is_sensor = FALSE)

    east_dat <- ms_cast_and_reflag(east_dat,
                                   variable_flags_dirty = c('V2', 'V4', 'V5', 'V6',
                                                            'V7'),
                                   variable_flags_to_drop = 'DROP')

    east_dat <- ms_conversions(east_dat,
                               convert_units_from = c('SRP' = 'ug/l',
                                                      'TDP' = 'ug/l',
                                                      'NH4_N' = 'ug/l',
                                                      'NO3_NO2_N' = 'ug/l',
                                                      'TDN' = 'ug/l'),
                               convert_units_to = c('SRP' = 'mg/l',
                                                    'TDP' = 'mg/l',
                                                    'NH4_N' = 'mg/l',
                                                    'NO3_NO2_N' = 'mg/l',
                                                    'TDN' = 'mg/l'))

    d <- rbind(east_dat, west_dat)

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    sites <- unique(d$site_name)

    for(s in 1:length(sites)){

        d_site <- d %>%
            filter(site_name == !!sites[s])

        write_ms_file(d = d_site,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = sites[s],
                      level = 'munged',
                      shapefile = FALSE)
    }

    return()
}

#derive kernels ####

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms001 <- derive_stream_flux

#precip_gauge_locations: STATUS=READY
#. handle_errors
process_2_ms002 <- precip_gauge_from_site_data

#precip_pchem_pflux: STATUS=READY
#. handle_errors
process_2_ms003 <- derive_precip_pchem_pflux
