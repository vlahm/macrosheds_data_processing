
#npp_CONUS_250m: STATUS=READY
#. handle_errors
process_3_ms805 <- function(network, domain, prodname_ms, site_code, boundaries){

    warning('original CONUS npp (250m) and gpp (30m) kernels might have internal naming issues now. untested since 9/24 modification. note that gpp func has more transformations')
    npp <- try(get_gee_standard(network = network,
                                domain = domain,
                                gee_id = 'UMT/NTSG/v2/LANDSAT/NPP',
                                band = 'annualNPP',
                                prodname = 'npp_CONUS_250m',
                                rez = 30,
                                site_boundary = boundaries,
                                contiguous_us = TRUE))

    if(is.null(npp)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(npp, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    npp <- npp$table %>%
        mutate(datetime = as.numeric(substr(datetime, 0, 4)),
               val = val * 0.0001) %>% #scale factor of gee product
        select(year = datetime, site_code, var, val)

    if(all(is.na(npp$val))){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    npp <- append_unprod_prefix(npp, prodname_ms)
    npp <- bind_older_ws_traits(npp)

    save_general_files(final_file = npp,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/npp_CONUS_250m/'))

    return()
}

#gpp_CONUS_30m: STATUS=READY
#. handle_errors
process_3_ms806 <- function(network, domain, prodname_ms, site_code, boundaries){

    gpp <- try(get_gee_standard(network = network,
                                domain = domain,
                                gee_id = 'UMT/NTSG/v2/LANDSAT/GPP',
                                band = 'GPP',
                                prodname = 'gpp_CONUS_30m',
                                rez = 30,
                                site_boundary = boundaries,
                                contiguous_us = TRUE))

    if(is.null(gpp)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(gpp, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    gpp <- gpp$table %>%
        mutate(year = substr(datetime, 1, 4),
               doy = substr(datetime, 5, 7),
               date_ = ymd(paste(year, '01', '01', sep = '-')),
               datetime = as.Date(as.numeric(doy), format = '%j', origin = date_),
               year = as.numeric(year),
               val = val * 0.0001) %>% #scale factor of gee product
        select(site_code, datetime, year, var, val) %>%
        filter(! is.na(val))

    if(all(gpp$val == 0) || all(is.na(gpp$val))){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    gpp_sum <- gpp %>%
        filter(var == 'gpp_CONUS_30m_median') %>%
        group_by(site_code, year, var) %>%
        summarize(val = sum(val, na.rm = TRUE),
                  count = n(),
                  .groups = 'drop') %>%
        mutate(val = (val / (count * 16)) * 365) %>%
        mutate(var = 'gpp_CONUS_30m_sum') %>%
        select(-count)

    gpp_sd_year <- gpp %>%
        filter(var == 'gpp_CONUS_30m_median') %>%
        group_by(site_code, year, var) %>%
        summarize(val = sd(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = 'gpp_CONUS_30m_sd_year')

    gpp_sd <- gpp %>%
        filter(var == 'gpp_CONUS_30m_sd') %>%
        group_by(site_code, year, var) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = 'gpp_CONUS_30m_sd_space')

    gpp_final <- rbind(gpp_sum, gpp_sd_year, gpp_sd) %>%
        select(year, site_code, var, val)

    gpp_raw <- gpp %>%
        select(datetime, site_code, var, val)

    gpp_final <- append_unprod_prefix(gpp_final, prodname_ms)
    gpp_raw <- append_unprod_prefix(gpp_raw, prodname_ms)

    gpp_final <- bind_older_ws_traits(gpp_final)
    gpp_raw <- bind_older_ws_traits(gpp_raw)

    save_general_files(final_file = gpp_final,
                       raw_file = gpp_raw,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/gpp_CONUS_30m/'))

    return()
}

#gpp_global_500m; npp_global_500m: STATUS=READY
#. handle_errors
process_3_ms826 <- function(network, domain, prodname_ms, site_code, boundaries){

    prodname <- prodname_from_prodname_ms(prodname_ms)
    pp <- try(get_gee_standard(network = network,
                               domain = domain,
                               gee_id = 'MODIS/061/MOD17A3HGF',
                               band = paste0(toupper(substr(prodname, 1, 1)), 'pp'),
                               prodname = prodname,
                               rez = 500,
                               site_boundary = boundaries,
                               contiguous_us = TRUE))

    if(is.null(pp)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(pp, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    pp <- pp$table %>%
        mutate(year = as.numeric(substr(datetime, 1, 4)),
               datetime = as.Date(gsub('_', '-', datetime)))%>%
        select(site_code, datetime, year, var, val) %>%
        filter(! is.na(val))

    if(all(pp$val == 0) || all(is.na(pp$val))){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    pp_sum <- pp %>%
        filter(var == paste0(prodname, '_median'))

    pp_sd <- pp %>%
        filter(var == paste0(prodname, '_sd'))

    pp_final <- bind_rows(pp_sum, pp_sd) %>%
        select(year, site_code, var, val)

    pp_raw <- pp %>%
        select(datetime, site_code, var, val)

    pp_final <- append_unprod_prefix(pp_final, prodname_ms)
    pp_raw <- append_unprod_prefix(pp_raw, prodname_ms)

    pp_final <- bind_older_ws_traits(pp_final)
    pp_raw <- bind_older_ws_traits(pp_raw)

    save_general_files(final_file = pp_final,
                       raw_file = pp_raw,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/{prodname}/'))

    return()
}

#lai; fpar: STATUS=READY
#. handle_errors
process_3_ms807 <- function(network, domain, prodname_ms, site_code, boundaries){

    if(grepl('lai', prodname_ms)){

        lai <- try(get_gee_standard(network = network,
                                    domain = domain,
                                    gee_id = 'MODIS/006/MOD15A2H',
                                    band = 'Lai_500m',
                                    prodname = 'lai',
                                    rez = 500,
                                    site_boundary = boundaries,
                                    qa_band = 'FparLai_QC',
                                    bit_mask = '1',
                                    batch = TRUE))

        if(is.null(lai)){
            return(generate_ms_err(glue('No data were retrived for {site_code}')))
        }

        if(inherits(lai, 'try-error')){
            return(generate_ms_err(glue('error in retrieving {site_code}')))
        }

        lai <- lai$table %>%
            mutate(year = as.numeric(substr(datetime, 1, 4))) %>%
            mutate(datetime = ymd(datetime),
                   val = val * 0.1) %>% #scale factor of gee product
            select(site_code, datetime, year, var, val)

        if(all(lai$val == 0) || all(is.na(lai$val))){
            return(generate_ms_exception(glue('No data were retrived for {site_code}')))
        }

        lai_means <- lai %>%
            filter(var == 'lai_median') %>%
            group_by(site_code, year) %>%
            summarize(lai_max = max(val, na.rm = TRUE),
                      lai_min = min(val, na.rm = TRUE),
                      lai_mean = mean(val, na.rm = TRUE),
                      lai_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('lai_max', 'lai_min', 'lai_mean', 'lai_sd_year'),
                         names_to = 'var',
                         values_to = 'val')

        lai_sd <- lai %>%
            filter(var == 'lai_sd') %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'lai_sd_space')

        lai_final <- rbind(lai_means, lai_sd) %>%
            select(year, site_code, var, val)

        lai_raw <- lai %>%
            select(datetime, site_code, var, val)

        lai_final <- append_unprod_prefix(lai_final, prodname_ms)
        lai_raw <- append_unprod_prefix(lai_raw, prodname_ms)

        lai_final <- bind_older_ws_traits(lai_final)
        lai_raw <- bind_older_ws_traits(lai_raw)

        save_general_files(
            final_file = lai_final,
            raw_file = lai_raw,
            domain_dir = glue('data/{network}/{domain}/ws_traits/lai/')
        )
    }

    if(grepl('fpar', prodname_ms)){

        fpar <- try(get_gee_standard(network = network,
                                     domain = domain,
                                     gee_id = 'MODIS/006/MOD15A2H',
                                     band = 'Fpar_500m',
                                     prodname = 'fpar',
                                     rez = 500,
                                     site_boundary = boundaries,
                                     qa_band = 'FparLai_QC',
                                     bit_mask = '1',
                                     batch = TRUE))

        if(is.null(fpar)){
            return(generate_ms_exception(glue('No data were retrived for {site_code}')))
        }

        if(inherits(fpar, 'try-error')){
            return(generate_ms_err(glue('error in retrieving {site_code}')))
        }

        fpar <- fpar$table %>%
            mutate(year = as.numeric(substr(datetime, 1, 4))) %>%
            mutate(datetime = ymd(datetime),
                   val = val * 0.01) %>% #scale factor of gee product
            select(site_code, datetime, year, var, val)

        if(all(fpar$val == 0) || all(is.na(fpar$val))){
            return(generate_ms_exception(glue('No data were retrived for {site_code}')))
        }

        fpar_means <- fpar %>%
            filter(var == 'fpar_median') %>%
            group_by(site_code, year) %>%
            summarize(fpar_max = max(val, na.rm = TRUE),
                      fpar_min = min(val, na.rm = TRUE),
                      fpar_mean = mean(val, na.rm = TRUE),
                      fpar_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('fpar_max', 'fpar_min', 'fpar_mean', 'fpar_sd_year'),
                         names_to = 'var',
                         values_to = 'val')

        fpar_sd <- fpar %>%
            filter(var == 'fpar_sd') %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'fpar_sd_space')

        fpar_final <- rbind(fpar_means, fpar_sd) %>%
            select(year, site_code, var, val)

        fpar_raw <- fpar %>%
            select(datetime, site_code, val, var)

        fpar_final <- append_unprod_prefix(fpar_final, prodname_ms)
        fpar_raw <- append_unprod_prefix(fpar_raw, prodname_ms)

        fpar_final <- bind_older_ws_traits(fpar_final)
        fpar_raw <- bind_older_ws_traits(fpar_raw)

        save_general_files(
            final_file = fpar_final,
            raw_file = fpar_raw,
            domain_dir = glue('data/{network}/{domain}/ws_traits/fpar/')
        )

        return()
    }
}

#tree_cover; veg_cover; bare_cover: STATUS=READY
#. handle_errors
process_3_ms808 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    if(grepl('tree_cover', prodname_ms)) {
        var <- try(get_gee_standard(network = network,
                                    domain = domain,
                                    gee_id = 'MODIS/006/MOD44B',
                                    band = 'Percent_Tree_Cover',
                                    prodname = 'tree_cover',
                                    rez = 250,
                                    site_boundary = boundaries))
    }

    if(grepl('veg_cover', prodname_ms)) {
        var <- try(get_gee_standard(network=network,
                                    domain=domain,
                                    gee_id='MODIS/006/MOD44B',
                                    band='Percent_NonTree_Vegetation',
                                    prodname='veg_cover',
                                    rez=250,
                                    site_boundary=boundaries))
    }

    if(grepl('bare_cover', prodname_ms)) {
        var <- try(get_gee_standard(network=network,
                                    domain=domain,
                                    gee_id='MODIS/006/MOD44B',
                                    band='Percent_NonVegetated',
                                    prodname='bare_cover',
                                    rez=250,
                                    site_boundary=boundaries))
    }

    if(is.null(var)) {
        return(generate_ms_exception(glue('No data were retrived for {s}',
                                          s = site_code)))
    }

    if(class(var) == 'try-error'){
        return(generate_ms_err(glue('error in retrieving {s}',
                                    s = site_code)))
    }

    var <- var$table %>%
        mutate(datetime = ymd(datetime)) %>%
        mutate(year = year(datetime)) %>%
        select(site_code, datetime, year, val, var)

    type <- str_split_fixed(prodname_ms, '__', n = Inf)[,1]

    var_final <- var %>%
        select(site_code, year, var, val)

    var_final <- append_unprod_prefix(var_final, prodname_ms)

    dir <- glue('data/{n}/{d}/ws_traits/{v}/',
                n = network, d = domain, v = type)

    var_final <- bind_older_ws_traits(var_final)

    save_general_files(final_file = var_final,
                       domain_dir = dir)

    return()
}

#prism_precip; prism_temp: STATUS=READY
#. handle_errors
process_3_ms809 <- function(network, domain, prodname_ms, site_code, boundaries){

    if(grepl('prism_precip', prodname_ms)){
        final <- try(get_gee_standard(network = network,
                                      domain = domain,
                                      gee_id = 'OREGONSTATE/PRISM/AN81d',
                                      band = 'ppt',
                                      prodname = 'precip',
                                      rez = 4000,
                                      site_boundary = boundaries,
                                      batch = TRUE,
                                      contiguous_us = TRUE))
    }

    if(grepl('prism_temp_mean', prodname_ms)){
        final <- try(get_gee_standard(network = network,
                                      domain = domain,
                                      gee_id = 'OREGONSTATE/PRISM/AN81d',
                                      band = 'tmean',
                                      prodname = 'temp_mean',
                                      rez = 4000,
                                      site_boundary = boundaries,
                                      batch = TRUE,
                                      contiguous_us = TRUE))
    }

    if(is.null(final)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(final, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    final <- final$table %>%
        mutate(datetime = substr(datetime, 0, 8)) %>%
        mutate(datetime = ymd(datetime))

    if(all(is.na(final$val)) || all(final$val == 0)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(grepl('prism_precip', prodname_ms)){

        final_sum_c <- final %>%
            filter(var == 'precip_median') %>%
            mutate(year = year(datetime)) %>%
            group_by(site_code, year) %>%
            summarize(cumulative_precip = sum(val, na.rm = TRUE),
                      precip_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('cumulative_precip', 'precip_sd_year'),
                         names_to = 'var',
                         values_to = 'val') %>%
            filter(val > 0)

        final_sum_sd <- final %>%
            filter(var == 'precip_sd') %>%
            mutate(year = year(datetime)) %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'precip_sd_space')

        final_sum <- rbind(final_sum_c, final_sum_sd) %>%
            select(year, site_code, var, val)

    } else {

        final_temp <- final %>%
            filter(var == 'temp_mean_median') %>%
            mutate(year = year(datetime)) %>%
            group_by(site_code, year) %>%
            summarize(temp_mean = mean(val, na.rm = TRUE),
                      temp_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('temp_mean', 'temp_sd_year'),
                         names_to = 'var',
                         values_to = 'val')

        temp_sd <- final %>%
            filter(var == 'temp_mean_sd') %>%
            mutate(year = year(datetime)) %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'temp_sd_space')

        final_sum <- rbind(final_temp, temp_sd) %>%
            select(year, site_code, var, val)
    }

    final <- final %>%
        select(datetime, site_code, var, val)

    type <- str_split_fixed(prodname_ms, '__', n = Inf)[, 1]
    type <- ifelse(type == 'prism_precip', 'cc_precip', 'cc_temp')

    final <- append_unprod_prefix(final, prodname_ms)
    final_sum <- append_unprod_prefix(final_sum, prodname_ms)

    final <- bind_older_ws_traits(final)
    final_sum <- bind_older_ws_traits(final_sum)

    save_general_files(final_file = final_sum,
                       raw_file = final,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/{type}/'))

    return()
}

#start_season; end_season; max_season; season_length: STATUS=READY
#. handle_errors
process_3_ms810 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == sites[s])

        site <- sites[s]

        if(prodname_ms == 'start_season__ms810') {

            sm(get_phenology(network=network, domain=domain, prodname_ms=prodname_ms,
                             time='start_season', site_boundary=site_boundary,
                             site_code=site))

        }

        if(prodname_ms == 'max_season__ms810') {

            sm(get_phenology(network=network, domain=domain, prodname_ms=prodname_ms,
                             time='max_season', site_boundary=site_boundary,
                             site_code=site))

        }

        if(prodname_ms == 'end_season__ms810') {

            sm(get_phenology(network=network, domain=domain, prodname_ms=prodname_ms,
                             time='end_season', site_boundary=site_boundary,
                             site_code=site))
        }

        if(prodname_ms == 'season_length__ms810') {

            sm(get_phenology(network=network, domain=domain, prodname_ms=prodname_ms,
                             time='length_season', site_boundary=site_boundary,
                             site_code=site))
        }
    }

    return()
}

#terrain: STATUS=READY
#. handle_errors
process_3_ms811 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    dir.create(glue('data/{n}/{d}/ws_traits/terrain/',
                    n = network,
                    d = domain), recursive = TRUE)


    sites <- boundaries$site_code
    for(s in 1:length(sites)){
        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s])

        area <- as.numeric(sf::st_area(site_boundary)/1000000)

        z_level <- case_when(area > 50 ~ 8,
                             area >= 25 & area <= 50 ~ 12,
                             area < 25 ~ 14)

        dem <- elevatr::get_elev_raster(site_boundary, z = z_level)

        dem <- dem %>%
            terra::crop(., site_boundary) %>%
            terra::mask(., site_boundary)

        # Elevation
        elev_values <- terra::values(dem)
        elev_values <- elev_values[elev_values >= 0]
        elev_mean <- mean(elev_values, na.rm = TRUE)
        elev_sd <- sd(elev_values, na.rm = TRUE)
        elev_min <- min(elev_values, na.rm = TRUE)
        elev_max <- max(elev_values, na.rm = TRUE)

        # Slope
        dem_path <- tempfile(fileext = '.tif')
        terra::writeRaster(dem, dem_path)
        slope_path <- tempfile(fileext = '.tif')

        whitebox::wbt_slope(dem_path, slope_path)

        slope <- terra::rast(slope_path) %>%
            terra::crop(., terra::vect(site_boundary)) %>%
            terra::mask(., terra::vect(site_boundary))

        slope_values <- terra::values(slope)
        slope_mean <- mean(slope_values, na.rm = TRUE)
        slope_sd <- sd(slope_values, na.rm = TRUE)

        # Aspect
        aspect_path <- tempfile(fileext = '.tif')
        whitebox::wbt_aspect(dem_path, aspect_path)

        aspect <- terra::rast(aspect_path) %>%
            terra::crop(., terra::vect(site_boundary)) %>%
            terra::mask(., terra::vect(site_boundary))

        aspect_values <- terra::values(aspect)
        aspect_mean <- mean(aspect_values, na.rm = TRUE)
        aspect_sd <- sd(aspect_values, na.rm = TRUE)

        site_terrain <- tibble(year = NA,
                               site_code = sites[s],
                               var = c('slope_mean', 'slope_sd', 'elev_mean',
                                       'elev_sd', 'elev_min', 'elev_max',
                                       'aspect_mean', 'aspect_sd'),
                               val = c(slope_mean, slope_sd, elev_mean, elev_sd, elev_min,
                                       elev_max, aspect_mean, aspect_sd))

        site_terrain <- append_unprod_prefix(site_terrain, prodname_ms)

        write_feather(site_terrain, glue('data/{n}/{d}/ws_traits/terrain/{s}.feather',
                                         n = network,
                                         d = domain,
                                         s = sites[s]))

    }
}

#nrcs_soils: STATUS=READY
#. handle_errors
process_3_ms812 <- function(network, domain, prodname_ms, site_code, boundaries){

    dir.create(glue('data/{n}/{d}/ws_traits/nrcs_soils/',
                    n = network,
                    d = domain), recursive = TRUE)

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        # Soil Organic Matter
        soil_tib <- sm(get_nrcs_soils(network = network,
                                      domain = domain,
                                      nrcs_var_name = c(
                                          # percent
                                          'soil_org' = 'om_r',
                                          # percent
                                          'soil_sand' = 'sandtotal_r',
                                          # percent
                                          'soil_silt' = 'silttotal_r',
                                          # percent
                                          'soil_clay' = 'claytotal_r',
                                          # mass/volume
                                          # 'soil_partical_density' = 'partdensity',
                                          # micrometers per second
                                          # 'soil_ksat' = 'ksat_r',
                                          # centimeters of water per centimeter of soil,
                                          # quantity of water that the soil is capable
                                          # of storing for use by plants
                                          'soil_awc' = 'awc_r',
                                          # Water content, 1/10 bar, is the amount of soil
                                          # water retained at a tension of 15 bars, expressed
                                          # as a volumetric percentage of the whole
                                          # soil material.
                                          'soil_water_0.1bar' = 'wtenthbar_r',
                                          # Water content, 1/3 bar, is the amount of soil
                                          # water retained at a tension of 15 bars, expressed
                                          # as a volumetric percentage of the whole
                                          # soil material. 15 bar = wilting point
                                          'soil_water_0.33bar' = 'wthirdbar_r',
                                          # Water content, 15 bar, is the amount of soil
                                          # water retained at a tension of 15 bars, expressed
                                          # as a volumetric percentage of the whole
                                          # soil material. 15 bar = field capacity
                                          'soil_water_15bar' = 'wfifteenbar_r',
                                          # Water content, 0 bar, is the amount of soil
                                          # water retained at a tension of 15 bars, expressed
                                          # as a volumetric percentage of the whole
                                          # soil material.
                                          'soil_water_0bar' = 'wsatiated_r',
                                          # percent of carbonates, by weight, in the
                                          # fraction of the soil less than 2 millimeters
                                          # in size.
                                          # 'pf_soil_carbonate' = 'caco3_r',
                                          # percent, by weight hydrated calcium sulfates
                                          # in the fraction of the soil less than 20
                                          # millimeters in size
                                          # 'pf_soil_gypsum' = 'gypsum_r',
                                          # Cation-exchange capacity (CEC-7) is the
                                          # total amount of extractable cations that can
                                          # be held by the soil, expressed in terms of
                                          # milliequivalents per 100 grams of soil at
                                          # neutrality (pH 7.0)
                                          'soil_cat_exchange_7' = 'cec7_r',
                                          # Effective cation-exchange capacity refers to
                                          # the sum of extractable cations plus aluminum
                                          # expressed in terms of milliequivalents per
                                          # 100 grams of soil
                                          # 'pf_soil_cat_exchange_eff' = 'ecec_r',
                                          # Electrical conductivity (EC) is the electrolytic
                                          # conductivity of an extract from saturated
                                          # soil paste, expressed as decisiemens per
                                          # meter at 25 degrees C.
                                          # 'pf_soil_elec_cond' = 'ec_r',
                                          # Sodium adsorption ratio is a measure of the
                                          # amount of sodium (Na) relative to calcium (Ca)
                                          # and magnesium (Mg) in the water extract from
                                          # saturated soil paste. It is the ratio of the
                                          # Na concentration divided by the square root
                                          # of one-half of the Ca + Mg concentration.
                                          # Soils that have SAR values of 13 or more may
                                          # be characterized by an increased dispersion
                                          # of organic matter and clay particles, reduced
                                          # saturated hydraulic conductivity (Ksat) and
                                          # aeration, and a general degradation of soil
                                          # structure.
                                          # 'pf_soil_SAR' = 'sar_r',
                                          # pH is the 1:1 water method. A crushed soil
                                          # sample is mixed with an equal amount of water,
                                          # and a measurement is made of the suspension.
                                          'soil_ph' = 'ph1to1h2o_r'),
                                      # Bulk density, one-third bar, is the ovendry
                                      # weight of the soil material less than 2
                                      # millimeters in size per unit volume of soil
                                      # at water tension of 1/3 bar, expressed in
                                      # grams per cubic centimeter
                                      # 'pf_soil_bulk_density' = 'dbthirdbar_r'),
                                      #Linear extensibility refers to the change in
                                      # length of an unconfined clod as moisture
                                      # content is decreased from a moist to a dry state.
                                      # It is an expression of the volume change
                                      # between the water content of the clod at
                                      # 1/3- or 1/10-bar tension (33kPa or 10kPa tension)
                                      # and oven dryness. The volume change is reported
                                      # as percent change for the whole soil
                                      # 'soil_linear_extend' = 'lep_r',
                                      # Liquid limit (LL) is one of the standard
                                      # Atterberg limits used to indicate the plasticity
                                      # characteristics of a soil. It is the water
                                      # content, on a percent by weight basis, of
                                      # the soil (passing #40 sieve) at which the
                                      # soil changes from a plastic to a liquid state
                                      # 'soil_liquid_limit' = 'll_r',
                                      # Plasticity index (PI) is one of the standard
                                      # Atterberg limits used to indicate the plasticity
                                      # characteristics of a soil. It is defined as
                                      # the numerical difference between the liquid
                                      # limit and plastic limit of the soil. It is
                                      # the range of water content in which a soil
                                      # exhibits the characteristics of a plastic solid.
                                      # 'soil_plasticity_index' = 'pi_r'
                                      site = sites[s],
                                      ws_boundaries = boundaries))

        if(is_ms_exception(soil_tib)) {
            sw(logerror(soil_tib, logger = logger_module))
            next
        } else{
            soil_tib <- append_unprod_prefix(soil_tib, prodname_ms)
            write_feather(soil_tib, glue('data/{n}/{d}/ws_traits/nrcs_soils/{s}.feather',
                                         n = network,
                                         d = domain,
                                         s = sites[s]))
        }
    }

}

#nlcd: STATUS=READY
#. handle_errors
process_3_ms813 <- function(network, domain, prodname_ms, site_code, boundaries){

    nlcd_dir <- glue('data/{n}/{d}/ws_traits/nlcd',
                     n = network,
                     d = domain)

    dir.create(nlcd_dir,
               recursive = TRUE,
               showWarnings = FALSE)

    # Load landcover defs
    color_key = read_csv('data/spatial/nlcd/pixel_color_key.csv',
                         show_col_types = FALSE)

    nlcd_summary = color_key %>%
        as_tibble() %>%
        select(1, 3) %>%
        rename(id = class_code) %>%
        mutate(id = as.character(id))

    # 1992 to common name here: https://pubs.usgs.gov/of/2008/1379/pdf/ofr2008-1379.pdf
    color_key_1992 = read_csv('data/spatial/nlcd/1992_pixel_color_key.csv',
                              show_col_types = FALSE)

    nlcd_summary_1992 = color_key_1992 %>%
        as_tibble() %>%
        select(class_code, macrosheds_1992_code, macrosheds_code) %>%
        rename(id = class_code) %>%
        mutate(id = as.character(id))

    all_ee_task <- c()
    needed_files <- c()
    nlcd_all <- tibble()
    sites <- boundaries$site_code
    for(s in 1:length(sites)){
        # Get site boundary and check if the watershed is in Puerto Rico, Alaska, or Hawaii
        site_boundary <- boundaries %>%
            filter(site_code == sites[s]) %>%
            st_make_valid()

        ak_bb <- sf::st_bbox(obj = c(xmin = -173, ymin = 51.22, xmax = -129,
                                     ymax = 71.35), crs = 4326) %>%
            sf::st_as_sfc(., crs = 4326)

        pr_bb <- sf::st_bbox(obj = c(xmin = -67.95, ymin = 17.91, xmax = -65.22,
                                     ymax = 18.51), crs = 4326) %>%
            sf::st_as_sfc(., crs = 4326)

        hi_bb <- sf::st_bbox(obj = c(xmin = -160.24, ymin = 18.91, xmax = -154.81,
                                     ymax = 22.23), crs = 4326) %>%
            sf::st_as_sfc(., crs = 4326)

        usa_bb <- sf::st_bbox(obj = c(xmin = -124.725, ymin = 24.498, xmax = -66.9499,
                                      ymax = 49.384), crs = 4326) %>%
            sf::st_as_sfc(., crs = 4326)

        is_ak <- length(sm(sf::st_intersects(ak_bb, site_boundary))[[1]]) == 1
        is_pr <- length(sm(sf::st_intersects(pr_bb, site_boundary))[[1]]) == 1
        is_hi <- length(sm(sf::st_intersects(hi_bb, site_boundary))[[1]]) == 1
        is_usa <- length(sm(sf::st_intersects(usa_bb, site_boundary))[[1]]) == 1

        if(! is_ak && ! is_pr && ! is_hi && ! is_usa){
            return(generate_ms_exception(glue('Not within the USA, so no NLCD for {s}',
                                              s = site_code)))
        }

        if(is_ak) nlcd_epochs <- c('2001_AK', '2011_AK', '2016_AK')
        if(is_pr) nlcd_epochs <- '2001_PR'
        if(is_hi) nlcd_epochs <- '2001_HI'
        if(is_usa){
            #pre-2016 epochs are all included in the 2016 release. this list is appended below
            nlcd_epochs <- as.character(c(1992, 2001, 2004, 2006, 2008, 2011, 2013, 2016))
        }

        contents <- ee$data$listImages('USGS/NLCD_RELEASES')
        avail_releases <- sapply(contents$images, function(x) x$id)

        #filter to releases that actually have NLCD images
        for(i in length(avail_releases):1){
            ar <- avail_releases[i]
            asset_nms <- sapply(ee$data$listAssets(ar)$assets, function(x) x$name)
            if(! any(grepl('2016_REL', asset_nms)) &&
               ! any(grepl('/NLCD$', asset_nms))) avail_releases <- avail_releases[-i]
        }

        nlcd_epochs <- union(nlcd_epochs,
                             str_extract(avail_releases,
                                         '([0-9]{4})_REL$',
                                         group = 1))

        if(exists('gee_bounding_dates', where = .GlobalEnv)){

            most_recent_held <- list.files(nlcd_dir, full.names = TRUE)

            if(length(most_recent_held)){

                most_recent_held <- read_feather(most_recent_held[1], columns = 'year') %>%
                    pull() %>%
                    max()

                #sort out which releases are needed
                yrs <- as.numeric(str_extract(avail_releases, '/([0-9]{4})_REL$', group = 1))
                if(any(yrs > 2021)) stop('need to assimilate new release manually at least once more. see next comment')
                avail_releases <- avail_releases[yrs > most_recent_held]
                new_yrs <- as.numeric(str_extract(avail_releases, '/([0-9]{4})_REL$', group = 1))
                if(grepl('_[A-Z]{2}$', nlcd_epochs[1])){
                    #the next release will probably have AK, PR, HI extensions. maybe parse those here
                } else {
                    nlcd_epochs <- nlcd_epochs[as.numeric(nlcd_epochs) > most_recent_held]
                    nlcd_epochs <- c(nlcd_epochs, as.character(new_yrs))
                }

                if(! length(avail_releases)){
                    loginfo('nothing to do', logger = logger_module)
                    return()
                }
            }
        }

        user_info <- rgee::ee_user_info(quiet = TRUE)
        asset_folder <- glue('{a}/macrosheds_ws_boundaries/{d}/',
                             a = user_info$asset_home,
                             d = domain)

        asset_path <- rgee::ee_manage_assetlist(asset_folder)

        if(nrow(asset_path) == 1){
            ws_boundary_asset <- ee$FeatureCollection(asset_path$ID)
            filter_ee <- ee$Filter$inList('site_code', c(sites[s], sites[s]))
            site_ws_asset <- ws_boundary_asset$filter(filter_ee);
        } else {
            ws_boundary_asset <- str_split_fixed(asset_path$ID, '/', n = Inf)
            ws_boundary_asset <- ws_boundary_asset[,ncol(ws_boundary_asset)]

            this_asset <- asset_path[grep(sites[s], ws_boundary_asset),]
            site_ws_asset <- ee$FeatureCollection(this_asset$ID)
        }

        for(e in nlcd_epochs){

            imgcol <- ifelse(as.numeric(str_extract(e, '[0-9]+')) <= 2016,
                             'USGS/NLCD_RELEASES/2016_REL',
                             glue('USGS/NLCD_RELEASES/{e}_REL/NLCD'))
            #small possibility that this form will be required one day:
            #USGS/NLCD_RELEASES/2027_REL/NLCD/2027
            #go on gee explorer and run e.g.:
            # var assetList = ee.data.listAssets("USGS/NLCD_RELEASES/2016_REL/");
            # print(assetList);
            # var assetList = ee.data.listAssets("USGS/NLCD_RELEASES/2019_REL");
            # print(assetList);
            # var assetList = ee.data.listAssets("USGS/NLCD_RELEASES/2020_REL");
            # print(assetList);
            # var assetList = ee.data.listAssets("USGS/NLCD_RELEASES/2021_REL/NLCD");
            # print(assetList);
            # var assetList = ee.data.listAssets("USGS/NLCD_RELEASES/2023_REL");
            # print(assetList);
            #to see the contents of each available set. find available sets using 'avail_releases' code above

            img <- ee$ImageCollection(imgcol)$
                select('landcover')$
                filter(ee$Filter$eq('system:index', e))$
                first()$
                clip(site_ws_asset)

            ee_description <- glue('{n}_{d}_{s}_{p}_{e}',
                                   d = domain,
                                   n = network,
                                   s = sites[s],
                                   p = str_split_fixed(prodname_ms, '__', n = Inf)[1, 1],
                                   e = e)

            file_name <- paste0('nlcdX_X', e, 'X_X', sites[s])
            ee_task <- ee$batch$Export$image$toDrive(image = img,
                                                     description = ee_description,
                                                     folder = 'GEE',
                                                     # crs = 'ESPG:4326',
                                                     region = site_ws_asset$geometry(),
                                                     fileNamePrefix = file_name,
                                                     maxPixels = 105921861) #one larger than neon-TOMB

            needed_files <- c(needed_files, file_name)
            all_ee_task <- c(all_ee_task, ee_description)

            try(googledrive::drive_rm(paste0('GEE/', file_name, '.tif')),
                silent = TRUE) #in case previous drive_rm failed

            start_mess <- try(ee_task$start())
            if(class(start_mess) == 'try-error'){
                return(generate_ms_err(glue('error in retrieving {s}',
                                            s = site_code)))
            }
            #ee_monitoring(ee_task)
        }
    }

    needed_files <- paste0(needed_files, '.tif')

    task_running <- rgee::ee_manage_task()

    task_running <- task_running %>%
        filter(DestinationPath %in% all_ee_task)

    while(any(task_running$State %in% c('RUNNING', 'READY'))){
        task_running <- rgee::ee_manage_task()

        task_running <- task_running %>%
            filter(DestinationPath %in% all_ee_task)

        Sys.sleep(10)
    }

    Sys.sleep(60)
    task_running <- rgee::ee_manage_task()
    if(any(task_running$State %in% c('RUNNING', 'READY'))){
        stop('weird. somehow the while loop above is exiting early')
    }

    temp_rgee <- tempfile(fileext = '.tif')

    for(i in 1:length(needed_files)){

        rel_file <- needed_files[i]

        string <- str_match(rel_file, '(.+?)X_X(.+?)X_X(.+?)\\.tif')[2:4]
        year <- string[2]
        site <- string[3]

        file_there <- googledrive::drive_get(paste0('GEE/', rel_file))

        if(nrow(file_there) == 0) next

        expo_backoff(
            expr = {
                googledrive::drive_download(file = paste0('GEE/', rel_file),
                                            temp_rgee,
                                            overwrite = TRUE)
            },
            max_attempts = 5
        ) %>% invisible()

        nlcd_rast <- terra::rast(temp_rgee)
        nlcd_rast[as.vector(terra::values(nlcd_rast)) == 0] <- NA

        googledrive::drive_rm(rel_file)

        tabulated_values = terra::values(nlcd_rast) %>%
            table() %>%
            as_tibble() %>%
            rename(id = '.',
                   CellTally = 'n')

        if(length(str_split_fixed(year, '_', n = Inf)[1, ]) == 2){
            year <- as.numeric(str_split_fixed(year, pattern = '_', n = Inf)[1, 1])
        }

        if(year == 1992){

            nlcd_e = full_join(nlcd_summary_1992,
                               tabulated_values,
                               by = 'id') %>%
                mutate(sum = sum(CellTally, na.rm = TRUE))

            nlcd_e_1992names <- nlcd_e %>%
                mutate(percent = round((CellTally / sum) * 100, 1)) %>%
                mutate(percent = ifelse(is.na(percent), 0, percent)) %>%
                select(var = macrosheds_1992_code, val = percent) %>%
                mutate(year = !!year)

            nlcd_e_norm_names <- nlcd_e %>%
                group_by(macrosheds_code) %>%
                summarize(CellTally1992 = sum(CellTally, na.rm = TRUE),
                          .groups = 'drop') %>%
                mutate(sum = sum(CellTally1992, na.rm = TRUE)) %>%
                mutate(percent = round((CellTally1992 / sum) * 100, 1)) %>%
                mutate(percent = ifelse(is.na(percent), 0, percent)) %>%
                select(var = macrosheds_code, val = percent) %>%
                mutate(year = !!year)

            nlcd_e <- rbind(nlcd_e_1992names, nlcd_e_norm_names) %>%
                mutate(site_code = !!site)

        } else {

            nlcd_e <- full_join(nlcd_summary,
                                tabulated_values,
                                by = 'id')

            nlcd_e <- nlcd_e %>%
                mutate(percent = round((CellTally * 100) / sum(CellTally, na.rm = TRUE), 1)) %>%
                mutate(percent = ifelse(is.na(percent), 0, percent)) %>%
                select(var = macrosheds_code, val = percent) %>%
                mutate(year = !!year) %>%
                mutate(site_code = !!site)
        }

        nlcd_all <- rbind(nlcd_all, nlcd_e)
    }

    nlcd_final <- nlcd_all %>%
        mutate(year = as.numeric(year)) %>%
        select(year, site_code, var, val)

    nlcd_final <- append_unprod_prefix(nlcd_final, prodname_ms)

    nlcd_final <- bind_older_ws_traits(nlcd_final)

    save_general_files(final_file = nlcd_final,
                       domain_dir = nlcd_dir)
}

#nadp: STATUS=READY
#. handle_errors
process_3_ms814 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    # https://gaftp.epa.gov/Epadatacommons/ORD/NHDPlusLandscapeAttributes/LakeCat/Documentation/DataDictionary.html
    # https://www.sciencebase.gov/catalog/item/53481333e4b06f6ce034aae7
    # https://github.com/USEPA/StreamCat/blob/master/ControlTable_StreamCat.csv

    nadp_dir <- glue('data/{network}/{domain}/ws_traits/nadp/')

    dir.create(nadp_dir,
               recursive = TRUE,
               showWarnings = FALSE)

    nadp_files <- list.files('data/spatial/ndap',
                             recursive = TRUE,
                             full.names = TRUE)

    sites <- boundaries$site_code

    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s])

        usa_bb <- sf::st_bbox(obj = c(xmin = -124.725, ymin = 24.498, xmax = -66.9499,
                                      ymax = 49.384), crs = 4326) %>%
            sf::st_as_sfc(crs = 4326)

        is_usa <- length(sm(sf::st_intersects(usa_bb, site_boundary))[[1]]) == 1

        if(! is_usa){
            msg <- generate_ms_exception(glue('No data available for {sites[s]}'))

            logerror(msg = msg,
                     logger = logger_module)
            next
        }

        all_vars <- tibble()
        for(p in 1:length(nadp_files)){

            year <- str_split_fixed(nadp_files[p], '/', n = Inf)[1, 4]
            var <- str_split_fixed(str_split_fixed(nadp_files[p], '/', n = Inf)[1, 5], '_', Inf)[1, 2]

            ws_values <- try(extract_ws_mean(site_boundary = site_boundary,
                                             raster_path = nadp_files[p]),
                             silent = TRUE)

            if(inherits(ws_values, 'try-error')) next


            val_mean <- round(unname(ws_values['mean']), 3)
            val_sd <- round(unname(ws_values['sd']), 3)
            percent_na <- round(unname(ws_values['pctCellErr']), 2)

            one_year_var <- tibble(year = year,
                                   val = c(val_mean, val_sd),
                                   var = c(var, var),
                                   pctCellErr = percent_na,
                                   type = c('mean', 'sd_space'),
                                   site_code = !!sites[s])

            all_vars <- rbind(all_vars, one_year_var)
        }

        fin_nadp <- all_vars %>%
            mutate(var = case_when(var == 'ca' ~ 'annual_Ca_flux',
                                   var == 'cl' ~ 'annual_Cl_flux',
                                   var == 'hplus' ~ 'annual_H_flux',
                                   var == 'k' ~ 'annual_K_flux',
                                   var == 'mg' ~ 'annual_Mg_flux',
                                   var == 'na' ~ 'annual_Na_flux',
                                   var == 'nh4' ~ 'annual_NH4_flux',
                                   var == 'no3' ~ 'annual_NO3_flux',
                                   var == 'so4' ~ 'annual_SO4_flux',
                                   var == 'splusn' ~ 'annual_S_N_flux',
                                   var == 'totalN' ~ 'annual_N_flux')) %>%
            mutate(var = paste0(var, '_', type)) %>%
            mutate(year = as.numeric(year)) %>%
            select(year, site_code, var, val, pctCellErr)

        if(all(is.na(fin_nadp$val))){
            msg <- generate_ms_exception(glue('No data were retrived for {sites[s]}'))

            logerror(msg = msg,
                     logger = logger_module)
        } else {
            fin_nadp <- append_unprod_prefix(fin_nadp, prodname_ms)
            write_feather(fin_nadp,
                          glue('{nadp_dir}sum_{sites[s]}.feather'))
        }
    }
}

#pelletier_soil_thickness: STATUS=READY
#. handle_errors
process_3_ms815 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    # https://daac.ornl.gov/cgi-bin/dsviewer.pl?ds_id=1304

    thickness_dir <- glue('data/{n}/{d}/ws_traits/pelletier_soil_thickness/',
                          n = network,
                          d = domain)

    dir.create(thickness_dir, recursive = TRUE, showWarnings = FALSE)

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s])

        thinkness_files <- 'data/spatial/pelletier_soil_thickness/average_soil_and_sedimentary-deposit_thickness.tif'


        ws_values <- try(extract_ws_mean(site_boundary = site_boundary,
                                         raster_path = thinkness_files))


        if(inherits(ws_values, 'try-error')){

            msg <- generate_ms_exception(glue('No data were retrived for {s}',
                                              s = sites[s]))

            logerror(msg = msg,
                     logger = logger_module)
            next
        }

        thinkness_tib <- tibble(year = NA,
                                val = unname(ws_values['mean']),
                                var = 'soil_thickness',
                                pctCellErr = unname(ws_values['pctCellErr']),
                                ms_status = NA)  %>%
            mutate(site_code = !!sites[s]) %>%
            select(year, site_code, var, val, pctCellErr)

        thinkness_tib <- append_unprod_prefix(thinkness_tib, prodname_ms)
        write_feather(thinkness_tib, glue('{d}{s}.feather',
                                          d = thickness_dir,
                                          s = sites[s]))

    }
}

#geochemical: STATUS=READY
#. handle_errors
process_3_ms816 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    geomchem_dir <- glue('data/{n}/{d}/ws_traits/geochemical',
                         n = network,
                         d = domain)

    dir.create(geomchem_dir, recursive = TRUE, showWarnings = FALSE)

    geomchem_files <- list.files('data/spatial/geochemical', recursive = TRUE, full.names = TRUE)


    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s])

        all_vars <- tibble()
        for(p in 1:length(geomchem_files)){

            var <- str_split_fixed(geomchem_files[p], '/', n = Inf)[1,4]
            var <- str_split_fixed(var, '[.]', n = Inf)[1,1]
            var <- str_split_fixed(var, '_', n = Inf)[1,1]

            ws_values <- try(extract_ws_mean(site_boundary = site_boundary,
                                             raster_path = geomchem_files[p]),
                             silent = TRUE)

            if(inherits(ws_values, 'try-error')) next

            val_mean <- round(unname(ws_values['mean']), 2)
            val_sd <- round(unname(ws_values['sd']), 2)
            percent_na <-round(unname(ws_values['pctCellErr']), 2)

            one_var <- tibble(val = c(val_mean, val_sd),
                              var = c(paste0(var, '_mean'), paste0(var, '_sd')),
                              pctCellErr = percent_na)

            all_vars <- rbind(all_vars, one_var)
        }

        if(nrow(all_vars) == 0){

            msg <- generate_ms_exception(glue('No data available for: ', sites[s]))
            logerror(msg = msg,
                     logger = logger_module)

            next
        }

        all_vars <- all_vars %>%
            mutate(site_code = !!sites[s],
                   year = NA,
                   var = paste0('geo_', var)) %>%
            select(year, site_code, var, val, pctCellErr)

        all_vars <- append_unprod_prefix(all_vars, prodname_ms)
        write_feather(all_vars, glue('{d}/{s}.feather',
                                     d = geomchem_dir,
                                     s = sites[s]))

    }
}

#ndvi; evi: STATUS=READY
#. handle_errors
process_3_ms817 <- function(network, domain, prodname_ms, site_code, boundaries){

    prodname <- prodname_from_prodname_ms(prodname_ms)
    geeid <- ifelse(prodname == 'evi',
                    'MODIS/061/MOD13Q1', #should only be this one in 2025
                    'MODIS/006/MOD13Q1')

    vi <- try({
        get_gee_standard(
            network = network,
            domain = domain,
            gee_id = geeid,
            band = toupper(prodname),
            prodname = prodname,
            rez = 250,
            site_boundary = boundaries,
            qa_band = 'SummaryQA',
            bit_mask = '11'
        )
    })

    if(is.null(vi)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(vi, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    vi <- vi$table %>%
        mutate(datetime = ymd(datetime)) %>%
        select(site_code, datetime, var, val) %>%
        mutate(year = year(datetime),
               val = val * 0.0001) #scale factor of gee product

    if(prodname == 'ndvi'){

        vi_means <- vi %>%
            filter(var == 'ndvi_median') %>%
            group_by(site_code, year) %>%
            summarize(ndvi_max = max(val, na.rm = TRUE),
                      ndvi_min = min(val, na.rm = TRUE),
                      ndvi_mean = mean(val, na.rm = TRUE),
                      ndvi_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('ndvi_max', 'ndvi_min', 'ndvi_mean', 'ndvi_sd_year'),
                         names_to = 'var',
                         values_to = 'val')
    } else {

        vi_means <- vi %>%
            filter(var == 'evi_median') %>%
            group_by(site_code, year) %>%
            summarize(evi_max = max(val, na.rm = TRUE),
                      evi_min = min(val, na.rm = TRUE),
                      evi_mean = mean(val, na.rm = TRUE),
                      evi_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('evi_max', 'evi_min', 'evi_mean', 'evi_sd_year'),
                         names_to = 'var',
                         values_to = 'val')
    }

    vi_sd <- vi %>%
        filter(var == paste0(prodname, '_sd')) %>%
        group_by(site_code, year) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = paste0(prodname, '_sd_space'))

    vi_final <- rbind(vi_means, vi_sd) %>%
        select(year, site_code, var, val)

    vi_raw <- vi %>%
        select(datetime, site_code, var, val)

    vi_final <- append_unprod_prefix(vi_final, prodname_ms)
    vi_raw <- append_unprod_prefix(vi_raw, prodname_ms)

    vi_final <- bind_older_ws_traits(vi_final)
    vi_raw <- bind_older_ws_traits(vi_raw)

    save_general_files(final_file = vi_final,
                       raw_file = vi_raw,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/{prodname}/'))

    return()
}

#bfi: STATUS=READY
#. handle_errors
process_3_ms818 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    # https://gaftp.epa.gov/epadatacommons/ORD/NHDPlusLandscapeAttributes/StreamCat/Documentation/DataDictionary.html
    # https://daac.ornl.gov/cgi-bin/dsviewer.pl?ds_id=1304

    bfi_dir <- glue('data/{n}/{d}/ws_traits/bfi/',
                    n = network,
                    d = domain)

    dir.create(bfi_dir,
               recursive = TRUE,
               showWarnings = FALSE)

    bfi_files <- 'data/spatial/bfi.tif'
    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s])

        ws_values <- try(extract_ws_mean(site_boundary = site_boundary,
                                         raster_path = bfi_files),
                         silent = TRUE)

        if(inherits(ws_values, 'try-error')){
            msg <- generate_ms_exception(glue('No data were retrived for {s}',
                                              s = sites[s]))

            logerror(msg = msg,
                     logger = logger_module)

            next
        }

        val_mean <- round(unname(ws_values['mean']), 2)
        val_sd <- round(unname(ws_values['sd']), 2)
        percent_na <-round(unname(ws_values['pctCellErr']), 2)

        bfi_tib <- tibble(year = NA,
                          val = c(val_mean, val_sd),
                          var = c('bfi_mean', 'bfi_sd'),
                          pctCellErr = percent_na,
                          ms_status = NA)  %>%
            mutate(site_code = !!sites[s]) %>%
            select(year, site_code, var, val, pctCellErr)

        bfi_tib <- append_unprod_prefix(bfi_tib, prodname_ms)
        write_feather(bfi_tib, glue('{d}{s}.feather',
                                    d = bfi_dir,
                                    s = sites[s]))
    }
}

#tcw: STATUS=READY
#. handle_errors
process_3_ms819 <- function(network, domain, prodname_ms, site_code, boundaries){

    tcw <- try(get_gee_standard(network = network,
                                domain = domain,
                                gee_id = 'Oxford/MAP/TCW_5km_Monthly',
                                band = 'Mean',
                                prodname = 'tcw',
                                rez = 5000,
                                site_boundary = boundaries))

    if(is.null(tcw)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(tcw, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    tcw <- tcw$table %>%
        mutate(datetime = ymd(paste0(substr(datetime, 1, 7), '_01'))) %>%
        mutate(year = year(datetime))

    tcw_means <- tcw %>%
        filter(var == 'tcw_median') %>%
        group_by(site_code, year) %>%
        summarize(tcw_max = max(val, na.rm = TRUE),
                  tcw_min = min(val, na.rm = TRUE),
                  tcw_mean = mean(val, na.rm = TRUE),
                  tcw_sd_year = sd(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        pivot_longer(cols = c('tcw_max', 'tcw_min', 'tcw_mean', 'tcw_sd_year'),
                     names_to = 'var',
                     values_to = 'val')

    tcw_sd <- tcw %>%
        filter(var == 'tcw_sd') %>%
        group_by(site_code, year) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = 'tcw_sd_space')

    tcw_final <- rbind(tcw_means, tcw_sd) %>%
        select(year, site_code, var, val)

    tcw <- tcw %>%
        select(datetime, site_code, var, val)

    tcw <- append_unprod_prefix(tcw, prodname_ms)
    tcw_final <- append_unprod_prefix(tcw_final, prodname_ms)

    tcw <- bind_older_ws_traits(tcw)
    tcw_final <- bind_older_ws_traits(tcw_final)

    save_general_files(final_file = tcw_final,
                       raw_file = tcw,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/tcw/'))

    return()
}

#et_ref: STATUS=READY
#. handle_errors
process_3_ms820 <- function(network, domain, prodname_ms, site_code, boundaries){

    final <- try(get_gee_standard(network = network,
                                  domain = domain,
                                  gee_id = 'IDAHO_EPSCOR/GRIDMET',
                                  band = 'eto',
                                  prodname = 'et_ref',
                                  rez = 4000,
                                  site_boundary = boundaries,
                                  batch = TRUE,
                                  contiguous_us = TRUE))

    if(is.null(final)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(final, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    final <- final$table %>%
        mutate(datetime = substr(datetime, 0, 8)) %>%
        mutate(datetime = ymd(datetime))

    if(all(is.na(final$val)) || all(final$val == 0)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    final_ <- final %>%
        filter(var == 'et_ref_median') %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(et_ref_mean = mean(val, na.rm = TRUE),
                  et_ref_sd_year = sd(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        pivot_longer(cols = c('et_ref_mean', 'et_ref_sd_year'),
                     names_to = 'var',
                     values_to = 'val')

    temp_sd <- final %>%
        filter(var == 'et_ref_sd') %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = 'et_ref_sd_space')

    final_sum <- rbind(final_, temp_sd) %>%
        select(year, site_code, var, val)

    final <- final %>%
        select(datetime, site_code, var, val)

    final <- append_unprod_prefix(final, prodname_ms)
    final_sum <- append_unprod_prefix(final_sum, prodname_ms)

    final <- bind_older_ws_traits(final)
    final_sum <- bind_older_ws_traits(final_sum)

    save_general_files(final_file = final_sum,
                       raw_file = final,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/et_ref/'))

    return()
}

#nsidc: STATUS=READY
#. handle_errors
process_3_ms821 <- function(network, domain, prodname_ms, site_code, boundaries){

    usa_bb <- sf::st_bbox(
        obj = c(xmin = -124.725, ymin = 24.498, xmax = -66.9499, ymax = 49.384),
        crs = 4326
    ) %>%
        sf::st_as_sfc(crs = 4326)

    snow_dir <- glue('data/{network}/{domain}/ws_traits/nsidc')
    dir.create(snow_dir, recursive = TRUE, showWarnings = FALSE)
    snow_files <- list.files('data/spatial/nsidc/',
                             recursive = TRUE,
                             full.names = TRUE)

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        files <- list.files(glue('data/{network}/{domain}/derived/'))
        ws_prodname <- grep('ws_boundary', files, value = TRUE)

        # If there are multiple ws boundary folders, get largest prod code
        if(length(ws_prodname) > 1){

            prod_codes <- str_match(ws_prodname, 'ms([0-9]{3})$')[, 2]
            max_code <- max(prod_codes)
            ws_prodname <- ws_prodname[grep(max_code, prod_codes)]
        }

        ws_path <- glue('data/{n}/{d}/derived/{p}/{s}',
                        n = network,
                        d = domain,
                        p = ws_prodname,
                        s = sites[s])

        site_boundary <- sf::st_read(ws_path, quiet = TRUE)
        is_usa <- ! length(sm(sf::st_intersects(usa_bb, site_boundary))[[1]]) == 0

        if(! is_usa){
            msg <- generate_ms_exception(glue('No data available for {sites[s]}'))
            logerror(msg = msg, logger = logger_module)
            next
        }

        nthreads <- parallel::detectCores()
        clst <- ms_parallelize(maxcores = nthreads)

        all_years <- tibble()
        all_years <- foreach::foreach(
            p = 1:length(snow_files),
            .combine = rbind,
            .init = all_years) %dopar% {

                snow_year <- str_match(snow_files[p], 'WY([0-9]{4})_v01\\.nc$')[1,2]
                site_boundary <- sf::st_read(ws_path, quiet = TRUE) %>%
                    terra::vect(.)

                snow_file <- terra::rast(snow_files[p])

                swe_tib = terra::extract(snow_file, site_boundary, weights = TRUE)

                final <- swe_tib %>%
                    pivot_longer(cols = starts_with(c('SWE', 'DEPTH'))) %>%
                    mutate(weighted_value = value*weight) %>%
                    group_by(name) %>%
                    summarize(val = sum(weighted_value, na.rm = TRUE),
                              weights = sum(weight, na.rm = TRUE),
                              n = n(),
                              sd = sd(value, na.rm = TRUE),
                              na = sum(is.na(value)),
                              .groups = 'drop') %>%
                    mutate(mean = val / weights,
                           pctCellErr = (na / n) * 100) %>%
                    mutate(var = str_split_fixed(name, '_', n = Inf)[, 1],
                           day = str_split_fixed(name, '_', n = Inf)[, 2]) %>%
                    mutate(datetime = as_date(as.numeric(day),
                                              origin = paste0(snow_year, '-09-30'))) %>%
                    select(datetime, mean, sd, var, pctCellErr) %>%
                    mutate(var = case_when(var == 'DEPTH' ~ 'snow_depth',
                                           var == 'SWE' ~ 'swe')) %>%
                    pivot_longer(cols = c('mean', 'sd')) %>%
                    mutate(var = paste(var, name, sep = '_')) %>%
                    select(datetime, var, val = value, pctCellErr)

                return(final)
            }

        ms_unparallelize(clst)

        all_years <- all_years %>%
            mutate(site_code = !!sites[s]) %>%
            select(datetime, site_code, var, val, pctCellErr)

        snow_d_means <- all_years %>%
            mutate(year = year(datetime)) %>%
            filter(var == 'snow_depth_mean') %>%
            group_by(site_code, year) %>%
            summarize(snow_depth_ann_max = max(val, na.rm = TRUE),
                      snow_depth_ann_min = min(val, na.rm = TRUE),
                      snow_depth_ann_mean = mean(val, na.rm = TRUE),
                      snow_depth_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('snow_depth_ann_max', 'snow_depth_ann_min',
                                  'snow_depth_ann_mean', 'snow_depth_sd_year'),
                         names_to = 'var',
                         values_to = 'val')

        snow_d_sd <- all_years %>%
            mutate(year = year(datetime)) %>%
            filter(var == 'snow_depth_sd') %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'snow_depth_sd_space')

        swe_means <- all_years %>%
            mutate(year = year(datetime)) %>%
            filter(var == 'swe_mean') %>%
            group_by(site_code, year) %>%
            summarize(swe_ann_max = max(val, na.rm = TRUE),
                      swe_ann_min = min(val, na.rm = TRUE),
                      swe_ann_mean = mean(val, na.rm = TRUE),
                      swe_sd_year = sd(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            pivot_longer(cols = c('swe_ann_max', 'swe_ann_min', 'swe_ann_mean',
                                  'swe_sd_year'),
                         names_to = 'var',
                         values_to = 'val')

        swe_sd <- all_years %>%
            mutate(year = year(datetime)) %>%
            filter(var == 'swe_sd') %>%
            group_by(site_code, year) %>%
            summarize(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(var = 'swe_sd_space')

        snow_final <- rbind(snow_d_means, snow_d_sd, swe_means, swe_sd) %>%
            select(year, site_code, var, val)

        all_years <- append_unprod_prefix(all_years, prodname_ms)
        snow_final <- append_unprod_prefix(snow_final, prodname_ms)

        save_general_files(final_file = snow_final,
                           raw_file = all_years,
                           domain_dir = glue('data/{network}/{domain}/ws_traits/nsidc/'))
    }
}

#glhymps: STATUS=READY
#. handle_errors
process_3_ms822 <- function(network, domain, prodname_ms, site_code, boundaries){

    dir.create(glue('data/{network}/{ddomain}/ws_traits/glhymps/'),
               recursive = TRUE,
               showWarnings = FALSE)

    glhymps <- st_read('data/spatial/GLHYMPS/GLHYMPS.shp', quiet = TRUE)

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s]) %>%
            sf::st_transform(sf::st_crs(glhymps)) %>%
            sf::st_make_valid()

        site_area <- site_data %>%
            filter(network == !!network,
                   domain == !!domain,
                   site_code == !!sites[s],
                   site_type != 'rain_gauge') %>%
            pull(ws_area_ha)

        site_area <- site_area * 10000

        # glhymps is maybe an invalid geometry, need to fix
        message('is the comment above still relevant? see code at top of lithology kernel if so')
        browser()
        sub_surface <- sf::st_intersection(glhymps, site_boundary) %>%
            mutate(intersect_area = as.numeric(sf::st_area(geometry))) %>%
            mutate(prop_basin = intersect_area / !!site_area) %>%
            mutate(Porosity_weight = Porosty*prop_basin,
                   Permeability_no_permafrost_weight = Prmblty_n_ * prop_basin,
                   Permeability_permafrost_weight = Prmblt_ * prop_basin,
                   Permeability_standard_deviation_weight = Prmblty_s_ * prop_basin)

        area_sub_dif <- sum(sub_surface$intersect_area) / site_area
        area_sub_dif <- abs(1 - area_sub_dif)

        if(area_sub_dif < 0.05){
            pctCellErr <- 0
        } else {
            pctCellErr <- area_sub_dif * 100
        }

        sub_surface <- sub_surface %>%
            as_tibble() %>%
            group_by(site_code) %>%
            summarize(sub_surf_porosity_mean = sum(Porosity_weight),
                      sub_surf_porosity_sd = sd(Porosty),
                      sub_surf_permeability_mean = sum(Permeability_no_permafrost_weight),
                      sub_surf_permeability_sd = sd(Prmblty_n_),
                      sub_surf_permeability_perm_mean = sum(Permeability_permafrost_weight),
                      sub_surf_permeability_perm_sd = sd(Prmblt_),
                      .groups = 'drop') %>%
            select(site_code, starts_with('sub_surf')) %>%
            pivot_longer(cols = starts_with('sub_surf'),
                         names_to = 'var',
                         values_to = 'val') %>%
            mutate(year = NA,
                   pctCellErr = !!pctCellErr)

        sub_surface <- append_unprod_prefix(sub_surface, prodname_ms)

        write_feather(sub_surface, glue('data/{n}/{d}/ws_traits/glhymps/{s}.feather',
                                        n = network,
                                        d = domain,
                                        s = sites[s]))
    }
}

#lithology: STATUS=READY
#. handle_errors
process_3_ms823 <- function(network, domain, prodname_ms, site_code, boundaries){

    dir.create(glue('data/{network}/{domain}/ws_traits/lithology/'),
               recursive = TRUE)

    sf::sf_use_s2(FALSE)
    glim <- st_read('data/spatial/LiMW/LiMW_GIS 2015.gdb', quiet = TRUE)
    glim <- sf::st_make_valid(glim)

    # glim_look <- rgdal::readOGR('data/spatial/LiMW/LiMW_GIS 2015.gdb')
    # glim_look_sf <- st_as_sf(glim_look)
    # glim_safe <- st_make_valid(glim_look_sf)
    # rgdal:::writeOGR(glim_safe, 'data/spatial/LiMW/LiMW_GIS 2015.shp', driver = 'ESRI Shapefile')
    # st_write(glim_safe, 'data/spatial/LiMW/LiMW_GIS 2015', driver = 'GeoJSON')

    geol_codes <- c('ND', 'SU', 'SS', 'SM', 'SC', 'PY', 'EV', 'MT', 'PA', 'PI',
                    'PB', 'VA', 'VI', 'VB', 'IG', 'WB')

    sites <- boundaries$site_code
    for(s in 1:length(sites)){

        site_boundary <- boundaries %>%
            filter(site_code == !!sites[s]) %>%
            sf::st_transform(sf::st_crs(glim))

        # site_area <- site_data %>%
        #   filter(network == !!network,
        #          domain == !!domain,
        #          site_code == !!sites[s]) %>%
        #   pull(ws_area_ha)
        #
        # site_area <- site_area * 10000

        lithology  <- sf::st_intersection(glim, site_boundary) %>%
            mutate(intersect_area = as.numeric(sf::st_area(Shape))) %>%
            group_by(xx) %>%
            summarize(intersect_area = sum(intersect_area),
                      .groups = 'drop')

        total_area <- sum(lithology$intersect_area, na.rm = TRUE)

        lithology <- lithology %>%
            mutate(prop = intersect_area / !!total_area) %>%
            mutate(prop_basin = intersect_area / !!total_area) %>%
            mutate(prop_basin = round(prop_basin, 5) * 100) %>%
            as_tibble() %>%
            mutate(var = paste0('geol_class_', toupper(xx)),
                   site_code = !!sites[s],
                   year = NA) %>%
            rename(val = prop_basin) %>%
            select(site_code, var, val, year)

        vars_prez <- unique(lithology$var)

        geol_tib <- tibble(site_code =  sites[s],
                           var = paste0('geol_class_', geol_codes),
                           val = 0,
                           year = NA) %>%
            filter(! var %in% !!vars_prez)

        lithology <- rbind(lithology, geol_tib)
        lithology <- append_unprod_prefix(lithology, prodname_ms)

        write_feather(lithology, glue('data/{n}/{d}/ws_traits/lithology/{s}.feather',
                                      n = network,
                                      d = domain,
                                      s = sites[s]))
    }

    sf::sf_use_s2(TRUE)
}

#daymet: STATUS=READY
#. handle_errors
process_3_ms824 <- function(network, domain, prodname_ms, site_code,
                            boundaries) {

    user_info <- rgee::ee_user_info(quiet = TRUE)

    asset_folder <- glue('{a}/macrosheds_ws_boundaries/{d}/',
                         a = user_info$asset_home,
                         d = domain)

    asset_path <- rgee::ee_manage_assetlist(asset_folder)

    if(nrow(asset_path) > 1){
        for(i in 1:nrow(asset_path)){

            if(i == 1){
                ws_boundary_asset <- ee$FeatureCollection(asset_path$ID[i])
            }
            if(i > 1){
                one_ws <- ee$FeatureCollection(asset_path$ID[i])

                ws_boundary_asset <- ws_boundary_asset$merge(one_ws)
            }
        }
    } else{
        ws_boundary_asset <- ee$FeatureCollection(asset_path$ID)
    }

    imgcol <- ee$ImageCollection('NASA/ORNL/DAYMET_V4')$
        filterBounds(ws_boundary_asset)$
        select('dayl','prcp', 'tmin', 'tmax', 'srad', 'swe', 'vp')

    if(! bulk_mode){
        scale_ <- case_when(boundaries$area < 1e5 ~ 1000,
                            between(boundaries$area, 1e5, 1e6) ~ 2000,
                            boundaries$area > 1e6 ~ 16000)
    } else {
        scale_ <- 1000
    }

    results <- ws_boundary_asset$map(function(f) {
        fin = imgcol$map(function(i) {
            mean = i$reduceRegion(
                geometry = f$geometry(),
                reducer = ee$Reducer$mean(),
                scale = scale_
            )
            f$setMulti(mean)$set(list(date = i$date()))
        })
    })$flatten()

    gee <- results$select(propertySelectors = c('site_code', 'date', 'dayl',
                                                'prcp', 'srad', 'swe', 'tmax',
                                                'tmin', 'vp'),
                          retainGeometry = FALSE)

    ee_description <-  glue('{n}_{d}_{p}',
                            d = domain,
                            n = network,
                            p = prodname_ms)

    ee_task <- ee$batch$Export$table$toDrive(collection = gee,
                                             description = ee_description,
                                             fileFormat = 'CSV',
                                             folder = 'GEE',
                                             fileNamePrefix = 'rgee')

    ee_task$start()
    ee_monitoring(ee_task, quiet = TRUE, max_attempts = Inf)

    temp_rgee <- tempfile(fileext = '.csv')

    expo_backoff(
        expr = {
            googledrive::drive_download(file = 'GEE/rgee.csv',
                                        temp_rgee,
                                        verbose = FALSE)
        },
        max_attempts = 5
    ) %>% invisible()

    fin_table <- read_csv(temp_rgee,
                          show_col_types = FALSE)

    googledrive::drive_rm('GEE/rgee.csv', verbose = FALSE)

    if(nrow(fin_table) == 0){
        return(generate_ms_exception(glue('No data were retrived for {domain}')))
    }

    fin_table <- fin_table %>%
        select(date, site_code, dayl, prcp, srad, swe, tmax, tmin, vp)

    dir.create(glue('data/{n}/{d}/ws_traits/daymet/',
                    n = network,
                    d = domain),
               showWarnings = FALSE)

    file_path <- glue('data/{n}/{d}/ws_traits/daymet/domain_climate.feather',
                      n = network,
                      d = domain)

    write_feather(fin_table, file_path)

    return()
}

#modis_igbp: STATUS=READY
#. handle_errors
process_3_ms825 <- function(network, domain, prodname_ms, site_code, boundaries){

    igbp_dir <- glue('data/{n}/{d}/ws_traits/modis_igbp/',
                     n = network,
                     d = domain)

    dir.create(igbp_dir,
               recursive = TRUE,
               showWarnings = FALSE)

    igbp_epochs <- ee$ImageCollection('MODIS/006/MCD12Q1')$aggregate_array('system:index')$getInfo()
    if(exists('gee_bounding_dates', where = .GlobalEnv)){

        most_recent_held <- list.files(igbp_dir, full.names = TRUE)

        if(length(most_recent_held)){

            most_recent_held <- read_feather(most_recent_held[1], columns = 'year') %>%
                pull() %>%
                max()

            yrs <- as.numeric(str_extract(igbp_epochs, '^([0-9]{4})_', group = 1))
            igbp_epochs <- igbp_epochs[yrs > most_recent_held]

            if(! length(igbp_epochs)){
                loginfo('nothing to do', logger = logger_module)
                return()
            }
        }
    }

    # Load landcover defs
    color_key = read_csv('data/spatial/modis_igbp/modis_land_cover.csv',
                         show_col_types = FALSE)

    igbp_summary = color_key %>%
        as_tibble() %>%
        select(1, 3) %>%
        rename(id = class_code) %>%
        mutate(id = as.character(id))

    all_ee_task <- c()
    needed_files <- c()
    igbp_all <- tibble()
    sites <- boundaries$site_code
    for(s in 1:length(sites)){
        # Get site boundary and check if the watershed is in Puerto Rico, Alaska, or Hawaii
        site_boundary <- boundaries %>%
            filter(site_code == sites[s])

        user_info <- rgee::ee_user_info(quiet = TRUE)
        asset_folder <- glue('{a}/macrosheds_ws_boundaries/{d}/',
                             a = user_info$asset_home,
                             d = domain)

        asset_path <- rgee::ee_manage_assetlist(asset_folder)

        if(nrow(asset_path) == 1){
            ws_boundary_asset <- ee$FeatureCollection(asset_path$ID)
            filter_ee <- ee$Filter$inList('site_code', c(sites[s], sites[s]))
            site_ws_asset <- ws_boundary_asset$filter(filter_ee);
        } else {
            ws_boundary_asset <- str_split_fixed(asset_path$ID, '/', n = Inf)
            ws_boundary_asset <- ws_boundary_asset[,ncol(ws_boundary_asset)]

            this_asset <- asset_path[grep(sites[s], ws_boundary_asset),]
            site_ws_asset <- ee$FeatureCollection(this_asset$ID)
        }

        for(e in igbp_epochs){

            #subset_id = paste0('NLCD', as.character(e))
            img <- ee$ImageCollection('MODIS/006/MCD12Q1')$
                select('LC_Type1')$
                filter(ee$Filter$eq('system:index', e))$
                first()$
                clip(site_ws_asset)
            # clip(site_ws_asset$geometry())

            ee_description <-  glue('{n}_{d}_{s}_{p}_{e}',
                                    d = domain,
                                    n = network,
                                    s = sites[s],
                                    p = str_split_fixed(prodname_ms, '__', n = Inf)[1,1],
                                    e = e)

            file_name <- paste0('igbpX_X', e, 'X_X', sites[s])
            ee_task <- ee$batch$Export$image$toDrive(image = img,
                                                     description = ee_description,
                                                     folder = 'GEE',
                                                     region = site_ws_asset$geometry(),
                                                     fileNamePrefix = file_name,
                                                     maxPixels=NULL)

            needed_files <- c(needed_files, file_name)
            all_ee_task <- c(all_ee_task, ee_description)

            try(googledrive::drive_rm(paste0('GEE/', file_name, '.tif')),
                silent = TRUE) #in case previous drive_rm failed

            start_mess <- try(ee_task$start())
            if(inherits(start_mess, 'try-error')){
                return(generate_ms_err(glue('error in retrieving {s}',
                                            s = site_code)))
            }
        }
    }

    needed_files <- paste0(needed_files, '.tif')

    task_running <- rgee::ee_manage_task()

    task_running <- task_running %>%
        filter(DestinationPath %in% all_ee_task)

    while(any(task_running$State %in% c('RUNNING', 'READY'))){
        task_running <- rgee::ee_manage_task()

        task_running <- task_running %>%
            filter(DestinationPath %in% all_ee_task)

        Sys.sleep(5)
    }
    temp_rgee <- tempfile(fileext = '.tif')

    for(i in 1:length(needed_files)){

        rel_file <- needed_files[i]

        string <- str_match(rel_file, '(.+?)X_X(.+?)X_X(.+?)\\.tif')[2:4]
        year <- string[2]
        site <- string[3]

        file_there <- googledrive::drive_get(paste0('GEE/', rel_file))

        if(nrow(file_there) == 0){ next }
        expo_backoff(
            expr = {
                googledrive::drive_download(file = paste0('GEE/', rel_file),
                                            temp_rgee,
                                            overwrite = TRUE)
            },
            max_attempts = 5
        ) %>% invisible()

        igbp_rast <- terra::rast(temp_rgee)

        igbp_rast[as.vector(terra::values(igbp_rast)) == 0] <- NA

        googledrive::drive_rm(rel_file)

        tabulated_values = terra::values(igbp_rast) %>%
            table() %>%
            as_tibble() %>%
            rename(id = '.',
                   CellTally = 'n')

        igbp_e = full_join(igbp_summary,
                           tabulated_values,
                           by = 'id')

        igbp_e <- igbp_e %>%
            mutate(percent = round((CellTally * 100) / sum(CellTally, na.rm = TRUE), 3)) %>%
            mutate(percent = ifelse(is.na(percent), 0, percent)) %>%
            select(var = macrosheds_code, val = percent) %>%
            mutate(year = !!year) %>%
            mutate(site_code = !!site)

        igbp_all = rbind(igbp_all, igbp_e)
    }

    igbp_final <- igbp_all %>%
        mutate(year = as.numeric(str_split_fixed(year, '_', n = Inf)[, 1])) %>%
        select(year, site_code, var, val)

    igbp_final <- append_unprod_prefix(igbp_final, prodname_ms)

    igbp_final <- bind_older_ws_traits(igbp_final)

    save_general_files(final_file = igbp_final,
                       domain_dir = igbp_dir)
}

#et: STATUS=READY
#. handle_errors
process_3_ms827 <- function(network, domain, prodname_ms, site_code, boundaries){

    final <- try(get_gee_standard(network = network,
                                  domain = domain,
                                  gee_id = 'MODIS/061/MOD16A2GF',
                                  band = 'ET',
                                  prodname = 'et',
                                  rez = 500,
                                  site_boundary = boundaries,
                                  batch = TRUE,
                                  contiguous_us = FALSE))

    if(is.null(final)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(final, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    final <- final$table %>%
        mutate(datetime = ymd(datetime))

    if(all(is.na(final$val)) || all(final$val == 0)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    final_ <- final %>%
        filter(var == 'et_median') %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(et_mean = mean(val, na.rm = TRUE),
                  et_sd_year = sd(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        pivot_longer(cols = c('et_mean', 'et_sd_year'),
                     names_to = 'var',
                     values_to = 'val')

    temp_sd <- final %>%
        filter(var == 'et_sd') %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = 'et_sd_space')

    final_sum <- rbind(final_, temp_sd) %>%
        select(year, site_code, var, val)

    final <- final %>%
        select(datetime, site_code, var, val)

    final <- append_unprod_prefix(final, prodname_ms)
    final_sum <- append_unprod_prefix(final_sum, prodname_ms)

    final <- bind_older_ws_traits(final)
    final_sum <- bind_older_ws_traits(final_sum)

    save_general_files(final_file = final_sum,
                       raw_file = final,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/et/'))

    return()
}

#pdsi; spei30d: STATUS=READY
#. handle_errors
process_3_ms828 <- function(network, domain, prodname_ms, site_code, boundaries){

    prodname <- prodname_from_prodname_ms(prodname_ms)

    final <- try(get_gee_standard(network = network,
                                  domain = domain,
                                  gee_id = 'GRIDMET/DROUGHT',
                                  band = prodname,
                                  prodname = prodname,
                                  rez = 4638.3,
                                  site_boundary = boundaries,
                                  batch = TRUE,
                                  contiguous_us = TRUE))

    if(is.null(final)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    if(inherits(final, 'try-error')){
        return(generate_ms_err(glue('error in retrieving {site_code}')))
    }

    final <- final$table %>%
        mutate(datetime = substr(datetime, 0, 8)) %>%
        mutate(datetime = ymd(datetime))

    if(all(is.na(final$val)) || all(final$val == 0)){
        return(generate_ms_exception(glue('No data were retrived for {site_code}')))
    }

    final_ <- final %>%
        filter(var == paste0(prodname, '_median')) %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(!!paste0(prodname, '_mean') := mean(val, na.rm = TRUE),
                  !!paste0(prodname, '_sd_year') := sd(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        pivot_longer(cols = c(paste0(prodname, '_mean'),
                              paste0(prodname, '_sd_year')),
                     names_to = 'var',
                     values_to = 'val')

    temp_sd <- final %>%
        filter(var == paste0(prodname, '_sd')) %>%
        mutate(year = year(datetime)) %>%
        group_by(site_code, year) %>%
        summarize(val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        mutate(var = paste0(prodname, '_sd_space'))

    final_sum <- rbind(final_, temp_sd) %>%
        select(year, site_code, var, val)

    final <- final %>%
        select(datetime, site_code, var, val)

    final <- append_unprod_prefix(final, prodname_ms)
    final_sum <- append_unprod_prefix(final_sum, prodname_ms)

    final <- bind_older_ws_traits(final)
    final_sum <- bind_older_ws_traits(final_sum)

    save_general_files(final_file = final_sum,
                       raw_file = final,
                       domain_dir = glue('data/{network}/{domain}/ws_traits/{prodname}/'))

    return()
}
