#junk functions, possibly useful for parts

# obsolete kernels ####

process_0_DP1.20093.001_api = function(d, set_details){

    data1_ind = intersect(grep("expanded", d$data$files$name),
        grep("fieldSuperParent", d$data$files$name))
    data2_ind = intersect(grep("expanded", d$data$files$name),
        grep("externalLabData", d$data$files$name))
    data3_ind = intersect(grep("expanded", d$data$files$name),
        grep("domainLabData", d$data$files$name))

    data1 = tryCatch({
        read.delim(d$data$files$url[data1_ind], sep=",",
            stringsAsFactors=FALSE)
    }, error=function(e){
        data.frame()
    })
    data2 = tryCatch({
        read.delim(d$data$files$url[data2_ind], sep=",",
            stringsAsFactors=FALSE)
    }, error=function(e){
        data.frame()
    })
    data3 = tryCatch({
        read.delim(d$data$files$url[data3_ind], sep=",",
            stringsAsFactors=FALSE)
    }, error=function(e){
        data.frame()
    })

    if(nrow(data1)){
        data1 = select(data1, siteID, collectDate, dissolvedOxygen,
            dissolvedOxygenSaturation, specificConductance, waterTemp,
            maxDepth)
    }
    if(nrow(data2)){
        data2 = select(data2, siteID, collectDate, pH, externalConductance,
            externalANC, starts_with('water'), starts_with('total'),
            starts_with('dissolved'), uvAbsorbance250, uvAbsorbance284,
            shipmentWarmQF, externalLabDataQF)
    }
    if(nrow(data3)){
        data3 = select(data3, siteID, collectDate, starts_with('alk'),
            starts_with('anc'))
    }

    out_sub = plyr::join_all(list(data1, data2, data3), type='full') %>%
        group_by(collectDate) %>%
        summarise_each(list(~ if(is.numeric(.)){
            mean(., na.rm = TRUE)
        } else {
            first(.)
        })) %>%
        ungroup() %>%
        mutate(datetime=as.POSIXct(collectDate, tz='UTC',
            format='%Y-%m-%dT%H:%MZ')) %>%
        select(-collectDate)

    return(out_sub)
} #chem: obsolete

process_0_DP1.20288.001_api = function(d, set_details){

    data_inds = intersect(grep("expanded", d$data$files$name),
        grep("instantaneous", d$data$files$name))

    site_with_suffixes = determine_upstream_downstream(d, data_inds,
        set_details)
    if(is_ms_err(site_with_suffixes)) return(site_with_suffixes)

    #process upstream and downstream sites independently
    for(j in 1:length(data_inds)){

        site_with_suffix = site_with_suffixes[j]

        #download data
        out_sub = read.delim(d$data$files$url[data_inds[j]], sep=",",
            stringsAsFactors=FALSE)

        out_sub = resolve_neon_naming_conflicts(out_sub,
            set_details_=set_details,
            replacements=c('specificCond'='specificConductance',
                'dissolvedOxygenSat'='dissolvedOxygenSaturation'))
        if(is_ms_err(out_sub)) return(out_sub)

        out_sub = mutate(out_sub,
            datetime=as.POSIXct(startDateTime,
                tz='UTC', format='%Y-%m-%dT%H:%M:%SZ'),
            site=site_with_suffix) %>%
            select(-startDateTime)
    }

    return(out_sub)
} #waterqual: obsolete

resolve_neon_naming_conflicts_OBSOLETE = function(out_sub_, replacements=NULL,
    from_api=FALSE, set_details_){

    #obsolete now that neonUtilities package is working

    #replacements is a named vector. name=find, value=replace;
    #failed match does nothing

    prodcode = set_details_$prodcode
    site = set_details_$site
    date = set_details_$date

    out_cols = colnames(out_sub_)

    if(! is.null(replacements)){

        #get list of variables included
        varind = grep('SciRvw', out_cols)
        rgx = str_match(out_cols[varind], '^(\\w*)(?:FinalQFSciRvw|SciRvwQF)$')
        # varlist = flagprefixlist = rgx[,2]
        varlist = rgx[,2]

        #harmonize redundant variable names
        for(i in 1:length(replacements)){
            r = replacements[i]
            varlist = replace(varlist, which(varlist == names(r)), r)
        }
    }

    if('startDate' %in% out_cols){
        colnames(out_sub_) = replace(out_cols, which(out_cols == 'startDate'),
            'startDateTime')
    } else if('endDate' %in% out_cols){
        colnames(out_sub_) = replace(out_cols, which(out_cols == 'endDate'),
            'startDateTime') #not a mistake
    } else if(! 'startDateTime' %in% out_cols){
        msg = glue('Datetime column not found for site ',
            '{site} ({prodname_ms}, {date}).', site=site, prodname_ms=prodcode, date=date)
        logwarn(msg, logger=logger_module)
        return(generate_ms_err())
    }

    #subset relevant columns (needed if NEON API was used)
    if(from_api){
        flagcols = grepl('.+?FinalQF(?!SciRvw)', out_cols,
            perl=TRUE)
        datacols = ! grepl('QF', out_cols, perl=TRUE)
        relevant_cols = flagcols | datacols
        out_sub_ = out_sub_[, relevant_cols]
    }

    return(out_sub_)
}

determine_upstream_downstream_api_OBSOLETE = function(d_, data_inds_, set_details_){
    #obsolete now that neonUtilities package is working

    prodcode = set_details_$prodcode
    site = set_details_$site
    date = set_details_$date

    #determine which dataset is upstream/downstream if necessary
    updown_suffixes = c('-up', '-down')
    if(length(data_inds_) == 2){
        position = str_split(d_$data$files$name[data_inds_[1]], '\\.')[[1]][7]
        updown_order = if(position == '101') 1:2 else 2:1
    } else if(length(data_inds_) == 1){
        updown_order = 1
    } else {
        msg = glue('Problem with upstream/downstream indicator for site ',
            '{site} ({prodname_ms}, {date}).', site=site, prodname_ms=prodcode, date=date)
        logwarn(msg, logger=logger_module)
        return(generate_ms_err())
    }

    site_with_suffixes = paste0(site, updown_suffixes[updown_order])

    return(site_with_suffixes)
}

#precipitation: STATUS=TEST (hbef)
process_2_13TEST <- function(network, domain, prodname_ms){

    #910.945x slower than shortcut method

    #load precipitation data, watershed boundaries, rain gauge locations
    precip2 <- read_combine_feathers(network, domain, prodname_ms)
    wb <- read_combine_shapefiles(network, domain, 'ws_boundary__94')
    rg <- read_combine_shapefiles(network, domain, 'precip_gauge_locations__100')

    #project based on average latlong of watershed boundaries
    bbox <- as.list(sf::st_bbox(wb))
    projstring <- choose_projection(lat = mean(bbox$ymin, bbox$ymax),
                                    long = mean(bbox$xmin, bbox$xmax))
    wb <- sf::st_transform(wb, projstring)
    rg <- sf::st_transform(rg, projstring)

    #get a DEM that encompasses all watersheds
    dem <- sm(elevatr::get_elev_raster(wb, z = 12))

    precip2 <- precip2 %>%
        mutate(datetime = lubridate::year(datetime)) %>% #temporary
        group_by(site_name, datetime) %>%
        summarize(
            precip = mean(precip, na.rm=TRUE),
            ms_status = numeric_any(ms_status)) %>%
        ungroup() %>%
        filter(site_name %in% rg$site_name)

    for(j in 1){
        # for(j in 1:nrow(wb)){

        wbj <- slice(wb, j)
        site_name <- wbj$site_name
        dem_wbj <- terra::crop(dem, wbj)
        dem_wbj <- terra::mask(dem_wbj, wbj)

        #calculate mean watershed precipitation for every timestep
        ws_mean_precip <- rep(NA, nrow(precip))
        timesteps <- unique(precip2$datetime)
        for(k in 1:length(timesteps)){

            precip_k <- precip2 %>%
                filter(datetime == timesteps[k]) %>%
                left_join(rg) %>%
                sf::st_as_sf()

            # zz <- bind_cols(precip_k, as_tibble(sf::st_coordinates(precip_k$geometry)))
            # zz2 = sf::st_read('~/Downloads/hmm/hbef_raingage/hbef_raingage.shp')
            gs <- gstat::gstat(formula = precip~1,
                               locations = precip_k)
            idw <- interpolate(dem, gs)
            idw_mask <- raster::mask(idw, wbj)
            ws_mean_precip[k] <- raster::values(idw_mask) %>%
                mean(., na.rm = TRUE)
        }

        site_precip2 <- tibble(datetime = precip_dt,
                               site_name = site_name,
                               precip = ws_mean_precip,
                               ms_status = precip_status)
    }

    #interp final precip to a desirable interval?
    return()
}

#precipitation: STATUS=OBSOLETE (hbef)
process_2_13OBS <- function(network, domain, prodname_ms){

    #this logic is temporary, and just gets precip into the format that works
    #with the portal. but once interp is working, we'll perform that here
    #instead

    mfiles <- list_munged_files(network = network,
                                domain = domain,
                                prodname_ms = prodname_ms)

    combined <- tibble()
    for(f in mfiles){
        d = read_feather(f)
        combined <- bind_rows(combined, d)
    }

    #this chunk will be replaced by create_portal_link when interp is ready
    prod_dir = glue('data/{n}/{d}/derived/{p}', n=network, d=domain,
                    p=prodname_ms)
    dir.create(prod_dir, showWarnings=FALSE, recursive=TRUE)
    site_file <- glue('data/{n}/{d}/derived/{p}/precip.feather',
                      n = network,
                      d = domain,
                      p = prodname_ms)
    write_feather(combined, site_file)
    portal_site_file <- glue('../portal/data/{d}/precip.feather', d = domain)
    unlink(portal_site_file)
    invisible(sw(file.link(to = portal_site_file, from = site_file)))

    gc()
    return()
}

#precip_chemistry: STATUS=OBSOLETE (hbef)
process_2_208OBS <- function(network, domain, prodname_ms){

    #this logic is temporary, and just gets pchem into the format that works
    #with the portal. but once interp is working, we'll perform that here
    #instead

    mfiles <- ue(list_munged_files(network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms))

    combined <- tibble()
    for(f in mfiles){
        d = read_feather(f)
        combined <- bind_rows(combined, d)
    }

    #this chunk will be replaced by create_portal_link when interp is ready
    prod_dir = glue('data/{n}/{d}/derived/{p}', n=network, d=domain,
                    p=prodname_ms)
    dir.create(prod_dir, showWarnings=FALSE, recursive=TRUE)
    site_file <- glue('data/{n}/{d}/derived/{p}/precip.feather',
                      n = network,
                      d = domain,
                      p = prodname_ms)
    write_feather(combined, site_file)
    portal_site_file <- glue('../portal/data/{d}/precip.feather', d = domain)
    unlink(portal_site_file)
    invisible(sw(file.link(to = portal_site_file, from = site_file)))

    return()
}

#precip_flux_inst: STATUS=OBSOLETE (hbef; must localize precip to stream sites first)
process_2_ms002 <- function(network, domain, prodname_ms){

    chemprod <- 'precip_chemistry__208'
    qprod <- 'precipitation__13'

    chemfiles <- ue(list_munged_files(network = network,
                                      domain = domain,
                                      prodname_ms = chemprod))
    qfiles <- ue(list_munged_files(network = network,
                                   domain = domain,
                                   prodname_ms = qprod))

    flux_sites <- generics::intersect(
        ue(fname_from_fpath(qfiles, include_fext = FALSE)),
        ue(fname_from_fpath(chemfiles, include_fext = FALSE)))

    for(s in flux_sites){

        flux <- sw(ue(calc_inst_flux(chemprod = chemprod,
                                     qprod = qprod,
                                     site_name = s,
                                     dt_round_interv = 'hours')))

        ue(write_ms_file(d = flux,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms,
                         site_name = s,
                         level = 'derived',
                         shapefile = FALSE,
                         link_to_portal = TRUE))
    }

    return()
}

### attempt to bundle all idw loggers (environment issues) ####
#. handle_errors
idw_log <- function(phase, from_env, ...){

    #phase is one of "wb" (watershed boundary), "var" (variable), or
    #   "ts" (timestep), corresponding to the phase of idw processing that
    #   should be logged.
    #from_env is the environment in which to look for variables passed as
    #   positional arguments. This will usually be the parent environment of
    #   idw_log and can be specified in the call as from_env = environment()
    #... must contain any variables needed inside the subsection of
    #   idw_log specified by phase.

    if(! verbose) return()

    #populate positional arguments in local environment
    dots = match.call(expand.dots = FALSE)$...
    names = vapply(dots, as.character, '')
    vars = mget(names, inherits = TRUE)
    thisenv = environment()
    mapply(function(n, v) assign(n, v, envir = thisenv),
           names,
           vars)

    #log the specified phase of idw processing
    if(phase == 'wb'){

        msg <- glue('site: {s}; {ii}/{w}',
                    s = site_name,
                    ii = i,
                    w = nrow(wb))

    } else if(phase == 'var'){

        msg <- glue('site: {s}; var: {vv}; {jj}/{nv}',
                    s = site_name,
                    vv = v,
                    jj = j,
                    nv = nvars)

    } else if(phase == 'ts'){

        if(k == 1 || k %% 1000 == 0){
            msg <- glue('timestep: {kk}/{nt}',
                        kk = k,
                        nt = ntimesteps)
        }

    } else {
        stop('phase must be one of "wb", "var", "ts"')
    }

    loginfo(msg,
            logger = logger_module)

    return()
}

### test code####
    desired_interval = '5 days'; impute_limit=30
    # saveRDS(ws_mean_precip, '~/Desktop/ws_precip_temp.rds')
    ws_mean_precip = readRDS('~/Desktop/ws_precip_temp.rds') %>%
        mutate(datetime = as_datetime(as.character(datetime), format='%Y'))
    w2 = w3 = ws_mean_precip
    w2$datetime = as.POSIXct(1:nrow(w2), origin='2000-01-01', tz = 'UTC')
    w3$precip[c(3:9, 15)] = NA
    w4 = w3
    w4$ms_interp = 0

    ms_df = ws_mean_precip
    ms_df = w2
    ms_df = w3
    ms_df = w4

#in case we ever want to track changes in detection limits through time ####

#all kernels would also have to be modified so that datetime is determined
    #before detection limit is decided. an accurate datetime column
    #is needed to calculate temporally explicit detlims

