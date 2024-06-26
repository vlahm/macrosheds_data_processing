#everything here is embarrassingly parallel. make it happen by 2015.
#will need to abandon blocklist indicators in favor of products.csv
#"component" column expressions

#. handle_errors
munge_by_site <- function(network, domain, site_code, prodname_ms, tracker,
                          keep_status = 'ok',
                          spatial_regex = '(location|boundary)',
                          silent = TRUE,
                          interp_control = list()){

    #for when a data product is organized with no more than one site per file
    #(neon and konza have this arrangement). if not all components
    #will be munged, use the blocklist. an example of how to do this is given
    #by src/lter/trout_lake/processing_kernels.R:process_0_276. In some cases,
    #we've built tools to allow the "components" column in products.csv to
    #serve as a blocklist. this will not work in most cases and has been deprecated.

    #site_code is either the true name of a site, like "watershed1", or
    #   the standin "sitename_NA" that we use elsewhere. If the latter,
    #   this munge engine will look inside the munged file to determine
    #   the name of the site. This is necessary when the true site name isn't
    #   included in tracker.
    #keep_status is passed on to extract_retrieval_log
    #spatial_regex is a regex string that matches one or more prodname_ms
    #    values. If the prodname_ms being munged matches this string,
    #    write_ms_file will assume it's writing a spatial object, and not a
    #    standalone file
    #   is handled within the kernel (i.e. set this to FALSE).
    #   This is the case for neon, which reports
    #   "set" and "collect" dates for each precip chemistry capture.
    #interp_control: optional list of arguments to pass to synchronize_timestep

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_code,
                                           keep_status = keep_status)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    prodcode <- prodcode_from_prodname_ms(prodname_ms)
    processing_func <- get(paste0('process_1_', prodcode))

    is_spatial <- ifelse(grepl(spatial_regex,
                               prodname_ms),
                         TRUE,
                         FALSE)

    out <- tibble()
    for(k in 1:nrow(retrieval_log)){

        in_comp <- retrieval_log[k, 'component', drop=TRUE]

        out_comp <- sw(do.call(processing_func,
                               args = list(network = network,
                                           domain = domain,
                                           prodname_ms = prodname_ms,
                                           site_code = site_code,
                                           component = in_comp)))

        if(is_ms_err(out_comp)) return(out_comp)

        if(! is_ms_exception(out_comp)){

            if(is_spatial){

                #internal data.table error encountered here for hbef -> discharge__1
                out <- data.table::rbindlist(list(out, out_comp),
                                             use.names = TRUE,
                                             fill = TRUE) %>%
                    as_tibble()

            } else {
                out <- bind_rows(out, out_comp)
            }

        }
    }

    if(site_code == 'sitename_NA' && ! is_empty(out)){
        site_code_from_file <- unique(out$site_code)
    } else {
        site_code_from_file <- site_code
    }

    if(length(site_code_from_file) > 1){
        stop('multiple sites encountered in a dataset that should contain only one')
    }

    if(! is_empty(out)){

        if(! is_spatial){

            out <- qc_hdetlim_and_uncert(out, prodname_ms = prodname_ms)

            #sometimes files are divided up temporally, and the last
            #row of one file gets rounded to the same datetime as the first
            #row of another. It's also possible that there are gaps between
            #successive files that could be filled. we can resolve all that by
            #re-synchronizing here.
            #of course, it's mad inefficient to run this twice, so maybe we should
            #_only_ run it here. that will take some investigation though. for one
            #thing, we'd need to consider giant bind_rows operations above when
            #operating in high-res mode

            out <- do.call(synchronize_timestep,
                           args = c(list(d = out),
                                    interp_control))
        }

        write_ms_file(d = out,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_code = site_code_from_file,
                      level = 'munged',
                      shapefile = is_spatial,
                      link_to_portal = FALSE)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_code = site_code,
                          new_status = 'ok')

    msg <- glue('munged {p} ({n}/{d}/{s})',
                p = prodname_ms,
                n = network,
                d = domain,
                s = site_code)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
munge_combined <- function(network, domain, site_code, prodname_ms, tracker,
                           spatial_regex = '(location|boundary)',
                           silent = TRUE,
                           interp_control = list()){

    #for when a data product has multiple sites in each component, and
    #all components will be munged

    #spatial_regex is a regex string that matches one or more prodname_ms
    #    values. If the prodname_ms being munged matches this string,
    #    write_ms_file will assume it's writing a spatial object, and not a
    #    standalone file
    #interp_control: optional list of arguments to pass to synchronize_timestep

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_code)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    prodcode <- prodcode_from_prodname_ms(prodname_ms)
    processing_func <- get(paste0('process_1_', prodcode))

    is_spatial <- ifelse(grepl(spatial_regex,
                               prodname_ms),
                         TRUE,
                         FALSE)

    out <- tibble()
    for(k in 1:nrow(retrieval_log)){

        in_comp <- pull(retrieval_log[k, 'component'])

        out_comp <- sw(do.call(processing_func,
                               args = list(network = network,
                                           domain = domain,
                                           prodname_ms = prodname_ms,
                                           site_code = site_code,
                                           component = in_comp)))

        if(is.null(out_comp)) next

        if(is_blocklist_indicator(out_comp)){

            update_data_tracker_r(network = network,
                                  domain = domain,
                                  tracker_name = 'held_data',
                                  set_details = list(prodname_ms = prodname_ms,
                                                     site_code = site_code,
                                                     component = in_comp),
                                  new_status = 'blocklist')
            next
        }

        #BUILD THIS REGION INTO A HANDLE-ALL FUNC
        #IS IT POSSIBLE TO return(next)?

        if(is_ms_err(out_comp)) return(out_comp)

        if(! is_ms_exception(out_comp)){

            if(is_spatial){

                # out <- data.table::rbindlist(list(out, out_comp),
                    #                          use.names = TRUE,
                    #                          fill = TRUE) %>%
                    # as_tibble()

                out <- rbind(out, out_comp)

            } else {

                #internal dplyr error encountered here for konza -> precip_gauge_locations__230
                # out <- bind_rows_sf(out, as_tibble(out_comp))
                out <- bind_rows(out, out_comp)
            }

        }
    }

    sites <- unique(out$site_code)

    for(i in seq_along(sites)){

        filt_site <- sites[i]

        out_comp_filt <- filter(out, site_code == !!filt_site)

        if(! is_spatial){

            out_comp_filt <- qc_hdetlim_and_uncert(out_comp_filt,
                                                   prodname_ms = prodname_ms)

            #sometimes files are divided up temporally, and the last
            #row of one file gets rounded to the same datetime as the first
            #row of another. It's also possible that there are gaps between
            #successive files that could be filled. we can resolve all that by
            #re-synchronizing here.
            #of course, it's mad inefficient to run this twice, so maybe we should
            #_only_ run it here. that will take some investigation though. for one
            #thing, we'd need to consider giant bind_rows operations above when
            #operating in high-res mode

            out_comp_filt <- do.call(synchronize_timestep,
                                     args = c(list(d = out_comp_filt),
                                              interp_control))
        }

        write_ms_file(d = out_comp_filt,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_code = filt_site,
                      level = 'munged',
                      shapefile = is_spatial,
                      link_to_portal = FALSE)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_code = site_code,
                          new_status = 'ok')

    msg = glue('munged {p} ({n}/{d}/{s})',
               p = prodname_ms,
               n = network,
               d = domain,
               s = site_code)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
munge_combined_split <- function(network, domain, site_code, prodname_ms, tracker,
                                 spatial_regex = '(location|boundary)',
                                 silent = TRUE,
                                 interp_control = list()){

    #for when a data product has multiple sites in each component, and
    #logic governing the use of components will be handled within the kernel

    #spatial_regex is a regex string that matches one or more prodname_ms
    #   values. If the prodname_ms being munged matches this string,
    #   write_ms_file will assume it's writing a spatial object, and not a
    #   standalone file
    #interp_control: optional list of arguments to pass to synchronize_timestep

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_code)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    prodcode <- prodcode_from_prodname_ms(prodname_ms)

    is_spatial <- ifelse(grepl(spatial_regex,
                               prodname_ms),
                         TRUE,
                         FALSE)

    processing_func <- get(paste0('process_1_', prodcode))

    if(! 'component' %in% colnames(retrieval_log)){
        retrieval_log$component <- 'placeholder'
    }

    components <- pull(retrieval_log, component)
        # rename_with(~sub('^component$', 'components', .)) %>%
        # pull(components)

    out_comp <- sw(do.call(processing_func,
                           args = list(network = network,
                                       domain = domain,
                                       prodname_ms = prodname_ms,
                                       site_code = site_code,
                                       components = components)))

    if(is_ms_err(out_comp)){
        return(out_comp)
    }

    if(is_blocklist_indicator(out_comp)){
        logwarn(glue('Skipping product {p} (for now?)',
                     p = prodname_ms))
        return(out_comp)
    }

    sites <- unique(out_comp$site_code)

    for(i in 1:length(sites)){

        filt_site <- sites[i]
        out_comp_filt <- filter(out_comp, site_code == filt_site)

        if(! is_spatial){

            out_comp_filt <- qc_hdetlim_and_uncert(out_comp_filt,
                                                   prodname_ms = prodname_ms)

            #sometimes files are divided up temporally, and the last
            #row of one file gets rounded to the same datetime as the first
            #row of another. It's also possible that there are gaps between
            #successive files that could be filled. we can resolve all that by
            #re-synchronizing here.
            #of course, it's mad inefficient to run this twice, so maybe we should
            #_only_ run it here. that will take some investigation though. for one
            #thing, we'd need to consider giant bind_rows operations above when
            #operating in high-res mode

            out_comp_filt <- do.call(synchronize_timestep,
                                     args = c(list(d = out_comp_filt),
                                              interp_control))
        }

        write_ms_file(d = out_comp_filt,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_code = filt_site,
                      level = 'munged',
                      shapefile = is_spatial,
                      link_to_portal = FALSE)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_code = site_code,
                          new_status = 'ok')

    msg <- glue('munged {p} ({n}/{d}/{s})',
                p = prodname_ms,
                n = network,
                d = domain,
                s = site_code)

    loginfo(msg, logger = logger_module)

    return()
}

#. handle_errors
munge_time_component <-  function(network, domain, site_code, prodname_ms, tracker,
                                  silent = TRUE){

    # Used when a data product is a subset of the entire record, such as individual
    # data product of each year of a hydrology record. When this is used, a derive
    # kernel is necessary to combine data products and perform
    # qc_hdetlim_and_uncert() and synchronize_timestep(), which are normally run
    # in the munge engine
    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_code)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    out <- tibble()
    for(k in 1:nrow(retrieval_log)){

        prodcode <- prodcode_from_prodname_ms(prodname_ms)

        processing_func <- get(paste0('process_1_', prodcode))
        in_comp <- pull(retrieval_log[k, 'component'])

        out_comp <- sw(do.call(processing_func,
                               args = list(network = network,
                                           domain = domain,
                                           prodname_ms = prodname_ms,
                                           site_code = site_code,
                                           component = in_comp)))

        if(is.null(out_comp)) next

        if(is_blocklist_indicator(out_comp)){
            update_data_tracker_r(network = network,
                                  domain = domain,
                                  tracker_name = 'held_data',
                                  set_details = list(prodname_ms = prodname_ms,
                                                     site_code = site_code,
                                                     component = in_comp),
                                  new_status = 'blocklist')
            next
        }

        #BUILD THIS REGION INTO A HANDLE-ALL FUNC
        #IS IT POSSIBLE TO return(next)?

        if(is_ms_err(out_comp)) return(out_comp)

        if(! is_ms_exception(out_comp)){
            out <- bind_rows(out, out_comp)
        }
    }

    sites <- unique(out$site_code)

    for(i in 1:length(sites)){

        filt_site <- sites[i]
        out_filt <- filter(out, site_code == filt_site)

        prod_dir <- glue('data/{n}/{d}/munged/{p}',
                         n = network,
                         d = domain,
                         p = prodname_ms)

        dir.create(prod_dir,
                   showWarnings = FALSE,
                   recursive = TRUE)

        site_file <- glue('{pd}/{s}.feather',
                          pd = prod_dir,
                          s = sites[i])

        write_feather(out_filt, site_file)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_code = site_code,
                          new_status = 'ok')

    msg <- glue('munged {p} ({n}/{d}/{s})',
                p = prodname_ms,
                n = network,
                d = domain,
                s = site_code)

    loginfo(msg,
            logger = logger_module)

    return()
}
