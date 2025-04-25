#retrieval kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_700 <- function(set_details, network, domain){

    download_raw_file(network = network,
                      domain = domain,
                      set_details = set_details,
                      file_type = '.csv')

    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_900 <- function(set_details, network, domain){

    download_raw_file(network = network,
                      domain = domain,
                      set_details = set_details,
                      file_type = '.csv')

    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_800 <- function(set_details, network, domain){

    download_raw_file(network = network,
                      domain = domain,
                      set_details = set_details,
                      file_type = '.csv')

    return()
}

#precipitation: STATUS=READY
#. handle_errors
process_0_3110 <- function(set_details, network, domain){

    download_raw_file(network = network,
                      domain = domain,
                      set_details = set_details,
                      file_type = '.csv')

    return()
}

#ws_boundary: STATUS=READY
#. handle_errors
process_0_3200 <- function(set_details, network, domain){

  download_raw_file(network = network,
                    domain = domain,
                    set_details = set_details,
                    file_type = '.zip')

  return()
}

#munge kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_700 <- function(network, domain, prodname_ms, site_code, component){

  browser()
    rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    d_ <- read.csv(rawfile) %>%
        distinct()

    #2024: no location info available for missing sites: CBLM, GFuGR, GRGF, GRuTW
    d <- ms_read_raw_csv(preprocessed_tibble = d_,
                         datetime_cols = c('Date' = '%Y-%m-%d',
                                              'time' = '%H:%M'),
                         datetime_tz = 'Etc/GMT+5',
                         site_code_col = 'Site',
                         #very different values at e.g. GFCP and GFCPComp sometimes
                         # alt_site_code = list('GFCP' = 'GFCPComp',
                         #                      'GFGL' = 'GFGLComp',
                         #                      'GFVN' = 'GFVNComp',
                         #                      # 'GRGF' = 'grgf',
                         #                      'RGHT' = 'RGHTisco'),
                         data_cols = c('Cl', 'NO3'='NO3_N', 'PO4'='PO4_P', 'SO4', 'TN', 'TP',
                                       'temperature'='temp', 'dox'='DO', 'pH',
                                       'Turbidity'='turbid_NTU', 'Ecoli',
                                       'conductivity'='spCond', 'Ca', 'HCO3',
                                       'K', 'Mg', 'Na',
                                       'd15N.NO3'='d15N_NO3', 'd18O.NO3'='d18O_NO3'),
                         set_to_NA = error_code_variants,
                         data_col_pattern = '#V#',
                         is_sensor = FALSE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA)

    #pH values greater than 100, removing here
    d <- mutate(d,
                val = ifelse(var == 'GN_pH' & val > 14, NA, val))

    # conv_units <- c('PO4_P', 'SO4', 'TP', 'DO', 'Ca', 'HCO3', 'K', 'Mg', 'Na')
    conv_units <- c('Ca', 'HCO3', 'K', 'Mg', 'Na')

    d <- ms_conversions_(
        d,
        convert_units_from = setNames(rep('ug/l', length(conv_units)),
                                      conv_units),
        convert_units_to = setNames(rep('mg/l', length(conv_units)),
                                    conv_units)
    )

    return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_900 <- function(network, domain, prodname_ms, site_code, component){

    rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c('Date' = '%Y-%m-%d',
                                              'time' = '%H:%M'),
                         datetime_tz = 'Etc/GMT+5',
                         site_code_col = 'Site',
                         data_cols = c('Cl', 'NO3'='NO3_N', 'PO4'='PO4_P', 'SO4', 'TN', 'TP',
                                       'temperature'='temp', 'dox'='DO', 'ph'='pH',
                                       'Turbidity'='turbid_NTU', 'Ecoli'),
                         set_to_NA = c(error_code_variants,
                                       'brown/clear water', 'clear', 'teal',
                                       'orange precipitate', 'turbid', 'bubbles'),
                         data_col_pattern = '#V#',
                         is_sensor = FALSE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA)

    d <- ms_conversions_(d,
                        convert_units_from = c(DO = 'ug/l'),
                        convert_units_to = c(DO = 'mg/l'))

    return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_800 <- function(network, domain, prodname_ms, site_code, component){

    rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c('date' = '%Y-%m-%d'),
                         datetime_tz = 'Etc/GMT+5',
                         site_code_col = 'site',
                         data_cols = c('chloride'='Cl', 'nitrate'='NO3_N', 'phosphate'='PO4_P',
                                       'sulfate'='SO4', 'nitrogen_total'='TN',
                                       'phosphorus_total'='TP'),
                         set_to_NA = error_code_variants,
                         data_col_pattern = '#V#',
                         is_sensor = FALSE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA)

    d <- ms_conversions_(d,
                        convert_units_from = c(PO4_P = 'ug/l',
                                               TP = 'ug/l',
                                               SO4 = 'ug/l'),
                        convert_units_to = c(PO4_P = 'mg/l',
                                             TP = 'mg/l',
                                             SO4 = 'mg/l'))

      return(d)
}

#precipitation: STATUS=READY
#. handle_errors
process_1_3110 <- function(network, domain, prodname_ms, site_code, component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_code,
                    c = component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = c('Date_Time_EST' = '%Y-%m-%d %H:%M'),
                         datetime_tz = 'Etc/GMT+5',
                         site_code_col = 'Rain_Gauge_ID',
                         data_cols = c('Precipitation_mm'='precipitation'),
                         data_col_pattern = '#V#',
                         is_sensor = TRUE)

    # Baltimore precip is recorded at 8 sites where there are two tipping-bucket
    # rain gauges each. It appears that only rain events are reported, as the
    # dataset has no 0 values (waiting on response from BES). To correct for this
    # both gauges at each site are averaged and 0 values are filled in for all
    # minutes where there is not a record.

    d <- d %>%
        rename(val = 3) %>%
        mutate(site_code = str_split_fixed(site_code, '_', n = Inf)[, 1]) %>%
        group_by(datetime, site_code) %>%
        summarise(val = mean(val, na.rm = TRUE))

    rain_gauges <- unique(d$site_code)

    final <- tibble()
    for(i in 1:length(rain_gauges)){

        onesite <- d %>%
            filter(site_code == rain_gauges[i])

        dates <- seq.POSIXt(min(onesite$datetime), max(onesite$datetime), by = 'min')

        with_0s <- tibble(datetime = dates)

        fin <- full_join(with_0s, onesite, by = 'datetime') %>%
            mutate(val = ifelse(is.na(val), 0, val)) %>%
            mutate(site_code = rain_gauges[i])

        final <- rbind(final, fin)
    }

    d <- final %>%
        mutate(var = 'IS_precipitation',
               ms_status = 0)

    return(d)
}

#ws_boundary: STATUS=READY
#. handle_errors
process_1_3200 <- function(network, domain, prodname_ms, site_code, component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.zip',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    rawdir <- glue('data/{n}/{d}/raw/{p}',
                   n=network, d=domain, p=prodname_ms)

    zipped_files <- unzip(zipfile = rawfile,
                          exdir = rawdir,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    shape_paths <- glue('{d}/01m/{s}',
                       d = rawdir,
                       s = 'BES Watershed Boundary Shapefiles')

    files <- list.files(shape_paths, full.names = T)

    shp_files <- grep('.shp', files, value = T)

    shp_files <- shp_files[! grepl('.shp.xml', shp_files)]

    full_site_code <- str_split_fixed(shp_files, '[/]', n = Inf)[,8]
    full_site_code <- str_split_fixed(full_site_code, '[.]', n = Inf)[,1]

    wbs <- tibble()
    for(i in 1:length(shp_files)){

        site_code <- case_when(full_site_code == 'Baisman_Run' ~ 'BARN',
                               full_site_code == 'Carroll_Park' ~ 'GFCP',
                               full_site_code == 'Dead_Run' ~ 'DRKR',
                               full_site_code == 'Glyndon' ~ 'GFGL',
                               full_site_code == 'Gwynnbrook' ~ 'GFGB',
                               full_site_code == 'McDonogh' ~ 'MCDN',
                               full_site_code == 'Pond_Branch' ~ 'POBR',
                               full_site_code == 'Villa_Nova' ~ 'GFVN')

        wb <- st_read(shp_files[i], quiet = TRUE) %>%
          mutate(site_code = !!site_code[i],
                 area = Area_m2 / 10000) %>%
          select(-Area_m2) %>%
          sf::st_transform(4326)

        wbs <- rbind(wbs, wb)
    }

    unlink('data/lter/baltimore/raw/ws_boundary__3200/01m', recursive = TRUE)
    unlink('data/lter/baltimore/raw/ws_boundary__3200/30m', recursive = TRUE)
    unlink('data/lter/baltimore/raw/ws_boundary__3200/READ\ ME.txt')

    return(wbs)
}

#derive kernels ####

#precip_gauge_locations
#. handle_errors
process_2_ms013 <- precip_gauge_from_site_data

#stream_gauge_locations
#. handle_errors
process_2_ms014 <- stream_gauge_from_site_data

#stream_chemistry: STATUS=READY
#. handle_errors
process_2_ms012 <- function(network, domain, prodname_ms){

    combine_products(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     input_prodname_ms = c('stream_chemistry__700',
                                           'stream_chemistry__900',
                                           'stream_chemistry__800'))

    return()
}

#discharge: STATUS=READY
#. handle_errors
process_2_ms011 <- function(network, domain, prodname_ms){

    pull_usgs_discharge(network = network,
                        domain = domain,
                        prodname_ms = prodname_ms,
                        sites = c('GFCP' = '01589352', 'GFGB' = '01589197',
                                  'GFGL' = '01589180', 'GFVN' = '01589300',
                                  'POBR' = '01583570', 'DRKR' = '01589330',
                                  'BARN' = '01583580', 'MCDN' = '01589238',
                                  'MAWI' = '01589351'),
                        time_step = c('daily', 'daily', 'daily',
                                      'daily', 'daily', 'daily',
                                      'daily', 'daily', 'daily'))

  return()
}

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms003 <- derive_stream_flux

# #precipitation: STATUS=OBSOLETE
# #. handle_errors
# process_2_ms001 <- derive_precip

#precip_pchem_pflux: STATUS=READY
#. handle_errors
process_2_ms001 <- derive_precip_pchem_pflux
