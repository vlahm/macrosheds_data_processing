#functions without the "#. handle_errors" decorator have special error handling

handle_errors = function(f){

    #decorator function. takes any function as argument and executes it.
    #if error occurs within passed function, combines error message and
    #pretty callstack as single message, logs and emails this message.
    #returns custom macrosheds (ms) error class.

    #TODO: log unabridged callstack, email pretty one

    wrapper = function(...){

        thisenv = environment()

        tryCatch({
            return_val = f(...)
        }, error=function(e){

            err_cnt_new = err_cnt + 1
            assign('err_cnt', err_cnt_new, pos=.GlobalEnv)

            err_msg = as.character(e)
            if(! err_msg %in% unique_errors){
                unique_errors_new = append(unique_errors, err_msg)
                assign('unique_errors', unique_errors_new, pos=.GlobalEnv)
            }

            pretty_callstack = pprint_callstack()

            if(exists('s')) site_name = s
            if(! exists('site_name')) site_name = 'NO SITE'
            if(! exists('prodname_ms')) prodname_ms = 'NO PRODUCT'

            full_message = glue('{ec}\n\n',
                                'NETWORK: {n}\nDOMAIN: {d}\nSITE: {s}\n',
                                'PRODUCT: {p}\nERROR_MSG: {e}\nMS_CALLSTACK: {c}\n\n_',
                                ec=err_cnt, n=network, d=domain, s=site_name, p=prodname_ms,
                                e=err_msg, c=pretty_callstack)

            logerror(full_message, logger=logger_module)

            email_err_msgs = append(email_err_msgs, full_message)
            assign('email_err_msgs', email_err_msgs, pos=.GlobalEnv)

            assign('return_val', generate_ms_err(full_message), pos=thisenv)

        })

        if(is_ms_exception(return_val)){

            exception_msg = as.character(return_val)

            if(! exception_msg %in% unique_exceptions){
                unique_exceptions_new = append(unique_exceptions, exception_msg)
                assign('unique_exceptions', unique_exceptions_new,
                       pos=.GlobalEnv)
            }

            message(glue('MS Exception: ', exception_msg))
        }

        if(! is.null(return_val)) return(return_val)
    }

    return(wrapper)
}

source('src/global/function_aliases.R')
source_decoratees('src/global/munge_engines.R')

assign('email_err_msgs', list(), envir=.GlobalEnv)
assign('err_cnt', 0, envir=.GlobalEnv)
assign('unique_errors', c(), envir=.GlobalEnv)
assign('unique_exceptions', c(), envir=.GlobalEnv)

#exports from an attempt to use socket cluster parallelization;
# idw_pkg_export <- c('logging', 'errors', 'jsonlite', 'plyr',
#                     'tidyverse', 'lubridate', 'feather', 'glue',
#                     'emayili', 'tinsel', 'imputeTS')
# idw_var_export <- c('logger_module', 'err_cnt')

#these are column names that are in every non-spatial macrosheds dataset by the
#time it reaches its final formatted/cleaned state. we sometimes want to ignore
#these columns when operating on ms tibbles/feathers. this list may also grow.
assign('ms_canonicals',
       c('datetime', 'site_name', 'ms_status', 'ms_interp'),
       envir = .GlobalEnv)

# flag systems (future use?; increasing user value and difficulty to manage):

# system1: binary status (0=chill, 1=unchill)
# system2: 0=chill, 1=unit_unknown, 2=unit_concern, 4=other_concern
# system3: 0=chill, 1=unit_unknown, 2=unit_concern,
#4=method_unknown, 8=method_concern, 16=other_concern
# system4: 0=chill, 1=unit_unknown, 2=unit_concern,
#4=method_unknown, 8=method_concern, 16=sensor_concern, 32=general_concern
flagmap = list(
    clean=c(), #0
    method_unknown=c(), #1; method not given
    method_concern=c(), #2; method known to be lame
    #--- flagsum <= 3: ok
    #--- flagsum > 3: dirty
    sensor_concern=c(), #4; keywords: sensor*, expos*, detect*
    unit_unknown=c(), #8; unit not given
    unit_concern=c(), #16; unit unclear or inconvertible
    general_concern=c() #32; keywords:
)

#ue stands for "unhandle_errors"; wrap this around any ms function
#that is called inside a processing kernel
ue <- function(o){
    if(is_ms_err(o)) stop('The previous error has been unhandled.', call. = FALSE)
    else return(o)
}

pprint_callstack = function(){

    #make callstack more informative. if we end up sourcing files rather than
    #packaging, print which files were sourced along with callstack.

    # zz = as.list(sys.calls())
    # zx[[zxc]] <<- zz
    # zxc <<- zxc + 1
    # call_list = zz
    # # call_list = zx[[1]]

    call_list = as.list(sys.calls())
    call_names = sapply(call_list, all.names, max.names=2)
    ms_entities = grep('pprint', ls(envir=.GlobalEnv), value=TRUE, invert=TRUE)
    ms_calls_bool = sapply(call_names, function(x) any(x %in% ms_entities))
    # call_vec = call_vec[call_vec != 'pprint_callstack']

    # l = length(call_list)
    # call_list_cleaned = call_list[-((l - 4):l)]
    call_list_cleaned = call_list[ms_calls_bool]
    call_vec = unlist(lapply(call_list_cleaned,
                             function(x){
                                 paste(deparse(x), collapse='\n')
                             }))

    call_string_pretty = paste(call_vec, collapse=' -->\n\t')

    return(call_string_pretty)
}

#errors are not handled for this function because it is used inside pipelines that
#are used inside processing kernels, so it can't be wrapped in ue(). Find a way to
#make ue() pipelineable and this numeric_any can be decorated
numeric_any <- function(num_vec){
    return(as.numeric(any(as.logical(num_vec))))
}

#. handle_errors
sourceflags_to_ms_status <- function(d, flagstatus_mappings,
                                     exclude_mapvals = rep(FALSE, length(flagstatus_mappings))){

    #d is a df/tibble with flag and/or status columns
    #flagstatus_mappings is a list of flag or status column names mapped to
    #vectors of values that might be encountered in those columns.
    #see exclude_mapvals.
    #exclude_mapvals: a boolean vector of length equal to the length of
    #flagstatus_mappings. for each FALSE, values in the corresponding vector
    #are treated as OK values (mapped to ms_status 0). values
    #not in the vector are treated as flagged (mapped to ms_status 1).
    #For each TRUE, this relationship is inverted, i.e. values *in* the
    #corresponding vector are treated as flagged.

    flagcolnames = names(flagstatus_mappings)
    d = mutate(d, ms_status = 0)

    for(i in 1:length(flagstatus_mappings)){
        # d = filter(d, !! sym(flagcolnames[i]) %in% flagcols[[i]])
        # d = mutate(d,
        #     ms_status = ifelse(flagcolnames[i] %in% flagcols[[i]], 0, 1))

        if(exclude_mapvals[i]){
            ok_bool = ! d[[flagcolnames[i]]] %in% flagstatus_mappings[[i]]
        } else {
            ok_bool = d[[flagcolnames[i]]] %in% flagstatus_mappings[[i]]
        }

        d$ms_status[! ok_bool] = 1
    }

    d = select(d, -one_of(flagcolnames))

    return(d)
}

#. handle_errors
export_to_global <- function(from_env, exclude=NULL){

    #exclude is a character vector of names not to export.
    #unmatched names will be ignored.

    #vars could also be passed individually and handled by ...
    # vars = list(...)
    # varnames = all.vars(match.call())

    varnames = ls(name=from_env)
    varnames = varnames[! varnames %in% exclude]
    vars = mget(varnames, envir=from_env)

    for(i in 1:length(varnames)){
        assign(varnames[i], vars[[i]], .GlobalEnv)
    }

    return()
}

#. handle_errors
get_all_local_helpers <- function(network=domain, domain){

    #source_decoratees reads in decorator functions (tinsel package).
    #because it can only read them into the current environment, all files
    #sourced by this function are exported locally, then exported globally

    location1 = glue('src/{n}/network_helpers.R', n=network)
    if(file.exists(location1)){
        sw(source(location1, local=TRUE))
        sw(source_decoratees(location1))
    }

    location2 = glue('src/{n}/{d}/domain_helpers.R', n=network, d=domain)
    if(file.exists(location2)){
        sw(source(location2, local=TRUE))
        sw(source_decoratees(location2))
    }

    location3 = glue('src/{n}/processing_kernels.R', n=network)
    if(file.exists(location3)){
        sw(source(location3, local=TRUE))
        sw(source_decoratees(location3))
    }

    location4 = glue('src/{n}/{d}/processing_kernels.R', n=network, d=domain)
    if(file.exists(location4)){
        sw(source(location4, local=TRUE))
        sw(source_decoratees(location4))
    }

    rm(location1, location2, location3, location4)

    export_to_global(from_env=environment(),
                     exclude=c('network', 'domain', 'thisenv'))

    return()
}

#. handle_errors
set_up_logger <- function(network=domain, domain){

    #the logging package establishes logger hierarchy based on name.
    #our root logger is named "ms", and our network-domain loggers are named
    #ms.network.domain, e.g. "ms.lter.hbef". When messages are logged, loggers
    #are referred to as name.module. A message logged to
    #logger="ms.lter.hbef.module" would be handled by loggers named
    #"ms.lter.hbef", "ms.lter", and "ms", some of which may not have established
    #handlers

    logger_name = glue('ms.{n}.{d}', n=network, d=domain)
    logger_module = glue(logger_name, '.module')

    if(! dir.exists('logs')){
        dir.create('logs')
    }

    logging::addHandler(logging::writeToFile, logger=logger_name,
                        file=glue('logs/{n}_{d}.log', n=network, d=domain))

    return(logger_module)
}

#. handle_errors
extract_from_config <- function(key){
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = stringr::str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}

#. handle_errors
clear_from_mem <- function(..., clearlist){

    if(missing(clearlist)){
        dots = match.call(expand.dots = FALSE)$...
        clearlist = vapply(dots, as.character, '')
    }

    rm(list=clearlist, envir=.GlobalEnv)
    gc()

    return()
}

#. handle_errors
retain_ms_globals <- function(retain_vars){

    all_globals = ls(envir=.GlobalEnv, all.names=TRUE)
    clutter = all_globals[! all_globals %in% retain_vars]

    clear_from_mem(clearlist=clutter)

    return()
}

generate_ms_err = function(text=1){
    errobj = text
    class(errobj) = 'ms_err'
    return(errobj)
}

generate_ms_exception = function(text=1){
    excobj = text
    class(excobj) = 'ms_exception'
    return(excobj)
}

generate_blacklist_indicator = function(text=1){
    indobj = text
    class(indobj) = 'blacklist_indicator'
    return(indobj)
}

#. handle_errors
is_ms_err <- function(x){
    return('ms_err' %in% class(x))
}

#. handle_errors
is_ms_exception <- function(x){
    return('ms_exception' %in% class(x))
}

#. handle_errors
is_blacklist_indicator <- function(x){
    return('blacklist_indicator' %in% class(x))
}

#. handle_errors
evaluate_result_status <- function(r){

    if(is_ms_err(r) || is_ms_exception(r)){
        status <- 'error'
    } else if(is_blacklist_indicator(r)){
        status <- 'blacklist'
    } else {
        status <- 'ok'
    }

    return(status)
}

email_err = function(msgs, addrs, pw){

    if(is.list(msgs)){
        msgs = Reduce(function(x, y) paste(x, y, sep='\n---\n'), msgs)
    }

    text_body = glue('Error list:\n\n', msgs, '\n\nEnd of errors')

    mailout = tryCatch({

        for(a in addrs){

            email = envelope() %>%
                from('grdouser@gmail.com') %>%
                to(a) %>%
                subject('MacroSheds error') %>%
                text(text_body)

            smtp = server(host='smtp.gmail.com',
                          port=587, #or 465 for SMTPS
                          username='grdouser@gmail.com',
                          password=pw)

            smtp(email, verbose=FALSE)
        }

    }, error=function(e){

        #not sure if class "error" is always returned by tryCatch,
        #so creating custom class
        errout = 'err'
        class(errout) = 'err'
        return(errout)
    })

    if('err' %in% class(mailout)){
        msg = 'Something bogus happened in email_err'
        logerr(msg, logger=logger_module)
        return('email fail')
    } else {
        return('email success')
    }

}

get_data_tracker = function(network=domain, domain){

    #network is an optional macrosheds network name string. If omitted, it's
    #assumed to be identical to the domain string.
    #domain is a macrosheds domain string

    thisenv = environment()

    tryCatch({

        tracker_data = glue('data/{n}/{d}/data_tracker.json',
                            n=network, d=domain) %>%
            readr::read_file() %>%
            jsonlite::fromJSON()

    }, error=function(e){
        assign('tracker_data', list(), pos=thisenv)
    })

    return(tracker_data)
}

#. handle_errors
make_tracker_skeleton <- function(retrieval_chunks){

    #retrieval_chunks is a vector of identifiers for subsets (chunks) of
    #the overall dataset to be retrieved, e.g. sitemonths for NEON

    munge_derive_skeleton = list(status='pending', mtime='1500-01-01')

    tracker_skeleton = list(
        retrieve=tibble::tibble(
            component=retrieval_chunks, mtime='1500-01-01',
            held_version='-1', status='pending'),
        munge=munge_derive_skeleton,
        derive=munge_derive_skeleton)

    return(tracker_skeleton)
}

#. handle_errors
insert_site_skeleton <- function(tracker, prodname_ms, site_name,
                                 site_components){

    tracker[[prodname_ms]][[site_name]] =
        make_tracker_skeleton(retrieval_chunks=site_components)

    return(tracker)
}

#. handle_errors
product_is_tracked <- function(tracker, prodname_ms){
    bool = prodname_ms %in% names(tracker)
    return(bool)
}

#. handle_errors
site_is_tracked <- function(tracker, prodname_ms, site_name){
    bool = site_name %in% names(tracker[[prodname_ms]])
    return(bool)
}

#. handle_errors
track_new_product <- function(tracker, prodname_ms){

    if(prodname_ms %in% names(tracker)){
        logwarn('This product is already being tracked.', logger=logger_module)
        return(tracker)
    }

    tracker[[prodname_ms]] = list()
    return(tracker)
}

#. handle_errors
track_new_site_components <- function(tracker, prodname_ms, site_name, avail){

    retrieval_tracker = tracker[[prodname_ms]][[site_name]]$retrieve

    retrieval_tracker = avail %>%
        filter(! component %in% retrieval_tracker$component) %>%
        select(component) %>%
        mutate(mtime='1900-01-01', held_version='-1', status='pending') %>%
        bind_rows(retrieval_tracker) %>%
        arrange(component)

    tracker[[prodname_ms]][[site_name]]$retrieve = retrieval_tracker

    return(tracker)
}

#. handle_errors
filter_unneeded_sets <- function(tracker_with_details){

    new_sets = tracker_with_details %>%
        filter(status != 'blacklist' | is.na(status)) %>%
        filter(needed == TRUE | is.na(needed))

    if(any(is.na(new_sets$needed))){
        msg = paste0('Must run `track_new_site_components` and ',
                     '`populate_set_details` before running `populate_set_details`')
        logerror(msg, logger=logger_module)
        stop(msg)
    }

    return(new_sets)
}

#. handle_errors
update_data_tracker_r <- function(network=domain, domain, tracker=NULL,
                                  tracker_name=NULL, set_details=NULL, new_status=NULL){

    #this updates the retrieve section of a data tracker in memory and on disk.
    #see update_data_tracker_m for the munge section and update_data_tracker_d
    #for the derive section

    #if tracker is supplied, it will be used to write/overwrite the one on disk.
    #if it is omitted or set to NULL, the appropriate tracker will be loaded
    #from disk, updated, and then written back to disk.

    if(is.null(tracker) && (
        is.null(tracker_name) || is.null(set_details) || is.null(new_status)
    )){
        msg = paste0('If tracker is not supplied, these args must be:',
                     'tracker_name, set_details, new_status.')
        logerror(msg, logger=logger_module)
        stop(msg)
    }

    if(is.null(tracker)){

        tracker = get_data_tracker(network=network, domain=domain)

        rt = tracker[[set_details$prodname_ms]][[set_details$site_name]]$retrieve

        set_ind = which(rt$component == set_details$component)

        if(new_status %in% c('pending', 'ok')){
            rt$held_version[set_ind] = as.character(set_details$avail_version)
        }
        rt$status[set_ind] = new_status
        rt$mtime[set_ind] = as.character(Sys.time())

        tracker[[set_details$prodname_ms]][[set_details$site_name]]$retrieve = rt

        assign(tracker_name, tracker, pos=.GlobalEnv)
    }

    trackerdir <- glue('data/{n}/{d}', n=network, d=domain)
    if(! dir.exists('trackerdir')){
        dir.create(trackerdir, showWarnings = FALSE, recursive = TRUE)
    }

    trackerfile = glue(trackerdir, '/data_tracker.json')
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)

    return()
}

#. handle_errors
update_data_tracker_m <- function(network=domain, domain, tracker_name,
                                  prodname_ms, site_name, new_status){

    #this updates the munge section of a data tracker in memory and on disk.
    #see update_data_tracker_r for the retrieval section and
    #update_data_tracker_d for the derive section

    tracker = get_data_tracker(network=network, domain=domain)

    mt = tracker[[prodname_ms]][[site_name]]$munge

    mt$status = new_status
    mt$mtime = as.character(Sys.time())

    tracker[[prodname_ms]][[site_name]]$munge = mt

    assign(tracker_name, tracker, pos=.GlobalEnv)

    trackerdir <- glue('data/{n}/{d}', n=network, d=domain)
    if(! dir.exists('trackerdir')){
        dir.create(trackerdir, showWarnings = FALSE, recursive = TRUE)
    }

    trackerfile = glue(trackerdir, '/data_tracker.json')
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)

    return()
}

#. handle_errors
update_data_tracker_d <- function(network=domain, domain, tracker=NULL,
                                  tracker_name=NULL, prodname_ms=NULL, site_name=NULL, new_status=NULL){

    #this updates the derive section of a data tracker in memory and on disk.
    #see update_data_tracker_r for the retrieval section and
    #update_data_tracker_m for the munge section

    #if tracker is supplied, it will be used to write/overwrite the one on disk.
    #if it is omitted or set to NULL, the appropriate tracker will be loaded
    #from disk, updated, and then written back to disk.

    if(is.null(tracker) && (
        is.null(tracker_name) || is.null(prodname_ms) ||
        is.null(new_status) || is.null(site_name)
    )){
        msg = paste0('If tracker is not supplied, these args must be:',
                     'tracker_name, prodname_ms, new_status, new_status.')
        logerror(msg, logger=logger_module)
        stop(msg)
    }

    if(is.null(tracker)){

        tracker = get_data_tracker(network=network, domain=domain)

        dt = tracker[[prodname_ms]][[site_name]]$derive

        if(is.null(dt)){
            return(generate_ms_exception('Product not yet tracked; no action taken.'))
        }

        dt$status = new_status
        dt$mtime = as.character(Sys.time())

        tracker[[prodname_ms]][[site_name]]$derive = dt

        assign(tracker_name, tracker, pos=.GlobalEnv)
    }

    trackerdir <- glue('data/{n}/{d}', n=network, d=domain)
    if(! dir.exists('trackerdir')){
        dir.create(trackerdir, showWarnings = FALSE, recursive = TRUE)
    }

    trackerfile = glue(trackerdir, '/data_tracker.json')
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)

    return()
}

#. handle_errors
backup_tracker <- function(path){

    mch = stringr::str_match(path,
                             '(data/.+?/.+?)/(data_tracker.json)')[, 2:3]

    if(any(is.na(mch))){
        stop('Invalid tracker path or name')
    }

    dir.create(glue(mch[1], '/tracker_backups'),
               recursive=TRUE, showWarnings=FALSE)

    tstamp = Sys.time() %>%
        with_tz(tzone='UTC') %>%
        format('%Y%m%dT%HZ') #tstamp format: YYYYMMDDTHHZ

    newpath = glue('{p}/tracker_backups/{f}_{t}', p=mch[1], f=mch[2], t=tstamp)
    file.copy(path, newpath, overwrite=FALSE) #write only one tracker per hour

    #remove tracker backups older than 7 days
    system2('find', c(glue(mch[1], '/tracker_backups/*'),
                      '-mtime', '+7', '-exec', 'rm', '{}', '\\;'))

    return()
}

#. handle_errors
extract_retrieval_log <- function(tracker, prodname_ms, site_name,
                                  keep_status='ok'){

    retrieved_data = tracker[[prodname_ms]][[site_name]]$retrieve %>%
        tibble::as_tibble() %>%
        filter(status == keep_status)

    return(retrieved_data)
}

#. handle_errors
get_munge_status <- function(tracker, prodname_ms, site_name){
    munge_status = tracker[[prodname_ms]][[site_name]]$munge$status
    return(munge_status)
}

#. handle_errors
get_derive_status <- function(tracker, prodname_ms, site_name){
    derive_status = tracker[[prodname_ms]][[site_name]]$derive$status
    return(derive_status)
}

#. handle_errors
get_product_info <- function(network, domain=NULL, status_level, get_statuses){

    #unlike other functions with network and domain arguments, this one accepts
    #either network alone, or network and domain. if just network is given,
    #it will look for products.csv at the network level

    if(is.null(domain)){
        prods = sm(read_csv(glue('src/{n}/products.csv', n=network)))
    } else {
        prods = sm(read_csv(glue('src/{n}/{d}/products.csv', n=network, d=domain)))
    }

    status_column = glue(status_level, '_status')
    prods = prods[prods[[status_column]] %in% get_statuses, ]

    return(prods)
}

#. handle_errors
prodcode_from_prodname_ms <- function(prodname_ms){

    #prodname_ms consists of the macrosheds official name for a data
    #category, e.g. discharge, and the source-specific code for that
    #data product, e.g. DP1.20093. These two values are concatenated,
    #separated by a double underscore. So long as we never use a double
    #underscore in a macrosheds official data category name, this function
    #will be able to split a prodname_ms into its two constituent parts.

    namesplit <- strsplit(prodname_ms, '__')[[1]]
    name_length <- length(namesplit)
    prodcode <- namesplit[2:name_length]
    prodcode <- paste(prodcode, collapse = '__')

    return(prodcode)
}

#. handle_errors
prodname_from_prodname_ms <- function(prodname_ms){

    #prodname_ms consists of the macrosheds official name for a data
    #category, e.g. discharge, and the source-specific code for that
    #data product, e.g. DP1.20093. These two values are concatenated,
    #separated by a double underscore. So long as we never use a double
    #underscore in a macrosheds official data category name, this function
    #will be able to split a prodname_ms into its two constituent parts.

    prodname <- strsplit(prodname_ms, '__')[[1]][1]
    return(prodname)
}

#. handle_errors
ms_retrieve <- function(network=domain, domain){
    source(glue('src/{n}/{d}/retrieve.R', n=network, d=domain))
    return()
}

#. handle_errors
ms_munge <- function(network=domain, domain){
    source(glue('src/{n}/{d}/munge.R', n=network, d=domain))
    return()
}

#. handle_errors
ms_derive <- function(network=domain, domain){
    source(glue('src/{n}/{d}/derive.R', n=network, d=domain))
    return()
}

#. handle_errors
serialize_list_to_dir <- function(l, dest){

    #l must be a named list
    #dest is the path to a directory that will be created if it doesn't exist

    #list element classes currently handled: data.frame, character

    elemclasses = lapply(l, class)

    handled = lapply(elemclasses,
                     function(x) any(c('character', 'data.frame') %in% x))

    if(! all(unlist(handled))){
        stop('Unhandled class encountered')
    }

    dir.create(dest, showWarnings=FALSE, recursive=TRUE)

    for(i in 1:length(l)){

        if('data.frame' %in% elemclasses[[i]]){

            fpath = paste0(dest, '/', names(l)[i], '.feather')
            write_feather(l[[i]], fpath)

        } else if('character' %in% x){

            fpath = paste0(dest, '/', names(l)[i], '.txt')
            readr::write_file(l[[i]], fpath)
        }
    }

    return()
}

#. handle_errors
parse_molecular_formulae <- function(formulae){

    #`formulae` is a vector

    # formulae = c('C', 'C4', 'Cl', 'Cl2', 'CCl', 'C2Cl', 'C2Cl2', 'C2Cl2B2')
    # formulae = 'BCH10He10PLi2'
    # formulae='Mn'

    conc_vars = str_match(formulae, '^(?:OM|TM|DO|TD|UT|UTK|TK)?([A-Za-z0-9]+)_?')[,2]
    two_let_symb_num = str_extract_all(conc_vars, '([A-Z][a-z][0-9]+)')
    conc_vars = str_remove_all(conc_vars, '([A-Z][a-z][0-9]+)')
    one_let_symb_num = str_extract_all(conc_vars, '([A-Z][0-9]+)')
    conc_vars = str_remove_all(conc_vars, '([A-Z][0-9]+)')
    two_let_symb = str_extract_all(conc_vars, '([A-Z][a-z])')
    conc_vars = str_remove_all(conc_vars, '([A-Z][a-z])')
    one_let_symb = str_extract_all(conc_vars, '([A-Z])')

    constituents = mapply(c, SIMPLIFY=FALSE,
                          two_let_symb_num, one_let_symb_num, two_let_symb, one_let_symb)

    return(constituents) # a list of vectors
}

#. handle_errors
combine_atomic_masses <- function(molecular_constituents){

    #`molecular_constituents` is a vector

    xmat = str_match(molecular_constituents,
                     '([A-Z][a-z]?)([0-9]+)?')[, -1, drop=FALSE]
    elems = xmat[,1]
    mults = as.numeric(xmat[,2])
    mults[is.na(mults)] = 1
    molecular_mass = sum(PeriodicTable::mass(elems) * mults)

    return(molecular_mass) #a scalar
}

#. handle_errors
calculate_molar_mass <- function(molecular_formula){

    if(length(molecular_formula) > 1){
        stop('molecular_formula must be a string of length 1')
    }

    parsed_formula = parse_molecular_formulae(molecular_formula)[[1]]
    molar_mass = combine_atomic_masses(parsed_formula)

    return(molar_mass)
}

#. handle_errors
convert_molecule <- function(x, from, to){

    #e.g. convert_molecule(1.54, 'NH4', 'N')

    from_mass <- calculate_molar_mass(from)
    to_mass <- calculate_molar_mass(to)
    converted_mass <- x * to_mass / from_mass

    return(converted_mass)
}

#. handle_errors
update_product_file <- function(network, domain, level, prodcode, status,
                                prodname){

    if(network == domain){
        prods = sm(read_csv(glue('src/{n}/products.csv', n=network)))
    } else {
        prods = sm(read_csv(glue('src/{n}/{d}/products.csv', n=network, d=domain)))
    }

    prodname_list <- strsplit(prodname, '; ')
    names_matched <- sapply(prodname_list, function(x) all(x %in% prods$prodname))
    if(! all(names_matched)){
        stop(glue('All prodnames in processing_kernels.R must match ',
                  'prodnames in products.csv'))
    }

    for(i in 1:length(prodcode)){
        col_name = as.character(glue(level[i], '_status'))
        row_num <- which(prods$prodcode == prodcode[i] &
                             prods$prodname %in% prodname_list[[i]])
        prods[row_num, col_name] = status[i]
    }

    if(network == domain){
        write_csv(prods, glue('src/{n}/products.csv', n=network))
    } else {
        write_csv(prods, glue('src/{n}/{d}/products.csv', n=network, d=domain))
    }

    return()
}

#. handle_errors
update_product_statuses <- function(network, domain){

    #status_codes should maybe be defined globally, or in a file
    status_codes = c('READY', 'PENDING', 'PAUSED', 'OBSOLETE', 'TEST')
    kf = glue('src/{n}/{d}/processing_kernels.R', n=network, d=domain)
    kernel_lines = read_lines(kf)

    status_line_inds = grep('STATUS=([A-Z]+)', kernel_lines)
    mch = stringr::str_match(kernel_lines[status_line_inds],
                             '#(.+?): STATUS=([A-Z]+)')[, 2:3]
    prodnames = mch[, 1, drop=TRUE]
    statuses = mch[, 2, drop=TRUE]

    if(any(! statuses %in% status_codes)){
        stop(glue('Illegal status in ', kf))
    }

    funcname_lines = kernel_lines[status_line_inds + 2]

    if(any(! grep('process_[0-2]_.+?', funcname_lines))){
        stop(glue('function definition must begin exactly two lines after STATUS',
                  ' indicator. function must be named "process_<level>_<prodcode>"'))
    }

    func_codes = stringr::str_match(funcname_lines,
                                    'process_([0-2])_(.+)? <-')[, 2:3, drop=FALSE]

    func_lvls = func_codes[, 1, drop=TRUE]
    prodcodes = func_codes[, 2, drop=TRUE]

    level_names = case_when(func_lvls == 0 ~ "retrieve",
                            func_lvls == 1 ~ "munge",
                            func_lvls == 2 ~ "derive")

    status_names = tolower(statuses)

    update_product_file(network=network, domain=domain, level=level_names,
                        prodcode=prodcodes, status=status_names,
                        prodname=prodnames)

    return()
}

#. handle_errors
convert_unit <- function(val, input_unit, output_unit){

    units <- tibble(prefix = c('n', "u", "m", "c", "d", "h", "k", "M"),
                    convert_factor = c(0.000000001, 0.000001, 0.001, 0.01, 0.1, 100,
                                       1000, 1000000))

    old_fraction <- as.vector(str_split_fixed(input_unit, "/", n = Inf))

    old_top <- as.vector(str_split_fixed(old_fraction[1], "", n = Inf))

    if(length(old_top) == 2) {
        old_top_unit <- str_split_fixed(old_top, "", 2)[1]

        old_top_conver <- as.numeric(filter(units, prefix == old_top_unit)[,2])

    }else {
        old_top_conver <- 1
    }

    if(length(old_fraction) == 2) {
        old_bottom <- as.vector(str_split_fixed(old_fraction[2], "", n = Inf))

        old_bottom_conver <- ifelse(length(old_bottom) == 1, 1,
                                    as.numeric(filter(units, prefix == old_bottom[1])[,2]))
    } else{old_bottom_conver <- 1}

    new_fraction <- as.vector(str_split_fixed(output_unit, "/", n = Inf))

    new_top <- as.vector(str_split_fixed(new_fraction[1], "", n = Inf))

    if(length(new_top) == 2) {
        new_top_unit <- str_split_fixed(new_top, "", 2)[1]

        new_top_conver <- as.numeric(filter(units, prefix == new_top_unit)[,2])

    }else {
        new_top_conver <- 1
    }

    if(length(new_fraction) == 2) {
        new_bottom <- as.vector(str_split_fixed(new_fraction[2], "", n = Inf))

        new_bottom_conver <- ifelse(length(new_bottom) == 1, 1,
                                    as.numeric(filter(units, prefix == new_bottom[1])[,2]))
    } else{new_bottom_conver <- 1}

    new_val <- val*old_top_conver*new_top_conver

    new_val <- new_val/(old_bottom_conver*new_bottom_conver)

    return(new_val) }

#. handle_errors
write_ms_file <- function(d, network, domain, prodname_ms, site_name,
                          level='munged', shapefile=FALSE,
                          link_to_portal = TRUE){

    #write an ms tibble or shapefile to its appropriate destination based on
    #network, domain, prodname_ms, site_name, and processing level. If a tibble,
    #write as a feather file (site_name.feather),
    #and write any uncertainty included in the tibble as a separate feather
    #site_name_uncert.feather. by default, create a hardlink to the file
    #from the data portal as well as from the data_acquisition storage system,
    #assuming the portal directory is a sibling of the data_acquision directory
    #and is named "portal"

    if(! level %in% c('munged', 'derived')){
        stop('level must be "munged" or "derived"')
    }

    if(shapefile){

        site_dir = glue('{wd}/data/{n}/{d}/{l}/{p}/{s}',
                        wd = getwd(),
                        n = network,
                        d = domain,
                        l = level,
                        p = prodname_ms,
                        s = site_name)

        dir.create(site_dir,
                   showWarnings = FALSE,
                   recursive = TRUE)

        sw(sf::st_write(obj = d,
                        dsn = glue(site_dir, '/', site_name, '.shp'),
                        delete_dsn = TRUE,
                        quiet = TRUE))

    } else {

        prod_dir = glue('data/{n}/{d}/{l}/{p}',
                        n = network,
                        d = domain,
                        l = level,
                        p = prodname_ms)
        dir.create(prod_dir,
                   showWarnings = FALSE,
                   recursive = TRUE)

        site_file = glue('{pd}/{s}.feather',
                         pd = prod_dir,
                         s = site_name)
        site_file_uncert = glue('{pd}/{s}_uncert.feather',
                                pd = prod_dir,
                                s = site_name)

        d_uncert <- lapply(d,
                           function(x){
                               if(is.numeric(x) && any(errors(x) != 0)){
                                   errors(x)
                               }
                            })
        d_uncert <- as_tibble(d_uncert[! sapply(d_uncert, is.null)])
        write_feather(d_uncert, site_file_uncert)

        #make sure write_feather will omit attrib by def (with no artifacts)
        write_feather(d, site_file)
    }

    if(link_to_portal){
        create_portal_link(network = network,
                           domain = domain,
                           prodname_ms = prodname_ms,
                           site_name = site_name,
                           level = level,
                           dir = shapefile)
    }

    return()
}

#. handle_errors
create_portal_link <- function(network, domain, prodname_ms, site_name,
                               level = 'munged', dir = FALSE){

    #level is one of 'munged', 'derived', corresponding to the
    #location, within the data_acquisition system, of the data to be linked
    #if dir=TRUE, treat site_name as a directory name, and link all files
    #within (necessary for e.g. shapefiles, which often come with other files)

    #todo: allow level='raw'; flexibility for linking arbitrary file extensions

    if(! level %in% c('munged', 'derived')){
        stop('level must be "munged" or "derived"')
    }

    portal_prod_dir = glue('../portal/data/{d}/{p}', #portal ignores network
                           d = domain,
                           p = strsplit(prodname_ms, '__')[[1]][1])
    dir.create(portal_prod_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    if(! dir){

        portal_site_file = glue('{pd}/{s}.feather',
                                pd = portal_prod_dir,
                                s = site_name)
        portal_site_file_uncert = glue('{pd}/{s}_uncert.feather',
                                       pd = portal_prod_dir,
                                       s = site_name)

        #if there's already a data file for this site-time-product in
        #the portal repo, remove it
        unlink(portal_site_file)
        unlink(portal_site_file_uncert)

        #create a link to the portal repo from the new site file
        #(note: really, to and from are equivalent, as they both
        #point to the same underlying structure in the filesystem)
        site_file = glue('data/{n}/{d}/{l}/{p}/{s}.feather',
                         n = network,
                         d = domain,
                         l = level,
                         p = prodname_ms,
                         s = site_name)
        site_file_uncert = glue('data/{n}/{d}/{l}/{p}/{s}_uncert.feather',
                                n = network,
                                d = domain,
                                l = level,
                                p = prodname_ms,
                                s = site_name)

        invisible(sw(file.link(to = portal_site_file,
                               from = site_file)))

        if(file.exists(site_file_uncert)){
            invisible(sw(file.link(to = portal_site_file_uncert,
                                   from = site_file_uncert)))
        }

    } else {

        site_dir <- glue('data/{n}/{d}/{l}/{p}/{s}',
                         n = network,
                         d = domain,
                         l = level,
                         p = prodname_ms,
                         s = site_name)

        portal_prod_dir <- glue('../portal/data/{d}/{p}',
                                d = domain,
                                p = strsplit(prodname_ms, '__')[[1]][1])

        dir.create(portal_prod_dir,
                   showWarnings = FALSE,
                   recursive = TRUE)

        site_files <- list.files(site_dir)
        for(s in site_files){

            site_file <- glue(site_dir, '/', s)
            portal_site_file <- glue(portal_prod_dir, '/', s)
            unlink(portal_site_file)
            invisible(sw(file.link(to = portal_site_file,
                                   from = site_file)))
        }

    }

    return()
}

#. handle_errors
is_ms_prodcode <- function(prodcode){

    #always specify macrosheds "pseudo product codes" as "msXXX" where
    #X is zero-padded integer. these codes are used for derived products
    #that don't exist within the data source.

    return(grepl('ms[0-9]{3}', prodcode))
}

#. handle_errors
list_munged_files <- function(network, domain, prodname_ms,
                              omit_uncertainty_files = FALSE){

    mfiles <- glue('data/{n}/{d}/munged/{p}',
                   n = network,
                   d = domain,
                   p = prodname_ms) %>%
        list.files(full.names = TRUE)

    if(omit_uncertainty_files){
        mfiles <- mfiles[! grepl('_uncert.feather$',
                                 mfiles,
                                 perl = TRUE)]
    }

    return(mfiles)
}

#. handle_errors
fname_from_fpath <- function(paths, include_fext = TRUE){

    #paths is a vector of filepaths of/this/form. final slash is used to
    #delineate file name.

    #if include_fext == FALSE, file extension will not be included

    fnames <- vapply(strsplit(paths, '/'),
                     function(x) x[length(x)],
                     FUN.VALUE = '')

    if(! include_fext){
        fnames <- str_match(fnames,'(.*?)\\..*')[, 2]
    }

    return(fnames)
}

#still in progress
delineate_watershed <- function(lat, long) {

    site <- tibble(x = lat,
                   y = long) %>%
        sf::st_as_sf(coords = c("y", "x"), crs = 4269) %>%
        sf::st_transform(102008)

    start_comid <- nhdplusTools::discover_nhdplus_id(sf::st_sfc(
        sf::st_point(c(long, lat)), crs = 4269))

    flowline <- nhdplusTools::navigate_nldi(list(featureSource = "comid",
                                                 featureID = start_comid),
                                            mode = "upstreamTributaries",
                                            data_source = "")

    subset_file <- tempfile(fileext = ".gpkg")

    subset <- nhdplusTools::subset_nhdplus(comids = flowline$nhdplus_comid,
                                           output_file = subset_file,
                                           nhdplus_data = "download",
                                           return_data = TRUE)

    flowlines <- subset$NHDFlowline_Network %>%
        sf::st_transform(102008)

    catchments <- subset$CatchmentSP %>%
        sf::st_transform(102008)

    upstream <- nhdplusTools::get_UT(flowlines, start_comid)

    watershed <- catchments %>%
        filter(featureid %in% upstream) %>%
        sf::st_buffer(0.01) %>%
        sf::st_union() %>%
        sf::st_as_sf()

    if(as.numeric(sf::st_area(watershed)) >= 60000000) {
        return(watershed)
    }
    else {

        outline = sf::st_as_sfc(sf::st_bbox(flowlines))

        outline_buff <- outline %>%
            sf::st_buffer(5000)

        dem <- elevatr::get_elev_raster(as(outline_buff, 'Spatial'), z=12)

        temp_raster <- tempfile(fileext = ".tif")

        raster::writeRaster(dem, temp_raster, overwrite = T)

        temp_point <- tempfile(fileext = ".shp")

        sf::st_write(sf::st_zm(site), temp_point, delete_layer=TRUE)

        temp_breash2 <- tempfile(fileext = ".tif")
        whitebox::wbt_fill_single_cell_pits(temp_raster, temp_breash2)

        temp_breached <- tempfile(fileext = ".tif")
        whitebox::wbt_breach_depressions(temp_breash2,temp_breached,flat_increment=.01)

        temp_d8_pntr <- tempfile(fileext = ".tif")
        whitebox::wbt_d8_pointer(temp_breached,temp_d8_pntr)

        temp_shed <- tempfile(fileext = ".tif")
        whitebox::wbt_unnest_basins(temp_d8_pntr, temp_point, temp_shed)

        # No idea why but wbt_unnest_basins() aves whatever file path with a _1 after the name so must add
        file_new <- str_split_fixed(temp_shed, "[.]", n = 2)

        file_shed <- paste0(file_new[1], "_1.", file_new[2])

        check <- raster::raster(file_shed)
        values <- raster::getValues(check)
        values[is.na(values)] <- 0


        if(sum(values, na.rm = TRUE) < 100) {

            flow <- tempfile(fileext = ".tif")
            whitebox::wbt_d8_flow_accumulation(temp_breached,flow,out_type='catchment area')

            snap <- tempfile(fileext = ".shp")
            whitebox::wbt_snap_pour_points(temp_point, flow, snap, 50)

            temp_shed <- tempfile(fileext = ".tif")
            whitebox::wbt_unnest_basins(temp_d8_pntr, snap, temp_shed)

            file_new <- str_split_fixed(temp_shed, "[.]", n = 2)

            file_shed <- paste0(file_new[1], "_1.", file_new[2])

            check <- raster::raster(file_shed)
            values <- raster::getValues(check)
            values[is.na(values)] <- 0
        }
        watershed_raster <- raster::rasterToPolygons(raster::raster(file_shed))

        #Convert shapefile to sf
        watershed_df <- sf::st_as_sf(watershed_raster)

        #buffer to join all pixles into one shape
        watershed <- sf::st_buffer(watershed_df, 0.1) %>%
            sf::st_union() %>%
            sf::st_as_sf()

        if(sum(values, na.rm = T) < 100) {
            watershed <- watershed %>%
                mutate(flag = "check")
        }

        #sf::st_write(watershed_union, dsn =
        #                glue("data/{n}/{d}/geospatial/ws_boundaries/{s}.shp",
        #                    n = sites$network, d = sites$domain, s = sites$site_name))
        return(watershed)

    }
}

#. handle_errors
calc_inst_flux <- function(chemprod, qprod, site_name){#, dt_round_interv,
    #impute_limit = 30){

    #chemprod is the prodname_ms for stream or precip chemistry
    #qprod is the prodname_ms for stream discharge or precip volume over time
    #dt_round_interv is a rounding interval passed to lubridate::round_date

    #todo:
    #1 incorporate read_combine_feather
    #2 a lot of datetime management code has been commented. note that if
    #you need to bring it back (because of some unforeseen problem
    #with synchronize_timestep), you'll need to change some of the any()
    #calls to numeric_any, or convert ms_status and ms_interp to
    #logical and then summarize with any()

    qvar <- prodname_from_prodname_ms(qprod)
    if(! qvar %in% c('precipitation', 'discharge')){
        stop('Could not determine stream/precip')
    }

    flux_vars <- ms_vars %>% #ms_vars is global
        filter(flux_convertible == 1) %>%
        pull(variable_code)

    chem <- read_feather(glue('data/{n}/{d}/munged/{cp}/{s}.feather',
                              n = network,
                              d = domain,
                              cp = chemprod,
                              s = site_name)) %>%
        select(one_of(flux_vars), 'datetime', 'ms_status', 'ms_interp')
    #     mutate(datetime = lubridate::round_date(datetime, dt_round_interv)) %>%
    #     group_by(datetime) %>%
    #     summarize_all(~ if(is.numeric(.)) mean(., na.rm=TRUE) else any(.)) %>%
    #     ungroup()
    # chem = manufacture_uncert_msdf(chem)

    # detlims_c <- identify_detection_limit(chem)
    # ue(identify_detection_limit_t(chem,
    #                               network = network,
    #                               domain = domain))

    daterange <- range(chem$datetime)
    # fulldt <- tibble(datetime = seq(daterange[1], daterange[2],
    #                                 by=dt_round_interv))

    discharge <- read_feather(glue('data/{n}/{d}/munged/{qp}/{s}.feather',
                                   n = network,
                                   d = domain,
                                   qp = qprod,
                                   s = site_name)) %>%
        select(-site_name) %>%
        filter(datetime >= daterange[1], datetime <= daterange[2])
    # mutate(datetime = lubridate::round_date(datetime, dt_round_interv)) %>%
    # group_by(datetime) %>%
    # summarize_all(~ if(is.numeric(.)) mean(., na.rm=TRUE) else any(.)) %>%
    # ungroup()
    # discharge = manufacture_uncert_msdf(discharge)

    # discharge = manufacture_uncert_msdf(discharge)
    # chem = manufacture_uncert_msdf(chem)
    # discharge = filter(discharge, datetime < as.POSIXct('1980-01-01'))
    # chem = filter(chem, datetime < as.POSIXct('1980-01-01'))

    flux <- chem %>%
        full_join(discharge,
                  by = 'datetime') %>%
        select_if(~(! all(is.na(.)))) %>%
        rowwise(datetime) %>%
        mutate(
            ms_interp = numeric_any(c_across(c(ms_interp.x, ms_interp.y))),
            ms_status = numeric_any(c_across(c(ms_status.x, ms_status.y)))) %>%
        ungroup() %>%
        select(-ms_status.x, -ms_status.y, -ms_interp.x, -ms_interp.y) %>%
        mutate_at(vars(-datetime, -!!sym(qvar), -ms_status, -ms_interp),
                  ~(. * !!sym(qvar))) %>%
        select(-!!sym(qvar)) %>%
        mutate(site_name = !!(site_name)) %>%
        # filter_at(vars(-site_name, -datetime, -ms_status, -ms_interp),
        filter_at(vars(-any_of(ms_canonicals)),
                  any_vars(! is.na(.))) %>%
        arrange(datetime) %>%
        select(datetime, site_name, everything()) %>%
        relocate(ms_status, .after = last_col()) %>%
        relocate(ms_interp, .after = last_col())

    # qq = identify_detection_limit_s(flux)
    # identify_detection_limit_t(flux, network, domain)
    # jj <- ue(apply_detection_limit_t(flux, network, domain))
    flux <- ue(apply_detection_limit_t(flux, network, domain))
    # identify_detection_limit_s(jj)

    return(flux)
}

#. handle_errors
read_combine_shapefiles <- function(network, domain, prodname_ms){

    prodpaths <- list.files(glue('data/{n}/{d}/munged/{p}',
                                 n = network,
                                 d = domain,
                                 p = prodname_ms),
                            recursive = TRUE,
                            full.names = TRUE,
                            pattern = '*.shp')

    shapes <- lapply(prodpaths,
                     function(x){
                         sf::st_read(x,
                                     stringsAsFactors = FALSE,
                                     quiet = TRUE)
                     })

    # wb <- sw(Reduce(sf::st_union, wbs)) %>%
    combined <- sw(Reduce(rbind, shapes))
    # sf::st_transform(projstring)

    return(combined)
}

#. handle_errors
read_combine_feathers <- function(network, domain, prodname_ms){

    #read all data feathers associated with a network-domain-product,
    #separately read any accompanying uncertainty files, insert uncertainty
    #into each tibble after it is read, row bind all tibbles, arrange by
    #site_name, datetime columns if they exist

    prodpaths <- list_munged_files(network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms,
                                   omit_uncertainty_files = TRUE)

    combined <- tibble()
    for(i in 1:length(prodpaths)){
        # combined <- read_feather(prodpaths[i]) %>%
        #     bind_rows(combined)
        part <- read_feather(prodpaths[i])
        uncert_filepath <- sub('\\.feather$',
                               '_uncert.feather',
                               prodpaths[i],
                               perl = TRUE)
        if(file.exists(uncert_filepath)){
            part_uncert <- read_feather(uncert_filepath)
            part <- insert_uncertainty_df(part, part_uncert)
        }

        combined <- bind_rows(combined, part)
    }

    if(all(c('datetime', 'site_name') %in% colnames(combined))){
        combined <- arrange(combined, datetime, site_name)
    }

    return(combined)
}

#. handle_errors
choose_projection <- function(lat = NULL, long = NULL, unprojected = FALSE){

    if(unprojected){
        PROJ4 <- glue('+proj=longlat +datum=WGS84 +no_defs ',
                      '+ellps=WGS84 +towgs84=0,0,0')
        return(PROJ4)
    }

    if(is.null(lat) || is.null(long)){
        stop('If projecting, lat and long are required.')
    }

    if(lat <= 15 && lat >= -15){ #equatorial
        PROJ4 = glue('+proj=laea +lon_0=', long)
    } else { #temperate or polar
        PROJ4 = glue('+proj=laea +lat_0=', lat, ' +lon_0=', long)
    }

    return(PROJ4)
}

#. handle_errors
reconstitute_raster <- function(x, template){

    m = matrix(as.vector(x),
               nrow=nrow(template),
               ncol=ncol(template),
               byrow=TRUE)
    r <- raster(m,
                crs=raster::projection(template))
    extent(r) <- raster::extent(template)

    return(r)
}

#. handle_errors
shortcut_idw <- function(encompassing_dem, wshd_bnd, data_locations,
                         data_values, stream_site_name, output_varname,
                         elev_agnostic = FALSE, verbose = FALSE){

    #encompassing_dem must cover the area of wshd_bnd and precip_gauges
    #wshd_bnd is an sf object with columns site_name and geometry
    #it represents a single watershed boundary
    #data_locations is an sf object with columns site_name and geometry
    #it represents all sites (e.g. rain gauges) that will be used in
    #the interpolation
    #data_values is a data.frame with one column each for datetime and ms_status,
    #and an additional named column of data values for each data location.
    #output_varname is only used to name the column in the tibble that is returned
    #elev_agnostic is a boolean that determines whether elevation should be
    #included as a predictor of the variable being interpolated

    # loginfo(glue('shortcut_idw: working on {ss}', ss=stream_site_name),
    #     logger = logger_module)

    #matrixify input data so we can use matrix operations
    d_status <- data_values$ms_status
    d_interp <- data_values$ms_interp
    d_dt <- data_values$datetime
    data_matrix <- select(data_values,
                          -ms_status,
                          -datetime,
                          -ms_interp) %>%
        err_df_to_matrix()

    #clean dem and get elevation values
    dem_wb <- terra::crop(encompassing_dem, wshd_bnd)
    dem_wb <- terra::mask(dem_wb, wshd_bnd)
    elevs <- terra::values(dem_wb)

    #compute distances from all dem cells to all data locations
    inv_distmat <- matrix(NA, nrow = length(dem_wb), ncol = ncol(data_matrix),
                          dimnames = list(NULL, colnames(data_matrix)))
    for(k in 1:ncol(data_matrix)){
        dk <- filter(data_locations, site_name == colnames(data_matrix)[k])
        inv_dist2 <- 1 / raster::distanceFromPoints(dem_wb, dk)^2 %>%
            terra::values(.)
        inv_dist2[is.na(elevs)] <- NA #mask
        inv_distmat[, k] <- inv_dist2
    }

    #calculate watershed mean at every timestep
    ws_mean <- rep(NA, nrow(data_matrix))
    ntimesteps <- nrow(data_matrix)
    for(k in 1:ntimesteps){

        idw_log_timestep(verbose = verbose,
                         site_name = stream_site_name,
                         v = output_varname,
                         k = k,
                         ntimesteps = ntimesteps)
        # if(verbose){
        #     if(k %% 1000 == 0){
        #         msg <- glue('giant loop: {kk}/{nt}',
        #             kk = k,
        #             nt = ntimesteps)
        #         loginfo(msg,
        #             logger = logger_module)
        #     }
        # }

        #assign cell weights as normalized inverse squared distances
        dk <- t(data_matrix[k, , drop = FALSE])
        inv_distmat_sub <- inv_distmat[, ! is.na(dk), drop = FALSE]
        dk <- dk[! is.na(dk), , drop = FALSE]
        weightmat <- do.call(rbind, #avoids matrix transposition
                             unlist(apply(inv_distmat_sub, #normalize by row
                                          1,
                                          function(x) list(x / sum(x))),
                                    recursive = FALSE))

        #perform vectorized idw
        dk[is.na(dk)] <- 0 #allows matrix multiplication
        d_idw <- weightmat %*% dk

        #reapply uncertainty dropped by `%*%`
        errors(d_idw) <- sum(get_relative_uncert(dk))

        #determine data-elevation relationship for interp weighting
        if(! elev_agnostic){
            d_elev <- tibble(site_name = rownames(dk),
                             d = dk[,1]) %>%
                left_join(data_locations,
                          by = 'site_name')
            mod <- lm(d ~ elevation, data = d_elev)
            ab <- as.list(mod$coefficients)

            #estimate raster values from elevation alone
            d_from_elev <- ab$elevation * elevs + ab$`(Intercept)`

            #average both approaches (this should be weighted toward idw
            #when close to any data location, and weighted half and half when far)
            # d_idw <- mapply(function(x, y) mean(c(x, y), na.rm=TRUE),
            #                 d_idw,
            #                 d_from_elev)
            d_idw <- (d_idw + d_from_elev) / 2
        }

        ws_mean[k] <- mean(d_idw, na.rm=TRUE)
        errors(ws_mean)[k] <- mean(errors(d_idw), na.rm=TRUE)
    }
    # compare_interp_methods()

    ws_mean <- tibble(datetime = d_dt,
                      site_name = stream_site_name,
                      !!output_varname := ws_mean,
                      ms_status = d_status,
                      ms_interp = d_interp)

    return(ws_mean)
}

#. handle_errors
shortcut_idw_concflux <- function(encompassing_dem, wshd_bnd, data_locations,
                                  precip_values, chem_values, stream_site_name,
                                  verbose = FALSE){

    #this function is similar to shortcut_idw, but when it gets to the
    #vectorized raster stage, it multiplies precip chem by precip volume
    #to calculate flux for each cell. then it returns a list containing two
    #derived values: watershed average concentration and ws ave flux.

    #encompassing_dem must cover the area of wshd_bnd and precip_gauges
    #wshd_bnd is an sf object with columns site_name and geometry
    #it represents a single watershed boundary
    #data_locations is an sf object with columns site_name and geometry
    #it represents all sites (e.g. rain gauges) that will be used in
    #the interpolation
    #precip_values is a data.frame with one column each for datetime and ms_status,
    #and an additional named column of data values for each precip location.
    #chem_values is a data.frame with one column each for datetime and ms_status,
    #and an additional named column of data values for each
    #precip chemistry location.

    # loginfo(glue('shortcut_idw_concflux: working on {ss}', ss=stream_site_name),
    #     logger = logger_module)

    common_dts <- base::intersect(as.character(precip_values$datetime),
                                  as.character(chem_values$datetime))
    precip_values <- filter(precip_values,
                            as.character(datetime) %in% common_dts)
    chem_values <- filter(chem_values,
                          as.character(datetime) %in% common_dts)

    #matrixify input data so we can use matrix operations
    d_dt <- precip_values$datetime

    p_status <- precip_values$ms_status
    p_interp <- precip_values$ms_interp
    p_matrix <- select(precip_values,
                       -ms_status,
                       -datetime,
                       -ms_interp) %>%
        err_df_to_matrix()

    c_status <- chem_values$ms_status
    c_interp <- chem_values$ms_interp
    c_matrix <- select(chem_values,
                       -ms_status,
                       -datetime,
                       -ms_interp) %>%
        err_df_to_matrix()

    d_status = bitwOr(p_status, c_status)
    d_interp = bitwOr(p_interp, c_interp)

    # gauges <- base::union(colnames(p_matrix),
    #                       colnames(c_matrix))
    # ngauges <- length(gauges)

    #clean dem and get elevation values
    dem_wb <- terra::crop(encompassing_dem, wshd_bnd)
    dem_wb <- terra::mask(dem_wb, wshd_bnd)
    elevs <- terra::values(dem_wb)

    #compute distances from all dem cells to all precip locations
    inv_distmat_p <- matrix(NA, nrow = length(dem_wb), ncol = ncol(p_matrix),
                            dimnames = list(NULL, colnames(p_matrix)))
    for(k in 1:ncol(p_matrix)){
        dk <- filter(data_locations, site_name == colnames(p_matrix)[k])
        inv_dist2 <- 1 / raster::distanceFromPoints(dem_wb, dk)^2 %>%
            terra::values(.)
        inv_dist2[is.na(elevs)] <- NA #mask
        inv_distmat_p[, k] <- inv_dist2
    }

    #compute distances from all dem cells to all chemistry locations
    inv_distmat_c <- matrix(NA, nrow = length(dem_wb), ncol = ncol(c_matrix),
                            dimnames = list(NULL, colnames(c_matrix)))
    for(k in 1:ncol(c_matrix)){
        dk <- filter(data_locations, site_name == colnames(c_matrix)[k])
        inv_dist2 <- 1 / raster::distanceFromPoints(dem_wb, dk)^2 %>%
            terra::values(.)
        inv_dist2[is.na(elevs)] <- NA
        inv_distmat_c[, k] <- inv_dist2
    }

    #calculate watershed mean concentration and flux at every timestep
    if(nrow(p_matrix) != nrow(c_matrix)) stop('P and C timesteps not equal')
    ntimesteps <- nrow(p_matrix)
    ws_mean_conc <- ws_mean_flux <- rep(NA, ntimesteps)
    for(k in 1:ntimesteps){

        idw_log_timestep(verbose = verbose,
                         site_name = stream_site_name,
                         v = '      ',
                         k = k,
                         ntimesteps = ntimesteps)
        # if(verbose){
        #     if(k %% 1000 == 0){
        #         msg <- glue('giant loop: {kk}/{nt}',
        #             kk = k,
        #             nt = ntimesteps)
        #         loginfo(msg,
        #             logger = logger_module)
        #     }
        # }

        #assign cell weights as normalized inverse squared distances (p)
        pk <- t(p_matrix[k, , drop = FALSE])
        inv_distmat_p_sub <- inv_distmat_p[, ! is.na(pk), drop=FALSE]
        pk <- pk[! is.na(pk), , drop=FALSE]
        weightmat_p <- do.call(rbind, #avoids matrix transposition
                               unlist(apply(inv_distmat_p_sub, #normalize by row
                                            1,
                                            function(x) list(x / sum(x))),
                                      recursive = FALSE))

        #assign cell weights as normalized inverse squared distances (c)
        ck <- t(c_matrix[k, , drop = FALSE])
        inv_distmat_c_sub <- inv_distmat_c[, ! is.na(ck), drop=FALSE]
        ck <- ck[! is.na(ck), , drop=FALSE]
        weightmat_c <- do.call(rbind,
                               unlist(apply(inv_distmat_c_sub,
                                            1,
                                            function(x) list(x / sum(x))),
                                      recursive = FALSE))

        #determine data-elevation relationship for interp weighting (p only)
        d_elev <- tibble(site_name = rownames(pk),
                         precip = pk[,1]) %>%
            left_join(data_locations,
                      by = 'site_name')
        mod <- lm(precip ~ elevation, data = d_elev)
        ab <- as.list(mod$coefficients)

        #perform vectorized idw (p)
        pk[is.na(pk)] <- 0 #allows matrix multiplication
        p_idw <- weightmat_p %*% pk

        #perform vectorized idw (c)
        ck[is.na(ck)] <- 0
        c_idw <- weightmat_c %*% ck

        #reapply uncertainty dropped by `%*%`
        errors(p_idw) <- sum(get_relative_uncert(pk))
        errors(c_idw) <- sum(get_relative_uncert(ck))

        #estimate raster values from elevation alone (p only)
        p_from_elev <- ab$elevation * elevs + ab$`(Intercept)`

        #average both approaches (p only; this should be weighted toward idw
        #when close to any data location, and weighted half and half when far)
        p_ensemb <- (p_idw + p_from_elev) / 2

        #calculate flux for every cell
        flux_interp <- c_idw * p_ensemb

        #calculate watershed averages (work around error drop)
        ws_mean_conc[k] <- mean(c_idw, na.rm=TRUE)
        ws_mean_flux[k] <- mean(flux_interp, na.rm=TRUE)
        errors(ws_mean_conc)[k] <- mean(errors(c_idw), na.rm=TRUE)
        errors(ws_mean_flux)[k] <- mean(errors(flux_interp), na.rm=TRUE)
    }
    # compare_interp_methods()

    ws_means <- tibble(datetime = d_dt,
                       site_name = stream_site_name,
                       concentration = ws_mean_conc,
                       flux = ws_mean_flux,
                       ms_status = d_status,
                       ms_interp = d_interp)

    return(ws_means)
}

#. handle_errors
synchronize_timestep <- function(ms_df, desired_interval, impute_limit = 30){

    #ms_df is a data.frame or tibble with columns datetime, site_name,
    #ms_status, and one or more data columns. if ms_interp column is already
    #included with input, its values will be carried through to the output.
    #desired_interval is a character string that can be parsed by the "by"
    #parameter to base::seq.POSIXt, e.g. "5 mins"
    #impute_limit is the maximum number of consecutive points to
    #inter/extrapolate. it's passed to imputeTS::na_interpolate

    #output will include a numeric binary column called "ms_interp".
    #0 for not interpolated, 1 for interpolated

    non_data_columns <- c('datetime', 'site_name', 'ms_status', 'ms_interp')
    uniq_sites <- unique(ms_df$site_name)

    ms_df <- ms_df %>%
        filter(! is.na(datetime)) %>%
        select_if(~( sum(! is.na(.)) >= 1 ))

    if(ncol(ms_df) < 4){
        stop('no data to synchronize. bypassing processing.')
    }

    #round to desired_interval
    ms_df <- sw(ms_df %>%
        mutate(
            datetime = lubridate::as_datetime(datetime),
            datetime = lubridate::round_date(datetime,
                                             desired_interval)) %>%
        mutate_at(vars(one_of('ms_status', 'ms_interp')),
                  as.logical) %>%
        group_by(datetime, site_name) %>%
        summarize_all(~ if(is.numeric(.)) mean(., na.rm=TRUE) else any(.)) %>%
        ungroup() %>%
        arrange(datetime))

    #fill in missing timepoints with NAs
    daterange <- range(ms_df$datetime)
    fulldt = seq(daterange[1],
                 daterange[2],
                 by = desired_interval)
    fulldt = tibble(site_name = rep(uniq_sites,
                                    each = length(fulldt)),
                    datetime = rep(fulldt,
                                   times = length(uniq_sites)))

    #if missing, add binary column to track which points are interped
    if(! 'ms_interp'  %in% colnames(ms_df)) ms_df$ms_interp <- FALSE

    #find columns that don't have enough data to do interpolation
    insufficient_data_cols <- ms_df %>%
        select(-non_data_columns) %>%
        summarize_all( ~(sum(! is.na(.)) < 2) ) %>%
        unlist() %>%
        which() %>%
        names()

    #interpolate up to impute_limit; remove empty rows; populate ms_interp column
    ms_df_adjusted <- ms_df %>%
        full_join(fulldt, #right_join would be more efficient, but this is future-proof
                  by = c('datetime', 'site_name')) %>%
        arrange(datetime) %>%
        mutate_at(vars(-one_of(c(non_data_columns, insufficient_data_cols))),
                  imputeTS::na_interpolation,
                  maxgap = impute_limit) %>%
        filter_at(vars(-one_of(non_data_columns)),
                  any_vars(! is.na(.))) %>%
        mutate(
            ms_status = ifelse(is.na(ms_status), FALSE, ms_status),
            ms_interp = ifelse(is.na(ms_interp), TRUE, ms_interp),
            ms_status = as.numeric(ms_status),
            ms_interp = as.numeric(ms_interp)) %>%
        select(site_name, datetime, everything()) %>%
        relocate(ms_status, .after = last_col()) %>%
        relocate(ms_interp, .after = last_col())

    return(ms_df_adjusted)
}

#. handle_errors
recursive_tracker_update <- function(l, elem_name, new_val){

    #implements depth-first tree traversal

    if(is.list(l)){

        nms <- names(l)
        for(i in 1:length(l)){

            subl <- l[[i]]

            if(nms[i] == elem_name){
                l[[i]] <- new_val
            } else if(is.list(subl)){
                l[[i]] <- recursive_tracker_update(subl, elem_name, new_val)
            }

        }
    }

    return(l)
}

#. handle_errors
ms_parallelize <- function(maxcores = Inf){

    #maxcores is the maximum number of processor cores to use for R tasks.
    #   you may want to leave a few aside for other processes.

    #value: a cluster object. you'll need this to return to serial mode and
    #   free up the cores that were employed by R. Be sure to run
    #parallel::stopCluster(<cluster object>) after the parallel tasks are complete.

    #be sure to call

    #we need to find a way to protect some cores for serving the portal
    #if we end up processing data and serving the portal on the same
    #machine/cluster. we can use taskset to assign the shiny process
    #to 1-3 cores and this process to any others.

    ncores <- min(parallel::detectCores(), maxcores)

    if(.Platform$OS.type == 'windows'){
        clst <- parallel::makeCluster(ncores, type = 'PSOCK')
    } else {
        clst <- parallel::makeCluster(ncores, type = 'FORK')
    }

    doParallel::registerDoParallel(clst)

    return(clst)
}

#. handle_errors
idw_parallel_combine <- function(d1, d2){

    #this is for use with foreach loops inside the 3 idw prep functions
    #   (precip_idw, pchem_idw, flux_idw)

    if(is.character(d1) && d1 == 'first iter') return(d2)

    ms_status <- bitwOr(d1$ms_status, d2$ms_status)
    ms_interp <- bitwOr(d1$ms_interp, d2$ms_interp)

    d_comb <- bind_cols(d1[, 1:(ncol(d1) - 2)],
                        d2[, 3, drop = FALSE],
                        tibble(ms_status = ms_status),
                        tibble(ms_interp = ms_interp))

    return(d_comb)
}

#. handle_errors
idw_log_wb <- function(verbose, site_name, i, nw){

    if(! verbose) return()

    msg <- glue('site: {s} ({ii}/{w})',
                s = site_name,
                ii = i,
                w = nw)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
idw_log_var <- function(verbose, site_name, v, j, nvars){

    if(! verbose) return()

    msg <- glue('site: {s} (_/__); var: {vv} ({jj}/{nv})',
                s = site_name,
                vv = v,
                jj = j,
                nv = nvars)

    loginfo(msg,
            logger = logger_module)

    return()
}

#. handle_errors
idw_log_timestep <- function(verbose, site_name=NULL, v, k, ntimesteps){

    if(! verbose) return()

    if(k == 1 || k %% 1000 == 0){
        msg <- glue('site: {s} (_/__); var: {vv} (_/__); timestep: ({kk}/{nt})',
                    s = site_name,
                    vv = v,
                    kk = k,
                    nt = ntimesteps)

        loginfo(msg,
                logger = logger_module)
    }

    return()
}

#. handle_errors
precip_idw <- function(precip_prodname, wb_prodname, pgauge_prodname,
                       precip_prodname_out, verbose = TRUE){

    #load precip data, watershed boundaries, rain gauge locations
    precip <- read_combine_feathers(network = network,
                                    domain = domain,
                                    prodname_ms = precip_prodname)
    # precip = filter(precip, site_name %in% c("GSWS01", "SPOTFI", "UNIT3B", "WS1SDL", "WS3JRD"))
    # precip = manufacture_uncert_msdf(precip)
    wb <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = wb_prodname)
    rg <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = pgauge_prodname)

    #project based on average latlong of watershed boundaries
    bbox <- as.list(sf::st_bbox(wb))
    projstring <- choose_projection(lat = mean(bbox$ymin, bbox$ymax),
                                    long = mean(bbox$xmin, bbox$xmax))
    wb <- sf::st_transform(wb, projstring)
    rg <- sf::st_transform(rg, projstring)

    #get a DEM that encompasses all watersheds; add elev column to rain gauges
    dem <- sm(elevatr::get_elev_raster(wb, z = 12)) #res should adjust with area
    rg$elevation <- terra::extract(dem, rg)

    #clean precip and arrange for matrixification
    detlim <- identify_detection_limit_s(precip$precip)

    #this avoids a lot of slow summarizing
    status_cols <- precip %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    precip <- precip %>%
        filter(site_name %in% rg$site_name) %>%

        #this block is for testing only (makes dataset smaller)
        # mutate(datetime = lubridate::year(datetime)) %>% #by year
        # # # mutate(datetime = lubridate::as_date(datetime)) %>% #by day
        # group_by(site_name, datetime) %>%
        # summarize(
        #     precip = mean(precip, na.rm=TRUE),
        #     ms_status = numeric_any(ms_status),
        #     ms_interp = numeric_any(ms_status)) %>%
        # ungroup() %>%

        select(-ms_status, -ms_interp) %>%
        tidyr::pivot_wider(names_from = site_name,
                           values_from = precip) %>%
        left_join(status_cols,
                  by = 'datetime') %>%
        arrange(datetime)

        # #kept this here in case it's actually somehow faster? (never benchmarked)
        # group_by(datetime) %>%
        # summarize_all(max, na.rm = FALSE) %>%
        # ungroup() %>%
        # arrange(datetime)

        # # and this is the clunky way to summarize status cols (left jic)
        #mutate(
        #    ms_status = as.logical(ms_status),
        #    ms_interp = as.logical(ms_interp)) %>%
        #group_by(datetime) %>%
        #summarize_all(~ if(is.numeric(.)) mean(., na.rm=TRUE) else any(.)) %>%
        #ungroup() %>%
        #mutate(
        #    ms_status = as.numeric(ms_status),
        #    ms_interp = as.numeric(ms_interp)) %>%
        #filter_at(vars(-datetime, -ms_status, -ms_interp),
        #    any_vars(! is.na(.))) %>%
        #arrange(datetime)

    clst <- ms_parallelize()

    #interpolate precipitation volume and write watershed averages
    catchout <- foreach::foreach(i = 1:nrow(wb)) %dopar% {
    # for(j in 1:nrow(wb)){

        wbi <- slice(wb, i)
        site_name <- wbi$site_name

        idw_log_wb(verbose = verbose,
                   site_name = site_name,
                   i = i,
                   nw = nrow(wb))
        # idw_log(phase = 'wb',
        #         from_env = environment(),
        #         verbose, site_name, i, wb)
        # if(verbose){
        #     msg <- glue('site: {s}; {jj}/{w}',
        #         s = site_name,
        #         jj = j,
        #         w = nrow(wb))
        #     loginfo(msg,
        #         logger = logger_module)
        # }

        ws_mean_precip <- shortcut_idw(encompassing_dem = dem,
                                       wshd_bnd = wbi,
                                       data_locations = rg,
                                       data_values = precip,
                                       stream_site_name = site_name,
                                       output_varname = 'precip',
                                       elev_agnostic = FALSE,
                                       verbose = verbose)

        ws_mean_precip$precip <- apply_detection_limit_s(ws_mean_precip$precip,
                                                        detlim)

        #interp final precip to a desirable interval?
        write_ms_file(ws_mean_precip,
                      network = network,
                      domain = domain,
                      prodname_ms = precip_prodname_out,
                      site_name = site_name,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = TRUE)
    }

    parallel::stopCluster(clst)

    return()
}

#. handle_errors
pchem_idw <- function(pchem_prodname, precip_prodname, wb_prodname,
                      pgauge_prodname, pchem_prodname_out, verbose = TRUE){

    #load watershed boundaries, rain gauge locations, precip and pchem data
    wb <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = wb_prodname)
    rg <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = pgauge_prodname)
    pchem <- read_combine_feathers(network = network,
                                   domain = domain,
                                   prodname_ms = pchem_prodname) %>%
        filter(site_name %in% rg$site_name)
    # pchem = manufacture_uncert_msdf(pchem)

    #project based on average latlong of watershed boundaries
    bbox <- as.list(sf::st_bbox(wb))
    projstring <- choose_projection(lat = mean(bbox$ymin, bbox$ymax),
                                    long = mean(bbox$xmin, bbox$xmax))
    wb <- sf::st_transform(wb, projstring)
    rg <- sf::st_transform(rg, projstring)

    #get a DEM that encompasses all watersheds; add elev column to rain gauges
    dem <- sm(elevatr::get_elev_raster(wb, z = 12)) #res should adjust with area
    rg$elevation <- terra::extract(dem, rg)

    # #clean precip and arrange for matrixification (nvm. precip not needed for this)
    # precip <- precip %>%
    #     filter(site_name %in% rg$site_name) %>%
    #     # mutate(datetime = lubridate::year(datetime)) %>% #for testing
    #     # group_by(site_name, datetime) %>%
    #     # summarize(
    #     #     precip = mean(precip, na.rm=TRUE),
    #     #     ms_status = numeric_any(ms_status),
    #     #     ms_interp = numeric_any(ms_interp)) %>%
    #     # ungroup() %>%
    #     tidyr::pivot_wider(names_from = site_name,
    #                        values_from = precip) %>%
    #     mutate(
    #         ms_status = as.logical(ms_status),
    #         ms_interp = as.logical(ms_interp)) %>%
    #     group_by(datetime) %>%
    #     summarize_all(~ if(is.numeric(.)) mean(., na.rm=TRUE) else any(.)) %>%
    #     ungroup() %>%
    #     mutate(
    #         ms_status = as.numeric(ms_status),
    #         ms_interp = as.numeric(ms_interp)) %>%
    #     filter_at(vars(-datetime, -ms_status, -ms_interp),
    #         any_vars(! is.na(.))) %>%
    #     arrange(datetime)

    #organize variables by those that can be flux converted and those that can't
    # flux_vars <- ms_vars$variable_code[as.logical(ms_vars$flux_convertible)]
    pchem_vars <- colnames(select(pchem,
                                  -datetime,
                                  -site_name,
                                  -ms_status,
                                  -ms_interp))
    # -one_of(flux_vars))))

    #this avoids a lot of slow summarizing (IGNORES SITE!)
    status_cols <- pchem %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    #clean pchem one variable at a time, matrixify it, insert it into list
    detlims <- identify_detection_limit_s(pchem)
    nvars <- length(pchem_vars)
    pchem_setlist <- as.list(rep(NA, nvars))
    for(i in 1:nvars){

        v <- pchem_vars[i]

        #clean data and arrange for matrixification
        pchem_setlist[[i]] <- pchem %>%
            select(datetime, site_name, !!v) %>%#, ms_status, ms_interp) %>%
            # filter(site_name %in% rg$site_name) %>%

            #testing block
            # mutate(datetime = lubridate::year(datetime)) %>%
            # # mutate(datetime = lubridate::as_date(datetime)) %>% #finer? coarser?
            # group_by(site_name, datetime) %>%
            # summarize(
            #     !!v := mean(!!sym(v), na.rm=TRUE),
            #     ms_status = numeric_any(ms_status),
            #     ms_interp = numeric_any(ms_interp)) %>%
            # ungroup() %>%
            tidyr::pivot_wider(names_from = site_name,
                               values_from = !!sym(v)) %>%
            left_join(status_cols,
                      by = 'datetime') %>%
            arrange(datetime)
    }

    clst <- ms_parallelize()
    # clst <- parallel::makeCluster(4, type = 'PSOCK')
    # doParallel::registerDoParallel(clst)

    #send vars into regular idw interpolator WITHOUT precip, one at a time;
    #combine and write outputs by site
    # catchout <- foreach::foreach(i = 1:nrow(wb)) %:% {
    # pchem_setlist = lapply(pchem_setlist, function(x) x[1:4,])
    # pchem_setlist = pchem_setlist[1:8]
    # nvars = length(pchem_setlist)
    # pchem_setlist = lapply(pchem_setlist, manufacture_uncert_msdf)
    # verbose = TRUE
    for(i in 1:nrow(wb)){

        wbi <- slice(wb, i)
        site_name <- wbi$site_name

        idw_log_wb(verbose = verbose,
                   site_name = site_name,
                   i = i,
                   nw = nrow(wb))

        ws_mean_d <- foreach::foreach(j = 1:nvars,
                                      .combine = idw_parallel_combine,
                                      .init = 'first iter') %dopar% {
                                      # .packages = idw_pkg_export,
                                      # .export = idw_var_export,
                                      # .errorhandling = 'remove',
                                      # .verbose = TRUE) %dopar% {

        # for(j in 1:nvars){q

            v <- pchem_vars[j]

            # idw_log(phase = 'var')
            # idw_log(phase = 'var',
            #         from_env = environment(),
            #         verbose, site_name, v, j, nvars)
            idw_log_var(verbose = verbose,
                        site_name = site_name,
                        v = v,
                        j = j,
                        nvars = nvars)
            # if(verbose){
            #     msg <- glue('site: {s}; var: {vv}; {jj}/{nv}',
            #         s = site_name,
            #         vv = v,
            #         jj = j,
            #         nv = nvars)
            #     loginfo(msg,
            #         logger = logger_module)
            # }

            # ws_mean <- shortcut_idw(encompassing_dem = dem,
            shortcut_idw(encompassing_dem = dem,
                         wshd_bnd = wbi,
                         data_locations = rg,
                         data_values = pchem_setlist[[j]],
                         stream_site_name = site_name,
                         output_varname = v,
                         elev_agnostic = TRUE,
                         verbose = verbose)
         }

        #     if(j == 1){
        #         datetime_out <- select(ws_mean, datetime)
        #         site_name_out <- select(ws_mean, site_name)
        #         ms_status_out <- ws_mean$ms_status
        #         ms_interp_out <- ws_mean$ms_interp
        #
        #         ws_mean_d <- ws_mean %>%
        #             select(!!v)
        #     } else {
        #         ws_mean_d <- ws_mean %>%
        #             select(!!v) %>%
        #             bind_cols(ws_mean_d)
        #     }
        #
        #     ms_status_out <- bitwOr(ws_mean$ms_status, ms_status_out)
        #     ms_interp_out <- bitwOr(ws_mean$ms_interp, ms_interp_out)
        # }

        # #reassemble tibbles
        # ws_mean_d <- bind_cols(datetime_out, site_name_out, ws_mean_d)
        # ws_mean_d$ms_status <- ms_status_out
        # ws_mean_d$ms_interp <- ms_interp_out

        if(any(is.na(ws_mean_d$datetime))){
            stop('NA datetime found in ws_mean_d')
        }

        ws_mean_d <- apply_detection_limit_s(ws_mean_d, detlims)

        # msg <- glue('{w}, {n}, {d}, {p}',
        #     w = nrow(ws_mean_d),
        #     n = network,
        #     d = domain,
        #     p = prodname_ms)
        # loginfo(msg,
        #     logger = logger_module)

        write_ms_file(ws_mean_d,
                      network = network,
                      domain = domain,
                      prodname_ms = pchem_prodname_out,
                      site_name = site_name,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = TRUE)
    }

    parallel::stopCluster(clst)

    return()
}

#. handle_errors
flux_idw <- function(pchem_prodname, precip_prodname, wb_prodname,
                     pgauge_prodname, flux_prodname_out, verbose = TRUE){

    #load watershed boundaries, rain gauge locations, precip and pchem data
    wb <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = wb_prodname)
    rg <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = pgauge_prodname)
    pchem <- read_combine_feathers(network = network,
                                   domain = domain,
                                   prodname_ms = pchem_prodname) %>%
        filter(site_name %in% rg$site_name)
    # pchem = manufacture_uncert_msdf(pchem)
    precip <- read_combine_feathers(network = network,
                                    domain = domain,
                                    prodname_ms = precip_prodname) %>%
        filter(site_name %in% rg$site_name)
    # precip = manufacture_uncert_msdf(precip)

    #project based on average latlong of watershed boundaries
    bbox <- as.list(sf::st_bbox(wb))
    projstring <- choose_projection(lat = mean(bbox$ymin, bbox$ymax),
                                    long = mean(bbox$xmin, bbox$xmax))
    wb <- sf::st_transform(wb, projstring)
    rg <- sf::st_transform(rg, projstring)

    #get a DEM that encompasses all watersheds; add elev column to rain gauges
    dem <- sm(elevatr::get_elev_raster(wb, z = 12)) #res should adjust with area
    rg$elevation <- terra::extract(dem, rg)

    #this avoids a lot of slow summarizing
    status_cols <- precip %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    #clean precip and arrange for matrixification
    precip <- precip %>%
        # filter(site_name %in% rg$site_name) %>%

        #testing block
        # mutate(datetime = lubridate::year(datetime)) %>%
        # group_by(site_name, datetime) %>%
        # summarize(
        #     precip = mean(precip, na.rm=TRUE),
        #     ms_status = numeric_any(ms_status)) %>%
        # ungroup() %>%

        select(-ms_status, -ms_interp) %>%
        tidyr::pivot_wider(names_from = site_name,
                           values_from = precip) %>%
        left_join(status_cols,
                  by = 'datetime') %>%
        arrange(datetime)

    #organize variables by those that can be flux converted and those that can't
    flux_vars <- ms_vars$variable_code[as.logical(ms_vars$flux_convertible)]
    pchem_vars_fluxable <- colnames(sw(select(pchem,
                                              one_of(flux_vars))))

    #this avoids a lot of slow summarizing
    status_cols <- pchem %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    #clean pchem one variable at a time, matrixify it, insert it into list
    detlims <- identify_detection_limit_s(pchem)
    nvars_fluxable <- length(pchem_vars_fluxable)
    pchem_setlist_fluxable <- as.list(rep(NA, nvars_fluxable))
    for(i in 1:nvars_fluxable){

        v <- pchem_vars_fluxable[i]

        #clean data and arrange for matrixification
        pchem_setlist_fluxable[[i]] <- pchem %>%
            select(datetime, site_name, !!v) %>%
            # filter(site_name %in% rg$site_name) %>%

            #testing block
            # mutate(datetime = lubridate::year(datetime)) %>%
            # group_by(site_name, datetime) %>%
            # summarize(
            #     !!v := mean(!!sym(v), na.rm=TRUE),
            #     ms_status = numeric_any(ms_status)) %>%
            # ungroup() %>%

            tidyr::pivot_wider(names_from = site_name,
                               values_from = !!sym(v)) %>%
            left_join(status_cols,
                      by = 'datetime') %>%
            arrange(datetime)
    }

    clst <- ms_parallelize()

    #send vars into flux interpolator with precip, one at a time;
    #combine and write outputs by site
    # catchout <- foreach::foreach(i = 1:nrow(wb)) %dopar% {
    for(i in 1:nrow(wb)){

        wbi <- slice(wb, i)
        site_name <- wbi$site_name

        idw_log_wb(verbose = verbose,
                   site_name = site_name,
                   i = i,
                   nw = nrow(wb))
        # if(verbose){
        #     msg <- glue('site: {s}; {ii}/{w}',
        #         s = site_name,
        #         ii = i,
        #         w = nrow(wb))
        #     loginfo(msg,
        #         logger = logger_module)
        # }

        ws_mean_flux <- foreach::foreach(j = 1:nvars_fluxable,
                                         .combine = idw_parallel_combine,
                                         .init = 'first iter') %dopar% {
                                         # .packages = idw_pkg_export,
                                         # .export = idw_var_export) %dopar% {
        # for(j in 1:nvars_fluxable){

            v <- pchem_vars_fluxable[j]

            idw_log_var(verbose = verbose,
                        site_name = site_name,
                        v = v,
                        j = j,
                        nvars = nvars)

            shortcut_idw_concflux(encompassing_dem = dem,
                                  wshd_bnd = wbi,
                                  data_locations = rg,
                                  precip_values = precip,
                                  chem_values = pchem_setlist_fluxable[[j]],
                                  stream_site_name = site_name,
                                  verbose = verbose)
        }

        #     if(j == 1){
        #         datetime_out <- select(ws_means, datetime)
        #         site_name_out <- select(ws_means, site_name)
        #         ms_status_out <- ws_means$ms_status
        #         ms_interp_out <- ws_means$ms_interp
        #
        #         # ws_mean_conc <- ws_means %>%
        #         #     select(concentration) %>%
        #         #     rename(!!v := concentration)
        #
        #         ws_mean_flux <- ws_means %>%
        #             select(flux) %>%
        #             rename(!!v := flux)
        #     } else {
        #         # ws_mean_conc <- ws_means %>%
        #         #     select(concentration) %>%
        #         #     rename(!!v := concentration) %>%
        #         #     bind_cols(ws_mean_conc)
        #
        #         ws_mean_flux <- ws_means %>%
        #             select(flux) %>%
        #             rename(!!v := flux) %>%
        #             bind_cols(ws_mean_flux)
        #     }
        #
        #     ms_status_out <- bitwOr(ws_means$ms_status, ms_status_out)
        #     ms_interp_out <- bitwOr(ws_means$ms_interp, ms_interp_out)
        # }
        #
        # #reassemble tibbles
        # # ws_mean_conc <- bind_cols(datetime_out, site_name_out, ws_mean_conc)
        # ws_mean_flux <- bind_cols(datetime_out, site_name_out, ws_mean_flux)
        # ws_mean_flux$ms_status <- ms_status_out
        # ws_mean_flux$ms_interp <- ms_interp_out
        # # ws_mean_conc$ms_status <- ws_mean_flux$ms_status <- ms_status_out
        # # ws_mean_conc$ms_interp <- ws_mean_flux$ms_interp <- ms_interp_out

        # if(any(is.na(ws_mean_conc$datetime))){
        #     stop('NA datetime found in ws_mean_conc')
        # }
        if(any(is.na(ws_mean_flux$datetime))){
            stop('NA datetime found in ws_mean_flux')
        }

        # ue(write_ms_file(ws_mean_conc,
        #                  network = network,
        #                  domain = domain,
        #                  prodname_ms = prodname_ms,
        #                  site_name = site_name,
        #                  level = 'derived',
        #                  shapefile = FALSE,
        #                  link_to_portal = TRUE))

        ws_mean_flux <- apply_detection_limit_s(ws_mean_flux, detlims)

        ue(write_ms_file(ws_mean_flux,
                         network = network,
                         domain = domain,
                         prodname_ms = flux_prodname_out,
                         site_name = site_name,
                         level = 'derived',
                         shapefile = FALSE,
                         link_to_portal = TRUE))
    }

    parallel::stopCluster(clst)

    return()
}

#. handle_errors
invalidate_derived_products <- function(successor_string){

    if(all(is.na(successor_string)) || successor_string == ''){
        return()
    }

    successors <- strsplit(successor_string, '\\|\\|')[[1]]

    for(s in successors){

        catch <- update_data_tracker_d(network = network,
                                       domain = domain,
                                       tracker_name = 'held_data',
                                       prodname_ms = s,
                                       site_name = 'sitename_NA',
                                       new_status = 'pending')
    }

    return()
}

#. handle_errors
write_metadata_r <- function(murl, network, domain, prodname_ms){

    #this writes the metadata file for retrieved macrosheds data
    #see write_metadata_m for munged macrosheds data and write_metadata_d
    #for derived macrosheds data

    #also see read_metadata_r

    #create raw directory if necessary

    raw_dir <- glue('data/{n}/{d}/raw/documentation',
                    n = network,
                    d = domain)
    dir.create(raw_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #write metadata file
    data_acq_file <- glue('{rd}/documentation_{p}.txt',
                          rd = raw_dir,
                          p = prodname_ms)

    readr::write_file(murl,
                      path = data_acq_file)

    # #create portal directory if necessary
    # portal_dir <- glue('../portal/data/{d}/{p}', #portal ignores network
    #                    d = domain,
    #                    p = strsplit(prodname_ms, '__')[[1]][1])
    # dir.create(portal_dir,
    #            showWarnings = FALSE,
    #            recursive = TRUE)
    #
    # #hardlink file
    # portal_file <- glue(portal_dir, '/raw_data_documentation_url.txt')
    # unlink(portal_file)
    # invisible(sw(file.link(to = portal_file,
    #                        from = data_acq_file)))

    return()
}

#. handle_errors
read_metadata_r <- function(network, domain, prodname_ms){

    #this reads the metadata file for retrieved macrosheds data

    #also see write_metadata_r, write_metadata_m, and write_metadata_d

    murlfile <- glue('data/{n}/{d}/raw/documentation/documentation_{p}.txt',
                     n = network,
                     d = domain,
                     p = prodname_ms)

    murl <- readr::read_file(murlfile)#, silent = TRUE)

    # if('try-error' %in% class(murl)){
    #     return(NULL)
    # } else {
    return(murl)
    # }
}

#. handle_errors
get_precursors <- function(network, domain, prodname_ms){

    #this determines which munged products were used to generate
    #a derived product

    prodfile <- glue('src/{n}/{d}/products.csv',
                     n = network,
                     d = domain)
    allprods <- sm(read_csv(prodfile))

    prodnames_ms <- paste(allprods$prodname,
                          allprods$prodcode,
                          sep='__')

    precursor_bool <- vapply(allprods$precursor_of,
                             function(x){
                                 prodname_ms %in% strsplit(as.character(x),
                                                           '\\|\\|')[[1]]
                             },
                             FUN.VALUE = logical(1),
                             USE.NAMES = FALSE)

    precursors <- prodnames_ms[precursor_bool]
    precursors <- if(length(precursors)) precursors else 'no precursors'

    return(precursors)
}

#. handle_errors
document_kernel_code <- function(network, domain, prodname_ms, level){

    #this documents the code used to munge macrosheds data from raw source data.
    #see document_code_d for derived macrosheds data

    #level is numeric 0, 1, or 2, corresponding to raw, munged, derived

    if(! is.numeric(level) || ! level %in% 0:2){
        stop('level must be numeric 0, 1, or 2')
    }

    kernel_file <- glue('src/{n}/{d}/processing_kernels.R',
                        n = network,
                        d = domain)

    thisenv <- environment()

    sw(source(kernel_file, local = TRUE))

    # kernel_func <- tryCatch({
    prodcode <- prodcode_from_prodname_ms(prodname_ms)
    fnc <- mget(paste0('process_', level, '_', prodcode),
                envir = thisenv,
                inherits = FALSE,
                ifnotfound = list(''))[[1]] #arg only available in mget
    kernel_func <- paste(deparse(fnc), collapse = '\n')
    # }, error = function(e) return(NULL))

    return(kernel_func)
}

#. handle_errors
write_metadata_m <- function(network, domain, prodname_ms){

    #this writes the metadata file for munged macrosheds data
    #see write_metadata_r for retrieved macrosheds data and write_metadata_d
    #for derived macrosheds data

    #also see read_metadata_r

    #assemble metadata
    sitelist <- names(held_data[[prodname_ms]])
    complist <- lapply(sitelist,
                       function(x){
                           held_data[[prodname_ms]][[x]]$retrieve$component
                       })
    compsbysite <- mapply(function(s, c){
        glue('\tfor site: {s}\n\t\tcomp(s): {c}',
             s = s,
             c = paste(c, collapse = ', '),
             .trim = FALSE)
    }, sitelist, complist)

    display_args <- list(network = paste0("'", network, "'"),
                         domain = paste0("'", domain, "'"),
                         prodname_ms = paste0("'", prodname_ms, "'"),
                         # site_name = paste0("'", site_name, "'"),
                         site_name = glue("<each of: '",
                                          paste(sitelist,
                                                collapse = "', '"),
                                          "'>"),
                         `component(s)` = paste0('\n',
                                                 paste(compsbysite,
                                                       collapse = '\n')))

    metadata_r <- ue(read_metadata_r(network = network,
                                     domain = domain,
                                     prodname_ms = prodname_ms))

    code_m <- ue(document_kernel_code(network = network,
                                      domain = domain,
                                      prodname_ms = prodname_ms,
                                      level = 1))

    mdoc <- read_file('src/templates/write_metadata_m_boilerplate.txt') %>%
        glue(.,
             p = prodname_ms,
             mr = metadata_r,
             k = code_m,
             a = paste(names(display_args),
                       display_args,
                       sep = ' = ',
                       collapse = '\n'))

    #create munged directory if necessary
    munged_dir <- glue('data/{n}/{d}/munged/documentation',
                       n = network,
                       d = domain)
    dir.create(munged_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #write metadata file
    data_acq_file <- glue('{md}/documentation_{p}.txt',
                          md = munged_dir,
                          p = prodname_ms)
    readr::write_file(mdoc,
                      path = data_acq_file)

    #create portal directory if necessary
    portal_dir <- glue('../portal/data/{d}/documentation', #portal ignores network
                       d = domain)
    dir.create(portal_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #hardlink file
    portal_file <- glue('{pd}/documentation_{p}.txt',
                        pd = portal_dir,
                        p = prodname_ms)
    unlink(portal_file)
    invisible(sw(file.link(to = portal_file,
                           from = data_acq_file)))

    return()
}

#. handle_errors
write_metadata_d <- function(network, domain, prodname_ms){

    #this writes the metadata file for derived macrosheds data
    #see write_metadata_r for retrieved macrosheds data and write_metadata_m
    #for munged macrosheds data

    #also see read_metadata_r

    #assemble metadata
    display_args <- list(network = paste0("'", network, "'"),
                         domain = paste0("'", domain, "'"),
                         prodname_ms = paste0("'", prodname_ms, "'"))

    precursors <- ue(get_precursors(network = network,
                                    domain = domain,
                                    prodname_ms = prodname_ms))

    code_d <- ue(document_kernel_code(network = network,
                                      domain = domain,
                                      prodname_ms = prodname_ms,
                                      level = 2))

    ddoc <- read_file('src/templates/write_metadata_d_boilerplate.txt') %>%
        glue(.,
             p = prodname_ms,
             mp = paste(precursors, collapse = '\n'),
             k = code_d,
             a = paste(names(display_args),
                       display_args,
                       sep = ' = ',
                       collapse = '\n'))

    #create derived directory if necessary
    derived_dir <- glue('data/{n}/{d}/derived/documentation',
                        n = network,
                        d = domain)
                        # p = prodname_ms)
    dir.create(derived_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #write metadata file
    data_acq_file <- glue('{dd}/documentation_{p}.txt',
                          dd = derived_dir,
                          p = prodname_ms)
    readr::write_file(ddoc,
                      path = data_acq_file)

    #create portal directory if necessary
    portal_dir <- glue('../portal/data/{d}/documentation', #portal ignores network
                       d = domain)
                       # p = strsplit(prodname_ms, '__')[[1]][1])
    dir.create(portal_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #hardlink file
    portal_file <- glue('{pd}/documentation_{p}.txt',
                        pd = portal_dir,
                        p = prodname_ms)
    unlink(portal_file) #this will overwrite any munged product supervened by derive
    invisible(sw(file.link(to = portal_file,
                           from = data_acq_file)))

    return()
}

#. handle_errors
identify_detection_limit_s <- function(x){

    #this is the scalar version of identify_detection_limit (_s).
    #it was the first iteration, and has been superseded by the temporally-
    #explicit version (identify_detection_limit_t).
    #that version relies on stored data, so automatically
    #writes to data/<network>/<domain>/detection_limits.json. This version
    #just returns its output. This version is still used for idw (where input
    #sites != output sites), but we should find a way to get the minimum input
    #detection limit for all sites being averaged and apply that detlim to the
    #output.)

    #if x is a 2d array-like object, the detection limit (number of
    #decimal places) of each column is returned. non-numeric columns return NA.
    #If x is a vector (or something that can be coerced to a vector),
    #the detection limit is returned as a scalar.

    #detection limit is computed as the 10th percentile of the number of characters
    #following each decimal place. NAs and zeros are ignored when computing
    #detection limit.

    identify_detection_limit_v <- function(x){

        #x is a vector, or it will be coerced to one.
        #non-numeric vectors return NA vectors of the same length

        x <- unname(unlist(x))
        if(! is.numeric(x)) return(rep(NA, length(x)))

        options(scipen = 100)
        nas <- is.na(x) | x == 0

        x <- as.character(x)
        nsigdigs <- stringr::str_split_fixed(x, '\\.', 2)[, 2] %>%
            nchar()

        nsigdigs[nas] <- NA

        options(scipen = 0)

        return(nsigdigs)
    }

    if(! is.null(dim(x))){

        detlim <- vapply(X = x,
                         FUN = function(y){
                             identify_detection_limit_v(y) %>%
                                 # Mode(na.rm = TRUE)
                                 quantile(probs = 0.1,
                                          na.rm = TRUE,
                                          names = FALSE)
                         },
                         FUN.VALUE = numeric(1))

    } else if(is.atomic(x) && length(x)){
        detlim <- identify_detection_limit_v(x) %>%
            # Mode(na.rm=TRUE)
            quantile(probs = 0.1,
                     na.rm = TRUE,
                     names = FALSE)
    } else {
        stop('x must be a vector or 2d array-like')
    }

    return(detlim)
}

#. handle_errors
apply_detection_limit_s <- function(x, digits){

    #this is the scalar version of apply_detection_limit (_s).
    #it was the first iteration, and has been superseded by the temporally-
    #explicit version (apply_detection_limit_t).
    #that version relies on stored data, so automatically
    #reads from data/<network>/<domain>/detection_limits.json. This version
    #just accepts detection limits as an argument.
    #This version is still used for idw (where input
    #sites != output sites), but we should find a way to get the minimum input
    #detection limit for all sites being averaged and apply that detlim to the
    #output.)

    #x: a 2d array-like or a numeric vector
    #digits: a numeric vector if x is a 2d array-like, or a numeric scalar if
    #digits is a vector or vector-like, containing the detection limits (in
    #digits after the decimal) to be applied to x. application of detection
    #limits is handled by round.

    #if x is a 2d array-like object, digits are applied column-wise
    #If x is a vector (or something that can be coerced to a vector),
    #digits is applied elementwise

    #if x is a 2d array-like with named columns and digits is a named vector,
    #values of digits are matched by name to columns of x. unmatched values
    #of digits are ignored. unmatched columns of x are unaffected.
    #if either x or digits is not named, all names are ignored.

    #attempting to apply detection limits to non-numerics results in error

    #NA values of digits are not used.

    if(! is.numeric(digits) && ! all(is.na(digits))){
        stop('digits must be numeric')
    }

    apply_detection_limit_v <- function(x, digits){

        x <- unname(unlist(x))
        if(is.na(digits)) return(x)
        if(! is.numeric(x)) stop('all affected columns of x must be numeric.')
        x <- round(x, digits)

        return(x)
    }

    if(! is.null(dim(x))){

        # if(length(digits) != ncol(x)){
        #     stop('length of digits must equal number of columns in x')
        # }

        if(! is.null(names(digits)) && ! is.null(colnames(x))){

            #if any columns don't have detection limits specified,
            #fill in those missing specifications with NAs
            missing_specifications <- setdiff(colnames(x), names(digits))
            more_digits <- rep(NA, length(missing_specifications))
            names(more_digits) <- missing_specifications
            digits <- c(digits, more_digits)

            #ignore detection limits whose names don't match names in x
            reorder <- match(colnames(x), names(digits))
            digits <- digits[! is.na(reorder)]
            reorder <- reorder[! is.na(reorder)]
            digits <- digits[reorder]

        } else if(length(digits) != ncol(x)){
            stop('length of digits must equal number of columns in x')
        }

        x <- mapply(FUN = function(y, z){
                    apply_detection_limit_v(y, z)
                },
                y = x,
                z = digits,
                SIMPLIFY = FALSE) %>%
            as_tibble()

    } else if(is.atomic(x) && length(x)){

        if(length(digits) != 1){
            stop('length of digits must be 1 if x is a vector')
        }

        x <- apply_detection_limit_v(x, digits)

    } else {
        stop('x must be a vector or 2d array-like')
    }

    return(x)
}

#. handle_errors
Mode <- function(x, na.rm = TRUE){

    if(na.rm){
        x <- na.omit(x)
    }

    ux <- unique(x)
    mode_out <- ux[which.max(tabulate(match(x, ux)))]
    return(mode_out)

}

#. handle_errors
identify_detection_limit_t <- function(X, network, domain,
                                       return_detlims = FALSE){

    #this is the temporally explicit version of identify_detection_limit (_t).
    #it supersedes the scalar version (identify_detection_limit_s).
    #that version just returns its output. This version relies on stored data,
    #so automatically writes to data/<network>/<domain>/detection_limits.json,
    #and, if return_detlims = TRUE, returns its output as an integer matrix
    #of detection limits with size equal to that of X.

    #X is a 2d array-like object with column names. must have datetime and
    #site_name columns.

    #the detection limit (number of decimal places)
    #of each column is written to data/<network>/<domain>/detection_limits.json
    #as a nested list:
    #prodname_ms
    #    variable
    #        startdt1: limit1
    #        startdt2: limit2 ...
    #non-numeric columns are not considered variables and are given detlims of
    #NA, beginning at the earliest datetime for each site. If
    #return_detlims == TRUE, these columns are populated with NAs.
    #macrosheds-canonical columns (datetime, site_name, ms_status, ms_interp)
    #are recognized as non-variables and given detection limits of NA

    #detection limit (detlim) for each site-variable-datetime is computed as the
    #number of characters following each decimal place. NA detlims are filled
    #by locf, followed by nocb. Then, to account for false detlims arising from
    #trailing zeros, positive monotonicity is forced by carrying forward
    #cumulative maximum detlims. Each time the detlim increases,
    #a new startdt and limit are recorded.

    #X will be sorted ascendingly by site_name and then datetime.

    X <- as_tibble(X) %>%
        arrange(site_name, datetime)

    # if(! 'site_name' %in% colnames(X)){
    #     sitename_present <- FALSE
    #     X$site_name = '0'
    # } else {
    #     sitename_present <- TRUE
    # }

    identify_detection_limit_v <- function(x, varnm, dt, sn, output = 'list'){

        #x is a vector
        #varnm is the name of the column that became x
        #dt is a datetime vector
        #sn is a site name vector
        #output is either 'list' or 'vector'. If 'list', this function
        #   summarizes x by site, returning a list of site names, each containing
        #   two elements, a vector of start dates, and a vector of corresponding
        #   detection limits. Detection limits are only recorded for the first
        #   value and for any change that follows. If output is 'vector', this
        #   function returns a vector of detection limits the same length as x.

        #non-numeric vectors return NA detection limits

        sites <- unique(sn)

        #for non-numerics, build a list of prodname -> site -> dt: lim
        #where dt is always the earliest datetime and lim is always NA
        if(varnm %in% ms_canonicals || ! is.numeric(x)){

            if(output == 'vector'){
                detlim <- rep(NA, length(x))
                return(detlim)
            }

            detlim <- list()
            for(i in 1:length(sites)){
                nulldt <- as.character(dt[sn == sites[i]][1])
                detlim[[i]] <- list(startdt = nulldt,
                                    lim = NA)
            }

            names(detlim) <- sites
            return(detlim)
        }

        options(scipen = 100)
        nas <- is.na(x) | x == 0

        x <- as.character(x)
        nsigdigs <- stringr::str_split_fixed(x, '\\.', 2)[, 2] %>%
            nchar()

        nsigdigs[nas] <- NA

        #for each site, clean up the timeseries of detection limits:
        #   first, fill NAs by locf, then by nocb
        #   next, force positive monotonicity by locf
        nsigdigs_l <- tibble(nsigdigs, dt, sn) %>%
            base::split(sn) %>%
            map(~ if(all(is.na(.x$nsigdigs))) .x else
                mutate(.x,
                       nsigdigs = imputeTS::na_locf(nsigdigs,
                                                    na_remaining = 'rev') %>%
                           force_monotonic_locf()))

        if(output == 'vector'){

            #avoid the case where the first few detection lims
            #are artificially set low because their last sigdig is 0
            nsigdigs_l <- lapply(X = nsigdigs_l,
                                 FUN = function(z){

                                     #for sites with all-NA detlims, return as-is
                                     if(all(is.na(z$nsigdigs))){
                                         return(z)
                                     }

                                     if(length(z$nsigdigs) > 5 &&
                                        length(unique(z$nsigdigs[1:5]) > 1)){
                                         z$nsigdigs[1:5] <- z$nsigdigs[6]
                                     }

                                     return(z)
                                 })

            nsigdigs_df <- Reduce(bind_rows, nsigdigs_l) %>%
                arrange(sn, dt) #probably superfluous, but safe

            options(scipen = 0)

            detlims <- nsigdigs_df$nsigdigs

            return(detlims)
        }

        #build datetime-detlim pairs for each change in detlim for each variable
        detlims <- lapply(X = nsigdigs_l,
                          FUN = function(z){

                              #for sites with all-NA detlims, build the same
                              #default list as above
                              if(all(is.na(z$nsigdigs))){
                                  detlims <- list(startdt = as.character(z$dt[1]),
                                                  lim = NA)
                                  return(detlims)
                              }

                              runs <- rle2(z$nsigdigs)

                              #avoid the case where the first few detection lims
                              #are artificially set low because their last
                              #sigdig is 0
                              if(runs$lengths[1] %in% 1:5 && nrow(runs) > 1){
                                  runs <- runs[-1, ]
                                  runs$starts[1] <- 1
                              }

                              detlims <- list(startdt = as.character(z$dt[runs$starts]),
                                              lim = runs$values)
                          })

        options(scipen = 0)

        return(detlims)
    }

    if(! is.null(dim(X))){

        detlim <- mapply(FUN = function(X, varnms, dt, sn){
                             identify_detection_limit_v(x = X,
                                                        varnm = varnms,
                                                        dt = dt,
                                                        sn = sn)
                         },
                         X = X,
                         varnms = colnames(X),
                         MoreArgs = list(dt = X$datetime,
                                         sn = X$site_name),
                         SIMPLIFY = FALSE)

    } else {
        stop('X must be a 2d array-like')
    }

    write_detection_limit(detlim,
                          network = network,
                          domain = domain)

    if(return_detlims){

        # detlim <- lapply(X = X,
        #                  FUN = function(y, dt, sn){
        #                      identify_detection_limit_v(y,
        #                                                 dt = dt,
        #                                                 sn = sn,
        #                                                 output = 'vector')
        #                  },
        #                  dt = X$datetime,
        #                  sn = X$site_name) %>%
        detlim <- mapply(FUN = function(X, varnms, dt, sn){
                             identify_detection_limit_v(x = X,
                                                        varnm = varnms,
                                                        dt = dt,
                                                        sn = sn,
                                                        output = 'vector')
                         },
                         X = X,
                         varnms = colnames(X),
                         MoreArgs = list(dt = X$datetime,
                                         sn = X$site_name),
                         SIMPLIFY = FALSE) %>%
            as_tibble()

        return(detlim)
    }

    return()
}

#. handle_errors
apply_detection_limit_t <- function(X, network, domain){

    #this is the temporally explicit version of identify_detection_limit (_t).
    #it supersedes the scalar version (identify_detection_limit_s).
    #that version just returns its output. This version relies on stored data,
    #so automatically reads from data/<network>/<domain>/detection_limits.json.

    #X is a 2d array-like object with column names. must have a datetime column

    #attempting to apply detection limits to non-numerics results in error. The
    #following macrosheds-canonical column names are automatically skipped:
    #ms_status, ms_interp, site_name, datetime. Attempting to apply detection
    #limits to a variable for which detection limits are not known (not present
    #in detection_limits.json) results in error. Superfluous variable entries in
    #detection_limits.json are ignored.

    X <- as_tibble(X) %>%
        arrange(site_name, datetime)

    detlim <- read_detection_limit(network, domain)
    if(is_ms_err(detlim)){
        stop('problem reading detection limits from file')
    }

    apply_detection_limit_v <- function(x, varnm, dt, sn, detlim){

        if(varnm %in% c('ms_status', 'ms_interp', 'site_name', 'datetime')){
            return(x)
        }

        if(! is.numeric(x)) return(x)
        if(is.numeric(x) && ! varnm %in% names(detlim)){
            stop(glue('Missing detection limits for var: {v}', v = varnm))
        }

        detlim_var <- detlim[[varnm]]

        site_lst <- tibble(dt, sn, x) %>%
            base::split(sn)

        # detlim_varsite = list(startdt=c("2005-05-31 05:10:00", "2005-08-03 01:40:00"),
        #                       lim=c(1, 2))
        # z = site_lst[[1]]

        Xerr <- lapply(X = site_lst,
                       FUN = function(z) errors(z$x)) %>%
            unlist() %>%
            unname()

        rounded <- lapply(X = site_lst,
                          FUN = function(z){

                              if(all(is.na(z$x))) return(z$x)

                              detlim_varsite <- detlim_var[[z$sn[1]]]
                              if(all(is.na(detlim_varsite$lim))) return(z$x)

                              cutvec <- c(as.POSIXct(detlim_varsite$startdt,
                                                     tz = 'UTC'),
                                          as.POSIXct('2900-01-01 00:00:00'))

                              roundvec <- cut(x = z$dt,
                                              breaks = cutvec,
                                              include.lowest = TRUE,
                                              labels = detlim_varsite$lim) %>%
                                              as.character() %>%
                                              as.numeric()

                              rounded <- mapply(FUN = function(a, b){
                                                    round(a, b)
                                                },
                                                a = z$x,
                                                b = roundvec,
                                                USE.NAMES = FALSE)

                              return(rounded)
                          }) %>%
            unlist() %>%
            unname()

        errors(rounded) <- Xerr

        return(rounded)
    }

    if(! is.null(dim(X))){

        X <- mapply(FUN = function(X, varnms, dt, sn, detlim){

                        apply_detection_limit_v(x = X,
                                                varnm = varnms,
                                                dt = dt,
                                                sn = sn,
                                                detlim = detlim)

                    },
                    X = X,
                    varnms = colnames(X),
                    MoreArgs = list(dt = X$datetime,
                                    sn = X$site_name,
                                    detlim = detlim),
                    SIMPLIFY = FALSE)

        X = as_tibble(X)

    } else {
        stop('X must be a 2d array-like')
    }

    return(X)
}

#. handle_errors
read_detection_limit <- function(network, domain){

    detlims <- glue('data/{n}/{d}/detection_limits.json',
                    n = network,
                    d = domain) %>%
        readr::read_file() %>%
        jsonlite::fromJSON()

    # detlims_prod <- detlims[[prodname_ms]]

    return(detlims)
}

#. handle_errors
write_detection_limit <- function(detlim, network, domain){

    detlims_file <- glue('data/{n}/{d}/detection_limits.json',
                         n = network,
                         d = domain)

    readr::write_file(jsonlite::toJSON(detlim), detlims_file)

    return()
}

#. handle_errors
rle2 <- function(x){#, return_list = FALSE){

    r <- rle(x)
    ends <- cumsum(r$lengths)

    # if(return_list){
    #
    #     r <- list(values = r$values,
    #               starts = c(1, ends[-length(ends)] + 1),
    #               stops = ends,
    #               lengths = r$lengths)
    #
    # } else {

    r <- tibble(values = r$values,
                starts = c(1, ends[-length(ends)] + 1),
                stops = ends,
                lengths = r$lengths)
    # }

    return(r)
}

#. handle_errors
force_monotonic_locf <- function(v, ascending = TRUE){

    if(any(is.na(v))){
        stop('v may not contain NAs')
    }

    if(ascending){
        mv <- cummax(v)
        adjust <- v < mv
    } else {
        mv <- cummin(v)
        adjust <- v > mv
    }

    runs <- rle2(adjust)

    for(i in which(runs$values)){
        stt <- runs$starts[i]
        stp <- runs$stops[i]
        replc <- v[runs$stops[i - 1]]
        v[stt:stp] <- replc
    }

    return(v)
}

#. handle_errors
detection_limit_as_uncertainty <- function(detlim){

    uncert <- lapply(detlim,
                     FUN = function(x) 1 / 10^x) %>%
                  as_tibble()

    return(uncert)
}

#. handle_errors
insert_uncertainty_df <- function(x, uncert){

    #x is a data.frame of data values
    #uncert is a data.frame of corresponding uncertainty values to be inserted.
    #   column names of uncert will be matched to those of x. columns in x that
    #   are not in uncert are ignored (with a warning if they're non-canonical).
    #   columns of uncert that are not in x raise an error.

    # if(! base::setequal(colnames(x), colnames(uncert))){
    if( length(base::setdiff(colnames(uncert), colnames(x))) ){
        stop('uncert cannot contain columns that are not in x')
    }

    xonlycols <- base::setdiff(colnames(x), colnames(uncert))
    if(any(! xonlycols %in% ms_canonicals)){
        warning("x contains non-canonical columns that aren't in uncert.")
    }

    # for(n in colnames(x)){
    for(n in colnames(uncert)){
        if(all(is.na(uncert[[n]]))) next
        errors(x[[n]]) <- uncert[[n]]
    }

    return(x)
}

#. handle_errors
carry_uncertainty <- function(d, network, domain){

    u <- identify_detection_limit_t(d,
                                    network = network,
                                    domain = domain,
                                    return_detlims = TRUE)
    u <- detection_limit_as_uncertainty(u)
    d <- insert_uncertainty_df(d, u)

    return(d)
}

#. handle_errors
err_df_to_matrix <- function(df){

    if(! all(sapply(df, class) %in% c('errors', 'numeric'))){
        stop('all columns of df must be of class "errors" or "numeric"')
    }

    errmat <- as.matrix(as.data.frame(lapply(df, errors)))
    M <- as.matrix(df)
    errors(M) <- errmat

    return(M)
}

#. handle_errors
get_relative_uncert <- function(x){

    if(any(class(x) %in% c('list', 'data.frame', 'array'))){
        stop(glue('this function not yet adapted for class {cl}',
                  cl = paste(class(tibble(x=1:3)),
                             collapse = ', ')))
    }

    ru <- errors(x) / errors::drop_errors(x) * 100

    return(ru)
}
