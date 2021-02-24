#retrieval kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_DP1.20093 <- function(set_details, network, domain){
    # set_details=s

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE)
    # write_lines(data_pile$readme_20093$X1, '/tmp/chili.txt')

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#stream_nitrate: STATUS=READY
#. handle_errors
process_0_DP1.20033 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#stream_PAR: STATUS=READY
#. handle_errors
process_0_DP1.20042 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE, avg=5)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#stream_temperature: STATUS=READY
#. handle_errors
process_0_DP1.20053 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE, avg=5)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#air_pressure: STATUS=PAUSED
#. handle_errors
process_0_DP1.00004 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE, avg=30)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    # out_sub = data_pile$BP_30min %>%
    #     mutate(site_name=paste0(set_details$site_name, updown)) %>%
    #     select(site_name, startDateTime, staPresMean, staPresFinalQF)

    return()
}

#stream_gases: STATUS=READY
#. handle_errors
process_0_DP1.20097 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#surface_elevation: STATUS=PAUSED
#. handle_errors
process_0_DP1.20016 <- function(set_details, network, domain){

    stop('disabled. waiting on NEON to fix this product')

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE, avg=5)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    # out_sub = select(data_pile$EOS_5_min, startDateTime,
    #     surfacewaterElevMean, sWatElevFinalQF, verticalPosition,
    #     horizontalPosition)

    #BELOW: old code for acquiring sensor positions. relevant for decyphering
    #neon's level data and eventually estimating discharge

    # drc = glue('data/neon/neon/raw/surfaceElev_sensorpos/{s}',
    #     s=set_details$site_name)
    # dir.create(drc, showWarnings=FALSE, recursive=TRUE)
    # f = glue(drc, '/{p}.feather', p=set_details$component)
    #
    # # if(file.exists(f)){
    # #     sens_pos = read_feather(f)
    # #     sens_pos = bind_rows(data_pile$sensor_positions_20016, sens_pos) %>%
    # #         distinct()
    # # } else {
    # #     sens_pos = data_pile$sensor_positions_20016
    # # }
    #
    # write_feather(data_pile$sensor_positions_20016, f)

    return()
}

#stream_quality: STATUS=READY
#. handle_errors
process_0_DP1.20288 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
        site=set_details$site_name, startdate=set_details$component,
        enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
        wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
        s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#precipitation: STATUS=READY
#. handle_errors
process_0_DP1.00006 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
                                             site=set_details$site_name, startdate=set_details$component,
                                             enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
                         wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
                         s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#discharge: STATUS=READY
#. handle_errors
process_0_DP4.00130 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
                                             site=set_details$site_name, startdate=set_details$component,
                                             enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
                         wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
                         s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#precip_chemistry: STATUS=READY
#. handle_errors
process_0_DP1.00013 <- function(set_details, network, domain){

    data_pile = neonUtilities::loadByProduct(set_details$prodcode_full,
                                             site=set_details$site_name, startdate=set_details$component,
                                             enddate=set_details$component, package='basic', check.size=FALSE)

    raw_data_dest = glue('{wd}/data/{n}/{d}/raw/{p}/{s}/{c}',
                         wd=getwd(), n=network, d=domain, p=set_details$prodname_ms,
                         s=set_details$site_name, c=set_details$component)

    serialize_list_to_dir(data_pile, raw_data_dest)

    return()
}

#ws_boundary: STATUS=READY
#. handle_errors
process_0_VERSIONLESS001 <- function(set_details, network, domain){

    raw_data_dest <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                          n = network,
                          d = domain,
                          p = prodname_ms,
                          s = set_details$site_name,
                          c = set_details$component)

    dir.create(path = raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    rawfile <- glue(raw_data_dest,
                    '/NEONAquaticWatershed.zip')

    res <- httr::HEAD('https://www.neonscience.org/sites/default/files/NEONAquaticWatershed.zip')
    last_mod_dt <- httr::parse_http_date(res$headers$`last-modified`) %>%
        as.POSIXct() %>%
        with_tz('UTC')

    if(last_mod_dt > set_details$last_mod_dt){

        download.file(url = 'https://www.neonscience.org/sites/default/files/NEONAquaticWatershed.zip',
                      destfile = rawfile,
                      cacheOK = FALSE,
                      method = 'curl')

        loginfo(msg = paste('Updated', set_details$component),
                logger = logger_module)

        return(last_mod_dt)
    }

    return()
}

#munge kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_DP1.20093 <- function(network, domain, prodname_ms, site_name,
    component){
    # site_name=site_name; component=in_comp

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
        n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles <- list.files(rawdir)


    relevant_file1 <- 'swc_domainLabData.feather'
    relevant_file2 <- 'swc_externalLabDataByAnalyte.feather'

    if(relevant_file1 %in% rawfiles){

        out_dom <- read_feather(glue(rawdir, '/', relevant_file1)) %>%
            select(siteID, collectDate, remarks, alkMgPerL,
                   ancMeqPerL) %>%
            mutate(ms_status = ifelse(is.na(remarks), 0, 1)) %>%
            select(-remarks) %>%
            rename(ANC = ancMeqPerL,
                   alk = alkMgPerL) %>%
            mutate(ANC = ANC/1000) %>% # convert from meq/l to eq/l
            pivot_longer(cols = c('ANC', 'alk'), names_to = 'var',
                         values_to = 'val') %>%
            filter(!is.na(val)) %>%
            rename(site_name = siteID,
                   datetime = collectDate) %>%
            mutate(datetime = force_tz(datetime, tzone = 'UTC'))


    }

  if(relevant_file2 %in% rawfiles){

        out_lab <- read_feather(glue(rawdir, '/', relevant_file2)) %>%
            select(site_name = siteID, datetime = collectDate, var = analyte,
                   val = analyteConcentration, shipmentWarmQF, sampleCondition) %>%
            mutate(ms_status = ifelse( shipmentWarmQF == 1 | sampleCondition != 'GOOD',
                                      1, 0)) %>%
            select(-shipmentWarmQF, -sampleCondition) %>%
            mutate(var = case_when(var == 'Si' ~ 'SiO2',
                                   var == 'Ortho - P' ~ 'PO4_P',
                                   var == 'NO3+NO2 - N' ~ 'NO3_NO2_N',
                                   var == 'NO2 - N' ~ 'NO3_N',
                                   var == 'NH4 - N' ~ 'NH4_N',
                                   var == 'conductivity' ~ 'spCond',
                                   var == 'UV Absorbance (280 nm)' ~ 'abs280',
                                   var == 'UV Absorbance (250 nm)' ~ 'abs250',
                                   TRUE ~ var)) %>%
            mutate(val = ifelse(var == 'ANC', val/1000, val)) %>%
            filter(var != 'TSS - Dry Mass') %>%
            mutate(datetime = force_tz(datetime, 'UTC'))

  }

    if(!exists('out_lab') && !exists('out_dom')) {
        print(paste0('swc_externalLabDataByAnalyte.feather and swc_domainLabData.feather are missing for ', component))

        out_sub <- tibble()

    } else {

        if(!exists('out_lab')) {
            print(paste0('swc_externalLabDataByAnalyte.feather is missing for', component, ', will proceed with Alk and ANC file'))

            out_sub <- out_dom
      }

      if(!exists('out_dom')) {
          print(paste0('swc_domainLabData.feather is missing for ', component, ', will proceed with chemisty file file'))

          out_sub <- out_lab
      }

      if(exists('out_dom') && exists('out_lab')) {
          out_sub <- rbind(out_lab, out_dom)
      }

    out_sub <- out_sub %>%
        group_by(datetime, site_name, var) %>%
        summarize(
            val = mean(val, na.rm=TRUE),
            ms_status = max(ms_status, na.rm = TRUE)) %>%
        mutate(val = ifelse(is.nan(val), NA, val))

    }

    return(out_sub)
}

#stream_nitrate: STATUS=READY
#. handle_errors
process_1_DP1.20033 <- function(network, domain, prodname_ms, site_name,
    component){
    # prodname_ms=prodname_ms; site_name=site_name; component=in_comp

    rawdir = glue('data/{n}/{d}/raw/{p}/{s}/{c}',
        n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles = list.files(rawdir)

    relevant_file1 = 'NSW_15_minute.feather'
    if(relevant_file1 %in% rawfiles){
        rawd = read_feather(glue(rawdir, '/', relevant_file1))
    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    if(all(rawd$finalQF == 1)){
        return(generate_ms_exception('All records failed QA'))
    }

    updown <- determine_upstream_downstream(rawd)
    N_mass <- calculate_molar_mass('N')

    out_sub <- rawd %>%
        mutate(
            site_name=paste0(siteID, updown), #append "-up" to upstream site_names
            datetime = force_tz(startDateTime, 'UTC'), #GMT -> UTC
            surfWaterNitrateMean = surfWaterNitrateMean * N_mass / 1000) %>% #uM/L NO3 -> mg/L N
        select(site_name, datetime=startDateTime, val=surfWaterNitrateMean,
               ms_status = finalQF) %>%
      mutate(var = 'NO3_N')

    return(out_sub)
}

#stream_PAR: STATUS=READY
#. handle_errors
process_1_DP1.20042 <- function(network, domain, prodname_ms, site_name,
    component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                  n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles <- list.files(rawdir)

    relevant_file1 = 'PARWS_5min.feather'

    if(relevant_file1 %in% rawfiles){
        rawd <- read_feather(glue(rawdir, '/', relevant_file1))
    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    if(all(rawd$PARFinalQF == 1) || all(is.na(rawd$PARMean))){
        return(generate_ms_exception('All records failed QA or no data in component'))
    }

    updown <- determine_upstream_downstream(rawd)

    out_sub <- rawd %>%
        mutate(
            site_name=paste0(siteID, updown), #append "-up" to upstream site_names
            datetime = force_tz(startDateTime, 'UTC')) %>% #GMT -> UTC
        group_by(datetime, site_name) %>%
        summarize(
            val = mean(PARMean, na.rm=TRUE),
            ms_status = numeric_any(PARFinalQF)) %>%
        ungroup() %>%
      mutate(var = 'PAR') %>%
        select(site_name, datetime=datetime, var, val, ms_status)

    out_sub[is.na(out_sub)] <- NA

    return(out_sub)
}

#stream_temperature: STATUS=READY
#. handle_errors
process_1_DP1.20053 <- function(network, domain, prodname_ms, site_name,
    component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                   n = network,
                   d = domain,
                   p = prodname_ms,
                   s = site_name,
                   c = component)

    rawfiles <- list.files(rawdir)
    # write_neon_readme(rawdir, dest='/tmp/neon_readme.txt')
    # varkey = write_neon_variablekey(rawdir, dest='/tmp/neon_varkey.csv')

    relevant_file1 <- 'TSW_5min.feather'

    if(relevant_file1 %in% rawfiles){
        rawd <- read_feather(glue(rawdir, '/', relevant_file1))
    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    if(all(rawd$finalQF == 1) || all(is.na(rawd$surfWaterTempMean))){
        return(generate_ms_exception('All records failed QA or no data in component'))
    }

    updown <- determine_upstream_downstream(rawd)
    # rawd <- mutate(rawd,
    #                siteID = paste0(siteID, updown))

    out_sub <- rawd %>%
      mutate(site_name = paste0(siteID, updown)) %>%
      mutate(datetime = force_tz(startDateTime, 'UTC')) %>%
      group_by(datetime, site_name) %>%
      summarize(val = mean(surfWaterTempMean, na.rm=TRUE),
                ms_status = numeric_any(finalQF)) %>%
      ungroup() %>%
      mutate(var = 'temp') %>%
      select(site_name, datetime, var, val, ms_status)

    out_sub[is.na(out_sub)] <- NA

    return(out_sub)

    # d <- ms_read_raw_csv(preprocessed_tibble = rawd,
    #                      datetime_cols = c(startDateTime = '%Y-%m-%d %H:%M:%S'),
    #                      datetime_tz = 'UTC',
    #                      site_name_col = 'siteID',
    #                      data_cols = c(surfWaterTempMean = 'temp'),
    #                      data_col_pattern = '#V#',
    #                      is_sensor = TRUE,
    #                      summary_flagcols = 'finalQF')
    #
    # d <- ms_cast_and_reflag(d,
    #                         summary_flags_clean = list(finalQF = 0),
    #                         summary_flags_dirty = list(fieldCode = 1),
    #                         varflag_col_pattern = NA)
    # #
    # # # d <- ms_conversions(d, )
    # #
    # # d <- carry_uncertainty(d,
    # #                        network = network,
    # #                        domain = domain,
    # #                        prodname_ms = prodname_ms)
    # #
    # # d <- synchronize_timestep(d)
    # #
    # # d <- apply_detection_limit_t(d, network, domain, prodname_ms)
    #
    # return(d)
}

#air_pressure: STATUS=PAUSED
#. handle_errors
process_1_DP1.00004 <- function(network, domain, prodname_ms, site_name,
    component){
    rawdir = glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                  n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles = list.files(rawdir)
    # write_neon_readme(rawdir, dest='/tmp/neon_readme.txt')
    # varkey = write_neon_variablekey(rawdir, dest='/tmp/neon_varkey.csv')

    relevant_file1 = 'BP_30min.feather'

    if(relevant_file1 %in% rawfiles){
        rawd = read_feather(glue(rawdir, '/', relevant_file1))
        out_sub = sourceflags_to_ms_status(rawd, list(staPresFinalQF = 0))
    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    if(all(out_sub$ms_status == 1)){
        return(generate_ms_exception('All records failed QA'))
    }

    updown = determine_upstream_downstream(out_sub)

    out_sub = out_sub %>%
        mutate(
            site_name=paste0(siteID, updown), #append "-up" to upstream site_names
            startDateTime = force_tz(startDateTime, 'UTC')) %>% #GMT -> UTC
        group_by(startDateTime, site_name) %>%
        summarize(
            staPresMean = mean(staPresMean, na.rm=TRUE),
            ms_status = numeric_any(ms_status)) %>%
        ungroup() %>%
        select(site_name, datetime=startDateTime, airpressure=staPresMean,
            ms_status)

    out_sub <- synchronize_timestep(d = out_sub)

    return(out_sub)
}

#stream_gases: STATUS=READY
#. handle_errors
process_1_DP1.20097 <- function(network, domain, prodname_ms, site_name,
    component){

    rawdir = glue('data/{n}/{d}/raw/{p}/{s}/{c}',
        n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles = list.files(rawdir)

    relevant_file1 = 'sdg_externalLabData.feather'

    # file_data = read_feather(glue(rawdir, '/', 'sdg_fieldData.feather'))
    # file_data_air = read_feather(glue(rawdir, '/', 'sdg_fieldDataAir.feather'))
    # file_data_proc = read_feather(glue(rawdir, '/', 'sdg_fieldDataProc.feather'))
    # file_data_parent = read_feather(glue(rawdir, '/', 'sdg_fieldSuperParent.feather'))
    # validation = read_feather(glue(rawdir, '/', 'validation_20097.feather'))
    # variable = read_feather(glue(rawdir, '/', 'variables_20097.feather'))

    if(relevant_file1 %in% rawfiles){

        rawd = read_feather(glue(rawdir, '/', relevant_file1)) %>%
          mutate(sampleCondition = ifelse(is.na(sampleCondition), 1, sampleCondition)) %>%
          mutate(condition = ifelse(sampleCondition == 'OK',
                 0, 1)) %>%
          mutate(gasCheckStandardQF = ifelse(is.na(gasCheckStandardQF), 0,
                                             gasCheckStandardQF)) %>%
          mutate(condition_2 = ifelse(gasCheckStandardQF == 1, 1, 0)) %>%
          mutate(error = ifelse(condition == 1 | condition_2 == 1, 1, 0))

    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    if(all(rawd$error == 1)){
        return(generate_ms_exception('All records failed QA'))
    }

    out_sub <- rawd %>%
        mutate(
          datetime = lubridate::force_tz(collectDate, 'UTC'), #GMT -> UTC
          type =  grepl("AIR", rawd$sampleID)) %>%
        mutate(type = ifelse(type == TRUE, 'air', 'water')) %>%
      filter(type == 'water') %>%
        group_by(datetime, siteID) %>%
      summarise('CH4' = mean(concentrationCH4, na.rm = TRUE),
                'CO2' = mean(concentrationCO2, na.rm = TRUE),
                'N2O' = mean(concentrationN2O, na.rm = TRUE),
                ms_status = max(error, na.rm = TRUE)) %>%
        ungroup() %>%
        rename(site_name = siteID) %>%
      pivot_longer(cols = c('CH4', 'CO2', 'N2O'), names_to = 'var', values_to = 'val')

    return(out_sub)
}

#surface_elevation: STATUS=PENDING (not yet needed. waiting on neon)
#. handle_errors
process_1_DP1.20016 <- function(network, domain, prodname_ms, site_name,
    component){
    NULL
}

#stream_quality: STATUS=READY
#. handle_errors
process_1_DP1.20288 <- function(network, domain, prodname_ms, site_name,
    component){

    rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
        n=network, d=domain, p=prodname_ms, s=site_name, c=component)

    rawfiles <- list.files(rawdir)
    relevant_file1 <- 'waq_instantaneous.feather'

    if(relevant_file1 %in% rawfiles){
        rawd <- read_feather(glue(rawdir, '/', relevant_file1))
    } else {
        return(generate_ms_exception('Relevant file missing'))
    }

    na_test <- rawd %>%
      select(specificConductance, dissolvedOxygen, pH, chlorophyll, turbidity, fDOM) %>%
      unique() %>%
      is.na()

    if(all(na_test[1,]) && nrow(na_test) == 1) {

      return(generate_ms_exception('Data file contains all NAs'))
    }

    updown = determine_upstream_downstream(rawd)

    out_sub <- rawd %>%
      mutate(site_name=paste0(site_name, updown)) %>%
      select(site_name, datetime=startDateTime, 'spCond__|dat'=specificConductance,
             'spCond__|flg' = specificCondFinalQF, 'DO__|dat'=dissolvedOxygen,
             'DO__|flg' = dissolvedOxygenFinalQF, 'pH__|dat' = pH,
             'pH__|flg' = pHFinalQF, 'CHL__|dat'=chlorophyll,
             'CHL__|flg' = chlorophyllFinalQF,'turbid__|dat'=turbidity,
             'turbid__|flg' = turbidityFinalQF, 'FDOM__|dat'=fDOM,
             'FDOM__|flg' = fDOMFinalQF)

    out_sub <- ms_cast_and_reflag(out_sub,
                                  variable_flags_clean = 0,
                                  variable_flags_dirty = 1)

    return(out_sub)
}

#precipitation: STATUS=READY
#. handle_errors
process_1_DP1.00006 <- function(network, domain, prodname_ms, site_name,
                                component) {

  rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  rawfiles <- list.files(rawdir)

  relevant_file1 <- 'PRIPRE_5min.feather'
  relevant_file2 <- 'SECPRE_1min.feather'

  if(relevant_file2 %in% rawfiles) {
    rawd2 <- read_feather(glue(rawdir, '/', relevant_file2))

    out_sub2 <- rawd2 %>%
      mutate(site_name=paste(site_name, horizontalPosition, sep = '_'),
             datetime = lubridate::force_tz(startDateTime, 'UTC')) %>%
      mutate(secPrecipRangeQF = ifelse(is.na(secPrecipRangeQF), 0, secPrecipRangeQF),
             secPrecipSciRvwQF = ifelse(is.na(secPrecipSciRvwQF), 0, secPrecipSciRvwQF)) %>%
      mutate(ms_status = ifelse(secPrecipRangeQF == 1 | secPrecipSciRvwQF == 1,
                                1, 0)) %>%
      mutate(var = 'precipitation') %>%
      select(site_name, datetime, var, val = secPrecipBulk, ms_status)
  }

  if(relevant_file1 %in% rawfiles) {
    rawd1 <- read_feather(glue(rawdir, '/', relevant_file1))

    out_sub1 <- rawd1 %>%
      mutate(site_name=paste(site_name, horizontalPosition, sep = '_'),
             datetime = lubridate::force_tz(startDateTime, 'UTC')) %>%
      mutate(ms_status = ifelse(priPrecipFinalQF == 1,
                                1, 0)) %>%
      mutate(var = 'precipitation') %>%
      select(site_name, datetime, var, val = priPrecipBulk, ms_status)
  }

  if(!relevant_file1 %in% rawfiles && ! relevant_file2 %in% rawfiles) {
    return(generate_ms_exception('Missing precip files'))
  }

  if(relevant_file1 %in% rawfiles && relevant_file2 %in% rawfiles) {

    out_sub <- rbind(out_sub2, out_sub1)

  } else {
    if(relevant_file1 %in% rawfiles) { out_sub <- out_sub1 }
    if(relevant_file2 %in% rawfiles) { out_sub <- out_sub2 }
  }

  return(out_sub)

}

#discharge: STATUS=READY
#. handle_errors
process_1_DP4.00130 <-function(network, domain, prodname_ms, site_name,
                                   component){

  rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  rawfiles <- list.files(rawdir)

  relevant_file <- 'csd_continuousDischarge.feather'

  if(relevant_file %in% rawfiles) {

    rawd <- read_feather(glue(rawdir, '/', relevant_file))

    out_sub <- rawd %>%
      mutate(dischargeFinalQFSciRvw = ifelse(is.na(dischargeFinalQFSciRvw), 0, dischargeFinalQFSciRvw),
             dischargeFinalQF = ifelse(is.na(dischargeFinalQF), 0, dischargeFinalQF)) %>%
      mutate(ms_status = ifelse(dischargeFinalQF == 1 | dischargeFinalQFSciRvw == 1,
                                1, 0)) %>%
      mutate(var = 'discharge') %>%
      select(site_name = siteID, datetime = endDate, var, val = maxpostDischarge, ms_status)
  } else {
    return(generate_ms_exception('Missing discharge files'))
  }

  return(out_sub)

}

#precip_chemistry: STATUS=READY
#. handle_errors
process_1_DP1.00013 <- function(network, domain, prodname_ms, site_name,
                                component){

  rawdir <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                 n=network, d=domain, p=prodname_ms, s=site_name, c=component)

  rawfiles <- list.files(rawdir)

  relevant_file <- 'wdp_chemLab.feather'

  # Units all mg/l uS/cm and pH

  if(relevant_file %in% rawfiles){

    out_sub <- read_feather(glue(rawdir, '/', relevant_file)) %>%
      rename('Ca__|dat' = precipCalcium,
             'Mg__|dat' = precipMagnesium,
             'K__|dat' = precipPotassium,
             'Na__|dat' = precipSodium,
             'NH4__|dat' = precipAmmonium,
             'NO3__|dat' =  precipNitrate,
             'SO4__|dat' = precipSulfate,
             'PO4__|dat' = precipPhosphate,
             'Cl__|dat' = precipChloride,
             'Br__|dat' = precipBromide,
             'pH__|dat' = pH,
             'spCond__|dat' = precipConductivity,
             'Ca__|flg' = precipCalciumFlag,
             'Mg__|flg' = precipMagnesiumFlag,
             'K__|flg' = precipPotassiumFlag,
             'Na__|flg' = precipSodiumFlag,
             'NH4__|flg' = precipAmmoniumFlag,
             'NO3__|flg' =  precipNitrateFlag,
             'SO4__|flg' = precipSulfateFlag,
             'PO4__|flg' = precipPhosphateFlag,
             'Cl__|flg' = precipChlorideFlag,
             'Br__|flg' = precipBromideFlag) %>%
      mutate('spCond__|flg' = NA,
             'pH__|flg' = NA) %>%
      select(datetime = collectDate, namedLocation, contains('|dat'), contains('|flg')) %>%
      mutate(across(contains('|flg'), ~ifelse(is.na(.x), 0, 1))) %>%
      mutate(site_name = !!site_name) %>%
      select(-namedLocation)

    out_sub <- ms_cast_and_reflag(out_sub,
                            variable_flags_clean = 0,
                            variable_flags_dirty = 1)

    return(out_sub)

  } else {
    return(generate_ms_exception('wdp_chemLab.feather file missing'))
  }
}

#ws_boundary: STATUS=READY
#. handle_errors
process_1_VERSIONLESS001 <- function(network, domain, prodname_ms, site_name,
                                     component){

    rawdir1 <- glue('data/{n}/{d}/raw/{p}/{s}/{c}',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    rawfile1 <- glue(rawdir1, '/NEONAquaticWatershed.zip')

    zipped_files <- unzip(zipfile = rawfile1,
                          exdir = rawdir1,
                          overwrite = TRUE)

    projstring <- choose_projection(unprojected = TRUE)

    d <- sf::st_read(glue(rawdir1,
                          '/NEON_Aquatic_Watershed.shp'),
                     stringsAsFactors = FALSE,
                     quiet = TRUE) %>%
        filter(Science != 'Lake') %>%
        # mutate(area = WSAreaKm2 * 100) %>%
        select(site_name = SiteID, geometry = geometry) %>%
        sf::st_transform(projstring) %>%
        arrange(site_name)

    if(nrow(d) == 0) stop('no rows in sf object')

    # munged_data_dest <- glue('data/{n}/{d}/munged/{p}',
    #                          n = network,
    #                          d = domain,
    #                          p = prodname_ms)
    #
    # dir.create(path = munged_data_dest,
    #            showWarnings = FALSE,
    #            recursive = TRUE)

    for(i in 1:nrow(d)){

        # dir.create(path = glue(munged_data_dest,
        #                        '/',
        #                        d$site_name[i]),
        #            showWarnings = FALSE,
        #            recursive = TRUE)

        write_ms_file(d = d[i, ],
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = d$site_name[i],
                      level = 'munged',
                      shapefile = TRUE)
    }

    unlink(zipped_files)

    # return(d)
    return()
}

#derive kernels ####

#stream_chemistry: STATUS=READY
#. handle_errors
process_2_ms001 <- function(network, domain, prodname_ms) {

    combine_products(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     input_prodname_ms = c('stream_quality__DP1.20288',
                                           'stream_gases__DP1.20288',
                                           'stream_temperature__DP1.20053',
                                           'stream_nitrate__DP1.20033',
                                           'stream_chemistry__DP1.20093'))

    return()
}

#precipitation: STATUS=READY
#. handle_errors
process_2_ms002 <- function(network, domain, prodname_ms) {

    #Temporary, NEON only hace 1 precip gauge (usually) per site. Eventuly will
    #leverage other data to interploate but for now directly linking gauge to
    #watersheds
    dir.create('data/neon/neon/derived/precipitation__ms002/', recursive = TRUE)

    dir <- 'data/neon/neon/munged/precipitation__DP1.00006/'

    site_files <- list.files(dir)

    sites <- unique(str_split_fixed(site_files, '_', n = Inf)[,1])

    for(i in 1:length(sites)) {

        file <- grep(sites[i], site_files, value = TRUE)

        if(length(file) == 1) {

            precip <- read_feather(paste0(dir, file)) %>%
                mutate(site_name = !!sites[i]) %>%
                mutate(var = 'IS_precipitation')
        } else {

            file <- grep('900', file, value = TRUE)

            precip <- read_feather(paste0(dir, file)) %>%
                mutate(site_name = !!sites[i]) %>%
                mutate(var = 'IS_precipitation')
        }

        write_feather(precip, glue('data/neon/neon/derived/precipitation__ms002/{s}.feather',
                           s = sites[i]))

    }

  return()
}

#precip_flux_inst: STATUS=READY
#. handle_errors
process_2_ms003 <- function(network, domain, prodname_ms) {

    chemfiles <- ms_list_files(network = network,
                               domain = domain,
                               prodname_ms = 'precip_chemistry__DP1.00013')

    qfiles <- ms_list_files(network = network,
                            domain = domain,
                            prodname_ms = 'precipitation__ms002')

  flux_sites <- generics::intersect(
    fname_from_fpath(qfiles, include_fext = FALSE),
    fname_from_fpath(chemfiles, include_fext = FALSE))

  for(s in flux_sites){

    flux <- sw(calc_inst_flux(chemprod = 'precip_chemistry__DP1.00013',
                              qprod = 'precipitation__ms002',
                              site_name = s))

    if(!is.null(flux)) {

      write_ms_file(d = flux,
                    network = network,
                    domain = domain,
                    prodname_ms = prodname_ms,
                    site_name = s,
                    level = 'derived',
                    shapefile = FALSE)
    }
  }
}
