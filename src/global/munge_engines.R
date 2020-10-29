#. handle_errors
munge_by_site <- function(network, domain, site_name, prodname_ms, tracker,
                          spatial_regex = '(location|boundary)',
                          silent = TRUE){

    #for when a data product is organized with one site per file
    #(neon and konza have this arrangement). if not all components
    #will be munged, use the "components" column in products.csv

    #site_name is either the true name of a site, like "watershed1", or
    #   the standin "sitename_NA" that we use elsewhere. If the latter,
    #   this munge engine will look inside the munged file to determine
    #   the name of the site. This is necessary when the true site name isn't
    #   included in tracker.
    #spatial_regex is a regex string that matches one or more prodname_ms
    #    values. If the prodname_ms being munged matches this string,
    #    write_ms_file will assume it's writing a spatial object, and not a
    #    standalone file

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_name)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    out <- tibble()
    for(k in 1:nrow(retrieval_log)){

        prodcode <- prodcode_from_prodname_ms(prodname_ms)

        processing_func <- get(paste0('process_1_', prodcode))
        in_comp <- retrieval_log[k, 'component', drop=TRUE]

        out_comp <- sw(do.call(processing_func,
                               args = list(network = network,
                                           domain = domain,
                                           prodname_ms = prodname_ms,
                                           site_name = site_name,
                                           component = in_comp)))

        if(! is_ms_err(out_comp) && ! is_ms_exception(out_comp)){
            out = bind_rows(out, out_comp)
        }
    }

    if(site_name == 'sitename_NA' && ! is_empty(out)) site_name <- unique(out$site_name)

    if(length(site_name) > 1) {
        stop('multiple sites encountered in a dataset that should contain only one')
    }

    if(! is_empty(out)){

        is_spatial <- ifelse(grepl(spatial_regex,
                                   prodname_ms),
                             TRUE,
                             FALSE)

        write_ms_file(d = out,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = site_name,
                      level = 'munged',
                      shapefile = is_spatial,
                      link_to_portal = FALSE)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_name = site_name,
                          new_status = 'ok')

    msg <- glue('munged {p} ({n}/{d}/{s})',
                p = prodname_ms,
                n = network,
                d = domain,
                s = site_name)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
munge_combined <- function(network, domain, site_name, prodname_ms, tracker,
                           spatial_regex = '(location|boundary)',
                           silent = TRUE){

    #for when a data product has multiple sites in each component, and
    #all components will be munged

    #spatial_regex is a regex string that matches one or more prodname_ms
    #    values. If the prodname_ms being munged matches this string,
    #    write_ms_file will assume it's writing a spatial object, and not a
    #    standalone file

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_name)
        # filter(component != "Analytical Methods")

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
                                           site_name = site_name,
                                           component = in_comp)))

        if(is.null(out_comp)) next

        if(is_blacklist_indicator(out_comp)){
            update_data_tracker_r(network = network,
                                  domain = domain,
                                  tracker_name = 'held_data',
                                  set_details = list(prodname_ms = prodname_ms,
                                                     site_name = site_name,
                                                     component = in_comp),
                                  new_status = 'blacklist')
            next
        }

        #BUILD THIS REGION INTO A HANDLE-ALL FUNC
        #IS IT POSSIBLE TO return(next)?

        if(! is_ms_err(out_comp) && ! is_ms_exception(out_comp)){
            out <- bind_rows(out, out_comp)
        }

        sites <- unique(out_comp$site_name)

        for(i in 1:length(sites)){

            filt_site <- sites[i]
            out_comp_filt <- filter(out_comp, site_name == filt_site)

            is_spatial <- ifelse(grepl(spatial_regex,
                                       prodname_ms),
                                 TRUE,
                                 FALSE)

            write_ms_file(d = out_comp_filt,
                          network = network,
                          domain = domain,
                          prodname_ms = prodname_ms,
                          site_name = filt_site,
                          level = 'munged',
                          shapefile = is_spatial,
                          link_to_portal = FALSE)
        }
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_name = site_name,
                          new_status = 'ok')

    msg = glue('munged {p} ({n}/{d}/{s})',
               p = prodname_ms,
               n = network,
               d = domain,
               s = site_name)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
munge_combined_split <- function(network, domain, site_name, prodname_ms, tracker,
                                 spatial_regex = '(location|boundary)',
                                 silent = TRUE){

    #for when a data product has multiple sites in each component, and
    #logic governing the use of components will be handled within the kernel

    #spatial_regex is a regex string that matches one or more prodname_ms
    #   values. If the prodname_ms being munged matches this string,
    #   write_ms_file will assume it's writing a spatial object, and not a
    #   standalone file

    # tracker=held_data; k=1

    retrieval_log <- extract_retrieval_log(tracker,
                                           prodname_ms,
                                           site_name)

    if(nrow(retrieval_log) == 0){
        return(generate_ms_err('missing retrieval log'))
    }

    prodcode <- prodcode_from_prodname_ms(prodname_ms)

    processing_func <- get(paste0('process_1_', prodcode))
    components <- pull(retrieval_log, component)

    out_comp <- sw(do.call(processing_func,
                           args = list(network = network,
                                       domain = domain,
                                       prodname_ms = prodname_ms,
                                       site_name = site_name,
                                       components = components)))

    if(is_ms_err(out_comp)){
        return(out_comp)
    }

    sites <- unique(out_comp$site_name)

    for(i in 1:length(sites)){

        filt_site <- sites[i]
        out_comp_filt <- filter(out_comp, site_name == filt_site)

        is_spatial <- ifelse(grepl(spatial_regex,
                                   prodname_ms),
                             TRUE,
                             FALSE)

        write_ms_file(d = out_comp_filt,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = filt_site,
                      level = 'munged',
                      shapefile = is_spatial,
                      link_to_portal = FALSE)
    }

    update_data_tracker_m(network = network,
                          domain = domain,
                          tracker_name = 'held_data',
                          prodname_ms = prodname_ms,
                          site_name = site_name,
                          new_status = 'ok')

    msg = glue('munged {p} ({n}/{d}/{s})',
               p = prodname_ms,
               n = network,
               d = domain,
               s = site_name)

    loginfo(msg,
            logger = logger_module)

    return()
}
