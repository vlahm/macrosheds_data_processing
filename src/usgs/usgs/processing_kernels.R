#retrieval kernels ####

#discharge: STATUS=READY
#. handle_errors
process_0_1 <- function(set_details, network, domain){

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                         wd=getwd(),
                         n=network,
                         d=domain,
                         p=set_details$prodname_ms,
                         s=set_details$site_code)

    dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

    if(set_details$data_type_cd == 'dv') {
        d <- dataRetrieval::readNWISdv(set_details$site_no, '00060')
    } else {
        d <- dataRetrieval::readNWISuv(set_details$site_no, '00060')
    }

    write_feather(d, glue(raw_data_dest, '/', set_details$component, '.feather'))

    return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_2 <- function(set_details, network, domain){

  raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                       wd=getwd(),
                       n=network,
                       d=domain,
                       p=set_details$prodname_ms,
                       s=set_details$site_code)

  dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

  if(set_details$data_type_cd == 'dv') {
    d <- dataRetrieval::readNWISdv(set_details$site_no, set_details$component)
  } else {
    d <- dataRetrieval::readNWISuv(set_details$site_no, set_details$component)
  }

  write_feather(d, glue(raw_data_dest, '/', set_details$component, '.feather'))

  return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_3 <- function(set_details, network, domain){

  raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}',
                       wd=getwd(),
                       n=network,
                       d=domain,
                       p=set_details$prodname_ms,
                       s=set_details$site_code)

  dir.create(raw_data_dest, showWarnings=FALSE, recursive=TRUE)

  d <- dataRetrieval::readNWISqw(siteNumbers = set_details$site_no,
                                 parameterCd = set_details$component)

  write_feather(d, glue(raw_data_dest, '/', set_details$component, '.feather'))

  return()
}

#munge kernels ####

#discharge: STATUS=READY
#. handle_errors
process_1_1 <- function(network, domain, prodname_ms, site_code, component){

    rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.feather',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    d <- read_feather(rawfile) %>%
        mutate(across(everything(), as.character),
               dateTime = if_else(nchar(dateTime) == 10,
                                  paste(dateTime, '12:00:00'),
                                  dateTime))

    d <- ms_read_raw_csv(
        preprocessed_tibble = d,
        datetime_cols = c(dateTime = '%Y-%m-%d %H:%M:%S'),
        datetime_tz = 'UTC',
        site_code_col = 'site_no',
        alt_site_code = list(black_earth_creek = '05406457'),
        data_cols = c('X_00060_00000' = 'discharge'),
        data_col_pattern = '#V#',
        is_sensor = TRUE,
        set_to_NA = '',
        summary_flagcols = 'X_00060_00000_cd'
    )

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA,
                            summary_flags_clean = list(X_00060_00000_cd = 'A'),
                            summary_flags_to_drop = list(X_00060_00000_cd = 'sentinel'))

    d$val <- d$val * 28.31685 #cfs -> L/s

    return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_2 <- function(network, domain, prodname_ms, site_code, component){

    rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.feather',
                   n=network, d=domain, p=prodname_ms, s=site_code, c=component)

    d <- read_feather(rawfile)

    d_names <- names(d)
    data_cd <- grep('X_', d_names)

    codes <- str_split_fixed(d_names, '_', n = Inf)[data_cd,2]
    qaqc <- str_split_fixed(d_names, '_', n = Inf)[data_cd,4]

    d_names[data_cd]<- paste0(codes, qaqc)

    names(d) <- d_names

    val_col <- d_names[!grepl('agency_cd|site_no|dateTime|cd', d_names)]
    qaqc_col <- d_names[grepl('cd', d_names) & !grepl('tz|agency', d_names)]

    usgs_to_macrosheds <- sm(read_csv('src/usgs/usgs/usgs_to_macrosheds.csv'))

    macrosheds_var <- usgs_to_macrosheds %>%
      filter(usgs_code == !!val_col)

    d <- d %>%
        rename(datetime = dateTime,
               val = !!val_col) %>%
        mutate(site_code = !!site_code) %>%
        mutate(ms_status = ifelse(.data[[qaqc_col]] == 'A', 0, 1)) %>%
        mutate(var = !!macrosheds_var$macrosheds_var) %>%
        select(site_code, datetime, val, var, ms_status)

    d <- identify_sampling_bypass(d,
                                  is_sensor = TRUE,
                                  network = network,
                                  domain = domain,
                                  prodname_ms = prodname_ms)

    return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_3 <- function(network, domain, prodname_ms, site_code, component){

  rawfile = glue('data/{n}/{d}/raw/{p}/{s}/{c}.feather',
                 n=network, d=domain, p=prodname_ms, s=site_code, c=component)

  d <- read_feather(rawfile)

  usgs_parm_cd <- unique(d$parm_cd)
  if(! length(usgs_parm_cd) == 1){
    return(generate_ms_err('Multiple parm_cd in site_file, investigate'))
  }

  usgs_to_macrosheds <- sm(read_csv('src/usgs/usgs/usgs_to_macrosheds.csv'))

  parm_to_var <- usgs_to_macrosheds[usgs_to_macrosheds[,2] == usgs_parm_cd,]

  d <- d %>%
    filter(medium_cd == 'WS') %>%
    mutate(dqi_cd = ifelse(dqi_cd == 'R', 0, 1),
           remark_cd = ifelse(is.na(remark_cd), 0, 1),
           result_lab_cm_tx = ifelse(is.na(result_lab_cm_tx), 0, 1)) %>%
    mutate(ms_status = ifelse(dqi_cd == 1 | remark_cd == 1 | result_lab_cm_tx == 1,
                              1,
                              0)) %>%
    mutate(var = !!parm_to_var$macrosheds_var) %>%
    select(datetime = startDateTime,
           var,
           val = result_va,
           ms_status) %>%
    mutate(site_code := !!site_code)

  # need to add overwrite options
  d <- identify_sampling_bypass(d,
                                is_sensor = FALSE,
                                date_col = 'datetime',
                                network = network,
                                domain = domain,
                                prodname_ms = prodname_ms,
                                sampling_type = parm_to_var$sampling)

  return(d)
}

#derive kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_2_ms004 <- function(network, domain, prodname_ms) {

  combine_products(network = network,
                   domain = domain,
                   prodname_ms = prodname_ms,
                   input_prodname_ms = c('stream_chemistry__2',
                                         'stream_chemistry__3'))
}

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms005 <- derive_stream_flux

#stream_gauge_locations: STATUS=READY
#. handle_errors
process_2_ms007 <- stream_gauge_from_site_data
