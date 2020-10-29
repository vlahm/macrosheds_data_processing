#retrieval kernels ####

#stream_chemistry_gwynns: STATUS=READY
#. handle_errors
process_0_700 <- function(set_details, network, domain){

  download_raw_file(network = network,
                    domain = domain,
                    set_details = set_details,
                    file_type = '.csv')

  return()
}

#stream_chemistry_club: STATUS=READY
#. handle_errors
process_0_900 <- function(set_details, network, domain){

  download_raw_file(network = network,
                    domain = domain,
                    set_details = set_details,
                    file_type = '.csv')

  return()
}

#stream_chemistry_gwynns_up: STATUS=READY
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

#munge kernels ####

#stream_chemistry_gwynns: STATUS=READY
#. handle_errors
process_1_700 <- function(network, domain, prodname_ms, site_name,
                          component) {
  # site_name=site_name; component=in_comp

  rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  d <- ms_read_raw_csv(filepath = rawfile,
                       datetime_cols = list('Date' = '%Y-%m-%d',
                                            'time' = '%H:%M'),
                       datetime_tz = 'US/Eastern',
                       site_name_col = 'Site',
                       alt_site_name = list('GFCP' = 'GFCPisco',
                                            'GFGL' = 'GFGLisco',
                                            'GFVN' = 'GFVNisco',
                                            'GRGF' = 'grgf',
                                            'RGHT' = 'RGHTisco'),
                       data_cols = c('Cl', 'NO3'='NO3_N', 'PO4'='PO4_P', 'SO4', 'TN', 'TP',
                                     'temperature'='temp', 'dox'='DO', 'pH',
                                     'Turbidity'='turbid', 'Ecoli',
                                     'conductivity'='spCond', 'Ca', 'HCO3',
                                     'K', 'Mg', 'Na'),
                       set_to_NA = -999.99,
                       data_col_pattern = '#V#',
                       is_sensor = FALSE)

  d <- pivot_longer(data = d,
                    cols = ends_with('__|dat'),
                    names_pattern = '^(.+?)__\\|(dat)$',
                    names_to = c('var', '.value')) %>%
    rename(val = dat) %>%
    mutate(ms_status = 0)

  d <- remove_all_na_sites(d)

  d <- carry_uncertainty(d,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms)

  # Turbidity is in NTU the ms_vars is in FNU, nut sure these are comparable
  d <- ms_conversions(d,
                      convert_units_from = c(PO4_P = 'ug/l',
                                             SO4 = 'ug/l'),
                      convert_units_to = c(PO4_P = 'mg/l',
                                           SO4 = 'mg/l'))

  d <- synchronize_timestep(d,
                            desired_interval = '1 day', #set to '15 min' when we have server
                            impute_limit = 30)

  d <- apply_detection_limit_t(d, network, domain, prodname_ms)

  return(d)
}

#stream_chemistry_club: STATUS=READY
#. handle_errors
process_1_900 <- function(network, domain, prodname_ms, site_name,
                          component) {
  # site_name=site_name; component=in_comp

  rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  d <- ms_read_raw_csv(filepath = rawfile,
                       datetime_cols = list('Date' = '%Y-%m-%d',
                                            'time' = '%H:%M'),
                       datetime_tz = 'US/Eastern',
                       site_name_col = 'Site',
                       data_cols = c('Cl', 'NO3'='NO3_N', 'PO4'='PO4_P', 'SO4', 'TN', 'TP',
                                     'temperature'='temp', 'dox'='DO', 'ph'='pH',
                                     'Turbidity'='turbid', 'Ecoli'),
                       set_to_NA = c(-999.990, -999.99, -999),
                       data_col_pattern = '#V#',
                       is_sensor = FALSE)

  d <- pivot_longer(data = d,
                    cols = ends_with('__|dat'),
                    names_pattern = '^(.+?)__\\|(dat)$',
                    names_to = c('var', '.value')) %>%
    rename(val = dat) %>%
    mutate(ms_status = 0)

  d <- remove_all_na_sites(d)

  d <- carry_uncertainty(d,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms)

  d <- ms_conversions(d,
                      convert_units_from = c(PO4_P = 'ug/l'),
                      convert_units_to = c(PO4_P = 'mg/l'))

  d <- synchronize_timestep(d,
                            desired_interval = '1 day', #set to '15 min' when we have server
                            impute_limit = 30)

  d <- apply_detection_limit_t(d, network, domain, prodname_ms)

  return(d)
}


#stream_chemistry_gwynns_up: STATUS=READY
#. handle_errors
process_1_800 <- function(network, domain, prodname_ms, site_name,
                          component) {

  rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  d <- ms_read_raw_csv(filepath = rawfile,
                       datetime_cols = list('date' = '%Y-%m-%d'),
                       datetime_tz = 'US/Eastern',
                       site_name_col = 'site',
                       data_cols = c('chloride'='Cl', 'nitrate'='NO3_N', 'phosphate'='PO4_P',
                                     'sulfate'='SO4', 'nitrogen_total'='TN',
                                     'phosphorus_total'='TP'),
                       set_to_NA = c(-999.990, -999.99, -999),
                       data_col_pattern = '#V#',
                       is_sensor = FALSE)

  d <- pivot_longer(data = d,
                    cols = ends_with('__|dat'),
                    names_pattern = '^(.+?)__\\|(dat)$',
                    names_to = c('var', '.value')) %>%
    rename(val = dat) %>%
    mutate(ms_status = 0)

  d <- remove_all_na_sites(d)

  d <- carry_uncertainty(d,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms)

  d <- ms_conversions(d,
                      convert_units_from = c(PO4_P = 'ug/l',
                                             TP = 'ug/l',
                                             SO4 = 'ug/l'),
                      convert_units_to = c(PO4_P = 'mg/l',
                                           TP = 'mg/l',
                                           SO4 = 'mg/l'))

  d <- synchronize_timestep(d,
                            desired_interval = '1 day', #set to '15 min' when we have server
                            impute_limit = 30)

  d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#precipitation: STATUS=READY
#. handle_errors
process_1_3110 <- function(network, domain, prodname_ms, site_name,
                           component) {

  rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  d <- ms_read_raw_csv(filepath = rawfile,
                       datetime_cols = list('Date_Time_EST' = '%Y-%m-%d %H:%M'),
                       datetime_tz = 'US/Eastern',
                       site_name_col = 'Rain_Gauge_ID',
                       data_cols = c('Precipitation_mm'='precipitation_ns'),
                       data_col_pattern = '#V#',
                       is_sensor = TRUE)


  # Baltimore precip is recorded at 8 sites where there are two tipping-bucket
  # rain gauges each. It appears that only rain events are reported, as the
  # dataset has no 0 values (waiting on response from BES). To correct for this
  # both gauges at each site are averaged and 0 values are filled in for all
  # minutes where there is not a record.


  d <- d %>%
    rename(val = 3) %>%
    mutate(site_name = str_split_fixed(site_name, '_', n = Inf)[,1]) %>%
    group_by(datetime, site_name) %>%
    summarise(val = mean(val, na.rm = TRUE))

  rain_gauges <- unique(d$site_name)

  final <- tibble()
  for(i in 1:length(rain_gauges)) {

    onesite <- d %>%
      filter(site_name == rain_gauges[i])

    dates <- seq.POSIXt(min(onesite$datetime), max(onesite$datetime), by = 'min')

    with_0s <- tibble(datetime = dates)

    fin <- full_join(with_0s, onesite, by = 'datetime') %>%
      mutate(val = ifelse(is.na(val), 0, val)) %>%
      mutate(site_name = rain_gauges[i])

    final <- rbind(final, fin)
  }

  d <- final %>%
    mutate(var = 'IS_precipitation_ns',
           ms_status = 0)

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

#derive kernels ####

#rain_gauge_locations
#. handle_errors
process_2_ms013 <- function(network, domain, prodname_ms) {

  baltimore_gauges <- read_csv('data/general/site_data.csv') %>%
    filter(domain == 'baltimore',
           site_type == 'rain_gauge') %>%
    sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326) %>%
    select(site_name)

  for(i in 1:nrow(baltimore_gauges)){

    rg <- baltimore_gauges[i,]

    write_ms_file(d = rg,
                  network = network,
                  domain = domain,
                  prodname_ms = prodname_ms,
                  site_name = rg$site_name,
                  level = 'derived',
                  shapefile = TRUE,
                  link_to_portal = FALSE)
  }

  return()
}

#stream_gauge_locations
#. handle_errors
process_2_ms014 <- function(network, domain, prodname_ms) {

  baltimore_gauges <- read_csv('data/general/site_data.csv') %>%
    filter(domain == 'baltimore',
           site_type == 'stream_gauge') %>%
    sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326) %>%
    select(site_name)

  for(i in 1:nrow(baltimore_gauges)){

    sg <- baltimore_gauges[i,]

    write_ms_file(d = sg,
                  network = network,
                  domain = domain,
                  prodname_ms = prodname_ms,
                  site_name = sg$site_name,
                  level = 'derived',
                  shapefile = TRUE,
                  link_to_portal = FALSE)
  }

  return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_2_ms012 <- function(network, domain, prodname_ms) {

  chem_files <- ms_list_files(network = network,
                              domain = domain,
                              level = 'munged',
                              prodname_ms = c('stream_chemistry_gwynns__700',
                                              'stream_chemistry_club__900',
                                              'stream_chemistry_gwynns_up__800'))

  dir <- glue('data/{n}/{d}/derived/{p}',
              n = network,
              d = domain,
              p = prodname_ms)

  dir.create(dir, showWarnings = FALSE)

  site_feather <- str_split_fixed(chem_files, '/', n = Inf)[,6]
  sites <- unique(str_split_fixed(site_feather, '[.]', n = Inf)[,1])

  for(i in 1:length(sites)) {
    site_files <- grep(sites[i], chem_files, value = TRUE)

    sile_full <- map_dfr(site_files, read_feather)

    write_ms_file(d = sile_full,
                  network = network,
                  domain = domain,
                  prodname_ms = prodname_ms,
                  site_name = sites[i],
                  level = 'derived',
                  shapefile = FALSE,
                  link_to_portal = FALSE)
  }

  return()
}

#discharge: STATUS=READY
#. handle_errors
process_2_ms011 <- function(network, domain, prodname_ms) {

  baltimore_sites <- c('GFCP' = '01589352', 'GFGB' = '01589197', 'GFGL' = '01589180', 'GFVN' = '01589300',
                       'POBR' = '01583570', 'DRKR' = '01589330', 'BARN' = '01583580',
                       'RGHT' = '01589340', 'MCDN' = '01589238', 'MAWI' = '01589351')

  for(i in 1:length(baltimore_sites)) {

    if(baltimore_sites[i] == 'MAWI') {
      discharge <- dataRetrieval::readNWISdv(baltimore_sites[i], '00060') %>%
        mutate(datetime = ymd_hms(paste0(Date, ' ', '12:00:00'), tz = 'UTC')) %>%
        mutate(val = X_00060_00003)
    } else {
      discharge <- dataRetrieval::readNWISuv(baltimore_sites[i], '00060') %>%
        rename(datetime = dateTime,
               val = X_00060_00000)
    }

    discharge <- discharge %>%
      mutate(site_name =!!names(baltimore_sites[i])) %>%
      mutate(var = 'discharge',
             val = val * 28.31685,
             ms_status = 0) %>%
      select(site_name, datetime, val, var, ms_status)

    d <- identify_sampling_bypass(discharge,
                             is_sensor = TRUE,
                             network = network,
                             domain = domain,
                             prodname_ms = prodname_ms)

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d,
                              desired_interval = '1 day', #set to '15 min' when we have server
                              impute_limit = 30)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)



    if(! dir.exists(glue('data/{n}/{d}/derived/{p}',
                    n = network,
                    d = domain,
                    p = prodname_ms))) {

      dir.create(glue('data/{n}/{d}/derived/{p}',
                      n = network,
                      d = domain,
                      p = prodname_ms),
                 recursive = TRUE)
    }

    write_ms_file <- write_ms_file(d,
                                   network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms,
                                   site_name = names(baltimore_sites[i]),
                                   level = 'derived',
                                   shapefile = FALSE,
                                   link_to_portal = FALSE)
  }

  return()
}

#precipitation: STATUS=READY
#. handle_errors
process_2_ms001 <- function(network, domain, prodname_ms){

  precip_idw(precip_prodname = 'precipitation__4',
             wb_prodname = 'ws_boundary_ms000',
             pgauge_prodname = 'rain_gauge_locations__230',
             precip_prodname_out = prodname_ms)

  return()
}

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms003 <- function(network, domain, prodname_ms){

  chemprod <- 'stream_chemistry__ms012'
  qprod <- 'discharge__ms011'

  chemfiles <- ms_list_files(network = network,
                             domain = domain,
                             level = 'derived',
                             prodname_ms = chemprod)
  qfiles <- ms_list_files(network = network,
                          domain = domain,
                          level = 'derived',
                          prodname_ms = qprod)

  flux_sites <- generics::intersect(
    fname_from_fpath(qfiles, include_fext = FALSE),
    fname_from_fpath(chemfiles, include_fext = FALSE))

  for(s in flux_sites){

    flux <- sw(calc_inst_flux(chemprod = chemprod,
                              qprod = qprod,
                              level = 'derived',
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

#precipitation: STATUS=READY
#. handle_errors
process_2_ms001 <- function(network, domain, prodname_ms){

    precip_idw(precip_prodname = 'precipitation__3110',
               wb_prodname = 'ws_boundary_ms000',
               pgauge_prodname = 'rain_gauge_locations__ms013',
               precip_prodname_out = prodname_ms)

  return()
}
