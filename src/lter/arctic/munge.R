loginfo('Beginning munge', logger=logger_module)

prod_info <- get_product_info(network = network,
                             domain = domain,
                             status_level = 'munge',
                             get_statuses = 'ready')

# i=5
for(i in 1:nrow(prod_info)){

    prodname_ms <<- paste0(prod_info$prodname[i], '__', prod_info$prodcode[i])

    held_data <<- get_data_tracker(network=network, domain=domain)

    if(! product_is_tracked(held_data, prodname_ms)){
        logwarn(glue('Product {p} is not yet tracked. Retrieve ',
                     'it before munging it.', p=prodname_ms), logger=logger_module)
        next
    }

    sites <- names(held_data[[prodname_ms]])

    #j = 1
    for(j in 1:length(sites)){

        site_name <- sites[j]

        munge_status <- get_munge_status(tracker = held_data,
                                         prodname_ms = prodname_ms,
                                         site_name = site_name)
        if(munge_status == 'ok'){
            loginfo(glue('Nothing to do for {s} {p}',
                       s=site_name, p=prodname_ms), logger=logger_module)
            next
        } else {
            loginfo(glue('Munging {s} {p}',
                         s=site_name, p=prodname_ms), logger=logger_module)
        }

        munge_rtn <- munge_combined(network = network,
                                    domain = domain,
                                    site_name = site_name,
                                    prodname_ms = prodname_ms,
                                    tracker = held_data)

        if(is_ms_err(munge_rtn)){

            logging::logerror(as.character(munge_rtn))
            update_data_tracker_m(network = network,
                                  domain = domain,
                                  tracker_name = 'held_data',
                                  prodname_ms = prodname_ms,
                                  site_name = site_name,
                                  new_status = 'error')

        } else if(is_blacklist_indicator(munge_rtn)){
            next
        } else {
            invalidate_derived_products(
                successor_string = prod_info$precursor_of[i])
        }
    }

    write_metadata_m(network = network,
                     domain = domain,
                     prodname_ms = prodname_ms,
                     tracker = held_data)

    gc()
}

loginfo('Munging complete for all sites and products',
        logger=logger_module)
