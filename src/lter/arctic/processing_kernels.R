source('src/lter/arctic/domain_helpers.R', local=TRUE)

#retrieval kernels ####

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_10601 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_20118 <- retrieve_arctic

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_10303 <- retrieve_arctic

#precipitation: STATUS=READY
#. handle_errors
process_0_1489 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_20120 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1593 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1594 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1595 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1596 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1597 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1598 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1599 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1600 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1601 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1589 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1590 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1591 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1592 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1645 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1644 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_1646 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_10069 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_10068 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_10070 <- retrieve_arctic

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_0_10591 <- retrieve_arctic

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_20103 <- retrieve_arctic

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_20111 <- retrieve_arctic

#stream_chemistry: STATUS=READY
#. handle_errors
process_0_20112 <- retrieve_arctic

#munge kernels ####

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_10601 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character')

    d <- d[4:nrow(d),]

    if(prodname_ms == 'discharge__10601'){

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date' = '%Y-%m-%d',
                                                  'Time' = '%H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'River',
                             alt_site_name = list('Oksrukuyik_Creek' = c('Oksrukuyik Creek',
                                                                         'Oksrukuyik Creek ')),
                             data_cols = c('Discharge..m3.sec.' = 'discharge'),
                             is_sensor = TRUE,
                             set_to_NA = c('-1111', ''),
                             data_col_pattern = '#V#')

        d <- ms_cast_and_reflag(d,
                                varflag_col_pattern = NA)

        d <- d %>%
            mutate(val = val*1000)
    } else{

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date' = '%Y-%m-%d',
                                                  'Time' = '%H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'River',
                             alt_site_name = list('Oksrukuyik_Creek' = c('Oksrukuyik Creek',
                                                                         'Oksrukuyik Creek ')),
                             data_cols = c('Temperature..degree.C.' = 'temp'),
                             is_sensor = TRUE,
                             set_to_NA = c('-1111', ''),
                             data_col_pattern = '#V#')

        d <- ms_cast_and_reflag(d,
                                varflag_col_pattern = NA)

    }

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_20118 <- function(network, domain, prodname_ms, site_name,
                            component){

  rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                  n = network,
                  d = domain,
                  p = prodname_ms,
                  s = site_name,
                  c = component)

  d <- read.csv(rawfile, colClasses = 'character') %>%
      mutate(River = 'Kuparuk_River')

  d <- d[4:nrow(d),]

  if(prodname_ms == 'discharge__20118'){

      d <- ms_read_raw_csv(preprocessed_tibble = d,
                           datetime_cols = list('Date' = '%Y-%m-%d',
                                                'Time' = '%H:%M'),
                           datetime_tz = 'America/Anchorage',
                           site_name_col = 'River',
                           data_cols = c('Discharge..m3.sec.' = 'discharge'),
                           is_sensor = TRUE,
                           set_to_NA = c('-1111', ''),
                           data_col_pattern = '#V#')

      d <- ms_cast_and_reflag(d,
                              varflag_col_pattern = NA)

      d <- d %>%
          mutate(val = val*1000)

  } else{

      d <- d %>%
          rename(temperature = 8)

      d <- ms_read_raw_csv(preprocessed_tibble = d,
                           datetime_cols = list('Date' = '%Y-%m-%d',
                                                'Time' = '%H:%M'),
                           datetime_tz = 'America/Anchorage',
                           site_name_col = 'River',
                           data_cols = c('temperature' = 'temp'),
                           is_sensor = TRUE,
                           set_to_NA = c('-1111', ''),
                           data_col_pattern = '#V#')

      d <- ms_cast_and_reflag(d,
                              varflag_col_pattern = NA)

  }

  d <- carry_uncertainty(d,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms)

  d <- synchronize_timestep(d)

  d <- apply_detection_limit_t(d, network, domain, prodname_ms)

  return(d)
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_1_10303 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character') %>%
        as_tibble()

    #TODO: this product changed file formats around jan 2021. the kernel still works
    #if we just comment this next line, but it could probably stand a thorough
    #check (for new flag values, etc)

    # d <- d[4:nrow(d),]

    check <- d %>%
        group_by(River, Station) %>%
        summarise(count = n())

    sites_lots <- check %>%
        ungroup() %>%
        filter(count >= 300) %>%
        mutate(River = str_replace_all(River, ' ', '_')) %>%
        mutate(site_name = paste(River, Station, sep = '_')) %>%
        select(site_name)

    d <- d %>%
        mutate(site_name = paste(River, Station, sep = '_')) %>%
        mutate(site_name = str_replace_all(site_name, ' ', '_')) %>%
        mutate(site_name = case_when(site_name == 'Oksrukuyik_Creek_Wolf_Creek' ~ 'Wolf_Creek',
                                     site_name == 'Kuparuk_River_Hershey_Creek' ~ 'Hershey_Creek',
                                     TRUE ~ site_name)) %>%
        select(-River) %>%
        right_join(., sites_lots, by = 'site_name')

    na_vec <- vector('character', 64)

    na_vec <- replace(na_vec, values = NA)

    #Sestonic Chlorophyll a same as regular Chlorophyll A?
    #Sestonic Particulate Carbon same as total particulate carbon?
    #Sestonic Particulate Nitrogen same as total particulate nitrogen?
    #Sestonic Particulate Phosphorus same as total particulate P?
    #Ommited Loss on Ignition but can always add back in

    arctic_var_names <- c("Alkalinity", "Ammonium", "Carbon Dioxide", "Cations: Calcium",
                          "Cations: Magnesium","Cations: Potassium",
      "Cations: Sodium", "Chloride", "Dissolved Inorganic Carbon", "Dissolved Organic Carbon",
      "Nitrate+Nitrite", "Sestonic Chlorophyll a", "Sestonic Particulate Carbon",
      "Sestonic Particulate Nitrogen", "Sestonic Particulate Phosphorus",
      "Sestonic Phaeopigment", "Silica", "Soluble Reactive Phosphorus", "Sulfate",
      "Total Dissolved Nitrogen",  "Total Dissolved Phosphorus", "Cations: Aluminum",
      "Cations: Boron", "Cations: Cadmium", "Cations: Chromium", "Cations: Copper", "Cations: Iron",
      "Cations: Lead", "Cations: Manganese","Cations: Nickel", "Cations: Silicon",
      "Cations: Strontium", "Cations: Sulfur", "Cations: Zinc", "Conductivity",
      "Loss on Ignition", "pH", "Sestonic Phaeophytin", "Sestonic Total Chlorophyll",
      "Specific Conductivity", "Temp when sample collected", "Total Suspended Sediment",
      "Benthic Ash Free Dry Mass", "Benthic Particulate Carbon", "Benthic Particulate Nitrogen",
      "Benthic Particulate Phosphorus", "Epilithic Chlorophyll a", "Epilithic Phaeophytin",
      "Epilithic Total Chlorophyll", "Moss: Hygrohypnum: Aluminum", "Moss: Hygrohypnum: Boron",
      "Moss: Hygrohypnum: Calcium", "Moss: Hygrohypnum: Carbon", "Moss: Hygrohypnum: Copper",
      "Moss: Hygrohypnum: Iron", "Moss: Hygrohypnum: Magnesium", "Moss: Hygrohypnum: Manganese",
      "Moss: Hygrohypnum: Nitrogen", "Moss: Hygrohypnum: Phosphorus", "Moss: Hygrohypnum: Potassium",
      "Moss: Hygrohypnum: Sodium", "Moss: Hygrohypnum: Sulfur", "Moss: Hygrohypnum: Znnc",
      "Moss: Schistidium: Aluminum", "Moss: Schistidium: Boron", "Moss: Schistidium: Calcium",
      "Moss: Schistidium: Carbon", "Moss: Schistidium: Copper", "Moss: Schistidium: Iron",
      "Moss: Schistidium: LOI", "Moss: Schistidium: Magnesium", "Moss: Schistidium: Manganese",
      "Moss: Schistidium: Nitrogen", "Moss: Schistidium: Phosphorus","Moss: Schistidium: Potassium",
      "Moss: Schistidium: Sodium", "Moss: Schistidium: Sulfur", "Moss: Schistidium: Zinc",
      "Moss: Hygrohypnum: LOI", "Moss: Fontinalis: LOI", "Moss: Fontinalis: Nitrogen",
      "Moss: Fontinalis: Phosphorus", "Moss: Lemanea: Aluminum", "Moss: Lemanea: Boron",
      "Moss: Lemanea: Calcium", "Moss: Lemanea: Carbon", "Moss: Lemanea: Copper",
      "Moss: Lemanea: Iron", "Moss: Lemanea: LOI", "Moss: Lemanea: Magnesium",
      "Moss: Lemanea: Manganese", "Moss: Lemanea: Nitrogen", "Moss: Lemanea: Phosphorus",
      "Moss: Lemanea: Potassium", "Moss: Lemanea: Sodium", "Moss: Lemanea: Sulfur" ,
      "Moss: Lemanea: Zinc", "Moss: Liverwort: Aluminum", "Moss: Liverwort: Boron",
      "Moss: Liverwort: Calcium", "Moss: Liverwort: Carbon", "Moss: Liverwort: Copper",
      "Moss: Liverwort: Iron", "Moss: Liverwort: LOI", "Moss: Liverwort: Magnesium",
      "Moss: Liverwort: Manganese", "Moss: Liverwort: Nitrogen", "Moss: Liverwort: Phosphorus",
      "Moss: Liverwort: Potassium", "Moss: Liverwort: Sodium", "Moss: Liverwort: Sulfur",
      "Moss: Liverwort: Zinc", "Moss: Fontinalis: Carbon", "Epilithic Phaeopigment", "Methane")

    var_names <- tibble(Type = arctic_var_names,
                        var = c('alk', 'NH4', 'CO2', 'Ca', 'Mg', 'K', 'Na', 'Cl',
                                'DIC', 'DOC', 'NO3_NO2', 'CHL', 'TPC', 'TPN', 'TPP',
                                'phaeopig', 'SiO2', 'SRP', 'SO4', 'TDN', 'TDP', 'Al',
                                'B', 'Cd', 'Cr', 'Cu', 'Fe', 'Pb', 'Mn', 'Ni', 'Si',
                                'Sr', 'S', 'Zn', 'spCond', NA, 'pH', 'pheophy', 'TCHL',
                                'spCond', 'temp', 'TSS', NA, 'BPC', 'BPN', 'BPP',
                                'ECHL_A', 'E_pheophy', 'T_ECHL', 'MH_Al', 'MH_B', 'MH_Ca',
                                'MH_C', 'MH_Cu',  'MH_Fe', 'MH_Mg', 'MH_Mn', 'MH_N',
                                'MH_P', 'MH_K', 'MH_Na', 'MH_S', 'MH_Zn', 'MS_Al',
                                'MS_B', 'MS_Ca', 'MS_C', 'MS_Cu', 'MS_Fe', NA,
                                'MS_Mg', 'MS_Mn', 'MS_N', 'MS_P', 'MS_K', 'MS_Na',
                                'MS_S', 'MS_Zn', NA, NA, 'MF_N', 'MF_P',
                                'ML_Al', 'ML_B', 'ML_Ca', 'ML_C', 'ML_Cu', 'ML_Fe',
                                NA, 'ML_Mg', 'ML_Mn', 'ML_N', 'ML_P', 'ML_K',
                                'ML_Na', 'ML_S', 'ML_Zn', 'MLW_Al', 'MLW_B', 'MLW_Ca',
                                'MLW_C', 'MLW_Cu', 'MLW_Fe', NA, 'MLW_Mg', 'MLW_Mn',
                                'MLW_N', 'MLW_P', 'MLW_K', 'MLW_Na', 'MLW_S', 'MLW_Zn',
                                'MF_C', NA, 'CH4'))

    d[d == '-9999'] <- NA

    d <- d %>%
        full_join(var_names, by = 'Type') %>%
        select(site_name, datetime=Date, val=Value, Comments, var) %>%
        mutate(ms_status = case_when(Comments == 'ISCO' ~ 0,
                                     Comments == ' ' ~ 0,
                                     TRUE ~ 1)) %>%
        select(-Comments) %>%
        mutate(date = str_split_fixed(datetime, ' ', n = Inf)[,1]) %>%
        # mutate(time = str_split_fixed(datetime, ' ', n = Inf)[,2]) %>%
        # mutate(time = ifelse(time == '00:00', '12:00', time)) %>%
        #mutate(datetime = as_datetime(paste(date, time, sep = ' '), format = '%Y-%m-%d %H:%M', tz = 'America/Anchorage')) %>%
        mutate(val = as.numeric(val)) %>%
        filter(!is.na(val),
               !is.na(var)) %>%
        select(-date) %>%
        mutate(datetime = with_tz(datetime, 'UTC')) %>%
        group_by(site_name, datetime, var) %>%
        summarise(val = mean(val, na.rm = TRUE),
                  ms_status = max(ms_status, na.rm = TRUE)) %>%
        ungroup() %>%
      #Temporarily removing alk, the alk in ms_vars is in units of mg/l but
      #here it is reported in eq, not sure how to convert the two
        filter(var != 'alk')

    d <- identify_sampling_bypass(df = d,
                                  is_sensor =  FALSE,
                                  domain = domain,
                                  network = network,
                                  prodname_ms = prodname_ms)

    d <- ms_conversions(d,
                        convert_units_from = c(NH4 = 'umol/l',
                                               CO2 = 'umol/l',
                                               Ca = 'umol/l',
                                               Mg = 'umol/l',
                                               K = 'umol/l',
                                               Na = 'umol/l',
                                               Cl = 'umol/l',
                                               DIC = 'umol/l',
                                               DOC = 'umol/l',
                                               NO3_NO2 = 'umol/l',
                                               CHL = 'ug/l',
                                               TPC = 'ug/l',
                                               TPN = 'ug/l',
                                               TPP = 'ug/l',
                                               phaeopig = 'ug/l',
                                               SiO2 = 'umol/l',
                                               SRP = 'umol/l',
                                               SO4 = 'umol/l',
                                               TDN = 'umol/l',
                                               TDP = 'umol/l',
                                               Al = 'umol/l',
                                               B = 'umol/l',
                                               Cd = 'umol/l',
                                               Cr = 'umol/l',
                                               Cu = 'umol/l',
                                               Fe = 'umol/l',
                                               Pb = 'umol/l',
                                               Mn = 'umol/l',
                                               Ni = 'umol/l',
                                               Si = 'umol/l',
                                               Sr = 'umol/l',
                                               S = 'umol/l',
                                               Zn = 'umol/l',
                                               pheophy = 'ug/l',
                                               TCHL = 'ug/l',
                                               BPC = 'ug/cm2',
                                               BPN = 'ug/cm2',
                                               BPP = 'ug/cm2',
                                               ECHL_A = 'ug/cm2',
                                               E_pheophy = 'ug/cm2',
                                               T_ECHL = 'ug/cm2',
                                               CH4 = 'umol/l'),
                        convert_units_to = c(NH4 = 'mg/l',
                                             CO2 = 'mg/l',
                                             Ca = 'mg/l',
                                             Mg = 'mg/l',
                                             K = 'mg/l',
                                             Na = 'mg/l',
                                             Cl = 'mg/l',
                                             DIC = 'mg/l',
                                             DOC = 'mg/l',
                                             NO3_NO2 = 'mg/l',
                                             CHL = 'mg/l',
                                             TPC = 'mg/l',
                                             TPN = 'mg/l',
                                             TPP = 'mg/l',
                                             phaeopig = 'mg/l',
                                             SiO2 = 'mg/l',
                                             SRP = 'mg/l',
                                             SO4 = 'mg/l',
                                             TDN = 'mg/l',
                                             TDP = 'mg/l',
                                             Al = 'mg/l',
                                             B = 'mg/l',
                                             Cd = 'mg/l',
                                             Cr = 'mg/l',
                                             Cu = 'mg/l',
                                             Fe = 'mg/l',
                                             Pb = 'mg/l',
                                             Mn = 'mg/l',
                                             Ni = 'mg/l',
                                             Si = 'mg/l',
                                             Sr = 'mg/l',
                                             S = 'mg/l',
                                             Zn = 'mg/l',
                                             pheophy = 'mg/l',
                                             TCHL = 'mg/l',
                                             BPC = 'mg/cm2',
                                             BPN = 'mg/cm2',
                                             BPP = 'mg/cm2',
                                             ECHL_A = 'mg/cm2',
                                             E_pheophy = 'mg/cm2',
                                             T_ECHL = 'mg/cm2',
                                             CH4 = 'mg/l'))
    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    remove_1_vars <- d %>%
        group_by(site_name, var) %>%
        summarise(n = n()) %>%
        filter(n == 1) %>%
        select(-n) %>%
        mutate(remove = 1)

    d <- d %>%
        left_join(., remove_1_vars, by = c('site_name', 'var')) %>%
        filter(is.na(remove)) %>%
        select(-remove)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#precipitation: STATUS=READY
#. handle_errors
process_1_1489 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- ms_read_raw_csv(filepath = rawfile,
                         datetime_cols = list('Date' = '%Y%m%d'),
                         datetime_tz = 'America/Anchorage',
                         site_name_col = 'Station',
                         data_cols = c('Daily_Precip_Total_mm' = 'precipitation'),
                         is_sensor = TRUE,
                         set_to_NA = '#N/A',
                         data_col_pattern = '#V#',
                         summary_flagcols = 'Flag_Daily_Precip_Total_mm')

    d <- ms_cast_and_reflag(d,
                            summary_flags_clean = list('Flag_Daily_Precip_Total_mm' = ''),
                            summary_flags_dirty = list('Flag_Daily_Precip_Total_mm' = 'E'),
                            varflag_col_pattern = NA)

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_20120 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character') %>%
      rename(temp = 7)

    d <- d[4:nrow(d),]

    if(prodname_ms == 'discharge__20120'){

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date' = '%Y-%m-%d',
                                                  'Time' = '%H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'River',
                             data_cols = c('Discharge..m3.sec.' = 'discharge'),
                             is_sensor = TRUE,
                             alt_site_name = list('Roche_Moutonnee_Creek_Main' = 'Roche Moutonnee Creek',
                                                  'Trevor_Creek_Main' = 'Trevor Creek'),
                             set_to_NA = c('-9999', '-1111'),
                             data_col_pattern = '#V#',
                             summary_flagcols = 'Comments')

        d <- ms_cast_and_reflag(d,
                                summary_flags_clean = list('Comments' = ''),
                                summary_flags_dirty = list('Comments' = c('Late season staff gauge',
                                                                          'WINTER')),
                                varflag_col_pattern = NA)

        d <- d %>%
          mutate(val = val*1000)

    } else{

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date' = '%Y-%m-%d',
                                                  'Time' = '%H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'River',
                             data_cols = 'temp',
                             is_sensor = TRUE,
                             alt_site_name = list('Roche_Moutonnee_Creek_Main' = 'Roche Moutonnee Creek',
                                                  'Trevor_Creek_Main' = 'Trevor Creek'),
                             set_to_NA = c('-9999', '-1111'),
                             data_col_pattern = '#V#',
                             summary_flagcols = 'Comments')

        d <- ms_cast_and_reflag(d,
                                summary_flags_clean = list('Comments' = ''),
                                summary_flags_dirty = list('Comments' = c('Late season staff gauge',
                                                                          'WINTER')),
                                varflag_col_pattern = NA)
    }

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1593 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1594 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1595 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1596 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1597 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1598 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1599 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1600 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1601 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1589 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1590 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1591 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1592 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1645 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1644 <- munge_toolik_2

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_1646 <- munge_toolik_2

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_10069 <- munge_toolik_2

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_10068 <- munge_toolik_2

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_10070 <- munge_toolik

#discharge; stream_chemistry: STATUS=READY
#. handle_errors
process_1_10591 <- function(network, domain, prodname_ms, site_name,
                                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character') %>%
        mutate(site_name = 'Toolik_Inlet_Main') %>%
        rename(Date_Time = 1)

    d <- d[4:nrow(d),]

    if(grepl('discharge', prodname_ms)){

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date_Time' = '%y-%m-%d %H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'site_name',
                             data_cols =  c('Q_m3sec' = 'discharge'),
                             data_col_pattern = '#V#',
                             set_to_NA = c('-1111', '-1.111'),
                             is_sensor = TRUE)

        d <- ms_cast_and_reflag(d,
                                varflag_col_pattern = NA,
                                variable_flags_to_drop = NA,
                                variable_flags_clean = NA)

        # Convert from cm/s to liters/s
        d <- d %>%
          mutate(val = val*1000)

    } else{

        d <- ms_read_raw_csv(preprocessed_tibble = d,
                             datetime_cols = list('Date_Time' = '%y-%m-%d %H:%M'),
                             datetime_tz = 'America/Anchorage',
                             site_name_col = 'site_name',
                             data_cols =  c('Water_Temp_C' = 'temp',
                                            'Conductivity_uScm' = 'spCond'),
                             data_col_pattern = '#V#',
                             set_to_NA = c('-1111', '-1.111', '-9999'),
                             is_sensor = TRUE)

        d <- ms_cast_and_reflag(d,
                                varflag_col_pattern = NA,
                                variable_flags_to_drop = NA,
                                variable_flags_clean = NA)
    }

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#stream_chemistry: STATUS=PENDING
#. handle_errors
process_1_20103 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    #STill need to identify which site exactly
    d <- read.csv(rawfile, colClasses = 'character') %>%
      mutate(site_name = 'Kuparuk_River') %>%
      rename(date = 1)

    d <- d[4:nrow(d),]

    #Incorectly identifying installed as grab
    d <- ms_read_raw_csv(preprocessed_tibble = d,
                         datetime_cols = list('date' = '%y-%m-%d %H:%M'),
                         datetime_tz = 'America/Anchorage',
                         site_name_col = 'site_name',
                         data_cols =  c('Nitrate..mg.L.' = 'NO3',
                                        'DOC..mg.L.' = 'DOC'),
                         data_col_pattern = '#V#',
                         set_to_NA = c('-1111', '-1.111', '-9999'),
                         is_sensor = TRUE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA,
                            variable_flags_to_drop = NA,
                            variable_flags_clean = NA)

    d <- ms_conversions(d,
                        convert_units_from = c('NO3' = 'mg/l'),
                        convert_units_to = c('NO3' = 'mg/l'))

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}


#stream_chemistry: STATUS=READY
#. handle_errors
process_1_20111 <- function(network, domain, prodname_ms, site_name,
                            component){

    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character') %>%
        mutate(site_name = 'Oksrukuyik_Creek_-0.1') %>%
        rename(date = 1)

    d <- d[4:nrow(d),]

    #Incorectly identifying installed as grab
    d <- ms_read_raw_csv(preprocessed_tibble = d,
                         datetime_cols = list('date' = '%y-%m-%d %H:%M'),
                         datetime_tz = 'America/Anchorage',
                         site_name_col = 'site_name',
                         data_cols =  c('Nitrate..mg.L.' = 'NO3',
                                        'DOC..mg.L.' = 'DOC'),
                         data_col_pattern = '#V#',
                         set_to_NA = c('-1111', '-1.111', '-9999'),
                         is_sensor = TRUE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA,
                            variable_flags_to_drop = NA,
                            variable_flags_clean = NA)

    d <- ms_conversions(d,
                        convert_units_from = c('NO3' = 'mg/l'),
                        convert_units_to = c('NO3' = 'mg/l'))

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}


#stream_chemistry: STATUS=READY
#. handle_errors
process_1_20112 <- function(network, domain, prodname_ms, site_name,
                            component){


    rawfile <- glue('data/{n}/{d}/raw/{p}/{s}/{c}.csv',
                    n = network,
                    d = domain,
                    p = prodname_ms,
                    s = site_name,
                    c = component)

    d <- read.csv(rawfile, colClasses = 'character') %>%
      mutate(site_name = 'Trevor_Creek_Main') %>%
      rename(date = 1)

    d <- d[4:nrow(d),]

    #Incorectly identifying installed as grab
    d <- ms_read_raw_csv(preprocessed_tibble = d,
                         datetime_cols = list('date' = '%y-%m-%d %H:%M'),
                         datetime_tz = 'America/Anchorage',
                         site_name_col = 'site_name',
                         data_cols =  c('Nitrate..mg.L.' = 'NO3',
                                        'DOC..mg.L.' = 'DOC'),
                         data_col_pattern = '#V#',
                         set_to_NA = c('-1111', '-1.111', '-9999'),
                         is_sensor = TRUE)

    d <- ms_cast_and_reflag(d,
                            varflag_col_pattern = NA,
                            variable_flags_to_drop = NA,
                            variable_flags_clean = NA)

    d <- ms_conversions(d,
                        convert_units_from = c('NO3' = 'mg/l'),
                        convert_units_to = c('NO3' = 'mg/l'))

    d <- carry_uncertainty(d,
                           network = network,
                           domain = domain,
                           prodname_ms = prodname_ms)

    d <- synchronize_timestep(d)

    d <- apply_detection_limit_t(d, network, domain, prodname_ms)

    return(d)
}

#derive kernels ####

#discharge: STATUS=READY
#. handle_errors
process_2_ms001 <- function(network, domain, prodname_ms) {

    combine_products(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     input_prodname_ms = c('discharge__10068', 'discharge__10069',
                                           'discharge__10070', 'discharge__10591',
                                           'discharge__10601', 'discharge__1589',
                                           'discharge__1590', 'discharge__1591',
                                           'discharge__1592', 'discharge__1593',
                                           'discharge__1594', 'discharge__1595',
                                           'discharge__1596', 'discharge__1597',
                                           'discharge__1598', 'discharge__1599',
                                           'discharge__1600', 'discharge__1601',
                                           'discharge__1644', 'discharge__1645',
                                           'discharge__1646', 'discharge__20118',
                                           'discharge__20120'))

    # Becasue arctic lter only records Q at one location on two streams but
    # samples 5 km up and down stream of where Q is measured, we are associated
    # Q at that one site with all smapling points within 5km up and down stream
    q_assoc_sites <- site_data %>%
        filter(domain == 'arctic') %>%
        filter(stream %in% c('Oksrukuyik Creek', 'Kuparuk River')) %>%
        pull(site_name)

    for(s in 1:length(q_assoc_sites)){

        site_name <- q_assoc_sites[s]

        q_stream <- paste(str_split_fixed(site_name, '_', n = Inf)[1,1:2], collapse = '_')

        dir <- 'data/lter/arctic/derived/discharge__ms001'
        og_file_name <- paste0(dir, '/', q_stream, '.feather')
        new_file_name <- paste0(dir, '/', site_name, '.feather')

        site_q_file <- read_feather(og_file_name) %>%
            mutate(site_name = !!q_assoc_sites[s])

        write_feather(site_q_file, new_file_name)
    }

  return()
}

#stream_chemistry: STATUS=READY
#. handle_errors
process_2_ms002 <- function(network, domain, prodname_ms) {

    combine_products(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     input_prodname_ms = c('stream_chemistry__10068', 'stream_chemistry__10069',
                                           'stream_chemistry__10070', 'stream_chemistry__10591',
                                           'stream_chemistry__10601', 'stream_chemistry__1589',
                                           'stream_chemistry__1590', 'stream_chemistry__1591',
                                           'stream_chemistry__1592', 'stream_chemistry__1593',
                                           'stream_chemistry__1594', 'stream_chemistry__1595',
                                           'stream_chemistry__1596', 'stream_chemistry__1597',
                                           'stream_chemistry__1598', 'stream_chemistry__1599',
                                           'stream_chemistry__1600', 'stream_chemistry__1601',
                                           'stream_chemistry__1644', 'stream_chemistry__1645',
                                           'stream_chemistry__1646', 'stream_chemistry__20118',
                                           'stream_chemistry__20120', 'stream_chemistry__10303'))

    return()
}

#precip_gauge_locations: STATUS=READY
#. handle_errors
process_2_ms003 <- precip_gauge_from_site_data

#stream_gauge_locations: STATUS=READY
#. handle_errors
process_2_ms004 <- stream_gauge_from_site_data

#stream_flux_inst: STATUS=READY
#. handle_errors
process_2_ms005 <- derive_stream_flux

#precipitation: STATUS=READY
#. handle_errors
process_2_ms006 <- function(network, domain, prodname_ms) {

    #Temporary, arctic only has 1 precip gauge. Eventuly will
    #leverage other data to interploate but for now directly linking gauge to
    #watersheds (similar to neon)

    new_dir <- 'data/lter/arctic/derived/precipitation__ms006/'
    dir.create(new_dir, recursive = TRUE)

    dir <- 'data/lter/arctic/derived/discharge__ms001/'

    site_files <- list.files(dir)

    sites <- unique(str_split_fixed(site_files, '.feather', n = Inf)[,1])

    for(i in 1:length(sites)) {

        precip <- read_feather('data/lter/arctic/munged/precipitation__1489/TLKMAIN.feather') %>%
            mutate(site_name == !! sites[i])

      write_feather(precip, glue('{n}{s}.feather',
                                 n = new_dir,
                                 s = sites[i]))

    }

    return()
}
