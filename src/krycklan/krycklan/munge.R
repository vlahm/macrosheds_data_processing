
loginfo('Beginning munge',
        logger = logger_module)

prod_info <- get_product_info(network = network,
                              domain = domain,
                              status_level = 'munge',
                              get_statuses = 'ready') %>%
    filter(! grepl(pattern = '^VERSIONLESS',
                   x = prodcode))

if(! is.null(prodname_filter)){
    prod_info <- filter(prod_info, prodname %in% prodname_filter)
}

if(nrow(prod_info) == 0) return()

for(i in seq_len(nrow(prod_info))){

    prodname_ms <<- paste0(prod_info$prodname[i], '__', prod_info$prodcode[i])

    held_data <<- get_data_tracker(network=network, domain=domain)

    if(! product_is_tracked(held_data, prodname_ms)){

        logwarn(glue('Product {p} is not yet tracked. Retrieve ',
                     'it before munging it.',
                     p = prodname_ms),
                logger = logger_module)
        next
    }

    sites <- names(held_data[[prodname_ms]])

    for(j in 1:length(sites)){

        site_code <- sites[j]

        munge_status <- get_munge_status(tracker = held_data,
                                         prodname_ms = prodname_ms,
                                         site_code = site_code)

        if(munge_status == 'ok'){

            loginfo(glue('Nothing to do for {s} {p}',
                         s = site_code,
                         p = prodname_ms),
                    logger = logger_module)
            next

        } else {
            loginfo(glue('Munging {s} {p}',
                         s = site_code,
                         p = prodname_ms),
                    logger = logger_module)
        }

        if(grepl('precip', prodname_ms)){

            munge_rtn <- munge_combined_split(
                network = network,
                domain = domain,
                prodname_ms = prodname_ms,
                site_code = sites[j],
                tracker = held_data,
                interp_control = list(
                    admit_NAs = TRUE,
                    paired_p_and_pchem = FALSE,
                    allow_pre_interp = TRUE
                ))

        } else {

            munge_rtn <- munge_combined_split(
                network = network,
                domain = domain,
                prodname_ms = prodname_ms,
                site_code = sites[j],
                tracker = held_data)
        }

        if(is_ms_err(munge_rtn)){
            update_data_tracker_m(network = network,
                                  domain = domain,
                                  tracker_name = 'held_data',
                                  prodname_ms = prodname_ms,
                                  site_code = sites[j],
                                  new_status = 'error')

        } else {
            invalidate_derived_products(successor_string = prod_info$precursor_of[i])
        }
    }

    write_metadata_m(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     tracker = held_data)

    gc()
}

loginfo('Munge complete for all versionless products',
        logger = logger_module)
