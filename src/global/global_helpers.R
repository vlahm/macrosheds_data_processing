#functions without the "#. handle_errors" decorator have special error handling

handle_errors <- function(f){

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

            if(exists('s')) site_code = s
            if(! exists('site_code')) site_code = 'NO SITE'
            if(! exists('prodname_ms')) prodname_ms = 'NO PRODUCT'

            full_message = glue('{ec}\n\n',
                                'NETWORK: {n}\nDOMAIN: {d}\nSITE: {s}\n',
                                'PRODUCT: {p}\nERROR_MSG: {e}\nMS_CALLSTACK: {c}\n\n_',
                                ec=err_cnt, n=network, d=domain, s=site_code, p=prodname_ms,
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
source('src/global/munge_engines.R')

if(ms_instance$use_ms_error_handling){
    source_decoratees('src/global/munge_engines.R')
}

assign('protected_environment',
       value = new.env(parent = .GlobalEnv),
       envir = .GlobalEnv)
assign('email_err_msgs',
       value = list(),
       envir = .GlobalEnv)
assign('err_cnt',
       value = 0,
       envir = .GlobalEnv)
assign('unique_errors',
       value = c(),
       envir = .GlobalEnv)
assign('unique_exceptions',
       value = c(),
       envir = .GlobalEnv)
assign('typical_derprods',
       value = c('precipitation', 'precip_chemistry', 'stream_flux_inst',
                 'precip_flux_inst', 'precip_pchem_pflux'),
       envir = .GlobalEnv)
assign('canonical_derprods',
       value = c('stream_flux_inst', 'discharge', 'precip_gauge_locations',
                 # 'precipitation', 'precip_chemistry',  'precip_flux_inst',
                 'stream_chemistry', 'stream_gauge_locations', 'ws_boundary'),
       envir = .GlobalEnv)

molecular_conversion_map <- list(
    NH4 = 'N',
    NH3 = 'N',
    NH3_NH4 = 'N',
    NO3 = 'N',
    NO2 = 'N',
    NO3_NO2 = 'N',
    SiO3 = 'Si',
    SiO2 = 'Si',
    SO4 = 'S',
    PO4 = 'P',
    orthophosphate = 'P')
assign('molecular_conversion_map',
       value = molecular_conversion_map,
       envir = .GlobalEnv)

normally_converted_molecules <- names(molecular_conversion_map)
normally_converted_to <- paste(normally_converted_molecules,
                               str_extract(normally_converted_molecules, '^([NPS]i?)', group = 0),
                               sep = '_')
if(sum(grepl('_NA$', normally_converted_to)) != 1) stop('molecular_conversion_map has changed')
normally_converted_to <- sub('_NA$', '_P', normally_converted_to)

assign('normally_converted_molecules',
       value = normally_converted_molecules,
       envir = .GlobalEnv)

assign('normally_converted_to',
       value = normally_converted_to,
       envir = .GlobalEnv)

status_codes <- c('READY', 'PENDING', 'PAUSED', 'OBSOLETE', 'TEST')
assign('status_codes',
       value = status_codes,
       envir = .GlobalEnv)

known_publishers <- c(
    'Environmental Data Initiative',
    'HydroShare',
    'Watershed Function SFA, ESS-DIVE repository',
    'U.S. Geological Survey',
    'United States Geological Survey (USGS), Environmental Protection Agency (EPA)',
    'Wisconsin State Laboratory of Hygiene',#add to loch vale
    'National Water Information Service',
    'Forest Science Data Bank',
    'USDA Ag Data Commons', #add to santee (also need to add a url in santee?)
    'Forest Service Research Data Archive',
    'U.S. Forest Service, Northern Region',
    'NEON', #manually added to record
    'Carbon Dioxide Information Analysis Center, Oak Ridge National Laboratory, U.S. Department of Energy',
    'Penn State University', #add to shale_hills
    #these are for ws_attrs
    'United States Department of Agriculture, Natural Resources Conservation Service',
    'Joerd',
    'Remote Sensing in Ecology and Conservation',
    'NASA EOSDIS Land Processes DAAC',
    'NASA EOSDIS Land Processes Distributed Active Archive Center',
    'Oregon State University',
    'Earth Resources Observation and Science (EROS) Center',
    'ORNL DAAC',
    'NASA National Snow and Ice Data Center Distributed Active Archive Center',
    'PANGAEA',
    'ISPRS Journal of Photogrammetry and Remote Sensing',
    'International Journal of Climatology', #journal
    'Scholars Portal Dataverse',
    'Svartberget Research Station',
    'SITES',
    'Water Resour. Res' #journal
)
#known_publishers NOTES. fix these in citation gsheet before building dataset.
#(also apply to institutional_authors below):
#IF any more journals get added as publishers and they don't have the word "Journal" in their name,
#   convert_ms_to_bib() will need to be updated accordingly (to recognize when to use journal formatting)
#   suef may need url
#   sleepers might need commas changed to periods
#   shale_hills might need commas changed to periods and ampersands added to authors
#   one east_river site has "ESS_DIVE" instead of "ESS-DIVE"
#   run find and replace on the gsheet using this expression: \(([0-9]{4})[a-z]\) and "($1)" to replace
#   remove the "and" before and add a space within "and International Institute of Tropical Forestry(IITF), USDA Forest Service"
#   find and replace "& Melack, J. (" to "& Melack, J. M. ("

assign('known_publishers',
       value = known_publishers,
       envir = .GlobalEnv)

#might need to update these before generating new dataset
institutional_authors <- c(
    'Bonanza Creek LTER',
    'Cary Institute of Ecosystem Studies',
    'U.S. Forest Service',
    'Niwot Ridge LTER',
    'Plum Island Ecosystems LTER',
    'Santa Barbara Coastal LTER',
    'U.S. Geological Survey',
    'Hubbard Brook Watershed Ecosystem Record (HBWatER)',
    'NEON (National Ecological Observatory Network)',
    'NADP Program Office',
    'Water Quality Portal',
    'Santee Experimental Forest, Southern Research Station, USDA Forest Service',
    'International Institute of Tropical Forestry (IITF), USDA Forest Service',
    'USDA Forest Service, Northern Research Station',
    'USDA Forest Service, Southern Region',
    'Mapzen',
    'PRISM Climate Group',
    'Soil Survey Staff',
    'Svartberget Research Station'
)

two_letter_seq <- paste0(rep(letters, each = 26), letters)

names(institutional_authors) <- paste0('Placeholder',
                                       two_letter_seq[1:length(institutional_authors)],
                                       ' X. X.')

assign('institutional_authors',
       value = institutional_authors,
       envir = .GlobalEnv)

#exports from an attempt to use socket cluster parallelization;
# idw_pkg_export <- c('logging', 'errors', 'jsonlite', 'plyr',
#                     'tidyverse', 'lubridate', 'feather', 'glue',
#                     'emayili', 'tinsel', 'imputeTS')
# idw_var_export <- c('logger_module', 'err_cnt')

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

numeric_any <- function(num_vec){
    return(as.numeric(any(as.logical(num_vec))))
}

numeric_any_v <- function(...){ #attack of the ellipses

    #...: numeric vectors of equal length. should be just 0s and 1s, but
    #   integers other than 1 are also considered TRUE by as.logical()

    #the vectorized version of numeric_any. good for stuff like:
    #    mutate(ms_status = numeric_any(c(ms_status_x, ms_status_flow)))

    #returns a single vector of the same length as arguments

    #this func could be useful in global situations
    numeric_any_positional <- function(...) numeric_any(c(...))

    numeric_any_elementwise <- function(...){
        Map(function(...) numeric_any_positional(...), ...)
    }

    out <- do.call(numeric_any_elementwise,
                   args = list(...)) %>%
        unlist()

    if(is.null(out)) out <- numeric()

    return(out)
}

sd_or_0 <- function(x, na.rm = FALSE){

    #Only used to bypass the tyranny of the errors package not letting
    #me take the mean of an errors object of length 1 without setting the
    #uncertainty to 0

    x <- if(is.vector(x) || is.factor(x)) x else as.double(x)

    if(length(x) == 1) return(0)

    x <- sqrt(var(x, na.rm = na.rm))
}

gsub_v <- function(pattern, replacement_vec, x){

    #just like the first three arguments to gsub, except that
    #   replacement is now a vector of replacements.
    #return a vector of the same length as replacement_vec, where
    #   each element in replacement_vec has been used once

    subbed <- sapply(replacement_vec,
                     function(v) gsub(pattern = pattern,
                                      replacement = v,
                                      x = x),
                     USE.NAMES = FALSE)

    return(subbed)
}

identify_sampling <- function(df,
                              is_sensor,
                              date_col = 'datetime',
                              network,
                              domain,
                              prodname_ms,
                              sampling_type){

    #TODO: for hbef, identify_sampling is writing sites names as 1 not w1

    #is_sensor: named logical vector. see documention for
    #   ms_read_raw_csv, but note that an unnamed logical vector of length one
    #   cannot be used here. also note that the original variable/flag column names
    #   from the raw file are converted to canonical macrosheds names by
    #   ms_read_raw_csv before it passes is_sensor to identify_sampling.

    #checks
    if(any(! is.logical(is_sensor))){
        stop('all values in is_sensor must be logical.')
    }

    svh_names <- names(is_sensor)
    if(is.null(svh_names) || any(is.na(svh_names))){
        stop('all elements of is_sensor must be named.')
    }

    #parse is_sensor into a character vector of sample regimen codes
    is_sensor <- ifelse(is_sensor, 'S', 'N')

    #set up directory system to store sample regimen metadata
    sampling_dir <- glue('data/{n}/{d}',
                         n = network,
                         d = domain)

    sampling_file <- glue('data/{n}/{d}/sampling_type.json',
                          n = network,
                          d = domain)

    master <- try(jsonlite::fromJSON(readr::read_file(sampling_file)),
                  silent = TRUE)

    if('try-error' %in% class(master)){
        dir.create(sampling_dir, recursive = TRUE, showWarnings = FALSE)
        file.create(sampling_file)
        master <- list()
    }

    #determine and record sample regimen for each variable
    col_names <- colnames(df)

    data_cols <- grep(pattern = '__[|]dat',
                      col_names,
                      value = TRUE)

    flg_cols <- grep(pattern = '__[|]flg',
                     col_names,
                     value = TRUE)

    site_codes <- unique(df$site_code)

    for(p in 1:length(data_cols)){

        # var_name <- str_split_fixed(data_cols[p], '__', 2)[1]

        # df_var <- df %>%
        #     select(datetime, !!var_name := .data[[data_cols[p]]], site_code)

        all_sites <- tibble()

        for(i in seq_along(site_codes)){

            # df_site <- df_var %>%
            df_site <- df %>%
                filter(site_code == !!site_codes[i]) %>%
                arrange(datetime)
                    # ! is.na(.data[[date_col]]), #NAs here are indicative of bugs we want to fix, so let's let them through
                    # ! is.na(.data[[var_name]])) #NAs here are indicative of bugs we want to fix, so let's let them through

            dates <- df_site[[date_col]]
            dif <- diff(dates)
            unit <- attr(dif, 'units')

            conver_mins <- case_when(
                unit %in% c('seconds', 'secs') ~ 0.01666667,
                unit %in% c('minutes', 'mins') ~ 1,
                unit == 'hours' ~ 60,
                unit == 'days' ~ 1440,
                TRUE ~ NA_real_)

            if(is.na(conver_mins)) stop('Weird time unit encountered. address this.')

            dif_mins <- as.numeric(dif) * conver_mins
            dif_mins <- round(dif_mins)

            mode_mins <- Mode(dif_mins)
            mean_mins <- mean(dif_mins, na.rm = T)
            prop_mode_min <- length(dif_mins[dif_mins == mode_mins])/length(dif_mins)

            # remove gaps larger than 90 days (for seasonal sampling)
            dif_mins <- dif_mins[dif_mins < 129600]

            if(length(dif_mins) == 0){
                # This is grab
                g_a <- tibble('site_code' = site_codes[i],
                              'type' = 'G',
                              'starts' = min(dates, na.rm = TRUE),
                              'interval' = mode_mins)
            } else{
                if(prop_mode_min >= 0.5 && mode_mins <= 1440){
                        # This is installed
                    g_a <- tibble('site_code' = site_codes[i],
                                  'type' = 'I',
                                  'starts' = min(dates, na.rm = TRUE),
                                  'interval' = mode_mins)
                    } else{
                        if(mean_mins <= 1440){
                            # This is installed (non standard interval like HBEF)
                            g_a <- tibble('site_code' = site_codes[i],
                                          'type' = 'I',
                                          'starts' = min(dates, na.rm = TRUE),
                                          'interval' = mean_mins)
                        } else{
                            # This is grab
                            g_a <- tibble('site_code' = site_codes[i],
                                          'type' = 'G',
                                          'starts' = min(dates, na.rm = TRUE),
                                          'interval' = mean_mins)
                        }
                    }
                }

            if(! is.null(sampling_type)){
                g_a <- g_a %>%
                    mutate(type = sampling_type)
            }

            var_name_base <- str_split(string = data_cols[p],
                                       pattern = '__\\|')[[1]][1]

            g_a <- g_a %>%
                mutate(
                    type = paste0(type,
                                  !!is_sensor[var_name_base]),
                    var = as.character(glue('{ty}_{vb}',
                                            ty = type,
                                            vb = var_name_base)))

            master[[prodname_ms]][[var_name_base]][[site_codes[i]]] <-
                list('startdt' = g_a$starts,
                     'type' = g_a$type,
                     'interval' = g_a$interval)

            g_a <- g_a %>%
                mutate(interval = as.character(interval))

            all_sites <- bind_rows(all_sites, g_a)
        }

        #include new prefixes in df column names
        prefixed_varname <- all_sites$var[1]

        dat_colname <- paste0(drop_var_prefix(prefixed_varname),
                              '__|dat')
        flg_colname <- paste0(drop_var_prefix(prefixed_varname),
                              '__|flg')

        data_col_ind <- match(dat_colname,
                              colnames(df))
        flag_col_ind <- match(flg_colname,
                              colnames(df))

        colnames(df)[data_col_ind] <- paste0(prefixed_varname,
                                             '__|dat')
        colnames(df)[flag_col_ind] <- paste0(prefixed_varname,
                                             '__|flg')
    }

    readr::write_file(jsonlite::toJSON(master), sampling_file)

    return(df)
}

identify_sampling_bypass <- function(df,
                              is_sensor,
                              date_col = 'datetime',
                              network,
                              domain,
                              prodname_ms,
                              sampling_type = NULL){

    #This case is used (primarily for neon) when use of ms_read_raw_csv and
    # ms_cast_and_reflag are prohibited because of incompatible data structures

    #checks
    if(!is.logical(is_sensor)){
        stop('is_sensor must be logical.')
    }

    #parse is_sensor into a character vector of sample regimen codes
    is_sensor <- ifelse(is_sensor, 'S', 'N')

    #set up directory system to store sample regimen metadata
    if(is.na(domain)) stop('domain not defined')
    sampling_dir <- glue('data/{n}/{d}',
                         n = network,
                         d = domain)

    sampling_file <- glue('data/{n}/{d}/sampling_type.json',
                          n = network,
                          d = domain)

    if(file.exists(sampling_file)){
        master <- jsonlite::fromJSON(readr::read_file(sampling_file))
    } else {
        dir.create(sampling_dir, recursive = TRUE)
        file.create(sampling_file)
        master <- list()
    }

    site_codes <- unique(df$site_code)

    variables <- unique(df$var)

    all_vars <- tibble()
    for(p in 1:length(variables)){
    #for(p in 1:43){

        all_sites <- tibble()
        for(i in 1:length(site_codes)){

            # df_site <- df_var %>%
            df_site <- df %>%
                filter(site_code == !!site_codes[i]) %>%
                filter(var == !!variables[p]) %>%
                arrange(datetime)
            # ! is.na(.data[[date_col]]), #NAs here are indicative of bugs we want to fix, so let's let them through
            # ! is.na(.data[[var_name]])) #NAs here are indicative of bugs we want to fix, so let's let them through

            dates <- df_site[[date_col]]
            dif <- diff(dates)
            unit <- attr(dif, 'units')

            conver <- case_when(
                unit %in% c('seconds', 'secs') ~ 0.01666667,
                unit %in% c('minutes', 'mins') ~ 1,
                unit == 'hours' ~ 60,
                unit == 'days' ~ 1440,
                TRUE ~ NA_real_)

            if(is.na(conver)) stop('Weird time unit encountered. address this.')

            dif_minutes <- as.numeric(dif) * conver

            # table <- rle2(dif_minutes) %>% #table is a commonly used function
            run_table <- rle2(dif_minutes) %>%
                mutate(
                    site_code = !!site_codes[i],
                    starts := dates[starts],
                    stops := dates[stops],
                    # sum = sum(lengths, na.rm = TRUE), #superfluous
                    porportion = lengths / sum(lengths, na.rm = TRUE),
                    time = difftime(stops, starts, units = 'days'))

            # Sites with no record
            if(nrow(run_table) == 0){

                g_a <- tibble('site_code' = site_codes[i],
                              'type' = 'G',
                              'starts' = lubridate::NA_POSIXct_,
                              'interval' = NA_real_)

            } else {

                test <- filter(run_table,
                               time > 60,
                               lengths > 60)

                #Sites where there are not at least 60 consecutive records, record
                #for at least 60 consecutive days, and have an average interval of
                #more than 1 day are assumed to be grab samples
                if(nrow(test) == 0 && mean(run_table$values, na.rm = TRUE) > 1440){

                    g_a <- tibble('site_code' = site_codes[i],
                                  'type' = 'G',
                                  'starts' = min(run_table$starts,
                                                 na.rm = TRUE),
                                  'interval' = round(Mode(run_table$values,
                                                          na.rm = TRUE)))
                }

                #Sites with consecutive samples are have a consistent interval
                if(nrow(test) != 0 && nrow(run_table) <= 20){

                    g_a <- test %>%
                        select(site_code, starts, interval = values) %>%
                        group_by(site_code, interval) %>%
                        summarise(starts = min(starts,
                                               na.rm = TRUE)) %>%
                        mutate(type = 'I') %>%
                        arrange(starts)

                }

                #Sites where they do not have a consistent recording interval but
                #the average interval is less than one day are assumed to be automatic
                # (such as HBEF discharge that is automatic but lacks a consistent
                #recording interval)
                if(
                    (nrow(test) == 0 && mean(run_table$values, na.rm = TRUE) <= 1440) ||
                    (nrow(test) != 0 && nrow(run_table) > 20)
                ){ #could this be handed with else?

                    table_ <- run_table %>%
                        filter(porportion >= 0.05) %>%
                        mutate(type = 'I') %>%
                        select(starts, site_code, type, interval = values) %>%
                        mutate(interval = as.character(round(interval)))

                    table_var <- run_table %>%
                        filter(porportion <= 0.05)  %>%
                        group_by(site_code) %>%
                        summarise(starts = min(starts,
                                               na.rm = TRUE)) %>%
                        mutate(
                            type = 'I',
                            interval = 'variable') %>%
                        select(starts, site_code, type, interval)

                    g_a <- rbind(table_, table_var) %>%
                        arrange(starts)
                }
            }

            interval_changes <- rle2(g_a$interval)$starts

            if(! is.null(sampling_type)){

                g_a <- g_a %>%
                    mutate(type = sampling_type)
            }

            g_a <- g_a %>%
                mutate(
                    type = paste0(type,
                                  !!is_sensor),
                    new_var = as.character(glue('{ty}_{vb}',
                               ty = type,
                               vb = variables[p])),
                    var = variables[p]) %>%
                slice(interval_changes)

            master[[prodname_ms]][[variables[p]]][[site_codes[i]]] <-
                list('startdt' = g_a$starts,
                     'type' = g_a$type,
                     'interval' = g_a$interval)

            all_sites <- rbind(all_sites, g_a)
        }
        all_vars <- rbind(all_sites, all_vars)# %>%
            #distinct(var, .keep_all = TRUE)
    }

    correct_names <- all_vars %>%
        select(site_code, new_var, var) %>%
        group_by(site_code, var) %>%
        summarise(new_var = first(new_var)) %>%
        ungroup()

    df <- left_join(df, correct_names, by = c("site_code", "var")) %>%
        select(datetime, site_code, var=new_var, val, ms_status)

    readr::write_file(jsonlite::toJSON(master), sampling_file)

    return(df)
}

drop_var_prefix <- function(x){

    unprefixed <- ifelse(grepl('^(?!Ge_)[IGa-z][SNa-z]_.+', x, perl = TRUE),
                         substr(x, 4, nchar(x)),
                         x)

    return(unprefixed)
}

extract_var_prefix <- function(x){

    prefix <- ifelse(grepl('^(?!Ge_)[IGa-z][SNa-z]_.+', x, perl = TRUE),
                     substr(x, 1, 2),
                     x)

    return(prefix)
}

ms_read_raw_csv <- function(filepath,
                            preprocessed_tibble,
                            datetime_cols,
                            datetime_tz,
                            optionalize_nontoken_characters = ':',
                            site_code_col,
                            alt_site_code,
                            data_cols,
                            data_col_pattern,
                            alt_datacol_pattern,
                            is_sensor,
                            set_to_NA,
                            convert_to_BDL_flag,
                            numeric_dl_col_pattern,
                            set_to_0,
                            var_flagcol_pattern,
                            alt_varflagcol_pattern,
                            summary_flagcols,
                            sampling_type = NULL,
                            keep_bdl_values = FALSE,
                            keep_empty_rows = FALSE,
                            ignore_missing_col_warning = FALSE){

    #TODO:
    #add a silent = TRUE option. this would hide all warnings
    #allow a vector of possible matches for each element of datetime_cols
    #   (i.e. make it take a list of named vectors)
    #write more checks for improper specification.
    #if file to be read is stored in long format, this function will not work!
    #this could easily be adapted to read other delimited filetypes.
    #could also add a drop_empty_rows and/or drop_empty_datacols parameter.
    #   atm those things happen automatically
    #likewise, a remove_duplicates param could be nice. atm, for duplicated rows,
    #   the one with the fewest NA values is kept automatically
    #allow a third option in is_sensor for mixed sensor/nonsensor
    #   (also change param name). check for comments inside munge kernels
    #   indicating where this is needed
    #site_code_col should eventually work like datetime_cols (in case site_code is
    #   separated into multiple components)
    #can't deal with missing sitecode column as is
    #implement pivot_wider_names_from and pivot_wider_values_from. they should
    #   produce a cascade of default values supplied to data_cols, (data_cols_pattern),
    #   flagcol patterns. numeric_dl_column and other params will also be updated

    #filepath: string
    #preprocessed_tibble: a tibble with all character columns. Supply this
    #   argument if a dataset requires modification before it can be processed
    #   by ms_read_raw_csv. This may be necessary if, e.g.
    #   time is stored in a format that can't be parsed by standard datetime
    #   format strings. Either filepath or preprocessed_tibble
    #   must be supplied, but not both.
    #datetime_cols: a named character vector. names are column names that
    #   contain components of a datetime. values are format strings (e.g.
    #   '%Y-%m-%d', '%H') corresponding to the datetime components in those
    #   columns.
    #datetime_tz: string specifying time zone. this specification must be
    #   among those provided by OlsonNames()
    #optionalize_nontoken_characters: character vector; used when there might be
    #   variation in date/time formatting within a column. in regex speak,
    #   optionalizing a token string means, "match this string if it exists,
    #   but move on to the next token if it doesn't." All datetime parsing tokens
    #   (like "%H") are optionalized automatically when this function converts
    #   them to regex. But other tokens like ":" and "-" that might be used in
    #   datetime strings are not. Concretely, if you wanted to read either "%H:%M:%S"
    #   or "%H:%M" in the same column, you'd set optionalize_nontoken_characters = ':',
    #   and then the parser wouldn't require there to be two colons in order to
    #   match the string. Don't use this if you don't have to, because it reduces
    #   specificity. See "optional" argument to dt_format_to_regex for more details.
    #site_code_col: name of column containing site name information
    #alt_site_code: optional list. Names of list elements are desired site_codes
    #   within MacroSheds. List elements are character vectors of alternative
    #   names that might be encountered. Used when sites are misnamed or need
    #   to be changed due to inconsistencies within and across datasets.
    #data_cols: vector of names of columns containing data. If elements of this
    #   vector are named, names are taken to be the column names as they exist
    #   in the file, and values are used to replace those names. Data columns that
    #   aren't referred to in this argument will be omitted from the output,
    #   as will their associated flag columns (if any).
    #data_col_pattern: a string containing the wildcard "#V#",
    #   which represents any number of characters. If data column names will be
    #   used as-is, this wildcard is all you need. if data columns contain
    #   recurring, superfluous characters, you can omit them with regex. for
    #   example, if data columns are named outflow_x, outflow_y, outflow_...., use
    #   data_col_pattern = 'outflow_#V#' and then you don't have to bother
    #   typing the full names in your argument to data_cols.
    #alt_datacol_pattern: optional string with same mechanics as
    #   data_col_pattern. use this if there
    #   might be a second way in which column names are generated, e.g.
    #   outflow_x, outflow_y, outflow_... AND
    #   output_x, output_y, output_....
    #is_sensor: either a single logical value, which will be applied to all
    #   variable columns OR a named logical vector with the same length and names as
    #   data_cols. If the latter, names correspond to variable names in the file to be read.
    #   TRUE means the corresponding variable(s) was/were
    #   measured with a sensor (which may be susceptible to drift and/or fouling),
    #   FALSE means the measurement(s) was/were not recorded by a sensor. This
    #   category includes analytical measurement in a lab, visual recording, etc.
    #set_to_NA: character. For values such as '9999' that are proxies for NA values.
    #convert_to_BDL_flag: character vector of QC flags that should be interpreted
    #   as "below detection limit". For numeric codes, e.g. -888, give their
    #   character representations, i.e. "-888". Accepts '#*#' as a wildcard that
    #   can stand in for any numeral or a decimal point. Wildcard is useful for forms like
    #   "<0.03", "<0.05", etc. Instead of listing these, you can just pass "<#*#".
    #   This parameter is only for below-detection-limit flags within data columns.
    #   Codes will be standardized to "BDL" and extracted into the variable-flag column
    #   corresponding to each data variable. Variable-flag columns will be created
    #   as necessary. See also numeric_dl_col_pattern.
    #   See ms_cast_and_reflag for the next step in handling BDL data.
    #numeric_dl_col_pattern: as opposed to convert_to_BDL_flag, which can handle e.g.
    #   "<0.04" within a data column, this parameter is for when there's a whole
    #   separate column of numeric detection limit values for each variable (probably
    #   this will only be true if you had to use pivot_wider on a long-format table). DL
    #   values will be converted to "BDL" flags, which will be merged
    #   with any other flag information. Note that convert_to_BDL_flag is not
    #   necessary when numeric_dl_col_pattern is used. If you find a situation
    #   where both are needed, we probably have work to do.
    #set_to_0: character. For values that we want to set to zero. We're setting BDLs to
    #   1/2 detlim instead, so this param is probably obsolete
    #var_flagcol_pattern: optional string with same mechanics as the other
    #   pattern parameters. this one is for columns containing flag
    #   information that is specific to one variable. If there's only one
    #   data column, omit this argument and use summary_flagcols for all
    #   flag information. If that one data column contains BDL flags (see
    #   convert_to_BDL_flag), some amending of this function might be needed.
    #alt_varflagcol_pattern: optional string with same mechanics as the other
    #   pattern parameters. just in case there are two naming conventions for
    #   variable-specific flag columns
    #summary_flagcols: optional unnamed vector of column names for flag columns
    #   that pertain to all variables
    #sampling_type: optional value to overwrite identify_sampling because in
    #   some case this function is misidentifying sampling type. This must be a
    #   single value of 'G' or 'I' and is applied to all variables in product
    #keep_bdl_values: logical. if TRUE, data column values indicating the
    #   detection limit, e.g. "<0.7" will be replaced with that limit, i.e. "0.7".
    #   Only use this if you are following up with update_detlims().
    #   If the values recorded in the cells represent half detection limit, or something
    #   else, we need to write new handling.
    #keep_empty_rows: logical. if FALSE, rows without data values will be dropped.
    #ignore_missing_col_warning: logical. if TRUE, do not warn about absence of
    #   expected column names (probably set to TRUE if using alt_datacol_pattern)

    #return value: a tibble of ordered and renamed columns, omitting any columns
    #   from the original file that do not contain data, flaime, or site_code. All-NA data columns and their corresponding
    #   flag columns will also be omitted, as will rows where all data values
    #   are NA. Rows with NA in the datetime or site_code column are dropped.
    #   data columns are given type double. all other
    #   columns are given type character. data and flag/qaqc columns are
    #   given two-letter prefixes representing sample regimen
    #   (I = installed vs. G = grab; S = sensor vs N = non-sensor).
    #   Data and flag/qaqc columns are also given
    #   suffixes (__|flg and __|dat) that allow them to be cast into long format
    #   by ms_cast_and_reflag.

    #checks

    filepath_supplied <-  ! missing(filepath) && ! is.null(filepath)
    tibble_supplied <-  ! missing(preprocessed_tibble) && ! is.null(preprocessed_tibble)

     if(filepath_supplied && tibble_supplied){
        stop(glue('Only one of filepath and preprocessed_tibble can be supplied. ',
                  'preprocessed_tibble is for rare circumstances only.'))
    }

    if(! datetime_tz %in% OlsonNames()){
        stop('datetime_tz must be included in OlsonNames()')
    }

    if(is.list(datetime_cols)){
        stop('datetime_cols must be a named character vector')
    }

    if(length(data_cols) == 1 &&
       ! (missing(var_flagcol_pattern) || is.null(var_flagcol_pattern))){
        stop(paste0('Only one data column. Use summary_flagcols instead ',
                    'of var_flagcol_pattern.'))
    }

    if(any(! is.logical(is_sensor))){
        stop('all values in is_sensor must be logical.')
    }

    svh_names <- names(is_sensor)
    if(
        length(is_sensor) != 1 &&
        (is.null(svh_names) || any(is.na(svh_names)))
    ){
        stop('if is_sensor is not length 1, all elements must be named.')
    }

    if(! all(data_cols %in% ms_vars$variable_code)) {

        for(i in 1:length(data_cols)) {
            if(!data_cols[i] %in% ms_vars$variable_code) {
                logerror(msg = paste(unname(data_cols[i]), 'is not in varibles gsheet; add'),
                        logger = logger_module)
            }
        }
    }

    if(! is.null(sampling_type)){
        if(! length(sampling_type) == 1){
            stop('sampling_type must be a length of 1')
        }
        if(! sampling_type %in% c('G', 'I')){
            stop('sampling_type must be either I or G')
        }
    }

    if(missing(var_flagcol_pattern) && ! missing(alt_varflagcol_pattern)){
        stop('alt_varflagcol_pattern supplied but var_flagcol_pattern missing. Use var_flagcol_pattern.')
    }

    #@spencer: ifelse(dn_dupes == ''... would have evaluated only the first element. this should take care of it
    datacol_names <- names(data_cols)
    if(! is.null(datacol_names)){

        dn_dupes <- duplicated(datacol_names) & datacol_names != ''

        if(any(dn_dupes)){
            stop(paste('duplicate name(s) in data_cols:',
                       paste(datacol_names[dn_dupes],
                             collapse = ', ')))
        }
    }

    #parse args; deal with missing args
    datetime_colnames <- names(datetime_cols)
    datetime_formats <- unname(datetime_cols)

    alt_datacols <- var_flagcols <- alt_varflagcols <- dl_cols <- NA
    alt_datacol_names <- var_flagcol_names <- alt_varflagcol_names <- NA
    if(missing(summary_flagcols)){
        summary_flagcols <- NULL
    }

    if(missing(set_to_NA)) {
        set_to_NA <- NULL
    }

    if(missing(convert_to_BDL_flag)) {
        convert_to_BDL_flag <- NULL
    }

    if(missing(numeric_dl_col_pattern)) {
        numeric_dl_col_pattern <- NULL
    }

    if(missing(set_to_0)) {
        set_to_0 <- NULL
    }

    if(missing(alt_site_code)) {
        alt_site_code <- NULL
    }

    #fill in missing names in data_cols (for columns that are already
    #   canonically named)
    datacol_names0 <- names(data_cols)
    if(is.null(datacol_names0)) datacol_names0 <- rep('', length(data_cols))
    datacol_names0[datacol_names0 == ''] <-
        unname(data_cols[datacol_names0 == ''])

    #expand data columnname wildcards and rename data_cols
    datacol_names <- gsub_v(pattern = '#V#',
                            replacement_vec = datacol_names0,
                            x = data_col_pattern)
    names(data_cols) <- datacol_names

    #expand alternative data columnname wildcards and populate alt_datacols
    if(! missing(alt_datacol_pattern) && ! is.null(alt_datacol_pattern)){
        alt_datacols <- data_cols
        alt_datacol_names <- gsub_v(pattern = '#V#',
                                    replacement_vec = datacol_names0,
                                    x = alt_datacol_pattern)
        names(alt_datacols) <- alt_datacol_names
    }

    #expand varflag columnname wildcards and populate var_flagcols
    if(! missing(var_flagcol_pattern) && ! is.null(var_flagcol_pattern)){
        var_flagcols <- data_cols
        var_flagcol_names <- gsub_v(pattern = '#V#',
                                    replacement_vec = datacol_names0,
                                    x = var_flagcol_pattern)
        names(var_flagcols) <- var_flagcol_names
    }

    #expand alt varflag columnname wildcards and populate alt_varflagcols
    if(! missing(alt_varflagcol_pattern) && ! is.null(alt_varflagcol_pattern)){
        alt_varflagcols <- data_cols
        alt_varflagcol_names <- gsub_v(pattern = '#V#',
                                       replacement_vec = datacol_names0,
                                       x = alt_varflagcol_pattern)
        names(alt_varflagcols) <- alt_varflagcol_names
    }

    #expand DL columnname wildcards and populate dl_cols
    if(! missing(numeric_dl_col_pattern) && ! is.null(numeric_dl_col_pattern)){
        dl_cols <- data_cols
        numeric_dl_col_names <- gsub_v(pattern = '#V#',
                                       replacement_vec = datacol_names0,
                                       x = numeric_dl_col_pattern)
        names(dl_cols) <- numeric_dl_col_names
    }

    #combine all available column name mappings; assemble new name vector
    colnames_all <- c(data_cols, alt_datacols, var_flagcols, alt_varflagcols)#, dl_cols)
    na_inds <- is.na(colnames_all)
    colnames_all <- colnames_all[! na_inds]

    suffixes <- rep(c('__|dat', '__|dat', '__|flg', '__|flg'),#, '__|dl'),
                    times = c(length(data_cols),
                              length(alt_datacols),
                              length(var_flagcols),
                              length(alt_varflagcols)))
                              # length(dl_cols)))

    suffixes <- suffixes[! na_inds]
    colnames_new <- paste0(colnames_all, suffixes)

    colnames_all <- c(datetime_colnames, colnames_all)
    names(colnames_all)[1:length(datetime_cols)] <- datetime_colnames
    colnames_new <- c(datetime_colnames, colnames_new)

    if(! missing(site_code_col) && ! is.null(site_code_col)){
        colnames_all <- c('site_code', colnames_all)
        names(colnames_all)[1] <- site_code_col
        colnames_new <- c('site_code', colnames_new)
    }

    if(! is.null(summary_flagcols)){
        nsumcol <- length(summary_flagcols)
        summary_flagcols_named <- summary_flagcols
        names(summary_flagcols_named) <- summary_flagcols
        colnames_all <- c(colnames_all, summary_flagcols_named)
        colnames_new <- c(colnames_new, summary_flagcols)
    }

    #assemble colClasses argument to read.csv
    classes_d1 <- rep('numeric', length(data_cols))
    names(classes_d1) <- datacol_names

    classes_d2 <- rep('numeric', length(alt_datacols))
    names(classes_d2) <- alt_datacol_names

    classes_f1 <- rep('character', length(var_flagcols))
    names(classes_f1) <- var_flagcol_names

    classes_f2 <- rep('character', length(alt_varflagcols))
    names(classes_f2) <- alt_varflagcol_names

    classes_f3 <- rep('character', length(summary_flagcols))
    names(classes_f3) <- summary_flagcols

    class_dt <- rep('character', length(datetime_cols))
    names(class_dt) <- datetime_colnames

    if(! missing(site_code_col) && ! is.null(site_code_col)){
        class_sn <- 'character'
        names(class_sn) <- site_code_col
    }

    classes_all <- c(class_dt, class_sn, classes_d1, classes_d2, classes_f1,
                     classes_f2, classes_f3)
    classes_all <- classes_all[! is.na(names(classes_all))]

    if(filepath_supplied){
        d <- read.csv(filepath,
                      stringsAsFactors = FALSE,
                      colClasses = "character")
    } else {
        d <- mutate(preprocessed_tibble,
               across(where(~is.POSIXct(.)),
                      ~format(., '%Y-%m-%d %H:%M:%S')),
               across(where(~! is.POSIXct(.)),
                      as.character))
    }

    missing_colnames <- setdiff(names(colnames_all), colnames(d))
    if(length(missing_colnames) && ! ignore_missing_col_warning){
        logwarn(paste0('These columns missing from source data. Can signify an upstream change:\n',
                       paste(missing_colnames, collapse = ', ')),
                logger = logger_module)
    }

    d <- sw(select(d, any_of(c(names(colnames_all),
                               names(dl_cols),
                               'NA.')))) %>% #for NA meaning "sodium"
        as_tibble()

    if('NA.' %in% colnames(d)) class(d$NA.) = 'character'


    # NOTE: if we want to be able to match multiple input cols to a single
    # macrosheds var, we need to accept dupes in the data_cols values.
    # merge any input columns with same end-variable, where the vlaues from whichever
    # input column is provided first will be used when any overlapping observations
    dc_dupes <- duplicated(unname(data_cols))
    if(any(dc_dupes)){
      warning(paste('duplicate value(s) in data_cols:',
                   paste(unname(data_cols)[dc_dupes],
                         collapse = ', ')))
      ## warning('combinging duplicates, giving first entry column priority')
      d <- combine_multiple_input_cols(d, data_cols = data_cols, var_flagcols = var_flagcols)

      # prune base column tracking objects
      var_flagcols <- var_flagcols[names(var_flagcols) %in% colnames(d)]
      data_cols <- data_cols[names(data_cols) %in% colnames(d)]
    }

    # Remove any variable flags created by pattern but do not exist in data
    # colnames_all <- colnames_all[names(colnames_all) %in% names(d)]
    # classes_all <- classes_all[names(classes_all) %in% names(d)]

    # Set values to NA if used as a flag or missing data indication
    # Not sure why %in% does not work, seem to only operate on one row
    if(! is.null(set_to_NA)){
        for(i in 1:length(set_to_NA)){
            d[d == set_to_NA[i]] <- NA
        }
    }

    # Set values to 0 if used as a flag for below detection limit
    if(! is.null(set_to_0)){
        for(i in 1:length(set_to_0)){
            d[d == set_to_0[i]] <- '0'
        }
    }

    #extract numeric DL column information into data columns
    if(! is.null(numeric_dl_col_pattern)){
      for(i in seq_along(numeric_dl_col_names)){
        dl_col <- d[[numeric_dl_col_names[i]]]
        if(any(!is.na(dl_col))) {
          d[! is.na(dl_col), datacol_names[i]] <- paste0('<', dl_col[! is.na(dl_col)])
        }
      }

      convert_to_BDL_flag <- c(convert_to_BDL_flag, '<#*#')
      d <- select(d, -all_of(numeric_dl_col_names))
    }
    #move BDL flags from data columns into flag columns. Replace with NA,
    #which will be converted to 1/2 detlim downstream

    bdl_cols_do_not_drop <- c()
    new_varflag_cols <- c()
    all_datacols <- c(data_cols, alt_datacols)
    all_datacols <- all_datacols[!is.na(all_datacols)]

    for(i in seq_along(convert_to_BDL_flag)){

        bdl_flag <- convert_to_BDL_flag[i]
        if(grepl('#*#', bdl_flag)){
            bdl_flag <- sub('#*#', '[0-9\\.]+', bdl_flag, fixed = TRUE)
            has_wildcard <- TRUE
        } else {
            has_wildcard <- FALSE
        }

        for(j in seq_along(all_datacols)){

            d_varcode <- unname(all_datacols)[j][[1]]
            d_colname <- names(all_datacols)[j]
            d_clm <- d[[d_colname]]

            if(is.null(d_clm)) next #column doesn't exist

            if(has_wildcard){
                bdl_inds <- ! is.na(d_clm) & grepl(bdl_flag, d_clm)
            } else {
                bdl_inds <- ! is.na(d_clm) & d_clm == bdl_flag
            }

            if(! any(bdl_inds)) next #this bdl code doesn't exist in this column

            if(!(length(var_flagcols) == 1 && is.na(var_flagcols))){
                candidate_flagcol <- names(var_flagcols)[var_flagcols == d_varcode][1]
                var_flagcol_already_exists <- ! is.null(candidate_flagcol) && candidate_flagcol %in% colnames(d)
            } else {
                candidate_flagcol <- paste0(d_varcode, '__|flg')
                var_flagcol_already_exists <- FALSE
            }

            if(candidate_flagcol %in% new_varflag_cols){
                var_flagcol_already_exists <- TRUE
            }

            if(! var_flagcol_already_exists){
                d[[candidate_flagcol]] <- NA_character_
                new_varflag_cols <- c(new_varflag_cols, candidate_flagcol)
            }

            # populate flag column with BDL information,
            # and set value to NA
            d[bdl_inds, candidate_flagcol] <- 'BDL'
            if(keep_bdl_values) {
                d[bdl_inds, d_colname] <- sapply(d[bdl_inds, d_colname], function(x) gsub("[^0-9\\.\\-]*", "", x))
            } else {
                d[bdl_inds, d_colname] <- NA_character_
            }

            # look up DL googlsheet, and see if this site has DL info
            # for this variable
            bdl_cols_do_not_drop <- c(bdl_cols_do_not_drop,
                                      paste0(d_colname, '__|dat'))

        }
    }
    bdl_cols_do_not_drop <- unique(bdl_cols_do_not_drop)
    new_varflag_cols <- unique(new_varflag_cols)

    #establish class of newly created varflag cols
    new_varflag_classes <- rep('character', times = length(new_varflag_cols))
    names(new_varflag_classes) <- new_varflag_cols
    classes_all <- c(classes_all, new_varflag_classes)

    #Set correct class for each column
    colnames_d <- colnames(d)

    illegal_chars <- c()
    for(i in 1:ncol(d)){

        if(colnames_d[i] == 'NA.'){
            sw(class(d[[i]]) <- 'numeric')
            next
        }

        newclass <- unname(classes_all[names(classes_all) == colnames_d[i]])

        #notify about illegal characters in data columns
        if(newclass == 'numeric'){

            illegal_char_inds <- sw(! is.na(d[[i]]) & is.na(as.numeric(d[[i]])))
            if(any(illegal_char_inds)){

                new_illegal_chars <- unique(pull(d[illegal_char_inds, i]))
                illegal_chars <- c(illegal_chars, new_illegal_chars)

                message(paste0('[See next log warning.] Illegal chars in column ', colnames_d[i], ': "',
                               paste(new_illegal_chars, collapse = '", "'),
                               '"'))
            }
        }

        sw(class(d[[i]]) <- newclass)
    }

    illegal_chars <- unique(illegal_chars)
    cmpnt <- if(exists('component') && ! is.null(component)) component else '[no component]'

    if(! is.null(illegal_chars)){
        logwarn(msg = glue('Coercing illegal data records to NA in {n}, {d}, {s}, {p}, {cc}: {ill}',
                           n = network,
                           d = domain,
                           s = ifelse(exists('site_code'), site_code, '[site_code unavailable]'),
                           p = prodname_ms,
                           cc = cmpnt,
                           ill = paste0('"', paste(illegal_chars, collapse = '", "')), '"'),
                logger = logger_module)
    }

    #rename cols to canonical names
    for(i in 1:ncol(d)){

        if(colnames_d[i] == 'NA.'){
            colnames_d[i] <- 'Na__|dat'
            next
        }

        canonical_name_ind <- names(colnames_all) == colnames_d[i]
        if(any(canonical_name_ind)){
            colnames_d[i] <- colnames_new[canonical_name_ind]
        }
    }

    colnames(d) <- colnames_d

    #resolve datetime structure into POSIXct
    d  <- resolve_datetime(d = d,
                           datetime_colnames = datetime_colnames,
                           datetime_formats = datetime_formats,
                           datetime_tz = datetime_tz,
                           optional = optionalize_nontoken_characters)

    if(all(is.na(d$datetime))){
        stop('All datetime failed to parse. Check datetime formats used.')
    }

    if(any(is.na(d$datetime))){

        n_na <- sum(is.na(d$datetime))
        pct_na <- round(n_na / nrow(d) * 100, 2)
        if(pct_na == 0) pct_na <- '<1'

        logwarn(msg = glue('{nna} ({pna}%) datetime(s) failed to parse in {n}, {d}, {s}, {p}',
                           nna = n_na,
                           pna = pct_na,
                           n = network,
                           d = domain,
                           s = ifelse(exists('site_code'), site_code, '[site_code unavailable]'),
                           p = prodname_ms),
                logger = logger_module)
    }

    #remove rows with NA in datetime or site_code
    d <- sw(filter(d,
                   across(any_of(c('datetime', 'site_code')),
                          ~ ! is.na(.x))))

    #identify flag columns with BDLs (should not be dropped)
    flg_col_names <- colnames(d)[str_detect('__|flg', colnames(d))]
    flg_col_names <- c(flg_col_names, summary_flagcols)
    bdl_cols_do_not_drop2 <- apply(d[, flg_col_names], 2, function(x)
        {
            any(! is.na(x) & x == 'BDL')
        }) %>%
        names()
    bdl_cols_do_not_drop2 <- c(bdl_cols_do_not_drop2,
                               sub(pattern = '__\\|flg',
                                   replacement = '__|dat',
                                   bdl_cols_do_not_drop2)) %>% unique()

    #identify columns that are all-NA and should be dropped, unless
    #   BDLs within. if any BDLs in summary columns, don't drop columns.
    summary_bdls_present <- FALSE
    if(! is.null(summary_flagcols)){
        summary_bdls_present <- lapply(d[, summary_flagcols], function(x)
            {
                ! is.na(x) & x == 'BDL'
            }) %>%
            unlist() %>%
            any()
    }

    if(! summary_bdls_present){

        all_na_cols_bool <- apply(select(d, ends_with('__|dat')),
                                  MARGIN = 2,
                                  function(x) all(is.na(x)))
        all_na_cols <- names(all_na_cols_bool[all_na_cols_bool])
        all_na_cols <- all_na_cols[! all_na_cols %in% bdl_cols_do_not_drop]
        all_na_cols <- c(all_na_cols,
                         sub(pattern = '__\\|dat',
                             replacement = '__|flg',
                             all_na_cols))
        all_na_cols <- all_na_cols[! all_na_cols %in% bdl_cols_do_not_drop2]

    } else all_na_cols <- NULL

    #identify rows with BDL flags
    if(! is.null(flg_col_names)){
        bdl_rows_do_not_drop <- apply(d[, flg_col_names], 1, function(x){
            any(! is.na(x) & is.character(x) & x == 'BDL')
        })
    } else {
        bdl_rows_do_not_drop = rep(FALSE, nrow(d))
    }

    #remove all-NA data columns without BDLs
    d <- select(d, -any_of(all_na_cols))

    if(! any(grepl('__\\|dat', colnames(d)))){
        logwarn('all data columns have been removed (no data values present).',
                logger = logger_module)
        return(tibble())
    }

    #remove rows with NA for all data columns, except if they have BDLs.
    if(! keep_empty_rows){
        keeper_rows <- apply(d[, grepl('__\\|dat$', colnames(d))], 1, function(x) any(! is.na(x)))
        d <- d[keeper_rows | bdl_rows_do_not_drop, ]
    }

    #for duplicated datetime-site_code pairs, keep the row with the fewest NA
    #   values. We could instead do something more sophisticated.
    #20230406 CHANGE: taking mean by variable
    # d <- d %>%
    #     rowwise(one_of(c('datetime', 'site_code'))) %>%
    #     mutate(NAsum = sum(is.na(c_across(ends_with('__|dat'))))) %>%
    #     ungroup() %>%
    #     arrange(datetime, site_code, NAsum) %>%
    #     select(-NAsum) %>%
    #     distinct(datetime, site_code, .keep_all = TRUE) %>%
    #     arrange(site_code, datetime)
    d <- d %>%
        group_by(datetime, site_code) %>%
        summarize(across(ends_with('__|dat'), ~mean(., na.rm = TRUE)),
                  across(! ends_with('__|dat'), ~(na.omit(.)[1]))) %>%
        ungroup() %>%
        arrange(site_code, datetime)

    #convert NaNs to NAs, just in case.
    d[is.na(d)] <- NA

    #either assemble or reorder is_sensor to match names in data_cols
    if(length(is_sensor) == 1){

        is_sensor <- rep(is_sensor,
                         length(data_cols))
        names(is_sensor) <- unname(data_cols)

    } else {

        data_col_order <- match(names(is_sensor),
                                names(data_cols))
        is_sensor <- is_sensor[data_col_order]
    }

    #fix site names if multiple names refer to the same site
    if(! is.null(alt_site_code)){

        for(z in 1:length(alt_site_code)){

            d <- mutate(d,
                        site_code = ifelse(site_code %in% !!alt_site_code[[z]],
                                           !!names(alt_site_code)[z],
                                           site_code))
        }
    }

    #prepend two-letter code to each variable representing sample regimen and
    #record sample regimen metadata
    if(nrow(d)){

        d <- sm(identify_sampling(df = d,
                                  is_sensor = is_sensor,
                                  domain = domain,
                                  network = network,
                                  prodname_ms = prodname_ms,
                                  sampling_type = sampling_type))
    }

    #Check if all sites are in site gsheet
    unq_sites <- unique(d$site_code)
    if(! all(unq_sites %in% site_data$site_code)){

        unrecorded_sites <- sort(setdiff(unq_sites, site_data$site_code))

        logwarn(msg = paste0('These sites not recorded in gsheet:\n',
                            paste(unrecorded_sites, collapse = ', ')),
                logger = logger_module)
    }

    ## # final check that if there is only one data column and a supplied summary flag column
    ## # that the summary flag column has correct name
    ## if(length(data_cols) == 1 && !is.na(summary_flagcols)){
    ##   datcol = paste0(data_cols[[1]], "__\\|dat")
    ##   sumcol = paste0(data_cols[[1]], "__|flg")
    ##   full.datcol = names(d)[grepl(datcol, names(d))]
    ##   full.sumcol = stringr::str_replace(full.datcol, '__\\|dat', '__|flg')

    ##   names(d)[names(d) == summary_flagcols] <- full.sumcol
    ## }

    return(d)
}

resolve_datetime <- function(d,
                             datetime_colnames,
                             datetime_formats,
                             datetime_tz,
                             optional){

    #d: a data.frame or tibble with at least one date or time column
    #   (all date and/or time columns must contain character strings,
    #   not parsed date/time/datetime objects).
    #datetime_colnames: character vector; column names that contain
    #   relevant datetime information.
    #datetime_formats: character vector; datetime parsing tokens
    #   (like '%A, %Y-%m-%d %I:%M:%S %p' or '%j') corresponding to the
    #   elements of datetime_colnames.
    #datetime_tz: character; time zone of the returned datetime column.
    #optional: character vector; see dt_format_to_regex.

    #return value: d, but with a "datetime" column containing POSIXct datetimes
    #   and without the input datetime columns

    if(datetime_tz %in% c('Pacific/Auckland', 'Etc/GMT-12', 'Etc/GMT+12')){
        stop("dates (not datetimes) might get shifted to the previous day due to timezone and this function's quirks")
    }

    dt_tb <- tibble(basecol = rep(NA, nrow(d)))
    for(i in 1:length(datetime_colnames)){

        dt_comps <- str_match_all(string = datetime_formats[i],
                                  pattern = '%([a-zA-Z])')[[1]][,2]
        dt_regex <- dt_format_to_regex(datetime_formats[i],
                                       optional = optional)

        dt_tb <- d %>%
            select(one_of(datetime_colnames[i])) %>%
            tidyr::extract(col = !!datetime_colnames[i],
                           into = dt_comps,
                           regex = dt_regex,
                           remove = TRUE,
                           convert = FALSE) %>%
            bind_cols(dt_tb)
    }

    dt_tb$basecol = NULL

    if(! any(c('H', 'I') %in% colnames(dt_tb))){
        dt_tb$H <- '12'
        datetime_formats <- c(datetime_formats, '%H')
    }

    tokens_present <- colnames(dt_tb)

    #fill in defaults if applicable:
    #(12 for hour, 00 for minute and second, PM for AM/PM)
    dt_tb <- dt_tb %>%
        mutate(
            across(any_of(c('H', 'I')), ~ifelse(is.na(.x), '12', .x)),
            across(any_of(c('M', 'S')), ~ifelse(is.na(.x), '00', .x)),
            across(any_of('p'), ~ifelse(is.na(.x), 'PM', .x)))

    #resolve datetime structure into POSIXct
    datetime_formats_split <- stringr::str_extract_all(datetime_formats,
                                                       '%[a-zA-Z]') %>%
        unlist()

    dt_col_order <- match(paste0('%', tokens_present),
                          datetime_formats_split)

    #defaults part 2
    if('H' %in% tokens_present){
        dt_tb$H[dt_tb$H == ''] <- '12'
    }
    if('M' %in% tokens_present){
        dt_tb$M[dt_tb$M == ''] <- '00'
    }
    if('S' %in% tokens_present){
        dt_tb$S[dt_tb$S == ''] <- '00'
    }
    if('I' %in% tokens_present){
        stop('if "p" is specified as AM but "I" is not specified, this could cause date shifts during time zone conversion.')
        dt_tb$I[dt_tb$I == ''] <- '12'
    }
    if('p' %in% tokens_present){
        dt_tb$P[dt_tb$P == ''] <- 'PM'
    }

    #parse into datetimes
    handler <- function(xx){

        xx %>%
            tidyr::unite(col = 'datetime___', #in case the original column is named "datetime"
                         everything(),
                         sep = ' ',
                         remove = TRUE) %>%
            mutate(
                datetime___ = as_datetime(
                    datetime___,
                    format = paste(datetime_formats_split[dt_col_order],
                                   collapse = ' '),
                    tz = datetime_tz
                ),
                datetime___ = with_tz(datetime___, tz = 'UTC')
            )
    }

    dt_tb_ <- sw(handler(dt_tb))

    tryCatch({
        handler(dt_tb)
    }, warning = function(w){

        if(grepl('failed to parse', w$message)){

            print(dt_tb[is.na(dt_tb_), ])
            new_message <- paste(w$message, ' MacroSheds corollary: this often means timezone is misspecified! are the error dates above in march/april/nov?')
            message(new_message)
        }
    })

    d <- d %>%
        bind_cols(dt_tb_) %>%
        select(-one_of(datetime_colnames), datetime = datetime___) %>%
        relocate(datetime)

    return(d)
}

dt_format_to_regex <- function(fmt, optional){

    #fmt is a character vector of datetime formatting strings, such as
    #   '%A, %Y-%m-%d %I:%M:%S %p' or '%j'. each element of fmt that is a
    #   datetime token is replaced with a regex string that matches
    #   what the token represents. For example, '%Y' matches a 4-digit
    #   year and '[0-9]{4}' matches a 4-digit numeric sequence. non-token
    #   characters (anything not following a %) are not modified. Note that
    #   tokens B, b, h, A, and a are replaced by '[a-zA-Z]+', which matches
    #   any sequence of one or more alphabetic characters of either case,
    #   not just meaningful month/day names 'Weds' or 'january'. Also note
    #   that these tokens are not currently accepted: g, G, n, t, c, r, R, T.
    #optional is a vector of characters that should be made
    #   optional in the exported regex (followed by a '?'). This is useful if
    #   e.g. fmt is '%H:%M:%S' and elements to be matched may either appear in
    #   HH:MM:SS or HH:MM format. making the ":" character optional here
    #   (via optional = ':') allows the hour and minute data to be retained,
    #   whereas the regex engine would otherwise expect two ":"s, find
    #   only one, and return NA.

    dt_format_regex <- list(Y = '([0-9]{4})?',    #year
                            y = '([0-9]{2})?',    #year
                            B = '([a-zA-Z]+)?',   #month
                            b = '([a-zA-Z]+)?',   #month
                            h = '([a-zA-Z]+)?',   #month
                            m = '([0-9]{1,2})?',  #month
                            e = '([0-9]{1,2})?',  #day
                            d = '([0-9]{1,2})?',  #day
                            j = '([0-9]{3})?',    #day
                            A = '([a-zA-Z]+)?',   #day
                            a = '([a-zA-Z]+)?',   #day
                            u = '([0-9]{1})?',    #day
                            w = '([0-9]{1})?',    #day
                            U = '([0-9]{2})?',    #week
                            W = '([0-9]{2})?',    #week
                            V = '([0-9]{2})?',    #week
                            C = '([0-9]{2})?',    #century
                            H = '([0-9]{1,2})?',  #hour
                            I = '([0-9]{1,2})?',  #hour
                            M = '([0-9]{1,2})?',  #minute
                            S = '([0-9]{1,2})?',  #second
                            p = '([AP]M)?',       #AM/PM
                            # z = '([+\\-][0-9]{4})?', #signed hour
                            `F` = '([0-9]{4}-[0-9]{2}-[0-9]{2})') #YMD

    for(i in 1:length(fmt)){
        fmt_components <- str_match_all(string = fmt[i],
                                        pattern = '%([a-zA-Z])')[[1]][,2]

        if(any(fmt_components %in% c('g', 'G', 'n', 't', 'c'))){
            stop(paste('Tokens g, G, n, and t are not yet accepted.',
                       'enhance dt_format_to_regex if you want to use them!'))
        }
        if(any(fmt_components %in% c('r', 'R', 'T'))){
            stop('Tokens r, R, and T are not accepted. Use a different specification.')
        }
        if(any(fmt_components %in% c('z'))){
            stop('"z" probably should be accepted, but we would need to accommodate it when assigning hour defaults in resolve_datetime')
        }

        for(j in 1:length(fmt_components)){
            component <- fmt_components[j]
            fmt[i] <- sub(pattern = paste0('%', component),
                          replacement = dt_format_regex[[component]],
                          x = fmt[i])
        }
    }

    if(! missing(optional)){
        for(o in optional){
            fmt <- gsub(pattern = o,
                        replacement = paste0(o, '?'),
                        x = fmt)
        }
    }

    return(fmt)
}

escape_special_regex <- function(x){

    #x is a character vector. any special characters in x will be escaped with
    #   a double backslash, e.g. "air.pressure.kpa" will become
    #   "air\\.pressure\\.kpa"

    #this function currently only escapes "." and "|", because they're the
    #   special regex characters that can appear in column names.

    special_regex_colchars <- c('.', '|')
    special_regex <- paste0('([\\',
                            paste(special_regex_colchars,
                                  collapse = '\\'),
                            '])')

    escaped <- gsub(pattern = special_regex,
                    replacement = '\\\\\\1',
                    x,
                    perl = TRUE)

    return(escaped)
}

ms_cast_and_reflag <- function(d,
                               input_shape = 'wide',
                               data_col_pattern = '#V#__|dat',
                               varflag_col_pattern = '#V#__|flg',
                               variable_flags_to_drop,
                               variable_flags_clean,
                               variable_flags_dirty,
                               variable_flags_bdl,
                               summary_flags_to_drop,
                               summary_flags_clean,
                               summary_flags_dirty,
                               summary_flags_bdl,
                               keep_empty_rows = FALSE){

    #d is a df/tibble with ONLY a site_code column, a datetime column,
    #   flag and/or status columns, and data columns. There must be no
    #   columns with grouping data, variable names, units, methods, etc.
    #   Data columns must be suffixed identically. Variable flag columns
    #   must be suffixed identically and differently from data columns.
    #   If d was generated by ms_read_raw_csv, it will be good to go.
    #input_shape is the format ("wide"/"long") of d
    #   (currently only "wide" supported).
    #data_col_pattern: a string containing the wildcard "#V#",
    #   which represents any number of characters, and the suffix that pertains
    #   to data columns (currently this must be '#V#__|dat'.
    #varflag_col_pattern: a string containing the wildcard "#V#",
    #   which represents any number of characters, and the suffix that pertains
    #   to variable flag/status columns (currently this must be '#V#__|flg'.
    #   Or set this to NA if there are no variable-specific flag/status columns.
    #variable_flags_to_drop: a character vector of values that might appear in
    #   the variable flag columns. Elements of this vector are treated as
    #   bad data and are removed. Use '#*#' to refer to all values not
    #   specified in variable_flags_clean (or variable_flags_bdl). This will also
    #   keep any variables specified via variable_flags_dirty, but the point of '#*#'
    #   is that you don't need to specify all of those, if there are lots of them.
    #   This parameter is optional,
    #   though at least 2 of variable_flags_to_drop, variable_flags_clean,
    #   and variable_flags_dirty must be supplied if varflag_col_pattern is specified
    #   (not NA) AND variable_flags_bdl is not provided.
    #   If '#*#' is used, variable_flags_clean must be supplied.
    #variable_flags_clean: a character vector of values that might appear in
    #   the variable flag columns. Elements of this vector are given an
    #   ms_status of 0, meaning clean. This parameter is optional, though at least 2
    #   of variable_flags_to_drop, variable_flags_clean, and variable_flags_dirty
    #   must be supplied if varflag_col_pattern is specified
    #   (not NA) AND variable_flags_bdl is not provided.
    #   This parameter does not use the '#*#' wildcard.
    #variable_flags_dirty: a character vector of values that might appear in
    #   the variable flag columns. Elements of this vector are given an
    #   ms_status of 1, meaning dirty/questionable. This parameter is optional, though at least 2
    #   of variable_flags_to_drop, variable_flags_clean, and variable_flags_dirty
    #   must be supplied if varflag_col_pattern is specified
    #   (not NA) AND variable_flags_bdl is not provided.
    #   This parameter does not use the '#*#' wildcard.
    #variable_flags_bdl: optional character vector of values that might appear in
    #   the variable flag columns indicating that their corresponding data values are
    #   below detection limit. These values will be replaced with half their
    #   detection limit by qc_hdetlim_and_uncert. Resulting ms_status will be
    #   set to 1 (dirty/questionable).
    #summary_flags_to_drop: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in
    #   the summary flag/status columns. Associated records are treated as
    #   bad data and are removed. Use '#*#' to refer to all values not
    #   included in summary_flags_clean or summary_flags_bdl. This parameter is optional, though
    #   if there are summary flag columns, at least 2
    #   of summary_flags_to_drop, summary_flags_clean, and summary_flags_dirty
    #   must be supplied (omit this argument otherwise).
    #   If '#*#' is used, summary_flags_clean must be supplied.
    #summary_flags_clean: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in the summary flag/status columns.
    #   Associated records are given an ms_status of 0, meaning clean.
    #   This parameter is optional, though
    #   if there are summary flag columns, at least 2 of summary_flags_to_drop,
    #   summary_flags_clean, and summary_flags_dirty must be supplied
    #   (omit this argument otherwise).
    #   Note: This parameter does not use the '#*#' wildcard.
    #summary_flags_dirty: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in the summary flag/status columns.
    #   Associated records are given an ms_status of 1, meaning dirty.
    #   This parameter is optional, though
    #   if there are summary flag columns, at least 2 of summary_flags_to_drop,
    #   summary_flags_clean, and summary_flags_dirty must be supplied
    #   (omit this argument otherwise).
    #   Note: This parameter does not use the '#*#' wildcard.
    #summary_flags_bdl: optional named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in the summary flag/status columns.
    #   Associated data records are assigned ms_status = 2, which is used as an
    #   indicator to insert 1/2 detlims downstream.
    #keep_empty_rows: logical. if FALSE, rows without data values will be dropped.

    #return value: a long-format tibble with 5 columns: datetime, site_code,
    #   var, val, ms_status. Rows with NA in any non-status column are removed,
    #   except rows with NA in the val column and ms_status == 2, designating
    #   a BDL value that will be inserted as 1/2 detlim later.

    #arg checks
    if(! input_shape == 'wide'){
        stop('ms_cast_and_reflag only implemented for input_shape = "wide"')
    }

    sumdrop <- ! missing(summary_flags_to_drop) && ! is.null(summary_flags_to_drop)
    sumclen <- ! missing(summary_flags_clean) && ! is.null(summary_flags_clean)
    sumdirt <- ! missing(summary_flags_dirty) && ! is.null(summary_flags_dirty)
    sumbdl <- ! missing(summary_flags_bdl) && ! is.null(summary_flags_bdl)
    no_sumflags <- all(c(sumdrop, sumclen, sumdirt) == FALSE) #not including bdl...

    if(sum(c(sumdrop, sumclen, sumdirt)) == 1){
        stop(paste0('Must supply 2 (or none) of summary_flags_to_drop, ',
                    'summary_flags_clean, summary_flags_dirty'))
    }

    name_orders <- list()

    if(sumclen){
        if(! inherits(summary_flags_clean, 'list')){
            stop('summary_flags_clean must be a list')
        }
        if(any(sapply(summary_flags_clean, function(x) '#*#' %in% x))){
            stop(glue('the #*# wildcard may only be used in ',
                      'summary_flags_to_drop and variable_flags_to_drop'))
        }
        name_orders[['clen']] <- names(summary_flags_clean)
    }

    if(sumdirt){
        if(! inherits(summary_flags_dirty, 'list')){
            stop('summary_flags_dirty must be a list')
        }
        if(any(sapply(summary_flags_dirty, function(x) '#*#' %in% x))){
            stop(glue('the #*# wildcard may only be used in ',
                      'summary_flags_to_drop and variable_flags_to_drop'))
        }
        name_orders[['dirt']] <- names(summary_flags_dirty)
    }

    if(sumdrop){

        if(! inherits(summary_flags_to_drop, 'list')){
            stop('summary_flags_to_drop must be a list')
        }

        drop_wildcard_bool <- sapply(summary_flags_to_drop, function(x) '#*#' %in% x)
        if(any(drop_wildcard_bool) && ! sumclen){
            stop(glue('if #*# wildcard is used in summary_flags_to_drop, ',
                      'summary_flags_clean must be supplied'))
        }

        drop_multicode_bool <- sapply(summary_flags_to_drop, function(x) length(x) > 1)
        if(any(drop_wildcard_bool & drop_multicode_bool)){
            stop(glue('if #*# wildcard is supplied as part of summary_flags_to_drop,',
                      ' it must be in a character vector of length 1'))
        }

        name_orders[['drop']] <- names(summary_flags_to_drop)
    }

    if(sumbdl){
        name_orders[['bdl']] <- names(summary_flags_bdl)
    }

    if(sumclen || sumdirt || sumdrop || sumbdl){
        order_seen <- name_orders[[1]]
        if(length(name_orders) > 1){
            for(i in 2:length(name_orders)){
                nord <- name_orders[[i]]
                if(! identical(order_seen[order_seen %in% nord], nord[nord %in% order_seen])){
                    stop('sub-elements of summary_flag_* parameters must appear in the same order')
                }
            }
        }
    }

    vardrop <- ! missing(variable_flags_to_drop) && ! is.null(variable_flags_to_drop)
    varclen <- ! missing(variable_flags_clean) && ! is.null(variable_flags_clean)
    vardirt <- ! missing(variable_flags_dirty) && ! is.null(variable_flags_dirty)
    varbdl <- ! missing(variable_flags_bdl) && ! is.null(variable_flags_bdl)
    no_varflags <- is.na(varflag_col_pattern)

    if(varclen && varbdl && ! vardirt){
        warning('under this specification (variable_flags clean + bdl +/- drop - dirty), all unmatched varflags (except NA) will become ms_status = 1 (dirty)')
    }
    if(vardirt && varbdl && ! varclen){
        warning('under this specification (variable_flags dirty + bdl +/- drop - clean), all unmatched varflags will become ms_status = 0 (clean)')
    }
    if(vardrop && varbdl && ! varclen && ! vardirt){
        stop('illegal specification (variable flags drop + bdl - clean - dirty). Please specify either clean or dirty in addition to drop.')
    }

    if(sum(c(vardrop, varclen, vardirt)) < 2 && ! no_varflags && ! varbdl){
        stop(paste0('Must supply at least 2 of variable_flags_to_drop, ',
                    'variable_flags_clean, variable_flags_dirty (or set ',
                    'varflag_col_pattern = NA)'))
    }

    if(varclen){
        justNA <- length(variable_flags_clean) == 1 && is.na(variable_flags_clean)
        if(! (justNA || mode(variable_flags_clean) == 'character')){
            stop('variable_flags_clean must be a character vector')
        }
    }

    if(vardirt){
        justNA <- length(variable_flags_dirty) == 1 && is.na(variable_flags_dirty)
        if(! (justNA || mode(variable_flags_dirty) == 'character')){
            stop('variable_flags_dirty must be a character vector')
        }
    }

    if(vardrop){

        justNA <- length(variable_flags_to_drop) == 1 && is.na(variable_flags_to_drop)
        if(! (justNA || mode(variable_flags_to_drop) == 'character')){
            stop('variable_flags_to_drop must be a character vector')
        }

        if('#*#' %in% variable_flags_to_drop && length(variable_flags_to_drop) > 1){
            stop(glue('if #*# wildcard is used in variable_flags_to_drop,',
                      ' it must be the only element in its argument vector'))
        }

        if(variable_flags_to_drop == '#*#' && ! varclen){
            stop(glue('if #*# wildcard is used in variable_flags_to_drop, ',
                      'variable_flags_clean must be supplied'))
        }
    }

    #make sure args jibe with ms_read_raw_csv args
    all_na_rows <- filter(d, if_all(ends_with('__|dat'), is.na))
    if(nrow(all_na_rows) && ! keep_empty_rows){
        warning('keep_empty_rows is FALSE, but there are all-NA rows, suggesting ',
                'that parameter was set differently in ms_read_raw_csv')
    }

    #make sure the same flagcodes aren't passed to more than one parameter
    varflgs_c <- c('variable_flags_dirty', 'variable_flags_clean', 'variable_flags_to_drop', 'variable_flags_bdl')
    dupe_flags <- c()
    for(p in varflgs_c){
        for(q in varflgs_c){
            if(p == q) next
            pp = try(get(p), silent = TRUE); if(inherits(pp, 'try-error')) next
            qq = try(get(q), silent = TRUE); if(inherits(qq, 'try-error')) next
            dupe_flags <- intersect(pp, qq)
            if(length(dupe_flags)) stop(paste('same code used in', p, 'and', q))
        }
    }

    summflgs_c <- c('summary_flags_dirty', 'summary_flags_clean', 'summary_flags_to_drop', 'summary_flags_bdl')
    dupe_flags <- c()
    for(p in summflgs_c){
        for(q in summflgs_c){
            if(p == q) next
            pp = try(get(p), silent = TRUE); if(inherits(pp, 'try-error')) next
            qq = try(get(q), silent = TRUE); if(inherits(qq, 'try-error')) next
            shared_names <- intersect(names(pp), names(qq))
            for(s in shared_names){
                dupe_flags <- intersect(pp[[s]], qq[[s]])
                if(length(dupe_flags)) stop(paste('same code used corresponding elements of', p, 'and', q))
            }
        }
    }

    if(! no_sumflags){
        if(sumdrop){
            summary_colnames <- names(summary_flags_to_drop)
        } else {
            summary_colnames <- names(summary_flags_clean)
        }
    } else {
        summary_colnames <- NULL
    }

    if(sumbdl){
        sum_bdl_colnames <- names(summary_flags_bdl)
    } else {
        sum_bdl_colnames <- NULL
    }

    data_col_keyword <- gsub(pattern = '#V#',
                             replacement = '',
                             data_col_pattern)

    varflag_keyword <- gsub(pattern = '#V#',
                            replacement = '',
                            varflag_col_pattern)

    #cast to long format (would have to auto-generate names_pattern regex
    #   to allow for data_col_pattern and varflag_col_pattern to vary) if
    #   there's more than one data column. otherwise just remove data column
    #   suffix.
    ndatacols <- sum(grepl(escape_special_regex(data_col_keyword),
                           colnames(d)))
    if(ndatacols > 1){

        if(no_varflags){
            d <- pivot_longer(data = d,
                              cols = ends_with(data_col_keyword),
                              names_pattern = '^(.+?)__\\|(dat)$',
                              names_to = c('var', '.value'))
        } else {
            d <- pivot_longer(data = d,
                              cols = ends_with(c(data_col_keyword, varflag_keyword)),
                              names_pattern = '^(.+?)__\\|(dat|flg)$',
                              names_to = c('var', '.value'))
        }

    } else {

        data_ind <- grep(pattern = escape_special_regex(data_col_keyword),
             x = colnames(d))

        varname  <- gsub(pattern = escape_special_regex(data_col_keyword),
                         replacement = '',
                         x = colnames(d)[data_ind])

        colnames(d)[data_ind] <- 'dat'
        d$var <- varname
    }

    #filter rows with summary flags indicating bad data (data to drop)
    if(! no_sumflags){


        smflags <- c('summary_flags_clean', 'summary_flags_dirty', 'summary_flags_bdl', 'summary_flags_to_drop')
        summary_flag_colnames <- mget(smflags) %>%
            map(names) %>%
            reduce(union)

        #lots of work to warn user if they don't specify '' as a clean summary flag
        if(sumclen){

            known_chars <- unname(unlist(sw(
                purrr::keep(unlist(mget(smflags)),
                            ~ length(.) > 1 ||
                                is.na(.) ||
                                (inherits(., 'character') && nchar(.) >= 0)))))

            for(s in summary_flag_colnames){
                if('' %in% d[[s]] && ! '' %in% summary_flags_clean[[s]]){
                    warning('Summary flag "" (empty string) is present in column ',
                            s, ' but not marked as "clean". are you sure about this?')
                }
            }
        }

        #another elaborate check to see that all possible flags are accounted for
        if(sumdirt && sumclen && sumdrop){

            flags_handled <- c()
            flags_seen <- c()
            i <- 0
            passes <- 0
            while(TRUE){

                i <- i + 1

                if(sumclen && length(summary_flags_clean) >= i){
                    flags_handled <- c(flags_handled, summary_flags_clean[[i]])
                    flags_seen <- c(flags_seen, unique(d[[names(summary_flags_clean)[i]]]))
                } else {
                    passes <- passes + 1
                }

                if(sumdirt && length(summary_flags_dirty) >= i){
                    flags_handled <- c(flags_handled, summary_flags_dirty[[i]])
                    flags_seen <- c(flags_seen, unique(d[[names(summary_flags_dirty)[i]]]))
                } else {
                    passes <- passes + 1
                }

                if(sumdrop && length(summary_flags_to_drop) >= i){
                    flags_handled <- c(flags_handled, summary_flags_to_drop[[i]])
                    flags_seen <- c(flags_seen, unique(d[[names(summary_flags_to_drop)[i]]]))
                } else {
                    passes <- passes + 1
                }

                if(sumbdl && length(summary_flags_bdl) >= i){
                    flags_handled <- c(flags_handled, summary_flags_bdl[[i]])
                    flags_seen <- c(flags_seen, unique(d[[names(summary_flags_bdl)[i]]]))
                } else {
                    passes <- passes + 1
                }

                if(passes == 4) break

                flags_unaccounted_for <- setdiff(flags_seen, flags_handled)

                if(any(is.na(flags_unaccounted_for))){
                    warning('NA summary flags not explicitly handled. Assuming these are clean')
                    flags_unaccounted_for <- flags_unaccounted_for[! is.na(flags_unaccounted_for)]
                }

                if(length(flags_unaccounted_for)){
                    flags_unaccounted_for[flags_unaccounted_for == ''] <- '[empty string]'
                    stop('under this specification (summary_flags clean + dirty + drop +/- bdl), ',
                         'every flag must be explicitly handled. Please specify what to do with ',
                         'these flags in column "', summary_flag_colnames[i], '": ',
                         paste(flags_unaccounted_for, collapse = ', '))
                }

                passes <- 0
            }
        }

        if(sumdrop){

            drop_rows <- matrix(NA, nrow = nrow(d), ncol = length(summary_flags_to_drop))
            for(i in 1:length(summary_flags_to_drop)){

                smtd <- summary_flags_to_drop[i]
                if(length(smtd[[1]]) == 1 && smtd[[1]] == '#*#'){

                    if(is.null(unlist(summary_flags_clean[i])) ||
                       (sumdirt && ! is.null(unlist(summary_flags_dirty[i])))){
                        stop('if summary_flags_to_drop is "#*#", corresponding summary_flags_clean must be supplied and summary_flags_dirty must not.')
                    }

                    flagcol <- d[[names(summary_flags_clean)[i]]]
                    accounted_for <- is.na(flagcol) | flagcol %in% summary_flags_clean[[i]]
                    drop_rows[accounted_for, i] <- FALSE

                    if(sumbdl && length(summary_flags_bdl) >= i){
                        flagcol <- d[[names(summary_flags_bdl)[i]]]
                        accounted_for <- is.na(flagcol) | flagcol %in% summary_flags_bdl[[i]]
                        drop_rows[accounted_for, i] <- FALSE
                    }

                } else {
                    drop_rows[d[[names(smtd)]] %in% unlist(smtd), i] <- TRUE
                }
            }

            drop_rows <- apply(drop_rows, 1, any)
            drop_rows[is.na(drop_rows)] <- FALSE
            d <- d[! drop_rows, ]

        } else {

            drop_rows <- rep(TRUE, nrow(d))
            i <- 0
            passes <- 0
            while(TRUE){

                i <- i + 1

                if(sumclen && length(summary_flags_clean) >= i){
                    flagcol <- d[[names(summary_flags_clean)[i]]]
                    accounted_for <- is.na(flagcol) | flagcol %in% summary_flags_clean[[i]]
                    drop_rows[accounted_for] <- FALSE
                } else {
                    passes <- passes + 1
                }

                if(sumdirt && length(summary_flags_dirty) >= i){
                    flagcol <- d[[names(summary_flags_dirty)[i]]]
                    accounted_for <- is.na(flagcol) | flagcol %in% summary_flags_dirty[[i]]
                    drop_rows[accounted_for] <- FALSE
                } else {
                    passes <- passes + 1
                }

                if(sumbdl && length(summary_flags_bdl) >= i){
                    flagcol <- d[[names(summary_flags_bdl)[i]]]
                    accounted_for <- is.na(flagcol) | flagcol %in% summary_flags_bdl[[i]]
                    drop_rows[accounted_for] <- FALSE
                } else {
                    passes <- passes + 1
                }

                if(passes == 3) break
                passes <- 0
            }

            warning('under this specification (summary_flags clean + dirty +/- bdl - drop), ',
                    'all unmatched sumflags are DROPPED. dropping ', sum(drop_rows), ' of ',
                    nrow(d), ' records. Note that NA summary flags are never dropped.')

            d <- d[! drop_rows, ]
        }
    }

    #filter rows with variable flags indicating bad data (data to drop)
    if(! no_varflags){

        dont_drop_these <- c('variable_flags_clean', 'variable_flags_dirty', 'variable_flags_bdl')
        dont_drop_these <- unname(unlist(purrr::keep(mget(dont_drop_these),
                                                     ~ length(.) > 1 || sw(is.na(.)) || nchar(.) > 0)))

        if(vardrop){

            if(variable_flags_to_drop == '#*#'){
                warning('the "#*#" flag should probably be hard-deprecated.')
                d <- filter(d, is.na(flg) | flg %in% dont_drop_these)
            } else {
                d <- filter(d, ! flg %in% variable_flags_to_drop)
            }

        } else if(varclen && vardirt){

            to_drop <- nrow(filter(d, ! is.na(flg) & ! flg %in% dont_drop_these))
            warning('under this specification (variable_flags clean + dirty +/- bdl - drop), ',
                    'all unmatched varflags are DROPPED. dropping ', to_drop, ' of ',
                    nrow(d), ' records')
            d <- filter(d, is.na(flg) | flg %in% dont_drop_these)
        }
    }

    #binarize remaining flag information (not including BDLs yet; 0 = clean, 1 = questionable)
    if(! no_varflags && sum(c(varclen, vardirt, vardrop, varbdl)) != 1){ #i.e. if not only varbdl

        accounted_for <- c('variable_flags_clean', 'variable_flags_dirty', 'variable_flags_bdl', 'variable_flags_to_drop')
        accounted_for <- unname(unlist(purrr::keep(mget(accounted_for),
                                                   ~ length(.) > 1 || sw(is.na(.)) || nchar(.) > 0)))

        if('' %in% d$flg && varclen && ! '' %in% get('variable_flags_clean')){
            warning('Variable flag "" (empty string) is not marked as "clean". are you sure about this?')
        }

        if(vardirt && varclen && vardrop){

            flags_unaccounted_for <- setdiff(d$flg, accounted_for)

            if(any(is.na(flags_unaccounted_for))){
                warning('NA variable flags not explicitly handled. Assuming these are clean')
                flags_unaccounted_for <- flags_unaccounted_for[! is.na(flags_unaccounted_for)]
            }

            if(length(flags_unaccounted_for)){
                flags_unaccounted_for[flags_unaccounted_for == ''] <- '[empty string]'
                stop('under this specification (variable_flags clean + dirty + drop +/- bdl), ',
                     'every flag must be explicitly handled. Please specify what to do with ',
                     'these flags: ', paste(flags_unaccounted_for, collapse = ', '))
            }
        }

        if(varclen){
            d <- mutate(d, ms_status = if_else(is.na(flg) | flg %in% variable_flags_clean,
                                               0,
                                               1))
        } else {
            d <- mutate(d, ms_status = if_else(flg %in% variable_flags_dirty,
                                               1,
                                               0))
        }

    } else {
        d$ms_status <- 0
    }

    if(! no_sumflags){

        if(sumdirt){

            for(i in 1:length(summary_flags_dirty)){
                si <- summary_flags_dirty[i]
                flg_bool <- d[[names(si)]] %in% unlist(si)
                d$ms_status[flg_bool] <- 1
            }

        } else {

            d$ms_status <- 1
            for(i in 1:length(summary_flags_clean)){
                si <- summary_flags_clean[i]
                flagcol <- d[[names(si)]]
                flg_bool <- is.na(flagcol) | flagcol %in% unlist(si)
                d$ms_status[flg_bool] <- 0
            }
        }
    }

    #set val and ms_status for BDL records
    if(sumbdl){
        #this probably wouldn't happen unless there were only one data column
        for(i in seq_along(summary_flags_bdl)){
            si <- summary_flags_bdl[i]
            bdl_inds <- d[[names(si)]] %in% unlist(si)
            d[bdl_inds, 'ms_status'] <- 2 #this is a temporary flag. will be changed to 1 downstream.
        }
    }

    if(varbdl){
        bdl_inds <- d$flg %in% variable_flags_bdl
        d[bdl_inds, 'ms_status'] <- 2 #this is a temporary flag. will be changed to 1 downstream.
    }

    #remove rows with NA in the value column and no bdl flag.
    #these take up space and can be reconstructed by casting to wide form
    if(! keep_empty_rows){
        d <- filter(d, ! is.na(dat) | ms_status == 2)
    }

    #rearrange columns (this also would have to be flexified if we ever want
    #   to pass something other than the default for data_col_pattern or
    #   varflag_col_pattern
    d <- sw(d %>%
        select(-one_of(c(summary_colnames, 'flg'))) %>%
        select(datetime, site_code, var, dat, ms_status) %>%
        rename(val = dat) %>%
        arrange(site_code, var, datetime))

    return(d)
}

ms_conversions__ <- function(d,
                           keep_molecular,
                           convert_units_from,
                           convert_units_to,
                           row_wise = FALSE){

    #d: a macrosheds tibble that has already been through ms_cast_and_reflag
    #keep_molecular: a character vector of molecular formulae to be
    #   left alone. Otherwise these formulae: NO3, SO4, PO4, SiO2, NH4, NH3, NO3_NO2,
    #   will be converted according to the atomic masses of their main
    #   constituents. For example, NO3 should be converted to NO3-N within
    #   macrosheds, but passing 'NO3' to keep_molecular will leave it as NO3.
    #   The only time you'd want to do this is when a domain provides both
    #   forms. In that case we would process both forms separately, converting
    #   neither.
    #convert_units_from: a named character vector. Names are variable names
    #   without their sample-regimen prefixes (e.g. 'DIC', not 'GN_DIC'),
    #   and values are the units of those variables. Omit variables that don't
    #   need to be converted.
    #convert_units_to: a named character vector. Names are variable names
    #   without their sample-regimen prefixes (e.g. 'DIC', not 'GN_DIC'),
    #   and values are the units those variables should be converted to.
    #   Omit variables that don't need to be converted.
    #row_wise: logical. If TRUE, treat every row as a unique case, with its own
    #   separate conversion. This is necessary for converting detection limits
    #   in domain_detection_limits.

    #checks
    # cm <- ! missing(convert_molecules)
    cuF <- ! missing(convert_units_from) && ! is.null(convert_units_from)
    cuT <- ! missing(convert_units_to) && ! is.null(convert_units_to)

    if(sum(cuF, cuT) == 1){
        stop('convert_units_from and convert_units_to must be supplied together')
    }
    if(length(convert_units_from) != length(convert_units_to)){
        stop('convert_units_from and convert_units_to must have the same length')
    }

    if(! row_wise){
        if(any(duplicated(names(convert_units_from)))){
            stop('duplicated names in convert_units_from')
        }
        if(any(duplicated(names(convert_units_to)))){
            stop('duplicated names in convert_units_to')
        }

        cu_shared_names <- base::intersect(names(convert_units_from),
                                           names(convert_units_to))
        if(length(cu_shared_names) != length(convert_units_to)){
            stop('names of convert_units_from and convert_units_to must match')
        }

    } else {

        if(any(names(convert_units_from) != names(convert_units_to))){
            stop('in row_wise mode, names of convert_units_from and convert_units_to must be identical')
        }

        cu_shared_names <- names(convert_units_from)

        if(length(cu_shared_names) != nrow(d)){
            stop(paste('in row_wise mode, lengths of convert_units_from and convert_units_to',
                       'must be equal to the number of rows in d'))
        }

    }

    if(any(grepl('M', c(convert_units_from, convert_units_to)))){
        stop('specify moles as "mol", rather than "M"')
    }
    if(any(grepl('moles', c(convert_units_from, convert_units_to)))){
        stop('specify moles as "mol", rather than "moles"')
    }

    convert_units_from <- tolower(convert_units_from)
    convert_units_to <- tolower(convert_units_to)

    vars <- drop_var_prefix(d$var)

    if(is.null(vars) || any(is.na(vars)) || any(vars == '')){
        stop('some vars misspecified in d. are they missing prefixes?')
    }

    errant_var_specs <- ! cu_shared_names %in% vars
    if(any(errant_var_specs)){
        warning(paste('variables',
                      paste(cu_shared_names[errant_var_specs], collapse = ', '),
                      'not present in d. did you mean something else?'))
    }

    cmols <- normally_converted_molecules

    if(! missing(keep_molecular)){
        if(any(! keep_molecular %in% cmols)){
            stop(glue('keep_molecular must be a subset of {cm}',
                      cm = paste(cmols,
                                 collapse = ', ')))
        }
        cmols <- cmols[! cmols %in% keep_molecular]
    }

    cmols <- cmols[cmols %in% unique(vars)]

    #handle molecular conversions, like NO3 -> NO3_N

    for(v in cmols){

        v_ <- v
        if(v == 'orthophosphate') v_ <- 'PO4'

        d$val[vars == v] <- convert_molecule(x = d$val[vars == v],
                                             from = v_,
                                             to = unlist(molecular_conversion_map[v]))

        check_double <- str_split_fixed(unname(molecular_conversion_map[v]),
                                        '',
                                        n = Inf)[1, ]

        if(length(check_double) > 1 && length(unique(check_double)) == 1){
            molecular_conversion_map[v] <- unique(check_double)
        }

        new_name <- paste0(d$var[vars == v], '_', unname(molecular_conversion_map[v]))
        d$var[vars == v] <- new_name
    }

    loop_length <- ifelse(row_wise, nrow(d), length(convert_units_from))
    for(i in 1:loop_length){

        unitfrom <- convert_units_from[i]
        unitto <- convert_units_to[i]
        v <- names(unitfrom)

        d_subset <- if(row_wise) i else vars == v

        # Converts input to grams if the final unit contains grams
        g_conver <- FALSE
        if(grepl('mol|eq', unitfrom) && grepl('g', unitto) ||
           v %in% cmols){

            d$val[d_subset] <- convert_to_gl(x = d$val[d_subset],
                                             input_unit = unitfrom,
                                             molecule = v)

            g_conver <- TRUE
        }

        #convert prefix
        d$val[d_subset] <- convert_unit(x = d$val[d_subset],
                                        input_unit = unitfrom,
                                        output_unit = unitto)

        #Convert to mol or eq if that is the output unit
        if(grepl('mol|eq', unitto)) {

            d$val[d_subset] <- convert_from_gl(x = d$val[d_subset],
                                               input_unit = unitfrom,
                                               output_unit = unitto,
                                               molecule = v,
                                               g_conver = g_conver)
        }

        #Convert to #/mL from #/100mL
        if(grepl('#\\/ml', unitto) && grepl('#\\/100ml', unitfrom)) {
            d$val[d_subset] <- d$val[d_subset]/100
        }
    }

    return(d)
}

query_status <- function(status_code_vec, component = 'flag'){

    #TODO: investigate r packages for bitmapping in C*/FORTRAN

    #currently, status code integers have three digits. The first digit
    #represents qa/qc flags. 0 means unflagged and 1 means flagged. The
    #second digit is for datapoints that have been interpolated by macrosheds --
    #0 means original and 1 means interpolated. The third digit is for sensor (0)
    #versus grab (1) data.

    if(! component %in% c('flag', 'interp', 'regimen')){
        stop('component must be one of "flag", "interp", "regimen"')
    }

    #if we add status codes, they'll get tacked on to the right side of the
    #status code integer, and the following conditional will need to be updated.
    #just add the condition at the end, make it yield pos = 1, and increment the
    #positions yielded by the other conditions by 1.
    pos <- case_when(
        component == 'flag' ~ 3,
        component == 'interp' ~ 2,
        component == 'regimen' ~ 1)
    #component == 'new component' ~ 1

    #convert "binary" int to decimal int
    dec <- strtoi(as.character(status_code_vec), base = 2L)

    #get bit of interest as a decimal representation of a one-hot binary integer
    onehot <- bitwShiftL(1, (pos - 1))

    #if bit of interest is 0 in the status code, bitwise AND with the onehot
    #   will yield zero. if the bit of interest is 1, result will be nonzero
    bit_is_on <- bitwAnd(dec, onehot) != 0

    return(bit_is_on)
}

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

    #return()
}

get_all_local_helpers <- function(network, domain){

    #source_decoratees reads in decorator functions (tinsel package).
    #because it can only read them into the current environment, all files
    #sourced by this function are exported locally, then exported globally

    location1 <- glue('src/{n}/network_helpers.R',
                      n = network)

    if(file.exists(location1)){

        sw(source(location1, local = TRUE))

        if(ms_instance$use_ms_error_handling){
            sw(source_decoratees(location1))
        }
    }

    location2 <- glue('src/{n}/{d}/domain_helpers.R',
                      n = network,
                      d = domain)

    if(file.exists(location2)){

        sw(source(location2, local = TRUE))

        if(ms_instance$use_ms_error_handling){
            sw(source_decoratees(location2))
        }
    }

    location3 <- glue('src/{n}/processing_kernels.R',
                      n = network)

    if(file.exists(location3)){

        sw(source(location3, local = TRUE))

        if(ms_instance$use_ms_error_handling){
            sw(source_decoratees(location3))
        }
    }

    location4 <- glue('src/{n}/{d}/processing_kernels.R',
                      n = network,
                      d = domain)

    if(file.exists(location4)){

        sw(source(location4, local = TRUE))

        if(ms_instance$use_ms_error_handling){
            sw(source_decoratees(location4))
        }
    }

    rm(location1, location2, location3, location4)

    export_to_global(from_env = environment(),
                     exclude = c('network', 'domain', 'thisenv'))
}

set_up_logger <- function(network = domain, domain){

    #the logging package establishes logger hierarchy based on name.
    #our root logger is named "ms", and our network-domain loggers are named
    #ms.network.domain, e.g. "ms.lter.hbef". When messages are logged, loggers
    #are referred to as name.module. A message logged to
    #logger="ms.lter.hbef.module" would be handled by loggers named
    #"ms.lter.hbef", "ms.lter", and "ms", some of which may not have established
    #handlers

    logger_name <- glue('ms.{n}.{d}',
                       n = network,
                       d = domain)

    logger_module <- glue(logger_name,
                          '.module')

    if(! dir.exists('logs')){
        dir.create('logs',
                   showWarnings = FALSE)
    }

    logging::addHandler(handler = logging::writeToFile,
                        logger = logger_name,
                        file = glue('logs/{n}_{d}.log',
                                    n = network,
                                    d = domain))

    return(logger_module)
}

extract_from_config <- function(key){
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = stringr::str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}

clear_from_mem <- function(..., clearlist){

    if(missing(clearlist)){
        dots = match.call(expand.dots = FALSE)$...
        clearlist = vapply(dots, as.character, '')
    }

    rm(list=clearlist, envir=.GlobalEnv)
    gc()

    #return()
}

retain_ms_globals <- function(retain_vars){

    all_globals = ls(envir=.GlobalEnv, all.names=TRUE)
    clutter = all_globals[! all_globals %in% retain_vars]

    clear_from_mem(clearlist=clutter)

    #return()
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

generate_blocklist_indicator = function(text=1){
    indobj = text
    class(indobj) = 'blocklist_indicator'
    return(indobj)
}

is_ms_err <- function(x){
    return('ms_err' %in% class(x))
}

is_ms_exception <- function(x){
    return('ms_exception' %in% class(x))
}

is_blocklist_indicator <- function(x){
    return('blocklist_indicator' %in% class(x))
}

evaluate_result_status <- function(r){

    if(is_ms_err(r) || is_ms_exception(r)){
        status <- 'error'
    } else if(is_blocklist_indicator(r)){
        status <- 'blocklist'
    } else {
        status <- 'ok'
    }

    return(status)
}

email_err <- function(msgs, addrs, pw){

    if(is.list(msgs)){
        msgs = Reduce(function(x, y) paste(x, y, sep='\n---\n'), msgs)
    }

    text_body = glue('Error list:\n\n', msgs, '\n\nEnd of errors')

    mailout = tryCatch({

        for(a in addrs){

            email = emayili::envelope() %>%
                emayili::from('grdouser@gmail.com') %>%
                emayili::to(a) %>%
                emayili::subject('MacroSheds error') %>%
                emayili::text(text_body)

            smtp = emayili::server(host='smtp.gmail.com',
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
        logging::logerror(msg, logger=logger_module)
        return('email fail')
    } else {
        return('email success')
    }

}

get_data_tracker <- function(network = domain, domain){

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

make_tracker_skeleton <- function(retrieval_chunks,
                                  versionless){

    #retrieval_chunks is a vector of identifiers for subsets (chunks) of
    #the overall dataset to be retrieved, e.g. sitemonths for NEON

    munge_derive_skeleton <- list(status = 'pending',
                                  mtime = '1500-01-01')

    tracker_skeleton <- list(
        retrieve = tibble::tibble(
            component = retrieval_chunks,
            mtime = '1500-01-01',
            held_version = ifelse(versionless, '1500-01-01', '-1'),
            status = 'pending'),
        munge = munge_derive_skeleton,
        derive = munge_derive_skeleton)

    return(tracker_skeleton)
}

insert_site_skeleton <- function(tracker,
                                 prodname_ms,
                                 site_code,
                                 site_components,
                                 versionless = FALSE){

    #if versionless is TRUE, held_version will be populated with
    #"1500-01-01" as a placeholder value,
    #because the modification date stands in for the version when
    #we're dealing with versionless products. otherwise, held_version is given
    #a placeholder of -1

    tracker[[prodname_ms]][[site_code]] <-
        make_tracker_skeleton(retrieval_chunks = site_components,
                              versionless = versionless)

    return(tracker)
}

product_is_tracked <- function(tracker, prodname_ms){
    bool = prodname_ms %in% names(tracker)
    return(bool)
}

site_is_tracked <- function(tracker, prodname_ms, site_code){
    bool = site_code %in% names(tracker[[prodname_ms]])
    return(bool)
}

track_new_product <- function(tracker, prodname_ms){

    if(prodname_ms %in% names(tracker)){
        logwarn('This product is already being tracked.', logger=logger_module)
        return(tracker)
    }

    tracker[[prodname_ms]] = list()
    return(tracker)
}

track_new_site_components <- function(tracker, prodname_ms, site_code, avail){

    retrieval_tracker <- tracker[[prodname_ms]][[site_code]]$retrieve

    new_avail <- avail %>%
        filter(! component %in% retrieval_tracker$component) %>%
        select(component) %>%
        mutate(mtime = '1900-01-01',
               held_version = '-1',
               status = 'pending')

    if(! all(retrieval_tracker$component %in% avail$component)){

        obsolete_components <- retrieval_tracker %>%
            filter(! component %in% avail$component) %>%
            pull(component)

        logwarn(msg = glue("Tracked component(s) {tc} no longer available. ",
                           "Removing from tracker.",
                           tc = paste(obsolete_components,
                                      collapse = ', ')),
                logger = logger_module)

        retrieval_tracker <- filter(retrieval_tracker,
                                    component %in% avail$component)
    }

    retrieval_tracker <- new_avail %>%
        bind_rows(retrieval_tracker) %>%
        arrange(component)

    tracker[[prodname_ms]][[site_code]]$retrieve <- retrieval_tracker

    return(tracker)
}

filter_unneeded_sets <- function(tracker_with_details){

    new_sets = tracker_with_details %>%
        filter(status != 'blocklist' | is.na(status)) %>%
        filter(needed == TRUE | is.na(needed))

    if(any(is.na(new_sets$needed))){
        msg = paste0('Must run `track_new_site_components` and ',
                     '`populate_set_details` before running `populate_set_details`')
        logerror(msg, logger=logger_module)
        stop(msg)
    }

    return(new_sets)
}

update_data_tracker_r <- function(network = domain,
                                  domain,
                                  tracker = NULL,
                                  tracker_name = NULL,
                                  set_details = NULL,
                                  new_status = NULL){

    #this updates the retrieve section of a data tracker in memory and on disk.
    #see update_data_tracker_m for the munge section and update_data_tracker_d
    #for the derive section

    #if tracker is supplied, it will be used to write/overwrite the one on disk.
    #if it is omitted or set to NULL, the appropriate tracker will be loaded
    #from disk, updated, and then written back to disk. tracker_name, set_details,
    #and new_status must be supplied if tracker is not.

    if(exists('tracker', envir = .GlobalEnv)){
        warning('there is a "tracker" object defined in the global environment. ',
                'update_data_tracker_r will not work as intended')
    }

    if(is.null(tracker) && (
        is.null(tracker_name) || is.null(set_details) || is.null(new_status)
    )){

        msg <- paste0('If tracker is not supplied, these args must be:',
                     'tracker_name, set_details, new_status.')

        logerror(msg,
                 logger = logger_module)
        stop(msg)
    }

    if(is.null(tracker)){

        tracker <- get_data_tracker(network = network,
                                    domain = domain)

        rt <- tracker[[set_details$prodname_ms]][[set_details$site_code]]$retrieve

        if('component' %in% names(rt)){
            set_ind <- which(rt$component == set_details$component)
        } else {

            if(nrow(rt) > 1){
                stop('we need a way to distinguish rows when "component" column is missing')
            }

            set_ind <- 1
        }

        if(new_status %in% c('pending', 'ok')){

            if('avail_version' %in% names(set_details)){
                rt$held_version[set_ind] <- as.character(set_details$avail_version)
            } else {
                rt$held_version[set_ind] <- as.character(set_details$last_mod_dt)
            }
        }

        rt$status[set_ind] <- new_status
        rt$mtime[set_ind] <- as.character(Sys.time())

        tracker[[set_details$prodname_ms]][[set_details$site_code]]$retrieve <- rt

        assign(x = tracker_name,
               value = tracker,
               pos = .GlobalEnv)
    }

    trackerdir <- glue('data/{n}/{d}',
                       n = network,
                       d = domain)

    if(! dir.exists(trackerdir)){

        dir.create(trackerdir,
                   showWarnings = FALSE,
                   recursive = TRUE)
    }

    trackerfile <- glue(trackerdir,
                        '/data_tracker.json')

    readr::write_file(x = jsonlite::toJSON(tracker),
                      file = trackerfile)
    backup_tracker(trackerfile)
}

update_data_tracker_m <- function(network = domain,
                                  domain,
                                  tracker_name,
                                  prodname_ms,
                                  site_code,
                                  new_status){

    #this updates the munge section of a data tracker in memory and on disk.
    #see update_data_tracker_r for the retrieval section and
    #update_data_tracker_d for the derive section

    # #OBSOLETE? in addition, if new_status == 'ok', this function looks for the word
    # #"linked" in the "derive_status"
    # #column of the products.csv file for the corresponding network, domain,
    # #and linkprod row, and changes it to NA it if found.
    # #that way, any new versions of munged products will be re-linked to derive/.
    #
    # if(new_status == 'ok'){
    #
    #     prodfile <- glue('src/{n}/{d}/products.csv',
    #                      n = network,
    #                      d = domain)
    #
    #     prods <- sm(read_csv(prodfile))
    #
    #     # prodcode <- prodcode_from_prodname_ms(prodname_ms)
    #     prodname <- prodname_from_prodname_ms(prodname_ms)
    #     prodcode <- prods %>%
    #         filter(prodname == !!prodname,
    #                grepl('ms[0-9]{3}', prodcode)) %>%
    #         pull(prodcode)
    #
    #     rind <- which(prods$prodcode == prodcode & prods$prodname == prodname)
    #     sts <- prods$derive_status[rind]
    #
    #     for(i in seq_along(rind)){
    #
    #         if(! is.na(sts[i]) && sts[i] == 'linked'){
    #             prods$derive_status[rind[i]] <- NA_character_
    #         }
    #     }
    #
    #     write_csv(x = prods,
    #               file = prodfile)
    # }

    tracker <- get_data_tracker(network = network,
                                domain = domain)

    mt <- tracker[[prodname_ms]][[site_code]]$munge

    mt$status <- new_status
    mt$mtime <- as.character(Sys.time())

    tracker[[prodname_ms]][[site_code]]$munge <- mt

    assign(x = tracker_name,
           value = tracker,
           pos = .GlobalEnv)

    trackerdir <- glue('data/{n}/{d}',
                       n = network,
                       d = domain)

    if(! dir.exists(trackerdir)){
        dir.create(trackerdir,
                   showWarnings = FALSE,
                   recursive = TRUE)
    }

    trackerfile <- glue(trackerdir, '/data_tracker.json')
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)
}

update_data_tracker_d <- function(network = domain,
                                  domain,
                                  tracker = NULL,
                                  tracker_name = NULL,
                                  prodname_ms = NULL,
                                  site_code = NULL,
                                  new_status = NULL){

    #this updates the derive section of a data tracker in memory and on disk.
    #see update_data_tracker_r for the retrieval section and
    #update_data_tracker_m for the munge section

    #if tracker is supplied, it will be used to write/overwrite the one on disk.
    #if it is omitted or set to NULL, the appropriate tracker will be loaded
    #from disk, updated, and then written back to disk. tracker_name, set_details,
    #and new_status must be supplied if tracker is not.

    if(exists('tracker', envir = .GlobalEnv)){
        warning('there is a "tracker" object defined in the global environment. ',
                'update_data_tracker_d will not work as intended')
    }

    if(is.null(tracker) && (
        is.null(tracker_name) || is.null(prodname_ms) ||
        is.null(new_status) || is.null(site_code)
    )){
        msg = paste0('If tracker is not supplied, these args must be:',
                     'tracker_name, prodname_ms, new_status, new_status.')
        logerror(msg, logger=logger_module)
        stop(msg)
    }

    if(is.null(tracker)){

        tracker <- get_data_tracker(network = network,
                                    domain = domain)

        dt <- tracker[[prodname_ms]][[site_code]]$derive

        if(is.null(dt)){
            msg <- 'Derived product not yet tracked; not updating derive tracker.'
            # logging::logwarn(msg)
            return(generate_ms_exception(msg))
        }

        dt$status <- new_status
        dt$mtime <- as.character(Sys.time())
        tracker[[prodname_ms]][[site_code]]$derive <- dt

        assign(x = tracker_name,
               value = tracker,
               pos = .GlobalEnv)
    }

    trackerdir <- glue('data/{n}/{d}',
                       n = network,
                       d = domain)

    if(! dir.exists(trackerdir)){
        dir.create(trackerdir,
                   showWarnings = FALSE,
                   recursive = TRUE)
    }

    trackerfile <- glue(trackerdir, '/data_tracker.json')
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)
}

update_data_tracker_g <- function(network = domain,
                                  domain,
                                  tracker,
                                  prodname_ms,
                                  site_code,
                                  new_status){

    #this updates the general section of a data tracker in memory and on disk.

    #see update_data_tracker_r for the retrieval section,
    #update_data_tracker_m for the munge section, and
    #update_data_tracker_d for the derive section

    dt <- tracker[[prodname_ms]][[site_code]]$general

    if(is.null(dt)){
        return(generate_ms_exception('Product not yet tracked; no action taken.'))
    }

    dt$status <- new_status
    dt$mtime <- as.character(Sys.time())

    tracker[[prodname_ms]][[site_code]]$general <- dt

    assign(x = 'held_data',
           value = tracker,
           pos = .GlobalEnv)

    trackerfile <- glue('data/{n}/{d}/data_tracker.json',
                        n = network,
                        d = domain)

    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)
}

backup_tracker <- function(path,
                           force = FALSE){

    #force: logical. if FALSE, new tracker backup will only be written once per
    #   hour. If TRUE, it will be written regardless (up to once per second)

    mch <- stringr::str_match(path,
                              '(data/.+?/.+?)/(data_tracker.json)')[, 2:3]

    if(any(is.na(mch))){
        stop('Invalid tracker path or name')
    }

    dir.create(glue(mch[1], '/tracker_backups'),
               recursive = TRUE,
               showWarnings = FALSE)

    time_format <- ifelse(force, '%Y%m%dT%H%M%SZ', '%Y%m%dT%HZ')

    tstamp <- Sys.time() %>%
        with_tz(tzone = 'UTC') %>%
        format(time_format)

    newpath <- glue('{p}/tracker_backups/{f}_{t}',
                    p = mch[1],
                    f = mch[2],
                    t = tstamp)

    file.copy(from = path,
              to = newpath,
              overwrite = FALSE)

    #remove tracker backups older than 7 days
    system2('find', c(glue(mch[1], '/tracker_backups/*'),
                      '-mtime', '+7', '-exec', 'rm', '{}', '\\;'))
}

extract_retrieval_log <- function(tracker, prodname_ms, site_code,
                                  keep_status = 'ok'){

    retrieved_data <- tracker[[prodname_ms]][[site_code]]$retrieve %>%
        tibble::as_tibble() %>%
        filter(status %in% keep_status)

    return(retrieved_data)
}

get_munge_status <- function(tracker, prodname_ms, site_code){
    munge_status = tracker[[prodname_ms]][[site_code]]$munge$status
    return(munge_status)
}

get_derive_status <- function(tracker, prodname_ms, site_code){
    derive_status = tracker[[prodname_ms]][[site_code]]$derive$status
    return(derive_status)
}

get_general_status <- function(tracker, prodname_ms, site_code){
    general_status = tracker[[prodname_ms]][[site_code]]$general$status
    return(general_status)
}

get_product_info <- function(network,
                             domain,
                             status_level,
                             get_statuses){

    #status_level: string. one of "retrieve", "munge", "derive"
    #get_statuses: character vector. any of the possible kernel statuses, including
    #   "ready", "pending", "paused"

    #if status_level is
    #"derive", output will be sorted so that canonical derive products
    #(stream_flux_inst, precipitation, precip_chem, precip_flux_inst) are last,
    #ensuring that any prerequisites, including "compiled" products, are generated
    #first. If two derive products have the same name, they will be sorted
    #numerically (e.g. ms003, ms009)

    prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain)))

    status_column <- glue(status_level,
                          '_status')

    prods <- prods[prods[[status_column]] %in% get_statuses, ]

    if(status_level == 'derive'){

        custom_prods <- prods %>%
            filter(grepl('^CUSTOM', prodname))

        combiner_for_typical <- prods$prodname %in% c('precipitation', 'precip_chemistry') &
            ! grepl('^ms[8-9][0-9]{2}$', prods$prodcode)

        atypicals <- prods %>%
            filter(! prodname %in% !!typical_derprods | combiner_for_typical,
                   ! grepl('^CUSTOM', prodname)) %>%
            arrange(prodcode)

        #usgs Q and/or cdnr Q must be retrieved before Q is combined
        external_q_source <- str_match(atypicals$prodname, '(.+)_discharge')[, 2] %>%
            na.omit()
        if(any(! external_q_source %in% c('usgs', 'cdnr'))){
            stop('need to update this for new external discharge source')
        }

        atypicals_sorted <- bind_rows(filter(atypicals, grepl('(?:usgs|cdnr)_discharge', prodname)),
                                      filter(atypicals, ! grepl('(?:usgs|cdnr)_discharge', prodname)))

        typicals_sorted <- prods %>%
            filter(prodname %in% !!typical_derprods,
                   ! combiner_for_typical,
                   ! grepl('^CUSTOM', prodname)) %>%
            arrange(order(match(prodname, !!typical_derprods)))

        prods <- bind_rows(atypicals_sorted,
                           typicals_sorted,
                           custom_prods)
    }

    return(prods)
}

prodcode_from_prodname_ms <- function(prodname_ms){

    #prodname_ms consists of the macrosheds official name for a data
    #category, e.g. discharge, and the source-specific code for that
    #data product, e.g. DP1.20093. These two values are concatenated,
    #separated by a double underscore. So long as we never use a double
    #underscore in a macrosheds official data category name, this function
    #will be able to split a prodname_ms into its two constituent parts.

    #accepts a vector of prodname_ms strings

    prodcode <- sapply(prodname_ms,
                       function(x){
                           namesplit <- strsplit(x, '__')[[1]]
                           name_length <- length(namesplit)
                           prodcode <- namesplit[2:name_length]
                           paste(prodcode, collapse = '__')
                       },
                       USE.NAMES = FALSE)

    # namesplit <- strsplit(prodname_ms, '__')[[1]]
    # name_length <- length(namesplit)
    # prodcode <- namesplit[2:name_length]
    # prodcode <- paste(prodcode, collapse = '__')

    return(prodcode)
}

prodname_from_prodname_ms <- function(prodname_ms){

    #prodname_ms consists of the macrosheds official name for a data
    #category, e.g. discharge, and the source-specific code for that
    #data product, e.g. DP1.20093. These two values are concatenated,
    #separated by a double underscore. So long as we never use a double
    #underscore in a macrosheds official data category name, this function
    #will be able to split a prodname_ms into its two constituent parts.

    #accepts a vector of prodname_ms strings

    prodname <- sapply(prodname_ms,
                       function(x) strsplit(x, '__')[[1]][1],
                       USE.NAMES = FALSE)
    # prodname <- strsplit(prodname_ms, '__')[[1]][1]

    return(prodname)
}

ms_retrieve <- function(network = domain,
                        domain,
                        prodname_filter = NULL){

    #execute main retrieval script for this network-domain
    norm_retrieve <- file.exists(glue('src/{n}/{d}/retrieve.R',
                                      n = network,
                                      d = domain))

    if(norm_retrieve){
        source(glue('src/{n}/{d}/retrieve.R',
                    n = network,
                    d = domain),
               local = TRUE)
    }

    #if there's a script for retrieval of versionless products, execute it too
    versionless_product_script <- glue('src/{n}/{d}/retrieve_versionless.R',
                                       n = network,
                                       d = domain)

    versionless_retrieve <- file.exists(versionless_product_script)
    if(versionless_retrieve){

        source(versionless_product_script,
               local = TRUE)
    }

    if(! norm_retrieve && ! versionless_retrieve){
        stop(glue('No retrieval script avalible for {n} {d}',
                  n = network,
                  d = domain))
    }
}

ms_munge <- function(network = domain,
                     domain,
                     prodname_filter = NULL){

    if(domain == 'neon'){
        #ensures that composite neon discharge is munged before official neon discharge
        source('src/neon/neon/munge_versionless.R', local = TRUE)
    }

    #execute main munge script for this network-domain
    norm_munge <- file.exists(glue('src/{n}/{d}/munge.R',
                                   n = network,
                                   d = domain))

    if(norm_munge){
        source(glue('src/{n}/{d}/munge.R',
                    n = network,
                    d = domain),
               local = TRUE)
    }

    #if there's a script for munging of versionless products, execute it too
    if(domain != 'neon'){

        versionless_product_script <- glue('src/{n}/{d}/munge_versionless.R',
                                           n = network,
                                           d = domain)

        if(file.exists(versionless_product_script)){

            source(versionless_product_script,
                   local = TRUE)
        }
    }

    if(! norm_munge && ! file.exists(versionless_product_script)){
        stop(glue('No munge script avalible for {n} {d}',
                  n = network,
                  d = domain))
    }
}

ms_general <- function(network = domain,
                       domain,
                       get_missing_only = FALSE,
                       general_prod_filter = NULL,
                       site_filter = NULL,
                       bulk_mode = TRUE){

    #get_missing_only: logical. if TRUE, ws_traits will only be retrieved
    #    for ws_traits directories that are missing or empty
    #general_prod_filter: character vector. only these products will be retrieved.
    #site_filter: character vector. only these sites will be retrieved.
    #bulk_mode. logical: if TRUE, the bounding box of the domain will be used to
    #   retrieve spatial data. if FALSE, site bboxes are used instead. TRUE is
    #   appropriate everywhere except NEON as of 2024. questioning that on 20240902

    if(get_missing_only){
        get_missing_only <<- TRUE
    } else {
        get_missing_only <<- FALSE
    }

    if(bulk_mode){
        bulk_mode <<- TRUE
    } else {
        bulk_mode <<- FALSE
    }

    if(! is.null(general_prod_filter)){
        general_prod_filter_ <<- general_prod_filter
    } else {
        sw(rm('general_prod_filter_', envir = .GlobalEnv))
    }

    if(! is.null(site_filter)){
        site_filter_ <<- site_filter
    } else {
        sw(rm('site_filter_', envir = .GlobalEnv))
    }

    source(glue('src/global/general.R',
                n = network,
                d = domain),
           local = TRUE)
}

ms_delineate <- function(network,
                         domain,
                         dev_machine_status,
                         verbose = FALSE,
                         overwrite_wb_sites = c()){

    #dev_machine_status: either '1337', indicating that your machine has >= 16 GB
    #   RAM, or 'n00b', indicating < 16 GB RAM. DEM resolution is chosen
    #   accordingly. passed to delineate_watershed_apriori
    #verbose: logical. determines the amount of informative messaging during run
    # overwrite_wb_sites: vector of sitenames to overwrite

    loginfo(msg = 'Beginning watershed delineation',
            logger = logger_module)

    site_locations <- site_data %>%
        filter(
            network == !!network,
            domain == !!domain,
            # ! is.na(latitude),
            # ! is.na(longitude),
            site_type == 'stream_gauge',
            in_workflow == 1) %>%
        select(site_code, latitude, longitude, CRS, colocated_gauge_id)

    #checks
    if(any(is.na(site_locations$latitude) | is.na(site_locations$longitude))){

        missing_loc <- is.na(site_locations$latitude) |
            is.na(site_locations$longitude)

        missing_site_codes <- site_locations$site_code[missing_loc]

        stop(glue('Missing/incomplete site location for:\nnetwork: {n}\ndomain: {d}\n',
                  'site(s): {ss}\n(see site_data gsheet)',
                  n = network,
                  d = domain,
                  ss = paste(missing_site_codes,
                             collapse = ', ')))
    }

    if(any(is.na(site_locations$CRS))){

        missing_site_codes <- site_locations$site_code[is.na(site_locations$CRS)]

        stop(glue('Missing CRS for:\nnetwork: {n}\ndomain: {d}\n',
                  'site(s): {ss}\n(see site_data gsheet)',
                  n = network,
                  d = domain,
                  ss = paste(missing_site_codes,
                             collapse = ', ')))
    }

    #locate or create the directory that contains watershed boundaries
    munged_dirs <- list.dirs(glue('data/{n}/{d}/munged',
                                  n = network,
                                  d = domain),
                             recursive = FALSE,
                             full.names = FALSE)

    ws_boundary_dir <- grep(pattern = '^ws_boundary.*',
                            x = munged_dirs,
                            value = TRUE)

    if(! length(ws_boundary_dir)){
        ws_boundary_dir <- 'ws_boundary__ms000'
        level <- 'derived'
        dir.create(glue('data/{n}/{d}/derived/{w}',
                        n = network,
                        d = domain,
                        w = ws_boundary_dir),
                   recursive = TRUE,
                   showWarnings = FALSE)
    } else {
        level <- 'munged'
    }

    #for each stream gauge site, check for existing wb file. if none, delineate
    for(i in 1:nrow(site_locations)){

        site <- site_locations$site_code[i]

        if(length(overwrite_wb_sites)){
            if(! site %in% overwrite_wb_sites){
                message('only working on overwrite sites, skipping')
                next
            }
        }

        if(verbose){
            print(glue('delineating {n}-{d}-{s} (site {sti} of {sl})',
                       n = network,
                       d = domain,
                       s = site,
                       sti = i,
                       sl = nrow(site_locations)))
        }

        site_dir <- glue('data/{n}/{d}/{l}/{w}/{s}',
                         n = network,
                         d = domain,
                         w = ws_boundary_dir,
                         l = level,
                         s = site)

        if(site %in% overwrite_wb_sites){
            message('site in overwrite vector, launching new delineation (you still need to manually remove the old delin specs from gsheet)')
        } else if(dir.exists(site_dir) && length(dir(site_dir))){
            message(glue('{s} already delineated ({d}). it will be re-linked during derive.',
                         s = site,
                         d = site_dir))

            #calculate watershed area and write it to site_data gsheet
            catch <- ms_calc_watershed_area(network = network,
                                            domain = domain,
                                            site_code = site,
                                            level = level,
                                            update_site_file = TRUE)

            next
        }

        dir.create(site_dir,
                   showWarnings = FALSE)

        if(site %in% overwrite_wb_sites) {
            specs <- data.frame(matrix(ncol = 1, nrow = 0))
        } else {
            specs <- ws_delin_specs %>%
                filter(network == !!network,
                       domain == !!domain,
                       site_code == !!site)
        }

        if(nrow(specs) == 1){

            message('Delineating from stored specifications')

            if(specs$flat_increment == 'null'){
                flat_increment <- NULL
            } else {
                flat_increment <- as.numeric(specs$flat_increment)
            }

            # specs=list(buffer_radius_m=1000,snap_siatance_m=150,snap_method='standard',
            #            dem_resolution=10,breach_method='lc',burn_streams=FALSE)
            delineate_watershed_by_specification(
                lat = site_locations$latitude[i],
                long = site_locations$longitude[i],
                crs = site_locations$CRS[i],
                buffer_radius = specs$buffer_radius_m,
                snap_dist = specs$snap_distance_m,
                snap_method = specs$snap_method,
                dem_resolution = specs$dem_resolution,
                flat_increment = flat_increment,
                breach_method = specs$breach_method,
                burn_streams = specs$burn_streams,
                write_dir = site_dir,
                verbose = verbose) %>%
                invisible()

            catch <- ms_calc_watershed_area(network = network,
                                            domain = domain,
                                            site_code = site,
                                            level = level,
                                            update_site_file = TRUE)

            loginfo(msg = glue('Delineation complete: {n}-{d}-{s}',
                               n = network,
                               d = domain,
                               s = site),
                    logger = logger_module)

            next
            #everything that follows pertains to interactive selection of an
            #appropriate delineation

        } else if(nrow(specs) == 0){

            if(! site %in% overwrite_wb_sites){
                if(ms_instance$instance_type != 'dev'){
                    stop(glue('Missing delineation specs for {n}-{d}-{s}. ',
                              'Delineate locally and push changes.',
                              n = network,
                              d = domain,
                              s = site))
                }
            }

            coloc_gauge <- site_locations$colocated_gauge_id[i]
            if(! is.na(coloc_gauge)){

                coloc_gauge_ <- str_split(coloc_gauge, ':')[[1]]

                if(! coloc_gauge_[1] == 'usgs') stop('alternative delineation routine only built for usgs gauges atm')

                delineate_watershed_nhd(site_code = site_locations$site_code[i],
                                        nwis_gauge_id = coloc_gauge_[2],
                                        write_dir = site_dir)

            } else {

                tmp <- tempdir()

                selection <- delineate_watershed_apriori_recurse(
                    lat = site_locations$latitude[i],
                    long = site_locations$longitude[i],
                    crs = site_locations$CRS[i],
                    site_code = site,
                    buffer_radius = NULL,
                    snap_dist = NULL,
                    snap_method = NULL,
                    dem_resolution = NULL,
                    flat_increment = NULL,
                    breach_method = 'basic',
                    burn_streams = FALSE,
                    scratch_dir = tmp,
                    write_dir = site_dir,
                    dev_machine_status = dev_machine_status,
                    verbose = verbose)

                if(is.numeric(selection) && selection == 1) next
                if(is.numeric(selection) && selection == 2) return(invisible(NULL))
            }

        } else {
            stop('Multiple entries for same network/domain/site in site_data')
        }

        if(is.na(coloc_gauge)){

            #write the specifications of the correctly delineated watershed
            rgx <- str_match(selection,
                             paste0('^wb[0-9]+_BUF([0-9]+)(standard|jenson)',
                                    'DIST([0-9]+)RES([0-9]+)INC([0-1\\.null]+)',
                                    'BREACH(basic|lc)BURN(TRUE|FALSE)\\.shp$'))

            write_wb_delin_specs(network = network,
                                 domain = domain,
                                 site_code = site,
                                 buffer_radius = as.numeric(rgx[, 2]),
                                 snap_method = rgx[, 3],
                                 snap_distance = as.numeric(rgx[, 4]),
                                 dem_resolution = as.numeric(rgx[, 5]),
                                 flat_increment = rgx[, 6],
                                 breach_method = rgx[, 7],
                                 burn_streams = rgx[, 8])
        }

        #calculate watershed area and write it to site_data gsheet
        catch <- ms_calc_watershed_area(network = network,
                                        domain = domain,
                                        site_code = site,
                                        level = level,
                                        update_site_file = TRUE)
    }


    prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain)))

    if(ws_boundary_dir == 'ws_boundary__ms000' &&
       ! 'ms000' %in% prods$prodcode){

        wb_successor_string <- prods %>%
            filter(
                grepl(pattern = '^ms[0-9]{3}$',
                      x = prodcode),
                prodname == 'precip_pchem_pflux') %>%
            mutate(prodname_ms = paste(prodname,
                                       prodcode,
                                       sep = '__')) %>%
            pull(prodname_ms) %>%
            paste(., collapse = '||')

        append_to_productfile(network = network,
                              domain = domain,
                              prodname = 'ws_boundary',
                              prodcode = 'ms000',
                              precursor_of = wb_successor_string,
                              notes = 'automated entry')
    }

    loginfo(msg = 'Delineations complete',
            logger = logger_module)
}

delineate_watershed_nhd <- function(site_code, nwis_gauge_id, write_dir){

    library(nhdplusTools)

    loginfo(paste('Retrieving watershed boundary from nhd for site:', site_code),
            logger = logger_module)

    nldi_nwis <- list(featureSource = "nwissite",
                      featureID = paste('USGS',
                                        as.character(nwis_gauge_id),
                                        sep = '-'))

    wb_sf <- nhdplusTools::get_nldi_basin(nldi_feature = nldi_nwis,
                                          simplify = FALSE,
                                          split = TRUE)

    ws_area_ha <- as.numeric(sf::st_area(wb_sf)) / 10000

    wb_sf <- wb_sf %>%
        mutate(site_code = !!site_code) %>%
        mutate(area = !!ws_area_ha)

    sw(sf::st_write(obj = wb_sf,
                    dsn = glue('{d}/{s}.shp',
                               d = write_dir,
                               s = site_code),
                    delete_dsn = TRUE,
                    quiet = TRUE))
}

choose_dem_resolution <- function(dev_machine_status, buffer_radius){

    if(dev_machine_status == '1337'){
        dem_resolution <- case_when(
            buffer_radius <= 1e4 ~ 12,
            buffer_radius == 1e5 ~ 11,
            buffer_radius == 1e6 ~ 10,
            buffer_radius == 1e7 ~ 8,
            buffer_radius == 1e8 ~ 6,
            buffer_radius == 1e9 ~ 4,
            buffer_radius >= 1e10 ~ 2)
    } else if(dev_machine_status == 'n00b'){
        dem_resolution <- case_when(
            buffer_radius <= 1e4 ~ 10,
            buffer_radius == 1e5 ~ 8,
            buffer_radius == 1e6 ~ 6,
            buffer_radius == 1e7 ~ 4,
            buffer_radius == 1e8 ~ 2,
            buffer_radius >= 1e9 ~ 1)
    } else {
        stop('dev_machine_status must be either "1337" or "n00b"')
    }

    return(dem_resolution)
}

delineate_watershed_apriori_recurse <- function(lat,
                                                long,
                                                crs,
                                                site_code,
                                                buffer_radius = NULL,
                                                snap_dist = NULL,
                                                snap_method = NULL,
                                                dem_resolution = NULL,
                                                flat_increment = NULL,
                                                breach_method = 'lc',
                                                burn_streams = FALSE,
                                                scratch_dir = tempdir(),
                                                write_dir,
                                                dev_machine_status = 'n00b',
                                                verbose = FALSE){

    #This function calls delineate_watershed_apriori recursively, taking
    #   user input after each call, until the user selects a delineation
    #   or aborts. For parameter documentation, see delineate_watershed_apriori.

    # tmp <- tempdir()
    scratch_dir <- stringr::str_replace_all(scratch_dir, '\\\\', '/')

    delin_out <- delineate_watershed_apriori(
        lat = lat,
        long = long,
        crs = crs,
        site_code = site_code,
        snap_dist = snap_dist,
        snap_method = snap_method,
        dem_resolution = dem_resolution,
        flat_increment = flat_increment,
        breach_method = breach_method,
        burn_streams = burn_streams,
        buffer_radius = buffer_radius,
        scratch_dir = scratch_dir,
        dev_machine_status = dev_machine_status,
        verbose = verbose)

    inspection_dir <- delin_out$inspection_dir

    files_to_inspect <- list.files(path = inspection_dir,
                                   pattern = '.shp')

    temp_point <- glue(scratch_dir, '/', 'POINT')

    tibble(longitude = long, latitude = lat) %>%
        sf::st_as_sf(coords = c('longitude', 'latitude'),
                     crs = crs) %>%
        sf::st_write(dsn = temp_point,
                     driver = 'ESRI Shapefile',
                     delete_dsn = TRUE,
                     quiet = TRUE)

    # #if only one delineation, write it into macrosheds storage
    # if(length(files_to_inspect) == 1){
    #
    #     selection <- files_to_inspect[1]
    #
    #     move_shapefiles(shp_files = selection,
    #                     from_dir = inspection_dir,
    #                     to_dir = write_dir)
    #
    #     message(glue('Delineation successful. Shapefile written to ',
    #                  write_dir))
    #
    #     #otherwise, technician must inspect all delineations and choose one
    # } else {

    nshapes <- length(files_to_inspect)
    numeric_selections <- paste('Accept delineation', 1:nshapes)

    wb_selections <- paste(paste0('[',
                                  c(1:nshapes, 'M', 'D', 'S', 'B', 'U', 'R', 'I', 'n', 'a'),
                                  ']'),
                           c(numeric_selections,
                             'Select pourpoint snapping method',
                             'Set pourpoint snapping maximum distance (meters)',
                             'Burn streams into the DEM (may help delineator across road-stream intersections)',
                             'Use more aggressive breaching method (temporary default, pending whitebox bugfix)',
                             'Set buffer radius (distance from pourpoint to include in DEM download; meters)',
                             'Select DEM resolution',
                             'Set flat_increment',
                             'Next (skip this one for now)',
                             'Abort delineation'),
                           sep = ': ',
                           collapse = '\n')

    # helper_code <- glue('{id}.\nmapview::mapviewOptions(fgb = FALSE);',
    #                     'mapview::mapview(sf::st_read("{wd}/{f}")) + ',
    #                     'mapview::mapview(sf::st_read("{pf}"))',
    #                     id = 1:length(files_to_inspect),
    #                     wd = inspection_dir,
    #                     f = files_to_inspect,
    #                     pf = temp_point) %>%
    #     paste(collapse = '\n\n')

    msg <- glue::glue('\n\nVisually inspect the watershed boundary candidate(s).\n',
                      # 'by pasting the mapview lines below into a separate instance of R.\n\n{hc}\n\n',
                      'Enter the number corresponding to the ',
                      'one that looks best, or select one or more tuning ',
                      'options (e.g. MDSBUR).\n\nChoices:\n{sel}\n\nEnter choice(s) here > ',
                      # hc = helper_code,
                      sel = wb_selections)

    for(i in seq_along(files_to_inspect)){

        mpv <- mapview::mapview(sf::st_read(file.path(inspection_dir,
                                                      files_to_inspect[i]),
                                            quiet = TRUE),
                                layer.name = paste('Candidate watershed', i)) +
            mapview::mapview(sf::st_read(temp_point, quiet = TRUE),
                             legend = FALSE,
                             layer.name = 'Input lat long')
            # mapview::mapview(sf::st_read(delin_out$unique_snaps_f[i]),
            #                  legend = FALSE,
            #                  layer.name = 'Snapped pour point')

        print(mpv)
        if(i != length(files_to_inspect)){
            get_response_enter(paste('\nPress [enter/return] to see candidate',
                                     i + 1))
        }
    }

    resp <- get_response_mchar(
        msg = msg,
        possible_resps = paste(c(1:nshapes, 'M', 'D', 'S', 'B', 'U', 'R', 'I', 'n', 'a'),
                               collapse = ''),
        allow_alphanumeric_response = FALSE)

    if('n' %in% resp){
        unlink(write_dir)
        print(glue('Moving on. You haven\'t seen the last of {s}!',
                   s = site_code))
        return(1)
    }

    if('a' %in% resp){
        unlink(write_dir)
        print(glue('Aborted. Any completed delineations have been saved.'))
        return(2)
    }

    if('M' %in% resp){
        snap_method <- get_response_1char(
            msg = paste0('Standard snapping moves the pourpoint to the cell with ',
                         'the highest flow accumulation within snap_dist. Jenson ',
                         'method tries to snap to the nearest stream cell.\n\n',
                         '1. Jenson\n2. Standard\n\n',
                         'Enter choice here > '),
            possible_chars = paste(1:2))
        snap_method <- ifelse(snap_method == '1', 'jenson', 'standard')
    }

    if('D' %in% resp){
        snap_dist <- get_response_int(
            msg = paste0('Enter a snap distance between 0 and 200 (meters) > '),
            min_val = 0,
            max_val = 200)
    }

    if('S' %in% resp){
        burn_streams <- TRUE
    } else {
        burn_streams <- FALSE
    }

    if('B' %in% resp){
        breach_method <- 'basic'
    } else {
        breach_method <- 'basic' #TODO: undo this when whitebox is fixed
        # breach_method <- 'lc'
    }

    if('U' %in% resp){
        buffer_radius <- get_response_int(
            msg = paste0('Enter a buffer radius between 1000 and 100000 (meters) > '),
            min_val = 0,
            max_val = 100000)
    }

    if('R' %in% resp){
        dem_resolution <- get_response_mchar(
            msg = paste0('Choose DEM resolution between 1 (low) and 14 (high)',
                         ' to pass to elevatr::get_elev_raster. For tiny ',
                         'watersheds, use 12-13. For giant ones, use 8-9.\n\n',
                         'Enter choice here > '),
            possible_resps = paste(1:14))
        dem_resolution <- as.numeric(dem_resolution)
    }

    if('I' %in% resp){

        bm <- ifelse(breach_method == 'basic',
                     'whitebox::wbt_breach_depressions',
                     'whitebox::wbt_breach_depressions_least_cost')

        new_options <- paste(paste0('[',
                                    c('S', 'M', 'L'),
                                    ']'),
                             c('0.001', '0.01', '0.1'),
                             sep = ': ',
                             collapse = '\n')

        resp2 <- get_response_1char(
            msg = glue('Pick the size of the elevation increment to pass to ',
                       bm, '.\n\n', new_options, '\n\nEnter choice here > '),
            possible_chars = c('S', 'M', 'L'))

        flat_increment <- switch(resp2,
                                 S = 0.001,
                                 M = 0.01,
                                 L = 0.1)
    }

    if(! any(grepl('[0-9]', resp))){

        if(is.null(buffer_radius)){
            buffer_radius_ <- delin_out$buffer_radius
        } else {
            buffer_radius_ <- buffer_radius
        }

        selection <- delineate_watershed_apriori_recurse(
            lat = lat,
            long = long,
            crs = crs,
            site_code = site_code,
            snap_dist = snap_dist,
            snap_method = snap_method,
            dem_resolution = dem_resolution,
            flat_increment = flat_increment,
            breach_method = breach_method,
            burn_streams = burn_streams,
            buffer_radius = buffer_radius_,
            scratch_dir = scratch_dir,
            write_dir = write_dir,
            dev_machine_status = dev_machine_status,
            verbose = verbose)

        return(selection)
    }

    selection <- files_to_inspect[as.numeric(resp)]

    move_shapefiles(shp_files = selection,
                    from_dir = inspection_dir,
                    to_dir = write_dir,
                    new_name_vec = site_code)

    message(glue('Selection {s}:\n\t{sel}\nwas written to:\n\t{sdr}',
                 s = resp,
                 sel = selection,
                 sdr = write_dir))

    return(selection)
}

get_utm_crs <- function(point){

    lon <- st_coordinates(point)[1, 1]
    lat <- st_coordinates(point)[1, 2]

    zone_number <- floor((lon + 180) / 6) + 1
    zone_hemisphere <- ifelse(lat >= 0, 'N', 'S')

    zone <- paste0(zone_number, zone_hemisphere)
    crs <- paste0("EPSG:", ifelse(grepl('N', zone), 32600, 32700) + zone_number)

    return(crs)
}

# site_row = site_data[1, ]; lat = site_row$latitude; long = site_row$longitude; crs=4326; site_code=site_row$site_code
delineate_watershed_apriori <- function(lat,
                                        long,
                                        crs,
                                        site_code,
                                        snap_dist = NULL,
                                        snap_method = NULL,
                                        dem_resolution = NULL,
                                        flat_increment = NULL,
                                        breach_method = 'basic',
                                        burn_streams = FALSE,
                                        buffer_radius = NULL,
                                        scratch_dir = tempdir(),
                                        dev_machine_status = 'n00b',
                                        verbose = FALSE){

    #lat: numeric representing latitude in decimal degrees
    #   (negative indicates southern hemisphere)
    #long: numeric representing longitude in decimal degrees
    #   (negative indicates west of prime meridian)
    #crs: numeric representing the coordinate reference system (e.g. WSG84)
    #buffer_radius: integer. the width (m) of the buffer around the site location.
    #   a DEM will be acquired that covers at least the full area of the buffer.
    #snap_dist: integer. the distance (m) around the recorded site location
    #   to search for a flow path.
    #snap_method: character. either "standard", which snaps the site location
    #   to the cell within snap_dist that has the highest flow value, or
    #   "jenson", which snaps to the nearest flow path, regardless of flow.
    #dem_resolution: optional integer 1-14. the granularity of the DEM that is used for
    #   delineation. this argument is passed directly to the z parameter of
    #   elevatr::get_elev_raster. 1 is low resolution; 14 is high. If NULL,
    #   this is determined automatically.
    #flat_increment: float or NULL. Passed to
    #   whitebox::wbt_breach_depressions_least_cost
    #   or whitebox::wbt_breach_depressions, depending on the value
    #   of breach_method (see next).
    #breach_method: string. Either 'basic', which invokes whitebox::wbt_breach_depressions,
    #   or 'lc', which invokes whitebox::wbt_breach_depressions_least_cost
    #burn_streams: logical. if TRUE, both whitebox::wbt_burn_streams_at_roads
    #   and whitebox::wbt_fill_burn are called on the DEM, using road and stream
    #   layers from OpenStreetMap.
    #scratch_dir: the directory where intermediate files will be dumped. This
    #   is a randomly generated temporary directory if not specified.
    #dev_machine_status: either '1337', indicating that your machine has >= 16 GB
    #   RAM, or 'n00b', indicating < 16 GB RAM. DEM resolution is chosen accordingly
    #verbose: logical. determines the amount of informative messaging during run

    #returns the location of candidate watershed boundary files

    # tmp <- tempdir()
    # tmp <- str_replace_all(tmp, '\\\\', '/')

    if(! is.null(dem_resolution) && ! is.numeric(dem_resolution)){
        stop('dem_resolution must be a numeric integer or NULL')
    }
    if(! is.null(flat_increment) && ! is.numeric(flat_increment)){
        stop('flat_increment must be numeric or NULL')
    }
    if(! is.null(snap_dist) && ! is.numeric(snap_dist)){
        stop('snap_dist must be numeric or NULL')
    }
    if(! is.null(buffer_radius) && ! is.numeric(buffer_radius)){
        stop('buffer_radius must be numeric or NULL')
    }
    if(! is.null(snap_method) && ! snap_method %in% c('jenson', 'standard')){
        stop('snap_dist must be "jenson", "standard", or NULL')
    }
    if(! breach_method %in% c('lc', 'basic')) stop('breach_method must be "basic" or "lc"')
    if(! is.logical(burn_streams)) stop('burn_streams must be logical')

    inspection_dir <- glue(scratch_dir, '/INSPECT_THESE')
    point_dir <- glue(scratch_dir, '/POINT')
    dem_f <- glue(scratch_dir, '/dem.tif')
    point_f <- glue(scratch_dir, '/point.shp')
    streams_f <- glue(scratch_dir, '/streams.shp')
    roads_f <- glue(scratch_dir, '/roads.shp')
    d8_f <- glue(scratch_dir, '/d8_pntr.tif')
    flow_f <- glue(scratch_dir, '/flow.tif')

    dir.create(path = inspection_dir,
               showWarnings = FALSE)

    old_files <- list.files(inspection_dir)

    if(length(old_files) > 0){
        file.remove(file.path(inspection_dir, old_files))
    }

    proj <- choose_projection(lat = lat,
                              long = long)

    site <- tibble(x = lat,
                   y = long) %>%
        sf::st_as_sf(coords = c("y", "x"),
                     crs = crs) %>%
        sf::st_transform(proj)
    # sf::st_transform(4326) #WGS 84 (would be nice to do this unprojected)

    #prepare for delineation loops
    if(is.null(buffer_radius)) buffer_radius <- 1000
    dem_coverage_insufficient <- FALSE
    while_loop_begin <- TRUE

    #snap site to flowlines 3 different ways. delineate watershed boundaries (wb)
    #for each unique snap. if the delineations get cut off, get more elevation data
    #and try again

    while(while_loop_begin || dem_coverage_insufficient){

        while_loop_begin <- FALSE

        if(is.null(dem_resolution)){
            # dem_resolution <- choose_dem_resolution(
            #     dev_machine_status = dev_machine_status,
            #     buffer_radius = buffer_radius)
            dem_resolution <- 9
        }

        if(verbose){

            if(is.null(flat_increment)){
                fi <- 'auto'
            } else {
                fi <- as.character(flat_increment)
            }

            if(breach_method == 'lc') breach_method <- 'lc (jk, temporarily "basic")'
            print(glue('Delineation specs for this attempt:\n',
                       '\tsite_code: {st}; ',
                       'dem_resolution: {dr}; flat_increment: {fi}\n',
                       '\tbreach_method: {bm}; burn_streams: {bs}\n',
                       '\tbuffer_radius: {br}; snap_method: {smt}\n',
                       '\tsnap_dist: {sdt}',
                       st = site_code,
                       dr = dem_resolution,
                       fi = fi,
                       bm = breach_method,
                       bs = as.character(burn_streams),
                       br = buffer_radius,
                       smt = ifelse(is.null(snap_method),
                                    'auto',
                                    as.character(snap_method)),
                       sdt = ifelse(is.null(snap_dist),
                                    'auto',
                                    as.character(snap_dist)),
                       .trim = FALSE))
        }

        site_buf <- sf::st_buffer(x = st_transform(site, get_utm_crs(site)),
                                  dist = buffer_radius) %>%
            st_transform(st_crs(site))

        dem <- expo_backoff(
            expr = {
                elevatr::get_elev_raster(locations = site_buf,
                                         z = dem_resolution,
                                         verbose = FALSE,
                                         override_size_check = TRUE)
            },
            max_attempts = 5
        )

        # terra::writeRaster(x = dem,
        terra::writeRaster(x = dem,
                            filename = dem_f,
                            overwrite = TRUE)

        #loses projection?
        sf::st_write(obj = site,
                     dsn = point_f,
                     delete_layer = TRUE,
                     quiet = TRUE)

        if(burn_streams){
            get_osm_roads(extent_raster = dem,
                          outfile = roads_f)
            get_osm_streams(extent_raster = dem,
                            outfile = streams_f)
        }

        whitebox::wbt_fill_single_cell_pits(dem = dem_f,
                                            output = dem_f) %>% invisible()

        if(breach_method == 'basic'){

            whitebox::wbt_breach_depressions(
                dem = dem_f,
                output = dem_f,
                flat_increment = flat_increment) %>% invisible()

        } else if(breach_method == 'lc'){

            whitebox::wbt_breach_depressions_least_cost(
                dem = dem_f,
                output = dem_f,
                dist = 10000, #maximum trench length
                fill = TRUE,
                flat_increment = flat_increment) %>% invisible()
        }
        #also see wbt_fill_depressions for when there are open pit mines

        if(burn_streams){

            #the secret is that BOTH of these burns can work in tandem!
            whitebox::wbt_burn_streams_at_roads(dem = dem_f,
                                                streams = streams_f,
                                                roads = roads_f,
                                                output = dem_f,
                                                width = 50) %>% invisible()
            whitebox::wbt_fill_burn(dem = dem_f,
                                    streams = streams_f,
                                    output = dem_f) %>% invisible()
        }

        whitebox::wbt_d8_pointer(dem = dem_f,
                                 output = d8_f) %>% invisible()

        whitebox::wbt_d8_flow_accumulation(input = dem_f,
                                           output = flow_f,
                                           out_type = 'catchment area') %>% invisible()

        if(! is.null(snap_method)){
            snap_method_func <- ifelse(snap_method == 'standard',
                                       whitebox::wbt_snap_pour_points,
                                       whitebox::wbt_jenson_snap_pour_points)
        }

        if(is.null(snap_dist) && is.null(snap_method)){

            snap1_f <- glue(scratch_dir, '/snap1_jenson_dist150.shp')
            whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                                  streams = flow_f,
                                                  output = snap1_f,
                                                  snap_dist = 150) %>% invisible()
            snap2_f <- glue(scratch_dir, '/snap2_standard_dist50.shp')
            whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                           flow_accum = flow_f,
                                           output = snap2_f,
                                           snap_dist = 50) %>% invisible()
            snap3_f <- glue(scratch_dir, '/snap3_standard_dist150.shp')
            whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                           flow_accum = flow_f,
                                           output = snap3_f,
                                           snap_dist = 150) %>% invisible()

            #the site has been snapped 3 different ways. identify unique snap locations.
            snap1 <- sf::st_read(snap1_f, quiet = TRUE)
            snap2 <- sf::st_read(snap2_f, quiet = TRUE)
            snap3 <- sf::st_read(snap3_f, quiet = TRUE)
            unique_snaps_f <- snap1_f
            if(! identical(snap1, snap2)) unique_snaps_f <- c(unique_snaps_f, snap2_f)
            if(! identical(snap1, snap3)) unique_snaps_f <- c(unique_snaps_f, snap3_f)

        } else if(is.null(snap_dist)){

            snap1_f <- glue('{scrd}/snap1_{smet}_dist150.shp',
                            scrd = scratch_dir,
                            smet = snap_method)

            snap2_f <- glue('{scrd}/snap2_{smet}_dist50.shp',
                            scrd = scratch_dir,
                            smet = snap_method)

            if(snap_method == 'standard'){

                whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                               flow_accum = flow_f,
                                               output = snap1_f,
                                               snap_dist = 150)
                whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                               flow_accum = flow_f,
                                               output = snap2_f,
                                               snap_dist = 50)
            } else {

                whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                                      streams = flow_f,
                                                      output = snap1_f,
                                                      snap_dist = 150)
                whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                                      streams = flow_f,
                                                      output = snap1_f,
                                                      snap_dist = 50)
            }

            #the site has been snapped 2 different ways. identify unique snap locations.
            snap1 <- sf::st_read(snap1_f, quiet = TRUE)
            snap2 <- sf::st_read(snap2_f, quiet = TRUE)
            unique_snaps_f <- snap1_f
            if(! identical(snap1, snap2)) unique_snaps_f <- c(unique_snaps_f, snap2_f)

        } else if(is.null(snap_method)){

            snap1_f <- glue('{scrd}/snap1_jenson_dist{sdst}.shp',
                            scrd = scratch_dir,
                            sdst = snap_dist)

            whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                                  streams = flow_f,
                                                  output = snap1_f,
                                                  snap_dist = snap_dist) %>% invisible()

            snap2_f <- glue('{scrd}/snap2_standard_dist{sdst}.shp',
                            scrd = scratch_dir,
                            sdst = snap_dist)

            whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                           flow_accum = flow_f,
                                           output = snap2_f,
                                           snap_dist = snap_dist) %>% invisible()

            #the site has been snapped 2 different ways. identify unique snap locations.
            snap1 <- sf::st_read(snap1_f, quiet = TRUE)
            snap2 <- sf::st_read(snap2_f, quiet = TRUE)
            unique_snaps_f <- snap1_f
            if(! identical(snap1, snap2)) unique_snaps_f <- c(unique_snaps_f, snap2_f)

        } else {

            snap1_f <- glue('{scrd}/snap1_{smet}_dist{sdst}.shp',
                            scrd = scratch_dir,
                            smet = snap_method,
                            sdst = snap_dist)

            snap_arglist <- list(pour_pts = point_f,
                                 output = snap1_f,
                                 snap_dist = snap_dist)

            if(snap_method == 'standard'){
                whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                               flow_accum = flow_f,
                                               output = snap1_f,
                                               snap_dist = snap_dist)
                # snap_arglist$flow_accum = flow_f
            } else {
                whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                                      streams = flow_f,
                                                      output = snap1_f,
                                                      snap_dist = snap_dist)
                # snap_arglist$streams = flow_f
            }

            # do.call(wbt_snap_pour_points,
            #         args = snap_arglist) %>% invisible()

            #the site has been snapped only one way
            unique_snaps_f <- c(snap1_f)
        }

        #good for experimenting with snap specs:
        # delineate_watershed_test2(scratch_dir, point_f, flow_f,
        #                           d8_f, 'standard', 1000)

        #delineate each unique location
        for(i in 1:length(unique_snaps_f)){

            rgx <- str_match(unique_snaps_f[i],
                             '.*?_(standard|jenson)_dist([0-9]+)\\.shp$')
            snap_method_ <- rgx[, 2]
            snap_dist_ <- rgx[, 3]

            wb_f <- glue('{path}/wb{n}_buffer{b}_{typ}_dist{dst}.tif',
                         path = scratch_dir,
                         n = i,
                         b = buffer_radius,
                         typ = snap_method_,
                         dst = snap_dist_)

            whitebox::wbt_watershed(d8_pntr = d8_f,
                                    pour_pts = unique_snaps_f[i],
                                    output = wb_f) %>% invisible()

            wb <- terra::rast(wb_f)

            #check how many wb cells coincide with the edge of the DEM.
            #If > 0.1% or > 5, broader DEM needed
            smry <- raster_intersection_summary(wb = wb,
                                                dem = dem)

            if(verbose){
                print(glue('site buffer radius: {br}; pour point snap: {sn}/{tot}; ',
                           'n intersecting border cells: {ni}; pct intersect: {pct}',
                           br = buffer_radius,
                           sn = i,
                           tot = length(unique_snaps_f),
                           ni = round(smry$n_intersections, 2),
                           pct = round(smry$pct_wb_cells_intersect, 2)))
            }

            if(smry$pct_wb_cells_intersect > 0.1 || smry$n_intersections > 5){

                buffer_radius_new <- buffer_radius * 10
                dem_coverage_insufficient <- TRUE
                print(glue('Hit DEM edge. Incrementing buffer.'))
                break

            } else {

                dem_coverage_insufficient <- FALSE
                buffer_radius_new <- buffer_radius

                #write and record temp files for the technician to visually inspect
                wb_sf <- wb %>%
                    terra::as.polygons() %>%
                    sf::st_as_sf() %>%
                    sf::st_buffer(dist = 0.1) %>%
                    sf::st_union() %>%
                    sf::st_as_sf() %>%
                    fill_sf_holes() %>%
                    sf::st_transform(4326)

                ws_area_ha <- as.numeric(sf::st_area(wb_sf)) / 10000

                wb_sf <- wb_sf %>%
                    mutate(site_code = !!site_code) %>%
                    mutate(area = !!ws_area_ha)

                if(is.null(flat_increment)){
                    flt_incrmt <- 'null'
                } else {
                    flt_incrmt <- as.character(flat_increment)
                }

                wb_sf_f <- glue('{path}/wb{n}_BUF{b}{typ}DIST{dst}RES{res}',
                                'INC{inc}BREACH{brc}BURN{brn}.shp',
                                path = inspection_dir,
                                n = i,
                                b = sprintf('%d', buffer_radius),
                                typ = snap_method_,
                                dst = snap_dist_,
                                res = dem_resolution,
                                inc = flt_incrmt,
                                brc = breach_method,
                                brn = as.character(burn_streams))

                sw(sf::st_write(obj = wb_sf,
                                dsn = wb_sf_f,
                                delete_dsn = TRUE,
                                quiet = TRUE))
            }
        }

        buffer_radius <- buffer_radius_new
    } #end while loop

    if(verbose){
        message(glue('Candidate delineations are in: ', inspection_dir))
    }

    delin_out <- list(inspection_dir = inspection_dir,
                      buffer_radius = buffer_radius)

    return(delin_out)
}

getfun <- function(x){

    if(length(grep('::', x)) > 0) {
        parts <- strsplit(x, '::')[[1]]
        getExportedValue(parts[1], parts[2])
    } else {
        x
    }
}

delineate_watershed_by_specification <- function(lat,
                                                 long,
                                                 crs,
                                                 buffer_radius,
                                                 snap_dist,
                                                 snap_method,
                                                 dem_resolution,
                                                 flat_increment,
                                                 breach_method,
                                                 burn_streams,
                                                 write_dir,
                                                 verbose = FALSE){

    #lat: numeric representing latitude in decimal degrees
    #   (negative indicates southern hemisphere)
    #long: numeric representing longitude in decimal degrees
    #   (negative indicates west of prime meridian)
    #crs: numeric representing the coordinate reference system (e.g. WSG84)
    #buffer_radius: integer. the width (m) of the buffer around the site location.
    #   a DEM will be acquired that covers at least the full area of the buffer.
    #snap_dist: integer. the distance (m) around the recorded site location
    #   to search for a flow path.
    #snap_method: character. either "standard", which snaps the site location
    #   to the cell within snap_dist that has the highest flow value, or
    #   "jenson", which snaps to the nearest flow path, regardless of flow.
    #dem_resolution: integer 1-14. the granularity of the DEM that is used for
    #   delineation. this argument is passed directly to the z parameter of
    #   elevatr::get_elev_raster. 1 is low resolution; 14 is high.
    #flat_increment: float or NULL. Passed to wbt_breach_depressions_least_cost
    #   or wbt_breach_depressions, depending on the value of breach_method (see next).
    #breach_method: string. Either 'basic', which invokes whitebox::wbt_breach_depressions,
    #   or 'lc', which invokes whitebox::wbt_breach_depressions_least_cost
    #burn_streams: logical. if TRUE, both whitebox::wbt_burn_streams_at_roads
    #   and whitebox::wbt_fill_burn are called on the DEM, using road and stream
    #   layers from OpenStreetMap.
    #write_dir: character. the directory to write shapefile watershed boundary to

    #returns the location of candidate watershed boundary files

    require(whitebox) #can't do e.g. whitebox::func in do.call

    if(! is.null(dem_resolution) && ! is.numeric(dem_resolution)){
        stop('dem_resolution must be a numeric integer or NULL')
    }
    if(! is.null(flat_increment) && ! is.numeric(flat_increment)){
        stop('flat_increment must be numeric or NULL')
    }
    if(! breach_method %in% c('lc', 'basic')) stop('breach_method must be "basic" or "lc"')
    if(! is.logical(burn_streams)) stop('burn_streams must be logical')

    tmp <- tempdir()
    inspection_dir <- glue(tmp, '/INSPECT_THESE')
    dem_f <- glue(tmp, '/dem.tif')
    point_f <- glue(tmp, '/point.shp')
    streams_f <- glue(tmp, '/streams.shp')
    roads_f <- glue(tmp, '/roads.shp')
    d8_f <- glue(tmp, '/d8_pntr.tif')
    flow_f <- glue(tmp, '/flow.tif')
    snap_f <- glue(tmp, '/snap.shp')
    wb_f <- glue(tmp, '/wb.tif')

    dir.create(path = inspection_dir,
               showWarnings = FALSE)

    proj <- choose_projection(lat = lat,
                              long = long)

    site <- tibble(x = lat,
                   y = long) %>%
        sf::st_as_sf(coords = c("y", "x"),
                     crs = crs) %>%
        sf::st_transform(proj)

    # site_buf <- sf::st_buffer(x = site,
    #                           dist = buffer_radius)
    site_buf <- sf::st_buffer(x = st_transform(site, get_utm_crs(site)),
                              dist = buffer_radius) %>%
        st_transform(st_crs(site))

    dem <- expo_backoff(
        expr = {
            elevatr::get_elev_raster(locations = site_buf,
                                     z = dem_resolution,
                                     verbose = FALSE,
                                     override_size_check = TRUE)
        },
        max_attempts = 5
    )

    terra::writeRaster(x = dem,
                        filename = dem_f,
                        overwrite = TRUE)
    # terra::rast(dem) %>%
    #     terra::writeRaster(dem_f,
    # overwrite = TRUE)
# qq <- terra::rast(dem_f)
# terra::plot(qq)

# qq <- raster::raster(dem_f)
# raster::plot(qq)
        # raster::rasterToPolygons() %>%
        # sf::st_as_sf() %>%
        # sf::st_buffer(dist = 0.1) %>%
        # sf::st_union() %>%
        # sf::st_as_sf() %>% #again? ugh.
        # sf::st_transform(4326) #EPSG for WGS84

    #loses projection
    sf::st_write(obj = site,
                 dsn = point_f,
                 delete_layer = TRUE,
                 quiet = TRUE)

    if(burn_streams){
        get_osm_roads(extent_raster = dem,
                      outfile = roads_f)
        get_osm_streams(extent_raster = dem,
                        outfile = streams_f)
    }

    whitebox::wbt_fill_single_cell_pits(dem = dem_f,
                                        output = dem_f) %>% invisible()

    if(breach_method == 'basic'){

        whitebox::wbt_breach_depressions(
            dem = dem_f,
            output = dem_f,
            flat_increment = flat_increment) %>% invisible()

    } else if(breach_method == 'lc'){

        message('lc method temporarily disabled. generates inconsistent output. using basic instead.')
        # whitebox::wbt_breach_depressions_least_cost(
        #     dem = dem_f,
        #     output = dem_f,
        #     dist = 10000, #maximum trench length
        #     fill = TRUE,
        #     flat_increment = flat_increment) %>% invisible()
        whitebox::wbt_breach_depressions(
            dem = dem_f,
            output = dem_f,
            flat_increment = flat_increment) %>% invisible()
    }
    #also see wbt_fill_depressions for when there are open pit mines

    # qq <- raster::raster(dem_f)
    # yyy=c(raster::values(qq))
    # xxx=c(raster::values(qq))

    if(burn_streams){

        #the secret is that BOTH of these burns can work in tandem!
        whitebox::wbt_burn_streams_at_roads(dem = dem_f,
                                            streams = streams_f,
                                            roads = roads_f,
                                            output = dem_f,
                                            width = 50) %>% invisible()
        whitebox::wbt_fill_burn(dem = dem_f,
                                streams = streams_f,
                                output = dem_f) %>% invisible()
    }

    whitebox::wbt_d8_pointer(dem = dem_f,
                             output = d8_f) %>% invisible()

    whitebox::wbt_d8_flow_accumulation(input = dem_f,
                                       output = flow_f,
                                       out_type = 'catchment area') %>% invisible()

    #call the appropriate snapping function from whitebox
    args <- list(pour_pts = point_f,
                 output = snap_f,
                 snap_dist = snap_dist)

    if(snap_method == 'standard'){
        args$flow_accum <- flow_f
        desired_func <- 'wbt_snap_pour_points'
    } else if(snap_method == 'jenson'){
        args$streams <- flow_f
        desired_func <- 'wbt_jenson_snap_pour_points'
    } else {
        stop('snap_method must be "standard" or "jenson"')
    }

    do.call(desired_func, args)

    #delineate
    whitebox::wbt_watershed(d8_pntr = d8_f,
                            pour_pts = snap_f,
                            output = wb_f) %>% invisible()

    wb_sf <- terra::rast(wb_f) %>%
        terra::as.polygons() %>%
        sf::st_as_sf() %>%
        sf::st_buffer(dist = 0.1) %>%
        sf::st_union() %>%
        sf::st_as_sf() %>%
        fill_sf_holes() %>%
        sf::st_transform(crs = 4326)

    site_code <- str_match(write_dir, '.+?/([^/]+)$')[, 2]

    ws_area_ha <- as.numeric(sf::st_area(wb_sf)) / 10000

    wb_sf <- wb_sf %>%
        mutate(site_code = !!site_code) %>%
        mutate(area = !!ws_area_ha)

    dir.create(write_dir,
               showWarnings = FALSE)

    sw(sf::st_write(obj = wb_sf,
                    dsn = glue('{d}/{s}.shp',
                               d = write_dir,
                               s = site_code),
                    delete_dsn = TRUE,
                    quiet = TRUE))

    message(glue('Watershed boundary written to ',
                 write_dir))
}

get_derive_ingredient <- function(network,
                                  domain,
                                  prodname,
                                  ignore_derprod = FALSE,
                                  ignore_derprod900 = TRUE,
                                  accept_multiple = FALSE){

    #get prodname_ms's by prodname, for specifying derive kernels.

    #ignore_derprod: logical. if TRUE, don't consider any product with an
    #   msXXX prodcode. In other words, return a munged prodname_ms. If FALSE,
    #   derived products take precedence over munged products.
    #ignore_derprod900: logical. if TRUE, don't consider any product with an
    #   ms9XX prodcode.
    #accept_multiple: logical. should more than one ingredient be returned?

    prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain))) %>%
        filter( (! is.na(munge_status) & munge_status == 'ready') |
                    (! is.na(derive_status) & derive_status %in% c('ready', 'linked')) |
                    (prodname == 'ws_boundary' & ! is.na(notes) & notes == 'automated entry') )

    if(ignore_derprod){

        prodname_ms <- prods %>%
            filter(
                !  grepl(pattern = '^ms[0-9]{3}$',
                         x = prodcode),
                prodname == !!prodname) %>%
            mutate(prodname_ms = paste(prodname,
                                       prodcode,
                                       sep = '__')) %>%
            pull(prodname_ms)

    } else {

        prodname_ms <- prods %>%
            filter(
                # grepl(pattern = '^ms[0-9]{3}$',
                #       x = prodcode),
                prodname == !!prodname) %>%
            mutate(prodname_ms = paste(prodname,
                                       prodcode,
                                       sep = '__')) %>%
            pull(prodname_ms)

        if(ignore_derprod900){
            prodname_ms <- prodname_ms[! grepl(pattern = '__ms9[0-9]{2}$',
                                               x = prodname_ms)]
        }

        #if there are multiple derive kernels, we're looking for the one that is
        #   a precursor to the other, so grab the one with the lower msXXX ID.
        #   UNLESS it's ws_boundary. then we want the one that's fully processed,
        #   so higher msXXX ID.
        if(length(prodname_ms) > 1){

            if(all(! is_derived_product(prodname_ms))){
                stop('pretty sure we need a combining derive kernel for:\n\t',
                     paste(prodname_ms, collapse = ', '))
            }

            #ignore munge kernels
            prodname_ms <- prodname_ms[grepl(pattern = 'ms[0-9]{3}$',
                                             x = prodname_ms,
                                             perl = TRUE)]

            combinekernel_inds <- substr(prodname_ms,
                                         nchar(prodname_ms) - 2,
                                         nchar(prodname_ms)) %>%
                as.numeric()

            if(prodname == 'ws_boundary'){
                combinekernel_ind <- which.max(combinekernel_inds)
            } else {
                combinekernel_ind <- which.min(combinekernel_inds)
            }

            prodname_ms <- prodname_ms[combinekernel_ind]
        }
    }

    if(length(prodname_ms) > 1 && ! accept_multiple){
        stop('could not resolve multiple products with same prodname')
    }

    return(prodname_ms)
}

ms_derive <- function(network = domain,
                      domain,
                      prodname_filter = NULL,
                      precip_pchem_pflux_skip_existing = FALSE){

    #categorize munged products. some are complete after munging, so they
    #   get hardlinked. some need to be compiled into canonical form (e.g.
    #   water_temp, spcond, gases -> stream_chemistry) by a derive
    #   kernel. and then of course there are products that consistently
    #   require actual derivation, like precip_flux_inst from precipitation
    #   and pchem (note that both of these will usually be replaced by the
    #   new precip_pchem_pflux kernels)

    if(! exists('held_data')){
        held_data <<- get_data_tracker(network = network,
                                       domain = domain)
    }

    #used by precip_pchem_pflux_idw
    if(precip_pchem_pflux_skip_existing){
        precip_pchem_pflux_skip_existing <<- TRUE
    } else {
        precip_pchem_pflux_skip_existing <<- FALSE
    }

    prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain)))

    #determine various categories governing how products should be handled
    has_ms_prodcode <- grepl('^ms[0-9]{3}$',
                             prods$prodcode,
                             perl = TRUE)

    is_being_munged <- ! is.na(prods$munge_status) & prods$munge_status == 'ready'

    is_self_precursor <- mapply(function(x, y){
                                    precursors <- strsplit(as.character(y),
                                                           '\\|\\|')[[1]]
                                    x %in% prodname_from_prodname_ms(precursors)
                                },
                                x = prods$prodname,
                                y = prods$precursor_of,
                                USE.NAMES = FALSE)

    is_a_link <- ! is.na(prods$derive_status) &
        prods$derive_status == 'linked'

    created_links <- prods$prodname[is_a_link]

    is_already_linked <- ! is_a_link &
        prods$prodname %in% created_links &
        prods$munge_status == 'ready'

    is_automated_entry <- ! is.na(prods$notes) &
        prods$notes == 'automated entry'

    #determine which active prods need to be linked (linkprods)
    is_linkprod <- (! is.na(prods$derive_status) &
                        prods$derive_status == 'linked') |
        (prods$prodname %in% canonical_derprods |
             grepl('CUSTOM', prods$prodname)) &
             ( ! has_ms_prodcode &
             is_being_munged &
             ! is_self_precursor)

    #this patch catches the case of precip/stream gauges being generated
    #by a derive kernel (which shouldn't be linked from munge)
    precip_gauges_derived <- any(grepl('precip_gauge_locations', prods$prodname) &
                                     has_ms_prodcode)
    stream_gauges_derived <- any(grepl('stream_gauge_locations', prods$prodname) &
                                     has_ms_prodcode)

    if(precip_gauges_derived){
       not_rly_linkprod <-  which(grepl('precip_gauge_locations',
                    prods$prodname) & ! has_ms_prodcode)
       is_linkprod[not_rly_linkprod] <- FALSE
    }

    if(stream_gauges_derived){
       not_rly_linkprod <-  which(grepl('stream_gauge_locations',
                    prods$prodname) & ! has_ms_prodcode)
       is_linkprod[not_rly_linkprod] <- FALSE
    }

    #re-link any already linked prods
    for(i in which(is_already_linked)){

        linked_prodcode <- get_derive_ingredient(network = network,
                                                 domain = domain,
                                                 prodname = prods$prodname[i]) %>%
                               prodcode_from_prodname_ms()

        prodname_ms_source <- paste(prods$prodname[i],
                                    prods$prodcode[i],
                                    sep = '__')

        qq <- prodname_from_prodname_ms(prodname_ms_source)
        if(nrow(filter(prods, !!is_being_munged, prodname == qq)) > 1){
            stop("is this a problem? i think we either need a combining derive kernel for ",
                 qq, ' or there is a derelict "linked" status in products.csv')
        }

        tryCatch({
            create_derived_links(network = network,
                                 domain = domain,
                                 prodname_ms = prodname_ms_source,
                                 new_prodcode = linked_prodcode)
        },
        error = function(e){
            logwarn(glue('Failed to link {p} to derive/',
                         p = prodname_ms_source),
                         logger = logger_module)
            }
        )

        write_metadata_d_linkprod(network = network,
                                  domain = domain,
                                  prodname_ms_mr = prodname_ms_source,
                                  prodname_ms_d = paste0(prods$prodname[i],
                                                         '__',
                                                         linked_prodcode))
    }

    #link any new linkprods and create new product entries
    prodcodes_num <- as.numeric(substr(
        prods$prodcode[grepl('^ms[0-7][0-9]{2}$',
                             prods$prodcode)],
        start = 3,
        stop = 5))

    code_800_or_900s <- grep(pattern = '^ms[8-9][0-9]{2}$',
                             x = prods$prodcode[has_ms_prodcode &
                                                    ! is_automated_entry],
                             value = TRUE)

    if(length(code_800_or_900s)){
        stop(glue('ms8XX and ms9XX are reserved prodcodes (generated ',
                  'automatically). Please rename: ',
                  paste(code_800_or_900s, collapse = ', ')))
    }

    if(any(is_linkprod)){

        new_prodcodes_num <- seq(max(prodcodes_num) + 1,
                                 max(prodcodes_num) + sum(is_linkprod))

        new_prodcodes <- stringr::str_pad(string = new_prodcodes_num,
                                          width = 3,
                                          side = 'left',
                                          pad = 0) %>%
            {paste0('ms', .)}
    }

    new_linkprod_inds <- which(is_linkprod &
                                   ! is_already_linked &
                                   ! is_a_link)

    for(i in seq_along(new_linkprod_inds)){

        prodname <- prods$prodname[new_linkprod_inds[i]]

        prodname_ms_source <- paste(prodname,
                                    prods$prodcode[new_linkprod_inds[i]],
                                    sep = '__')

        if(prodname_ms_source == 'ws_boundary__ms000'){
            next
        }

        qq <- prodname_from_prodname_ms(prodname_ms_source)
        if(nrow(filter(prods, !!is_being_munged, prodname == qq)) > 1){
            stop("is this a problem? i think we need a combining derive kernel for ", qq)
        }

        newcode <- new_prodcodes[i]

        thisenv = environment() #DELETE THIS CHECK WHEN FINISHED
        bypass_append = FALSE
        tryCatch({
            create_derived_links(network = network,
                                 domain = domain,
                                 prodname_ms = prodname_ms_source,
                                 new_prodcode = newcode)

        }, error = function(e){
            logwarn(glue('TEMPORARY BYPASS of normal error checking until we ',
                         'incorporate flux products from data sources'))
            #UNCOMMENT THE BELOW WHEN THE ABOVE IS NO LONGER NEEDED
            # stop(glue('{p} not found. There must be munge errors in need of fixing.',
            #           p = prodname_ms_source))
            #ALSO delete entries with #DELETE THIS
            assign('bypass_append', TRUE, envir=thisenv) #DELETE THIS
        })

        if(! bypass_append){  #MAKE THIS UNCONDITIONAL
        append_to_productfile(
            network = network,
            domain = domain,
            prodcode = newcode,
            prodname = prodname,
            derive_status = 'linked',
            notes = 'automated entry')
        }

        write_metadata_d_linkprod(network = network,
                                  domain = domain,
                                  prodname_ms_mr = prodname_ms_source,
                                  prodname_ms_d = paste0(prodname,
                                                         '__',
                                                         newcode))
    }

    waiting_retrv_kerns <- prods %>%
        filter(! is.na(retrieve_status) & retrieve_status != 'ready') %>%
        mutate(prodname_ms = paste(prodname, prodcode, sep='_')) %>%
        pull(prodname_ms)

    waiting_mng_kerns <- prods %>%
        filter(! is.na(munge_status) & munge_status != 'ready') %>%
        mutate(prodname_ms = paste(prodname, prodcode, sep='_')) %>%
        pull(prodname_ms)

    if(length(waiting_retrv_kerns)){
        logwarn(msg = glue('Some retrieve kernels are not ready: {wr}',
                           wr = paste(waiting_retrv_kerns,
                                      collapse = ', ')),
                logger = logger_module)
    }

    if(length(waiting_mng_kerns)){
        logwarn(msg = glue('Some munge kernels are not ready: {wr}',
                           wr = paste(waiting_mng_kerns,
                                      collapse = ', ')),
                logger = logger_module)
    }

    #compile any compprods and derive derprods (run all code in derive.R).
    #note: get_product_info() knows it must arrange derive products with
    #   non-canonicals first and CUSTOM products last
    source(glue('src/{n}/{d}/derive.R',
                n = network,
                d = domain),
           local = TRUE)

    #link all derived products to the data portal directory
    create_portal_links(network = network,
                        domain = domain)
    #for removing derelicts from portal/data
    #find portal/data ! -path './general/*' ! -path '*/documentation/*' ! -path '*flux_inst_scaled*' -type f -links 1 -delete
}

import_ancestor_env <- function(pos = 1){

    #populates the calling environment with variables from a parent or higher
    #   ancestor environment

    #pos: integer between 1 and the depth of the callstack - 1. 1 represents
    #   the immediate parent of the function in which import_ancestor_env
    #   is called.

    import_env <- parent.frame(n = pos + 1)
    varnames <- ls(name = import_env)
    vars <- mget(varnames,
                 envir = import_env)

    for(i in 1:length(varnames)){
        assign(varnames[i],
               value = vars[[i]],
               pos = pos)
    }
}

append_to_productfile <- function(network,
                                  domain,
                                  prodcode,
                                  prodname,
                                  # type, #obsolete
                                  retrieve_status,
                                  munge_status,
                                  derive_status,
                                  precursor_of,
                                  notes,
                                  components){

    #add a line to the products.csv file for a particular network and domain.
    #any fields omitted will be populated with NA.

    #if a prodname_ms is already in products.csv, this will terminate before
    #appending.

    import_ancestor_env()
    passed_args <- as.list(match.call())
    arg_nms <- names(passed_args)
    passed_args <- passed_args[! arg_nms %in% c('', 'network', 'domain')]
    passed_args <- lapply(passed_args,
                          function(x) eval(x))

    args_legit <- sapply(passed_args,
           function(x) length(x) == 1 && is.character(x))

    if(any(! args_legit)){
        stop('all arguments must be strings')
    }

    prodfile <- glue('src/{n}/{d}/products.csv',
                     n = network,
                     d = domain)

    prods <- sm(read_csv(prodfile)) %>%
        mutate(prodcode = as.character(prodcode))

    new_row <- unlist(passed_args)

    new_row <- new_row[names(new_row) %in% colnames(prods)]

    prods <- bind_rows(prods, new_row)

    new_row_is_duplicate <-
        duplicated(select(prods, prodname, prodcode))[nrow(prods)]

    if(new_row_is_duplicate){
        logging::logwarn(glue('New row would duplicate an existing row in ',
                              'products.csv. Not appending.'))
        return()
    }

    write_csv(x = prods,
              file = prodfile)
}

move_shapefiles <- function(shp_files, from_dir, to_dir, new_name_vec = NULL){

    #shp_files is a character vector of filenames with .shp extension
    #   (.shx, .prj, .dbf are handled internally and don't need to be listed)
    #from_dir and to_dir are strings representing the source and destination
    #   directories, respectively
    #new_name_vec is an optional character vector of new names for each shape file.
    #   these can end in ".shp", but don't need to

    if(any(! grepl('\\.shp$', shp_files))){
        stop('All components of shp_files must end in ".shp"')
    }

    if(length(shp_files) != length(new_name_vec)){
        stop('new_name_vec must have the same length as shp_files')
    }

    dir.create(to_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    for(i in 1:length(shp_files)){

        shapefile_base <- strsplit(shp_files[i], '\\.shp')[[1]]

        files_to_move <- list.files(path = from_dir,
                                    pattern = shapefile_base)

        extensions <- str_match(files_to_move,
                                paste0(shapefile_base, '(\\.[a-z]{3})'))[, 2]

        if(is.null(new_name_vec)){
            new_name_base <- rep(shapefile_base, length(files_to_move))
        } else {
            new_name_base <- strsplit(new_name_vec[i], '\\.shp$')[[1]]
            new_name_base <- rep(new_name_base, length(files_to_move))
        }

        tryCatch({

            #try to move the files (may fail if they are on different partitions)
            mapply(function(x, nm, ext) file.rename(from = paste(from_dir,
                                                                 x,
                                                                 sep = '/'),
                                                    to = glue('{td}/{n}{ex}',
                                                              td = to_dir,
                                                              n = nm,
                                                              ex = ext)),
                   x = files_to_move,
                   nm = new_name_base,
                   ext = extensions)

        }, warning = function(w){

            #if that fails, copy them and then delete them
            mapply(function(x, nm, ext) file.copy(from = paste(from_dir,
                                                               x,
                                                               sep = '/'),
                                                  to = glue('{td}/{n}{ex}',
                                                            td = to_dir,
                                                            n = nm,
                                                            ex = ext),
                                                  overwrite = TRUE),
                   x = files_to_move,
                   nm = new_name_base,
                   ext = extensions)

            lapply(paste(from_dir,
                         files_to_move,
                         sep = '/'),
                   unlink)
        })
    }

    #return()
}

get_response_enter <- function(msg,
                               response_from_file = NULL){

    #only returns if ENTER is pressed (or if anything is passed by response_from_file

    cat(msg)

    if(! is.null(response_from_file)){
        ch <- as.character(readLines(con = response_from_file, 1))
        rsps <- readLines(con = response_from_file)
        rsps <- rsps[2:length(rsps)]
        writeLines(rsps, con = response_from_file)
    } else {
        ch <- as.character(readLines(con = stdin(), 1))
    }

    return(invisible(NULL))
}

get_response_1char <- function(msg,
                               possible_chars,
                               subsequent_prompt = FALSE){

    #msg: character. a message that will be used to prompt the user
    #possible_chars: character vector of acceptable single-character responses
    #subsequent prompt: not to be set directly. This is handled by
    #   get_response_1char during recursion.

    if(subsequent_prompt){
        cat(paste('Please choose one of:',
                  paste(possible_chars,
                        collapse = ', '),
                  '\n> '))
    } else {
        cat(msg)
    }

    ch <- as.character(readLines(con = stdin(), 1))

    if(length(ch) == 1 && ch %in% possible_chars){
        return(ch)
    } else {
        get_response_1char(msg = msg,
                           possible_chars = possible_chars,
                           subsequent_prompt = TRUE)
    }
}

get_response_int <- function(msg,
                             min_val,
                             max_val,
                             subsequent_prompt = FALSE){

    #msg: character. a message that will be used to prompt the user
    #min_val: int. minimum allowable value, inclusive
    #max_val: int. maximum allowable value, inclusive
    #subsequent prompt: not to be set directly. This is handled by
    #   get_response_int during recursion.

    if(subsequent_prompt){
        cat(glue('Please choose an integer in the range [{minv}, {maxv}].',
                  minv = min_val,
                  maxv = max_val))
    } else {
        cat(msg)
    }

    nm <- as.numeric(as.character(readLines(con = stdin(), 1)))

    if(nm %% 1 == 0 && nm >= min_val && nm <= max_val){
        return(nm)
    } else {
        get_response_int(msg = msg,
                         min_val = min_val,
                         max_val = max_val,
                         subsequent_prompt = TRUE)
    }
}

get_response_mchar <- function(msg,
                               possible_resps,
                               allow_alphanumeric_response = TRUE,
                               subsequent_prompt = FALSE){

    #msg: character. a message that will be used to prompt the user
    #possible_resps: character vector. If length 1, each character in the response
    #   will be required to match a character in possible_resps, and the return
    #   value will be a character vector of each single-character tokens in the
    #   response. If
    #   length > 1, the response will be required to match an element of
    #   possible_resps exactly, and the response will be returned as-is.
    #allow_alphanumeric_response: logical. If FALSE, the response may not
    #   include both numerals and letters. Only applies when possible_resps
    #   has length 1.
    #subsequent prompt: not to be set directly. This is handled by
    #   get_response_mchar during recursion.

    split_by_character <- ifelse(length(possible_resps) == 1, TRUE, FALSE)

    if(subsequent_prompt){

        if(split_by_character){
            pr <- strsplit(possible_resps, split = '')[[1]]
        } else {
            pr <- possible_resps
        }

        cat(paste('Your options are:',
                  paste(pr,
                        collapse = ', '),
                  '\n> '))
    } else {
        cat(msg)
    }

    chs <- as.character(readLines(con = stdin(), 1))

    if(! allow_alphanumeric_response &&
       split_by_character &&
       grepl('[0-9]', chs) &&
       grepl('[a-zA-Z]', chs)){

        cat('Response may not include both letters and numbers.\n> ')
        resp <- get_response_mchar(
            msg = msg,
            possible_resps = possible_resps,
            allow_alphanumeric_response = allow_alphanumeric_response,
            subsequent_prompt = FALSE)

        return(resp)
    }

    if(length(chs)){
        if(split_by_character){

            if(length(possible_resps) != 1){
                stop('possible_resps must be length 1 if split_by_character is TRUE')
            }

            chs <- strsplit(chs, split = '')[[1]]
            possible_resps_split <- strsplit(possible_resps, split = '')[[1]]

            if(all(chs %in% possible_resps_split)){
                return(chs)
            }

        } else {

            if(length(possible_resps) < 2){
                stop('possible_resps must have length > 1 if split_by_character is FALSE')
            }

            if(any(possible_resps == chs)){
                return(chs)
            }
        }
    }

    resp <- get_response_mchar(
        msg = msg,
        possible_resps = possible_resps,
        allow_alphanumeric_response = allow_alphanumeric_response,
        subsequent_prompt = TRUE)

    return(resp)
}

ms_calc_watershed_area <- function(network,
                                   domain,
                                   site_code,
                                   level,
                                   update_site_file){

    #reads watershed boundary shapefile from macrosheds directory and calculates
    #   watershed area with sf::st_area

    #update_site_file: logical. if true, calculated watershed area is written
    #   to the ws_area_ha column in site_data gsheet

    #returns area in hectares

    print(glue('Computing watershed area for {n} - {d} - {l} - {s}',
               n = network,
               d = domain,
               l = level,
               s = site_code))

    ms_dir <- glue('data/{n}/{d}/{l}',
                   n = network,
                   d = domain,
                   l = level)

    level_dirs <- list.dirs(ms_dir,
                            recursive = FALSE,
                            full.names = FALSE)

    ws_boundary_dir <- grep(pattern = '^ws_boundary.*',
                            x = level_dirs,
                            value = TRUE)

    if(! length(ws_boundary_dir)){
        stop(glue('No ws_boundary directory found in ', munge_dir))
    }

    ws_boundary_dir <- rev(ws_boundary_dir)[1]

    site_dir <- glue('data/{n}/{d}/{l}/{w}/{s}',
                     n = network,
                     d = domain,
                     l = level,
                     w = ws_boundary_dir,
                     s = site_code)

    if(! dir.exists(site_dir) || ! length(dir(site_dir))){
        stop(glue('{s} directory missing or empty (data/{n}/{d}/{l}/{w})',
                  s = site_code,
                  n = network,
                  d = domain,
                  l = level,
                  w = ws_boundary_dir))
    }

    wd_path <- glue('data/{n}/{d}/{l}/{w}/{s}/{s}.shp',
                    n = network,
                    d = domain,
                    l = level,
                    w = ws_boundary_dir,
                    s = site_code)

    wb <- sf::st_read(wd_path,
                      quiet = TRUE)

    if(nrow(wb) != 1) stop('expected 1 row in ', wd_path, '; got ', nrow(wb), '.')

    if(! sf::st_is_valid(wb)){
        stop('Watershed is not s2 valid, was this boundary produced under an older version of the system?')
    }

    ws_area_ha <- as.numeric(sf::st_area(wb)) / 10000

    has_area_col <- 'area' %in% colnames(wb)
    if(! has_area_col || wb$area != ws_area_ha){
        wb$area <- ws_area_ha
        wb <- relocate(wb, area, .after = 'site_code')
        sw(sf::st_write(obj = wb,
                        dsn = wd_path,
                        driver = 'ESRI Shapefile',
                        delete_dsn = TRUE,
                        quiet = TRUE))
    }

    if(update_site_file){

        this_site_ix <- site_data$domain == domain &
            site_data$network == network &
            site_data$site_code == site_code &
            site_data$site_type != 'rain_gauge'

        current_ws_area <- site_data$ws_area_ha[this_site_ix]

        if(is.na(current_ws_area) || current_ws_area != ws_area_ha){

            site_data$ws_area_ha[this_site_ix] <- ws_area_ha

            ms_write_confdata(site_data,
                              which_dataset = 'site_data',
                              to_where = ms_instance$config_data_storage,
                              overwrite = TRUE)
        }
    }

    return(ws_area_ha)
}

write_wb_delin_specs <- function(network,
                                 domain,
                                 site_code,
                                 buffer_radius,
                                 snap_method,
                                 snap_distance,
                                 dem_resolution,
                                 flat_increment,
                                 breach_method,
                                 burn_streams){

    print(glue('Saving delineation specs'))

    new_entry <- tibble(network = network,
                        domain = domain,
                        site_code = site_code,
                        buffer_radius_m = buffer_radius,
                        snap_method = snap_method,
                        snap_distance_m = snap_distance,
                        dem_resolution = dem_resolution,
                        flat_increment = as.character(flat_increment),
                        breach_method = as.character(breach_method),
                        burn_streams = as.character(burn_streams))

    # ws_delin_specs <- bind_rows(ws_delin_specs, new_entry)

    ms_write_confdata(new_entry,
                      which_dataset = 'ws_delin_specs',
                      to_where = ms_instance$config_data_storage,
                      overwrite = FALSE)
}

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

    #return()
}

parse_molecular_formulae <- function(formulae){

    #`formulae` is a vector

    # formulae = c('C', 'C4', 'Cl', 'Cl2', 'CCl', 'C2Cl', 'C2Cl2', 'C2Cl2B2')
    # formulae = 'BCH10He10PLi2'
    # formulae='Mn'

    conc_vars = str_match(formulae, '^(?:OM|TM|DO|TD|UT|UTK|TK|TI|TO|DI)?([A-Za-z0-9]+)_?')[,2]
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

calculate_molar_mass <- function(molecular_formula){

    if(length(molecular_formula) > 1){
        stop('molecular_formula must be a string of length 1')
    }

    parsed_formula = parse_molecular_formulae(molecular_formula)[[1]]

    molar_mass = combine_atomic_masses(parsed_formula)

    return(molar_mass)
}

convert_molecule <- function(x, from, to){

    #e.g. convert_molecule(1.54, 'NH4', 'N')

    molecule_real <- ms_vars %>%
        filter(variable_code == !!from) %>%
        pull(molecule)

    if(! is.na(molecule_real)){
        from <- molecule_real
    }

    from_mass <- calculate_molar_mass(from)
    to_mass <- calculate_molar_mass(to)
    converted_mass <- x * to_mass / from_mass

    return(converted_mass)
}

update_product_file <- function(network,
                                domain,
                                level,
                                prodcode,
                                status,
                                prodname){

    prods = sm(read.csv(glue('src/{n}/{d}/products.csv',
                             n = network,
                             d = domain),
                        colClasses = 'character'))

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

    # if(network == domain){
    #     write_csv(prods, glue('src/{n}/products.csv', n=network))
    # } else {
    write_csv(x = prods,
              file = glue('src/{n}/{d}/products.csv',
                          n = network,
                          d = domain))
    # }
}

update_product_statuses <- function(network, domain){

    kf = glue('src/{n}/{d}/processing_kernels.R', n=network, d=domain)
    kernel_lines = read_lines(kf)

    status_line_inds = grep(pattern = '^# ?[^#]\\w.+?STATUS=([A-Z]+)',
                            x = kernel_lines,
                            perl = TRUE)
    mch = stringr::str_match(kernel_lines[status_line_inds],
                             '#(.+?): STATUS=([A-Z]+)')[, 2:3]
    prodnames = mch[, 1, drop=TRUE]
    statuses = mch[, 2, drop=TRUE]

    if(any(! statuses %in% status_codes)){
        stop(glue('Illegal status in ', kf))
    }

    decorator_lines <- grepl(pattern = '^#\\. handle_errors$',
                             x = kernel_lines[status_line_inds + 1])

    if(any(! decorator_lines)){
        stop(glue('missing or improper decorator lines (#. handle_errors) in ',
                  kf))
    }

    funcname_lines = kernel_lines[status_line_inds + 2]

    if(any(! grep('process_[0-2]_.+?', funcname_lines))){
        stop(glue('function definition must begin exactly two lines after STATUS',
                  ' indicator. function must be named "process_<level>_<prodcode>"'))
    }

    func_codes = stringr::str_match(funcname_lines,
                                    'process_([0-2])_(.+)? <-')[, 2:3, drop=FALSE]

    if(any(is.na(func_codes))){
        stop('error updating product statuses. probable extraneous lines in processing_kernels.R')
    }

    func_lvls = func_codes[, 1, drop=TRUE]
    prodcodes = func_codes[, 2, drop=TRUE]

    level_names = case_when(func_lvls == 0 ~ "retrieve",
                            func_lvls == 1 ~ "munge",
                            func_lvls == 2 ~ "derive")

    status_names = tolower(statuses)

    update_product_file(network = network,
                        domain = domain,
                        level = level_names,
                        prodcode = prodcodes,
                        status = status_names,
                        prodname = prodnames)
}

convert_to_gl <- function(x, input_unit, molecule){

    #this is for converting to concentration in mass per volume, from either
    #   equivalents per volume or moles per volume. It is NOT for converting to grams
    #   per liter. Therefore, if your input units are already xg/L, where x is
    #   n, u, m, k, etc., this function will do nothing. In fact, this function ignores
    #   those prefixes. Use convert_unit for that.

    molecule_real <- ms_vars %>%
        filter(variable_code == !!molecule) %>%
        pull(molecule)

    if(!is.na(molecule_real)){
        formula <- molecule_real
    } else {
        formula <- molecule
    }

    if(grepl('eq', input_unit)){

        valence <- ms_vars$valence[ms_vars$variable_code %in% molecule]

        if(length(valence) == 0) {stop('Varible is likely missing from ms_vars')}
        x <- (x * calculate_molar_mass(formula)) / valence

        return(x)
    }

    if(grepl('mol', input_unit)){
        x <- x * calculate_molar_mass(formula)
        return(x)
    }

    return(x)
}

convert_from_gl <- function(x, input_unit, output_unit, molecule, g_conver){

    #this is for converting from concentration in mass per liter to either moles
    #   per liter or equivalents per liter. It does not assume input units are
    #   g/L, but rather any metric mass unit per liter. Specify the input units
    #   with input_unit.
    if(input_unit == output_unit) {
      return(x)
    }

    molecule_real <- ms_vars %>%
        filter(variable_code == !!molecule) %>%
        pull(molecule)

    if(!is.na(molecule_real)) {
        formula <- molecule_real
    } else {
        formula <- molecule
    }

    if(grepl('eq', output_unit) && grepl('g', input_unit) ||
       grepl('eq', output_unit) && g_conver) {

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0 | is.na(valence)) {stop('Varible is likely missing from ms_vars')}
        x = (x * valence) / calculate_molar_mass(formula)

        return(x)
    }

    if(grepl('mol', output_unit) && grepl('g', input_unit) ||
       grepl('mol', output_unit) && g_conver) {

        x = x / calculate_molar_mass(formula)

        return(x)
    }

    if(grepl('mol', output_unit) && grepl('eq', input_unit) && !g_conver) {

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0) {stop('Varible or valence missing from ms_vars')}
        x = (x * calculate_molar_mass(formula)) / valence

        x = x / calculate_molar_mass(formula)

        return(x)
    }

    if(grepl('eq', output_unit) && grepl('mol', input_unit) && !g_conver) {

        x = x * calculate_molar_mass(formula)

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0) {stop('Varible or valence missing from ms_vars')}
        x = (x * valence)/calculate_molar_mass(formula)

        return(x)
    }

    return(x)

}

convert_unit <- function(x, input_unit, output_unit){

    units <- tibble(prefix = c('n', "u", "m", "c", "d", "h", "k", "M"),
                    convert_factor = c(0.000000001, 0.000001, 0.001, 0.01, 0.1, 100,
                                       1000, 1000000))

    old_fraction <- as.vector(str_split_fixed(input_unit, "/", n = Inf))
    old_top <- as.vector(str_split_fixed(old_fraction[1], "", n = Inf))

    if(length(old_fraction) == 2) {
        old_bottom <- as.vector(str_split_fixed(old_fraction[2], "", n = Inf))
    } else {
        old_bottom <- NULL
    }

    new_fraction <- as.vector(str_split_fixed(output_unit, "/", n = Inf))
    new_top <- as.vector(str_split_fixed(new_fraction[1], "", n = Inf))

    if(length(new_fraction == 2)) {
        new_bottom <- as.vector(str_split_fixed(new_fraction[2], "", n = Inf))
    } else {
        new_bottom <- NULL
    }

    old_top_unit <- tolower(str_split_fixed(old_top, "", 2)[1])

    if(old_top_unit %in% c('g', 'e', 'q', 'l') || old_fraction[1] == 'mol') {
        old_top_conver <- 1
    } else {
        old_top_conver <- as.numeric(filter(units, prefix == old_top_unit)[,2])
    }

    if(length(old_fraction) == 2) {
      old_bottom_unit <- tolower(str_split_fixed(old_bottom, "", 2)[1])
    }

    if(is.na(old_fraction[2])) {
        old_bottom_conver <- NULL
    } else if(old_bottom_unit %in% c('g', 'e', 'q', 'l') || old_fraction[2] == 'mol') {
        old_bottom_conver <- 1
    } else {
        old_bottom_conver <- as.numeric(filter(units, prefix == old_bottom_unit)[,2])
    }

  # debug
    tryCatch(
      expr = {
          new_top_unit <- tolower(str_split_fixed(new_top, "", 2)[1])
          if(new_top_unit %in% c('g', 'e', 'q', 'l') || new_fraction[1] == 'mol') {
              new_top_conver <- 1
          } else {
              new_top_conver <- as.numeric(filter(units, prefix == new_top_unit)[,2])
          }
      },
      error = function(e) {
        print(input_unit)
        print(output_unit)
        print(new_top_unit)
        print('has a variable code been changed in the variables sheet and not in the DL sheet?')
      }
    )
  # end debug

    new_bottom_unit <- tolower(str_split_fixed(new_bottom, "", 2)[1])
    if(is.na(new_fraction[2])) {
        new_bottom_conver <- NULL
    } else if(new_bottom_unit %in% c('g', 'e', 'q', 'l') || new_fraction[2] == 'mol') {
        new_bottom_conver <- 1
    } else {
        new_bottom_conver <- as.numeric(filter(units, prefix == new_bottom_unit)[,2])
    }

    new_val <- x*old_top_conver
    new_val <- new_val/new_top_conver

    # some vars do not have a bottom unit
    if(!is.null(old_bottom_conver)) {
      new_val <- new_val/old_bottom_conver
    }

    if(!is.null(new_bottom_conver)) {
      new_val <- new_val*new_bottom_conver
    }

    return(new_val)
}

write_ms_file <- function(d,
                          network,
                          domain,
                          prodname_ms,
                          site_code,
                          level = 'munged',
                          shapefile = FALSE,
                          link_to_portal = FALSE,
                          sep_errors = TRUE){

    #write an ms tibble or shapefile to its appropriate destination based on
    #network, domain, prodname_ms, site_code, and processing level. If a tibble,
    #write as a feather file (site_code.feather). Uncertainty (error) associated
    #with the val column will be extracted into a separate column called
    #val_err if sep_errors is TRUE.

    #deprecated:
    #if link_to_portal == TRUE, create a hard link to the
    #file from the portal repository, which is assumed to be a sibling of the
    #data_acquision directory and to be named "portal".

    if(link_to_portal){
        stop("we're not linking to portal this way anymore. see create_portal_links()")
    }

    if(! level %in% c('munged', 'derived')){
        stop('level must be "munged" or "derived"')
    }

    if(shapefile){

        site_dir = glue('data/{n}/{d}/{l}/{p}/{s}',
                        n = network,
                        d = domain,
                        l = level,
                        p = prodname_ms,
                        s = site_code)

        dir.create(site_dir,
                   showWarnings = FALSE,
                   recursive = TRUE)

        if(any(! sf::st_is_valid(d))) {
            d <- sf::st_make_valid(d)
        }

        sw(sf::st_write(obj = d,
                        dsn = glue(site_dir, '/', site_code, '.shp'),
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
                         s = site_code)

        if('val_err' %in% colnames(d) && inherits(d$val, 'errors')){
            stop('this dataset has uncertainty on the val column AND a val_err column. investigate')
        }

        if(sep_errors){

            #separate uncertainty into a new column.
            #remove errors attribute from val column if it exists (it always should)
            if(inherits(d$val, 'errors')){
                d$val_err <- errors(d$val)
                d$val <- errors::drop_errors(d$val)
            } else if(! 'val_err' %in% colnames(d)){
                stop(glue('Uncertainty missing from val column and no val_err column for ({n}-{d}-{s}-{p}). ',
                             'That means this dataset has not passed through ',
                             'qc_hdetlim_and_uncert yet. it should have.',
                             n = network,
                             d = domain,
                             s = site_code,
                             p = prodname_ms))
            }
        }

        #make sure write_feather will omit attrib by def (with no artifacts)
        write_feather(d, site_file)
    }

    if(link_to_portal){
        create_portal_link(network = network,
                           domain = domain,
                           prodname_ms = prodname_ms,
                           site_code = site_code,
                           level = level,
                           dir = shapefile)
    }
}

#deprecated (old form of this function is in helper_scrapyard.R)
create_portal_link <- function(network, domain, prodname_ms, site_code,
                               level = 'derived', dir = FALSE){

    #remove this once enough time has passed to be sure all devs are up to speed.

    stop(glue('create_portal_link has been deprecated. use create_portal_links ',
              '(plural)'))
}

create_derived_links <- function(network, domain, prodname_ms, new_prodcode){

    #for hardlinking munged products to the derive directory. this applies to all
    #munged products that require no derive-level processing.

    #new_prodcode is the derive-style prodcode (e.g. ms009) that will be
    #   given to the new links in the derive directory. this is determined
    #   programmatically by ms_derive

    new_prodname_ms <- paste(prodname_from_prodname_ms(prodname_ms),
                             new_prodcode,
                             sep = '__')

    old_loc <- ifelse(is_derived_product(prodname_ms), 'derived', 'munged')

    munge_dir <- glue('data/{n}/{d}/{l}/{p}',
                      n = network,
                      d = domain,
                      p = prodname_ms,
                      l = old_loc)

    derive_dir <- glue('data/{n}/{d}/derived/{p}',
                       n = network,
                       d = domain,
                       p = new_prodname_ms)

    dir.create(derive_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    mungefiles <- list.files(dirname(munge_dir),
                             pattern = basename(munge_dir),
                             full.names = TRUE)

    if(length(mungefiles) > 1){
        #weird case. just for panola as of 20240608

        if(domain != 'panola'){
            logwarn('this chunk was built just for panola and should not run for any other <=2024 domains. could easily cause problems for other domains. it should only run in the case where there are multiple versions of a single CUSTOM prodname_ms, e.g. different flux methods',
                    logger = logger_module)
        }

        if(all(is.na(str_match(mungefiles, '__[A-Za-z0-9]+_.*$')[, 1]))){
            stop('for this condition, the prodname_ms should have extra suffixes after the prodcode, e.g. data/webb/panola/derived/CUSTOMstream_flux_inst_scaled__ms008_Flx_ClmMod')
        }

        dirs_to_build <- convert_munge_path_to_derive_path(
            paths = mungefiles,
            munge_prodname_ms = prodname_ms,
            derive_prodname_ms = new_prodname_ms)

        dirs_to_build <- sub(paste0(new_prodname_ms, '_'),
                             paste0(new_prodname_ms, '/'),
                             dirs_to_build)

        for(dr in dirs_to_build){
            dir.create(dr,
                       showWarnings = FALSE,
                       recursive = TRUE)
        }

        for(i in seq_along(mungefiles)){

            files_to_link_from <- list.files(path = mungefiles[i],
                                             recursive = TRUE,
                                             full.names = TRUE)

            files_to_link_to <- file.path(dirs_to_build[i],
                                          basename(files_to_link_from))

            for(j in seq_along(files_to_link_from)){
                unlink(files_to_link_to[j])
                invisible(sw(file.link(to = files_to_link_to[j],
                                       from = files_to_link_from[j])))
            }
        }

        return(invisible())
    }

    dirs_to_build <- list.dirs(munge_dir,
                               recursive = TRUE)
    dirs_to_build <- dirs_to_build[dirs_to_build != munge_dir]

    dirs_to_build <- convert_munge_path_to_derive_path(
        paths = dirs_to_build,
        munge_prodname_ms = prodname_ms,
        derive_prodname_ms = new_prodname_ms)

    for(dr in dirs_to_build){
        dir.create(dr,
                   showWarnings = FALSE,
                   recursive = TRUE)
    }

    #"from" and "to" may seem counterintuitive here. keep in mind that files
    #as represented by the OS are actually all hardlinks to inodes in the kernel.
    #so when you make a new hardlink, you're linking *from* a new location
    #*to* an inode, as referenced by an existing hardlink. file.link uses
    #these words in a less realistic, but more intuitive way, i.e. *from*
    #an existing file *to* a new location
    files_to_link_from <- list.files(path = munge_dir,
                                     recursive = TRUE,
                                     full.names = TRUE)

    files_to_link_to <- convert_munge_path_to_derive_path(
        paths = files_to_link_from,
        munge_prodname_ms = prodname_ms,
        derive_prodname_ms = new_prodname_ms)

    for(i in 1:length(files_to_link_from)){
        unlink(files_to_link_to[i])
        invisible(sw(file.link(to = files_to_link_to[i],
                               from = files_to_link_from[i])))
    }
}

create_portal_links <- function(network, domain){

    #for hardlinking derived products to the portal directory. this applies to all
    #derived products except cdnr_discharge, usgs_discharge, and pre-idw precipitation.
    #we will eventually let portal users view and download uninterpolated (spatially)
    #rain gauge data, and at that time we may choose to simply delete the sections
    #below (**) that filter those datasets.

    derive_dir <- glue('data/{n}/{d}/derived',
                       n = network,
                       d = domain)

    portal_dir <- glue('../portal/data/{d}',
                       d = domain)

    dir.create(portal_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    dirs_to_ignore <- c()
    dirs_to_build <- list.dirs(derive_dir,
                               recursive = TRUE)
    dirs_to_build <- dirs_to_build[dirs_to_build != derive_dir]

    dirs_to_ignore <- c(dirs_to_ignore,
                        dirs_to_build[grepl(pattern = '(?:/cdnr_discharge|/usgs_discharge)',
                                            x = dirs_to_build)])

    ppaths <- grep(pattern = '/precipitation__ms[0-9]{3}$',
                   x = dirs_to_build,
                   value = TRUE) %>%
        sort()

    if(length(ppaths) > 2){
        stop("more than 2 derived precipitation products? what's going on here?")
    }

    # ** here's the first section referenced in the docstring above ---
    if(length(ppaths) == 2){
        dirs_to_ignore <- c(dirs_to_ignore, ppaths[1])
    }
    # see the next double-asterisk for the second and final section---

    dirs_to_build <- dirs_to_build[! dirs_to_build %in% dirs_to_ignore]
    dirs_to_build <- convert_derive_path_to_portal_path(paths = dirs_to_build)

    for(dr in dirs_to_build){
        dir.create(dr,
                   showWarnings = FALSE,
                   recursive = TRUE)
    }

    #"from" and "to" may seem counterintuitive here. keep in mind that files
    #as represented by the OS are actually all hardlinks to inodes in the kernel.
    #so when you make a new hardlink, you're linking *from* a new location
    #*to* an inode, as referenced by an existing hardlink. file.link uses
    #these words in a less realistic, but more intuitive way, i.e. *from*
    #an existing file *to* a new location
    files_to_link_from <- list.files(path = derive_dir,
                                     recursive = TRUE,
                                     full.names = TRUE)

    # ** here's the second and final section referenced in the docstring above ---
    if(length(dirs_to_ignore)){
        files_to_link_from <- files_to_link_from[! grepl(
            pattern = paste0('(?:',
                             paste(paste0('^',
                                   dirs_to_ignore),
                             collapse = '|'),
                             ')'),
            x = files_to_link_from)]
    }
    # ---

    files_to_link_to <- convert_derive_path_to_portal_path(
        paths = files_to_link_from)

    for(i in 1:length(files_to_link_from)){
        unlink(files_to_link_to[i])
        invisible(sw(file.link(to = files_to_link_to[i],
                               from = files_to_link_from[i])))
    }
}

convert_munge_path_to_derive_path <- function(paths,
                                              munge_prodname_ms,
                                              derive_prodname_ms){

    #paths: strings containing filepath information. expected words are
    #   "munged" and a readable prodname_ms. something like
    #   "data/lter/hbef/munged/ws_boundary__94/w1"
    #munge_prodname_ms: the prodname_ms for this product in its munged form.
    #   e.g. "ws_boundary__94"
    #derive_prodname_ms: the prodname_ms for this product in its derived form
    #   (may be the same as munge_prodname_ms), e.g. "ws_boundary__ms005"

    paths <- gsub(pattern = 'munged',
                  replacement = 'derived',
                  x = paths)

    paths <- gsub(pattern = paste0('__',
                                   prodcode_from_prodname_ms(munge_prodname_ms)),
                  replacement = paste0('__',
                                       prodcode_from_prodname_ms(derive_prodname_ms)),
                  x = paths)

    return(paths)
}

convert_derive_path_to_portal_path <- function(paths){

    #paths: strings containing filepath information. expected words are
    #   "derived" and a readable prodname_ms. something like
    #   "data/lter/hbef/derived/discharge__ms005" or
    #   "data/lter/hbef/derived/precip_gauge_locations__ms006/RG1"

    paths <- gsub(pattern = paste0('data/', network),
                  replacement = '../portal/data',
                  x = paths)

    paths <- gsub(pattern = 'derived/',
                  replacement = '',
                  x = paths)

    paths <- gsub(pattern = '__ms[0-9]{3}',
                  replacement = '',
                  x = paths,
                  perl = TRUE)

    return(paths)
}

is_ms_prodcode <- function(prodcode){

    #always specify macrosheds "pseudo product codes" as "msXXX" where
    #X is zero-padded integer. these codes are used for derived products
    #that don't exist within the data source.

    return(grepl('ms[0-9]{3}', prodcode))
}

ms_list_files <- function(network, domain, prodname_ms){

    #level is either "munged" or "derived"
    #prodname_ms can be a single string or a vector

    level <- ifelse(is_derived_product(prodname_ms), 'derived', 'munged')

    prods <- glue('data/{n}/{d}/{l}/{p}',
                  n = network,
                  d = domain,
                  l = level,
                  p = prodname_ms)

    missing_prods <- which(! dir.exists(prods))
    if(length(missing_prods)){
        stop('These products are missing: ', paste(prods[missing_prods], collapse = ', '))
    }

    files <- list.files(prods, full.names = TRUE)

    return(files)
}

fname_from_fpath <- function(paths, include_fext = TRUE){

    #paths is a vector of filepaths of/this/form. final slash is used to
    #delineate file name.

    #if include_fext == FALSE, file extension will not be included

    fnames <- vapply(strsplit(paths, '/'),
                     function(x) x[length(x)],
                     FUN.VALUE = '')

    if(! include_fext){

        # This was not working for sites that have a "." in their name
        #fnames <- str_match(fnames,'(.*?)\\..*')[, 2]

        fnames <- str_split_fixed(fnames, '.feather', n = Inf)[, 1]
    }

    return(fnames)
}

calc_inst_flux <- function(chemprod, qprod, site_code){

    #chemprod is the prodname_ms for stream or precip chemistry.
    #   it can be a munged or a derived product.
    #qprod is the prodname_ms for stream discharge or precip volume over time.
    #   it can be a munged or derived product.

    q_type <- prodname_from_prodname_ms(qprod)
    if(! grepl('(precipitation|discharge)', q_type)){
        stop('Could not determine stream/precip')
    }

    flux_vars <- ms_vars %>% #ms_vars is global
        filter(flux_convertible == 1) %>%
        pull(variable_code)

    chem <- read_combine_feathers(network = network,
                                  domain = domain,
                                  prodname_ms = chemprod) %>%
        filter(site_code == !!site_code,
               drop_var_prefix(var) %in% flux_vars)

    if(nrow(chem) == 0) return(NULL)

    daterange <- range(chem$datetime)

    flow <- read_combine_feathers(network = network,
                                  domain = domain,
                                  prodname_ms = qprod) %>%
        filter(
            site_code == !!site_code,
            datetime >= !!daterange[1],
            datetime <= !!daterange[2])

    if(nrow(flow) == 0) return(NULL)
    flow_is_highres <- Mode(diff(as.numeric(flow$datetime))) <= 15 * 60
    if(is.na(flow_is_highres)) flow_is_highres <- FALSE

    chem_split <- chem %>%
        group_by(var) %>%
        arrange(datetime) %>%
        dplyr::group_split() %>%
        as.list()

    #could do this in parallel (using furrr or foreach), but that might
    #incur the same OOM issues as doing it all at once in wide-format. worth trying,
    #but only use half of the available threads
    for(i in 1:length(chem_split)){

        chem_chunk <- chem_split[[i]]

        chem_is_highres <- Mode(diff(as.numeric(chem_chunk$datetime))) <= 15 * 60

        if(is.na(chem_is_highres)) chem_is_highres <- FALSE

        #if both chem and flow data are low resolution (grab samples),
        #   let approxjoin_datetime match up samples with a 12-hour gap. otherwise the
        #   gap should be 7.5 mins so that there isn't enormous duplication of
        #   timestamps where multiple high-res values can be snapped to the
        #   same low-res value
        if(! chem_is_highres && ! flow_is_highres){
            join_distance <- c('12:00:00')#, '%H:%M:%S')
        } else {
            join_distance <- c('7:30')#, '%M:%S')
        }

        d_ <- approxjoin_datetime(x = chem_chunk,
                                  y = flow,
                                  rollmax = join_distance,
                                  keep_datetimes_from = 'x')

        if(q_type == 'discharge'){
            d_ <- d_ %>%
                mutate(site_code = site_code_x,
                       var = var_x,
                    #  kg/d = mg/L *  L/s  * 86400 / 1e6
                       val = val_x * val_y * 86400 / 1e6,
                       ms_status = numeric_any_v(ms_status_x, ms_status_y),
                       ms_interp = numeric_any_v(ms_interp_x, ms_interp_y)) %>%
                select(-starts_with(c('site_code_', 'var_', 'val_',
                                      'ms_status_', 'ms_interp_'))) %>%
                filter(! is.na(val)) %>% #should be redundant
                arrange(datetime)
        } else {
            d_ <- d_ %>%
                mutate(site_code = site_code_x,
                       var = var_x,
                       # kg/ha/d = mg/L *  mm/d * ha/100
                       val = val_x * val_y / 100,
                       ms_status = numeric_any_v(ms_status_x, ms_status_y),
                       ms_interp = numeric_any_v(ms_interp_x, ms_interp_y)) %>%
                select(-starts_with(c('site_code_', 'var_', 'val_',
                                      'ms_status_', 'ms_interp_'))) %>%
                filter(! is.na(val)) %>% #should be redundant
                arrange(datetime) %>%
                undo_scale_flux_by_area()
        }

        chem_split[[i]] <- d_
    }

    flux <- chem_split %>%
        purrr::reduce(bind_rows) %>%
        arrange(site_code, var, datetime)
        # select(datetime, site_code, var, val, ms_status, ms_interp)

    if(nrow(flux) == 0) return(NULL)

    return(flux)
}

read_combine_shapefiles <- function(network, domain, prodname_ms){

    #TODO: sometimes multiple locations are listed for the same rain gauge.
    #   if there's a date associated with those locations, we should take that
    #   into account when performing IDW, and when plotting gauges on the map.
    #   (maybe previous locations could show up semitransparent). for now,
    #   we're just grabbing the last location listed (by order). We don't store
    #   date columns with our raingauge shapes yet, so that's the place to start.

    #TODO: also, this may be a problem for other spatial stuff.

    level <- ifelse(is_derived_product(prodname_ms),
                    'derived',
                    'munged')

    prodpaths <- list.files(glue('data/{n}/{d}/{l}/{p}',
                                 n = network,
                                 d = domain,
                                 l = level,
                                 p = prodname_ms),
                            recursive = TRUE,
                            full.names = TRUE,
                            pattern = '*.shp')

    shapes <- lapply(prodpaths,
                     function(x){
                         sf::st_read(x,
                                     stringsAsFactors = FALSE,
                                     quiet = TRUE) %>%
                             slice_tail()
                     })

    # wb <- sw(Reduce(sf::st_union, wbs)) %>%
    combined <- sw(Reduce(bind_rows, shapes))
    # sf::st_transform(projstring)

    return(combined)
}

is_derived_product <- function(prodname_ms){

    is_derived <- grepl('^ms[0-9]{3}$',
                        prodcode_from_prodname_ms(prodname_ms),
                        perl = TRUE)

    return(is_derived)
}

read_combine_feathers <- function(network,
                                  domain,
                                  prodname_ms){

    #read all data feathers associated with a network-domain-product,
    #row bind them, arrange by site_code, var, datetime. insert val_err column
    #into the val column as errors attribute and then remove val_err column
    #(error/uncertainty is handled by the errors package as an attribute,
    #so it must be written/read as a separate column).

    #the processing level is determined automatically from prodname_ms.
    #   If the product code is "msXXX" where X is a numeral, the processing
    #   level is assumed to be "derived". otherwise "munged"

    #handled in ms_list_files
    # level <- ifelse(is_derived_product(prodname_ms),
    #                 'derived',
    #                 'munged')

    prodpaths <- ms_list_files(network = network,
                               domain = domain,
                               prodname_ms = prodname_ms)

    combined <- tibble()
    for(i in 1:length(prodpaths)){
        part <- read_feather(prodpaths[i])
        combined <- bind_rows(combined, part)
    }

    combined <- combined %>%
        mutate(val = errors::set_errors(val, val_err)) %>%
        select(-val_err) %>%
        arrange(site_code, var, datetime)

    return(combined)
}

choose_projection <- function(lat = NULL,
                              long = NULL,
                              unprojected = FALSE){

    #TODO: CHOOSE PROJECTIONS MORE CAREFULLY

    if(unprojected){
        PROJ4 <- glue('+proj=longlat +datum=WGS84 +no_defs ',
                      '+ellps=WGS84 +towgs84=0,0,0')
        return(PROJ4)
    }

    if(is.null(lat) || is.null(long)){
        stop('If projecting, lat and long are required.')
    }

    abslat <- abs(lat)

    # if(abslat < 23){ #tropical
    #     PROJ4 = glue('+proj=laea +lon_0=', long)
    #              # ' +datum=WGS84 +units=m +no_defs')
    # } else { #temperate or polar
    #     PROJ4 = glue('+proj=laea +lat_0=', lat, ' +lon_0=', long)
    # }

    #this is what the makers of https://projectionwizard.org/# use to choose
    #a suitable projection: https://rdrr.io/cran/rCAT/man/simProjWiz.html
    # THIS WORKS (PROJECTS STUFF), BUT CAN'T BE READ AUTOMATICALLY BY st_read
    if(abslat < 70){ #tropical or temperate
        PROJ4 <- glue('+proj=cea +lon_0={lng} +lat_ts=0 +x_0=0 +y_0=0 ',
                      '+ellps=WGS84 +datum=WGS84 +units=m +no_defs',
                      lng = long)
    } else { #polar
        PROJ4 <- glue('+proj=laea +lat_0={lt} +lon_0={lng} +x_0=0 +y_0=0 ',
                      '+ellps=WGS84 +datum=WGS84 +units=m +no_defs',
                      lt = lat,
                      lng = long)
    }

    ## UTM/UPS would be nice for watersheds that don't fall on more than two zones
    ## (incomplete)
    # if(lat > 84 || lat < -80){ #polar; use Universal Polar Stereographic (UPS)
    #     PROJ4 <- glue('+proj=ups +lon_0=', long)
    #              # ' +datum=WGS84 +units=m +no_defs')
    # } else { #not polar; use UTM
    #     PROJ4 <- glue('+proj=utm +lat_0=', lat, ' +lon_0=', long)
    # }

    ## EXTRA CODE FOR CHOOSING PROJECTION BY LATITUDE ONLY
    # if(abslat < 23){ #tropical
    #     PROJ4 <- 9835 #Lambert cylindrical equal area (ellipsoidal; should spherical 9834 be used instead?)
    # } else if(abslat > 23 && abslat < 66){ # middle latitudes
    #     PROJ4 <- 5070 #albers equal area conic
    # } else { #polar (abslat >= 66)
    #     PROJ4 <- 9820 #lambert equal area azimuthal
    #     # PROJ4 <- 1027 #lambert equal area azimuthal (spherical)
    # }
    # PROJ4 <- 3857 #WGS 84 / Pseudo-Mercator
    # PROJ4 <- 2163

    return(PROJ4)
}

reconstitute_raster <- function(x, template){

    m = matrix(as.vector(x),
               nrow=nrow(template),
               ncol=ncol(template),
               byrow=TRUE)
    r <- terra::rast(m,
                crs=terra::crs(template))
    terra::ext(r) <- terra::ext(template)

    return(r)
}

shortcut_idw <- function(encompassing_dem,
                         wshd_bnd,
                         data_locations,
                         data_values,
                         durations_between_samples = NULL,
                         stream_site_code,
                         output_varname,
                         save_precip_quickref = FALSE,
                         elev_agnostic = FALSE,
                         verbose = FALSE){

    #encompassing_dem: RasterLayer must cover the area of wshd_bnd and precip_gauges
    #wshd_bnd: sf polygon with columns site_code and geometry
    #   it represents a single watershed boundary
    #data_locations:sf point(s) with columns site_code and geometry.
    #   it represents all sites (e.g. rain gauges) that will be used in
    #   the interpolation
    #data_values: data.frame with one column each for datetime and ms_status,
    #   and an additional named column of data values for each data location.
    #durations_between_samples: numeric vector representing the time differences
    #   between rows of data_values. Must be expressed in days. Only used if
    #   output_varname == 'SPECIAL CASE PRECIP' and save_precip_quickref == TRUE,
    #   so that quickref data can be expressed in mm/day, which is the unit
    #   required to calculate precip flux.
    #   NOTE: this could be calculated internally, but the duration of measurement
    #   preceding the first value can't be known. Because shortcut_idw is
    #   often run iteratively on chunks of a dataset, we require that
    #   durations_between_samples be passed as an input, so as to minimize
    #   the number of NAs generated.
    #output_varname: character; a prodname_ms, unless you're interpolating
    #   precipitation, in which case it must be "SPECIAL CASE PRECIP", because
    #   prefix information for precip is lost during the widen-by-site step
    #save_precip_quickref: logical. should interpolated precip for all DEM cells
    #   be saved for later use. Should only be true when precip chem will be
    #   interpolated too. only useable when output_varname = 'PRECIP SPECIAL CASE'
    #elev_agnostic: logical that determines whether elevation should be
    #   included as a predictor of the variable being interpolated

    # loginfo(glue('shortcut_idw: working on {ss}', ss=stream_site_code),
    #     logger = logger_module)

    if(output_varname != 'SPECIAL CASE PRECIP' && save_precip_quickref){
        stop(paste('save_precip_quickref can only be TRUE if output_varname',
                   '== "SPECIAL CASE PRECIP"'))
    }
    if(save_precip_quickref && is.null(durations_between_samples)){
        stop(paste('save_precip_quickref can only be TRUE if',
                    'durations_between_samples is supplied.'))
    }
    if(output_varname != 'SPECIAL CASE PRECIP' && ! is.null(durations_between_samples)){
        logwarn(msg = paste('In shortcut_idw: ignoring durations_between_samples because',
                            'output_varname != "SPECIAL CASE PRECIP".'),
                logger = logger_module)
    }

    if('ind' %in% colnames(data_values)){
        timestep_indices <- data_values$ind
        data_values$ind <- NULL
    }

    #matrixify input data so we can use matrix operations
    d_status <- data_values$ms_status
    d_interp <- data_values$ms_interp
    d_dt <- data_values$datetime
    if('prefix' %in% colnames(data_values)) d_pfx <- data_values$prefix

    data_matrix <- select(data_values,
                          -any_of(c('ms_status', 'datetime', 'ms_interp', 'prefix'))) %>%
        err_df_to_matrix()

    #clean dem and get elevation values
    dem_wb <- terra::crop(encompassing_dem, wshd_bnd)
    dem_wb <- terra::mask(dem_wb, wshd_bnd)

    wb_is_linear <- terra::nrow(dem_wb) == 1 || terra::ncol(dem_wb) == 1
    wb_all_na <- all(is.na(terra::values(dem_wb)))

    if(wb_all_na){

        if(wb_is_linear){

            #masking will cause trouble here (only known for niwot-MARTINELLI)
            dem_wb <- terra::crop(encompassing_dem, wshd_bnd)

        } else {
            stop('some kind of crop/mask issue with small watersheds?')
        }
    }

    elevs <- terra::values(dem_wb)
    elevs_masked <- elevs[! is.na(elevs)]

    #compute distances from all dem cells to all data locations
    inv_distmat <- matrix(NA,
                          nrow = length(elevs_masked),
                          ncol = ncol(data_matrix),
                          dimnames = list(NULL,
                                          colnames(data_matrix)))

    dem_wb_all_na <- dem_wb
    terra::values(dem_wb_all_na) <- NA
    dem_wb_all_na <- terra::rast(dem_wb_all_na)
    for(k in 1:ncol(data_matrix)){

        dk <- filter(data_locations,
                     site_code == colnames(data_matrix)[k])

        inv_dists_site <- 1 / terra::distance(terra::rast(dem_wb_all_na), terra::vect(dk))^2 %>%
            terra::values(.)

        inv_dists_site <- inv_dists_site[! is.na(elevs)] #drop elevs not included in mask
        inv_distmat[, k] <- inv_dists_site
    }

    #calculate watershed mean at every timestep
    if(save_precip_quickref) precip_quickref <- list()
    ptm <- proc.time()
    ws_mean <- rep(NA, nrow(data_matrix))
    ntimesteps <- nrow(data_matrix)
    for(k in 1:ntimesteps){

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

        if(nrow(dk) == 0){
            ws_mean[k] <- set_errors(NA_real_, NA)
            if(save_precip_quickref){
                precip_quickref[[k]] <- matrix(NA,
                                               nrow = nrow(d_idw),
                                               ncol = ncol(d_idw))
            }
            next
        }

        #reapply uncertainty dropped by `%*%`
        errors(d_idw) <- weightmat %*% matrix(errors(dk),
                                              nrow = nrow(dk))

        #determine data-elevation relationship for interp weighting
        if(! elev_agnostic && nrow(dk) >= 3){
            d_elev <- tibble(site_code = rownames(dk),
                             d = dk[,1]) %>%
                left_join(data_locations,
                          by = 'site_code') %>%
                mutate(d = errors::drop_errors(d))
            mod <- lm(d ~ elevation, data = d_elev)
            ab <- as.list(mod$coefficients)

            #estimate raster values from elevation alone
            d_from_elev <- ab$elevation * elevs_masked + ab$`(Intercept)`

            # Set all negative values to 0
            d_from_elev[d_from_elev < 0] <- 0

            #get weighted mean of both approaches:
            #weight on idw is 1; weight on elev-predicted is R^2
            rsq <- sw(cor(d_elev$d, mod$fitted.values)^2)
            if(! is.na(rsq)){
                d_idw <- (d_idw + d_from_elev * rsq) / (1 + rsq)
            }
        }

        ws_mean[k] <- mean(d_idw, na.rm=TRUE)
        errors(ws_mean)[k] <- mean(errors(d_idw), na.rm=TRUE)

        if(save_precip_quickref) precip_quickref[[k]] <- d_idw
    }

    if(save_precip_quickref){

        #convert to mm/d
        precip_quickref <- base::Map(
            f = function(millimeters, days){
                return(millimeters/days)
            },
            millimeters = precip_quickref,
            days = durations_between_samples)

        names(precip_quickref) <- as.character(timestep_indices)
        write_precip_quickref(precip_idw_list = precip_quickref,
                              network = network,
                              domain = domain,
                              site_code = stream_site_code,
                              chunkdtrange = range(d_dt))
    }
    # compare_interp_methods()

    if(output_varname == 'SPECIAL CASE PRECIP'){

        ws_mean <- tibble(datetime = d_dt,
                          site_code = stream_site_code,
                          var = paste(d_pfx, 'precipitation', sep = '_'),
                          concentration = ws_mean,
                          ms_status = d_status,
                          ms_interp = d_interp)

    } else {

        ws_mean <- tibble(datetime = d_dt,
                          site_code = stream_site_code,
                          var = output_varname,
                          concentration = ws_mean,
                          ms_status = d_status,
                          ms_interp = d_interp)
    }

    return(ws_mean)
}

shortcut_idw_concflux_v2 <- function(encompassing_dem,
                                     wshd_bnd,
                                     ws_area,
                                     data_locations,
                                     precip_values,
                                     chem_values,
                                     stream_site_code,
                                     output_varname,
                                     # dump_idw_precip,
                                     verbose = FALSE){

    #This replaces shortcut_idw_concflux! shortcut_idw is still used for
    #variables that can't be flux-converted, and for precipitation

    #this function is similar to shortcut_idw_concflux.
    #if the variable represented by chem_values and output_varname is
    #flux-convertible, it multiplies precip chem
    #by precip volume to calculate flux for each cell and returns
    #the means of IDW-interpolated precipitation, precip chem, and precip flux
    #for each sample timepoint. If that variable is not flux-convertible,
    #It only returns precipitation and precip chem. All interpolated products are
    #returned as standard macrosheds timeseries tibbles in a single list.

    #encompassing_dem: RasterLayer; must cover the area of wshd_bnd and
    #   precip_gauges
    #wshd_bnd: sf polygon with columns site_code and geometry.
    #   it represents a single watershed boundary.
    #ws_area: numeric scalar representing watershed area in hectares. This is
    #   passed so that it doesn't have to be calculated repeatedly (if
    #   shortcut_idw_concflux_v2 is running iteratively).
    #data_locations: sf point(s) with columns site_code and geometry.
    #   represents all sites (e.g. rain gauges) that will be used in
    #   the interpolation.
    #precip_values: a data.frame with datetime, ms_status, ms_interp,
    #   and a column of data values for each precip location.
    #chem_values: a data.frame with datetime, ms_status, ms_interp,
    #   and a column of data values for each precip chemistry location.
    #stream_site_code: character; the name of the watershed/stream, not the
    #   name of a precip gauge
    #output_varname: character; the prodname_ms used to populate the var
    #   column in the returned tibble
    #dump_idw_precip: logical; if TRUE, IDW-interpolated precipitation will
    #   be dumped to disk (data/<network>/<domain>/precip_idw_dumps/<site_code>.rds).
    #   this file will then be read by precip_pchem_pflux_idw, in order to
    #   properly build data/<network>/<domain>/derived/<precipitation_msXXX>.
    #   the precip_idw_dumps directory is automatically removed after it's used.
    #   This should only be set to TRUE for one iteration of the calling loop,
    #   or else time will be wasted rewriting the files.
    #   REMOVED; OBSOLETE

    precip_values$prefix <- NULL

    precip_quickref <- read_precip_quickref(network = network,
                                            domain = domain,
                                            site_code = stream_site_code,
                                            # dtrange = as.POSIXct(c('1968-01-01', '1976-06-01'), tz='UTC'))
                                            dtrange = range(chem_values$datetime))

    if(length(precip_quickref) == 1){

        just_checkin <- precip_quickref[[1]]

        if(class(just_checkin) == 'character' &&
            just_checkin == 'NO QUICKREF AVAILABLE'){

            return(tibble())
        }
    }

    precip_is_highres <- Mode(diff(as.numeric(precip_values$datetime))) <= 15 * 60
    if(is.na(precip_is_highres)) precip_is_highres <- FALSE
    chem_is_highres <- Mode(diff(as.numeric(chem_values$datetime))) <= 15 * 60
    if(is.na(chem_is_highres)) chem_is_highres <- FALSE

    #if both chem and precip data are low resolution (grab samples),
    #   let approxjoin_datetime match up samples with a 12-hour gap. otherwise the
    #   gap should be 7.5 mins so that there isn't enormous duplication of
    #   timestamps where multiple high-res values can be snapped to the
    #   same low-res value
    if(! chem_is_highres && ! precip_is_highres){
        join_distance <- c('12:00:00')
    } else {
        join_distance <- c('7:30')
    }

    dt_match_inds <- approxjoin_datetime(x = chem_values,
                                         y = precip_values,
                                         rollmax = join_distance,
                                         indices_only = TRUE)

    chem_values <- chem_values[dt_match_inds$x, ]
    common_datetimes <- chem_values$datetime

    if(length(common_datetimes) == 0){
        pchem_range <- range(chem_values$datetime)
        test <- filter(precip_values,
                       datetime > pchem_range[1],
                       datetime < pchem_range[2])
        if(nrow(test) > 0){
            logging::logerror('something is wrong with approxjoin_datetime')
        }
        return(tibble())
    }

    precip_values <- precip_values %>%
        mutate(ind = 1:n()) %>%
        slice(dt_match_inds$y) %>%
        mutate(datetime = !!common_datetimes)

    quickref_inds <- precip_values$ind
    precip_values$ind <- NULL

    #matrixify input data so we can use matrix operations
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

    rm(precip_values, chem_values); gc()

    d_status <- bitwOr(p_status, c_status)
    d_interp <- bitwOr(p_interp, c_interp)

    #clean dem and get elevation values
    dem_wb <- terra::crop(encompassing_dem, wshd_bnd)
    dem_wb <- terra::mask(dem_wb, wshd_bnd)
    elevs <- terra::values(dem_wb)

    elevs_all_NA <- is.null(Find(function(x) ! is.na(x), elevs))

    if(elevs_all_NA){
        #the crop/mask strategy can fail for very small basins. This is a workaround
        elevs_ <- terra::extract(terra::rast(encompassing_dem),
                                 wshd_bnd,
                                 weights = TRUE)
        # elevs <- elevs_ %>%
        #     select(-ID) %>%
        #     filter(weight >= 0.5) %>%
        #     pull(1)
        elevs[1] <- elevs_[which.max(elevs_$weight), 2]
        e_ <- 1 #governs precip quickref subsetting later
    } else {
        e_ <- TRUE
    }

    elevs_masked <- elevs[! is.na(elevs)]

    #compute distances from all dem cells to all chemistry locations
    inv_distmat_c <- matrix(NA,
                            nrow = length(elevs_masked),
                            ncol = ncol(c_matrix), #ngauges
                            dimnames = list(NULL,
                                            colnames(c_matrix)))

    dem_wb_all_na <- dem_wb
    terra::values(dem_wb_all_na) <- NA
    dem_wb_all_na <- terra::rast(dem_wb_all_na)
    for(k in 1:ncol(c_matrix)){
        dk <- filter(data_locations,
                     site_code == colnames(c_matrix)[k])

        inv_dists_site <- 1 / terra::distance(dem_wb_all_na, terra::vect(dk))^2 %>%
            terra::values(.)
        inv_dists_site <- inv_dists_site[! is.na(elevs)] #drop elevs not included in mask
        inv_distmat_c[, k] <- inv_dists_site
    }

    #calculate watershed mean concentration and flux at every timestep
    ptm <- proc.time()
    ntimesteps <- nrow(c_matrix)
    ws_mean_conc <- ws_mean_flux <- rep(NA, ntimesteps)

    for(k in 1:ntimesteps){

        ## GET CHEMISTRY FOR ALL CELLS IN TIMESTEP k

        #assign cell weights as normalized inverse squared distances (c)
        ck <- t(c_matrix[k, , drop = FALSE])
        inv_distmat_c_sub <- inv_distmat_c[, ! is.na(ck), drop=FALSE]
        ck <- ck[! is.na(ck), , drop=FALSE]
        weightmat_c <- do.call(rbind,
                               unlist(apply(inv_distmat_c_sub,
                                            1,
                                            function(x) list(x / sum(x))),
                                      recursive = FALSE))

        if(ncol(weightmat_c) == 0){
            ws_mean_conc[k] <- NA_real_ %>% set_errors(NA)
            ws_mean_flux[k] <- NA_real_ %>% set_errors(NA)
            next
        }

        #perform vectorized idw (c)
        ck[is.na(ck)] <- 0
        c_idw <- weightmat_c %*% ck

        #reapply uncertainty dropped by `%*%`
        errors(c_idw) <- weightmat_c %*% matrix(errors(ck),
                                                nrow = nrow(ck))

        ## GET FLUX FOR ALL CELLS; THEN AVERAGE CELLS FOR PCHEM, PFLUX, PRECIP

        #calculate flux for every cell:
        #   This is how we'd calcualate flux as kg/(ha * d):
        #       mm/d * mg/L * m/1000mm * kg/1,000,000mg * 1000L/m^(2 + 1) * 10,000m^2/ha
        #       therefore, kg/(ha * d) = mm * mg/L / d / 100 = (mm * mg) / (d * L * 100)
        #   But stream_flux_inst is not scaled by area when it's derived (that
        #   happens later), so we're going to derive precip_flux_inst
        #   as unscaled here, and then both can be scaled the same way in
        #   scale_flux_by_area. So we calculate flux in kg/(ha * d) as above,
        #   then multiply by watershed area in hectares.

        quickref_ind <- as.character(quickref_inds[k])
        #              mg/L        mm/day                                            ha
        flux_interp <- c_idw * precip_quickref[[quickref_ind]][e_, , drop = FALSE] * ws_area / 100

        #calculate watershed averages (work around error drop)
        ws_mean_conc[k] <- mean(c_idw, na.rm=TRUE)
        ws_mean_flux[k] <- mean(flux_interp, na.rm=TRUE)
        errors(ws_mean_conc)[k] <- mean(errors(c_idw), na.rm=TRUE)
        errors(ws_mean_flux)[k] <- mean(errors(flux_interp), na.rm=TRUE)
    }

    # compare_interp_methods()

    ws_means <- tibble(datetime = common_datetimes,
                       site_code = stream_site_code,
                       var = output_varname,
                       concentration = ws_mean_conc,
                       flux = ws_mean_flux,
                       ms_status = d_status,
                       ms_interp = d_interp)

    return(ws_means)
}

dump_precip_idw_tempfile <- function(ws_means,
                                     network,
                                     domain,
                                     site_code){

    #not to be confused with precip quickref, the tempfile (dumpfile) communicates
    #precipitation data used in flux calculation up the callstack from
    #shortcut_idw_concflux_v2 to precip_pchem_pflux_idw, so that the precip
    #product can be generated for free, as a byproduct

    dumpdir <- glue('data/{n}/{d}/precip_idw_dumps/',
                    n = network,
                    d = domain)

    dir.create(dumpdir,
               showWarnings = FALSE,
               recursive = TRUE)

    saveRDS(object = ws_means,
            file = glue('{dd}/{s}.rds',
                        dd = dumpdir,
                        s = site_code))
}

load_precip_idw_tempfile <- function(network,
                                     domain,
                                     site_code){

    #not to be confused with precip quickref, the tempfile (dumpfile) communicates
    #precipitation data used in flux calculation up the callstack from
    #shortcut_idw_concflux_v2 to precip_pchem_pflux_idw, so that the precip
    #product can be generated for free, as a byproduct

    dumpfile <- glue('data/{n}/{d}/precip_idw_dumps/{s}.rds',
                     n = network,
                     d = domain,
                     s = site_code)

    ws_means <- readRDS(dumpfile)

    unlink(dumpfile)

    return(ws_means)
}

write_precip_quickref <- function(precip_idw_list,
                                  network,
                                  domain,
                                  site_code,
                                  chunkdtrange){

    #allows precip values computed by shortcut_idw for each watershed
    #   raster cell to be reused by shortcut_idw_concflux_v2

    quickref_dir <- glue('data/{n}/{d}/precip_idw_quickref/',
                         n = network,
                         d = domain)

    dir.create(path = quickref_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    chunkfile <- paste(strftime(chunkdtrange[1],
                                format = '%Y-%m-%d %H:%M:%S',
                                tz = 'UTC'),
                       strftime(chunkdtrange[2],
                                format = '%Y-%m-%d %H:%M:%S',
                                tz = 'UTC'),
                       sep = '_')

    chunkfile <- str_replace_all(chunkfile, ':', '-')

    saveRDS(object = precip_idw_list,
            file = glue('{qd}/{cf}', #omitting extension for easier parsing
                        qd = quickref_dir,
                        cf = chunkfile))

    #previous approach: when chunks have a size limit:

    # #not to be confused with the precip idw tempfile (dumpfile),
    # #the quickref file allows the same precip idw data to be used across all
    # #chemistry variables when calculating flux. it's stored in 1000-timestep
    # #chunks
    #
    # chunk_number <- floor((timestep - 1) / 1000) + 1
    # chunkID <- stringr::str_pad(string = chunk_number,
    #                             width = 3,
    #                             side = 'left',
    #                             pad = '0')
    #
    # quickref_dir <- glue('data/{n}/{d}/precip_idw_quickref/{s}',
    #                      n = network,
    #                      d = domain,
    #                      s = site_code)
    #
    # chunkfile <- glue('chunk{ch}.rds',
    #                   ch = chunkID)
    #
    # if(! file.exists(chunkfile)){ #in case another thread has already written it
    #
    #     dir.create(path = quickref_dir,
    #                showWarnings = FALSE,
    #                recursive = TRUE)
    #
    #     saveRDS(object = precip_idw_list,
    #             file = paste(quickref_dir,
    #                          chunkfile,
    #                          sep = '/'))
    # }
}

read_precip_quickref <- function(network,
                                 domain,
                                 site_code,
                                 dtrange){
                                 # timestep){

    #allows precip values computed by shortcut_idw for each watershed
    #   raster cell to be reused by shortcut_idw_concflux_v2. These values are
    #   in mm/day

    quickref_dir <- glue('data/{n}/{d}/precip_idw_quickref',
                         n = network,
                         d = domain)

    quickref_chunks <- list.files(quickref_dir)

    refranges <- lapply(quickref_chunks,
           function(x){
               as.POSIXct(strsplit(x, '_')[[1]],
                          tz = 'UTC')
           }) %>%
        plyr::ldply(function(y){
            data.frame(startdt = y[1],
                       enddt = y[2])
        }) %>%
        mutate(ref_ind = 1:n())

    refranges_sel <- refranges %>%
        filter((startdt >= dtrange[1] & enddt <= dtrange[2]) |
                   (startdt < dtrange[1] & enddt >= dtrange[1]) |
                   (enddt > dtrange[2] & startdt <= dtrange[2]))
                   #redundant?
                   # (startdt > dtrange[1] & startdt <= dtrange[2] & enddt > dtrange[2]) |
                   # (startdt < dtrange[1] & enddt < dtrange[2] & enddt >= dtrange[1]))

    if(nrow(refranges_sel) == 0){
        return(list('0' = 'NO QUICKREF AVAILABLE'))
    }

    #handle the case where an end of dtrange falls right between the start and
    #end dates of a quickref file. this is possible because precip dates can
    #be shifted (replaced with pchem dates) inside precip_pchem_pflux_idw2
    ref_ind_range <- range(refranges_sel$ref_ind)

    if(dtrange[1] < refranges_sel$startdt[1] && ref_ind_range[1] > 1){

        refranges_sel <- bind_rows(refranges[ref_ind_range[1] - 1, ],
                                   refranges_sel)
    }

    if(dtrange[2] > refranges_sel$enddt[nrow(refranges_sel)] &&
       ref_ind_range[2] < nrow(refranges)){

        refranges_sel <- bind_rows(refranges_sel,
                                   refranges[ref_ind_range[2] + 1, ])
    }

    quickref <- list()
    for(i in 1:nrow(refranges_sel)){

        fn <- paste(strftime(refranges_sel$startdt[i],
                             format = '%Y-%m-%d %H-%M-%S',
                             tz = 'UTC'),
                    strftime(refranges_sel$enddt[i],
                             format = '%Y-%m-%d %H-%M-%S',
                             tz = 'UTC'),
                    sep = '_')

        qf <- readRDS(glue('{qd}/{f}',
                           qd = quickref_dir,
                           f = fn))

        quickref <- append(quickref, qf)
    }

    #for some reason the first ref sometimes gets duplicated?
    quickref <- quickref[! duplicated(names(quickref))]

    return(quickref)
}

populate_implicit_NAs <- function(d,
                                  interval,
                                  val_fill = NA,
                                  ms_status_fill = 0,
                                  ms_interp_fill = 1,
                                  edges_only = FALSE){

    #TODO: this would be more flexible if we could pass column names as
    #   positional args and use them in group_by and mutate

    #d: a ms tibble with at minimum datetime, site_code, and var columns
    #interval: the interval along which to populate missing values. (must be
    #   either '15 min' or '1 day'.
    #val_fill: character or NA. the token with which to populate missing
    #   elements of the `val` column. All other columns will be populated
    #   invariably with NA or 0. See details.
    #ms_status_fill: for new rows, the value to assign to the ms_status column
    #ms_interp_fill: for new rows, the value to assign to the ms_interp column
    #edges_only: logical. if TRUE, only two filler rows will be inserted into each
    #   gap, one just after the gap begins and the other just before the gap ends.
    #   If FALSE (the default), the gap will be fully populated according to
    #   the methods outlined in the details section.

    #this function makes implicit missing timeseries records explicit,
    #   by populating rows so that the datetime column is complete
    #   with respect to the sampling interval. In other words, if
    #   samples are taken every 15 minutes, but some samples are skipped
    #   (rows not present), this will create those rows. If ms_status or
    #   ms_interp columns are present, their new records will be populated
    #   with 0s. The val column will be populated with whatever is passed to
    #   val_fill. Any other columns will be populated with NAs.

    #returns d, complete with new rows, sorted by site_code, then var, then datetime

    if(! interval %in% c('15 min', '1 day')){
        stop('interval must be "15 min" or "1 day", unless we have decided otherwise')
    }

    complete_d <- d %>%
        mutate(fill_marker = 1) %>%
        group_by(site_code, var) %>%
        tidyr::complete(datetime = seq(min(datetime),
                                       max(datetime),
                                       by = interval)) %>%
        ungroup() %>%
        arrange(site_code, var, datetime) %>%
        select(datetime, site_code, var, everything())

    if(! any(is.na(complete_d$fill_marker))) return(d)

    if(! is.na(val_fill)){
        complete_d$val[is.na(complete_d$fill_marker)] <- val_fill
    }

    if('ms_status' %in% colnames(complete_d)){
        complete_d$ms_status[is.na(complete_d$ms_status)] <- ms_status_fill
    }

    if('ms_interp' %in% colnames(complete_d)){
        complete_d$ms_interp[is.na(complete_d$ms_interp)] <- ms_interp_fill
    }

    if(edges_only){

        midgap_rows <- rle2(is.na(complete_d$fill_marker)) %>%
            filter(values == TRUE) %>%
            select(starts, stops) %>%
            {purrr::map2(.x = .$starts,
                         .y = .$stops,
                         ~seq(.x, .y))} %>%
            purrr::map(~( if(length(.x) <= 2)
                {
                    return(NULL)
                } else {
                    return(.x[2:(length(.x) - 1)])
                }
            )) %>%
            unlist()
        if(! is.null(midgap_rows)){
            complete_d <- slice(complete_d,
                                -midgap_rows)
        }
    }

    complete_d$fill_marker <- NULL

    return(complete_d)
}

get_superunknowns <- function(special_vars){

    non_ws_chars <- filter(ms_vars, variable_type != 'ws_char') %>% pull(variable_code)
    superunknowns <- non_ws_chars[! non_ws_chars %in% unknown_detlim_prec_lookup$var]
    superunknowns <- superunknowns[! superunknowns %in% special_vars]

    return(superunknowns)
}

ms_daily_interpolate <- function(d, type, interval = NULL, maxgap = NULL){

    #d: a ms tibble
    #type: character. one of
    # + "linear",
    # + "nocb" (next observation carried backward), which is for pchem only,
    #   where measured concentrations may represent aggregated concentration
    #   over the measurement period.
    # + "mean_nocb", which is for precipitation only, where (rarely) measurements may represent
    #   accumulation over the measurement period. if NAs are present, successive NAs can be
    #   assumed to sum to the next measured value. Therefore each NA in a series can be estimated
    #   as the next measured value divided by the number of NAs in the series.
    # + "zero" for 0-interpolation, which can be appropriate for precip or pchem,
    #   though note that this is heavily dependent on any pre-interpolation and
    #   does not necessarily imply that NAs in the raw data are treated as 0s, for
    #   example if P is weekly and paired with pchem, we may use zero-interp
    #   for convenience and simplicity, since totals are all that matter when
    #   computing fluxes.
    #interval: the sampling interval (either '15 min' or '1 day'). an
    #   appropriate maxgap (i.e. max number of consecutive NAs to fill) will
    #   be chosen based on this interval if none is given.

    #fills gaps up to maxgap, then removes missing values

    if(length(unique(d$site_code)) > 1){
        stop(paste('ms_daily_interpolate is not designed to handle datasets',
                   'with more than one site.'))
    }

    if(length(unique(d$var)) > 1){
        stop(paste('ms_daily_interpolate is not designed to handle datasets',
                   'with more than one variable'))
    }

    if(! interval %in% c('15 min', '1 day')){
        stop('interval must be "15 min" or "1 day", unless we have decided otherwise')
    }

    types <- c('linear', 'nocb', 'mean_nocb', 'zero')
    if(! type %in% types){
        stop('type must be one of: "', paste(types, collapse = '", "'), '"')
    }

    if(! is.null(maxgap) && ! is.numeric(maxgap)){
        stop('maxgap must be numeric or NULL')
    }

    if(is.null(maxgap)){

        if(type %in% setdiff(types, 'linear')){
            maxgap <- 45 #days
        } else {
            var <- drop_var_prefix(d$var[1])
            maxgap <- ifelse(var == 'discharge',
                             3, #is Q
                             15) #is stream chemistry
        }

        if(interval == '15 min'){
            maxgap <- maxgap * 96
        }
    }

    d <- arrange(d, datetime)
    ms_interp_bool <- is.na(d$val) | d$ms_interp == 1

    d_interp <- do.call(paste('ms', type, 'interpolate',
                              sep = '_'),
                        args = list(d = d,
                                    maxgap = maxgap))

    d_interp <- d_interp %>%
        select(any_of(c('datetime', 'site_code', 'var', 'val', 'ms_status', 'ms_interp'))) %>%
        arrange(site_code, var, datetime)

    if(any(! is.na(filter(d_interp, is.na(ms_status))$val))){
        stop('assigning ms_status of 0 for a non-NA val. investigate')
    }

    d_interp$ms_status[is.na(d_interp$ms_status)] <- 0
    d_interp$ms_interp <- as.numeric(ms_interp_bool & ! is.na(d_interp$val))
    if(is.na(d$val[1])) d_interp$val[1] <- NA
    d_interp <- filter(d_interp, ! is.na(val)) #*

    return(d_interp)
}

ms_linear_interpolate <- function(d, maxgap){

    d_interp <- d %>%
        mutate(val_err = errors::errors(val),
               val = errors::drop_errors(val),

               #carry ms_status to any rows that have just been populated
               ms_status = imputeTS::na_locf(ms_status,
                                             na_remaining = 'rev',
                                             maxgap = maxgap),

               val = if(sum(! is.na(val)) > 1){
                   #linear interp NA vals
                   imputeTS::na_interpolation(val, maxgap = maxgap, rule = 1)
                   #unless not enough data in group; then do nothing
               } else val,

               val_err = if(sum(! is.na(val_err)) > 1){
                   #do the same for uncertainty
                   imputeTS::na_interpolation(val_err, maxgap = maxgap, rule = 1)
               } else val_err
        )

    errors::errors(d_interp$val) <- d_interp$val_err
    d_interp$val_err <- NULL

    return(d_interp)
}

ms_nocb_interpolate <- function(d, maxgap){

    d_interp <- d %>%
        mutate(val_err = errors::errors(val),
               val = errors::drop_errors(val),

               #carry ms_status to any rows that have just been populated
               ms_status = imputeTS::na_locf(ms_status,
                                             option = 'nocb',
                                             na_remaining = 'rev',
                                             maxgap = maxgap),

               val = if(sum(! is.na(val)) > 1){
                   #nocb interp NA vals
                   imputeTS::na_locf(val,
                                     option = 'nocb',
                                     na_remaining = 'keep',
                                     maxgap = maxgap)
                   #unless not enough data in group; then do nothing
               } else val,

               val_err = if(sum(! is.na(val_err)) > 1){
                   #do the same for uncertainty
                   imputeTS::na_locf(val_err,
                                     option = 'nocb',
                                     na_remaining = 'keep',
                                     maxgap = maxgap)
               } else val_err
        )

    errors::errors(d_interp$val) <- d_interp$val_err
    d_interp$val_err <- NULL

    return(d_interp)
}

ms_zero_interpolate <- function(d, maxgap){

    d_interp <- d %>%
        mutate(

            ms_status = imputeTS::na_replace(ms_status,
                                             fill = 0,
                                             maxgap = maxgap),

            val = if(sum(! is.na(val)) > 1){
                #nocb interp NA vals
                imputeTS::na_replace(val,
                                     fill = 0,
                                     maxgap = maxgap)
                #unless not enough data in group; then do nothing
            } else val
        )

    return(d_interp)
}

ms_mean_nocb_interpolate <- function(d, maxgap){

    d_interp <- d %>%
        mutate(val_err = errors::errors(val),
               val = errors::drop_errors(val),

               #carry ms_status to any rows that have just been populated (probably
               #redundant now, but can't hurt)
               ms_status = imputeTS::na_locf(ms_status,
                                             option = 'nocb',
                                             na_remaining = 'rev',
                                             maxgap = maxgap),

               val = if(sum(! is.na(val)) > 1){
                   #nocb interp NA vals
                   imputeTS::na_locf(val,
                                     option = 'nocb',
                                     na_remaining = 'keep',
                                     maxgap = maxgap)
                   #unless not enough data in group; then do nothing
               } else val,

               val_err = if(sum(! is.na(val_err)) > 1){
                   #do the same for uncertainty
                   imputeTS::na_locf(val_err,
                                     option = 'nocb',
                                     na_remaining = 'keep',
                                     maxgap = maxgap)
               } else val_err
        )

    errors::errors(d_interp$val) <- d_interp$val_err
    d_interp$val_err <- NULL

    return(d_interp)
}

synchronize_timestep <- function(d,
                                 precip_interp_method = NULL,
                                 impute_limit = NULL,
                                 admit_NAs = FALSE,
                                 paired_p_and_pchem = FALSE,
                                 allow_pre_interp = FALSE,
                                 prodname_ms_ = get('prodname_ms')){

    #d is a df/tibble with columns: datetime (POSIXct), site_code, var, val, ms_status
    #precip_interp_method: either "zero" for 0-interpolation, or "mean_nocb", which
    #   fills gaps assuming that each recorded sample is an aggregate of equal-volume
    #   samples over the preceding, unobserved days. nocb = "next observation carried backward".
    #   20240531: This is actually just a general-purpose override. doesn't apply only to
    #   precip/pchem and can be used to force any available method.
    #impute_limit: numeric or NULL. the maximum number of consecutive points to
    #   inter/extrapolate. it's passed to imputeTS::na_interpolate. if NULL,
    #   determined programmatically, based on interval and prodname.
    #admit_NAs: logical. if TRUE, allow NA values in `d`. for precipitation data,
    #   these will be imputed via get_nldas_precip. For precip_chemistry,
    #   these will be linearly interpolated. Both imputations occur after
    #   `d` has been aggregated to daily. If FALSE, the presence of NA
    #   values in `d` results in an error. [DEPRECATED (DISCONNECTED. DOES NOTHING)]
    #paired_p_and_pchem: logical. if TRUE (e.g. bear, loch_vale, sleepers),
    #   and pre_interp = TRUE, pre-interpolation will occur before data
    #   are coerced to daily. see pre_interp.
    #allow_pre_interp: logical. if TRUE, an initial round of interpolation is allowed
    #   to occur for select values before full interpolation occurs. this is only
    #   used for precipitation and precip_chemistry where meaningful NAs
    #   exist in the raw data and should be filled, either with NLDAS precip data
    #   or by linear interpolation (pchem) before the typical zero/nocb interpolation
    #   occurs
    #prodname_ms_: obsolete? some sort of override

    #output will include a numeric binary column called "ms_interp".
    #0 for not interpolated, 1 for interpolated. This column may already be
    #present in d. If so, it may be modified.

    if(nrow(d) < 2 || sum(! is.na(d$val)) < 2){
        stop('no data to synchronize. bypassing processing.')
    }

    # if(! precip_interp_method %in% c('zero', 'mean_nocb')){
    #     stop('precip_interp_method must be either "zero" or "mean_nocb"')
    # }

    # if(! admit_NAs && any(is.na(d$val))){
    #     stop('NAs present in d and admit_NAs = FALSE')
    # }

    #for some precip/pchem datasets, ms_interp will already be supplied by now,
    #so on 20240508 this func was updated to expect that column
    if(! 'ms_interp' %in% colnames(d)){
        d$ms_interp <- 0
    }

    #split dataset by site and variable. for each, determine whether we're
    #   dealing with ~daily data or ~15min data. set rounding_intervals
    #   accordingly. This approach avoids OOM errors with giant groupings.
    d_split <- d %>%
        group_by(site_code, var) %>%
        arrange(datetime) %>%
        dplyr::group_split() %>%
        as.list()

    mode_intervals_m <- vapply(
        X = d_split,
        FUN = function(x) Mode(diff(as.numeric(x$datetime)) / 60),
        FUN.VALUE = 0)

    rounding_intervals <- case_when(
        is.na(mode_intervals_m) | mode_intervals_m > 12 * 60 ~ '1 day',
        mode_intervals_m <= 12 * 60 ~ '1 day') #TODO, switch this back if we ever go sub-daily
        # mode_intervals_m <= 12 * 60 ~ '15 min')

    already_warned <- FALSE
    for(i in 1:length(d_split)){

        sitevar_chunk <- d_split[[i]]

        n_dupes <- sum(duplicated(sitevar_chunk$datetime) |
                       duplicated(sitevar_chunk$datetime,
                                  fromLast = TRUE))

        #average values for duplicate timestamps
        if(n_dupes > 0){

            # if(! already_warned){
            logwarn(msg = glue('averaging {n} duplicate datetimes found for site: {s}',
                               n = n_dupes,
                               s = sitevar_chunk$site_code[1]),
                               # v = sitevar_chunk$var[1]),
                    logger = logger_module)
            # }

            # already_warned <- TRUE

            sitevar_chunk_dt <- sitevar_chunk %>%
                mutate(val_err = errors(val),
                       val = errors::drop_errors(val)) %>%
                as.data.table()

            #take the mean value for any duplicate timestamps
            sitevar_chunk <- sitevar_chunk_dt[, .(
                site_code = data.table::first(site_code),
                var = data.table::first(var),
             #data.table doesn't work with the errors package, but we're
             #determining the uncertainty of the mean by the same method here:
             #    max(SDM, mean(uncert)),
             #    where SDM is the Standard Deviation of the Mean.
             #The one difference is that we remove NAs when computing
             #the standard deviation. Rationale: 1. This will only result in
             #"incorrect" error values if there's an NA error coupled with a
             #non-NA value (if the value is NA, the error must be too).
             #I don't think this happens very often, if ever.
             #2. an error of NA just looks like 0 error, which is more misleading
             #than even a wild nonzero error.
                val_err = max(sd_or_0(val, na.rm = TRUE) / sqrt(.N),
                              mean(val_err, na.rm = TRUE)),
                val = mean(val, na.rm = TRUE),
                ms_status = numeric_any(ms_status),
                ms_interp = numeric_any(ms_interp)
             ), keyby = datetime] %>%
                as_tibble() %>%
                mutate(val = set_errors(val, val_err)) %>%
                select(-val_err)
        }

        #estimating daily discharge via the trapezoidal rule as of 20240628
        var_is_q <- drop_var_prefix(sitevar_chunk$var[1]) == 'discharge'
        if(var_is_q){
            sitevar_chunk <- aggregate_subdaily_q(sitevar_chunk)
        }

        #round each site-variable tibble's datetime column to the desired interval.
        sitevar_chunk <- mutate(sitevar_chunk,
                                datetime = lubridate::floor_date(
                                    x = datetime,
                                    unit = rounding_intervals[i]))

        #split chunk into subchunks. one has duplicate datetimes to summarize,
        #   and the other doesn't. both will be interpolated in a bit.
        to_summarize_bool <- duplicated(sitevar_chunk$datetime) |
            duplicated(sitevar_chunk$datetime,
                       fromLast = TRUE)

        summary_and_interp_chunk <- sitevar_chunk[to_summarize_bool, ]
        interp_only_chunk <- sitevar_chunk[! to_summarize_bool, ]

        #careful (see below) if you ever mess with the following two lines
        var_is_p <- drop_var_prefix(sitevar_chunk$var[1]) == 'precipitation'
        var_is_pchem <- prodname_from_prodname_ms(prodname_ms_) %in% c('precip_chemistry', 'precip_isotopes')

        if(nrow(summary_and_interp_chunk)){

            #summarize by sum for P, and mean for everything else.
            #sub-daily discharge has already been aggregated to daily using trapezoidal
            #method, so this is a no-op

            summary_and_interp_chunk_dt <- summary_and_interp_chunk %>%
                mutate(val_err = errors(val),
                       val = errors::drop_errors(val)) %>%
                as.data.table()

            sitevar_chunk <- summary_and_interp_chunk_dt[, .(
                site_code = data.table::first(site_code),
                var = data.table::first(var),
                val_err = if(var_is_p)
                    {
                    #the errors package uses taylor series expansion here.
                    #maybe implement some day.
                        sum(val_err, na.rm = TRUE)
                    } else {
                        max(sd_or_0(val, na.rm = TRUE) / sqrt(.N),
                            mean(val_err, na.rm = TRUE))
                    },
                val = if(var_is_p) sum(val, na.rm = FALSE) else mean(val, na.rm = TRUE),
                ms_status = numeric_any(ms_status),
                ms_interp = numeric_any(ms_interp)
            ), by = datetime] %>%
                as_tibble() %>%
                mutate(val = set_errors(val, val_err)) %>%
                select(-val_err) %>%
                bind_rows(interp_only_chunk) %>%
                arrange(datetime)
        }

        sitevar_chunk$val[is.nan(sitevar_chunk$val)] <- NA_real_

        # nas_present <- any(is.na(sitevar_chunk$val))
        # if(! admit_NAs && nas_present) stop('should never happen')
        # if(nas_present && ! var_is_p && ! var_is_pchem) stop('should never happen')

        if(allow_pre_interp){

            if(! is.null(impute_limit)) stop('custom impute_limit not yet implemented for pre-interp')

            sitevar_chunk$ms_interp[is.na(sitevar_chunk$val)] <- 1

            sample_interval_d <- mode_intervals_m[i] / 60 / 24
            nsamp_to_interp <- 45 %/% sample_interval_d

            if(var_is_p){
                sitevar_chunk <- pre_interp_precip(sitevar_chunk)
            } else if(var_is_pchem){
                sitevar_chunk <- ms_linear_interpolate(sitevar_chunk,
                                                       maxgap = nsamp_to_interp)
            } else {
                stop('allow_pre_interp and paired_p_and_pchem should only be used for precipitation or precip_chemistry data')
            }
        }

        sitevar_chunk <- populate_implicit_NAs(
            d = sitevar_chunk,
            ms_status_fill = NA,
            interval = rounding_intervals[i])

        if(! var_is_p && ! var_is_pchem){
            interp_type <- 'linear'
        } else if(var_is_p && is.null(precip_interp_method)){
            interp_type <- 'zero' #var_is_p and var_is_pchem can both be true. strange, but manageable
        } else if(var_is_pchem && is.null(precip_interp_method)){
            interp_type <- 'nocb'
        } else {
            interp_type <- precip_interp_method
        }

        d_split[[i]] <- ms_daily_interpolate(
            type = interp_type,
            d = sitevar_chunk,
            interval = rounding_intervals[i],
            maxgap = impute_limit)

        #set ms_interp back to 0 for any NAs that were not interped
        d_split[[i]]$ms_interp[is.na(d_split[[i]]$val)] <- 0
    }

    #recombine list of tibbles into single tibble
    d <- d_split %>%
        purrr::reduce(bind_rows) %>%
        arrange(site_code, var, datetime) %>%
        select(datetime, site_code, var, val, ms_status, ms_interp)

    return(d)
}

aggregate_subdaily_q <- function(d){

    #uses pseudo trapezoidal rule to estimate daily discharge from
    #sub-daily (porentially irregular) sampling intervals.

    #if interval is not sub-daily, nothing to do here
    if(ms_determine_data_interval(d) >= 1440){
        message('no sub-daily Q to aggregate')
        return(d)
    } else {
        message('AGGREGATING SUB-DAILY Q')
    }

    d <- filter(d, ! is.na(val))

    first_midnight <- floor_date(min(d$datetime), unit = 'day') + days()
    last_midnight <- floor_date(max(d$datetime), unit = 'day')

    #insert and interpolate midnights
    d <- d %>%
        arrange(datetime) %>%
        tidyr::complete(datetime = seq(first_midnight, last_midnight, by = 'day'),
                        fill = list(site_code = d$site_code[1],
                                    var = d$var[1],
                                    ms_status = 0,
                                    ms_interp = 0)) %>%
        arrange(datetime) %>% #`complete` jumbles the order
        mutate(val = imputeTS::na_interpolation(val, maxgap = 1, rule = 1))

    first_dt <- min(d$datetime)
    last_dt <- max(d$datetime)

    #chop off incomplete first/last days
    if(format(first_dt, '%H:%M') != '00:00'){
        d <- filter(d, as.Date(datetime) != as.Date(first_dt))
    }
    if(format(last_dt, '%H:%M:%S') != c('00:00:00') &&
       ! grepl('^23:[4-5]', format(last_dt, '%H:%M'))){
        d <- filter(d,
                    as.Date(datetime) != as.Date(last_dt) |
                    format(datetime, '%H:%M:%S') == '00:00:00')
    }

    #pseudo-trapezoid rule to integrate discharge by second and bin it by day
    d <- d %>%
        mutate(next_dt = lead(datetime, 1, default = last(datetime)),
               time_diff = as.numeric(difftime(next_dt, datetime, units = 'sec')),
               #value for each interval becomes the average between it and the
               #next, weighted by the duration of the interval in seconds.
               liters = (val + lead(val, default = last(val))) / 2 * time_diff) %>%
        select(-val) %>%

        # group_by(datetime = floor_date(datetime, unit = 'day')) %>%
        # summarize(site_code = first(site_code),
        #           var = first(var),
        #           val = sum(liters),
        #           ms_status = numeric_any(ms_status),
        #           ms_interp = numeric_any(ms_interp),
        #           .groups = 'drop') %>%
        # mutate(val = val / 86400)

        mutate(liters_err = errors(liters),
               liters = errors::drop_errors(liters)) %>%
        #see parent function for explanation of what's going on here with error
        as.data.table() %>%
        .[, .(
            site_code = data.table::first(site_code),
            var = data.table::first(var),
            liters_err = max(sd_or_0(liters, na.rm = TRUE) / sqrt(.N),
                          mean(liters_err, na.rm = TRUE)),
            val = sum(liters),
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp)
        ), by = .(datetime = floor_date(datetime, unit = 'day'))] %>%
        as_tibble() %>%
        mutate(val = set_errors(val, liters_err),
               val = val / 86400) %>%
        select(-liters_err) %>%
        filter(! is.na(val))

    if(drop_errors(last(d$val)) == 0) d <- slice(d, -n())

    return(d)
}

pre_interp <- function(d, type){

    #type: character. either "NLDAS" for precipitation data or "linear" for pchem

    if(! type %in% c('NLDAS', 'linear')){
        stop('type must be "NLDAS" or "linear"')
    }

    meaningful_NA_sentinel <- -13254
    filter(d, val == meaningful_NA_sentinel)

    if(type == 'NLDAS'){
        get_nldas_precip(lat, lon, startdate = NULL, enddate = NULL)
    } else {
        ms_linear_interpolate()
    }

    return(d)
}

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

ms_parallelize <- function(maxcores = Inf){

    #maxcores is the maximum number of processor cores to use for R tasks.
    #   you may want to leave a few aside for other processes.

    #value: a cluster object. you'll need this to return to serial mode and
    #   free up the cores that were employed by R. Be sure to run
    #ms_unparallelize() after the parallel tasks are complete.

    #we need to find a way to protect some cores for serving the portal
    #if we end up processing data and serving the portal on the same
    #machine/cluster. we can use taskset to assign the shiny process
    #to 1-3 cores and this process to any others.

    #NOTE: this function has been updated to work with doFuture, which
    #   supplants doParallel. doFuture allows us to dispatch jobs on a cluster
    #   via Slurm. it might also allow us to dispatch multisession jobs on
    #   Windows

    #obsolete-ish notes:
    # #variables used inside the foreach loop on the master process will
    # #be written to the global environment, in some cases overwriting needed
    # #globals. we can set them aside in a separate environment and restore them later
    # protected_vars <- c('prodname_ms', 'verbose', 'site_code')
    # assign(x = 'protected_vars',
    #        val = mget(protected_vars,
    #                   ifnotfound = list(NULL, NULL, NULL),
    #                   inherits = TRUE),
    #        envir = protected_environment)

    #then set up parallelization
    # clst <- parallel::makeCluster(ncores)
    clst <- NULL
    ncores <- min(parallel::detectCores(), maxcores)

    if(ms_instance$which_machine == 'DCC'){
        doFuture::registerDoFuture()
        # future::plan(cluster, workers = clst) #might need this instead of Slurm one day
        future::plan(future.batchtools::batchtools_slurm)
    } else if(.Platform$OS.type == 'windows'){
        #issues (found while testing on linux):
        #1. inner precip logging waits till outer loop completes, then only prints to console.
        #2. konza error that doesn't occur with FORK cluster:
        #   task 1 failed - "task 2 failed - "unused argument (datetime_x = datetime)"
        #3. not fully utilizing cores like FORK does
        doFuture::registerDoFuture()
        # clst <- parallel::makeCluster(ncores)
        future::plan(multisession, workers = ncores)
         #clst <- parallel::makeCluster(ncores, type = 'PSOCK')
    } else {
        # future::plan(multicore) #can't be done from Rstudio
        clst <- parallel::makeCluster(ncores, type = 'FORK')
        doParallel::registerDoParallel(clst)
    }

    return(clst)
}

get_env_by_variable <- function(x){

    xobj <- deparse(substitute(x))
    gobjects <- ls(envir = .GlobalEnv)
    envirs <- gobjects[sapply(gobjects, function(x) is.environment(get(x)))]
    envirs <- c('.GlobalEnv', envirs)
    xin <- sapply(envirs, function(e) xobj %in% ls(envir = get(e)))
    return(envirs[xin])
}

idw_parallel_combine <- function(d1, d2){

    #this is for use with foreach loops inside the 4 idw prep functions
    #   (precip_idw, pchem_idw, flux_idw, precip_pchem_pflux_idw)

    if(is.character(d1) && d1 == 'first iter') return(d2)

    d_comb <- bind_rows(d1, d2)

    return(d_comb)
}

idw_log_wb <- function(verbose, site_code, i, nw){

    if(! verbose) return()

    msg <- glue('site: {s} ({ii}/{w})',
                s = site_code,
                ii = i,
                w = nw)

    loginfo(msg,
            logger = logger_module)
}

idw_log_var <- function(verbose,
                        site_code,
                        v,
                        j,
                        nvars,
                        ntimesteps,
                        is_fluxable = NA,
                        note = ''){

    if(! verbose) return()

    flux_calc_msg <- case_when(is_fluxable == FALSE ~ '[NO FLUX]',
                     is_fluxable == TRUE ~ '[yes flux]',
                     is.na(is_fluxable) ~ '')

    note <- ifelse(note == '',
                   note,
                   paste0('[', note, ']'))

    msg <- glue('site: {s}; var: {vv} ({jj}/{nv}) {f}; timesteps: {nt}; {n}',
                s = site_code,
                vv = v,
                jj = j,
                nv = nvars,
                nt = ntimesteps,
                f = flux_calc_msg,
                n = note)

    loginfo(msg,
            logger = logger_module)
}

idw_log_timestep <- function(verbose, site_code=NULL, v, k, ntimesteps,
                             time_elapsed){

    #time elapsed must be in minutes. use something like:
    #   (proc.time() - ptm)[3] / 60)

    if(! verbose) return()

    time_elapsed <- ifelse(k == 0,
                           '?',
                           time_elapsed)

    estimated_time_remaining <- ifelse(k == 0,
                                       '?',
                                       round(time_elapsed * (ntimesteps - k) / k,
                                             1))

    if(k == 1 || k %% 1000 == 0){
        msg <- glue('site: {s}; var: {vv}; timestep: ({kk}/{nt}); ',
                    'thread elapsed (mins): {et}; thread ETA (mins): {tm}',
                    s = site_code,
                    vv = v,
                    kk = k,
                    nt = ntimesteps,
                    et = round(time_elapsed, 1),
                    tm = estimated_time_remaining)

        loginfo(msg,
                logger = logger_module)
    }
}

datetimes_to_durations <- function(datetime_vec,
                                   variable_prefix_vec = NULL,
                                   unit,
                                   sensor_maxgap = Inf,
                                   nonsensor_maxgap = Inf,
                                   grab_maxgap = Inf,
                                   installed_maxgap = Inf){

    #datetime_vec: POSIXct. a vector of datetimes
    #variable_prefix_vec: POSIXct. a vector of macrosheds variable prefixes,
    #   e.g. 'IS'. This vector is generated by calling extract_var_prefix
    #   on the var column of a macrosheds data.frame. Only required if you
    #   supply one or more of the maxgap parameters.
    #unit: string. The desired datetime unit. Must be expressed in a form
    #   that's readable by base::difftime
    #sensor_maxgap: numeric. the largest data gap that should return
    #   a value. Durations longer than this gap will return NA. Expressed in
    #   the same units as unit (see above). This applies
    #   to sensor data only (IS and GS).
    #nonsensor_maxgap: numeric. the largest data gap that should return
    #   a value. Durations longer than this gap will return NA. Expressed in
    #   the same units as unit (see above). This applies
    #   to nonsensor data only (IN and GN).
    #grab_maxgap: numeric. the largest data gap that should return
    #   a value. Durations longer than this gap will return NA. Expressed in
    #   the same units as unit (see above). This applies
    #   to grab data only (GS and GN).
    #installed_maxgap: numeric. the largest data gap that should return
    #   a value. Durations longer than this gap will return NA. Expressed in
    #   the same units as unit (see above). This applies
    #   only to data from installed units (IS and IN).

    #an NA is prepended to the output, so that its length is the same as
    #   datetime_vec

    if(! is.null(variable_prefix_vec) &&
       ! all(variable_prefix_vec %in% c('GN', 'GS', 'IN', 'IS'))){
        stop(paste('all elements of variable_prefix_vec must be one of "GN",',
                   '"GS", "IN", "IS"'))
    }

    durs <- diff(datetime_vec)
    units(durs) <- unit
    durs <- c(NA_real_, as.numeric(durs))

    if(! is.null(variable_prefix_vec)){
        is_sensor_data <- grepl('^.S', variable_prefix_vec)
        is_installed_data <- grepl('^I', variable_prefix_vec)
    }

    if(! is.infinite(sensor_maxgap)){
        durs[is_sensor_data & durs > sensor_maxgap] <- NA_real_
    }
    if(! is.infinite(nonsensor_maxgap)){
        durs[! is_sensor_data & durs > nonsensor_maxgap] <- NA_real_
    }
    if(! is.infinite(grab_maxgap)){
        durs[! is_installed_data & durs > grab_maxgap] <- NA_real_
    }
    if(! is.infinite(installed_maxgap)){
        durs[is_installed_data & durs > installed_maxgap] <- NA_real_
    }

    return(durs)
}

calculate_dem_res <- function(area_ha, lat, ideal_n_cells){

    if(is.na(area_ha) || is.null(area_ha) || is.infinite(area_ha)) stop('illegal area_ha')

    area_sq_m <- area_ha * 1e4

    get_ground_res <- function(z, lat){
        cos(lat * pi / 180) * 2 * pi * 6378137 / (256 * 2^z)
    }
    calc_cells <- function(area, res) (sqrt(area) / res)^2

    zoom_levels <- 0:14
    res_diffs <- sapply(
        zoom_levels,
        function(zz){
            abs(calc_cells(area_sq_m, get_ground_res(zz, lat)) - ideal_n_cells)
        })

    return(zoom_levels[which.min(res_diffs)])
}

precip_pchem_pflux_idw <- function(pchem_prodname,
                                   precip_prodname,
                                   wb_prodname,
                                   pgauge_prodname,
                                   prodname_ms,
                                   # flux_prodname_out,
                                   verbose = TRUE,
                                   filter_sites = NULL,
                                   donor_domain = NULL){

    #filter_sites: useful for e.g. neon where sites are strewn everywhere and
    #    you wouldn't want to interpolate all gauges together. a list of:
    #       'precip': character vector of precip gauge ids
    #       "wb": character vector of site_codes (i.e. names of watershed boundaries)
    #donor_domain: named character vector of length 1. name is the donor network,
    #   and value is the donor domain. this applies when gauges for a different
    #   domain are the source of precip data for the domain being interpolated.
    #   (primary domain is taken from globally defined `network` and `domain`).
    #precip_pchem_pflux_skip_existing: logical. if TRUE, don't rebuild files that already exist.
    #   this parameter is controlled by ms_derive

    # if(! length(pchem_prodname)) stop('missing pchem_prodname')
    # if(! length(precip_prodname)) stop('missing precip_prodname')
    if(! length(wb_prodname)) stop('missing wb_prodname')
    if(! length(pgauge_prodname)) stop('missing pgauge_prodname')

    source_network <- ifelse(is.null(donor_domain),
                             network,
                             names(donor_domain))
    source_domain <- ifelse(is.null(donor_domain),
                            domain,
                            unname(donor_domain))

    #load watershed boundaries, rain gauge locations, precip and pchem data
    wb <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = wb_prodname)
    rg <- read_combine_shapefiles(network = source_network,
                                  domain = source_domain,
                                  prodname_ms = pgauge_prodname)

    if(! is.null(filter_sites)){
        wb <- filter(wb, site_code %in% filter_sites$wb)
        rg <- filter(rg, site_code %in% filter_sites$precip)
    }

    if(exists('precip_pchem_pflux_skip_existing') && precip_pchem_pflux_skip_existing){
        dd_ <- glue('data/{network}/{domain}/derived')
        dfs_ <- list.files(dd_, full.names = TRUE)
        if(any(grepl('precip_chemistry__ms901', dfs_))){
            fs_ <- list.files(file.path(dd_, 'precip_chemistry__ms901'))
            fs_ <- str_extract(fs_, '.+(?=\\.feather$)')
            message('skipping ', paste(fs_, collapse = ', '), ' because precip_pchem_pflux_skip_existing is TRUE')
            wb <- filter(wb, ! site_code %in% fs_)
            if(! nrow(wb)) return()
        }
    }

    pchem <- try({
        read_combine_feathers(network = source_network,
                              domain = source_domain,
                              prodname_ms = pchem_prodname) %>%
            filter(site_code %in% rg$site_code)
    }, silent = TRUE)

    precip_only <- FALSE
    if('try-error' %in% class(pchem) || nrow(pchem) == 0){
        precip_only <- TRUE
        logging::logwarn('No (or empty) pchem product. IDW-Interpolating precipitation only')
    } else if(! is.null(filter_sites)){
        pchem <- filter(pchem, site_code %in% filter_sites$precip)
    }

    precip <- try({
        read_combine_feathers(network = source_network,
                              domain = source_domain,
                              prodname_ms = precip_prodname) %>%
            filter(site_code %in% rg$site_code)
    }, silent = TRUE)

    pchem_only <- FALSE
    if('try-error' %in% class(precip) || nrow(precip) == 0){
        pchem_only <- TRUE
        if(precip_only) stop('Nothing to IDW interpolate. Is this kernel needed?')
        logging::logwarn('No (or empty) precip product. IDW-Interpolating pchem only')
    } else if(! is.null(filter_sites)){
        precip <- filter(precip, site_code %in% filter_sites$precip)
    }

    #project based on average latlong of watershed boundaries
    bbox <- as.list(sf::st_bbox(wb))
    projstring <- choose_projection(lat = mean(bbox$ymin, bbox$ymax),
                                    long = mean(bbox$xmin, bbox$xmax))
    wb <- sf::st_transform(wb, projstring)
    rg <- sf::st_transform(rg, projstring)

    #get a DEM that encompasses all watersheds and gauges
    wb_rg_bbox <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(bind_rows(wb, rg))))

    if(is.null(wb$area) || any(is.na(wb$area))) stop('missing "area" column in wb shapefile')

    # dem_res <- ifelse(any(wb$area < 5), 9, 8)
    dem_res <- calculate_dem_res(area_ha = min(wb$area),
                                 lat = mean(bbox$ymin, bbox$ymax),
                                 ideal_n_cells = 100)

    dem_res <- min(9, dem_res) #not looking for high-res tiny watersheds.

    dem <- expo_backoff(
        expr = {
            elevatr::get_elev_raster(locations = wb_rg_bbox,
                                     z = dem_res,
                                     clip = 'bbox',
                                     expand = 200,
                                     verbose = FALSE,
                                     override_size_check = TRUE)
        },
        max_attempts = 5
    )

    #add elev column to rain gauges
    rg$elevation <- terra::extract(dem, rg)

    #this avoids a lot of slow summarizing
    if(! pchem_only){

        status_cols <- precip %>%
            select(datetime, ms_status, ms_interp) %>%
            group_by(datetime) %>%
            summarize(
                ms_status = numeric_any(ms_status),
                ms_interp = numeric_any(ms_interp),
                .groups = 'drop')

        mode_samp_regimen <- precip %>%
            mutate(prefix = extract_var_prefix(var)) %>%
            select(datetime, prefix) %>%
            group_by(datetime) %>%
            summarize(prefix = Mode(prefix),
                      .groups = 'drop')

        day_durations_byproduct <- datetimes_to_durations(
            datetime_vec = precip$datetime,
            variable_prefix_vec = extract_var_prefix(precip$var),
            unit = 'days',
            installed_maxgap = 2,
            grab_maxgap = 30)

        precip$val[is.na(day_durations_byproduct)] <- NA

        precip <- precip %>%
            select(-ms_status, -ms_interp, -var) %>%
            tidyr::pivot_wider(names_from = site_code,
                               values_from = val) %>%
            left_join(status_cols, #they get lumped anyway
                      by = 'datetime') %>%
            left_join(mode_samp_regimen, #they get lumped anyway
                      by = 'datetime') %>%
            arrange(datetime)

        day_durations <- datetimes_to_durations(
            datetime_vec = precip$datetime,
            unit = 'days')
    }

    if(! precip_only){

        #determine which variables can be flux converted (prefix handling clunky here)
        flux_vars <- ms_vars$variable_code[as.logical(ms_vars$flux_convertible)]
        pchem_vars <- unique(pchem$var)
        pchem_vars_fluxable0 <- base::intersect(drop_var_prefix(pchem_vars),
                                                flux_vars)
        pchem_vars_fluxable <- pchem_vars[drop_var_prefix(pchem_vars) %in%
                                              pchem_vars_fluxable0]

        #this avoids a lot of slow summarizing
        status_cols <- pchem %>%
            select(datetime, ms_status, ms_interp) %>%
            group_by(datetime) %>%
            summarize(
                ms_status = numeric_any(ms_status),
                ms_interp = numeric_any(ms_interp))

        #clean pchem one variable at a time, matrixify it, insert it into list
        nvars <- length(pchem_vars)
        pchem_setlist <- as.list(rep(NA, nvars))
        for(i in 1:nvars){

            v <- pchem_vars[i]

            #clean data and arrange for matrixification
            pchem_setlist[[i]] <- pchem %>%
                filter(var == v) %>%
                select(-var, -ms_status, -ms_interp) %>%
                tidyr::pivot_wider(names_from = site_code,
                                   values_from = val) %>%
                left_join(status_cols,
                          by = 'datetime') %>%
                arrange(datetime)
        }
    } #end conditional pchem+pflux block (1)

    #make sure old quickref data aren't still sitting around
    unlink(glue('data/{n}/{d}/precip_idw_quickref',
                n = network,
                d = domain),
           recursive = TRUE)

    #send vars into interpolator with precip, one at a time. if var is flux-
    #convertible, interpolate precip, pchem, and pflux. otherwise, just precip
    #and pchem. combine and write outputs by site

    # # FOR TESTING (most hideous code ever written)
    # test_switch = 1 #either 1 or 2
    # if(! precip_only){
    #     if(test_switch == 1){
    #         fo <- pre_idw_filter_for_testing(pchem_setlist, precip_only, length_days = 90)
    #         if(! is.null(fo$x)){
    #             pchem_setlist <- fo$x
    #             if(length(fo$drop_these)){
    #                 pchem_vars_fluxable = pchem_vars_fluxable[-fo$drop_these]
    #             }
    #             nvars = length(pchem_setlist)
    #         }
    #         fo2 <- pre_idw_filter_for_testing(precip, precip_only,
    #                                           daterange = fo$daterange,
    #                                           length_days = 90)
    #         precip = fo2$x
    #     } else if(test_switch == 2){
    #         fo <- pre_idw_filter_for_testing(precip, precip_only, length_days = 90)
    #         precip = fo$x
    #         fo2 <- pre_idw_filter_for_testing(pchem_setlist, precip_only,
    #                                           daterange = fo$daterange,
    #                                           length_days = 90)
    #         pchem_setlist = fo2$x
    #         nvars = length(pchem_setlist)
    #     }
    #
    # } else {
    #     fo2 <- pre_idw_filter_for_testing(precip, precip_only, length_days = 90)
    #     precip = fo2$x
    # }

    # if(nrow(precip) == 0){
    #     stop('the test code removed all the precip data. change test_switch')
    # }

    for(i in 1:nrow(wb)){

        wbi <- slice(wb, i)
        site_code <- wbi$site_code
        wbi_area_ha <- as.numeric(sf::st_area(wbi)) / 10000

        idw_log_wb(verbose = verbose,
                   site_code = site_code,
                   i = i,
                   nw = nrow(wb))

        nthreads <- parallel::detectCores()

        ## IDW INTERPOLATE PRECIP FOR ALL TIMESTEPS. STORE CELL VALUES
        ## SO THEY CAN BE USED FOR PFLUX INTERP
        if(! pchem_only){

            ntimesteps_precip <- nrow(precip)
            nsuperchunks <- ceiling(ntimesteps_precip / 25000 * 2)
            nchunks_precip <- nthreads * nsuperchunks

            precip_superchunklist <- chunk_df(d = precip,
                                              nchunks = nsuperchunks,
                                              create_index_column = TRUE)

            ws_mean_precip <- tibble()
            for(s in 1:length(precip_superchunklist)){

                precip_superchunk <- precip_superchunklist[[s]]

                precip_chunklist <- chunk_df(d = precip_superchunk,
                                             nchunks = nthreads,
                                             create_index_column = FALSE)

                idw_log_var(verbose = verbose,
                            site_code = site_code,
                            v = 'precipitation',
                            j = paste('chunk', s),
                            ntimesteps = nrow(precip_superchunk),
                            nvars = nsuperchunks)

                clst <- ms_parallelize(maxcores = nthreads)
                # doFuture::registerDoFuture()
                # ncores <- min(parallel::detectCores(), maxcores)
                # clst <- parallel::makeCluster(nthreads, type='FORK')
                # future::plan(future::multicore, workers = 48)
                # future::plan(future::multisession, workers = 48)

                # parallel::stopCluster(clst)
                # fe_junk <- foreach:::.foreachGlobals
                # rm(list = ls(name = fe_junk),
                #    pos = fe_junk)

                ws_mean_precip_chunk <- foreach::foreach(
                    j = 1:min(nthreads, nrow(precip_superchunk)),
                    .combine = idw_parallel_combine,
                    .init = 'first iter') %dopar% {

                    pchunk <- precip_chunklist[[j]]

                    foreach_return <- shortcut_idw(
                        encompassing_dem = dem,
                        wshd_bnd = wbi,
                        data_locations = rg,
                        data_values = pchunk,
                        durations_between_samples = day_durations[pchunk$ind],
                        stream_site_code = site_code,
                        output_varname = 'SPECIAL CASE PRECIP',
                        save_precip_quickref = ! precip_only,
                        elev_agnostic = FALSE,
                        verbose = verbose)

                    foreach_return
                }

                ms_unparallelize(clst)

                rm(precip_chunklist); gc()

                ws_mean_precip <- bind_rows(ws_mean_precip, ws_mean_precip_chunk)
            }

            rm(precip_superchunklist); gc()

            if(any(is.na(ws_mean_precip$datetime))){
                stop('NA datetime found in ws_mean_precip')
            }

            ws_mean_precip <- ws_mean_precip %>%
                dplyr::rename_all(dplyr::recode, concentration = 'val') %>%
                arrange(datetime)

            write_ms_file(ws_mean_precip,
                          network = network,
                          domain = domain,
                          prodname_ms = 'precipitation__ms900',
                          site_code = site_code,
                          level = 'derived',
                          shapefile = FALSE,
                          link_to_portal = FALSE)

            rm(ws_mean_precip); gc()
        }

        ## NOW IDW INTERPOLATE PCHEM (IF PRECIP CHEMISTRY DATA EXIST)
        ## AND PFLUX (FOR VARIABLES THAT ARE FLUXABLE).
        if(! precip_only){

            ws_mean_chemflux <- tibble()
            for(j in 1:nvars){

                v <- pchem_vars[j]
                jd <- pchem_setlist[[j]]
                ntimesteps_chemflux <- nrow(jd)

                if(v %in% pchem_vars_fluxable && ! pchem_only){
                    is_fluxable <- TRUE
                } else {
                    is_fluxable <- FALSE
                }

                idw_log_var(verbose = verbose,
                            site_code = site_code,
                            v = v,
                            j = paste('var', j),
                            nvars = nvars,
                            ntimesteps = ntimesteps_chemflux,
                            is_fluxable = is_fluxable)

                nsuperchunks <- ceiling(ntimesteps_chemflux / 5000 * 2)
                nchunks_chemflux <- nthreads * nsuperchunks

                chemflux_superchunklist <- chunk_df(d = jd,
                                                    nchunks = nsuperchunks)
                nsuperchunks <- length(chemflux_superchunklist)

                ws_mean_chemflux_var <- tibble()
                for(s in 1:nsuperchunks){

                    chemflux_superchunk <- chemflux_superchunklist[[s]]

                    chemflux_chunklist <- chunk_df(d = chemflux_superchunk,
                                                   nchunks = nthreads)

                    idw_log_var(verbose = verbose,
                                site_code = site_code,
                                v = v,
                                j = paste('chunk', s),
                                ntimesteps = nrow(chemflux_superchunk),
                                nvars = nsuperchunks)

                    clst <- ms_parallelize(maxcores = nthreads)

                    foreach_out <- foreach::foreach(
                        l = 1:length(chemflux_chunklist),
                        # l = 1:min(nthreads, nrow(chemflux_superchunk)),
                        .combine = idw_parallel_combine,
                        .init = 'first iter') %dopar% {

                            if(is_fluxable){

                                foreach_chunk <- shortcut_idw_concflux_v2(
                                    encompassing_dem = dem,
                                    wshd_bnd = wbi,
                                    ws_area = wbi_area_ha,
                                    data_locations = rg,
                                    precip_values = precip,
                                    chem_values = chemflux_chunklist[[l]],
                                    stream_site_code = site_code,
                                    output_varname = v,
                                    verbose = verbose)

                            } else {

                                foreach_chunk <- shortcut_idw(
                                    encompassing_dem = dem,
                                    wshd_bnd = wbi,
                                    data_locations = rg,
                                    data_values = chemflux_chunklist[[l]],
                                    stream_site_code = site_code,
                                    output_varname = v,
                                    elev_agnostic = TRUE,
                                    verbose = verbose)
                            }

                            foreach_chunk
                        }

                        ms_unparallelize(clst)


                    rm(chemflux_chunklist); gc()

                    ws_mean_chemflux_var <- bind_rows(ws_mean_chemflux_var,
                                                      foreach_out)
                }

                rm(chemflux_superchunklist); gc()

                ws_mean_chemflux <- bind_rows(ws_mean_chemflux,
                                              ws_mean_chemflux_var)
            }

            if(any(is.na(ws_mean_chemflux$datetime))){
                stop('NA datetime found in ws_mean_chemflux')
            }

            if(! pchem_only){

                ws_mean_pflux <- ws_mean_chemflux %>%
                    select(-concentration) %>%
                    rename(val = flux) %>%
                    arrange(var, datetime)

                write_ms_file(ws_mean_pflux,
                              network = network,
                              domain = domain,
                              prodname_ms = 'precip_flux_inst__ms902',
                              site_code = site_code,
                              level = 'derived',
                              shapefile = FALSE,
                              link_to_portal = FALSE)

                rm(ws_mean_pflux)
            }

            ws_mean_pchem <- ws_mean_chemflux %>%
                select(-any_of('flux')) %>%
                rename(val = concentration) %>%
                arrange(var, datetime)

            write_ms_file(ws_mean_pchem,
                          network = network,
                          domain = domain,
                          prodname_ms = 'precip_chemistry__ms901',
                          site_code = site_code,
                          level = 'derived',
                          shapefile = FALSE,
                          link_to_portal = FALSE)

            rm(ws_mean_pchem); gc()
        } #end conditional pchem+pflux block (2)
    }

    if(! pchem_only){
        append_to_productfile(network = network,
                              domain = domain,
                              prodcode = 'ms900',
                              prodname = 'precipitation',
                              notes = 'automated entry')
    }

    if(! precip_only){
        append_to_productfile(network = network,
                              domain = domain,
                              prodcode = 'ms901',
                              prodname = 'precip_chemistry',
                              notes = 'automated entry')

        if(! pchem_only){
            append_to_productfile(network = network,
                                  domain = domain,
                                  prodcode = 'ms902',
                                  prodname = 'precip_flux_inst',
                                  notes = 'automated entry')
        }
    }

    unlink(glue('data/{n}/{d}/precip_idw_quickref',
                n = network,
                d = domain),
           recursive = TRUE)
}

ms_unparallelize <- function(cluster_object){

    #if cluster_object is NULL, nothing will happen

    if(is.null(cluster_object)){
        future::plan(future::sequential)
        return()
    }

    parallel::stopCluster(cluster_object)

    #remove foreach clutter that might compromise the next parallel run
    fe_junk <- foreach:::.foreachGlobals

    rm(list = ls(name = fe_junk),
       pos = fe_junk)
}

chunk_df <- function(d, nchunks, create_index_column = FALSE){

    nr <- nrow(d)
    chunksize <- nr/nchunks

    if(nr > 0){

        if(create_index_column) d <- mutate(d, ind = 1:n())

        chunklist <- split(d,
                           0:(nr - 1) %/% chunksize)

        return(chunklist)

    } else {

        logwarn(msg = 'Trying to chunk an empty tibble. Something is probably wrong',
                logger = logger_module)

        return(d)
    }
}

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
                                       site_code = 'sitename_NA',
                                       new_status = 'pending')
    }

    #the above relies on accurate bookkeeping in products.csv, but that is
    #unnecessary. now invalidating all discharge, special discharge, and
    #stream flux derive kernels when discharge is munged. same for precip, etc.

    derive_prods <- get_product_info(network = network,
                                     domain = domain,
                                     status_level = 'derive',
                                     get_statuses = 'ready')

    invalidate_bulk <- function(munge_cause, derive_effect){

        if(grepl(munge_cause, prodname_ms)){

            updt <- derive_prods %>%
                filter(grepl(derive_effect, prodname)) %>%
                mutate(prodname_ms = paste(prodname, prodcode, sep = '__')) %>%
                pull(prodname_ms)

            for(item in updt){
                catch <- update_data_tracker_d(network = network,
                                               domain = domain,
                                               tracker_name = 'held_data',
                                               prodname_ms = item,
                                               site_code = 'sitename_NA',
                                               new_status = 'pending')
            }
        }
    }

    invalidate_bulk('discharge', 'discharge|stream_flux')
    invalidate_bulk('stream_chemistry', 'stream_chem|stream_flux')
    invalidate_bulk('precipitation', 'precipit|precip_pchem')
    invalidate_bulk('precip_chemistry', 'precip_pchem')
}

write_metadata_r <- function(murl = NULL, network, domain, prodname_ms){

    #this writes the metadata file for retrieved macrosheds data.
    #see write_metadata_m for munged macrosheds data and write_metadata_d
    #for derived macrosheds data

    #also see read_metadata_r and read_metadata_m

    component_row <- site_doi_license %>%
        filter(network == !!network,
               domain == !!domain,
               macrosheds_prodcode == !!prodcode_from_prodname_ms(prodname_ms))

    #murl might not be a url per se, but a note like "this came from our google drive"
    if(is.null(murl)){

        murl <- component_row$link

        if(! length(murl)){
            stop('missing provenance for ', prodname_ms)
        }
    }

    last_dl <- component_row$link_download_datetime

    currency_check <- 'placeholder'
    is_hydroshare <- grepl('hydroshare\\.org', murl)
    is_edi <- grepl('portal\\.edirepository', murl)
    #is_essdive <-
    if(is_hydroshare){
        currency_check <- check_for_updates_hydroshare(murl, last_dl)
    } else if(is_edi){
        currency_check <- check_for_updates_edi(murl, last_dl)
    }

    if(grepl('^http', currency_check)){
        #new resource location
        murl <- currency_check
    }

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

    download_dt <- lubridate::with_tz(Sys.time(), 'UTC')

    readr::write_file(paste0(murl, ' (retrieved ',
                             download_dt,
                             ')'),
                      file = data_acq_file)

    manual_prov_check <- murl == 'NA' ||
        (! is_hydroshare && ! is_edi)

    if(is.character(murl) && any(manual_prov_check)){

        logwarn(msg = paste('manually verify provenance for', prodname_ms),
                logger = logger_module)

        update_prov_dt(dt = Sys.time())

        return()
    }

    if(is.character(murl) && grepl('MacroSheds drive', murl)){
        logwarn(msg = paste('MacroSheds gdrive file; manually verify provenenace for', prodname_ms),
                logger = logger_module)
        return()
    }

    dt_web_format <- paste(format(download_dt, '%Y-%m-%d %H:%M:%S'), 'UTC')
    update_provenance(murl, dt_web_format)

    return(invisible())
}

read_metadata_r <- function(network, domain, prodname_ms){

    #this reads the metadata file for retrieved macrosheds data

    #also see write_metadata_r, write_metadata_m, and write_metadata_d,
    #and read_metadata_m

    if(length(prodname_ms) != 1){
        stop('prodname_ms must be length 1')
    }

    if(prodname_ms == '<no precursors>'){
        return('N/A or Derived from lat/long (see site data table)')
    }

    murlfile <- glue('data/{n}/{d}/raw/documentation/documentation_{p}.txt',
                     n = network,
                     d = domain,
                     p = prodname_ms)

    murl <- readr::read_file(murlfile)

    return(murl)
}

read_metadata_m <- function(network, domain, prodname_ms){

    #this reads the metadata file for munged macrosheds data

    #also see write_metadata_r, write_metadata_m, and write_metadata_d,
    #and read_metadata_r

    if(length(prodname_ms) != 1){
        stop('prodname_ms must be length 1')
    }

    if(prodname_ms == '<no precursors>'){
        return('No munge kernel')
    }

    mdocf <- glue('data/{n}/{d}/munged/documentation/documentation_{p}.txt',
                  n = network,
                  d = domain,
                  p = prodname_ms)

    mdoc <- readr::read_file(mdocf)

    return(mdoc)
}

get_precursors <- function(network, domain, prodname_ms){

    #this determines which munged products were used to generate
    #a derived product

    prodfile <- glue('src/{n}/{d}/products.csv',
                     n = network,
                     d = domain)
    allprods <- sm(read_csv(prodfile)) %>%
        filter( (! is.na(munge_status) & munge_status == 'ready') |
                    (! is.na(derive_status) & derive_status == 'ready'))

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

document_kernel_code <- function(network, domain, prodname_ms, level){

    #this documents (as metadata) the code used to retrieve/munge/derive
    #macrosheds data. prodname_ms == 'ws_boundary__msXXX' is handled as
    #a special case.

    #level is numeric 0, 1, or 2, corresponding to raw, munged, derived

    if(! is.numeric(level) || ! level %in% 0:2){
        stop('level must be numeric 0, 1, or 2')
    }

    if(prodname_ms == 'ws_boundary__ms000'){
        return(paste0('For ms000, see ms_delineate, defined in\n',
                      'https://github.com/MacroSHEDS/data_processing/blob/master/src/global_helpers.R'))
    }

    kernel_file <- glue('src/{n}/{d}/processing_kernels.R',
                        n = network,
                        d = domain)

    thisenv <- environment()

    sw(source(kernel_file, local = TRUE))

    prodcode <- prodcode_from_prodname_ms(prodname_ms)
    fnc <- mget(paste0('process_', level, '_', prodcode),
                envir = thisenv,
                inherits = FALSE,
                ifnotfound = list(''))[[1]] #arg only available in mget
    kernel_func <- paste(deparse(fnc), collapse = '\n')
    func_name <- glue('process_{l}_{pc}',
                      l = level,
                      pc = prodcode_from_prodname_ms(prodname_ms))

    kernel_func <- paste(func_name,
                         kernel_func,
                         sep = ' <- ')

    return(kernel_func)
}

write_metadata_m <- function(network, domain, prodname_ms, tracker){

    #this writes the metadata file for munged macrosheds data
    #see write_metadata_r for retrieved macrosheds data and write_metadata_d
    #for derived macrosheds data

    #also see read_metadata_r and read_metadata_m

    #assemble metadata
    sitelist <- names(tracker[[prodname_ms]])
    complist <- lapply(sitelist,
                       function(x){
                           comp <- tracker[[prodname_ms]][[x]]$retrieve$component
                           if(is.null(comp)) comp <- 'NULL'
                           return(comp)
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
                         # site_code = paste0("'", site_code, "'"),
                         site_code = glue("<separately, each of: '",
                                          paste(sitelist,
                                                collapse = "', '"),
                                          "', with corresponding component>"),
                         `component(s)` = paste0('\n',
                                                 paste(compsbysite,
                                                       collapse = '\n')))

    # metadata_r <- read_metadata_r(network = network,
    #                               domain = domain,
    #                               prodname_ms = prodname_ms)

    code_m <- document_kernel_code(network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms,
                                   level = 1)

    mdoc <- read_file('src/templates/write_metadata_m_boilerplate.txt') %>%
        glue(.,
             p = prodname_ms,
             # mr = metadata_r,
             mk = code_m,
             ma = paste(names(display_args),
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
                      file = data_acq_file)

    # #create portal directory if necessary
    # portal_dir <- glue('../portal/data/{d}/documentation', #portal ignores network
    #                    d = domain)
    # dir.create(portal_dir,
    #            showWarnings = FALSE,
    #            recursive = TRUE)
    #
    # #hardlink file
    # portal_file <- glue('{pd}/documentation_{p}.txt',
    #                     pd = portal_dir,
    #                     p = prodname_ms)
    # unlink(portal_file)
    # invisible(sw(file.link(to = portal_file,
    #                        from = data_acq_file)))
}

write_metadata_d <- function(network,
                             domain,
                             prodname_ms){

    #this writes the metadata file for derived macrosheds data
    #see write_metadata_r for retrieved macrosheds data and write_metadata_m
    #for munged macrosheds data

    #also see read_metadata_r and read_metadata_m

    #assemble metadata
    display_args <- list(network = paste0("'", network, "'"),
                         domain = paste0("'", domain, "'"),
                         prodname_ms = paste0("'", prodname_ms, "'"))

    precursors <- get_precursors(network = network,
                                 domain = domain,
                                 prodname_ms = prodname_ms)

    if(length(precursors) == 1 && precursors == 'no precursors'){

        if(grepl('(^cdnr_|^usgs_)', prodname_ms)){
            return()
        } else if(! grepl('(gauge_locations|ws_boundary__ms...)', prodname_ms) &&
                  # For the case where all discharge is pulled from USGS
                  exists('prod_info') &&
                  !(grepl('discharge', prodname_ms) && sum(as.numeric(grepl('discharge', prod_info$prodname))) == 1)){
            stop(glue('really no precursors for {p}? might need to update products.csv', p = prodname_ms))
        }
    }

    precursors_m <- precursors[! is_derived_product(precursors)]
    precursors_d <- precursors[is_derived_product(precursors)]

    if(length(precursors_m) == 1 && precursors_m == 'no precursors'){
        precursors_m <- '<no precursors>'
    }

    if(length(precursors_d) & ! length(precursors_m)){

        precursors_m <- glue('<NA: all immediate precursors ({dp}) are derived products>',
                             dp = paste(precursors_d,
                                        collapse = ', '))
        urls_r <- NULL
        docs_m <- c()
        code_d <- document_kernel_code(network = network,
                                       domain = domain,
                                       prodname_ms = prodname_ms,
                                       level = 2)
    } else {

        urls_r <- sapply(precursors_m,
                         function(x){
                             read_metadata_r(network = network,
                                             domain = domain,
                                             prodname_ms = x)
                         })

        docs_m <- sapply(precursors_m,
                         function(x){
                             read_metadata_m(network = network,
                                             domain = domain,
                                             prodname_ms = x)
                         })

        code_d <- lapply(c(precursors_d, prodname_ms),
                         function(x){
                             document_kernel_code(network = network,
                                                  domain = domain,
                                                  prodname_ms = x,
                                                  level = 2)
                         })
    }

    ddoc <- read_file('src/templates/write_metadata_d_boilerplate.txt') %>%
        glue(.,
             p = prodname_ms,
             mp = paste(precursors_m,
                        collapse = '\n'),
             ru = ifelse(is.null(urls_r),
                         '<NA: See documentation for derived precursors>',
                         paste(paste0(paste0(names(urls_r),
                                             ':\n'),
                                      unname(urls_r)),
                               collapse = '\n\n')),
             flux_note = ifelse(grepl('flux', prodname_ms),
                                read_file('src/templates/flux_note.txt'),
                                ''),
             vsnless_note = ifelse(any(grepl('VERSIONLESS', precursors)),
                                   read_file('src/templates/VERSIONLESS_note.txt'),
                                   ''),
             dk = paste(code_d,
                        collapse = '\n\n'),
             da = paste(names(display_args),
                       display_args,
                       sep = ' = ',
                       collapse = '\n'),
             mb = paste(docs_m,
                        collapse = '\n\n'))

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
                      file = data_acq_file)

    # #create portal directory if necessary
    # portal_dir <- glue('../portal/data/{d}/documentation', #portal ignores network
    #                    d = domain)
    #                    # p = strsplit(prodname_ms, '__')[[1]][1])
    # dir.create(portal_dir,
    #            showWarnings = FALSE,
    #            recursive = TRUE)
    #
    # #hardlink file
    # portal_file <- glue('{pd}/documentation_{p}.txt',
    #                     pd = portal_dir,
    #                     p = prodname_ms)
    # unlink(portal_file) #this will overwrite any munged product supervened by derive
    # invisible(sw(file.link(to = portal_file,
    #                        from = data_acq_file)))
}

write_metadata_d_linkprod <- function(network,
                                      domain,
                                      prodname_ms_mr,
                                      prodname_ms_d){

    #this writes the metadata file for macrosheds linkprods.
    #see write_metadata_d for standard derived products

    #assemble metadata
    url_r <- try(read_metadata_r(network = network,
                                 domain = domain,
                                 prodname_ms = prodname_ms_mr),
                 silent = TRUE)

    if(inherits(url_r, 'try-error') || ! length(url_r)){

        if(prodname_from_prodname_ms(prodname_ms_d) == 'ws_boundary'){
            url_r <- 'NA: Derived from lat/long (see site data table)'
        } else {
            url_r <- 'NA'
        }
    }

    doc_m <- read_metadata_m(network = network,
                             domain = domain,
                             prodname_ms = prodname_ms_mr)

    if(inherits(doc_m, 'try-error') || ! length(doc_m)){

        if(prodname_from_prodname_ms(prodname_ms_d) == 'ws_boundary'){
            doc_m <- read_file('src/templates/ws_bounds_note.txt')
        } else {
            doc_m <- 'NA'
        }

    } else {

        if(prodname_from_prodname_ms(prodname_ms_d) == 'ws_boundary'){
            ws_bounds_note <- read_file('src/templates/ws_bounds_note.txt')
        } else {
            ws_bounds_note <- ''
        }
    }

    ddoc <- read_file('src/templates/write_metadata_d_linkprod_boilerplate.txt') %>%
        glue(.,
             p = prodname_ms_d,
             ru = url_r,
             flux_note = ifelse(grepl('flux', prodname_ms_d),
                                read_file('src/templates/flux_note.txt'),
                                ''),
             vsnless_note = ifelse(grepl('VERSIONLESS', prodname_ms_mr),
                                   read_file('src/templates/VERSIONLESS_note.txt'),
                                   ''),
             mb = doc_m,
             ws_bounds_note = ws_bounds_note)

    #create derived directory if necessary
    derived_dir <- glue('data/{n}/{d}/derived/documentation',
                        n = network,
                        d = domain)
    dir.create(derived_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    #write metadata file
    data_acq_file <- glue('{dd}/documentation_{p}.txt',
                          dd = derived_dir,
                          p = prodname_ms_d)
    readr::write_file(ddoc,
                      file = data_acq_file)
}

Mode <- function(x, na.rm = TRUE){

    if(na.rm){
        x <- na.omit(x)
    }

    ux <- unique(x)
    mode_out <- ux[which.max(tabulate(match(x, ux)))]
    return(mode_out)

}

get_successor <- function(network,
                          domain,
                          prodname_ms){

    successor <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain))) %>%
        mutate(prodname_ms = paste(prodname,
                                   prodcode,
                                   sep = '__')) %>%
        filter(prodname_ms == !!prodname_ms) %>%
        pull(precursor_of)

    return(successor)
}

make_hdetlim_prec_lookup_table <- function(dls){

    #for each variable, determine the minimum detlim and the minimum (coarsest)
    #precision across all domains.

    #return a table of half-detlim ("hdetlim") and precision

    lookup_table <- dls %>%
        # group_by(domain, var = variable_converted) %>%
        # summarize(detlim = median(detection_limit_converted),
        #           precision = min(precision)) %>%
        # group_by(var) %>%
        # summarize(detlim = median(detlim),
        group_by(var = variable_converted) %>%
        summarize(detlim = min(detection_limit_converted),
                  precision = min(precision),
                  .groups = 'drop') %>%
        mutate(hdetlim = detlim / 2) %>%
        select(-detlim)

    return(lookup_table)
}

get_hdetlim_or_uncert <- function(d, detlims, prodname_ms, which_){

    #d: a tibble in MacroSheds format
    #detlims: the output of standardize_detection_limits
    #prodname_ms: a MacroSheds prodname_ms to filter detlims by
    #which_: either "uncertainty" or "hdetlim" (meaning half-detection-limit)

    #returns a vector of half-detlims or uncertainty, or an empty vector if d has no rows.
    #   precipitation and discharge get uncertainty of 0.

    #note that, when which_ == 'uncertainty',
    #   it's actually precision values that are being manipulated, right till the end.
    #   it's precision that we keep track of in unknown_detlim_prec_lookup.

    #locates, estimates, or naively generates (as 0 or -Inf) detection limits for any value.
    #does not account for potential deviations in detection limits within a domain, i.e.
    #different detlims for each site. this has not been encountered yet.
    #order of decisions:
    #   1. if provider reports detlim/prec for same product, domain, variable, and daterange, use it
    #   2. if not for same daterange, use the nearest daterange
    #   3. if not for same product, but same domain, variable, and daterange, use that
    #   4. if not for same product or daterange, use the nearest daterange
    #   5. if not for same variable, use minimum for that variable across domains
    #   6. if nothing reported for a domain, use minima across domains
    #   7. if nothing to guess from, use 0 (detlim) or -Inf (precision).
    #       0 is also used as precision for a small subset of variables that will
    #       never have reported detection limits, and for which infinite uncertainty
    #       would be lame. Currently these are discharge, precipitation, and temperature

    if(! nrow(d)) return(numeric())

    if(! which_ %in% c('uncertainty', 'hdetlim')){
        stop('which_ must be "uncertainty" or "hdetlim"')
    }

    if(which_ == 'uncertainty'){

        which_ <- 'precision' #precision will be converted to uncert at the end

        if(grepl('precipitation|discharge', prodname_ms)){
            return(rep(0, nrow(d)))
        }
    }

    #a bit of cleanup and setup
    half_detlims_all <- detlims %>%
        mutate(hdetlim = detection_limit_converted / 2) %>%
        select(domain, prodcode, var = variable_converted, hdetlim, precision,
               start_date, end_date) %>%
        group_by(domain, prodcode, var) %>%
        #relevant for e.g. loch_vale 008, where NO2 and NO2_N are reported separately
        summarize(across(everything(), first)) %>%
        ungroup()

    out <- rep(NA_real_, nrow(d))

    d$var <- drop_var_prefix(d$var)
    d$datetime <- as.Date(d$datetime)
    d$prodname_ms <- prodname_ms

    #checks for cases 1-3
    got_domain <- half_detlims_all$domain == domain
    got_prodcode_at_domain <- sapply(half_detlims_all$prodcode, function(x){
        any(str_split(x, '\\|')[[1]] == prodname_ms)
    }) & got_domain

    #CASES 1-2
    dlsub <- filter(half_detlims_all, !!got_prodcode_at_domain)
    if(nrow(dlsub)){

        if(any(! is.na(dlsub$start_date) | ! is.na(dlsub$end_date))){

            dlsub <- dlsub %>%
                mutate(start_date = data.table::fifelse(is.na(start_date), as.Date('1800-01-01'), start_date),
                       end_date = data.table::fifelse(is.na(end_date), Sys.Date(), end_date)) %>%
                arrange(start_date, end_date) %>%
                as.data.table()

            #date interval join; CASE 1:
            #join d rows to dlsub if d's date* falls within the covered range
            out <- dlsub[as.data.table(d),
                         on = c("start_date<=datetime",
                                "end_date>=datetime",
                                'prodcode==prodname_ms',
                                "var==var"),
                         mult = 'first'][[which_]]

            if(length(out) != nrow(d)){
                message('overlapping entries in detlim table? (1)')
                browser()
            }

            # d = d0
            # d$var <- drop_var_prefix(d$var)
            # d$datetime <- as.Date(d$datetime)
            # # d[duplicated(d) | duplicated(d, fromLast = TRUE), ] %>%
            # #     pull(var) %>% unique()
            #
            # d = d[duplicated(d) | duplicated(d, fromLast = TRUE), ]
            # d = filter(d, var == 'NO2_N')
            # out = dlsub[as.data.table(d),
            #       on = c("start_date<=datetime",
            #              "end_date>=datetime",
            #              "var==var")][[which_]]
            # length(out); nrow(d)
            #
            # filter(dlsub, var == 'NO2_N')
            # filter(half_detlims_all, var == 'NO2_N') %>% arrange(start_date)
            # filter(detlims, domain == 'loch_vale', variable_converted == 'NO2_N') %>%
            #     arrange(start_date) %>%
            #     as.data.frame()

            # detlim_pre[duplicated(detlim_pre) | duplicated(detlim_pre, fromLast = TRUE), ]
            # domain_detection_limits[duplicated(domain_detection_limits) | duplicated(domain_detection_limits, fromLast = TRUE), ]
            # this_set <- domain_detection_limits %>%
            #     filter(domain == 'loch_vale',
            #            prodcode == 'stream_chemistry__VERSIONLESS008')
            # arrange(this_set, variable_original, variable_converted) %>%
            #     select(starts_with('variable'), ends_with('date')) %>%
            #     view()
            # dupes <- this_set %>%
            #     group_by(variable_converted, start_date, end_date) %>%
            #     summarize(n = n()) %>%
            #     ungroup() %>%
            #     filter(n != 1) %>%
            #     print(n = 1000)
            # this_set <- semi_join(this_set, dupes,
            #                       by = c('variable_converted', 'start_date', 'end_date')) %>%
            #     arrange(variable_converted, start_date, end_date)
            # View(this_set)

            #forward rolling join to start_date; CASE 2
            still_missing <- is.na(out)
            if(any(still_missing)){

                out[still_missing] <- dlsub[as.data.table(d[still_missing, ]),
                                            on = c(var = 'var',
                                                   start_date = 'datetime'),
                                            roll = Inf, rollends = c(TRUE, FALSE)][[which_]]
            }

            #backward rolling join to end_date; CASE 2
            still_missing <- is.na(out)
            if(any(still_missing)){

                out[still_missing] <- dlsub[as.data.table(d[still_missing, ]),
                                            on = c(var = 'var',
                                                   start_date = 'datetime'),
                                            roll = -Inf, rollends = c(FALSE, TRUE)][[which_]]
            }

        } else { #CASE 1 with no dates specified
            if(any(duplicated(select(dlsub, var)))){
                message('overlapping entries in detlim table? (2)')
                browser()
            }

            out <- d %>%
                left_join(dlsub, by = 'var') %>%
                pull(!!which_)
        }
    }

    #CASES 3-4
    still_missing <- is.na(out)
    if(any(still_missing)){

        dlsub <- filter(half_detlims_all, got_domain & ! got_prodcode_at_domain)
        if(nrow(dlsub)){

            if(any(! is.na(dlsub$start_date) | ! is.na(dlsub$end_date))){

                dlsub <- dlsub %>%
                    mutate(start_date = data.table::fifelse(is.na(start_date), as.Date('1800-01-01'), start_date),
                           end_date = data.table::fifelse(is.na(end_date), Sys.Date(), end_date)) %>%
                    arrange(start_date, end_date) %>%
                    as.data.table()

                #date interval join; CASE 3:
                #join d rows to dlsub if d's datetime falls within the covered range
                dl_matches <- dlsub[as.data.table(d[still_missing, ]),
                                    on = c('start_date<=datetime',
                                           'end_date>=datetime',
                                           'var==var'),
                                    mult = 'first'][[which_]]

                if(all(is.na(dl_matches))){
                    #quick fix. i think it's still possible that length(dl_matches) < sum(still_missing),
                    #   but this solution is fine if the problem never relates to actual hdetlim insertions.
                    dl_matches <- rep(NA, sum(still_missing))
                }

                if(length(dl_matches) != sum(still_missing)){
                    message('overlapping entries in detlim table? (3)')
                    browser()
                }

                out[still_missing] <- dl_matches

                #forward rolling join to start_date; CASE 4
                still_missing <- is.na(out)
                if(any(still_missing)){

                    out[still_missing] <- dlsub[as.data.table(d[still_missing, ]),
                                                on = c(var = 'var',
                                                       start_date = 'datetime'),
                                                roll = Inf, rollends = c(TRUE, FALSE)][[which_]]
                }

                #backward rolling join to end_date; CASE 4
                still_missing <- is.na(out)
                if(any(still_missing)){

                    out[still_missing] <- dlsub[as.data.table(d[still_missing, ]),
                                                on = c(var = 'var',
                                                       start_date = 'datetime'),
                                                roll = -Inf, rollends = c(FALSE, TRUE)][[which_]]
                }

            } else { #CASE 3 with no dates specified

                dlsub <- dlsub %>%
                    group_by(var) %>%
                    summarize(!!sym(which_) := median(!!sym(which_)),
                              .groups = 'drop')

                out_ <- d %>%
                    left_join(dlsub, by = 'var') %>%
                    pull(!!which_)

                out[still_missing] <- out_[still_missing]
            }
        }
    }

    #CASEs 4-5: fill in remaining blanks using minimum (hdetlim or precision)
    #across all reported values
    still_missing <- is.na(out)
    ref_inds <- match(d$var[still_missing], unknown_detlim_prec_lookup$var)
    out[still_missing] <- pull(unknown_detlim_prec_lookup[ref_inds, which_])

    #CASE 6: fill in still remaining blanks with 0 (Inf becomes 0 below)
    out[is.na(out)] <- data.table::fifelse(which_ == 'hdetlim', 0, Inf)

    # if(which_ == 'precision'){
    #
    #     #special variables get 0 uncertainty, instead of Inf.  Beyond Q and P,
    #     #   this would be kind of arbitrary, but we could add specCond, turbidity,
    #     #   pH, alkalinity, and suspSed. these rarely or never have reported detlims.
    #     special_vars <- c('discharge', 'precipitation', 'temperature')
    #     special_inds <- is.infinite(out) & d$var %in% special_vars
    #     out[special_inds] <- Inf #10^-Inf is 0
    # }

    #convert precision to uncertainty
    if(which_ == 'precision') out <- 10^-out

    return(out)
}

qc_hdetlim_and_uncert <- function(d, prodname_ms){

    #d: a tibble in MacroSheds format

    #returns the same tibble, with quality control (only range check as of 2024),
    #1/2 detection limit inserted
    #for any instance of ms_status == 2, any ms_status == 2 set back to 1,
    #and uncertainty attached to the val column

    d <- ms_check_range(d)

    bdl_inds <- d$ms_status == 2
    d$val[bdl_inds] <- get_hdetlim_or_uncert(d[bdl_inds, ],
                                             detlims = domain_detection_limits,
                                             prodname_ms = prodname_ms,
                                             which_ = 'hdetlim')
    d$ms_status[d$ms_status == 2] <- 1

    errors(d$val) <- get_hdetlim_or_uncert(d,
                                           detlims = domain_detection_limits,
                                           prodname_ms = prodname_ms,
                                           which_ = 'uncertainty')

    return(d)
}

rle2 <- function(x){

    r <- rle(x)
    ends <- cumsum(r$lengths)

    r <- tibble(values = r$values,
                starts = c(1, ends[-length(ends)] + 1),
                stops = ends,
                lengths = r$lengths)

    return(r)
}

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

get_gee_imgcol <- function(gee_id, band, prodname, start, end, qaqc=FALSE,
                           qa_band = NULL, bit_mask = NULL) {

    col_name <- paste0(prodname, 'X')

    if(qaqc){

        # Mask bad pixles functions
        get_gee_QABits <- function(image) {
            # Convert binary (character) to decimal (little endian)
            qa <- sum(2^(which(rev(unlist(strsplit(as.character(bit_mask), "")) == 1))-1))
            # Return a mask band image, giving the qa value.
            image$bitwiseAnd(qa)$lt(1)
        }

        clean_gee_img <- function(img) {
            # Extract the selected band
            img_values <- img$select(band)

            # Extract the quality band
            img_qa <- img$select(qa_band)

            # Select pixels to mask
            quality_mask <- get_gee_QABits(img_qa)

            # Mask pixels with value zero.
            img_values$updateMask(quality_mask)

            return(img_values)

        }

        gee_imcol <- ee$ImageCollection(gee_id)$
            filterDate(start, end)$
            map(clean_gee_img)$
            select(band)
            # map(function(x){
            #     date <- ee$Date(x$get("system:time_start"))$format('YYYY_MM_dd')
            #     name <- ee$String$cat(col_name, date)
            #     x$select(band)$rename(name)
            # })


    } else {

        gee_imcol <- ee$ImageCollection(gee_id)$
            filterDate(start, end)$
            select(band)
            # map(function(x){
            #     date <- ee$Date(x$get("system:time_start"))$format('YYYY_MM_dd')
            #     name <- ee$String$cat(col_name, date)
            #     x$select(band)$rename(name)
            # })
    }

    return(gee_imcol)

}

clean_gee_table <- function(ee_ws_table, reducer){

    col_names <- colnames(ee_ws_table)
    col_names <- grep('site_code|area',
                      col_names,
                      invert = TRUE,
                      value = TRUE)

    if(! grepl('^X[0-9\\-]+_[^X]+X', colnames(ee_ws_table)[3])) stop('adapt regex below')

    ee_ws_table <- ee_ws_table %>%
        pivot_longer(cols = !!col_names, values_to = 'val', names_to = 'var_date') %>%
        mutate(var = str_extract(var_date, '^X[0-9\\-]+_([^X]+)X', group = 1),
               datetime = str_extract(var_date, '^X([0-9\\-]+)_[^X]+X', group = 1)) %>%
        mutate(var = glue('{var}_{reducer}')) %>%
        select(site_code, datetime, var, val)

    return(ee_ws_table)
}

get_gee_standard <- function(network,
                             domain,
                             gee_id,
                             band,
                             prodname,
                             rez,
                             site_boundary,
                             batch = TRUE,
                             qa_band = NULL,
                             bit_mask = NULL,
                             contiguous_us = FALSE,
                             summary_stat = 'median'){

    #batch: logical. Deprecated in favor of the less hygienic but more convenient
    #   bulk_mode parameter of ms_general. batch is always TRUE now, because
    #   the alternative method fails on big timeseries like prism

    if(! summary_stat %in% c('median', 'mean')){
        stop('summary_stat must be median or mean')
    }

    # if(exists('bulk_mode') && bulk_mode){
    #     batch <- TRUE
    # } else {
    #     batch <- FALSE
    # }

    site_boundary <- sf::st_make_valid(site_boundary)

    if(contiguous_us){

        usa_bb <- sf::st_bbox(obj = c(xmin = -124.725, ymin = 24.498, xmax = -66.9499,
                                      ymax = 49.384), crs = 4326) %>%
            sf::st_as_sfc(., crs = 4326)

        is_usa <- ! length(sm(sf::st_intersects(usa_bb, site_boundary))[[1]]) == 0

        if(! is_usa){
            message('no sites within contiguous USA')
            return(NULL)
        }
    }

    qaqc <- FALSE
    if(! is.null(qa_band) || ! is.null(bit_mask)){
        if(any(is.null(qa_band), is.null(bit_mask))){
            stop('qa_band and bit_mask must both be provided if one is')
        } else{
            qaqc <- TRUE
        }
    }

    if(batch){

        # Remove file if is in drive
        googledrive::drive_rm('GEE/rgee.csv', verbose = FALSE)

        # Mask bad pixels functions
        get_gee_QABits <- function(image){

            # Convert binary (character) to decimal (little endian)
            qa <- sum(2^(which(rev(unlist(strsplit(as.character(bit_mask), "")) == 1))-1))

            # Return a mask band image, giving the qa value.
            image$bitwiseAnd(qa)$lt(1)
        }

        clean_gee_img <- function(img){

            # Extract the selected band
            img_values <- img$select(band)

            # Extract the quality band
            img_qa <- img$select(qa_band)

            # Select pixels to mask
            quality_mask <- get_gee_QABits(img_qa)

            # Mask pixels with value zero.
            img_values$updateMask(quality_mask)

        }

        user_info <- rgee::ee_user_info(quiet = TRUE)

        asset_folder <- glue('{a}/macrosheds_ws_boundaries/{d}/',
                             a = user_info$asset_home,
                             d = domain)

        asset_path <- rgee::ee_manage_assetlist(asset_folder)

        if(bulk_mode){
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

            } else {
                ws_boundary_asset <- ee$FeatureCollection(asset_path$ID)
            }
        } else {
            site_code <- site_boundary$site_code
            if(length(site_code) != 1) stop('err')
            pth <- asset_path$ID[grepl(glue('/{site_code}$'), asset_path$ID)]
            if(length(pth) != 1) stop('err2')
            ws_boundary_asset <- ee$FeatureCollection(pth)
        }

        if(qaqc){
            imgcol <- ee$ImageCollection(gee_id)$map(clean_gee_img)$select(band)
        } else {
            imgcol <- ee$ImageCollection(gee_id)$select(band)
        }

        if(exists('gee_bounding_dates', where = .GlobalEnv)){

            avail_dates <- try(imgcol$aggregate_array('system:index')$getInfo(),
                               silent = TRUE)
            if(inherits(avail_dates, 'try-error')) browser()

            already_got <- FALSE
            if(grepl('^[0-9]{4}$', avail_dates[1])){
                already_got <- as.numeric(avail_dates[length(avail_dates)]) <=
                    year(gee_bounding_dates[1])
            } else if(grepl('^[0-9]{4}_[0-9]{2}$', avail_dates[1])){
                already_got <- ym(avail_dates[length(avail_dates)]) <=
                    gee_bounding_dates[1]
            } else if(grepl('^[0-9]{4}[_\\-][0-9]{2}[_\\-][0-9]{2}$', avail_dates[1])){
                already_got <- ymd(avail_dates[length(avail_dates)]) <=
                    gee_bounding_dates[1]
            } else if(grepl('^[12][089][0-9]{6}$', avail_dates[1])){
                already_got <- ymd(avail_dates[length(avail_dates)]) <=
                    gee_bounding_dates[1]
            } else if(grepl('^[12][089][0-9]{5}$', avail_dates[1])){
                already_got <- as_datetime(avail_dates[length(avail_dates)],
                                           format = '%Y%j') <=
                    gee_bounding_dates[1]
            } else {
                browser()
            }

            if(already_got){
                loginfo(paste('Most recent release of', gee_id, 'already acquired'),
                        logger = logger_module)
                return()
            }

            imgcol <- imgcol$filterDate(gee_bounding_dates[1],
                                        gee_bounding_dates[2])
        }

        smallest_ws <- min(site_boundary$area)
        rez <- case_when(smallest_ws < 1e2 ~ rez / 4,
                         smallest_ws < 1e3 ~ rez / 2,
                         smallest_ws < 1e5 ~ rez,
                         smallest_ws < 1e6 ~ rez * 2,
                         smallest_ws >= 1e6 ~ rez * 4)

        if(summary_stat == 'median'){

            flat_img <- imgcol$map(function(image) {
                image$reduceRegions(
                    collection = ws_boundary_asset,
                    reducer = ee$Reducer$stdDev()$combine(
                        reducer2 = ee$Reducer$median(),
                        sharedInputs = TRUE),
                    scale = rez
                )
            })$flatten()

            gee <- flat_img$select(propertySelectors = c('site_code', 'imageId',
                                                         'stdDev', 'median'),
                                   retainGeometry = FALSE)
        } else {

            flat_img <- imgcol$map(function(image) {
                image$reduceRegions(
                    collection = ws_boundary_asset,
                    reducer = ee$Reducer$stdDev()$combine(
                        reducer2 = ee$Reducer$mean(),
                        sharedInputs = TRUE),
                    scale = rez
                )
            })$flatten()

            gee <- flat_img$select(propertySelectors = c('site_code', 'imageId',
                                                         'stdDev', 'mean'),
                                   retainGeometry = FALSE)
        }

        ee_description <-  glue('{network}_{domain}_{prodname}')

        ee_task <- ee$batch$Export$table$toDrive(
            collection = gee,
            description = ee_description,
            fileFormat = 'CSV',
            folder = 'GEE',
            fileNamePrefix = 'rgee'
        )

        ee_task$start()
        ee_monitoring(ee_task, max_attempts = Inf, quiet = TRUE)

        temp_rgee <- tempfile(fileext = '.csv')

        expo_backoff(
            expr = {
                googledrive::drive_download(file = 'GEE/rgee.csv',
                                            temp_rgee,
                                            verbose = FALSE)
            },
            max_attempts = 5
        ) %>% invisible()

        sd_name <- glue('{c}_sd', c = prodname)
        median_name <- glue('{c}_{s}', c = prodname, s = summary_stat)

        d_combined <- read_csv(temp_rgee, show_col_types = FALSE) %>%
            mutate(imageId = substr(`system:index`, 1, 10))

        googledrive::drive_rm('GEE/rgee.csv', verbose = FALSE)

        if(! summary_stat %in% colnames(d_combined) &&
           ! 'stdDev' %in% colnames(d_combined)){
            browser()
            return(NULL)
        }

        d_combined <- d_combined %>%
            select(site_code, stdDev, !!summary_stat, imageId) %>%
            rename(datetime = imageId,
                   !!sd_name := stdDev,
                   !!median_name := !!summary_stat) %>%
            pivot_longer(cols = all_of(c(sd_name, median_name)),
                         names_to = 'var',
                         values_to = 'val')

        out <- list(table = d_combined,
                    type = 'batch')

    } else {

        ## this never happens anymore? if resuscitate, resolve resolution/scale better

        if(exists('gee_bounding_dates', where = .GlobalEnv)){
            gee_startdate <- gee_bounding_dates[1]
            gee_enddate <- gee_bounding_dates[2]
        } else {
            gee_startdate <- '1957-10-25'
            gee_enddate <- '2040-01-01'
        }

        imgcol <- get_gee_imgcol(gee_id,
                                 band,
                                 prodname,
                                 gee_startdate,
                                 gee_enddate,
                                 qaqc = qaqc)

        d_combined <- tibble()
        for(i in seq_len(nrow(site_boundary))){

            site_bnd <- site_boundary[i, ]

            print(paste('Working on', site_bnd$site_code))

            scale_ <- case_when(site_bnd$area < 1e5 ~ rez,
                                between(site_bnd$area, 1e5, 1e6) ~ rez * 2,
                                site_bnd$area > 1e6 ~ rez * 4)

            while(TRUE){

                ext_median <- try(ee_extract(
                    x = imgcol,
                    y = site_bnd,
                    scale = scale_,
                    fun = ee$Reducer$median(),
                    sf = FALSE
                ))

                if(inherits(ext_median, 'try-error') && grepl('timed out', ext_median)){
                    message('median computation timed out. incrementing scale parameter')
                    scale_ <- scale_ * 2
                    if(is.na(scale_)) stop('rly need larger scales?')
                } else break
            }

            if(length(ext_median) == 2){
                ext_median <- tibble()
            } else if(length(ext_median) <= 4 || inherits(ext_median, 'try-error')){
                message('investigate this')
                browser()
            } else {
                ext_median <- clean_gee_table(ee_ws_table = ext_median,
                                              reducer = 'median')
            }

            while(TRUE){

                ext_sd <- try(ee_extract(
                    x = imgcol,
                    y = site_bnd,
                    scale = scale_,
                    fun = ee$Reducer$stdDev(),
                    sf = FALSE
                ))

                if(inherits(ext_sd, 'try-error') && grepl('timed out', ext_sd)){
                    message('sdev computation timed out. incrementing scale parameter')
                    scale_ <- scale_ * 2
                    if(is.na(scale_)) stop('rly need larger scales?')
                } else break
            }

            if(length(ext_sd) == 2){
                ext_sd <- tibble()
            } else if(length(ext_sd) <= 4 || inherits(ext_sd, 'try-error')){
                message('investigate this')
                browser()
            } else {
                ext_sd <- clean_gee_table(ext_sd, reducer = 'sd')
            }

            d_combined <- bind_rows(ext_median, ext_sd) %>%
                bind_rows(d_combined)
        }

        out <- list(table = d_combined,
                    type = 'ee_extract')
    }

    return(out)
}

get_relative_uncert <- function(x){

    if(any(class(x) %in% c('list', 'data.frame', 'array'))){
        stop(glue('this function not yet adapted for class {cl}',
                  cl = paste(class(tibble(x=1:3)),
                             collapse = ', ')))
    }

    ru <- errors(x) / abs(errors::drop_errors(x)) * 100

    return(ru)
}

get_phenology <- function(network, domain, prodname_ms, time, site_boundary,
                          site_code) {

    sheds_point <- site_boundary %>%
        sf::st_centroid() %>%
        sf::st_bbox()

    long <- as.numeric(sheds_point[1])

    place <- ifelse(long > -97.5, 'east', 'west')

    year_files <- list.files(glue('data/spatial/phenology/{u}/{p}',
                             p = place,
                             u = time))

    if(length(year_files) == 0) {
        return(NULL)
    }

    site_boundary <- sf::st_transform(site_boundary,
                                      '+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs')

    years <- as.numeric(str_split_fixed(year_files, '[.]', n = 2)[,1])

    final <- tibble()
    for(y in 1:length(years)) {

        path <- glue('data/spatial/phenology/{u}/{p}/{t}.tif',
                     u = time, p = place, t = years[y])

        ws_values <- try(extract_ws_mean(site_boundary = site_boundary,
                                         raster_path = path),
                         silent = TRUE)

        if(inherits(ws_values, 'try-error')) {

            msg <- generate_ms_exception(glue('No data was retrived for {s}, {y}',
                                       s = site_code,
                                       y = years[y]))

            loginfo(msg = msg,
                    logger = logger_module)

            next

        }

        val <- ws_values['mean']
        val_sd <- ws_values['sd']
        percent_na <- ws_values['pctCellErr']

        col_name <- case_when(time == 'start_season' ~ 'sos',
                              time == 'end_season' ~ 'eos',
                              time == 'max_season' ~ 'mos',
                              time == 'length_season' ~ 'los')

        mean_name <- glue('{n}_mean', n = col_name)
        sd_name <- glue('{n}_sd', n = col_name)

        one_var <- tibble(!!mean_name := val,
                          !!sd_name := val_sd,
                          pctCellErr = percent_na,
                          site_code = site_code,
                          year = years[y])

        final <- rbind(final, one_var)
        }

    if(nrow(final) == 0){
        return()
    }

    final <- final %>%
        mutate(!!mean_name := round(.data[[mean_name]])) %>%
        pivot_longer(cols = all_of(c(mean_name, sd_name)),
                     names_to = 'var',
                     values_to = 'val') %>%
        select(year, site_code, var, val, pctCellErr)

    dir <- glue('data/{n}/{d}/ws_traits/{p}/',
                n = network, d = domain, p = time)

    dir.create(dir, recursive = TRUE, showWarnings = FALSE)

    final_path <- glue('data/{n}/{d}/ws_traits/{p}/sum_{s}.feather',
                       n = network,
                       d = domain,
                       p = time,
                       s = site_code)

    final <- append_unprod_prefix(final, prodname_ms)
    write_feather(final, final_path)
}

err_df_to_matrix <- function(df){

    if(! all(sapply(df, class) %in% c('errors', 'numeric'))){
        stop('all columns of df must be of class "errors" or "numeric"')
    }

    errmat <- as.matrix(as.data.frame(lapply(df, errors)))
    M <- as.matrix(df)
    errors(M) <- errmat

    return(M)
}

raster_intersection_summary <- function(wb, dem){

    #wb is a delineated watershed boundary as a rasterLayer
    #dem is a DEM rasterLayer

    summary_out <- list()

    #convert wb to sf object (there are several benign but seemingly uncatchable
    #   garbage collection errors here)
    wb <- sf::st_as_sf(terra::as.polygons(wb))

    #get edge of DEM as sf object
    # dem_edge <- dem %>%
    #     terra::rast() %>%
    #     terra::boundaries() %>%
    #     terra::as.polygons() %>%
    #     sf::st_as_sf() %>%
    #     sf::st_boundary()

    # dem_edge <- dem %>%
    #     raster::focal(., #the terra version doesn't retain NA border
    #                  fun=function(x) return(0), na.rm=F,
    #                  w = matrix(1, nrow = 3, ncol = 3)) %>%
    #     raster::reclassify(rcl = matrix(c(0, NA,
    #                                       NA, 0), #set inner cells to NA
    #                                     ncol = 2)) %>%
    #     raster::rasterToPolygons() %>%
    #     sf::st_as_sf()

    get_out_cells <- function(x) {
        w <- sum(x, na.rm = FALSE)
        if(is.na(w)){
            return(0)
        } else{
            return(NA)
        }
    }

    dem_edge <- dem %>%
        terra::rast() %>%
        terra::focal(., fun=get_out_cells,
                      w = matrix(1, nrow = 3, ncol = 3)) %>%
        terra::as.polygons(dissolve = FALSE) %>%
        sf::st_as_sf() %>%
        # dem_edge was lossing it's crs or it was changing
        sf::st_transform(sf::st_crs(wb))

    #tally raster cells
    summary_out$n_wb_cells <- length(wb$geometry)
    summary_out$n_dem_cells <- length(dem_edge$geometry)

    #tally intersections; calc percent of wb cells that overlap
    intersections <- sf::st_intersects(wb, dem_edge) %>%
        as.matrix() %>%
        apply(MARGIN = 2,
              FUN = sum) %>%
        table()

    true_intersections <- sum(intersections[names(intersections) > 0])

    summary_out$n_intersections <- true_intersections
    summary_out$pct_wb_cells_intersect <- true_intersections /
        summary_out$n_wb_cells * 100

    return(summary_out)
}

remove_all_na_sites <- function(d){

    d_test <- d %>%
        mutate(na = ifelse(! is.na(val), 1, 0)) %>%
        group_by(site_code, var) %>%
        summarise(non_na = sum(na))

    d <- left_join(d, d_test, by = c("site_code", "var")) %>%
        filter(non_na > 1) %>%
        select(-non_na)
}

combine_products <- function(network, domain, prodname_ms, input_prodname_ms,
                             rtrn = FALSE){

    #Used to combine multiple products into one. Used when discharge, chemistry,
    #or other products are split into multiple products and we want them in one.

    #rtrn: logical. if TRUE, return the combined dataset rather than writing
    #it to disk

    files <- ms_list_files(network = network,
                           domain = domain,
                           prodname_ms = input_prodname_ms)

    dir <- glue('data/{n}/{d}/derived/{p}',
                n = network,
                d = domain,
                p = prodname_ms)

    dir.create(dir, showWarnings = FALSE)

    site_feather <- str_split_fixed(files, '/', n = Inf)[, 6]
    sites <- unique(str_split_fixed(site_feather, '[.]feather', n = Inf)[, 1])

    cmbn <- tibble()
    for(i in 1:length(sites)){

        site_files <- grep(paste0('/', sites[i], '.feather'), files, value = TRUE)
        site_full <- map_dfr(site_files, read_feather)

        dd <- duplicated(select(site_full, datetime, var))
        if(any(dd)){

            logwarn(glue('Duplicate/replicate records found for site {sites[i]}.',
                         ' These will be averaged.'),
                    logger = logger_module)

            site_full[dd | duplicated(select(site_full, datetime, var), fromLast = TRUE), ] %>%
                arrange(datetime, var) %>%
                print()

            site_full <- site_full %>%
                group_by(datetime, var) %>%
                summarize(site_code = first(site_code),
                          val = mean(val),
                          val_err = max(sd_or_0(val, na.rm = TRUE) / sqrt(n()),
                                        mean(val_err, na.rm = TRUE)),
                          ms_interp = max(ms_interp),
                          ms_status = max(ms_status),
                          .groups = 'drop') %>%
                relocate(datetime, site_code, var, val, ms_status, ms_interp, val_err)
        }

        if(! rtrn){
            write_ms_file(d = site_full,
                          network = network,
                          domain = domain,
                          prodname_ms = prodname_ms,
                          site_code = sites[i],
                          level = 'derived',
                          shapefile = FALSE)
        } else {
            cmbn <- bind_rows(cmbn, site_full)
        }
    }

    if(rtrn) return(cmbn)
}

load_config_datasets <- function(from_where){

    #this loads our "configuration" datasets into the global environment.
    #as of 10/27/20 those datasets include site_data, variables, universal_products,
    #name_variants (which is not loaded), and
    #watershed_delineation_specs. depending on the type of instance (remote/local),
    #those datasets are either read as local CSVs or as google sheets. for ms
    #developers, this will always be "remote". for future users, it'll be a
    #configurable option.

    if(from_where == 'remote'){

        ms_vars <- sm(googlesheets4::read_sheet(
            conf$variables_gsheet,
            na = c('', 'NA'),
            col_types = 'cccccccnnccnn'
        ))

        site_data <- sm(googlesheets4::read_sheet(
            conf$site_data_gsheet,
            na = c('', 'NA'),
            col_types = 'ccccccccnnnnncccccc'
        ))

        ws_delin_specs <- sm(googlesheets4::read_sheet(
            conf$delineation_gsheet,
            na = c('', 'NA'),
            col_types = 'cccncnnccl'
        ))

        ws_appendix <- sm(googlesheets4::read_sheet(
            conf$ws_boundary_appendix_gsheet,
            na = c('', 'NA'),
            col_types = 'ccccccccnnnlcnnnnnc'
        ))

        univ_products <- sm(googlesheets4::read_sheet(conf$univ_prods_gsheet,
                                                      na = c('', 'NA')))

        domain_detection_limits <- sm(googlesheets4::read_sheet(
            conf$dl_sheet,
            na = c('', 'NA'),
            col_types = 'cccccnnnnccDDl'
        ))

        site_doi_license <- googlesheets4::read_sheet(
            conf$site_doi_license_gsheet,
            skip = 4,
            na = c('', 'NA'),
            col_types = 'c'
        )

    } else if(from_where == 'local'){

        ms_vars <- sm(read_csv('data/general/variables.csv'))
        site_data <- sm(read_csv('data/general/site_data.csv'))
        univ_products <- sm(read_csv('data/general/universal_products.csv'))
        domain_detection_limits <- sm(read_csv('data/general/domain_detection_limits.csv'))
        ws_appendix <- sm(read_csv('data/general/ws_appendix.csv'))
        site_doi_license <- sm(read_csv('data/general/site_doi_license.csv'))

        ws_delin_specs <- tryCatch(sm(read_csv('data/general/watershed_delineation_specs.csv')),
                                   error = function(e){
                                       empty_tibble <- tibble(network = 'a',
                                                              domain = 'a',
                                                              site_code = 'a',
                                                              buffer_radius_m = 1,
                                                              snap_method = 'a',
                                                              snap_distance_m = 1,
                                                              dem_resolution = 1,
                                                              flat_increment = 1,
                                                              breach_method = 'a',
                                                              burn_streams = 'a')

                                       return(empty_tibble[-1, ])
                                   })

    } else {
        stop('from_where must be either "local" or "remote"')
    }

    assign('ms_vars',
           ms_vars,
           pos = .GlobalEnv)

    assign('site_data',
           site_data,
           pos = .GlobalEnv)

    assign('ws_delin_specs',
           ws_delin_specs,
           pos = .GlobalEnv)

    assign('ws_appendix',
           ws_appendix,
           pos = .GlobalEnv)

    assign('univ_products',
           univ_products,
           pos = .GlobalEnv)

    assign('domain_detection_limits',
           domain_detection_limits,
           pos = .GlobalEnv)

    assign('ws_appendix',
           ws_appendix,
           pos = .GlobalEnv)

    assign('site_doi_license',
           site_doi_license,
           pos = .GlobalEnv)
}

write_portal_config_datasets <- function(){

    #so we don't have to read these from gdrive when running the app in
    #production. also, nice to report download sizes this way and avoid some
    #real-time calculation.

    disturbance_record <- sm(googlesheets4::read_sheet(
        conf$disturbance_record_gsheet,
        na = c('', 'NA'),
        col_types = 'c'
    ))

    site_doi_license <- sm(googlesheets4::read_sheet(
        conf$site_doi_license_gsheet,
        skip = 4,
        na = c('', 'NA'),
        col_types = 'c'
    ))

    dir.create('../portal/data/general',
               showWarnings = FALSE,
               recursive = TRUE)

    write_csv(site_data, '../portal/data/general/site_data.csv')
    write_csv(ms_vars, '../portal/data/general/variables.csv')
    # write_csv(univ_products, '../portal/data/general/universal_products.csv')
    write_csv(disturbance_record, '../portal/data/general/disturbance_record.csv')
    write_csv(site_doi_license, '../portal/data/general/site_doi_license.csv')
}

compute_download_filesizes <- function(){

    #determines approximate sizes of downloadable zipfiles for each domain.
    #doing it here saves computation time in the portal.

    dir.create('../portal/data/general/download_sizes',
               showWarnings = FALSE,
               recursive = TRUE)

    dmn_dirs <- list.files('../portal/data/')
    dmn_dirs <- dmn_dirs[! dmn_dirs %in% c('general', 'all_ws_bounds', 'all_ws_bounds.zip')]

    dmn_dl_size <- data.frame(domain = dmn_dirs,
                              dl_size_MB = NA_character_)

    for(i in seq_along(dmn_dirs)){

        dmnfiles <- list.files(paste0('../portal/data/', dmn_dirs[i]),
                               full.names = TRUE,
                               recursive = TRUE,
                               include.dirs = FALSE,
                               pattern = '\\.feather$')

        dmnfilesizes <- sapply(dmnfiles, file.size)

        if(length(dmnfilesizes)){

            total_MB <- dmnfilesizes %>%
                sum() %>%
                {. / 1e6 * 0.12} %>% # 0.12 is the approximate compression ratio after zipping
                round(1) %>%
                as.character()

        } else {
            total_MB <- 'pending'
        }

        dmn_dl_size$dl_size_MB[i] <- ifelse(total_MB == '0', '< 1', total_MB)
    }

    write_csv(x = dmn_dl_size,
              file = '../portal/data/general/download_sizes/timeseries.csv')
}

ms_write_confdata <- function(x,
                              which_dataset,
                              to_where,
                              overwrite = FALSE){

    #x: a tibble or data.frame
    #which_dataset: string. either "ms_vars", "site_data", "univ_products",
    #   "ws_delin_specs", "domain_detection_limits", "site_doi_license", or "ws_appendix"
    #to_where: string. either "remote", meaning write this file to a google
    #   sheets connection defined in data_acquisition/config.json and
    #   data_acquisition/googlesheet_service_accnt.json, or "local", meaning
    #   write this file locally to data_acquisition/data/general/<which_dataset>.csv
    #overwrite: logical; If FALSE, x will be appended to which_dataset

    #depending on the type of instance (remote/local),
    #those datasets are either written to local CSVs or to google sheets. for ms
    #developers, this will always be "remote". for future users, it'll be a
    #configurable option.

    #which_dataset will also be updated in memory

    known_datasets <- c('ms_vars', 'site_data', 'ws_delin_specs', 'domain_detection_limits',
                        'univ_products', 'site_doi_license', 'ws_appendix')

    if(! which_dataset %in% known_datasets){
        stop(glue('which_dataset must be one of: "{kd}"',
                  kd = paste(known_datasets, collapse = '", "')))
    }

    if(which_dataset == 'site_data' && ! any(site_data$in_workflow == 0)){
        stop('something is still causing in_workflow == 0 sites to be removed from site_data')
    }

    type_string <- case_when(
        which_dataset == 'ms_vars' ~ 'cccccccnnccnn',
        which_dataset == 'site_data' ~ 'ccccccccnnnnncccccc',
        which_dataset == 'ws_delin_specs' ~ 'cccncnnccl',
        which_dataset == 'ws_appendix' ~ 'ccccccccnnnlcnnnnnc',
        which_dataset == 'domain_detection_limits' ~ 'cccccnnnnccDDl',
        which_dataset == 'site_doi_license' ~ 'c',
        TRUE ~ 'placeholder')

    if(which_dataset %in% c('univ_products')){
        type_string <- NULL
    }

    if(to_where == 'remote'){

        write_loc <- case_when(
            which_dataset == 'ms_vars' ~ conf$variables_gsheet,
            which_dataset == 'site_data' ~ conf$site_data_gsheet,
            which_dataset == 'univ_products' ~ conf$univ_prods_gsheet,
            which_dataset == 'ws_delin_specs' ~ conf$delineation_gsheet,
            which_dataset == 'ws_appendix' ~ conf$ws_boundary_appendix_gsheet,
            which_dataset == 'site_doi_license' ~ conf$site_doi_license_gsheet,
            which_dataset == 'domain_detection_limits' ~ conf$dl_sheet)

        ## write updates

        if(which_dataset == 'site_doi_license'){

            catch <- expo_backoff(
                expr = {
                    sm(googlesheets4::range_write(ss = write_loc,
                                                  data = x,
                                                  sheet = 1,
                                                  range = 'A6',
                                                  col_names = FALSE))
                },
                max_attempts = 4
            )

        } else if(overwrite){

            catch <- expo_backoff(
                expr = {
                    sm(googlesheets4::write_sheet(data = x,
                                                  ss = write_loc,
                                                  sheet = 1))
                },
                max_attempts = 4
            )

        } else {

            catch <- expo_backoff(
                expr = {
                    sm(googlesheets4::sheet_append(data = x,
                                                   ss = write_loc,
                                                   sheet = 1))
                },
                max_attempts = 4
            )

        }

        ## read back and update locally (probably unnecessary, but also harmless and maybe this is here for a reason)

        if(which_dataset == 'site_doi_license'){

            catch <- expo_backoff(
                expr = {
                    dset <- sm(googlesheets4::read_sheet(ss = write_loc,
                                                         na = c('', 'NA'),
                                                         skip = 4,
                                                         col_types = type_string))
                },
                max_attempts = 4
            )

        } else {

            catch <- expo_backoff(
                expr = {
                    dset <- sm(googlesheets4::read_sheet(ss = write_loc,
                                                         na = c('', 'NA'),
                                                         col_types = type_string))
                },
                max_attempts = 4
            )
        }

    } else if(to_where == 'local'){

        write_loc <- case_when(
            which_dataset == 'ms_vars' ~ 'variables.csv',
            which_dataset == 'site_data' ~ 'site_data.csv',
            which_dataset == 'univ_products' ~ 'universal_products.csv',
            which_dataset == 'ws_delin_specs' ~ 'watershed_delineation_specs.csv',
            which_dataset == 'ws_appendix' ~ 'ws_boundary_appendix.csv',
            which_dataset == 'site_doi_license' ~ 'site_doi_license.csv',
            which_dataset == 'domain_detection_limits' ~ 'domain_detection_limits.csv')

        if(overwrite){

            write_csv(x,
                      path = paste0('data/general/',
                                    write_loc))
        } else {

            dset <- read_csv(path = paste0('data/general/',
                                           write_loc))
            dset <- bind_rows(dset, x)

            write_csv(x = dset,
                      path = paste0('data/general/',
                                    write_loc))
        }

        dset <- read_csv(path = paste0('data/general/',
                                       write_loc),
                         col_types = type_string)

    } else {
        stop('to_where must be either "local" or "remote"')
    }

    assign(x = which_dataset,
           value = dset,
           envir = .GlobalEnv)
}

filter_single_samp_sites <- function(df) {

    counts <- df %>%
        group_by(site_code, var) %>%
        summarise(n = n())

    df <- left_join(df, counts, by = c('site_code', 'var')) %>%
        filter(n > 1) %>%
        select(-n)

    return(df)
}

#this section is for generalized derive kernels. this file is getting pretty huge.
#we should soon separate it into several different files, each with a
#particular category of global helpers.
derive_stream_flux <- function(network, domain, prodname_ms){

    schem_prodname_ms <- get_derive_ingredient(network = network,
                                               domain = domain,
                                               prodname = 'stream_chemistry',
                                               accept_multiple = TRUE)

    disch_prodname_ms <- get_derive_ingredient(network = network,
                                               domain = domain,
                                               prodname = 'discharge',
                                               accept_multiple = TRUE)

    chemfiles <- ms_list_files(network = network,
                               domain = domain,
                               prodname_ms = schem_prodname_ms)

    qfiles <- ms_list_files(network = network,
                            domain = domain,
                            prodname_ms = disch_prodname_ms)

    flux_sites <- base::intersect(
        fname_from_fpath(qfiles, include_fext = FALSE),
        fname_from_fpath(chemfiles, include_fext = FALSE))

    for(s in flux_sites){

        flux <- sw(calc_inst_flux(chemprod = schem_prodname_ms,
                                  qprod = disch_prodname_ms,
                                  site_code = s))
        if(!is.null(flux)){

            write_ms_file(d = flux,
                          network = network,
                          domain = domain,
                          prodname_ms = prodname_ms,
                          site_code = s,
                          level = 'derived',
                          shapefile = FALSE)
        }
    }

    return()
}

derive_precip_pchem_pflux <- function(network, domain, prodname_ms){

    #this function does the work of derive_precip, derive_precip_chem,
    #and derive_precip_flux. use it wherever possible to minimize
    #run time.

    # prodname_ms = 'precip_pchem_pflux__ms002'
    pchem_prodname_ms <- get_derive_ingredient(network = network,
                                               domain = domain,
                                               prodname = 'precip_chemistry')

    precip_prodname_ms <- get_derive_ingredient(network = network,
                                                domain = domain,
                                                prodname = 'precipitation')

    wb_prodname_ms <- get_derive_ingredient(network = network,
                                            domain = domain,
                                            prodname = 'ws_boundary')

    rg_prodname_ms <- get_derive_ingredient(network = network,
                                            domain = domain,
                                            prodname = 'precip_gauge_locations')

    # pchem_prodname = pchem_prodname_ms; precip_prodname = precip_prodname_ms
    # wb_prodname = wb_prodname_ms; pgauge_prodname = rg_prodname_ms
    precip_pchem_pflux_idw(pchem_prodname = pchem_prodname_ms,
                           precip_prodname = precip_prodname_ms,
                           wb_prodname = wb_prodname_ms,
                           pgauge_prodname = rg_prodname_ms,
                           prodname_ms = prodname_ms)
                           # flux_prodname_out = prodname_ms)

    return()
}

#end generalized derive kernel section

precip_gauge_from_site_data <- function(network, domain, prodname_ms) {

    locations <- site_data %>%
        filter(network == !!network,
               domain == !!domain,
               site_type == 'rain_gauge',
               in_workflow == 1)

    crs <- unique(locations$CRS)

    if(length(crs) > 1) {
        stop('crs is not consistent for all sites, cannot convert location in
             site_data to precip_gauge location product')
    }

    locations <- locations %>%
        sf::st_as_sf(coords = c('longitude', 'latitude'), crs = crs) %>%
        select(site_code)

    path <- glue('data/{n}/{d}/derived/{p}',
                 n = network,
                 d = domain,
                 p = prodname_ms)

    dir.create(path, recursive = TRUE)

    for(i in 1:nrow(locations)) {

        site_code <- pull(locations[i,], site_code)

        sf::st_write(locations[i,],
                     glue('{path}/{site_code}'),
                     driver = 'ESRI Shapefile',
                     delete_dsn = TRUE,
                     quiet = TRUE)
    }
}

stream_gauge_from_site_data <- function(network, domain, prodname_ms) {

    locations <- site_data %>%
        filter(network == !!network,
               domain == !!domain,
               site_type == 'stream_gauge',
               in_workflow == 1)

    crs <- unique(locations$CRS)

    if(length(crs) > 1){
        stop('crs is not consistent for all sites, cannot convert location in
             site_data to stream_gauge location product')
    }

    locations <- locations %>%
        sf::st_as_sf(coords = c('longitude', 'latitude'),
                     crs = crs) %>%
        select(site_code)

    path <- glue('data/{n}/{d}/derived/{p}',
                 n = network,
                 d = domain,
                 p = prodname_ms)

    dir.create(path,
               recursive = TRUE,
               showWarnings = FALSE)

    for(i in 1:nrow(locations)){

        site_code <- pull(locations[i, ], site_code)

        name_contains_period <- str_detect(site_code, '\\.')

        if(name_contains_period){

            #st_write does not allow periods in filenames. here's a workaround

            correct_dir <- glue('{path}/{site_code}')
            if(dir.exists(correct_dir)){
                unlink(correct_dir,
                       recursive = TRUE)
            }

            temp_name <- str_replace_all(site_code, '\\.', '__R__')

            sf::st_write(locations[i, ],
                         glue('{path}/{temp_name}'),
                         driver = 'ESRI Shapefile',
                         delete_dsn = TRUE,
                         quiet = TRUE)

            #all shapefile extensions
            extensions <- c('.shp', '.shx', '.dbf', '.prj', '.cpg', '.sbn',
                            '.sbx', '.fbn', '.fbx', '.ain', '.aih', '.ixs',
                            '.mxs', '.atx')

            for(ext in extensions){
                temp_path <- glue('{path}/{temp_name}/{temp_name}{ext}')
                if(file.exists(temp_path)){
                    file.rename(temp_path, glue('{path}/{temp_name}/{site_code}{ext}'))
                }
            }
            file.rename(glue('{path}/{temp_name}'),
                        correct_dir)

        } else {

            sf::st_write(locations[i, ],
                         glue('{path}/{site_code}'),
                         driver = 'ESRI Shapefile',
                         delete_dsn = TRUE,
                         quiet = TRUE)
        }
    }
}

pull_usgs_discharge <- function(network, domain, prodname_ms, sites, time_step){

    #This function is used in the case when a domain's discharge data is
    #associated with the USGS and is not available through the domain's portal
    #or the USGS data is preferable

    #sites: a named vector where the name is the site name we would like to be
    #    used in MacroSheds and the value is the USGS gauge ID
    #time_step: either a single input of 'daily' or 'sub_daily' depending what data
    #    is available or perfected. Or a vector the same length as sites with either
    #    'daily' and 'sub_daily'.

    # TODO
    # At some point this function should pull all daily data and sub daily data
    # and combine the two so as much sub daily data is grabbed but when only daily
    # data is available, that is used.

    if(length(time_step) == 1){
        time_step <- rep(time_step, length(sites))
    }

    if(!all(time_step %in% c('daily', 'sub_daily'))){
        stop('time_step can only include daily or sub_daily')
    }

    if(!length(time_step) == length(sites)){
        stop(paste0('time_step must either be a single chracter of daily or ',
        'sub_daily, or a vector of the same length as sites'))
    }

    for(i in 1:length(sites)){

        if(time_step[i] == 'daily'){
            discharge <- dataRetrieval::readNWISdv(sites[i], '00060') %>%
                mutate(datetime = ymd_hms(paste0(Date, ' ', '12:00:00'),
                                          tz = 'UTC')) %>%
                mutate(val = X_00060_00003) %>%
                rename(code = X_00060_00003_cd)
        } else {
            discharge <- dataRetrieval::readNWISuv(sites[i], '00060') %>%
                rename(datetime = dateTime,
                       val = X_00060_00000) %>%
                rename(code = X_00060_00000_cd)
        }

        discharge <- discharge %>%
            as_tibble() %>%
            mutate(site_code = !!names(sites[i]),
                   var = 'discharge',
                   val = val * 28.31685,
                   ms_status = if_else(grepl('^A', code), 0, 1)) %>%
                   #see https://help.waterdata.usgs.gov/codes-and-parameters/instantaneous-value-qualification-code-uv_rmk_cd
            select(site_code, datetime, val, var, ms_status)

        d <- identify_sampling_bypass(discharge,
                                      is_sensor = TRUE,
                                      network = network,
                                      domain = domain,
                                      prodname_ms = prodname_ms)

        d <- qc_hdetlim_and_uncert(d, prodname_ms = prodname_ms)

        d <- synchronize_timestep(d)

        if(! dir.exists(glue('data/{n}/{d}/derived/{p}',
                             n = network,
                             d = domain,
                             p = prodname_ms))){

            dir.create(glue('data/{n}/{d}/derived/{p}',
                            n = network,
                            d = domain,
                            p = prodname_ms),
                       recursive = TRUE)
        }

         write_ms_file(d,
                       network = network,
                       domain = domain,
                       prodname_ms = prodname_ms,
                       site_code = names(sites[i]),
                       level = 'derived',
                       shapefile = FALSE,
                       link_to_portal = FALSE)

         update_prov_dt(sitecd = unname(sites[i]),
                        dt = Sys.time(),
                        usgs = TRUE)
    }

    return()
}

log_with_indent <- function(msg, logger, level = 'info', indent = 1){

    #level is one of "info", "warn", 'error".
    #indent: the number of spaces to indent after the colon.

    indent_str <- paste(rep('\U2800\U2800', indent),
                        collapse = '')

    if(level == 'info'){
        loginfo(msg = paste0(enc2native(indent_str),
                             msg),
                logger = logger)
    } else if(level == 'warn'){
        logwarn(msg = paste0(enc2native(indent_str),
                             msg),
                logger = logger)
    } else if(level == 'error'){
        logerror(msg = paste0(enc2native(indent_str),
                              msg),
                logger = logger)
    }
}

final_cleanup <- function(path){

    #started with more encapsulation, but that's a lot of unneccessary read/write
    #operations, which can be hard on SSDs...

    require_shell_tool('find')
    print('final cleanup...')

    insert_unknown_uncertainties(path = path)
    NaN_to_NA(path = path)
    #make sure portal data got updated

    #...so now dumping operations here. So far:
    #1. convert datetime to date. we no longer have intentions of going sub-daily
    #2. remove sampling regime information from the variable name, into two separate columns
    #   scratch that. separate grab/installed into its own column, but ditch sensor/nonsensor
    #3. change name of "area" column in ws_boundary shapefiles to "ws_area_ha"
    #4. remove empty ws_trait folders

    paths <- list.files(path = path,
                        pattern = '*.feather',
                        recursive = TRUE,
                        full.names = TRUE)

    paths <- grep('/(?:biplot|general)/',
                  paths,
                  value = TRUE,
                  invert = TRUE)

    #1, 2
    for(p in paths){

        read_feather(p) %>%
            rename(date = datetime) %>%
            mutate(date = as.Date(date)) %>%
            tidyr::separate_wider_regex(
                cols = var,
                patterns = c(grab_sample = '.',
                             '..',
                             var = '.*')
            ) %>%
            mutate(grab_sample = grab_sample == 'G') %>%
            write_feather(p)
    }

    #3
    paths <- list.files(path = path,
                        pattern = '\\.shp$',
                        recursive = TRUE,
                        full.names = TRUE)
    paths <- grep('ws_bound', paths, value = TRUE)

    for(p in paths){
        st_read(p, quiet = TRUE) %>%
            rename(ws_area_ha = area) %>%
            st_write(dsn = p,
                     delete_dsn = TRUE,
                     quiet = TRUE)
    }

    #4
    system('find data -type d -empty -delete')
}

insert_unknown_uncertainties <- function(path){

    #loads all feather files in path. replaces val_err with NA for superunknown vars.

    paths <- list.files(path = path,
                        pattern = '*.feather',
                        recursive = TRUE,
                        full.names = TRUE)

    paths <- paths[! grepl('/biplot', paths)]

    for(p in paths){

        if(! 'var' %in% names(feather::feather_metadata(p)$types)) next
        d <- read_feather(p)
        d$val_err[drop_var_prefix(d$var) %in% superunknowns] <- NA
        write_feather(d, p)
    }
}

NaN_to_NA <- function(path){

    #loads all feather files in path. replaces NaN in val or val_err column with NA

    paths <- list.files(path = path,
                        pattern = '*.feather',
                        recursive = TRUE,
                        full.names = TRUE)

    paths <- paths[! grepl('/biplot', paths)]

    for(p in paths){

        if(! 'var' %in% names(feather::feather_metadata(p)$types)) next
        d <- read_feather(p)
        d$val[is.na(d$val)] <- NA
        d$val_err[is.na(d$val_err)] <- NA
        write_feather(d, p)
    }
}

create_missing_stream_gauge_locations <- function(where){

    ntws <- list.files('data', full.names = TRUE)
    ntws <- grep('general|spatial', ntws, invert = TRUE, value = TRUE)

    dmn_paths <- map(ntws, list.files, full.names = TRUE) %>% unlist()
    dmns <- sapply(dmn_paths, function(x) str_split(x, '/')[[1]][3],
                   USE.NAMES = FALSE)

    domains_in_wkflow <- site_data %>%
        filter(in_workflow == 1,
               site_type == 'stream_gauge') %>%
        distinct(domain) %>%
        pull()

    for(i in seq_along(dmns)){

        pth <- dmn_paths[i]
        d <- dmns[i]

        if(! d %in% domains_in_wkflow) next

        derived_dirs <- list.files(file.path(pth, 'derived'))
        if(! any(grepl('stream_gauge_locations', derived_dirs))){

            print(paste(d, 'is missing stream gauge locations!'))
            # site_data %>%
            #     filter(domain == !!d,
            #            in_workflow == 1,
            #            site_type == 'stream_gauge') %>%
            #     select(site_code, latitude, longitude) %>%
            #     st_as_sf(coords = c('longitude', 'latitude'), crs = 4326) %>%
            #     st_write(glue('{where}/5_shapefiles/{d}_stream_gauge_locations.shp'),
            #              driver = 'ESRI Shapefile',
            #              quiet = TRUE)
        }
    }
}

postprocess_attribution_ts <- function(){

    pcm <- tibble()
    for(i in seq_len(nrow(network_domain))){

        pcm <- read_csv(glue('src/{n}/{d}/products.csv',
                             n = network_domain$network[i],
                             d = network_domain$domain[i]),
                        show_col_types = FALSE) %>%
            filter(! retrieve_status %in% c('paused', 'pending')) %>%
            select(prodcode, prodname) %>%
            mutate(domain = network_domain$domain[i]) %>%
            bind_rows(pcm)
    }

    pcm <- pcm %>%
        filter(! is.na(prodcode),
               ! is.na(prodname),
               ! grepl('^ms[0-9]+$', prodcode))

    attrib_d <- googlesheets4::read_sheet(
        conf$site_doi_license_gsheet,
        skip = 4,
        na = c('', 'NA'),
        col_types = 'c'
    )

    attrib_d <- left_join(attrib_d, pcm,
                          by = c(macrosheds_prodcode = 'prodcode', 'domain'),
                          relationship = 'many-to-many')

    attrib_d %>%
        filter(is.na(prodname),
               ! grepl('^ms[0-9]+$', macrosheds_prodcode)) %>%
        select(network, domain, macrosheds_prodcode) %>%
        distinct() %>%
        print(n = 1000)

    get_response_enter('postprocess_attribution_ts is dropping the above records. if that seems right, press ENTER to continue')

    attrib_d <- attrib_d %>%
        relocate(prodname, .after = 'macrosheds_prodcode') %>%
        filter(! is.na(prodname)) %>%
        rename(macrosheds_prodname = prodname) %>%
        distinct() %>%
        arrange(network, domain, macrosheds_prodname, macrosheds_prodcode)

    return(attrib_d)
}

remove_spatial_portal_files <- function(){

    # paths <- list.dirs(path = '../portal/data',
    #                    recursive = TRUE,
    #                    full.names = TRUE)
    # grep('ws_bound|stream_gauge_loc|precip_gauge_loc', paths, value = TRUE)

    print('removing site-level spatial portal files')
    require_shell_tool('find')
    require_shell_tool('rm')

    warning('why is it saying "no such file or directory" even while successfully removing the files?')
    system("find ../portal -type d -name 'ws_boundary' -exec rm -r {} \\;")
    system("find ../portal -type d -name '*gauge_locations' -exec rm -r {} \\;")
}

conform_ws_attr_names <- function(){

    #1. drop all time-words from variable names (since these are aggregated
    #   at different temporal levels, and those levels are apparent from the date/year).
    #   EXCEPTION for the word "annual" in nadp variables. needed to indicate
    #   that although these are given a jan 1 date, they in fact apply to the whole year.
    #2. put the names of statistics after the actual variable names
    #3. remove the variable prefix

    cat('Cleaning up ws attr files and conforming variable names\n')

    var_changes <- c(
        area_ha = 'area',
        ws_area_ha = 'area',
        mean_annual_precip = 'precip_mean',
        mean_annual_temp = 'temp_mean',
        mean_sos = 'sos_mean',
        mean_eos = 'eos_mean',
        mean_los = 'los_mean',
        mean_mos = 'mos_mean',
        mean_annual_gpp_CONUS_30m = 'gpp_CONUS_30m_mean',
        mean_annual_npp_CONUS_250m = 'npp_CONUS_250m_mean',
        mean_annual_gpp_global_500m = 'gpp_global_500m_mean',
        mean_annual_npp_global_500m = 'npp_global_500m_mean',
        mean_annual_et = 'et_ref_mean',
        mean_annual_fpar = 'fpar_mean',
        mean_annual_lai = 'lai_mean',
        mean_annual_tcw = 'tcw_mean',
        mean_annual_ndvi = 'ndvi_mean',
        mean_annual_evi = 'evi_mean',
        snow_depth_ann_mean = 'snow_depth_mean',
        snow_depth_ann_max = 'snow_depth_max',
        snow_depth_ann_min = 'snow_depth_min',
        swe_ann_mean = 'swe_mean',
        swe_ann_max = 'swe_max',
        swe_ann_main = 'swe_min',
        temp_mean_median = 'temp_median',
        temp_mean_sd = 'temp_sd'
    )

    read_feather('../portal/data/general/biplot/year.feather') %>%
        mutate(pfx = extract_var_prefix(var),
               pfx = if_else(pfx == var, '', paste0(pfx, '_')),
               var = drop_var_prefix(var),
               var = sub('_space$', '', var),
               var = sub('^annual_', '', var),
               var = dplyr::recode(var, !!!var_changes),
               var = paste0(pfx, var)) %>%
        select(-pfx) %>%
        write_feather('../portal/data/general/biplot/year.feather')

    attr_ts <- list.files('../portal/data/general/spatial_downloadables',
                          pattern = 'spatial_timeseries',
                          full.names = TRUE)

    for(f in attr_ts){
        trt <- read_csv(f, show_col_types = FALSE) %>%
            mutate(var = drop_var_prefix(var)) %>%
            mutate(var = sub('_space$', '', var),
                   var = sub('^annual_', '', var),
                   var = dplyr::recode(var, !!!var_changes)) %>%
            group_by(var) %>%
            mutate(year = year(date),
                   date = if(length(unique(substr(date, 6, 10))) == 1) NA_Date_ else date) %>%
            ungroup() %>%
            select(network, domain, site_code, var, year, date, val, pctCellErr) %>%
            arrange(network, domain, site_code, year, date) %>%
            write_csv(f)
    }

    read_csv('../portal/data/general/spatial_downloadables/watershed_summaries.csv',
             show_col_types = FALSE) %>%
        rename_with(~substr(., 4, nchar(.)),
                    .cols = 5:ncol(.)) %>%
        rename_with(~dplyr::recode(., !!!var_changes),
                    .cols = 4:ncol(.)) %>%
        rename_with(~sub('_space$', '', .)) %>%
        rename_with(~sub('^annual_', '', .)) %>%
        arrange(network, domain, site_code) %>%
        write_csv('../portal/data/general/spatial_downloadables/watershed_summaries.csv')
}

postprocess_entire_dataset <- function(site_data,
                                       network_domain,
                                       dataset_version,
                                       thin_portal_data_to_interval = NA,
                                       populate_implicit_missing_values,
                                       generate_csv_for_each_product = FALSE,
                                       push_new_version_to_figshare_and_edi = FALSE,
                                       portal_config = NULL){
                                       # filter_ungauged_sites = TRUE){

    #thin_portal_data_to_interval: passed to the "unit" parameter of lubridate::floor_date
    #   set to NA (the dafault) to prevent thinning.
    #push_new_version_to_figshare: if TRUE, publishes the basic version of our dataset that's
    #   stored on Figshare and queried by the macrosheds R package
    #push_new_version_to_figshare_and_edi: if TRUE, publishes the full version of
    #   the dataset to EDI (primary) and Figshare (used by the macrosheds package)

    #for post-derive steps (and patches, honestly) that finalize the dataset and/or
    #save the portal some processing.

    loginfo(msg = 'Postprocessing all domains and products:',
            logger = logger_module)

    # if(filter_ungauged_sites){
    #     log_with_indent('Filtering ungauged sites', logger = logger_module)
    #     site_data <- filter(site_data, site_type != 'stream_sampling_point')
    # }

    log_with_indent('scaling flux by area', logger = logger_module)
    scale_flux_by_area(network_domain = network_domain,
                       site_data = site_data)

    log_with_indent('writing config datasets to local dir', logger = logger_module)
    write_portal_config_datasets()

    log_with_indent('combining watershed boundaries', logger = logger_module)
    combine_ws_boundaries()

    if(! is.na(thin_portal_data_to_interval)){
        log_with_indent('thinning portal datasets to 1 day',
                        logger = logger_module)
        thin_portal_data(network_domain = network_domain,
                         thin_interval = thin_portal_data_to_interval)
    } else {
        log_with_indent('NOT thinning portal datasets',
                        logger = logger_module)
    }

    if(populate_implicit_missing_values){
        log_with_indent('Completing cases (populating implicit missing rows)',
                        logger = logger_module)
        ms_complete_all_cases(network_domain = network_domain)
    } else {
        log_with_indent('NOT completing cases',
                        logger = logger_module)
    }

    log_with_indent('Inserting gap-border NAs in portal dataset (so plots show gaps)',
                    logger = logger_module)
    insert_gap_border_NAs(network_domain = network_domain)

    if(generate_csv_for_each_product){
        log_with_indent('Generating an analysis-ready CSV for each product',
                        logger = logger_module)
        generate_product_csvs(network_domain = network_domain)
    } else {
        log_with_indent('NOT generating analysis-ready CSVs',
                        logger = logger_module)
    }

    log_with_indent(glue('Generating output dataset v',
                         dataset_version),
                    logger = logger_module)
    generate_output_dataset(vsn = dataset_version)

    log_with_indent('final cleanup',
                    logger = logger_module)
    final_cleanup(path = paste0('macrosheds_dataset_v', dataset_version))
    remove_spatial_portal_files()

    log_with_indent('cataloging held data', logger = logger_module)
    catalog_held_data(site_data = site_data,
                      network_domain = network_domain)

    log_with_indent('determining which domains have Q', logger = logger_module)
    list_domains_with_discharge(site_data = site_data)

    # log_with_indent(glue('Removing unneeded files from portal dataset.',
    #                 logger = logger_module)
    # clean_portal_dataset()

    log_with_indent('Generating spatial summary data',
                    logger = logger_module)
    generate_watershed_summaries()

    log_with_indent('Generating spatial timeseries data',
                    logger = logger_module)
    generate_watershed_raw_spatial_dataset()

    log_with_indent('Generating biplot dataset',
                    logger = logger_module)
    compute_yearly_summary(filter_ms_interp = FALSE,
                           filter_ms_status = FALSE)
    compute_yearly_summary_ws()

    conform_ws_attr_names()

    # log_with_indent('Calculating sizes of downloadable files',
    #                 logger = logger_module)
    # compute_download_filesizes()

    if(push_new_version_to_figshare_and_edi){

        message('Are you sure you want to modify our published package dataset? mash ESC within 10 seconds if not.')
        Sys.sleep(10)

        log_with_indent(glue('Preparing dataset v{vv} for Figshare',
                             vv = dataset_version),
                        logger = logger_module)
        fs_dir <- paste0('macrosheds_figshare_v', dataset_version)
        dir.create(fs_dir, showWarnings = TRUE)
        prepare_for_figshare(where = fs_dir,
                             dataset_version = dataset_version)

        # log_with_indent('creating stream_gauge_locations shapefiles where they are missing',
        #                 logger = logger_module)
        #this func is disabled. just a (probably redundant) postcheck now
        create_missing_stream_gauge_locations(where = fs_dir)

        #run precip through the range check again (found crazy low values in luquillo precip) [1]
        #TODO move this upstream
        ff <- system(paste0('find macrosheds_dataset_v', vsn, ' -path "*/precipitation*/*.feather"'),
                     intern = TRUE)
        for(f in ff){
            zz = read_feather(f)
            if(any(na.omit(zz$val) < 0)){
                print(f)
                zz$val[! is.na(zz$val) & zz$val < 0] <- 0
                write_feather(zz, f)
            }
        }

        prepare_for_figshare_packageformat(where = fs_dir,
                                           dataset_version = dataset_version)
        reformat_camels_for_ms(vsn = dataset_version,
                               rebuild = TRUE)

        #run precip through the range check again (found crazy low values in luquillo precip) [1]
        #TODO move this upstream
        ff <- system(paste('find', fs_dir, '-path "*/2_timeseries_data/*/precipitation/*.feather"'),
                     intern = TRUE)
        for(f in ff){
            zz = read_feather(f)
            if(any(na.omit(zz$val) < 0)){
                # print(f)
                zz$val[! is.na(zz$val) & zz$val < 0] <- 0
                write_feather(zz, f)
            }
        }

        # log_with_indent('adding legal metadata to each domain directory',
        #                 logger = logger_module)
        # legal_details_scrape(dataset_version = dataset_version)

        # warning('TEMPORARY: removing all remaining NEON data, flux data, and in-progress domains')
        # remove_flux_neon_etc(where = fs_dir,
        #                      rm_dmns = c('swwd', 'mces', 'streampulse', 'acton_lake'))

        log_with_indent(glue('Uploading dataset v{vv} to Figshare',
                             vv = dataset_version),
                        logger = logger_module)
        # upload_dataset_to_figshare(dataset_version = dataset_version)

        # warning('are name issues like "lncd_lichens" not yet fixed upstream?')
        # system(glue("find {fs_dir} -name '*.csv' | xargs sed -e 's/cloased_shrub/closed_shrub/g' ",
        #             "-e 's/lg_lncd/lg_nlcd/g' -e 's/ci_mean_annual_et/ck_mean_annual_et/g' -i"))
        # system(glue("find ../portal -name '*.csv' | xargs sed -e 's/cloased_shrub/closed_shrub/g' ",
        #             "-e 's/lg_lncd/lg_nlcd/g' -e 's/ci_mean_annual_et/ck_mean_annual_et/g' ",
        #             "-e 's/idbp/igbp/g' -i"))
        # read_feather('../portal/data/general/biplot/year.feather') %>%
        #     mutate(var = ifelse(var == 'lb_igbp_cloased_shrub', 'lb_igbp_closed_shrub', var),
        #            var = ifelse(var == 'lg_lncd_lichens', 'lg_nlcd_lichens', var)) %>%
        #     write_feather('../portal/data/general/biplot/year.feather')

        #make feather versions of ws attr files
        read_csv(file.path(fs_dir, '1_watershed_attribute_data/ws_attr_summaries.csv'),
                 show_col_types = FALSE) %>%
            write_feather(file.path(fs_dir, '1_watershed_attribute_data/ws_attr_summaries.feather'))
        invisible(capture.output(
            lapply(
                list.files(file.path(fs_dir, '1_watershed_attribute_data/ws_attr_timeseries'),
                           full.names = TRUE),
                function(x){
                    write_feather(read_csv(x, show_col_types = FALSE),
                                  sub('\\.csv$', '.feather', x))
                }
            )
        ))

        upload_dataset_to_figshare_packageversion(dataset_version = dataset_version)
    } else {
        log_with_indent('NOT pushing data to Figshare.',
                        logger = logger_module)
    }

    if(push_new_version_to_figshare_and_edi){
        stop('ugh. looks like i computed load from figshare files, but load output is used above, so this needs to move up. possibly it can happen after prepare_for_figshare')
        compute_load()
    } else {
        print('compute_load depends on figshare formatting. skipping')
    }

    if(push_new_version_to_figshare_and_edi){

        log_with_indent(glue('Preparing dataset v{vv} for EDI',
                             vv = dataset_version),
                        logger = logger_module)

        # remotes::install_github('EDIorg/EMLassemblyline')
        library(EMLassemblyline)
        library(EDIutils)

        fs_dir <- paste0('macrosheds_figshare_v', dataset_version)
        dir.create(fs_dir, showWarnings = FALSE)

        wd <- file.path('eml', 'eml_templates')
        ed <- file.path('eml', 'eml_out')
        dd <- file.path('eml', 'data_links')

        if(! length(list.files(wd))) stop('need EML templates. see build_eml_templates.R')

        usr_rsp <- get_response_1char('REMOVING contents of eml/data_links. Might want to back this up. Continue? (y/n) >',
                                      c('y', 'n'))
        if(usr_rsp == 'n') stop('taking no further action')

        unlink(dd, recursive = TRUE)

        dir.create(wd, recursive = TRUE, showWarnings = FALSE)
        dir.create(ed, recursive = TRUE, showWarnings = FALSE)
        dir.create(dd, recursive = TRUE, showWarnings = FALSE)

        prepare_for_edi(from = fs_dir,
                        dataset_version = dataset_version,
                        wd = wd, ed = ed, dd = dd)

        manually_edit_eml()

        # stop('figure out why some Q values have uncertainty, some have 0, some NA. fix and rm the code immediately below this')
        # setwd('~/git/macrosheds/data_acquisition/eml/data_links/')
        # zz = list.files(pattern = '^timeseries_[a-z_]+\\.csv$')
        # for(z in zz){
        #     read_csv(z) %>%
        #         mutate(val_err = ifelse(var_category %in% c('discharge', 'precipitation'), NA_real_, val_err)) %>%
        #         write_csv(z)
        # }

        # log_with_indent(glue('Uploading dataset v{vv} to EDI',
        #                      vv = dataset_version),
        #                 logger = logger_module)
        # upload_dataset_to_edi(dataset_version = dataset_version) #not yet hooked up (can't be unless they change upload size limits for package. rn we need to request permission before upload)
    } else {
        log_with_indent('NOT preparing data for EDI',
                        logger = logger_module)
    }

    message('PUSH NEW macrosheds package version now that figshare ids are updated')
}

compute_load <- function(){

    #need to write out these files, then calc load, THEN zip them up in preparation for figshare.
    #in 2024 they were pre-unzipped for Gubbins+Lowman, but next time macrosheds_files_by_domain needs to be
    #run with notes comments/code toggled

    #20240917 addendum: the comments have been toggled back, so all shoudld be well,
    #but might need to change the location of root_2024? or at least the variable name
    stop('work to do')
    root_2024 <- '~/ssd2/ms_test'

    dir.create('scratch/load_out', showWarnings = FALSE)
    dir.create('scratch/load_diag', showWarnings = FALSE)
    dir.create('logs/load_err', showWarnings = FALSE)

    chemistry <- ms_load_product(macrosheds_root = root_2024,
                                 prodname = 'stream_chemistry',
                                 warn = FALSE)

    q <- ms_load_product(macrosheds_root = root_2024,
                         prodname = 'discharge',
                         warn = FALSE)

    load_sites <- intersect(unique(chemistry$site_code),
                            unique(q$site_code))

    clst <- ms_parallelize(maxcores = 8)

    catch <- foreach::foreach(s = load_sites) %dopar% {

        load_out <- try({
             ms_calc_flux(
                chemistry = filter(chemistry, site_code == !!s),
                q = filter(q, site_code == !!s),
                method = c('pw', 'rating', 'composite', 'beale', 'average'),
                aggregation = 'annual',
                good_year_check = FALSE
            )
        })

        if(inherits(load_out, 'try-error')){
            write_lines(load_out, glue('logs/load_err/{s}.txt'))
        } else {
            write_csv(load_out$load, glue('scratch/load_out/{s}.csv'))
            write_csv(load_out$diagnostics, glue('scratch/load_diag/{s}.csv'))
        }

        return(NULL)
    }

    warning('check logs/load_err!')

    ms_unparallelize(clst)
}

remove_flux_neon_etc <- function(where, rm_dmns){

    loc <- glue('{where}/0_documentation_and_metadata/04_site_documentation/04a_site_metadata.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    loc <- glue('{where}/0_documentation_and_metadata/08_data_irregularities.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    loc <- glue('{where}/1_watershed_attribute_data/ws_attr_summaries.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    loc <- glue('{where}/1_watershed_attribute_data/ws_attr_summaries.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    loc <- glue('{where}/macrosheds_documentation_packageformat/site_metadata.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    loc <- glue('{where}/macrosheds_documentation_packageformat/variable_catalog.csv')
    read_csv(loc) %>%
        filter(! domain %in% rm_dmns) %>%
        write_csv(loc)

    #rm flux
    loc <- glue('{where}/macrosheds_documentation_packageformat/variable_catalog.csv')
    read_csv(loc) %>%
        filter(! chem_category %in% c('precip_flux', 'stream_flux')) %>%
        write_csv(loc)
}

manually_edit_eml <- function(){

    require_shell_tool('ls')
    require_shell_tool('head')

    att <- read_tsv('eml/eml_templates/attributes_ws_attr_summaries.txt',
                    show_col_types = FALSE)

    most_recent_eml <- system('ls -t eml/eml_out/*.xml | head -n 1', intern = TRUE)
    eml <- read_lines(most_recent_eml)

    new_eml_chunk <- c('\t<methods>', '\t\t<methodStep>', '\t\t\t<description>',
                       NA, '\t\t\t</description>', '\t\t</methodStep>', '\t</methods>')

    mvclines <- grep('</missingValueCode>', eml)
    attlines <- grep('</attribute>', eml)
    atnlines <- grep('<attributeName>', eml)

    for(i in rev(seq_along(mvclines))){

        mvcl <- mvclines[i]

        if((mvcl + 1) %in% attlines){

            attl <- mvcl + 1
            attdif <- atnlines - attl
            attdif <- attdif[attdif < 0]
            atnl <- atnlines[which.max(attdif)]
            varn <- str_match(eml[atnl], '\\<attributeName\\>([^\\<]+)\\<\\/attributeName\\>$')[, 2]

            if(length(varn) != 1 || is.na(varn)) stop('problem with varn')

            if(! varn %in% att$attributeName) next

            attdeets <- pull(att[att$attributeName == varn, 'details'])

            if(is.na(attdeets)) next

            new_eml_chunk[4] <- attdeets
            eml <- c(eml[1:mvcl], new_eml_chunk, eml[attl:length(eml)])
        }
    }

    #update access control rule (Mark recommends)
    ctrlline <- grep('^ *<principal(?!>public)', eml, perl = TRUE)
    eml[ctrlline] <- sub('vlahm', 'uid=vlahm,o=EDI,dc=edirepository,dc=org', eml[ctrlline])

    write_lines(eml, most_recent_eml)

    ## (the upload to our server can be automated by uncommenting the following line
    ## (and modifying it to accept a password):
    # system(paste0('rsync -avP eml/data_links macrosheds@104.198.40.189:data/macrosheds_v', vsn))
    message(paste(most_recent_eml, 'is compiled and customized. USE THE PREVIEWER BEFORE PUBLISHING!\nhttps://portal.edirepository.org/nis/metadataPreviewer.jsp'))
    message(glue('Push staging files to server with rsync -avPhz eml/data_links macrosheds@34.122.13.215:data/macrosheds_v{vsn}'))
}

make_figshare_docs_skeleton <- function(where){

    # dir.create(file.path(where, 'macrosheds_documentation'), showWarnings = FALSE, recursive = TRUE)
    # dir.create(file.path(where, 'macrosheds_documentation', '04_site_documentation'), showWarnings = FALSE)
    # dir.create(file.path(where, 'macrosheds_documentation', '05_timeseries_documentation'), showWarnings = FALSE)
    # dir.create(file.path(where, 'macrosheds_documentation', '06_ws_attr_documentation'), showWarnings = FALSE)
    # dir.create(file.path(where, 'macrosheds_documentation', '07_CAMELS-compliant_datasets_documentation'), showWarnings = FALSE)
    # dir.create(file.path(where, 'macrosheds_documentation_packageformat'), showWarnings = FALSE)

    dir.create(file.path(where, '0_documentation_and_metadata'), showWarnings = FALSE, recursive = TRUE)
    dir.create(file.path(where, '0_documentation_and_metadata', '04_site_documentation'), showWarnings = FALSE)
    dir.create(file.path(where, '0_documentation_and_metadata', '05_timeseries_documentation'), showWarnings = FALSE)
    dir.create(file.path(where, '0_documentation_and_metadata', '06_ws_attr_documentation'), showWarnings = FALSE)
    dir.create(file.path(where, '0_documentation_and_metadata', '07_CAMELS-compliant_datasets_documentation'), showWarnings = FALSE)
    dir.create(file.path(where, 'macrosheds_documentation_packageformat'), showWarnings = FALSE)
    dir.create(file.path(where, '3_CAMELS-compliant_watershed_attributes'), showWarnings = FALSE)
    dir.create(file.path(where, '4_CAMELS-compliant_Daymet_forcings'), showWarnings = FALSE)
    dir.create(file.path(where, '5_shapefiles'), showWarnings = FALSE)
}

prepare_site_metadata_for_figshare <- function(outfile){

    #writes to figshare directory, where it then gets moved to edi directory,
    #but also writes the site_data file for the ms package

    figd <- select(site_data,
                   network, pretty_network, domain, pretty_domain, site_code, site_type,
                   epsg_code = CRS,
                   timezone_olson = local_time_zone) %>%
        right_join(read_csv('../portal/data/general/catalog_files/all_sites.csv',
                            col_types = cols()),
                   by = c(pretty_network = 'Network',
                          pretty_domain = 'Domain',
                          site_code = 'SiteCode',
                          site_type = 'SiteType')) %>%
        select(network,
               network_fullname = pretty_network,
               domain,
               domain_fullname = pretty_domain,
               site_code,
               site_fullname = SiteName,
               stream_name = StreamName,
               site_type,
               ws_status = WatershedStatus,
               latitude = Latitude,
               longitude = Longitude,
               epsg_code,
               ws_area_ha = AreaHectares,
               n_observations = Observations,
               n_variables = Variables,
               first_record = FirstRecord,
               last_record = LastRecord,
               timezone_olson)

    ms_site_data <- figd
    save(ms_site_data, file = '../r_package/data/ms_site_data.RData')

    write_csv(figd, outfile)
}

prepare_variable_metadata_for_figshare <- function(outfile, fs_format){

    #outfile: depends on fs_format. if "old", outfile will be written as-is. if
    #   "new", outfile provides only the core part of the output filename, and two
    #   separate output files are written--one for timeseries variables (prepended with '/05_timeseries_documentation/05b_timeseries_'),
    #   and one for ws attr variables (prepended with '/06_ws_attr_documentation/06b_ws_attr_'). missing paths are created if necessary.
    #fs_format: either "old" for compatibility with the original (37 zips) figshare format,
    #   or "new" for the more condensed and user-friendly, but less package-friendly format.
    #   in old-mode, just one variable metadata file is written. in new format, it's split into
    #   timeseries and ws attrs. In new format, range check limits are written too, as a third file.

    #also writes RData file for ms package

    if(fs_format == 'new'){

        outfile_ts <- file.path(dirname(outfile),
                                '05_timeseries_documentation',
                                paste0('05b_timeseries_',
                                       basename(outfile)))
        outfile_ws <- file.path(dirname(outfile),
                                '06_ws_attr_documentation',
                                paste0('06b_ws_attr_',
                                       basename(outfile)))
        outfile_range_check <- file.path(dirname(outfile),
                                         '05_timeseries_documentation',
                                         '05e_range_check_limits.csv')

        ms_vars_ts <- read_csv('../portal/data/general/catalog_files/all_variables.csv',
                         col_types = cols()) %>%
            select(variable_code = VariableCode,
                   variable_name = VariableName,
                   chem_category = ChemCategory,
                   unit = Unit,
                   # method
                   observations = Observations,
                   n_sites = Sites,
                   # mean_obs_per_site = MeanObsPerSite,
                   first_record = FirstRecord,
                   last_record = LastRecord) %>%
            arrange(tolower(variable_name), chem_category)
            # filter(! grepl('_flux$', chem_category)) #TEMP: removing flux metadata

        write_csv(ms_vars_ts, outfile_ts)

        ms_vars_ts <- ms_vars %>%
            filter(! variable_type == 'ws_char') %>%
            select(variable_code, variable_name, unit, molecule, valence, flux_convertible) %>%
            full_join(select(ms_vars_ts, variable_code, chem_category, observations,
                             n_sites, first_record, last_record),
                      by = 'variable_code') %>%
            mutate(n_sites = if_else(is.na(n_sites), 0, n_sites),
                   observations = if_else(is.na(observations), 0, observations)) %>%
            relocate(molecule, valence, .after = 'unit') %>%
            relocate(flux_convertible, .after = 'last_record') %>%
            arrange(tolower(variable_name), chem_category)

        save(ms_vars_ts, file = '../r_package/data/ms_vars_ts.RData')

        univ_codes <- univ_products %>%
            select(starts_with('data_')) %>%
            distinct()

        ms_vars_ws <- ms_vars %>%
            filter(variable_type == 'ws_char') %>%
            # arrange(variable_subtype, tolower(variable_code)) %>%
            select(variable_code, variable_name, unit) %>%
            mutate(
                data_class_code = str_extract(variable_code,
                                              '^([a-z])(?=[a-z]_)',
                                              group = 1),
                data_source_code = str_extract(variable_code,
                                               '^[a-z]([a-z])(?=_)',
                                               group = 1),
                variable_code = drop_var_prefix(variable_code)
            ) %>%
            left_join(univ_codes,
                      by = c('data_class_code', 'data_source_code')) %>%
            select(-matches('data.*code')) %>%
            arrange(data_class, tolower(data_source), tolower(variable_code))

        ms_vars_ws %>%
            filter(! grepl('^multi-year ', variable_name)) %>%
            write_csv('scratch/ms_vars_ws_ts.csv')

        write_csv(ms_vars_ws, outfile_ws)
        save(ms_vars_ws, file = '../r_package/data/ms_vars_ws_attr.RData')

        warning('remove the code below that filters streampulse variables (2 places)')

        ms_vars %>%
            filter(variable_type != 'ws_char') %>%
            select(variable_code, variable_name, unit,
                   range_check_minimum = val_min,
                   range_check_maximum = val_max) %>%
            arrange(tolower(variable_name)) %>%
            filter(! variable_code %in% normally_converted_molecules) %>%
            filter(! variable_code %in% c('model_GPP', 'model_ER', 'model_k600')) %>%
            write_csv(outfile_range_check)

    } else if(fs_format == 'old'){

        ms_vars %>%
            select(variable_code, variable_name, unit, variable_type,
                   variable_subtype, valence, molecule, flux_convertible) %>%
            arrange(variable_type == 'ws_char',
                    tolower(variable_name)) %>%
            filter(! variable_code %in% normally_converted_molecules) %>%
            mutate(variable_code = ifelse(variable_type == 'ws_char',
                                          drop_var_prefix(variable_code),
                                          variable_code)) %>%
            filter(! variable_code %in% c('model_GPP', 'model_ER', 'model_k600')) %>%
            write_csv(outfile)
    }
}

prepare_variable_catalog_for_figshare <- function(outfile){

    #prepare var data catalog files for macrosheds package
    var_cat_files <- list.files('../portal/data/general/catalog_files/indiv_variables',
                                full.names = TRUE)

    var_cat <- map_dfr(var_cat_files,
                       function(x){
                           var_cat_var = str_match(x, '([^/]+)\\.csv$')[, 2]
                           x = read_csv(x, col_types = 'cccccnTTc')
                           x$variable_code = var_cat_var
                           return(x)
                       }) %>%
        left_join(select(site_data, domain, pretty_domain, network, pretty_network) %>%
                      distinct(domain, network, .keep_all = TRUE),
                  by = c(Network = 'pretty_network',
                         Domain = 'pretty_domain')) %>%
        left_join(select(ms_vars, variable_code, variable_name) %>%
                      distinct(),
                  by = 'variable_code') %>%
        select(variable_code, variable_name,
               chem_category = ChemCategory, unit = Unit,
               network, domain, site_code = SiteCode, observations = Observations,
               first_record = FirstRecord, last_record = LastRecord,
               mean_obs_per_day = MeanObsPerDay) %>%
        mutate(mean_obs_per_day = as.numeric(mean_obs_per_day),
               mean_obs_per_day = ifelse(is.infinite(mean_obs_per_day), 1, mean_obs_per_day),
               first_record = as.Date(first_record),
               last_record = as.Date(last_record))

    # #prepare site data catalog files for macrosheds package
    # site_cat_files <- list.files('../portal/data/general/catalog_files/indiv_sites/',
    #                              full.names = TRUE)
    #
    # site_cat <- map_dfr(site_cat_files,
    #                     function(x){
    #                         site_cat_site = str_match(x, '([^/]+)\\.csv$')[, 2]
    #                         x = read_csv(x, col_types = 'ccccccccccc')
    #                         x$site_code = site_cat_site
    #                         return(x)
    #                     }) %>%
    #     site_cat %>%
    #     mutate(site_code = gsub(Domain, '', site_code),
    #            site_code = sub('^_*', '', site_code)) %>%
    #     select(site_code, domain, network)
    #
    #
    #     left_join(select(site_data, domain, network, site_code) %>%
    #                   distinct(domain, network, site_code, .keep_all = TRUE),
    #               by = 'site_code') %>%
    #     select(network, domain, site_code = SiteCode, ####
    #            chem_category = ChemCategory, unit = Unit, observations = Observations,
    #            first_record_utc = FirstRecordUTC, last_record_utc = LastRecordUTC,
    #            mean_obs_per_day = MeanObsPerDay) %>%
    #     mutate(observations = as.numeric(observations),
    #            mean_obs_per_day = as.numeric(mean_obs_per_day),
    #            percent_flagged = as.numeric(percent_flagged),
    #            percent_imputed = as.numeric(percent_imputed),
    #            first_record_utc = ymd_hms(first_record_utc),
    #            last_record_utc = ymd_hms(last_record_utc))

    write_csv(var_cat, outfile)
}

scrape_citations_into_bibtex <- function(d, outfile = NULL){

    #outfile: path to a ".bib" file that will be written. If NULL, text is returned.

    domains_present <- site_data %>%
        filter(in_workflow == 1) %>%
        distinct(domain) %>%
        pull()

    if('retrieved_from_GEE' %in% colnames(d)){
        cites <- d$citation
    } else {
        cites <- d %>%
            filter(domain %in% domains_present) %>%
            arrange(network, domain, macrosheds_prodname) %>%
            pull(citation)
    }

    cites <- unique(cites)

    bib_out <- ''
    for(cc in cites){
        bib_out <- glue(bib_out,
                        convert_ms_to_bib(cc),
                        .open = '<<', .close = '>>', .trim = FALSE)
    }

    if(is.null(outfile)){
        return(bib_out)
    }

    nwisyr <- year(Sys.Date())
    nwis_citation <- glue(
        '\n@misc{nwis_<<nwisyr>>,\n\t',
        'title = {{National} {Water} {Information} {System} data available on the {World} {Wide} {Web} ({USGS} {Water} {Data} for the {Nation})},\n\t',
        'publisher = {National Water Information System},\n\t',
        'author = {{U.S. Geological Survey}},\n\t',
        'year = {<<nwisyr>>},\n\t',
        'url = {http://waterdata.usgs.gov/nwis/}\n}',
        .open = '<<', .close = '>>', .trim = FALSE
    )

    bib_out <- paste0(bib_out, nwis_citation)
    writeLines(bib_out, outfile)

    message('Citations have been written to ', outfile,
            '. Import to Zotero, then export references in AGU style to Data Use Agreements, ',
            'and then press any key to continue.')
    cat('>')
    readLines(n = 1)
}

format_citation_for_DUA <- function(citations){

    #summarizes a vector of citations into the format we use for tables in
    #the Data Use Agreements document, e.g.:
    #Bowden 2021a-d; Kling 2016a-t; 2019; Shaver 2019; Zarnetske 2020; Zarnetske, Bowden, and Abbot 2020a,b

    citations <- unique(citations)

    auths_ <- years_ <- c()
    for(cc in citations){

        title <- find_resource_title(cc)

        comps <- str_split(cc, fixed(paste0('. ', title, '. ')))[[1]]
        comps_ <- str_match(comps[1], '^(.+)?\\. \\(([0-9]{4})\\)$')[, 2:3]

        author <- comps_[1]
        author <- sub('Cary Institute Of Ecosystem Studies',
                      'Cary Institute of Ecosystem Studies',
                      author)
        year <- comps_[2]

        auths_ <- c(auths_, author)
        years_ <- c(years_, year)
    }

    #for institutional author names, replace them with a placeholder so they can
    #be processed properly
    for(i in seq_along(auths_)){

        instid <- sapply(unname(institutional_authors),
                         function(x) str_detect(fixed(auths_[i]), fixed(x)),
                         USE.NAMES = FALSE) %>%
            which()

        if(length(instid)){
            auths_[i] <- str_replace(fixed(auths_[i]),
                                     fixed(unname(institutional_authors[instid])),
                                     names(institutional_authors[instid]))
        }
    }

    uniq_auth_year <- tibble(auths = auths_,
                             years = years_) %>%
        group_by(auths) %>%
        summarize(years = list(sort(as.numeric(years))),
                  n = list(as.integer(table(years))),
                  .groups = 'drop') %>%
        mutate(years = map(years, unique)) %>%
        mutate(etal = str_count(auths, '\\., (?:& )?') + 1 > 2,
               surnames = str_extract_all(auths, '\\b[a-zA-Z]{2,}\\b'))

    #find distinguishing indices for multi-author citations
    uniq_auth_year$distinguishing_elem <- NA_real_
    etals <- which(uniq_auth_year$etal)
    for(i in etals){

        cur_elem <- uniq_auth_year$surnames[[i]]
        other_elems <- uniq_auth_year$surnames[setdiff(etals, i)]

        diff_ind <- 1
        for(j in seq_along(other_elems)){

            comp_elem <- other_elems[[j]]
            min_length <- min(length(cur_elem), length(comp_elem))
            diff_ind_ <- which(cur_elem[1:min_length] != comp_elem[1:min_length])[1]

            diff_ind <- max(c(diff_ind, diff_ind_))
        }

        uniq_auth_year$distinguishing_elem[i] <- diff_ind
    }

    #format compact citation
    out <- c()
    for(i in 1:nrow(uniq_auth_year)){

        author <- uniq_auth_year$auths[i]
        yr <- uniq_auth_year$years[[i]]
        n_auth <- str_count(author, '\\., (?:& )?') + 1

        if(n_auth > 2){

            dist_elem <- uniq_auth_year$distinguishing_elem[i]
            all_auths <- str_extract_all(author, "\\b[a-zA-Z]{2,}\\b")[[1]]

            if(is.na(dist_elem) || n_auth == dist_elem){
                author <- paste(paste(all_auths[-length(all_auths)],
                                      collapse = ', '),
                                all_auths[length(all_auths)],
                                sep = ', & ')
            } else {
                author <- all_auths[1:dist_elem] %>%
                    paste(collapse = ', ') %>%
                    paste0(', et al.')
            }

        } else {
            author <- paste(str_extract_all(author, "\\b[a-zA-Z]{2,}\\b")[[1]],
                            collapse = ' & ')
        }

        for(j in seq_along(yr)){

            yy <- yr[j]
            nn <- uniq_auth_year$n[[i]][j]
            item <- paste(author, yy)

            if(nn > 1){
                item <- paste0(item, 'a-', c(letters, two_letter_seq)[nn])
            }

            out <- c(out, item)
        }
    }

    out <- sort(out)
    bases <- str_extract(out, '.*(?= [0-9]{4}(?:[a-z]\\-[a-z]+)?$)')
    yrs_plus <- str_extract(out, '[0-9]{4}(?:[a-z]\\-[a-z]+)?$')

    just_yr <- duplicated(bases)
    out[just_yr] <- yrs_plus[just_yr]

    #reassign institutional authors to their placeholders
    for(i in seq_along(out)){

        instid <- sapply(substr(names(institutional_authors), 1, 13),
                         function(x) str_detect(fixed(out[i]), fixed(x)),
                         USE.NAMES = FALSE) %>%
            which()

        if(length(instid)){
            out[i] <- sub(substr(names(institutional_authors[instid]),
                                 1, 13),
                          unname(institutional_authors[instid]),
                          out[i])
        }
    }

    str_out <- paste(out, collapse = '; ')

    return(str_out)
}

format_attrib_for_DUA <- function(d, outfile){

    #extract data from attribution gsheet and write it to CSV. It can then be
    #   copied and pasted to the table in the Data Use Agreements

    ss <- site_data %>%
        filter(site_type == 'stream_gauge',
               in_workflow == 1) %>%
        group_by(network, pretty_network, domain) %>%
        summarize(Sites = n(),
                  .groups = 'drop')

    d %>%
        # filter(domain == 'santa_barbara') %>% pull(citation)->citations
        group_by(network, domain) %>%
        summarize(Citations = format_citation_for_DUA(citation),
                  .groups = 'drop') %>%
        left_join(ss, by = c('network', 'domain')) %>%
        arrange(domain) %>%
        select(`Domain code` = domain,
               Network = pretty_network,
               Sites,
               Citations) %>%
        write_csv(outfile)

    message('Section 4.1 table has been written to ', outfile,
            '. Copy it to Data Use Agreements, 0.5 pt border, 8 pt Arial, 0.028 cell padding, middle vertical alignment, no minimum row height, bold header, and then press any key to continue.')
    readLines(n = 1)
}

add_letters_to_attrib_ts <- function(d){

    #changes e.g. "Smith, A. B. 2020" to "Smith, A. B. 2020a", where appropriate

    aa <- str_extract_all(d$citation, '\\([0-9]{4}[a-z]\\)') %>% unlist()
    if(length(aa)) stop('detected old yearletters in citation list')

    d <- d %>%
        arrange(citation) %>%
        mutate(authoryear = str_extract(citation, '.*? \\([12][0-9]{3}\\)'),
               year = str_extract(authoryear, '\\(([12][0-9]{3})\\)', group = 1)) %>%
        group_by(authoryear) %>%
        mutate(year = if(n() > 1) paste0(year, c(letters, two_letter_seq)[1:n()]) else year,
               citation = map2_chr(citation, year,
                                   ~sub('\\(([12][0-9]{3})\\)', glue('({.y})'), .x))) %>%
        ungroup() %>%
        select(-authoryear, -year)

    return(d)
}

assemble_misc_docs_figshare <- function(where){

    docs_dir <- file.path(where, '0_documentation_and_metadata')
    dir.create(docs_dir, showWarnings = FALSE)

    attrib_ts_data_noletters <- postprocess_attribution_ts()
    attrib_ts_data <- add_letters_to_attrib_ts(attrib_ts_data_noletters) %>%
        arrange(network, domain, macrosheds_prodname)
    write_csv(attrib_ts_data,
              file.path(docs_dir, '01b_attribution_and_intellectual_rights_complete.csv'))

    scrape_citations_into_bibtex(
        d = attrib_ts_data_noletters,
        outfile = file.path(docs_dir, '05_timeseries_documentation', '05h_timeseries_refs.bib')
    )
    format_attrib_for_DUA(d = attrib_ts_data_noletters, outfile = 'scratch/DUA.csv')

    attrib_ws_data <- googlesheets4::read_sheet(
        conf$univ_prods_gsheet,
        na = c('', 'NA'),
        col_types = 'c'
    ) %>%
        select(prodname, primary_source = data_source, retrieved_from_GEE = type,
               doi, license, citation, url, addtl_info = notes) %>%
        mutate(retrieved_from_GEE = ifelse(retrieved_from_GEE == 'gee', TRUE, FALSE))

    scrape_citations_into_bibtex(
        d = attrib_ws_data,
        outfile = file.path(docs_dir, '06_ws_attr_documentation', '06h_ws_attr_refs.bib')
    )

    googledrive::drive_download(file = googledrive::as_id(conf$data_use_agreements),
                                path = file.path(docs_dir, '01a_data_use_agreements.docx'),
                                overwrite = TRUE)

    #these datasets required for macrosheds package functioning
    save(attrib_ws_data, file = '../r_package/data/attribution_and_intellectual_rights_ws_attr.RData')
    save(attrib_ts_data, file = '../r_package/data/attribution_and_intellectual_rights_timeseries.RData')

    select(domain_detection_limits, -precision, -sigfigs, -added_programmatically) %>%
        write_csv(file.path(docs_dir, '05_timeseries_documentation', '05f_detection_limits_and_precision.csv'))
    # file.copy('src/templates/figshare_docfiles/05g_detection_limits_and_precision_column_descriptions.txt',
    #           file.path(docs_dir, '05_timeseries_documentation'))
    # file.copy('src/templates/figshare_docfiles/07a_CAMELS-compliant_datasets_metadata.txt',
    #           file.path(docs_dir, '07_CAMELS-compliant_datasets_documentation'))
    # file.copy('src/templates/figshare_docfiles/07b_CAMELS-compliant_ws_attributes_column_descriptions.txt',
    #           file.path(docs_dir, '07_CAMELS-compliant_datasets_documentation'))
    # file.copy('src/templates/figshare_docfiles/07c_CAMELS-compliant_Daymet_forcings_column_descriptions.txt',
    #           file.path(docs_dir, '07_CAMELS-compliant_datasets_documentation'))
    # file.copy('src/templates/figshare_docfiles/02_glossary.txt', docs_dir)
    # file.copy('src/templates/figshare_docfiles/03_changelog.txt', docs_dir)
    # file.copy('/home/mike/git/macrosheds/data_acquisition/src/templates/figshare_docfiles/04b_site_metadata_column_descriptions.txt',
    #           file.path(docs_dir, '04_site_documentation'))
    # file.copy('../portal/static/documentation/timeseries/columns.txt',
    #           file.path(docs_dir, '05_timeseries_documentation', '05d_timeseries_column_descriptions.txt'))
    # file.copy('../portal/static/documentation/watershed_summary/columns.csv',
    #           file.path(docs_dir, '06_ws_attr_documentation', '06f_ws_attr_summary_column_descriptions.csv'))
    # file.copy('../portal/static/documentation/watershed_trait_timeseries/columns.txt',
    #           file.path(docs_dir, '06_ws_attr_documentation', '06g_ws_attr_timeseries_column_descriptions.txt'))
    # file.copy('src/templates/figshare_docfiles/05c_timeseries_variable_metadata_column_descriptions.txt',
    #           file.path(docs_dir, '05_timeseries_documentation'))
    # file.copy('src/templates/figshare_docfiles/06c_ws_attr_variable_metadata_column_descriptions.txt',
    #           file.path(docs_dir, '06_ws_attr_documentation'))
    # file.copy('../portal/data/general/spatial_downloadables/variable_category_codes.csv',
    #           file.path(docs_dir, '06_ws_attr_documentation', '06d_ws_attr_variable_category_codes.csv'))
    # file.copy('../portal/data/general/spatial_downloadables/data_source_codes.csv',
    #           file.path(docs_dir, '06_ws_attr_documentation', '06e_ws_attr_data_source_codes.csv'))

    prepare_data_irreg_doc_for_figshare(outfile = file.path(docs_dir, '08_data_irregularities.csv'))
    prepare_dist_record_for_figshare(outfile = file.path(docs_dir, '09_disturbance_record.csv'))
}

prepare_data_irreg_doc_for_figshare <- function(outfile){

    sm(googlesheets4::read_sheet(
        'https://docs.google.com/spreadsheets/d/1R2eUTwDEHLhBGJ0OJkgt8Aleu1jo0z_b9C4gHrKoRWE/edit#gid=0',
        na = c('', 'NA'),
        col_types = 'ccccccccn'
    )) %>%
        mutate(included_in_current_dataset = as.logical(included_in_current_dataset)) %>%
        write_csv(outfile)
}

prepare_dist_record_for_figshare <- function(outfile){

    dist_rec <- sm(googlesheets4::read_sheet(
        'https://docs.google.com/spreadsheets/d/1jrYTulv3Wnfk3qBghXX1KjynJjkXB7M3n2M0TsdN4ys/edit?gid=0#gid=0',
        na = c('', 'NA'),
        col_types = 'ccccccccDDc'
    ))

    if(any(is.na(dist_rec$watershed_type))){
        stop('missing value in disturbance record "watershed_type" column')
    }

    dist_test <- site_data %>%
        filter(in_workflow == 1,
               site_type != 'rain_gauge') %>%
        select(domain, site_code, ws_status) %>%
        full_join(dist_rec, by = c('domain', 'site_code'))

    dist_test <- dist_test %>%
        select(domain, site_code, x_site_data = ws_status, x_dist = watershed_type, disturbance_source)

    nasum <- is.na(dist_test$x_site_data) + is.na(dist_test$x_dist)
    if(any(is.na(nasum) | nasum == 1)){
        stop('presence/absence mismatch between ws_status (site data) and watershed_type (disturbance record). There should really be only one such column, but there it is for now.')
    }

    distcompare <- dist_test$x_site_data == dist_test$x_dist
    if(any(! distcompare, na.rm = TRUE)){
        stop('value mismatch between ws_status (site data) and watershed_type (disturbance record). There should really be only one such column, but there it is for now.')
    }

    dist_rec %>%
        mutate(watershed_type = case_match(watershed_type,
                                           'exp' ~ 'experimental',
                                           'non_exp' ~ 'non_experimental')) %>%
        rename(watershed_status = watershed_type,
               disturbance_class = disturbance_type,
               disturbance_type = disturbance_def,
               details = disturbance_ex,
               reference = data_source) %>%
        write_csv(outfile)
}

prepare_ts_data_for_figshare <- function(where, dataset_version){

    tld <- file.path(where, 'macrosheds_timeseries_data')

    ## copy over all files from the output dataset. clean up some stuff
    file.copy(from = glue('macrosheds_dataset_v', dataset_version),
              to = where,
              recursive = TRUE)
    file.rename(from = file.path(where, glue('macrosheds_dataset_v', dataset_version)),
                to = tld)

    all_dirs <- list.dirs(tld)

    dmn_dirs <- grep(pattern = 'derived$',
                     x = all_dirs,
                     value = TRUE)

    # warning('temporarily removing NEON (there is another place where this happens)')
    # dmn_dirs <- grep('neon', dmn_dirs, invert = TRUE, value = TRUE)
    # unlink(file.path(tld, 'neon/'), recursive = TRUE)

    for(jd in dmn_dirs){

        ## incise the now-superfluous "derived" directory from the path
        to_folder <- sub(pattern = '/derived$',
                         replacement = '',
                         x = jd)

        system(glue('mv {j}/* {t}',
                    j = jd,
                    t = to_folder))
        file.remove(jd)

        dmn <- str_match(to_folder, '/([^/]+)$')[, 2]

        parent_folder <- sub(pattern = glue('/', dmn),
                             replacement = '',
                             x = to_folder)

        #dip into network dir for convenience. this is not ideal
        setwd(parent_folder)

        # ## TEMP
        # warning('temporarily removing flux from ts data')
        # flux_dirs_to_rm <- grep(pattern = 'flux',
        #                         x = list.files(dmn,
        #                                        full.names = TRUE),
        #                         value = TRUE)
        # invisible(lapply(flux_dirs_to_rm, unlink, recursive = TRUE))
        #
        # zz <- list.files(glue('{dmn}/documentation'), full.names = TRUE, recursive = TRUE)
        # file.remove(grep('flux_inst', zz, value = TRUE))
        # pppf = grep('precip_pchem_pflux', zz, value = TRUE)
        # if(length(pppf) > 1) stop()
        # if(length(pppf) == 1){
        #     read_file(pppf) %>%
        #         str_replace('Special note for flux products:\nOur instantaneous stream flux product is called \"stream_flux_inst\" during standard kernel \nprocessing, but its name changes to \"stream_flux_inst_scaled\" during postprocessing, when each value\nis scaled by watershed area. Consider both of these variant names to refer to the same product wherever\nyou encounter them in our documentation. The same goes for \"precip_flux_inst\" and \"precip_flux_inst_scaled\".\nMore information about postprocessing code is included below.',
        #                     'Special note: flux products are currently not included with the published dataset, but can be generated\nvia the macrosheds package for R. We will soon publish robust annual and monthly\nflux estimates for each siteyear, and at that time we may begin publishing instantaneous flux as well.') %>%
        #         write_file(pppf)
        # }

        ## remove the prodcode extensions from dirnames
        rslt <- character()
        rslt <- system(paste0("rename 's/(.+)__ms[0-9]{3}/$1/' ", dmn, "/* 2>&1"),
                       intern = TRUE)
        if(! is_empty(rslt)){
            setwd('../../..')
            stop(paste('precursor files still present for', dmn))
        }

        ## add a readme to each domain dir
        file.copy(from = '../../../src/templates/figshare_docfiles/ts_docs_readme.txt',
                  to = file.path(dmn, 'documentation', 'README.txt'))

        setwd('../../..')
    }
}

prepare_ws_attr_data_for_figshare <- function(where){

    tld <- file.path(where, 'macrosheds_watershed_attribute_data')

    dir.create(file.path(tld, 'ws_attr_timeseries'),
               showWarnings = FALSE,
               recursive = TRUE)

    ## copy over all files from the portal dataset
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_climate.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'climate.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_hydrology.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'hydrology.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_landcover.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'landcover.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_parentmaterial.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'parentmaterial.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_terrain.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'terrain.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/spatial_timeseries_vegetation.csv',
              to = file.path(tld, 'ws_attr_timeseries', 'vegetation.csv'))
    file.copy(from = '../portal/data/general/spatial_downloadables/watershed_summaries.csv',
              to = file.path(tld, 'ws_attr_summaries.csv'))

    # warning('temporarily removing NEON data')
    # system("find macrosheds_figshare_v1/macrosheds_watershed_attribute_data/ws_attr_timeseries -name '*.csv' | xargs sed -e '/neon/d' -i")
}

prepare_for_figshare <- function(where, dataset_version){

    if(.Platform$OS.type == 'windows'){
        stop(paste('The "system" calls below probably will not work on windows.',
                   'investigate and update those calls if necessary'))
    }

    #prepare documentation and metadata
    make_figshare_docs_skeleton(where = where)
    prepare_site_metadata_for_figshare(outfile = file.path(where, '0_documentation_and_metadata/04_site_documentation/04a_site_metadata.csv'))
    prepare_variable_metadata_for_figshare(outfile = file.path(where, '/0_documentation_and_metadata/variable_metadata.csv'),
                                           fs_format = 'new')
    assemble_misc_docs_figshare(where = where)

    #prepare data
    prepare_ts_data_for_figshare(where = where,
                                 dataset_version = dataset_version)
    prepare_ws_attr_data_for_figshare(where = where)

    #decided to change some dirnames. easiest to just do that as a patch here
    file.rename(file.path(where, 'macrosheds_watershed_attribute_data'),
                file.path(where, '1_watershed_attribute_data'))
    file.rename(file.path(where, 'macrosheds_timeseries_data'),
                file.path(where, '2_timeseries_data'))
}

convert_ts_feathers_to_csv <- function(where){

    fs <- list.files(where,
                     recursive = TRUE,
                     pattern = '\\.feather',
                     full.names = TRUE)

    if(! length(fs)) stop('edi prep already complete?')

    fs_csv <- sub('\\.feather', '.csv', fs)

    for(i in seq_along(fs)){

        f = fs[i]

        read_feather(f) %>%
            write_csv(fs_csv[i])

        file.remove(f)
    }

}

combine_ts_csvs <- function(where){

    #combines all timeseries csvs within a domain into a single
    #csv, containing all sites and variable categories (discharge, stream_chemistry, etc).
    #var_category becomes a column.

    #should be merged with convert_ts_feathers_to_csv for efficiency

    fs <- list.files(where,
                     recursive = TRUE,
                     pattern = '\\.csv',
                     full.names = TRUE)

    domains <- unique(str_match(fs, '2_timeseries_data/[A-Za-z_]+/([A-Za-z_]+)?/.*\\.csv$')[, 2])

    for(d in domains){

        fs_d <- grep(glue('2_timeseries_data/[A-Za-z_]+/{d}?/.*\\.csv$'), fs, value = TRUE)
        network_dir <- paste(str_split(fs_d[1], '/')[[1]][1:3], collapse = '/')
        var_type <- str_match(fs_d, '^[^/]+/[^/]+/[^/]+/[^/]+/([^/]+)')[, 2] %>%
            str_replace('CUSTOM', 'CUSTOM_')

        domain_combined <- tibble()
        for(i in seq_along(fs_d)){

            if(grepl('^CUSTOM_stream', var_type[i]) && d == 'panola'){

                var_subtype <- str_match(fs_d[i], '^[^/]+/[^/]+/[^/]+/[^/]+/[^/]+/([^/]+)')[, 2]
                var_subtype <- paste(var_type[i], var_subtype, sep = '_')
                var_subtype <- sub('_Flx', '', var_subtype)

                domain_combined <- read_csv(fs_d[i], show_col_types = FALSE) %>%
                    mutate(var_category = !!var_subtype) %>%
                    relocate(var_category, .after = 'var') %>%
                    bind_rows(domain_combined)

            } else {

                domain_combined <- read_csv(fs_d[i], show_col_types = FALSE) %>%
                    mutate(var_category = !!var_type[i]) %>%
                    relocate(var_category, .after = 'var') %>%
                    bind_rows(domain_combined)
            }

            file.remove(fs_d[i])
        }

        domain_combined %>%
            arrange(site_code, grepl('^CUSTOM', var_category), var_category, var) %>%
            write_csv(file.path(network_dir, paste0('timeseries_', d, '.csv')))
    }
}

combine_daymet_csvs <- function(where){

    #combines all daymet files into a single csv (for EDI) and feather (for figshare). removes individual csvs.

    fs <- list.files(where,
                     recursive = TRUE,
                     pattern = '\\.csv',
                     full.names = TRUE)

    dd <- map_dfr(fs, read_csv, show_col_types = FALSE) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')

    write_feather(dd, glue('{where}/4_CAMELS-compliant_Daymet_forcings/CAMELS_compliant_Daymet_forcings.feather'))
    write_csv(dd, glue('{where}/4_CAMELS-compliant_Daymet_forcings/CAMELS_compliant_Daymet_forcings.csv'))

    invisible(file.remove(fs))
}

combine_and_move_spatial_objects <- function(from, to){

    #for each domain, combined ws_boundaries, stream_gauge_locations, and precip_gauge_locations
    #one shapefile each. moves from 2_timeseries_data to 5_shapefiles

    dir.create(to, showWarnings = FALSE)

    fs <- list.files(from,
                     recursive = TRUE,
                     pattern = '\\.shp',
                     full.names = TRUE)

    domains <- unique(str_match(fs, '2_timeseries_data/[A-Za-z_]+/([A-Za-z_]+)?/.*\\.shp$')[, 2])

    for(d in domains){

        fs_d <- grep(glue('2_timeseries_data/[A-Za-z_]+/{d}?/.*\\.shp$'), fs,
                     value = TRUE)
        dirsplit <- str_split(fs_d[1], '/')[[1]]
        network_dir <- paste(dirsplit[1:3], collapse = '/')
        domain_dir <- paste(dirsplit[1:4], collapse = '/')
        shape_types <- unique(str_match(fs_d, glue('^{domain_dir}/([a-z_]+)'))[, 2])
        network_dir <- sub(from, to, network_dir)

        for(shape_type in shape_types){

            fs_d_t <- grep(shape_type, fs_d, value = TRUE)

            domain_combined <- st_read(fs_d_t[1], quiet = TRUE)
            st_delete(fs_d_t[1],
                      driver = 'ESRI Shapefile',
                      quiet = TRUE)
            fs_d_t <- fs_d_t[-1]

            for(i in seq_along(fs_d_t)){

                domain_combined <- st_read(fs_d_t[i], quiet = TRUE) %>%
                    bind_rows(domain_combined)

                st_delete(fs_d_t[i],
                          driver = 'ESRI Shapefile',
                          quiet = TRUE)
            }

            if(shape_type == 'ws_boundary') shape_type <- 'ws_boundaries'
            st_write(domain_combined, glue('{to}/{d}_{shape_type}.shp'),
                     quiet = TRUE)
        }
    }
}

prepare_for_edi <- function(from, dataset_version){

    log_with_indent('Converting 2_timeseries_data feathers to CSV (takes a few mins)',
                    indent = 2,
                    logger = logger_module)
    convert_ts_feathers_to_csv(file.path(from, '2_timeseries_data'))

    log_with_indent('Combining 2_timeseries_data CSVs (takes a few mins. should be merged with the previous func)',
                    indent = 2,
                    logger = logger_module)
    combine_ts_csvs(file.path(from, '2_timeseries_data'))

    # log_with_indent('Combining 4_CAMELS-compliant_Daymet_forcings CSVs',
    #                 indent = 2,
    #                 logger = logger_module)
    # combine_daymet_csvs(file.path(from, '4_CAMELS-compliant_Daymet_forcings'))
    #
    # log_with_indent('Combining ws attrs (separately for ms and camels-compliant)',
    #                 indent = 2,
    #                 logger = logger_module)
    # combine_ws_attrs(from)

    log_with_indent('Combining spatial objects by domain',
                    indent = 2,
                    logger = logger_module)
    combine_and_move_spatial_objects(from = file.path(from, '2_timeseries_data'),
                                     to = file.path(from, '5_shapefiles'))

    eml_misc(from)

    build_eml_data_links_and_generate_eml(from, vsn = dataset_version,
                                          wd = wd, dd = dd, ed = ed)
}

build_eml_data_links_and_generate_eml <- function(where, vsn){

    message('build_eml_data_links_and_generate_eml could still be cleaned up a bit, and possibly further automated')

    require_shell_tool('pandoc', path = '/home/mike/anaconda3/bin') #if you have pandoc installed globally, remove path arg

    # rm_networks <- c('webb', 'mwo')
    rm_networks <- c() #use this if not removing any networks this round

    #update this if necessary**
    warning('is bear still the only non-lter network that\'s on EDI?')
    non_lter_networks_on_edi <- c('bear')

    ##grab resources from gsheets (etc)

    file.copy(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/09_disturbance_record.csv'),
              file.path(dd, 'disturbance_record.csv'))

    googlesheets4::read_sheet(
        conf$univ_prods_gsheet,
        na = c('', 'NA'),
        col_types = 'c'
    ) %>%
        select(prodname, primary_source = data_source, retrieved_from_GEE = type,
               doi, license, citation, url, addtl_info = notes) %>%
        mutate(retrieved_from_GEE = ifelse(retrieved_from_GEE == 'gee', TRUE, FALSE)) %>%
        write_csv(file.path(dd, 'attribution_and_intellectual_rights_ws_attr.csv'))

    ##build provenance table

    prov <- read_csv(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/01b_attribution_and_intellectual_rights_complete.csv'),
                     show_col_types = FALSE) %>%
        mutate(dataPackageID = NA_character_, systemID = NA_character_, title = NA_character_,
               givenName = NA_character_, middleInitial = NA_character_,
               surName = NA_character_, role = NA_character_,
               onlineDescription = NA_character_) %>%
        select(dataPackageID, systemID, title, givenName,
               middleInitial, surName, role, organizationName = network,
               email = contact, onlineDescription = citation, url = link, contact_name1, creator_name1)

    prov <- filter(prov, ! organizationName %in% rm_networks)

    lter_sites <- prov$organizationName == 'lter'
    other_edi_sites <- prov$organizationName %in% non_lter_networks_on_edi

    prov$systemID[lter_sites | other_edi_sites] <- 'EDI'

    prov$dataPackageID[lter_sites | other_edi_sites] <-
        get_edi_identifier(prov$url[lter_sites | other_edi_sites])

    prov$title[! lter_sites] <- find_resource_title(prov$onlineDescription[! lter_sites])
    prov2 <- prov

    prov[! lter_sites, c('givenName', 'middleInitial', 'surName')] <- split_names(prov$contact_name1[! lter_sites])
    prov2[! lter_sites, c('givenName', 'middleInitial', 'surName')] <- split_names(prov$creator_name1[! lter_sites])
    prov$role[! lter_sites] <- 'contact'
    prov2$role[! lter_sites] <- 'creator'
    prov <- select(prov, -creator_name1, -contact_name1)
    prov2 <- select(prov2, -creator_name1, -contact_name1)
    prov <- bind_rows(prov, prov2) %>%
        arrange(organizationName, dataPackageID, title)

    write_tsv(prov, file.path(wd, 'provenance.txt'), na = '', quote = 'all')

    ## link misc files

    ts_tables <- list.files(glue('macrosheds_figshare_v{vsn}/2_timeseries_data'), pattern = '\\.csv$',
                            recursive = TRUE, full.names = TRUE)

    files_to_link <- c(
        ts_tables,
        list.files(glue('macrosheds_figshare_v{vsn}/1_watershed_attribute_data'),
                   full.names = TRUE, recursive = TRUE),
        glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.csv'),
        glue('macrosheds_figshare_v{vsn}/4_CAMELS-compliant_Daymet_forcings/CAMELS_compliant_Daymet_forcings.csv'),
        glue('macrosheds_figshare_v{vsn}/macrosheds_documentation_packageformat/site_metadata.csv'),
        glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/05_timeseries_documentation/05b_timeseries_variable_metadata.csv'),
        glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/05_timeseries_documentation/05e_range_check_limits.csv'),
        glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/05_timeseries_documentation/05f_detection_limits_and_precision.csv'),
        glue('scratch/ms_vars_ws_ts.csv'),
        # glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/06_ws_attr_documentation/06d_ws_attr_variable_category_codes.csv'),
        # glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/06_ws_attr_documentation/06e_ws_attr_data_source_codes.csv'),
        glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/08_data_irregularities.csv'),
        glue('macrosheds_figshare_v{vsn}/macrosheds_documentation_packageformat/variable_catalog.csv'),
        glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/attribution_and_intellectual_rights_timeseries.csv')
    )

    basenames <- basename(files_to_link)
    basenames <- sub('^0[1-9][a-z]?_', '', basenames)
    basenames <- sub('site_metadata', 'sites', basenames)
    basenames <- sub('timeseries_variable_metadata', 'variables_timeseries', basenames)
    basenames <- sub('ms_vars_ws_ts', 'variables_ws_attr_timeseries', basenames)
    # basenames <- sub('ws_attr_variable_category_codes', 'variable_category_codes_ws_attr', basenames)
    # basenames <- sub('ws_attr_data_source_codes', 'variable_data_source_codes_ws_attr', basenames)
    basenames <- sub('detection_limits_and_precision', 'detection_limits', basenames)
    basenames <- sub('CAMELS_compliant_ws_attr', 'CAMELS_compliant_ws_attr_summaries', basenames)
    basenames <- sub('variable_catalog', 'data_coverage_breakdown', basenames)
    link_locs <- file.path(dd, basenames)
    basenames <- c(basenames, 'disturbance_record.csv')
    basenames <- c(basenames, 'attribution_and_intellectual_rights_ws_attr.csv')

    descriptions <- basenames
    descriptions <- str_replace(descriptions,
                                '^attribution_and_intellectual_rights_ws_attr\\.csv$',
                                'Specific license requirements and expectations associated with each primary time-series dataset. See data_use_agreements.docx and attribution_and_intellectual_right_ws_attr.csv')
    descriptions <- str_replace(descriptions,
                                '^timeseries_([a-z_]+)\\.csv$',
                                'Time-series (streamflow, precip if available, chemistry) for domain: \\1. See variables_timeseries.csv and variable_sample_regimen_codes_timeseries.csv')
    descriptions <- str_replace(descriptions,
                                '^ws_attr_summaries\\.csv$',
                                'Watershed attribute data, summarized across time, for all domains')
    descriptions <- str_replace(descriptions,
                                '^ws_attr_timeseries\\.csv$',
                                'Watershed attribute data, temporally explicit, for all domains. See variables_ws_attr_timeseries.csv, variable_category_codes_ws_attr.csv, and variable_data_source_codes_ws_attr.csv')
    descriptions <- str_replace(descriptions,
                                '^CAMELS_compliant_ws_attr_summaries\\.csv$',
                                'Watershed attribute data, temporally explicit, for all domains, and interoperable with the CAMELS dataset (https://ral.ucar.edu/solutions/products/camels)')
    descriptions <- str_replace(descriptions,
                                '^CAMELS_compliant_Daymet_forcings\\.csv$',
                                'Daymet climate forcings for all domains; interoperable with the CAMELS dataset (https://ral.ucar.edu/solutions/products/camels)')
    descriptions <- str_replace(descriptions,
                                '^sites\\.csv$',
                                'Stream site metadata')
    descriptions <- str_replace(descriptions,
                                '^variables_timeseries\\.csv$',
                                'Time-series variable metadata (standard units, etc.)')
    descriptions <- str_replace(descriptions,
                                '^range_check_limits\\.csv$',
                                'Minimum and maximum values allowed to pass through our range filter. Values exceeding these limits are omitted from the MacroSheds dataset.')
    descriptions <- str_replace(descriptions,
                                '^detection_limits\\.csv$',
                                'Primary data source detection limits')
    descriptions <- str_replace(descriptions,
                                '^variables_ws_attr_timeseries\\.csv$',
                                'Watershed attribute variable metadata (standard units and definitions)')
    # descriptions <- str_replace(descriptions,
    #                             '^variable_category_codes_ws_attr\\.csv$',
    #                             'Watershed attribute category codes (the second letter of the variable code prefix)')
    # descriptions <- str_replace(descriptions,
    #                             '^variable_data_source_codes_ws_attr\\.csv$',
    #                             'Watershed attribute data source codes (the first letter of the variable code prefix)')
    descriptions <- str_replace(descriptions,
                                '^data_irregularities\\.csv$',
                                'Any notable inconsistencies within the MacroSheds dataset')
    descriptions <- str_replace(descriptions,
                                '^disturbance_record\\.csv$',
                                'A register of known watershed experiments and significant natural disturbances')
    descriptions <- str_replace(descriptions,
                                '^attribution_and_intellectual_rights_ws_attr\\.csv$',
                                'Information about fair use of watershed attribute data. See also attribution_and_intellectual_rights_timeseries.csv.')
    descriptions <- str_replace(descriptions,
                                '^data_coverage_breakdown\\.csv$',
                                'Number of observations, timespan of observation, by variable and site')

    for(i in seq_along(files_to_link)){
        sw(file.remove(link_locs[i]))
        sw(file.link(files_to_link[i], link_locs[i]))
    }

    ## link additional files that will be grouped under "other entities"

    sw(file.remove(file.path(dd, 'data_use_agreements.docx')))
    file.link(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/01a_data_use_agreements.docx'),
              file.path(dd, 'data_use_agreements.docx'))
    sw(file.remove(file.path(dd, 'timeseries_refs.bib')))
    file.link(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/05_timeseries_documentation/05h_timeseries_refs.bib'),
              file.path(dd, 'timeseries_refs.bib'))
    sw(file.remove(file.path(dd, 'ws_attr_refs.bib')))
    file.link(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/06_ws_attr_documentation/06h_ws_attr_refs.bib'),
              file.path(dd, 'ws_attr_refs.bib'))
    sw(file.remove(file.path(dd, 'changelog.txt')))
    file.link('CHANGELOG.md',
              file.path(dd, 'changelog.md'))
    sw(file.remove(file.path(dd, 'glossary.txt')))
    file.link(glue('src/templates/figshare_docfiles/02_glossary.txt'),
              file.path(dd, 'glossary.txt'))

    ## compile changelog to HTML

    #add your own path if pandoc is installed via conda, or remove path if it's
    #installed system-wide
    system('/home/mike/anaconda3/bin/pandoc eml/data_links/changelog.md -o eml/data_links/changelog.html --metadata=charset="UTF-8"')
    get_response_enter('Updated eml/data_links/changelog.html needs to be posted to https://macrosheds.org/pages/changelog.html.\nUpload it to our server and replace the old file, then press enter to continue.\n>')

    ## zip documentation.txt files together

    docfiles <- list.files(glue('macrosheds_figshare_v{vsn}/2_timeseries_data'),
                           full.names = TRUE, recursive = TRUE,
                           pattern = 'documentation_.*?\\.txt')

    docdir <- glue('{dd}/code_autodocumentation')
    dir.create(docdir)

    ntws <- unique(str_match(docfiles, glue('^macrosheds_figshare_v{vsn}/2_timeseries_data/([a-z_]+)'))[, 2])
    for(i in seq_along(ntws)){

        dir.create(file.path(docdir, ntws[i]))
        dmns <- list.files(glue('macrosheds_figshare_v{vsn}/2_timeseries_data/{ntws[i]}'))
        dmns <- grep('\\.csv', dmns, invert = TRUE, value = TRUE)
        for(j in seq_along(dmns)){

            dir.create(file.path(docdir, ntws[i], dmns[j]))
            fs <- list.files(glue('macrosheds_figshare_v{vsn}/2_timeseries_data/{ntws[i]}/{dmns[j]}/documentation'), full.names = TRUE)
            fs <- grep('README.txt$', fs, invert = TRUE, value = TRUE)
            file.copy(fs, file.path(docdir, ntws[i], dmns[j]))
        }
    }

    setwd(dd)
    zip('code_autodocumentation.zip', files = list.files('code_autodocumentation', full.names = TRUE), flags = '-r9Xq')
    setwd('../..')

    ## sample regimen codes

    # reg_codes = tribble(~sample_regimen_code, ~definition,
    #                     'IS', 'Sample collected by an Installed Sensor.',
    #                     'GN', 'Sample collected by hand (Grab sample) without a sensor (Non-sensor), e.g. a water sample for lab analysis.',
    #                     'IN', 'Sample collected via an Installed apparatus, though not with a sensor per se (Non-sensor). This is rare.',
    #                     'GS', 'Sample collected by hand (Grab sample), using a handheld Sensor.')
    #
    # write_csv(reg_codes, file.path(dd, 'variable_sample_regimen_codes_timeseries.csv'))
    #
    # basenames = c(basenames, 'variable_sample_regimen_codes_timeseries.csv')
    # descriptions = c(descriptions, 'Time-series sample regimen codes (the two-letter prefix on all time-series variable names)')

    ## include bibtex files with macrosheds R package

    ts_bib <- readr::read_file('eml/data_links/timeseries_refs.bib')
    save(ts_bib, file = '../r_package/data/bibtex_timeseries.RData')
    ws_bib <- readr::read_file('eml/data_links/ws_attr_refs.bib')
    save(ws_bib, file = '../r_package/data/bibtex_ws_attr.RData')

    ## load estimates and diagnostics

    ntw_dmn_join <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        select(domain, network, site_code)

    sw(map_dfr(list.files('scratch/load_out', full.names = TRUE),
                     read_csv, col_types = 'ccnncl') %>%
        filter(! is.na(load)) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        arrange(network, domain, site_code, var, water_year) %>%
        select(network, domain, site_code, var, water_year, everything()) %>%
        write_csv(file.path(dd, 'load_annual.csv')))

    map_dfr(list.files('scratch/load_diag', full.names = TRUE),
            read_csv, col_types = 'ccnnnnnnn') %>%
        select(-any_of('ws_area_ha')) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        arrange(network, domain, site_code, var, water_year) %>%
        select(network, domain, site_code, var, water_year, everything()) %>%
        write_csv(file.path(dd, 'load_annual_diagnostics.csv'))

    ## misc

    read_csv(glue('macrosheds_figshare_v{vsn}/0_documentation_and_metadata/01b_attribution_and_intellectual_rights_complete.csv'),
             show_col_types = FALSE) %>%
        filter(! network %in% rm_networks) %>%
        write_csv(file.path(dd, 'attribution_and_intellectual_rights_timeseries.csv'))

    file.remove(list.files(dd, pattern = '.*\\.feather$', full.names = TRUE)) #not sure how these got there, but doesn't matter
    basenames = grep('\\.feather$', basenames, invert = TRUE, value = TRUE)
    descriptions = grep('\\.feather$', descriptions, invert = TRUE, value = TRUE)

    # if(rm_neon_sites){
    #     read_csv('eml/data_links/CAMELS_compliant_Daymet_forcings.csv') %>%
    #         filter(! site_code %in% neon_sites) %>%
    #         write_csv('eml/data_links/CAMELS_compliant_Daymet_forcings.csv')
    #     read_csv('eml/data_links/CAMELS_compliant_ws_attr_summaries.csv') %>%
    #         filter(! site_code %in% neon_sites) %>%
    #         write_csv('eml/data_links/CAMELS_compliant_ws_attr_summaries.csv')
    # }

    #(re)create attributes and catvars templates for all domains, using hbef as template-template

    var_cat_map <- c(
        stream_chemistry = 'Stream chemistry',
        precip_chemistry = 'Precipitation chemistry',
        precipitation = 'Precipitation depth',
        discharge = 'Stream discharge',
        stream_flux_inst_scaled = 'Daily stream flux, scaled by watershed area, reported in kg/ha/d.',
        precip_flux_inst_scaled = 'Daily precipitation flux, scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_precipitation = 'Custom product. Redistributed as computed by primary source, so nonstandard within the MacroSheds corpus. Precipitation depth.',
        CUSTOM_stream_flux_inst_scaled = 'Custom product. Redistributed as computed by primary source, so nonstandard within the MacroSheds corpus. Daily stream flux, scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_precip_flux_inst_scaled = 'Custom product. Redistributed as computed by primary source, so nonstandard within the MacroSheds corpus. Daily precipitation flux, scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_stream_flux_inst_scaled_RefMod = 'Custom product. Redistributed as computed by primary source (in this case Panola Mountain Research Watershed), so nonstandard within the MacroSheds corpus. Daily stream flux for reference model, computed by the regression method and scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_stream_flux_inst_scaled_RefTot = 'Custom product. Redistributed as computed by primary source (in this case Panola Mountain Research Watershed), so nonstandard within the MacroSheds corpus. Daily stream flux for reference model, computed by the composite method and scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_stream_flux_inst_scaled_ClmMod = 'Custom product. Redistributed as computed by primary source (in this case Panola Mountain Research Watershed), so nonstandard within the MacroSheds corpus. Daily stream flux for climate models, computed by the regression method and scaled by watershed area, reported in kg/ha/d.',
        CUSTOM_stream_flux_inst_scaled_ClmTot = 'Custom product. Redistributed as computed by primary source (in this case Panola Mountain Research Watershed), so nonstandard within the MacroSheds corpus. Daily stream flux for climate models, computed by the composite method and scaled by watershed area, reported in kg/ha/d.',
        stream_flux_inst = 'Daily stream flux, NOT scaled by watershed area. Only for watersheds with unknown boundaries. Reported in kg/d.'
    ) %>%
        stack() %>%
        rename(definition = values,
               var_category = ind)

    ts_fls <- list.files('eml/data_links', pattern = '^timeseries.*?\\.csv')
    ts_fls <- grep('hbef\\.csv$', ts_fls, value = TRUE, invert = TRUE)
    ts_dmns <- str_match(ts_fls, '^timeseries_([a-z_0-9]+)\\.csv$')[, 2]
    for(td in ts_dmns){

        file.copy(from = 'eml/eml_templates/attributes_timeseries_hbef.txt',
                  to = glue('eml/eml_templates/attributes_timeseries_{td}.txt'),
                  overwrite = TRUE)

        read_csv(glue('eml/data_links/timeseries_{td}.csv'),
                 show_col_types = FALSE) %>%
            distinct(var_category) %>%
            left_join(var_cat_map, by = 'var_category') %>%
            mutate(attributeName = 'var_category') %>%
            select(attributeName, code = var_category, definition) %>%
            write_tsv(glue('eml/eml_templates/catvars_timeseries_{td}.txt'))
    }

    ## "logical" is an illegal data class in EML... Need to convert to integer.

    message('Converting grab_sample to numeric. This modification should be moved upstream, before files are linked')
    ts_fls <- list.files('eml/data_links',
                         pattern = '^timeseries.*?\\.csv',
                         full.names = TRUE)
    for(f in ts_fls){
        read_csv(f, show_col_types = FALSE) %>%
            mutate(grab_sample = as.numeric(grab_sample)) %>%
            write_csv(f)
    }

    read_csv('eml/data_links/load_annual.csv') %>%
        mutate(ms_recommended = as.numeric(ms_recommended)) %>%
        write_csv('eml/data_links/load_annual.csv')

    ## a few more deets

    temporal_coverage <- map(ts_tables, ~range(read_csv(., show_col_types = FALSE)$date)) %>%
        reduce(~c(min(c(.x[1], .y[1])), max(c(.x[2], .y[2]))))

    # if(rm_neon_sites){
    #     file.copy('eml/eml_templates/geographic_coverage.txt', '/tmp/aaa', overwrite = TRUE)
    #     read_lines('eml/eml_templates/geographic_coverage.txt') %>%
    #         str_subset(paste0('^', paste(neon_sites, collapse = '|')), negate = TRUE) %>%
    #         write_lines('eml/eml_templates/geographic_coverage.txt')
    # }

    other_entities <- c('shapefiles.zip',
                        'data_use_agreements.docx',
                        'timeseries_refs.bib',
                        'ws_attr_refs.bib',
                        'changelog.html',
                        'glossary.txt',
                        'code_autodocumentation.zip')

    other_ent_desc <- c(
        'Watershed boundaries, stream gauge locations, and precip gauge locations, for all domains.',
        'Terms and conditions for using MacroSheds data.',
        'Complete bibliographic references for time-series data.',
        'Complete bibliographic references for watershed attribute data.',
        'List of improvements and bugfixes associated with each version of the MacroSheds dataset. File hosted at https://macrosheds.org/pages/changelog.html',
        'Glossary of terms related to the MacroSheds dataset.',
        'Programmatically assembled pseudo-scripts intended to help users recreate/edit specific MacroSheds data products (Also see our code on GitHub).'
    )

    #add load stuff
    basenames <- c(basenames, 'load_annual.csv')
    descriptions <- c(descriptions, 'Annual solute loads for each site, computed by up to 5 methods, and with a recommended method based on Aulenbach et al. 2016')

    #rebuild geographic coverage template
    if(file.exists(file.path(wd, 'geographic_coverage.txt'))){
        file.remove(file.path(wd, 'geographic_coverage.txt'))
    }
    template_geographic_coverage(wd, dd, 'sites.csv',
                                 lat.col = 'latitude', lon.col = 'longitude',
                                 site.col = 'site_code')

    edi_pkg_id <- glue('edi.1262.{vsn}')

    #supported classes: character, numeric, categorical, Date
    make_eml(wd, dd, ed,
             dataset.title = 'MacroSheds: a synthesis of long-term biogeochemical, hydroclimatic, and geospatial data from small watershed ecosystem studies',
             temporal.coverage = temporal_coverage,
             geographic.description = NULL,#not needed if geographic_coverage.txt exists,
             geographic.coordinates = NULL,#same,
             maintenance.description = 'ongoing',
             data.table = basenames,
             data.table.name = basenames,
             data.table.description = descriptions,
             data.table.quote.character = rep('"', length(basenames)),
             data.table.url = glue('https://macrosheds.org/data/macrosheds_v{vsn}/{basenames}'),
             other.entity = other_entities,
             other.entity.name = other_entities,
             other.entity.description = other_ent_desc,
             other.entity.url = glue('https://macrosheds.org/data/macrosheds_v{vsn}/{other_entities}'),
             user.id = conf$edi_user_id,
             user.domain = NULL, #pretty sure this doesn't apply to us
             package.id = edi_pkg_id)

    #use this to fix issues related to attribute ordering
    # z_order_to = read_csv('eml/data_links/ws_attr_summaries.csv',
    #                       na = '') %>%
    #     colnames()
    # z_order_from = read_tsv('eml/eml_templates/attributes_ws_attr_summaries.txt')
    # if(length(z_order_to) != length(z_order_from$attributeName)) stop()
    # z_order_from[match(z_order_to, z_order_from$attributeName), ] %>%
    #     mutate(missingValueCode = 'NA') %>%
    #     write_tsv('eml/eml_templates/attributes_ws_attr_summaries.txt',
    #               na = '')

    # if(rm_neon_sites){
    #     file.copy('/tmp/aaa', 'eml/eml_templates/geographic_coverage.txt', overwrite = TRUE)
    # }
}

get_edi_identifier <- function(x){

    #x is a vector of EDI URLs. expects a form like
    #https://portal.edirepository.org/nis/mapbrowse?scope=edi&identifier=618&revision=1 or
    #https://portal.edirepository.org/nis/mapbrowse?scope=edi&identifier=621 or
    #https://portal.edirepository.org/nis/mapbrowse?scope=knb-lter-bes&identifier=900&revision=450 or
    #https://portal.edirepository.org/nis/mapbrowse?scope=knb-lter-bes&identifier=900

    x <- str_replace(x,
                     'https://portal.edirepository.org/nis/mapbrowse\\?scope=([a-z\\-]+)&identifier=([0-9]+)(?:&revision=([0-9]+))?$',
                     '\\1.\\2.\\3')

    x <- sub('\\.$', '.1', x)

    return(x)
}

find_resource_title <- function(x){

    #x: a vector of citation strings

    out <- sapply(x, function(xx){

        xx <- gsub('Mt. ', 'Mt ', xx)

        is_edi <- grepl('Environmental Data Initiative', xx)

        xspl <- strsplit(xx, '\\. ')[[1]]
        xspl <- xspl[! grepl('National Ecological Observatory Network', xspl)]
        xspl <- xspl[! grepl('Carbon Dioxide Information Analysis Center, Oak Ridge National Laboratory, U.S', xspl)]
        xspl <- xspl[! grepl('USDA Forest Service', xspl)]
        xspl <- xspl[! grepl('Susquehanna', xspl)]
        xspl <- xspl[! grepl('Dataset accessed from', xspl)]
        xspl <- xspl[! grepl('Williams', xspl)]
        xspl <- xspl[! grepl('^http', xspl)]
        xspl <- xspl[! grepl('Environmental Data Initiative', xspl)]
        xspl <- xspl[! grepl('^HydroShare$', xspl)]
        xspl <- Filter(function(x) ! x %in% known_publishers, xspl)
        xspl <- xspl[! grepl(', [A-Z]\\.,', xspl)]

        if(is_edi){
            xspl <- xspl[! grepl('^ver [0-9]+$', xspl)]
            xspl <- xspl[-(1:which(grepl('^\\(?[0-9]{4}[a-z]*\\)?$', xspl)))]
            # xspl <- xspl[-(1:which(grepl('^[0-9]{4}$', xspl)))]
            xspl <- paste(xspl, collapse = '. ')
        }
        #probs safe to build this. i feel like there's inconsistency in hydroshare
        #citations though. check on it first.
        # if(is_hydroshare)...

        xspl <- gsub('\\.$', '', xspl)

        xspl[which.max(nchar(xspl))]

    }, USE.NAMES = FALSE)

    out <- sub('in the Mt Hood National Forest',
               'in the Mt. Hood National Forest',
               out)

    return(out)
}

split_names <- function(x){

    #expects a vector of names, e.g.
    #Jane Doe
    #J. Doe
    #Jane H. Doe
    #J. H. Doe

    institution_indicators <- c('science', 'center', 'service', 'group', 'institute', 'department', 'national')

    xsep <- lapply(x, function(xx){

        if(is.na(xx)) return(c(NA_character_, NA_character_, NA_character_))
        splt <- strsplit(xx, '\\ ')[[1]]

        is_institution <- any(sapply(institution_indicators, function(z) grepl(z, xx, ignore.case = TRUE)))
        if(length(splt) > 3 && ! is_institution) stop('non-NA names must have 1-3 space-separated components')

        if(is_institution) return(c(xx, '', ''))

        if(length(splt) == 1){
            splt <- c(splt, '', '')
        } else if(length(splt) == 2){
            splt <- c(splt[1], '', splt[2])
        } else if(length(splt) == 3 && nchar(splt[2]) > 1){
            splt[2] <- toupper(substr(splt[2], 1, 1))
        }

        splt
    })

    xsep <- do.call(rbind, xsep)

    return(xsep)
}

combine_ws_attrs <- function(where){

    #ms-standard watershed attributes
    ws_attrs <- list.files(glue('{where}/1_watershed_attribute_data/ws_attr_timeseries'),
                           full.names = TRUE,
                           pattern = '*.csv')

    map_dfr(ws_attrs, read_csv, show_col_types = FALSE) %>%
        write_csv(glue('{where}/1_watershed_attribute_data/ws_attr_timeseries.csv'))

    invisible(file.remove(ws_attrs))
    # file.remove(glue('{where}/1_watershed_attribute_data/ws_attr_timeseries'))

    #camels-compliant watershed attributes
    ws_attrs <- list.files(glue('{where}/3_CAMELS-compliant_watershed_attributes'),
                           full.names = TRUE)

    d <- read_csv(ws_attrs[1], show_col_types = FALSE)
    for(i in 2:length(ws_attrs)){
        d <- full_join(d,
                       read_csv(ws_attrs[i],
                                show_col_types = FALSE),
                       by = 'site_code')
    }

    d <- d %>%
        select(-starts_with(c('network', 'domain'))) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')

    write_feather(d, glue('{where}/3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.feather'))
    write_csv(d, glue('{where}/3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.csv'))

    invisible(file.remove(ws_attrs))
}

eml_misc <- function(where){

    ## rename some files to clarify what they are in the absence of dir structure

    # fs <- list.files(glue('{where}/1_watershed_attribute_data/ws_attr_timeseries'),
    #                  full.names = TRUE)
    # file.rename(fs, sub('ws_attr_timeseries/', 'ws_attr_timeseries/ws_attr_ts_', fs))
    #
    # fs <- list.files(glue('{where}/3_CAMELS-compliant_watershed_attributes'),
    #                  full.names = TRUE)
    # file.rename(fs, sub('watershed_attributes/', 'watershed_attributes/CAMELS-compliant_ws_attr_ts_', fs))

    # file.rename(glue('{where}/4_CAMELS-compliant_Daymet_forcings/CAMELS-compliant_Daymet_forcings.csv'),
    #             glue('{where}/4_CAMELS-compliant_Daymet_forcings/CAMELS_compliant_Daymet_forcings.csv'))

    ## link shapefiles to eml loading dock and zip them together

    dir.create('eml/data_links/shapefiles', showWarnings = FALSE)

    sfs <- list.files(glue('{where}/5_shapefiles'), full.names = TRUE)
    sfs_basenames <- basename(sfs)
    file.link(sfs, file.path('eml/data_links/shapefiles', sfs_basenames))

    zip(zipfile = 'eml/data_links/shapefiles.zip',
        files = 'eml/data_links/shapefiles',
        flags = '-r9Xq')

    #clean up camels-style data
    read_csv(file.path(where, '3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.csv'),
             show_col_types = FALSE) %>%
        relocate('site_code', .before = p_mean) %>%
        filter(! grepl('[0-9]{8}', site_code)) %>%
        arrange(site_code) %>%
        write_csv(file.path(where, '3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.csv'))
}

prepare_for_figshare_packageformat <- function(where, dataset_version){

    if(.Platform$OS.type == 'windows'){
        stop(paste('The "system" calls below probably will not work on windows.',
                   'investigate and update those calls if you need to update figshare from windows'))
    }

    require_shell_tool('rename')
    require_shell_tool('find')
    require_shell_tool('rmdir')

    ##prepare documentation files needed by the package (some of these funcnames are now misnomers)

    prepare_site_metadata_for_figshare(outfile = file.path(where, 'macrosheds_documentation_packageformat/site_metadata.csv'))
    prepare_variable_metadata_for_figshare(outfile = file.path(where, 'macrosheds_documentation_packageformat/variable_metadata.csv'),
                                           fs_format = 'old')
    prepare_variable_catalog_for_figshare(outfile = file.path(where, 'macrosheds_documentation_packageformat/variable_catalog.csv'))
    file.copy('src/templates/figshare_docfiles/packageformat_readme.txt',
              file.path(where, 'macrosheds_documentation_packageformat', 'README.txt'),
              overwrite = TRUE)
    googledrive::drive_download(file = googledrive::as_id(conf$data_use_agreements),
                                path = file.path(where, 'macrosheds_documentation_packageformat',
                                                 'data_use_agreements.docx'),
                                overwrite = TRUE)

    tld <- glue('macrosheds_figshare_v{vv}/macrosheds_files_by_domain',
                vv = dataset_version)

    ## copy over all files from the output dataset.

    file.copy(from = glue('macrosheds_dataset_v', dataset_version),
              to = where,
              recursive = TRUE)
    if(file.exists(tld)) unlink(tld, recursive = TRUE) #so we can overwrite
    file.rename(from = file.path(where, glue('macrosheds_dataset_v', dataset_version)),
                to = tld)

    ## write load estimates to figshare timeseries folder as feathers

    ntw_dmn_join <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        select(domain, network, site_code)

    loadf <- list.files('scratch/load_out', full.names = TRUE)
    loadsites <- str_extract(loadf, '([^/]+)?\\.csv', group = 1)
    for(s in loadsites){

        dmn <- filter(ntw_dmn_join, site_code == !!s) %>%
            pull(domain)
        ntw <- filter(ntw_dmn_join, site_code == !!s) %>%
            pull(network)

        loaddir <- glue('macrosheds_figshare_v2/macrosheds_files_by_domain/{ntw}/{dmn}/derived/stream_load_scaled_annual')
        if(s %in% loadsites){
            d <- read_csv(loadf[loadsites == s], col_types = 'ccnncl')
            if(nrow(d)){
                d <- filter(d, ! is.na(load)) %>%
                    mutate(ms_recommended = as.numeric(ms_recommended)) ## TODO move upstream! (?)
                dir.create(loaddir, showWarnings = FALSE)
                write_feather(
                    d,
                    file.path(loaddir, paste0(s, '.feather'))
                )
            }
        }
    }

    # clean up some stuff, zip up timeseries data (including load)

    # uncomment these lines to make temp versions of dataset before package is updated ****
    #append a distinguishing token to all network dirs
    # system(glue("rename 's/(.*)/$1_/' {tld}/*")) #****

    all_dirs <- list.dirs(tld)

    dmn_dirs <- grep(pattern = 'derived$',
                     x = all_dirs,
                     value = TRUE)

    # warning('temporarily removing NEON')
    # dmn_dirs <- grep('neon', dmn_dirs, invert = TRUE, value = TRUE)
    # unlink(file.path(tld, 'neon/'), recursive = TRUE)

    for(jd in dmn_dirs){

        message(paste('working on', jd))

        ## convert grab_sample column to numeric
        #TODO move upstream!

        conv_fs <- list.files(jd,
                              pattern = 'feather$',
                              recursive = TRUE,
                              full.names = TRUE) %>%
            str_subset('stream_load_scaled',
                       negate = TRUE)

        for(ff in conv_fs){
            read_feather(ff) %>%
                mutate(grab_sample = as.numeric(grab_sample)) %>%
                write_feather(ff)
        }

        ## incise the now-superfluous "derived" directory from the path
        to_folder <- sub(pattern = '/derived$',
                         replacement = '',
                         x = jd)

        system(glue('mv {jd}/* {to_folder}'))
        file.remove(jd)

        dmn <- str_match(to_folder, '/([^/]+)$')[, 2]

        parent_folder <- dirname(to_folder)

        #dip into network dir for convenience. this is not ideal
        setwd(parent_folder)

        # ## TEMP
        # warning('temporarily removing all flux data from figshare dataset')
        # flux_dirs_to_rm <- grep(pattern = 'flux',
        #                         x = list.files(dmn,
        #                                        full.names = TRUE),
        #                         value = TRUE)
        # invisible(lapply(flux_dirs_to_rm, unlink, recursive = TRUE))

        ## remove the prodcode extensions from dirnames
        rslt <- character()
        rslt <- system(paste0("rename 's/(.+)__ms[0-9]{3}/$1/' ", dmn, "/* 2>&1"),
                       intern = TRUE)
        if(! is_empty(rslt)){
            setwd('../../..')
            stop('precursor files still present')
        }

        ## add a readme to each domain dir
        file.copy(from = '../../../src/templates/figshare_docfiles/ts_docs_readme.txt',
                  to = file.path(dmn, 'documentation', 'README.txt'))

        zip(zipfile = glue(dmn, '.zip'), #and switch this off ****
            files = dmn,
            flags = '-r9Xq')

        setwd('../../..')

        # system(glue('mv {file.path(parent_folder, dmn)} {tld}')) #****

        unlink(to_folder, recursive = TRUE) #and switch this off ****
    }

    system(glue('find <<tld>> -maxdepth 1 -type d -name "*_" -exec rmdir {} \\;', .open = '<<', .close = '>>')) #****
}

figshare_create_article <- function(title,
                                    description,
                                    type = c("dataset", "figure",  "media", "poster", "paper", "fileset"),
                                    keywords,
                                    category_ids,
                                    authors,
                                    token,
                                    verbose = FALSE){

    if(is.character(keywords)) keywords <- as.list(keywords)
    if(is.numeric(category_ids)) category_ids <- as.list(category_ids)

    header <- c(Authorization = sprintf("token %s", token))
    type <- match.arg(type)
    base <- "https://api.figshare.com/v2"
    method <- "account/articles"
    request <- paste(base, method, sep = "/")

    meta <- jsonlite::toJSON(list(title = title,
                                  description = description,
                                  defined_type = type,
                                  keywords = keywords,
                                  categories_by_source_id = as.character(category_ids), #this changed ~2024. "categories" key no longer accepted by API
                                  authors = authors),
                             auto_unbox = TRUE)

    if(verbose){
        print(request)
        print(header)
        print(meta)
    }

    post <- expo_backoff(
        expr = {
            httr::POST(request,
                       config = httr::add_headers(header),
                       body = meta)
        },
        max_attempts = 5
    ) %>% invisible()

    if(post$status_code > 201){
        httr::stop_for_status(post)
    } else {

        p <- jsonlite::fromJSON(httr::content(x = post,
                                              as = 'text',
                                              encoding = 'UTF-8'))

        article_id <- as.numeric(regmatches(p$location, regexpr('[0-9]+$', p$location)))
        message(glue('Created article {t} ({id}).',
                     t = title,
                     id = article_id))

        return(article_id)
    }
}

figshare_delete_article <- function(article_id,
                                    token){

    base <- "https://api.figshare.com/v2"
    method <- paste("account/articles", article_id, sep = "/")
    # if (!is.null(file_id)) {
    #     method <- paste(method, "files", file_id, sep = "/")
    # }
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))


    r <- expo_backoff(
        expr =  httr::DELETE(request, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 201){
        stop(paste('failed to delete article', article_id))
    }
}

figshare_delete_article_file <- function(article_id,
                                         file_id,
                                         token){

    #for deleting files, which are found within articles

    base <- "https://api.figshare.com/v2"
    method <- paste("account/articles", article_id, 'files', file_id, sep = "/")
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr =  httr::DELETE(request, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 204){
        stop(paste('failed to delete file', file_id, 'within article', article_id))
    }
}

figshare_publish_article <- function(article_id,
                                     token){

    base <- "https://api.figshare.com/v2"
    method <- paste("account/articles", article_id, 'publish', sep = "/")
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr = httr::POST(request, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 201){
        stop(paste('failed to publish article', article_id))
    }
}

figshare_publish_collection <- function(collection_id,
                                        token){

    base <- "https://api.figshare.com/v2"
    method <- paste("account/collections", collection_id, 'publish', sep = "/")
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))


    r <- expo_backoff(
        expr = httr::POST(request, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 201){
        stop(paste('failed to publish collection', collection_id))
    }
}

figshare_add_new_articles_to_collection <- function(collection_id,
                                                    article_ids,
                                                    token){

    if(is.numeric(article_ids)) article_ids <- as.list(article_ids)

    base <- "https://api.figshare.com/v2"
    method <- paste("account/collections", collection_id, 'articles', sep = "/")
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))
    meta <- jsonlite::toJSON(list(articles = article_ids),
                             auto_unbox = TRUE)

    r <- expo_backoff(
        expr = httr::POST(request, body = meta, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 201){
        stop(paste('failed to add articles',
                   paste(article_ids, collapse = ', '),
                   'to collection',
                   collection_id))
    }
}

figshare_replace_all_articles_in_collection <- function(collection_id,
                                                        article_ids,
                                                        token){

    if(is.numeric(article_ids)) article_ids <- as.list(article_ids)

    base <- "https://api.figshare.com/v2"
    method <- paste("account/collections", collection_id, 'articles', sep = "/")
    request <- paste(base, method, sep = "/")
    header <- c(Authorization = sprintf("token %s", token))
    meta <- jsonlite::toJSON(list(articles = article_ids),
                             auto_unbox = TRUE)

    r <- expo_backoff(
        expr = httr::PUT(request, body = meta, config = httr::add_headers(header)),
        max_attempts = 5
    ) %>% invisible()

    if(r$status_code > 201){
        stop(paste('failed to replace articles',
                   paste(article_ids, collapse = ', '),
                   'in collection',
                   collection_id))
    }
}

figshare_list_collections <- function(token){

    header <- c(Authorization = sprintf("token %s", token))


    r <- expo_backoff(
        expr = {
            httr::GET('https://api.figshare.com/v2/account/collections?page_size=1000',
                   httr::add_headers(header))
        },
        max_attempts = 5
    ) %>% invisible()

    return(content(r))
}

figshare_list_articles <- function(token){

    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr = {
            httr::GET('https://api.figshare.com/v2/account/articles?page_size=1000',
                      httr::add_headers(header))
        },
        max_attempts = 5
    ) %>% invisible()

    return(content(r))
}

figshare_list_article_files <- function(article_id,
                                        token){

    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr = {
            httr::GET(paste0('https://api.figshare.com/v2/account/articles/',
                             article_id, '/files?page_size=1000'),
                      httr::add_headers(header))
        },
        max_attempts = 5
    ) %>% invisible()

    return(content(r))
}

figshare_list_article_versions <- function(article_id,
                                           token){

    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr = {
            httr::GET(paste0('https://api.figshare.com/v2/articles/',
                             article_id, '/versions?page_size=1000'),
                      httr::add_headers(header))
        },
        max_attempts = 5
    ) %>% invisible()

    return(content(r))
}

figshare_list_version_details <- function(article_id,
                                          vsn_number,
                                          token){

    header <- c(Authorization = sprintf("token %s", token))

    r <- expo_backoff(
        expr = {
            httr::GET(paste0('https://api.figshare.com/v2/articles/',
                             article_id, '/versions/', vsn_number, '?page_size=1000'),
                      httr::add_headers(header))
        },
        max_attempts = 5
    ) %>% invisible()

    return(content(r))
}

figshare_upload_article <- function(article_id,
                                    file,
                                    token,
                                    ...){

    require(tools)

    base <- 'https://api.figshare.com/v2'

    #initialize upload (post MD5, size, name)
    request <- paste0(base, sprintf('/account/articles/%s/files',
                                    article_id))

    body <- list(md5 = unname(tools::md5sum(file)),
                 name = basename(file),
                 size = file.info(file)$size)
    auth_header <- c(Authorization = sprintf("token %s", token))

    out <- httr::POST(request,
                      config = httr::add_headers(auth_header),
                      body = body,
                      encode = 'json',
                      httr::accept_json(),
                      ...)

    #upload file by parts
    upload_deets <-  httr::GET(httr::content(out)$location,
                               config = httr::add_headers(auth_header)) %>%
        httr::content()

    part_deets <- httr::content(httr::GET(upload_deets$upload_url))

    for(part in part_deets$parts){

        url <- glue('{ul}/{p}',
                    ul = upload_deets$upload_url,
                    p = part$partNo)

        con <- base::file(file, 'rb')
        seek(con, part$startOffset)
        datachunk <- readBin(con, 'raw', n = part$endOffset - part$startOffset + 1)
        close(con)

        o <- httr::PUT(url,
                       config = httr::add_headers(auth_header,
                                                  `Content-Type` = 'multipart/form-data'),
                       body = datachunk)

        if(o$status_code != 200) stop(pate('error uploading chunk', part$partNo))
    }

    #complete upload
    request <- jsonlite::fromJSON(httr::content(out,
                                                "text",
                                                encoding = "UTF-8"))$location

    final_out <- httr::POST(request,
                            config = httr::add_headers(auth_header))

    if(final_out$status_code > 202){
        stop(paste0('error uploading ', basename(file), ' (', article_id, ').'))
    } else {
        message(paste0('Uploaded ', basename(file), ' (', article_id, ').'))
    }
}

upload_dataset_to_figshare <- function(dataset_version){

    ### ONE-TIME PREP

    ## create a collection on Figshare (already done; its ID is below)

    ## get a Figshare private access token (PAT) and add it to R env
    # usethis::edit_r_environ()

    ## get category IDs from category names
    # qqq <- content(rfigshare::fs_category_list(debug = TRUE))[[1]]
    # all_categories <- sapply(qqq, function(x) { xx = x$name; names(xx) = x$id ; return(xx)})
    # categories <- c('Earth Sciences not elsewhere classified',
    #                 'Environmental Monitoring',
    #                 'Geochemistry not elsewhere classified',
    #                 'Hydrology',
    #                 'Landscape Ecology',
    #                 'Freshwater Ecology')
    # cat_ids <- as.numeric(names(all_categories[all_categories %in% categories]))


    ### EVERY-TIME PREP

    collection_id <- 5621740 #see comments above
    token <- Sys.getenv('RFIGSHARE_PAT') #see comments above to set
    auth_header <- c(Authorization = sprintf('token %s', token))
    cat_ids <- c(80, 214, 251, 255, 261, 673) #determined above
    tld <- paste0('macrosheds_figshare_v', dataset_version)

    # Figshare versioning procedures: https://help.figshare.com/article/can-i-edit-or-delete-my-research-after-it-has-been-made-public
    message('uploading official dataset to fighare collection')

    usr_rsp <- get_response_1char('Proceeding will update existing published articles on Figshare. Continue? (y/n) >',
                                  c('y', 'n'))

    if(usr_rsp == 'n'){
        print('upload aborted')
        return()
    }

    existing_articles <- figshare_list_articles(token)
    existing_article_deets <- tibble(
        title = sapply(existing_articles, function(x) x$title),
        id = sapply(existing_articles, function(x) x$id),
    )

    ### ASSEMBLE DATASET COMPONENTS

    components <- c('macrosheds_documentation', 'macrosheds_timeseries_data',
                    'macrosheds_watershed_attribute_data')

    fs_ids <- c()
    for(comp in components){

        compzip <- paste0(comp, '.zip')
        if(file.exists(compzip)) unlink(compzip)

        setwd(tld) #can't seem to find a way around setwd. zip inserts junk files otherwise. -j can't be used here.
        zip(zipfile = compzip,
            files = comp,
            flags = '-r9X')
        setwd('..')

        keywords <- list('watershed', 'basin', 'catchment', 'ecosystem', 'long-term data',
                         'compilation', 'hydrology', 'climate', 'terrain', 'landcover',
                         'biogeochemistry', 'stream', 'river')

        ### FIGSHARE INTERACTIONS

        existing_article <- comp %in% existing_article_deets$title

        #if existing article, get figshare ID; otherwise create new article
        if(! existing_article){
            fs_id <- figshare_create_article(
                title = comp,
                description = case_when(comp == 'macrosheds_documentation' ~ 'Documentation, metadata, and legal information about the MacroSheds dataset',
                                        comp == 'macrosheds_timeseries_data' ~ 'All MacroSheds discharge, precip, and chemistry time series',
                                        comp == 'macrosheds_watershed_attribute_data' ~ 'All MacroSheds watershed descriptor data'),
                keywords = keywords,
                category_ids = cat_ids,
                authors = conf$figshare_author_list,
                type = 'dataset',
                token = token)
        } else {
            fs_id <- existing_article_deets$id[existing_article_deets$title == comp]
        }

        fs_ids <- c(fs_ids, fs_id)

        #if existing article, delete old version
        if(existing_article){

            fls <- figshare_list_article_files(fs_id,
                                               token = token)

            if(length(fls) > 1) stop(paste('article', fs_id, 'contains more than one file'))

            figshare_delete_article_file(fs_id,
                                         file_id = fls[[1]]$id,
                                         token = token)
        }

        figshare_upload_article(fs_id,
                                file = file.path(tld, compzip),
                                token = token)

        if(! existing_article){
            figshare_add_new_articles_to_collection(collection_id = collection_id,
                                                    article_ids = fs_id,
                                                    token = token)
        }
    }

    figshare_replace_all_articles_in_collection(collection_id = collection_id,
                                                article_ids = fs_ids,
                                                token = token)

    for(comp in components){
        figshare_publish_article(article_id = fs_id,
                                 token = token)
    }

    ### ONCE EVERYTHING IS PUBLIC, PUBLISH THE WHOLE COLLECTION

    figshare_publish_collection(collection_id = collection_id,
                                token = token)
}

upload_dataset_to_figshare_packageversion <- function(dataset_version){

    ### ONE-TIME PREP

    ## get a Figshare private access token (PAT) and add it to R env
    # usethis::edit_r_environ()

    ## get category IDs from category names (these have changed....)
    # qqq <- content(rfigshare::fs_category_list(debug = TRUE))[[1]]
    # all_categories <- sapply(qqq, function(x) { xx = x$name; names(xx) = x$id ; return(xx)})
    # categories <- c('Earth Sciences not elsewhere classified',
    #                 'Environmental Monitoring',
    #                 'Geochemistry not elsewhere classified',
    #                 'Hydrology',
    #                 'Landscape Ecology',
    #                 'Freshwater Ecology')
    # cat_ids <- as.numeric(names(all_categories[all_categories %in% categories]))

    if(! dir.exists('../r_package/R')){
        stop('cannot find r_package/R (needed for updating figshare file IDs). maybe your package path is different?')
    }

    ### EVERY-TIME PREP

    token <- Sys.getenv('RFIGSHARE_PAT') #see comments above to set
    auth_header <- c(Authorization = sprintf('token %s', token))
    # cat_ids <- c(80, 214, 251, 255, 261, 673) #determined above (these have changed)
    cat_ids <- c(410402, 370799, 310304, 370399, 379999, 410206)
    tld <- glue('macrosheds_figshare_v{dataset_version}/macrosheds_files_by_domain')

    # Figshare versioning procedures: https://help.figshare.com/article/can-i-edit-or-delete-my-research-after-it-has-been-made-public
    message('uploading dataset to fighare in package format')

    usr_rsp <- get_response_1char('Proceeding will update existing published articles on Figshare. Continue? (y/n) >',
                                  c('y', 'n'))

    if(usr_rsp == 'n'){
        print('upload aborted')
        return()
    }

    existing_articles <- figshare_list_articles(token)
    existing_dmn_deets <- tibble(
        title = sapply(existing_articles, function(x) x$title),
        id = sapply(existing_articles, function(x) x$id),
        domain = str_match(title, '^Network: .+?, Domain: (.+)$')[, 2]
    ) %>%
        filter(! is.na(domain)) %>%
        select(-title)
    existing_extras_deets <- tibble(
        title = sapply(existing_articles, function(x) x$title),
        id = sapply(existing_articles, function(x) x$id),
    )

    #format authors
    fshare_auths <- conf$figshare_author_list
    if(ms_instance$which_machine == 'BM1'){ #if mike gave you access to the figshare account for MS, comment this conditional
        fshare_auths[[1]] <- NULL #mike, included by default if uploading to mike's figshare account
    }
    fshare_auths[[which(sapply(fshare_auths, \(x) x$first_name == 'Amanda'))]]$orcid_id <- NULL #could update Amanda's orcid instead
    fshare_auths[[which(sapply(fshare_auths, \(x) x$first_name == 'Matthew'))]]$orcid_id <- NULL #could update Matt's orcid instead

    ### CREATE, UPLOAD, PUBLISH TIMESERIES

    ntws <- list.files(tld)

    file_ids_for_r_package_ <- tibble()
    for(i in seq_along(ntws)){

        ntw <- ntws[i]
        dmns <- list.files(file.path(tld, ntw))

        for(j in seq_along(dmns)){

            dmn <- sub('.zip', '', dmns[j])

            ## if new dmn, create figshare "article", which in this case is a dataset.
            ## else get the fs_id of the existing article

            print(paste('uploading', ntw, '-', dmn))

            if(! dmn %in% existing_dmn_deets$domain){

                fs_id <- figshare_create_article(
                    title = glue('Network: ', ntw, ', Domain: ', dmn),
                    description = 'MacroSheds data on Figshare are only intended to be accessed via the "macrosheds" R package. The official dataset is at https://portal.edirepository.org/nis/mapbrowse?scope=edi&identifier=1262.',
                    # description = glue('MacroSheds timeseries data, shapefiles, ',
                    #                    'and metadata for domain: {dmn}, within network: {ntw}'),
                    keywords = 'placeholder', #we don't actually want these articles to be searchable
                    category_ids = cat_ids, #required unfortunately
                    type = 'dataset',
                    authors = fshare_auths,
                    token = token)
            } else {
                fs_id <- existing_dmn_deets$id[existing_dmn_deets$domain == dmn]
            }

            #if existing article, delete old version
            if(dmn %in% existing_dmn_deets$domain){

                fls <- figshare_list_article_files(fs_id,
                                                   token = token)

                if(length(fls) > 1) stop(paste('article', fs_id, 'contains more than one file'))
                for(k in seq_along(fls)){
                    figshare_delete_article_file(fs_id,
                                                 file_id = fls[[k]]$id,
                                                 token = token)
                }
            }

            #upload new/updated domain zip to that article
            figshare_upload_article(fs_id,
                                    file = glue('{tld}/{ntw}/{dmn}.zip'),
                                    token = token)

            figshare_publish_article(article_id = fs_id,
                                     token = token)

            #get new file ID
            fls <- figshare_list_article_files(fs_id,
                                               token = token)
            file_ids_for_r_package_ <- bind_rows(
                file_ids_for_r_package_,
                tibble(network = ntw, domain = dmn, fig_code = fls[[1]]$id))
        }
    }

    #update figshare codes for R package
    load('../r_package/data/sysdata.RData')
    file_ids_for_r_package <- full_join(file_ids_for_r_package,
                                        file_ids_for_r_package_,
                                        by = c('network', 'domain')) %>%
        rename(!!paste0('fig_code_v', dataset_version) := fig_code)

    save(file_ids_for_r_package,
         file = '../r_package/data/sysdata.RData')

    ### CREATE, UPLOAD, PUBLISH SITES, VARS, LEGAL STUFF, SPATIAL DATA, AND DOCUMENTATION

    # other_uploadsA <- list.files('../portal/data/general/spatial_downloadables',
    other_uploadsA <- list.files(paste0('macrosheds_figshare_v', dataset_version, '/1_watershed_attribute_data/ws_attr_timeseries'),
                                 full.names = TRUE,
                                 pattern = '\\.feather$')
    titlesA <- paste0('spatial_timeseries_', str_match(other_uploadsA, '/([^/]+)\\.feather(?:\\.zip)?$')[, 2])
    other_uploadsA <- c(other_uploadsA, paste0('macrosheds_figshare_v', dataset_version, '/1_watershed_attribute_data/ws_attr_summaries.feather'))
    titlesA <- c(titlesA, 'watershed_summaries')
    names(other_uploadsA) <- rep('watershed_attributes', length(other_uploadsA))

    other_uploadsB <- c(
        documentation = '../portal/static/documentation/timeseries/columns.txt',
        documentation = '../portal/static/documentation/watershed_summary/columns.csv',
        documentation = '../portal/static/documentation/watershed_trait_timeseries/columns.txt')
    titlesB <- paste(str_match(other_uploadsB,
                               '/([^/]+)/columns\\....$')[, 2],
                     'column descriptions')

    other_uploadsC <- list.files('../portal/static/documentation',
                                 full.names = TRUE,
                                 pattern = '*.csv')
    names(other_uploadsC) <- rep('documentation', length(other_uploadsC))
    titlesC <- str_match(other_uploadsC, '/([^/]+)\\.csv$')[, 2]

    other_uploadsD <- c(documentation = paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/README.txt'),
                        # policy = 'src/templates/figshare_docfiles/ws_attr_LEGAL.csv',
                        # policy = 'src/templates/figshare_docfiles/timeseries_LEGAL.csv',
                        policy = paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/data_use_agreements.docx'))
    titlesD <- c('README', 'data_use_POLICY')

    other_uploadsE <- c(metadata = paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/site_metadata.csv'),
                        metadata = paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/variable_metadata.csv'),
                        metadata = paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/variable_catalog.csv'))
    titlesE <- c('site_metadata', 'variable_metadata', 'variable_catalog')

    other_uploads <- c(other_uploadsA, other_uploadsB, other_uploadsC, other_uploadsD, other_uploadsE)
    titles <- c(titlesA, titlesB, titlesC, titlesD, titlesE)

    print(paste('uploading extras'))

    #removing items that should now be accessed via EDI portal
    rms <- (names(other_uploads) == 'metadata' | grepl('(?:columns|codes)\\.(?:txt|csv)$', other_uploads))
    other_uploads <- other_uploads[! rms]
    titles <- titles[! rms]

    #variable catalog can be included with package data
    ms_var_catalog <- read_csv(paste0('macrosheds_figshare_v', dataset_version, '/macrosheds_documentation_packageformat/variable_catalog.csv'),
                               show_col_types = FALSE)
    save(ms_var_catalog, file = '../r_package/data/ms_var_catalog.RData')

    file_ids_for_r_package2_ <- tibble()
    for(i in rev(seq_along(other_uploads))){

        uf <- other_uploads[i]
        ut <- titles[i]

        if(! ut %in% existing_extras_deets$title){
            fs_id <- figshare_create_article(
                title = ut,
                description = 'MacroSheds data on Figshare are only intended to be accessed via the "macrosheds" R package. The official dataset is at https://portal.edirepository.org/nis/mapbrowse?scope=edi&identifier=1262.',
                # keywords = list(names(uf)),
                keywords = 'placeholder',
                category_ids = cat_ids,
                authors = fshare_auths,
                type = 'dataset',
                token = token)
        } else {
            fs_id <- existing_extras_deets$id[existing_extras_deets$title == ut]
        }

        #if existing article, delete old version
        if(ut %in% existing_extras_deets$title){

            for(fsid_ in fs_id){

                fls <- figshare_list_article_files(fsid_, token = token)

                for(j in seq_along(fls)){
                    figshare_delete_article_file(fsid_,
                                                 file_id = fls[[j]]$id,
                                                 token = token)
                }
            }
        }

        fs_id <- fs_id[1]

        figshare_upload_article(fs_id,
                                file = unname(uf),
                                token = token)

        figshare_publish_article(article_id = fs_id,
                                 token = token)

        #update file IDs for R package functions that reference figshare
        fls <- figshare_list_article_files(fs_id,
                                           token = token)

        file_ids_for_r_package2_ <- bind_rows(
            file_ids_for_r_package2_,
            tibble(ut, fig_code = fls[[1]]$id))
    }

    #### CREATE, UPLOAD, PUBLISH WS ATTRS

    more_fs_uploads <- c(camels_ws_attrs = glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/CAMELS_compliant_ws_attr.feather'),
                         camels_daymet = glue('macrosheds_figshare_v{vsn}/4_CAMELS-compliant_Daymet_forcings/CAMELS_compliant_Daymet_forcings.feather'))
    more_fs_titles <- c('watershed_summaries_CAMELS', 'Daymet_forcings_CAMELS')

    file_ids_for_r_package3_ <- tibble()
    for(i in seq_along(more_fs_uploads)){

        uf <- more_fs_uploads[i]
        ut <- more_fs_titles[i]

        if(! ut %in% existing_extras_deets$title){
            fs_id <- figshare_create_article(
                title = ut,
                description = 'MacroSheds data on Figshare are only intended to be accessed via the "macrosheds" R package. The official dataset is at https://portal.edirepository.org/nis/mapbrowse?scope=edi&identifier=1262.',
                # keywords = list(names(uf)),
                keywords = 'placeholder',
                category_ids = cat_ids,
                authors = fshare_auths,
                type = 'dataset',
                token = token)
        } else {
            fs_id <- existing_extras_deets$id[existing_extras_deets$title == ut]
        }

        #if existing article, delete old version
        if(ut %in% existing_extras_deets$title){

            for(fsid_ in fs_id){

                fls <- figshare_list_article_files(fsid_,
                                                   token = token)

                for(j in seq_along(fls)){
                    figshare_delete_article_file(fsid_,
                                                 file_id = fls[[j]]$id,
                                                 token = token)
                }
            }
        }

        fs_id <- fs_id[1]

        figshare_upload_article(fs_id,
                                file = unname(uf),
                                token = token)

        figshare_publish_article(article_id = fs_id,
                                 token = token)

        #update file IDs for R package functions that reference figshare
        fls <- figshare_list_article_files(fs_id,
                                           token = token)

        file_ids_for_r_package3_ <- bind_rows(
            file_ids_for_r_package3_,
            tibble(ut, fig_code = fls[[1]]$id))
    }

    #update figshare codes for R package
    load('../r_package/data/sysdata2.RData')

    newvcol <- paste0('fig_code_v', dataset_version)

    file_ids_for_r_package2 <- file_ids_for_r_package2_ %>%
        filter(! ut %in% !!file_ids_for_r_package3_$ut) %>%
        bind_rows(file_ids_for_r_package3_) %>%
        full_join(file_ids_for_r_package2,
              by = 'ut') %>%
        rename(!!newvcol := fig_code) %>%
        relocate(!!newvcol, .after = last_col())

    save(file_ids_for_r_package2, file = '../r_package/data/sysdata2.RData')

    file_ids_for_r_package2 %>%
        filter(ut == 'watershed_summaries') %>%
        pull(!!newvcol) %>%
        readr::write_lines(file = '../r_package/data/figshare_id_check.txt')
}

detrmin_mean_record_length <- function(df){

    test <- df %>%
        filter(!is.na(val)) %>%
        filter(Year != year(Sys.Date())) %>%
        group_by(Year, Month, Day) %>%
        summarise(max = max(val, na.rm = TRUE)) %>%
        ungroup() %>%
        filter(!(Month == 2 & Day == 29)) %>%
        group_by(Month, Day) %>%
        summarise(n = n())

    if(mean(test$n, na.rm = TRUE) < 3){
        return(nrow(test))
    }

    if(nrow(test) < 365) {

        quart_val <- quantile(test$n, .2)

        q_check <- test %>%
            filter(n >= quart_val)

        days_in_rec <- nrow(q_check)
    } else{
        days_in_rec <- 365
    }
    return(days_in_rec)
}

clean_portal_dataset <- function(){

    #not needed yet, but soon we'll go over the 6000 file limit and need to
    #trim down. we can then host static files somewhere else for download,
    #and the portal can just hold files needed for viz. still might become a
    #problem.

    #at that time we can remove ws_boundary files and unscaled flux (will need
    #to update biplot to receive precip_flux_scaled)

    find_dirs_within_portaldata <- function(keyword){

        files <- dir(path = '../portal/data',
                     pattern = paste0(keyword, '*'),
                     recursive = TRUE,
                     full.names = TRUE,
                     include.dirs = TRUE)

        return(files)
    }

    dirs_to_delete <- c()

    #watershed boundaries are
    for(k in c('ws_boundary')){

        dirs_to_delete <- c(dirs_to_delete,
                            find_dirs_within_portaldata(keyword = k))
    }

    #drop em all from the final dataset
    for(dr in dirs_to_delete){
        unlink(x = dr,
               recursive = TRUE)
    }
}

generate_output_dataset <- function(vsn){

    require_shell_tool('rsync')
    require_shell_tool('find')

    # #find doesn't accept OR in globs. there is a way to do this though
    # system(paste0('find data -path *derived/{*.feather,*.shx,*.shp,',
    #           '*.prj,*.dbf} -printf %P\\\\0\\\\n | ',
    #           'rsync -av --files-from=- data macrosheds_dataset_v', vsn))

    #copy feathers to output dir
    system(paste0('find data -path "*derived/*.feather" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))

    #copy shapefiles to output dir
    system(paste0('find data -path "*derived/*.shp" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))
    system(paste0('find data -path "*derived/*.shx" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))
    system(paste0('find data -path "*derived/*.prj" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))
    system(paste0('find data -path "*derived/*.dbf" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))

    #copy documentation to output dir
    system(paste0('find data -path "*derived/documentation*.txt" -printf %P\\\\0\\\\n | ',
              'rsync -av --files-from=- data macrosheds_dataset_v', vsn))

    find_dirs_within_outputdata <- function(keyword, vsn){

        files <- dir(path = paste0('macrosheds_dataset_v', vsn),
                     pattern = paste0(keyword, '*'),
                     recursive = TRUE,
                     full.names = TRUE,
                     include.dirs = TRUE)

        return(files)
    }

    dirs_to_delete <- c()

    #collect compprod dirs (intermediate products) that shouldn't be in the
    #final dataset
    for(k in c('cdnr_discharge__', 'usgs_discharge__')){

        dirs_to_delete <- c(dirs_to_delete,
          find_dirs_within_outputdata(keyword = k, vsn = vsn))
    }

    #remove intermediate products that shouldn't be in the final dataset
    for(k in c('precipitation', 'stream_chemistry', 'discharge', 'precip_chemistry',
               'precip_gauge_locations', 'stream_gauge_locations')){

        kfpaths <- find_dirs_within_outputdata(keyword = paste0(k, '__'),
                                               vsn = vsn)

        kpaths <- str_match(string = kfpaths,
                            pattern = paste0('(.*)?/',
                                             k))[, 2] %>%
                                             # '__ms[0-9]{3}$'))[, 2] %>%
            sort()

        kfac <- factor(kpaths)
        dirs_with_k_compprods <- as.character(kfac[duplicated(kfac)])

        for(dr in dirs_with_k_compprods){

            k_dirs <- list.files(path = dr,
                                 pattern = paste0('^', k, '__'))

            if(length(k_dirs) != 2){
                stop('there should only be two dirs in consideration here')
            }

            prodname_numeric <- str_match(string = k_dirs,
                                          pattern = paste0(k, '__ms([0-9]{3})'))[, 2] %>%
               as.numeric()

            if(any(is.na(prodname_numeric))){
                dir_to_delete_ind <- which(is.na(prodname_numeric))
            } else {
                dir_to_delete_ind <- which.min(prodname_numeric)
            }

            dirs_to_delete <- c(dirs_to_delete,
                                file.path(dr, k_dirs[dir_to_delete_ind]))
        }
    }

    #drop em all from the final dataset
    for(dr in dirs_to_delete){
        unlink(x = dr, recursive = TRUE)
    }

    #add notes
    warning("Don't forget to add notes! (and eventually generate changelog automatically)")
}

thin_portal_data <- function(network_domain, thin_interval){

    #thin_interval: passed to the "unit" parameter of lubridate::floor_date

    domains <- network_domain$domain

    n_domains <- length(domains)
    for(i in 1:n_domains){

        dmn <- domains[i]

        log_with_indent(msg = glue('{d}: ({ii}/{n})',
                                   d = dmn,
                                   ii = i,
                                   n = n_domains),
                        logger = logger_module,
                        indent = 2)

        prod_dirs <- try(
            {
                list.files(path = glue('../portal/data/{d}/',
                                       d = dmn),
                           full.names = FALSE,
                           recursive = FALSE)
            },
            silent = TRUE
        )

        if(length(prod_dirs)){

            #filter products that never need to be thinned. keep the ones that might
            rgx <- paste0('(^precipitation|^precip_chemistry|^discharge',
                          '|^precip_flux|^stream_chemistry|^stream_flux)')
            prod_dirs <- grep(pattern = rgx,
                              x = prod_dirs,
                              value = TRUE)
        }

        for(prd in prod_dirs){

            site_files <- list.files(path = glue('../portal/data/{d}/{p}',
                                                 d = dmn,
                                                 p = prd),
                                     full.names = TRUE,
                                     recursive = FALSE)

            if(prd == 'precipitation'){
                agg_call <- quote(sum(val, na.rm = TRUE))
            } else {
                agg_call <- quote(mean(val, na.rm = TRUE))
            }

            #thin files if necessary
            for(stf in site_files){

                dtcol <- read_feather(stf) %>%
                    select(datetime, var) %>%
                    arrange(var, datetime) %>%
                    select(datetime)
                interval_min <- Mode(diff(as.numeric(dtcol$datetime)) / 60)
                needs_thin <- ! is.na(interval_min) && interval_min <= 24 * 60

                if(needs_thin){
                    d <- read_feather(stf) %>%
                        mutate(
                            datetime = lubridate::floor_date(
                                x = datetime,
                                unit = thin_interval),
                            val = errors::set_errors(val, val_err)) %>%
                        select(-val_err)

                    if(length(unique(d$site_code)) > 1){
                        stop(paste('Multiple site_codes in', stf))
                    }

                    d %>%
                        group_by(datetime, var) %>%
                        summarize(
                            site_code = first(site_code),
                            val = eval(agg_call),
                            ms_status = numeric_any(ms_status),
                            ms_interp = numeric_any(ms_interp)) %>%
                        ungroup() %>%
                        mutate(val_err = errors(val),
                               val_err = ifelse(is.na(val_err), 0, val_err),
                               val = errors::drop_errors(val)) %>%
                        select(datetime, site_code, var, val, ms_status, ms_interp,
                               val_err) %>%
                        write_feather(stf)
                }
            }
        }
    }
}

list_domains_with_discharge <- function(site_data){

    #this identifies which sites have Q and which don't, so that the latter
    #   can be filtered from the sitelist in portal/global.R. that way,
    #   sites without discharge won't be selectable on the timeseries tab.

    Q_or_noQ <- site_data %>%
        select(network, domain, site_code) %>%
        distinct() %>%
        arrange(network, domain, site_code) %>%
        mutate(has_Q = NA)

    for(i in 1:nrow(Q_or_noQ)){

        ntw <- Q_or_noQ$network[i]
        dmn <- Q_or_noQ$domain[i]
        sit <- Q_or_noQ$site_code[i]

        clg <- sm(try(read_csv(glue('../portal/data/general/catalog_files/indiv_sites/',
                                    '{n}_{d}_{s}.csv',
                                    n = ntw,
                                    d = dmn,
                                    s = sit)),
                      silent = TRUE))

        if(! inherits(clg, 'try-error') && 'discharge' %in% clg$VariableCode){
            Q_or_noQ$has_Q[i] <- TRUE
        } else {
            Q_or_noQ$has_Q[i] <- FALSE
        }

    }

    if(any(is.na(Q_or_noQ$has_Q))){
        stop('NA detected in has_Q column. fix list_domains_with_discharge')
    }

    Q_or_noQ %>%
        filter(has_Q) %>%
        select(-has_Q) %>%
        write_csv(file = '../portal/data/general/sites_with_discharge.csv')
}

scale_flux_by_area <- function(network_domain, site_data){

    #this reads all flux data in data_acquisition/data and in portal/data,
    #   and scales it by watershed area. Originally this was only done for portal
    #   data, and originally each source file (*_flux_inst.feather) was retained
    #   after it was used to generate a *_flux_inst_scaled.feather. Now, the source
    #   file is removed after the scaled file is created. Thus, all our
    #   flux data is converted to kg/ha/d, and every flux file and
    #   directory gets a name change, after this function runs.

    #It would of course be more efficient to do this scaling within flux derive
    #   kernels, but this solution works fine and doesn't require major
    #   modification or rebuilding of the dataset.

    #see also undo_scale_flux_by_area (a much simpler function)

    #TODO: scale flux within derive kernels eventually. it'll make for clearer
    #   documentation

    stop('something is wrong with this function, or upstream. trace usgs/usgs/stream_flux_inst and see why it doesnt get linked. also see...')
    #loch vale. here is a command that will help: find . -type f -path '*/derived/*precip_flux_inst*/*.feather' ! -path '*documentation*' -links 1 #vs links 2
    #forsooth, there's actually something wrong with this function AND upstream. for one, hardlinks don't seem to be created for these domains (nvm, i think this was an anti-fluke)
    #for two, this function appears to have been designed to be hardlink-agnostic in that it operates separately on data_processing/data and portal/data

    require_shell_tool('find')
    missing_links <- system("find ../portal/data -name '*.feather' -links 1",
                            intern = TRUE)
    if(length(missing_links)){
        stop('might need to manually hardlink some files from data_processing/data to portal/data. def need to get to the bottom of this.')
        #obvs the scaled files created by this func won't be hardlinked anywhere. should they be?
    }

    ws_areas <- site_data %>%
        filter(in_workflow == 1,
               site_type == 'stream_gauge') %>%
        select(domain, site_code, ws_area_ha) %>%
        plyr::dlply(.variables = 'domain',
                    .fun = function(x) select(x, -domain))

    no_scale_dmns <- sapply(ws_areas, function(x) any(is.na(x$ws_area_ha))) %>%
        purrr::keep(isTRUE) %>%
        names()

    domains <- names(ws_areas)

    #the original engine of this function, which still only converts portal data
    engine_for_portal <- function(flux_var, domains, ws_areas){
        for(dmn in domains){

            if(dmn %in% no_scale_dmns){
                warning('NAs in ws_area_ha for ', dmn, '. Not scaling (skipping) this domain.')
                next
            }

            files <- try(
                {
                    list.files(path = glue('../portal/data/{d}/{v}',
                                           d = dmn,
                                           v = flux_var),
                               full.names = FALSE,
                               recursive = FALSE)
                },
                silent = TRUE
            )

            if('try-error' %in% class(files) || length(files) == 0) next

            dir.create(path = glue('../portal/data/{d}/{v}_scaled',
                                   d = dmn,
                                   v = flux_var),
                       recursive = TRUE,
                       showWarnings = FALSE)

            for(fil in files){

                d <- read_feather(glue('../portal/data/{d}/{v}/{f}',
                                       d = dmn,
                                       v = flux_var,
                                       f = fil))

                d <- d %>%
                    mutate(val = errors::set_errors(val, val_err)) %>%
                    select(-val_err) %>%
                    arrange(site_code, var, datetime) %>%
                    left_join(ws_areas[[dmn]],
                              by = 'site_code')

                if(any(is.na(d$ws_area_ha))){
                    warning('NAs in ws_area_ha for ', dmn, '. Not scaling this domain.')
                    break
                } else {
                    d <- mutate(d, val = sw(val / ws_area_ha))
                }

                d$ws_area_ha <- NULL
                d$val_err <- errors(d$val)
                d$val <- errors::drop_errors(d$val)

                write_feather(x = d,
                              path = glue('../portal/data/{dmn}/{flux_var}_scaled/{fil}'))
            }
        }
    }

    engine_for_portal(flux_var = 'stream_flux_inst',
                      domains = domains,
                      ws_areas = ws_areas)

    engine_for_portal(flux_var = 'CUSTOMstream_flux_inst',
                      domains = domains,
                      ws_areas = ws_areas)

    engine_for_portal(flux_var = 'precip_flux_inst',
                      domains = domains,
                      ws_areas = ws_areas)

    engine_for_portal(flux_var = 'CUSTOMprecip_flux_inst',
                      domains = domains,
                      ws_areas = ws_areas)

    unscaled_portal_flux_dirs <- dir(path = '../portal/data',
                                     pattern = '*_flux_inst',
                                     include.dirs = TRUE,
                                     full.names = TRUE,
                                     recursive = TRUE)

    unscaled_portal_flux_dirs <- grep('(/documentation/|inst_scaled)',
                                      unscaled_portal_flux_dirs,
                                      value = TRUE,
                                      invert = TRUE)

    #omit (i.e. do not delete) domains like mcmurdo that cannot be scaled
    unscaled_portal_flux_dirs <- grep(glue('/{paste(no_scale_dmns, collapse = "|")}/'),
                                      unscaled_portal_flux_dirs,
                                      value = TRUE,
                                      invert = TRUE)

    lapply(X = unscaled_portal_flux_dirs,
           FUN = unlink,
           recursive = TRUE)

    #the new engine, for scaling flux data within data_acquisition/data
    engine_for_data_acquis <- function(flux_var, network_domain, ws_areas){

        for(i in 1:nrow(network_domain)){

            ntw <- network_domain$network[i]
            dmn <- network_domain$domain[i]

            if(dmn %in% no_scale_dmns){
                warning('NAs in ws_area_ha for ', dmn, '. Not scaling (skipping) this domain.')
                next
            }

            flux_var_dir <- try(
                {
                    ff <- list.files(path = glue('data/{n}/{d}/derived',
                                                 n = ntw,
                                                 d = dmn),
                                                 # v = flux_var),
                                     pattern = flux_var,
                                     full.names = FALSE,
                                     recursive = FALSE)

                    # panola CUSTOM prods should be the only ones that are already scaled.
                    # (they get ignored here on that account).
                    # otherwise current practice is to unscale CUSTOM prods within
                    # kernels so that we don't have to keep track of them here.
                    ff <- ff[! grepl(pattern = 'inst_scaled',
                                     x = ff)]

                },
                silent = TRUE
            )

            if('try-error' %in% class(flux_var_dir) || length(flux_var_dir) == 0) next

            prodcode <- prodcode_from_prodname_ms(flux_var_dir)
            dir.create(path = glue('data/{n}/{d}/derived/{cst}{v}_scaled__{pc}',
                                   n = ntw,
                                   d = dmn,
                                   cst = ifelse(grepl('CUSTOM', flux_var_dir),
                                                'CUSTOM', ''),
                                   v = flux_var,
                                   pc = prodcode),
                       recursive = TRUE,
                       showWarnings = FALSE)

            files <- list.files(path = glue('data/{n}/{d}/derived/{fvd}',
                                            n = ntw,
                                            d = dmn,
                                            fvd = flux_var_dir),
                                pattern = '*.feather',
                                full.names = TRUE,
                                recursive = TRUE)

            for(f in files){

                d <- read_feather(f)

                d <- d %>%
                    mutate(val = errors::set_errors(val, val_err)) %>%
                    select(-val_err) %>%
                    arrange(site_code, var, datetime) %>%
                    left_join(ws_areas[[dmn]],
                              by = 'site_code')

                if(any(is.na(d$ws_area_ha))){
                    warning('NAs in ws_area_ha for ', dmn, '. Not scaling this domain.')
                    break
                } else {
                    d <- mutate(d, val = sw(val / ws_area_ha))
                }

                d$ws_area_ha <- NULL
                d$val_err <- errors(d$val)
                d$val <- errors::drop_errors(d$val)

                f_scaled <- sub(pattern = 'inst__',
                                replacement = 'inst_scaled__',
                                x = f)

                dir_fin <- gsub('(ms[0-9]{3}/).*', '\\1', f_scaled)
                if(! dir.exists(dir_fin)){
                    #pretty sure this section is unneeded. also the line above can be replaced with dirname(f_scaled)
                    browser()
                    dir.create(dir_fin)
                }

                write_feather(x = d,
                              path = f_scaled)
            }
        }
    }

    #don't need these here!
    # engine_for_data_acquis(flux_var = 'CUSTOMstream_flux_inst',
    # engine_for_data_acquis(flux_var = 'CUSTOMprecip_flux_inst',
    engine_for_data_acquis(flux_var = 'stream_flux_inst',
                           network_domain = network_domain,
                           ws_areas = ws_areas)
    engine_for_data_acquis(flux_var = 'precip_flux_inst',
                           network_domain = network_domain,
                           ws_areas = ws_areas)

    # system("find data -path '*/derived/*.feather' -links 1", intern = TRUE)
    # missing_links <- system("find ../portal/data -name '*.feather' -links 1",
    #                         intern = TRUE)
    # if(length(missing_links)){
    #     stop('might need to manually hardlink some files from data_processing/data to portal/data. def need to get to the bottom of this.')
    # }

    unscaled_acquisition_flux_dirs <- dir(path = 'data',
                                          pattern = '*_flux_inst',
                                          include.dirs = TRUE,
                                          full.names = TRUE,
                                          recursive = TRUE)

    unscaled_acquisition_flux_dirs <-
        unscaled_acquisition_flux_dirs[! grepl(pattern = '(/documentation/|_scaled)',
                                               x = unscaled_acquisition_flux_dirs)]

    unscaled_acquisition_flux_dirs <-
        unscaled_acquisition_flux_dirs[grepl(pattern = '/derived/',
                                               x = unscaled_acquisition_flux_dirs)]

    #omit (i.e. do not delete) domains like mcmurdo that cannot be scaled
    unscaled_acquisition_flux_dirs <- grep(glue('/{paste(no_scale_dmns, collapse = "|")}/'),
                                           unscaled_acquisition_flux_dirs,
                                           value = TRUE,
                                           invert = TRUE)

    lapply(X = unscaled_acquisition_flux_dirs,
           FUN = unlink,
           recursive = TRUE)

    return(invisible())
}

undo_scale_flux_by_area <- function(d){

    sites <- unique(d$site_code)

    ws_areas <- site_data %>%
        filter(site_type == 'stream_gauge',
               in_workflow == 1) %>%
        select(site_code, ws_area_ha) %>%
        filter(site_code %in% !!sites)

    d <- d %>%
        left_join(ws_areas,
                  by = 'site_code') %>%
        mutate(val = val * ws_area_ha) %>%
        select(-ws_area_ha)

    return(d)
}


approxjoin_datetime <- function(x,
                                y,
                                rollmax = '7:30',
                                keep_datetimes_from = 'x',
                                indices_only = FALSE){
                                #direction = 'forward'){

    #TODO: update to match nearest non-NA value by column if we ever go sub-daily.
    #some code for this in place below, but note that implementing this will
    #break incides_only. also there will be no good way to select the matching
    #date in cases where there are multiple data columns. i.e. there will be
    #seprate matched dates for each column... not sure how to handle.

    #x and y: macrosheds standard tibbles with only one site_code,
    #   which must be the same in x and y. Nonstandard tibbles may also work,
    #   so long as they have datetime columns, but the only case where we need
    #   this for other tibbles is inside precip_pchem_pflux_idw, in which case
    #   indices_only == TRUE, so it's not really set up for general-purpose joining
    #rollmax: the maximum snap time for matching elements of x and y.
    #   either '7:30' for continuous data or '12:00:00' for grab data
    #direction [REMOVED]: either 'forward', meaning elements of x will be rolled forward
    #   in time to match the next y, or 'backward', meaning elements of
    #   x will be rolled back in time to reach the previous y
    #keep_datetimes_from: string. either 'x' or 'y'. the datetime column from
    #   the corresponding tibble will be kept, and the other will be dropped
    #indices_only: logical. if TRUE, a join is not performed. rather,
    #   the matching indices from each tibble are returned as a named list of vectors..

    #good datasets for testing this function:
    # x <- tribble(
    #     ~datetime, ~site_code, ~var, ~val, ~ms_status, ~ms_interp,
    #     '1968-10-09 04:42:00', 'GSWS10', 'GN_alk', set_errors(27.75, 1), 0, 0,
    #     '1968-10-09 04:44:00', 'GSWS10', 'GN_alk', set_errors(21.29, 1), 0, 0,
    #     '1968-10-09 04:47:00', 'GSWS10', 'GN_alk', set_errors(21.29, 1), 0, 0,
    #     '1968-10-09 04:59:59', 'GSWS10', 'GN_alk', set_errors(16.04, 1), 0, 0,
    #     '1968-10-09 05:15:01', 'GSWS10', 'GN_alk', set_errors(17.21, 1), 1, 0,
    #     '1968-10-09 05:30:59', 'GSWS10', 'GN_alk', set_errors(16.50, 1), 0, 0) %>%
        # mutate(datetime = as.POSIXct(datetime, tz = 'UTC'))
    # y <- tribble(
    #     ~datetime, ~site_code, ~var, ~val, ~ms_status, ~ms_interp,
    #     '1968-10-09 04:00:00', 'GSWS10', 'GN_alk', set_errors(1.009, 1), 1, 0,
    #     '1968-10-09 04:15:00', 'GSWS10', 'GN_alk', set_errors(2.009, 1), 1, 1,
    #     '1968-10-09 04:30:00', 'GSWS10', 'GN_alk', set_errors(3.009, 1), 1, 1,
    #     '1968-10-09 04:45:00', 'GSWS10', 'GN_alk', set_errors(4.009, 1), 1, 1,
    #     '1968-10-09 05:00:00', 'GSWS10', 'GN_alk', set_errors(5.009, 1), 1, 1,
    #     '1968-10-09 05:15:00', 'GSWS10', 'GN_alk', set_errors(6.009, 1), 1, 1) %>%
    #     mutate(datetime = as.POSIXct(datetime, tz = 'UTC'))

    #tests
    if('site_code' %in% colnames(x) && length(unique(x$site_code)) > 1){
        stop('Only one site_code allowed in x at the moment')
    }
    if('var' %in% colnames(x) && length(unique(drop_var_prefix(x$var))) > 1){
        stop('Only one var allowed in x at the moment (not including prefix)')
    }
    if('site_code' %in% colnames(y) && length(unique(y$site_code)) > 1){
        stop('Only one site_code allowed in y at the moment')
    }
    if('var' %in% colnames(y) && length(unique(drop_var_prefix(y$var))) > 1){
        stop('Only one var allowed in y at the moment (not including prefix)')
    }
    if('site_code' %in% colnames(x) &&
       'site_code' %in% colnames(y) &&
       x$site_code[1] != y$site_code[1]) stop('x and y site_code must be the same')
    if(! rollmax %in% c('7:30', '12:00:00')) stop('rollmax must be "7:30" or "12:00:00"')
    # if(! direction %in% c('forward', 'backward')) stop('direction must be "forward" or "backward"')
    if(! keep_datetimes_from %in% c('x', 'y')) stop('keep_datetimes_from must be "x" or "y"')
    if(! 'datetime' %in% colnames(x) || ! 'datetime' %in% colnames(y)){
        stop('both x and y must have "datetime" columns containing POSIXct values')
    }
    if(! is.logical(indices_only)) stop('indices_only must be a logical')

    #data.table doesn't work with the errors package, so error needs
    #to be separated into its own column and handled with care.

    # #this will be useful if we go sub-daily
    # if(any(c('val', 'ms_status') %in% colnames(x))){
    #
    #     x <- x %>%
    #         mutate(
    #                # across(where(~inherits(., 'errors')),
    #                #        ~case_when(! is.na(.) & is.na(errors(.)) ~ set_errors(., 0), TRUE ~ .)),
    #                across(where(~inherits(., 'errors')),
    #                       ~errors(.),
    #                       .names = '{.col}_err'),
    #                across(where(~inherits(., 'errors')),
    #                       ~drop_errors(.))) %>%
    #         rename_with(.fn = ~paste0(., '_x'),
    #                     .cols = everything()) %>%
    #         # rename(datetime_x = datetime) %>%
    #         as.data.table()
    #
    #     y <- y %>%
    #         mutate(
    #                # across(where(~inherits(., 'errors')),
    #                #        ~case_when(! is.na(.) & is.na(errors(.)) ~ set_errors(., 0), TRUE ~ .)),
    #                across(where(~inherits(., 'errors')),
    #                       ~errors(.),
    #                       .names = '{.col}_err'),
    #                across(where(~inherits(., 'errors')),
    #                       ~drop_errors(.))) %>%
    #         rename_with(.fn = ~paste0(., '_y'),
    #                     .cols = everything()) %>%
    #         # rename(datetime_y = datetime) %>%
    #         as.data.table()

    if('val' %in% colnames(x)){

        x <- x %>%
            mutate(err = errors(val),
                   val = errors::drop_errors(val)) %>%
            rename_with(.fn = ~paste0(., '_x'),
                        .cols = everything()) %>%
            as.data.table()

        y <- y %>%
            mutate(err = errors(val),
                   val = errors::drop_errors(val)) %>%
            rename_with(.fn = ~paste0(., '_y'),
                        .cols = everything()) %>%
            as.data.table()

    } else {

        if(indices_only){
            x <- rename(x, datetime_x = datetime) %>%
                mutate(across(where(~inherits(., 'errors')),
                              ~drop_errors(.))) %>%
                as.data.table()

            y <- rename(y, datetime_y = datetime) %>%
                mutate(across(where(~inherits(., 'errors')),
                              ~drop_errors(.))) %>%
                as.data.table()
        } else {
            stop('this case not yet handled')
        }

    }

    #alternative implementation of the "on" argument in data.table joins...
    #probably more flexible, so leaving it here in case we need to do something crazy
    # data.table::setkeyv(x, 'datetime')
    # data.table::setkeyv(y, 'datetime')

    #convert the desired maximum roll distance from string to integer seconds
    rollmax <- ifelse(test = rollmax == '7:30',
                      yes = 7 * 60 + 30,
                      no = 12 * 60 * 60)

    #leaving this here in case the nearest neighbor join implemented below is too
    #slow. then we can fall back to a basic rolling join with a maximum distance
    # rollmax <- ifelse(test = direction == 'forward',
    #                   yes = -rollmax,
    #                   no = rollmax)
    #rollends will move the first/last value of x in the opposite `direction` if necessary
    # joined <- y[x, on = 'datetime', roll = rollmax, rollends = c(TRUE, TRUE)]

    #create columns in x that represent the snapping window around each datetime
    x[, `:=` (datetime_min = datetime_x - rollmax,
              datetime_max = datetime_x + rollmax)]
    y[, `:=` (datetime_y_orig = datetime_y)] #datetime col will be dropped from y

    #join x rows to y if y's datetime falls within the x range
    joined <- y[x, on = .(datetime_y <= datetime_max,
                          datetime_y >= datetime_min)]
    joined <- na.omit(joined, cols = 'datetime_y_orig') #drop rows without matches

    #for any datetimes in x or y that were matched more than once, keep only
    #the nearest match
    joined[, `:=` (datetime_match_diff = abs(datetime_x - datetime_y_orig))]
    joined <- joined[, .SD[which.min(datetime_match_diff)], by = datetime_x]
    joined <- joined[, .SD[which.min(datetime_match_diff)], by = datetime_y_orig]
    #this will grab the nearest non-NA for each column, but that messes up the datatime indices
    # joined = joined[order(datetime_match_diff),
    #                 lapply(.SD, function(z) dplyr::first(na.omit(z))),
    #                 by = datetime_x]

    if(indices_only){
        y_indices <- which(y$datetime_y %in% joined$datetime_y_orig)
        x_indices <- which(x$datetime_x %in% joined$datetime_x)
        return(list(x = x_indices, y = y_indices))
    }

    #drop and rename columns (data.table makes weird name modifications)
    if(keep_datetimes_from == 'x'){
        joined[, c('datetime_y', 'datetime_y.1', 'datetime_y_orig', 'datetime_match_diff') := NULL]
        setnames(joined, 'datetime_x', 'datetime')
    } else {
        joined[, c('datetime_x', 'datetime_y.1', 'datetime_y', 'datetime_match_diff') := NULL]
        setnames(joined, 'datetime_y_orig', 'datetime')
    }

    # #restore error objects, var column, original column names (with suffixes).
    # #original column order (incomplete. execution always returns before this point
    # #in idw, which is the only place where it would be necessary)
    # ernames = grep('_err_[xy]$', colnames(joined), value = TRUE)
    # ernames = ernames[sub('err_', '', ernames) %in% colnames(joined)]
    # for(erc in ernames){
    #     dac = sub('err_', '', erc)
    #     if(dac %in%
    #     set(joined, j = dac,
    #         value = set_errors(joined[[dac]], joined[[erc]]))
    # }

    joined <- as_tibble(joined) %>%
        mutate(val_x = errors::set_errors(val_x, err_x),
               val_y = errors::set_errors(val_y, err_y)) %>%
        select(-err_x, -err_y)

    joined <- select(joined,
                     datetime,
                     starts_with('site_code'),
                     any_of(c(starts_with('var_'), matches('^var$'))),
                     any_of(c(starts_with('val_'), matches('^val$'))),
                     starts_with('ms_status_'),
                     starts_with('ms_interp_'))

    return(joined)
}

retrieve_versionless_product <- function(network,
                                         domain,
                                         prodname_ms,
                                         site_code,
                                         resource_url = NA_character_,
                                         tracker,
                                         orcid_login,
                                         orcid_pass){

    #retrieves products that are served as static files.

    processing_func <- get(paste0('process_0_',
                                  prodcode_from_prodname_ms(prodname_ms)))

    rt <- tracker[[prodname_ms]][[site_code]]$retrieve

    for(i in 1:nrow(rt)){

        held_dt <- as.POSIXct(rt$held_version[i],
                              tz = 'UTC')

        deets <- list(prodname_ms = prodname_ms,
                      site_code = site_code,
                      component = rt$component[i],
                      last_mod_dt = held_dt,
                      url = resource_url)

        result <- do.call(processing_func,
                          args = list(set_details = deets,
                                      network = network,
                                      domain = domain))

        new_status <- evaluate_result_status(result)

        if('access_time' %in% names(result) && any(! is.na(result$access_time))){
            deets$last_mod_dt <- result$access_time[! is.na(result$access_time)][1]
        } else if(is.POSIXct(result)){
            stop('update kernel to return a list with url(s) and access_time(s)')
            # deets$last_mod_dt <- as.character(result)
        }

        update_data_tracker_r(network = network,
                              domain = domain,
                              tracker_name = 'held_data',
                              set_details = deets,
                              new_status = new_status)

        if(ms_instance$use_ms_error_handling){

            kernel_funcs <- glue('src/{n}/processing_kernels.R',
                                 n = network)

            if(! file.exists(kernel_funcs)){

                kernel_funcs <- glue('src/{n}/{d}/processing_kernels.R',
                                     n = network,
                                     d = domain)
            }

            source(kernel_funcs,
                   local = TRUE)

            processing_func <- get(paste0('process_0_',
                                   prodcode_from_prodname_ms(prodname_ms)))
        }

        source_urls <- get_source_urls(result_obj = result,
                                       processing_func = processing_func)

        write_metadata_r(murl = source_urls,
                         network = network,
                         domain = domain,
                         prodname_ms = prodname_ms)
    }
}

get_source_urls <- function(result_obj, processing_func){

    #identify URL(s) indicating data provenance, or return a
    #message explaining why there isn't one

    #find out if the processing func is an alias for download_from_googledrive()
    gd_search_string <- '\\s*download_from_googledrive_function_indicator <- TRUE'
    processing_func_text <- deparse(processing_func)
    # modify to find the string anywhere in the func
    uses_gdrive_func <- any(grepl(gd_search_string, processing_func_text))
    is_passive_kernel <- any(grepl(pattern = 'Nothing to do',
                                   x = processing_func_text,
                                   ignore.case = TRUE)) &&
        length(processing_func_text) < 12

    if(uses_gdrive_func){

        source_urls <- 'MacroSheds drive (contact us for original source): https://drive.google.com/drive/folders/1gugTmDybtMTbmKRq2WQvw2K1WkJjcmJr?usp=sharing'

    } else if('url' %in% names(result_obj)){

        source_urls <- paste(result_obj$url,
                             collapse = '\n')

    } else if(is.null(result_obj) && is_passive_kernel){

        logwarn(msg = 'Update return val to explain where this product comes from.',
                logger = logger_module)

        return('NA')
    } else {
        stop('investigate this. do we need to scrape the URL from products.csv?')
    }

    return(source_urls)
}

munge_versionless_product <- function(network,
                                      domain,
                                      prodname_ms,
                                      site_code,
                                      tracker){

    #munges products that are served as static files.

    processing_func <- get(paste0('process_1_',
                                  prodcode_from_prodname_ms(prodname_ms)))

    rt <- tracker[[prodname_ms]][[site_code]]$retrieve

    for(i in 1:nrow(rt)){

        held_dt <- as.POSIXct(rt$held_version[i],
                              tz = 'UTC')

        result <- do.call(processing_func,
                          args = list(network = network,
                                      domain = domain,
                                      prodname_ms = prodname_ms,
                                      site_code = site_code,
                                      component = rt$component[i]))

        new_status <- evaluate_result_status(result)

        update_data_tracker_m(network = network,
                              domain = domain,
                              tracker_name = 'held_data',
                              prodname_ms = prodname_ms,
                              site_code = site_code,
                              new_status = new_status)

        write_metadata_m(network = network,
                         domain = domain,
                         prodname_ms = prodname_ms,
                         tracker = held_data)
    }
}

catalog_held_data <- function(network_domain, site_data){

    catalog_dir <- '../portal/data/general/catalog_files'
    if(dir.exists(catalog_dir)){
        unlink(catalog_dir, recursive = TRUE)
    }

    dir.create(catalog_dir, showWarnings = FALSE)

    #tabulates:
    # + total nonspatial observations for the portal landing page
    # + informational catalog for all variables
    # + informational catalog for all sites
    # + informational catalog for each individual variable
    # + informational catalog for each individual site

    #TODO write full catalog for download using this code:
    #
    # var_files <- dir('../portal/data/general/catalog_files/indiv_variables',
    #                  full.names = TRUE)
    #
    # d_list <- list()
    # for(i in seq_along(var_files)){
    #
    #     f <- var_files[i]
    #     var_name <- str_match(f, '/([^/]+)?\\.csv$')[, 2]
    #
    #     d_list[[i]] <- read_csv(f,
    #                             col_types = cols()) %>%
    #         mutate(Variable = !!var_name) %>%
    #         select(Variable, everything())
    # }
    #
    # d <- Reduce(bind_rows, d_list)
    #
    # write_csv(d, '/tmp/macrosheds_variable-by-site_summary.csv')

    nobs_nonspatial <- 0

    output_dataset <- paste0('macrosheds_dataset_v', vsn)
    if(! dir.exists(output_dataset)){
        stop('output dataset not yet generated')
    }

    all_site_breakdown <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        select(-in_workflow, -notes, -CRS, -local_time_zone)

    all_variable_breakdown <- tibble()
    for(i in 1:nrow(network_domain)){

        # site_prods <- list.dirs(glue('data/{n}/{d}/derived',
        site_prods <- list.dirs(glue('{od}/{n}/{d}/derived',
                                    od = output_dataset,
                                    n = network_domain$network[i],
                                    d = network_domain$domain[i]),
                               full.names = TRUE)
        site_prods <- site_prods[! grepl('derived$', site_prods)]
        site_prods <- site_prods[! grepl('/documentation', site_prods)]

        if(length(site_prods) == 0) next

        spatial_prod_inds <- grep(pattern = '(gauge|boundary)',
                                  x = site_prods)

        spatial_prods <- site_prods[spatial_prod_inds]
        nonspatial_prods <- site_prods[-spatial_prod_inds]

        #don't double-count when there's a custom version of a product
        custprods <- grep('CUSTOM', nonspatial_prods, value = TRUE)
        if(length(custprods)){
            for(cp in custprods){
                pname <- str_extract(cp, 'CUSTOM(.+?)__', group = 1)
                if(sum(grepl(pname, nonspatial_prods)) > 1){
                    nonspatial_prods <- nonspatial_prods[! nonspatial_prods == cp]
                }
            }
        }

        for(j in seq_along(nonspatial_prods)){

            if(any(grepl('precip_pchem_pflux', nonspatial_prods))){
                logwarn(msg = 'why is there a precip_pchem_pflux directory? fix this',
                        logger = logger_module)
                nonspatial_prods <- nonspatial_prods[! grepl('precip_pchem_pflux', nonspatial_prods)]
            }

            ## sum all observations across all sites (will be redundant when the rest is done)
            prod_nobs <- list.files(nonspatial_prods[j],
                                    full.names = TRUE,
                                    recursive = TRUE) %>%
                purrr::map(~ feather::feather_metadata(.x)$dim[1]) %>%
                purrr::reduce(sum)

            nobs_nonspatial <- nobs_nonspatial + prod_nobs

            ## catalog sites for display (one at a time is the safest way)

            product_files <- list.files(nonspatial_prods[j],
                       full.names = TRUE,
                       recursive = TRUE)

            # product_vars <- c()
            # nobs <- 0
            # first_record <- last_record <- lubridate::NA_POSIXct_

            # product_breakdown <- tibble(var = character(),
            #                               sample_regimen = character(),
            #                               n_observations = numeric(),
            #                               first_record_UTC = lubridate::POSIXct(),
            #                               last_record_UTC = lubridate::POSIXct())

            #read and combine product files; calculate some goodies
            product_breakdown <- tibble()
            for(f in product_files){

                product_breakdown <- read_feather(f) %>%
                    # mutate(
                        # sample_regimen = extract_var_prefix(var),
                        # var = drop_var_prefix(var)) %>%
                    # group_by(var, sample_regimen, site_code) %>%
                    group_by(var, grab_sample, site_code) %>%
                    summarize(
                        n_observations = length(na.omit(val)),
                        first_record = min(date,
                                           na.rm = TRUE),
                        last_record = max(date,
                                          na.rm = TRUE),
                        # first_record_UTC = min(datetime,
                        #                        na.rm = TRUE),
                        # last_record_UTC = max(datetime,
                        #                       na.rm = TRUE),
                        prop_flagged = sum(ms_status) / n_observations,
                        prop_imputed = sum(ms_interp) / n_observations) %>%
                    ungroup() %>%
                    bind_rows(product_breakdown)

                flx_vars <- ms_vars$variable_code[ms_vars$flux_convertible == 1]
                is_flxvar <- product_breakdown$var %in% flx_vars
                other_chemish_vars <- ms_vars$variable_code[ms_vars$flux_convertible == 0 &
                    ms_vars$variable_type %in% c('phys', 'chem_mix', 'chem_discrete', 'bio', 'gas', 'isotope') &
                    ms_vars$unit %in% c('ueq/L', 'mg/L', 'eq/L')]
                is_other_chemish <- product_breakdown$var %in% other_chemish_vars

                product_breakdown$chem_class <- 'NA'
                if(grepl('stream_flux_inst', f)){
                    product_breakdown$chem_class[is_flxvar] <- 'stream_flux'
                    product_breakdown <- product_breakdown[! product_breakdown$chem_class == 'NA', ] #NAs shouldn't exist here
                } else if(grepl('precip_flux_inst', f)){
                    product_breakdown$chem_class[is_flxvar] <- 'precip_flux'
                    product_breakdown <- product_breakdown[! product_breakdown$chem_class == 'NA', ] #NAs shouldn't exist here
                } else if(grepl('precip_chemistry', f)){
                    product_breakdown$chem_class[is_flxvar | is_other_chemish] <- 'precip_conc'
                } else if(grepl('stream_chemistry', f)){
                    product_breakdown$chem_class[is_flxvar | is_other_chemish] <- 'stream_conc'
                }
            }

            #summarize and enhance goodies
            product_breakdown <- product_breakdown %>%
                group_by(var, grab_sample, site_code, chem_class) %>%
                summarize(
                    n_flagged = sum(prop_flagged * n_observations,
                                    na.rm = TRUE),
                    n_imputed = sum(prop_imputed * n_observations,
                                    na.rm = TRUE),
                    n_observations = sum(n_observations,
                                         na.rm = TRUE),
                    pct_flagged = round(n_flagged / n_observations * 100,
                                        digits = 2),
                    pct_imputed = round(n_imputed / n_observations * 100,
                                        digits = 2),
                    first_record = min(first_record,
                                       na.rm = TRUE),
                    last_record = max(last_record,
                                      na.rm = TRUE)) %>%
                ungroup() %>%
                select(-n_flagged, -n_imputed) %>%
                # mutate(sample_regimen = case_when(
                #     sample_regimen == 'GS' ~ 'grab-sensor',
                #     sample_regimen == 'IS' ~ 'installed-sensor',
                #     sample_regimen == 'GN' ~ 'grab-nonsensor',
                #     sample_regimen == 'IN' ~ 'installed-nonsensor')) %>%
                select(site_code, var, grab_sample, n_observations,
                       first_record, last_record, pct_flagged,
                       pct_imputed, chem_class)

            #if multiple sample regimens for a site-variable, aggregate and append them as grab_sample "all"
            product_breakdown <- product_breakdown %>%
                group_by(site_code, var, chem_class) %>%
                summarize(
                    n_observations = if(n() > 1) sum(n_observations, na.rm = TRUE) else first(n_observations),
                    pct_flagged = if(n() > 1) round(sum(pct_flagged, na.rm = TRUE), digits = 2) else first(pct_flagged),
                    pct_imputed = if(n() > 1) round(sum(pct_imputed, na.rm = TRUE), digits = 2) else first(pct_imputed),
                    first_record = if(n() > 1) min(first_record, na.rm = TRUE) else first(first_record),
                    last_record = if(n() > 1) max(last_record, na.rm = TRUE) else first(last_record),
                    grab_sample = if(n() > 1) FALSE else first(grab_sample)
                ) %>%
                ungroup() %>%
                # filter(sample_regimen != 'drop') %>%
                bind_rows(product_breakdown)

            #merge other stuff from variables and site_data config sheets;
            #final sorting and renaming
            #(TODO: add methods once we have that worked out)
            product_breakdown <- product_breakdown %>%
                left_join(select(ms_vars,
                                 variable_code, variable_name, unit), #, method
                          by = c('var' = 'variable_code')) %>%
                mutate(unit = ifelse(grepl('flux$',
                                           chem_class),
                                     'kg/ha/d',
                                     unit)) %>%
                left_join(select(all_site_breakdown,
                                 network, domain, site_code),
                          by = 'site_code') %>%
                select(network,
                       domain,
                       site_code,
                       VariableCode = var,
                       VariableName = variable_name,
                       ChemCategory = chem_class,
                       GrabSample = grab_sample,
                       # SampleRegimen = sample_regimen,
                       Unit = unit,
                       Observations = n_observations,
                       FirstRecord = first_record,
                       LastRecord = last_record,
                       PercentFlagged = pct_flagged,
                       PercentImputed = pct_imputed) %>%
                arrange(network, domain, site_code, VariableCode, ChemCategory,
                        GrabSample)
                # filter(! is.na(domain)) #only needed for unresolved Arctic naming issue (1/15/21)

            if(any(is.na(product_breakdown$domain))){
                browser()
                stop('NA domain(s) detected')
            }

            #combine with other product summaries
            all_variable_breakdown <- bind_rows(all_variable_breakdown,
                                                product_breakdown)
        }
    }

    readr::write_file(x = as.character(nobs_nonspatial),
                      file = '../portal/data/general/total_nonspatial_observations.txt')

    ## generate and write file describing all variables

    #chem and flux stuff is broken out by category, so summarize the vars that,
    #aren't. otherwise they'd be duplicated (because they exist in multiple files),
    #e.g. pH, spCond, d18O
    all_variable_breakdown <- all_variable_breakdown %>%
        group_by(network, domain, site_code, VariableCode, ChemCategory,
                 GrabSample) %>%
        summarize(VariableName = first(VariableName),
                  Unit = first(Unit),
                  FirstRecord = min(FirstRecord),
                  LastRecord = max(LastRecord),
                  PercentFlagged = sum(Observations * (PercentFlagged / 100)) /
                      sum(Observations) * 100,
                  PercentImputed = sum(Observations * (PercentImputed / 100)) /
                      sum(Observations) * 100,
                  Observations = sum(Observations),
                  .groups = 'drop')

    all_variable_display <- all_variable_breakdown %>%
        group_by(VariableCode, ChemCategory) %>%
        summarize(
            Observations = sum(Observations,
                               na.rm = TRUE),
            Sites = length(unique(paste0(network, domain, site_code))),
            FirstRecord = min(FirstRecord,
                              na.rm = TRUE),
            LastRecord = max(LastRecord,
                             na.rm = TRUE),
            VariableName = first(VariableName),
            Unit = first(Unit)) %>%
        ungroup() %>%
        mutate(MeanObsPerSite = round(Observations / Sites, 0),
               Availability = paste0("<button type='button' id='", VariableCode, "'>view</button>")) %>%
               # Availability = paste0("<a href='?", VariableCode, "'>view</a>")) %>%
        select(Availability, VariableName, VariableCode, ChemCategory, Unit,
               Observations, Sites, MeanObsPerSite, FirstRecord,
               LastRecord)

    readr::write_csv(x = all_variable_display,
                     file = '../portal/data/general/catalog_files/all_variables.csv')


    ## generate and write individual file for each variable, describing it by site

    dir.create('../portal/data/general/catalog_files/indiv_variables',
               showWarnings = FALSE)

    vars <- unique(all_variable_display$VariableCode)
    for(v in vars){

        indiv_variable_display <- all_variable_breakdown %>%
            filter(VariableCode == !!v) %>%
            group_by(network, domain, site_code, ChemCategory) %>%
            summarize(
                Observations = sum(Observations,
                                   na.rm = TRUE),
                FirstRecord = min(FirstRecord,
                                  na.rm = TRUE),
                LastRecord = max(LastRecord,
                                    na.rm = TRUE),
                Unit = first(Unit)) %>%
            ungroup()

        ndays <- difftime(time1 = indiv_variable_display$LastRecord,
                          time2 = indiv_variable_display$FirstRecord,
                          units = 'days') %>%
            as.numeric()

        indiv_variable_display$MeanObsPerDay <- round(
            indiv_variable_display$Observations / ndays,
            digits = 1
        )

        indiv_variable_display <- indiv_variable_display %>%
            left_join(select(all_site_breakdown,
                             domain, pretty_domain, network, pretty_network,
                             site_code),
                      by = c('network', 'domain', 'site_code')) %>%
            select(Network = pretty_network,
                   Domain = pretty_domain,
                   SiteCode = site_code,
                   ChemCategory, Unit, Observations, FirstRecord,
                   LastRecord, MeanObsPerDay) %>%
            arrange(Network, Domain, SiteCode, ChemCategory)

        if(any(duplicated(indiv_variable_display[c('SiteCode', 'ChemCategory')]))){
            stop("duplicated sites in indiv_variable_display. what's the deal?")
        }

        readr::write_csv(x = indiv_variable_display,
                         file = glue('../portal/data/general/catalog_files/indiv_variables/',
                                     v, '.csv'))
    }

    ## generate and write file describing all sites
    #TODO: ExternalLink column

    all_site_display <- all_variable_breakdown %>%
        group_by(network, domain, site_code) %>%
        summarize(
            Observations = sum(Observations,
                               na.rm = TRUE),
            Variables = length(unique(VariableCode)),
            FirstRecord = min(FirstRecord,
                              na.rm = TRUE),
            LastRecord = max(LastRecord,
                             na.rm = TRUE)) %>%
        ungroup() %>%
        mutate(MeanObsPerVar = round(Observations / Variables, 0),
               ExternalLink = 'feature not yet built',
               Availability = paste0("<button type='button' id='",
                                     network, '_', domain, '_', site_code,
                                     "'>view</button>")) %>%
               # GeodeticDatum = 'WGS 84') %>%
        left_join(all_site_breakdown,
                  by = c('network', 'domain', 'site_code')) %>%
        select(Availability,
               Network = pretty_network,
               Domain = pretty_domain,
               SiteCode = site_code,
               SiteName = full_name,
               StreamName = stream,
               WatershedStatus = ws_status,
               Latitude = latitude,
               Longitude = longitude,
               # GeodeticDatum,
               SiteType = site_type,
               AreaHectares = ws_area_ha,
               Observations, Variables, FirstRecord, LastRecord,
               ExternalLink) %>%
        mutate(WatershedStatus = case_when(WatershedStatus == 'exp' ~ 'experimental',
                                           WatershedStatus == 'non_exp' ~ 'non-experimental',
                                           TRUE ~ WatershedStatus))

    readr::write_csv(x = all_site_display,
                     file = '../portal/data/general/catalog_files/all_sites.csv')

    ## generate and write individual file for each site, describing it by variable

    dir.create('../portal/data/general/catalog_files/indiv_sites',
               showWarnings = FALSE)

    sites <- distinct(all_site_breakdown,
                      network, domain, site_code)

    for(i in 1:nrow(sites)){

        ntw <- sites$network[i]
        dmn <- sites$domain[i]
        sit <- sites$site_code[i]

        indiv_site_display <- all_variable_breakdown %>%
            filter(network == ntw,
                   domain == dmn,
                   site_code == sit)

        ndays <- difftime(time1 = indiv_site_display$LastRecord,
                          time2 = indiv_site_display$FirstRecord,
                          units = 'days') %>%
            as.numeric()

        indiv_site_display$MeanObsPerDay <- round(
            indiv_site_display$Observations / ndays,
            digits = 1
        )

        indiv_site_display <- indiv_site_display %>%
            # left_join(select(all_site_breakdown,
            #                  domain, pretty_domain, network, pretty_network,
            #                  site_code),
            #           by = c('network', 'domain', 'site_code')) %>%
            select(VariableCode, VariableName, ChemCategory, GrabSample, Unit,
                   Observations, FirstRecord, LastRecord,
                   MeanObsPerDay, PercentFlagged, PercentImputed)

        if(any(duplicated(indiv_site_display[c('VariableCode', 'ChemCategory', 'GrabSample')]))){
            stop("duplicated vars in indiv_site_display. what's the deal?")
        }

        readr::write_csv(x = indiv_site_display,
                         file = glue('../portal/data/general/catalog_files/indiv_sites/',
                                     '{n}_{d}_{s}.csv',
                                     n = ntw,
                                     d = dmn,
                                     s = sit))
    }

    #in case somebody asks for this stuff again:

    # #domains per network
    # site_data %>%
    #     filter(as.logical(in_workflow)) %>%
    #     group_by(network) %>%
    #     summarize(n_domains = length(unique(domain)))
    #
    # #sites per domain
    # site_data$stream[is.na(site_data$stream)] = 1:sum(is.na(site_data$stream))
    # site_data %>%
    #     filter(as.logical(in_workflow),
    #            site_type != 'rain_gauge') %>%
    #     group_by(network, domain) %>%
    #     summarize(n_sites = length(unique(site_code)),
    #               n_unique_streams = length(unique(stream)))
    #
    # #mean sites per domain
    # site_data %>%
    #     filter(as.logical(in_workflow),
    #            site_type != 'rain_gauge') %>%
    #     group_by(network, domain) %>%
    #     summarize(n_sites = length(unique(site_code))) %>%
    #     ungroup() %>%
    #     {mean(.$n_sites)}
    #
    # #total sites
    # site_data %>%
    #     filter(as.logical(in_workflow),
    #            site_type != 'rain_gauge') %>%
    #     group_by(network, domain) %>%
    #     summarize(n_sites = length(unique(site_code))) %>%
    #     ungroup() %>%
    #     {sum(.$n_sites)}
    #
    # #total unique streams
    # site_data %>%
    #     filter(as.logical(in_workflow),
    #            site_type != 'rain_gauge') %>%
    #     group_by(network, domain) %>%
    #     summarize(n_sites = length(unique(site_code)),
    #               n_unique_streams = length(unique(stream))) %>%
    #     ungroup() %>%
    #     {sum(.$n_unique_streams)}
}

greatest_common_divisor <- function(a, b){

    stopifnot(is.numeric(a), is.numeric(b))

    if(length(a) == 1){
        a <- rep(a, times = length(b))
    } else if(length(b) == 1){
        b <- rep(b, times = length(a))
    }

    n <- length(a)
    e <- d <- g <- numeric(n)

    for(k in 1:n){

        u <- c(1, 0, abs(a[k]))
        v <- c(0, 1, abs(b[k]))

        while(v[3] != 0){

            q <- floor(u[3]/v[3])
            t <- u - v * q
            u <- v
            v <- t
        }

        e[k] <- u[1] * sign(a[k])
        d[k] <- u[2] * sign(a[k])
        g[k] <- u[3]
    }

    return(g)
}

least_common_multiple <- function(a, b){

    stopifnot(is.numeric(a), is.numeric(b))

    if(length(a) == 1){
        a <- rep(a, times = length(b))
    } else if(length(b) == 1){
        b <- rep(b, times = length(a))
    }

    g <- greatest_common_divisor(a, b)

    return(a/g * b)
}

ms_determine_data_interval <- function(d, per_column = FALSE){

    #calculates the mode interval for each variable, then returns the
    #   greatest common divisor of those modes as the interval, in minutes.

    vars <- unique(d$var)

    interval_modes <- c()
    for(v in vars){
        time_diffs <- diff(d$datetime[d$var == v])
        units(time_diffs) = 'mins'
        interval_modes <- c(interval_modes, Mode(time_diffs))
    }

    if(per_column){
        names(interval_modes) <- vars
        return(interval_modes)
    }

    interval_modes <- interval_modes[! is.na(interval_modes)]

    if(! length(interval_modes)) return(NA_real_)

    data_interval <- Reduce(greatest_common_divisor, interval_modes)

    return(data_interval)
}

ms_complete_all_cases <- function(network_domain){

    #populates implicit NAs in all feather files across all product directories.
    #   Note: this only operates on files within data_acquisition/data, NOT within
    #   portal/data (those files should stay as small as possible. see
    #   insert_gap_border_NAs).

    #also note: when we switch back to high-res mode, we'll need to see how much
    #   more space our dataset takes up after this operation. it might be
    #   several gigs, which could be a problem.

    #For special cases (currently only McMurdo), winter data gaps in discharge
    #   timeseries will be populated with 0 instead of NA. McMurdo's winter is
    #   identified as any series of NAs longer than 180 days occurring between
    #   jan 2 and dec 30.

    paths <- list.files(path = 'data',
                        pattern = '*.feather',
                        recursive = TRUE,
                        full.names = TRUE)

    paths <- paths[grepl(pattern = 'derived', x = paths)]

    for(p in paths){

        d <- read_feather(p)
        sites <- unique(d$site_code)
        vars <- unique(d$var)

        if(all(class(d$datetime) == 'Date')){
            warning(paste('converting datetime column from date to datetime after reading', p))
            d$datetime <- lubridate::as_datetime(d$datetime)
        }

        dupes_present <- FALSE
        for(s in sites){
            for(v in vars){

                dt_diff <- d %>%
                    filter(site_code == !!s,
                           var == !!v) %>%
                    arrange(datetime) %>%
                    pull(datetime) %>%
                    as.numeric() %>%
                    diff()

                if(length(dt_diff)){

                    if(any(dt_diff == 0)){
                        warning(glue('Duplicate datetime found in {pp} ({ss}-{vv} slice).',
                                     'This will be removed, but we should find out what the deal is.',
                                      pp = p,
                                      ss = s,
                                      vv = v))

                        dupes_present <- TRUE
                    }

                    if(any(dt_diff <= 15 * 60 & dt_diff != 0)){
                        stop(glue("We need to make sure it's okay to make NAs ",
                                  "explicit, now that we're in high-res mode. ",
                                  "Copy the data directory, comment this error, ",
                                  "run this function, then compare data directory ",
                                  "sizes. If completing ",
                                  "cases doesn't make it absurdly huge, then ",
                                  "remove this error and carry on."))
                    }
                }
            }
        }

        if(dupes_present){
            d <- d %>%
                distinct(site_code, var, datetime,
                         .keep_all = TRUE) %>%
                arrange(site_code, var, datetime)
        }

        interv_mins <- ms_determine_data_interval(d = d)

        if(is.na(interv_mins)){ #only one value, so no interval
            next
        } else if(interv_mins %% 1440 == 0){
            data_interval <- '1 day'
        } else if(interv_mins %% 15 == 0){
            data_interval <- '15 mins'
        } else {
            stop(glue('data interval should be either 1 day or 15 minutes. If ',
                      'this has changed, update the conditional above this error ',
                      'and check for needed updates elsewhere'))
        }

        d <- populate_implicit_NAs(d = d,
                                   interval = data_interval)

        if(grepl('/mcmurdo/', p) && grepl('/discharge__', p)){

            #for sites/products with more than one variable prefix, something more
            #sophisticated will be needed. for mcmurdo, all discharge is IS_discharge
            d <- d %>%
                group_split(site_code, var,
                            year = lubridate::year(datetime)) %>%
                purrr::map_dfr(function(x){

                    na_runlengths <- rle(is.na(x$val))
                    na_len <- na_runlengths$lengths
                    is_na <- na_runlengths$values

                    if(any(is_na[c(1, length(is_na))])) return(x)

                    winter_run <- which(is_na & na_len > 180)

                    if(length(winter_run)){

                        csums <- cumsum(na_len[1:winter_run])
                        winter_inds <- (csums[length(csums) - 1] + 1) :
                            csums[length(csums)]
                        x$val[winter_inds] <- 0
                        x$ms_interp[winter_inds] <- 1
                    }

                    return(x)
                }) %>%
                arrange(site_code, var, datetime)
        }

        write_feather(x = d,
                      path = p)
    }
}

insert_gap_border_NAs <- function(network_domain){

    #populates rows bordering missing data segments with NA data, so that
    #   gaps are properly plotted by dygraphs, etc.
    #   Note: this only operates on files within portal/data, NOT within
    #   data_acquisition/data (see ms_complete_all_cases)

    #TODO: make the following documentation true. for now, nothing is done
    #   differently for mcmurdo, meaning the portal shows gaps for mcmurdo's
    #   winter where the public export data has 0s.
    #For special cases (currently only McMurdo), rows bordering winter data gaps
    #   in discharge timeseries will be populated with 0 instead of NA.
    #   McMurdo's winter is identified as any series of NAs longer than 180 days
    #   occurring between jan 2 and dec 30.

    #notice: running this function multiple times without rebuilding the portal
    #   dataset will keep adding NA rows to the beginning and end of each data
    #   gap. Basically, if you run this n times you'll fill data gaps of up
    #   to length n/2. This isn't a problem.

    paths <- list.files(path = '../portal/data',
                        pattern = '*.feather',
                        recursive = TRUE,
                        full.names = TRUE)

    paths <- paths[! grepl(pattern = '/general/', x = paths)]
    paths <- paths[! grepl(pattern = '/ws_traits/', x = paths)]

    for(p in paths){

        d <- read_feather(p)

        interv_mins <- ms_determine_data_interval(d = d)

        if(is.na(interv_mins)){
            next
        } else if(interv_mins %% 1440 == 0){
            data_interval <- '1 day'
        } else if(interv_mins %% 15 == 0){
            data_interval <- '15 mins'
        } else {
            stop(glue('data interval should be either 1 day or 15 minutes. If ',
                      'this has changed, updates the conditional above this error ',
                      'and check for needed updates elsewhere'))
        }

        d <- populate_implicit_NAs(d = d,
                                   interval = data_interval,
                                   edges_only = TRUE)

        write_feather(x = d,
                      path = p)
    }
}

generate_product_csvs <- function(network_domain){

    #in addition to the data/network/domain/product/site.feather format,
    #   we can provide analysis-ready CSVs.

    dir.create(path = 'output/all_chemQPflux_csv_wide',
               showWarnings = FALSE,
               recursive = TRUE)

    readr::write_file(x = paste('In casting these product sets from long to',
                                'wide format, ms_status (indicating data flags)',
                                'and ms_interp (indicating points interpolated',
                                'by MacroSheds) columns have been dropped. We',
                                'Can include this information in wide format,',
                                'but note that it will nearly double the size',
                                'of each CSV herein.'),
                      file = 'output/all_chemQPflux_csv_wide/README.txt')

    products <- c('stream_chemistry', 'stream_flux_inst_scaled', 'discharge',
                  'precip_chemistry', 'precip_flux_inst_scaled', 'precipitation')


    for(p in products){

        d <- load_entire_product(prodname = p,
                                 .sort = FALSE)

        if(nrow(d) != nrow(distinct(d, datetime, site_code, var))){
            print(paste('there are still duplicates in', p))
        }
        # zz = d %>%
        #     select(-ms_status, -ms_interp) %>%
        #     mutate(val = errors::drop_errors(val)) %>%
        #     tidyr::pivot_wider(names_from = var,
        #                        values_from = val,
        #                        values_fn = length)
        # zzz = apply(zz[,5:ncol(zz)], 1, function(x)any(! is.na(x) & x > 1))
        # filter(d, datetime == as.POSIXct('2003-08-20 00:00:00', tz='UTC'), site_code=='JBHH', var=='GN_PO4_P')

        d %>%
            select(-ms_status, -ms_interp) %>%
            mutate(val = errors::drop_errors(val)) %>%
            tidyr::pivot_wider(names_from = var,
                               values_from = val,
                               values_fn = mean) %>%
            arrange(network, domain, site_code, datetime) %>%
            readr::write_csv(file = glue('output/all_chemQPflux_csv_wide/{pp}.csv',
                                         pp = p))
    }
}

expo_backoff <- function(expr,
                         max_attempts = 10,
                         verbose = TRUE){

    for(attempt_i in seq_len(max_attempts)){

        results <- try(expr = expr,
                       silent = TRUE)

        if(inherits(results, 'try-error')){

            if(attempt_i == max_attempts){
                stop(attr(results, 'condition'))
            }

            backoff <- runif(n = 1,
                             min = 0,
                             max = 2^attempt_i - 1)

            if(verbose){
                print(glue("Backing off for ", round(backoff, 1), " seconds."))
            }

            Sys.sleep(backoff)

        } else {

            # if(verbose){
            #     print(paste0("Request succeeded after ", attempt_i, " attempt(s)."))
            # }

            break
        }
    }

    return(results)
}

combine_ws_boundaries <- function(){

    setwd('../portal/data/')

    ws_dirs <- dir(pattern = 'ws_boundary',
                   recursive = TRUE,
                   include.dirs = TRUE)

    ws_dirs <- grep(pattern = '^(?!.*documentation).*$',
                    x = ws_dirs,
                    value =  TRUE,
                    perl = TRUE)

    ws_list <- list()

    for(i in 1:length(ws_dirs)){

        ws_files <- list.files(ws_dirs[i],
                               pattern = '*shp',
                               recursive = TRUE,
                               full.names = TRUE)

        #read shapefiles, coerce to POLYGON, project, smooth borders
        ws_list_sub <- lapply(X = ws_files,
                              FUN = function(x){

                                  site_code <- str_match(string = x,
                                                         pattern = '^.*/(.*?)\\.shp$')[, 2]

                                  wb <- x %>%
                                      sf::st_read(quiet = TRUE) %>%
                                      sf::st_cast(to = 'POLYGON')

                                  coords <- sf::st_coordinates(wb)
                                  mean_latlong <- unname(colMeans(coords[, 1:2]))

                                  proj <- choose_projection(lat = mean_latlong[2],
                                                            long = mean_latlong[1])

                                  wb %>%
                                      sf::st_transform(crs = proj) %>%
                                      sf::st_union() %>%
                                      sf::st_as_sf() %>%
                                      mutate(site_code = !!site_code) %>%
                                      select(site_code, geometry = x) %>%
                                      sf::st_simplify(dTolerance = 30,
                                                      preserveTopology = TRUE) %>%
                                      sf::st_transform(crs = 4326) #back to WGS 84

                                  # if(length(x$geometry[[1]]) == 0) print(paste(i, site_code))
                              })

        ws_list <- append(x = ws_list,
                          values = ws_list_sub)
    }

    combined <- do.call(bind_rows, ws_list)

    dir.create(path = 'general/shed_boundary',
               showWarnings = FALSE)

    sf::st_write(obj = combined,
                 dsn = 'general/shed_boundary',
                 layer = 'shed_boundary.shp',
                 driver = 'ESRI Shapefile',
                 delete_layer = TRUE,
                 quiet = TRUE)

    if(ms_instance$op_system == 'windows'){
        setwd('../../')
        setwd('data_processing/')
    } else{
        success <- try(setwd('../../data_acquisition/'), silent = TRUE)

        if(inherits(success, 'try-error')){
            setwd('../../data_processing/')
        }
    }

}

get_osm_roads <- function(extent_raster, outfile = NULL){

    #extent_raster: either a terra spatRaster or a rasterLayer. The output
    #   roads will have the same crs, and roughly the same extent, as this raster.
    #outfile: string. If supplied, output shapefile will be written to this
    #   location. If not supplied, the output will be returned.

    message('Downloading roads layer from OpenStreetMap')

    extent_raster <- terra::rast(extent_raster)
    # rast_crs <- as.character(extent_raster@crs)
    rast_crs <- terra::crs(extent_raster,
                           proj = TRUE)

    extent_raster_wgs84 <- terra::project(extent_raster,
                                          y = 'epsg:4326')

    dem_bounds <- terra::ext(extent_raster_wgs84)[c(1, 3, 2, 4)]

    highway_types <- c('motorway', 'trunk', 'primary', 'secondary', 'tertiary')
    highway_types <- c(highway_types,
                       paste(highway_types, 'link', sep = '_'))

    roads_query <- osmdata::opq(dem_bounds) %>%
        osmdata::add_osm_feature(key = 'highway',
                                 value = highway_types)

    roads_query$prefix <- sub('timeout:25', 'timeout:180', roads_query$prefix)

    roads <- osmdata::osmdata_sf(roads_query)
    roads <- roads$osm_lines$geometry

    # plot(roads$osm_lines, max.plot = 1)

    roads_proj <- roads %>%
        sf::st_transform(crs = rast_crs) %>%
        sf::st_union() %>%
        # sf::st_transform(crs = WGS84) %>%
        sf::st_as_sf() %>%
        rename(geometry = x) %>%
        mutate(FID = 0:(n() - 1)) %>%
        dplyr::select(FID, geometry)

    if(! is.null(outfile)){

        sf::st_write(roads_proj,
                     dsn = outfile,
                     layer = 'roads',
                     driver = 'ESRI Shapefile',
                     delete_layer = TRUE,
                     quiet = TRUE)

        message(paste('OSM roads layer written to', outfile))

    } else {
        return(roads_proj)
    }
}

get_osm_streams <- function(extent_raster, outfile = NULL){

    #extent_raster: either a terra spatRaster or a rasterLayer. The output
    #   streams will have the same crs, and roughly the same extent, as this raster.
    #outfile: string. If supplied, output shapefile will be written to this
    #   location. If not supplied, the output will be returned.

    message('Downloading streams layer from OpenStreetMap')

    extent_raster <- terra::rast(extent_raster)
    # rast_crs <- as.character(extent_raster@crs)
    rast_crs <- terra::crs(extent_raster,
                           proj = TRUE)

    extent_raster_wgs84 <- terra::project(extent_raster,
                                          y = 'epsg:4326')

    dem_bounds <- terra::ext(extent_raster_wgs84)[c(1, 3, 2, 4)]

    streams_query <- osmdata::opq(dem_bounds) %>%
        osmdata::add_osm_feature(key = 'waterway',
                                 value = c('river', 'stream'))

    streams_query$prefix <- sub('timeout:25', 'timeout:180', streams_query$prefix)

    streams <- osmdata::osmdata_sf(streams_query)
    streams <- streams$osm_lines$geometry

    streams_proj <- streams %>%
        sf::st_transform(crs = rast_crs) %>%
        sf::st_union() %>%
        # sf::st_transform(crs = WGS84) %>%
        sf::st_as_sf() %>%
        rename(geometry = x) %>%
        mutate(FID = 0:(n() - 1)) %>%
        dplyr::select(FID, geometry)

    if(! is.null(outfile)){

        sf::st_write(streams_proj,
                     dsn = outfile,
                     layer = 'streams',
                     driver = 'ESRI Shapefile',
                     delete_layer = TRUE,
                     quiet = TRUE)

        message(paste('OSM streams layer written to', outfile))

    } else {
        return(streams_proj)
    }
}

fill_sf_holes <- function(x){

    #x: an sf object (probably needs to be projected)

    #if there are spaces in a shapefile polygon that are not filled in,
    #   this fills them.

    #if the first element of an sf geometry (which is a list) contains multiple
    #   elements, every element after the first is a hole. the first element
    #   is the outer geometry. so replace the geometry with a new polygon that
    #   is only the outer geometry

    wb_geom <- sf::st_geometry(x)
    # wb_geom_crs <- sf::st_crs(wb_geom)

    n_polygons <- length(wb_geom[[1]])
    if(n_polygons > 1){
        wb_geom[[1]] <- sf::st_polygon(wb_geom[[1]][1])
    }

    # if(length(wb_geom) != 1){
    #     wb_geom <- sf::st_combine(wb_geom)
    # }

    sf::st_geometry(x) <- wb_geom

    return(x)
}

get_nrcs_soils <- function(network,
                           domain,
                           nrcs_var_name,
                           site,
                           ws_boundaries){

    # Use soilDB to download  soil map unit key (mukey) classification raster
    site_boundary <- ws_boundaries %>%
        filter(site_code == site)

    bb <- sf::st_bbox(site_boundary)

    soil <- try(sw(soilDB::mukey.wcs(aoi = bb,
                                     db = 'gssurgo',
                                     quiet = TRUE)))

    # should build a chunking method for this
    if(class(soil) == 'try-error'){

        this_var_tib <- tibble(site_code = site,
                               year = NA,
                               var =  names(nrcs_var_name),
                               val = NA)

        return(generate_ms_exception(glue('No data available for {s} in NRCS database.',
                                          s = site)))
    }

    # mukey_values <- unique(soil@data@values)
    mukey_values <- values(soil)

    #### Grab soil vars

    # Query Soil Data Acess (SDA) to get the component key (cokey) in each mukey.
    #### each map unit made up of componets but components do not have
    #### spatial informaiton associted with them, but they do include information
    #### on the percentage of each mukey that is made up of each component.
    #### This informaiton on compositon is held in the component table in the
    #### comppct_r column, givin in a percent

    mukey_sql <- soilDB::format_SQL_in_statement(mukey_values)
    mukey_sql <- sub("'NaN'", '', mukey_sql)
    mukey_sql <- sub(',,', ',', mukey_sql)
    mukey_sql <- sub('^\\(,', '(', mukey_sql)
    mukey_sql <- sub(',\\)$', ')', mukey_sql) #probably just use na.rm = TRUE in values() above
    component_sql <- sprintf("SELECT cokey, mukey, compname, comppct_r, majcompflag FROM component WHERE mukey IN %s", mukey_sql)
    component <- sm(soilDB::SDA_query(component_sql))
    if(is.null(component)){
        stop('something misspecified in soilDB query')
    }

    # Check is soil data is available
    if(length(unique(component$compname)) == 1 &&
       unique(component$compname) == 'NOTCOM'){

        this_var_tib <- tibble(site_code = site,
                               year = NA,
                               var =  names(nrcs_var_name),
                               val = NA)

        return(generate_ms_exception(glue('gSSURGO surveys not yet completed for {s}',
                                          s = site)))
    }

    cokey <- unique(component[,1])
    cokey <- data.frame(ID=cokey)

    # Query SDA for the componets to get infromation on their horizons from the
    #### chorizon table. Each componet is made up of soil horizons (layer of soil
    #### vertically) identified by a chkey.
    #### Informaiton about the depth of each horizon is needed to calculate weighted
    #### averges of any parameter for the whole soil column
    #### hzdept_r = depth to top of horizon
    #### hzdepb_r = depth to bottom of horizon
    #### om_r = percent organic matter
    cokey_sql <- soilDB::format_SQL_in_statement(cokey$ID)
    chorizon_sql <- sprintf(paste0('SELECT cokey, chkey, hzname, desgnmaster, hzdept_r, hzdepb_r, ',
                                         paste(nrcs_var_name, collapse = ', '),
                                         ' FROM chorizon WHERE cokey IN %s'), cokey_sql)

    full_soil_data <- sm(soilDB::SDA_query(chorizon_sql))

    # Calculate weighted average for the entire soil column. This involves 3 steps.
    #### First the component's weighted average of all horizones. Second, the
    #### weighted avergae of each component in a map unit. And third, the weighted
    #### average of all mukeys in the watershed (weighted by their area)

    # cokey weighted average of all horizones
    soil_data_joined <- full_join(full_soil_data, component, by = c("cokey"))

    all_soil_vars <- tibble()
    for(s in 1:length(nrcs_var_name)){

        this_var <- unname(nrcs_var_name[s])

        soil_data_one_var <- soil_data_joined %>%
            select(cokey, chkey, hzname, desgnmaster, hzdept_r, hzdepb_r,
                   !!this_var, mukey, compname, comppct_r, majcompflag)

        cokey_size <- soil_data_one_var %>%
            filter(!is.na(.data[[this_var]])) %>%
            mutate(layer_size = hzdepb_r-hzdept_r) %>%
            group_by(cokey) %>%
            summarise(cokey_size = sum(layer_size)) %>%
            ungroup()

        cokey_weighted_av <- soil_data_one_var %>%
            filter(!is.na(.data[[this_var]])) %>%
            mutate(layer_size = hzdepb_r-hzdept_r) %>%
            left_join(., cokey_size, by = 'cokey') %>%
            mutate(layer_prop = layer_size/cokey_size) %>%
            mutate(value_mat_weith = .data[[this_var]] * layer_prop)  %>%
            group_by(mukey, cokey) %>%
            summarise(value_comp = sum(value_mat_weith),
                      comppct_r = unique(comppct_r)) %>%
            ungroup()

        # mukey weighted average of all compenets
        mukey_weighted_av <- cokey_weighted_av %>%
            group_by(mukey) %>%
            mutate(comppct_r_sum = sum(comppct_r)) %>%
            summarise(value_mukey = sum(value_comp*(comppct_r/comppct_r_sum)))

        # Watershed weighted average
        site_boundary_p <- sf::st_transform(site_boundary, crs = sf::st_crs(soil))

        soil_masked <- sw(terra::mask(soil, site_boundary_p))

        # watershed_mukey_values <- soil_masked@data@values %>%
        watershed_mukey_values <- values(soil_masked) %>%
            as_tibble() %>%
            filter(! is.na(mukey)) %>%
            group_by(mukey) %>%
            summarise(n = n()) %>%
            # rename(mukey = value) %>%
            left_join(mukey_weighted_av, by = 'mukey')


        # Info on soil data
        # query SDA's Mapunit Aggregated Attribute table (muaggatt) by mukey.
        # table information found here: https://sdmdataaccess.sc.egov.usda.gov/documents/TableColumnDescriptionsReport.pdf
        # https://www.nrcs.usda.gov/wps/portal/nrcs/detail/soils/survey/geo/?cid=nrcs142p2_053631
        # how the tables relate using mukey, cokey, and chkey is here: https://www.nrcs.usda.gov/Internet/FSE_DOCUMENTS/nrcs142p2_050900.pdf

        if(all(is.na(watershed_mukey_values$value_mukey))){

            watershed_value <- NA
        } else{

            total_cells <- sum(watershed_mukey_values$n)
            na_cells <- watershed_mukey_values %>%
                filter(is.na(value_mukey))
            na_cells <- sum(na_cells$n)

            watershed_mukey_values_weighted <- watershed_mukey_values %>%
                filter(!is.na(value_mukey)) %>%
                mutate(sum = sum(n, na.rm = TRUE)) %>%
                mutate(prop = n/sum)

            watershed_mukey_values_weighted <- watershed_mukey_values_weighted %>%
                mutate(weighted_av = prop*value_mukey)

            watershed_value <- sum(watershed_mukey_values_weighted$weighted_av,
                                   na.rm = TRUE)

            watershed_value <- round(watershed_value, 2)
            na_prop <- round((100*(na_cells/total_cells)), 2)
        }

        this_var_tib <- tibble(year = NA,
                               site_code = site,
                               var =  names(nrcs_var_name[s]),
                               val = watershed_value,
                               pctCellErr = na_prop)

        all_soil_vars <- rbind(all_soil_vars, this_var_tib)
    }

    return(all_soil_vars)

    # #Used to visualize raster
    # for(i in 1:nrow(watershed_mukey_values)){
    #   soil_masked@data@values[soil_masked@data@values == pull(watershed_mukey_values[i,1])] <- pull(watershed_mukey_values[i,3])
    # }
    # soil_masked@data@isfactor <- FALSE
    #
    # mapview::mapview(soil_masked)
    # raster::plot(soil_masked)

    # Other table in SDA system
    # # component table
    # compnent_sql <- soilDB::format_SQL_in_statement(cokey$ID)
    # component_sql <- sprintf("SELECT cokey, runoff, compname, compkind, comppct_r, majcompflag, otherph, localphase, slope_r, hydricrating, taxorder, taxsuborder, taxsubgrp, taxpartsize FROM component WHERE cokey IN %s", compnent_sql)
    # component_return <- soilDB::SDA_query(component_sql)
    #
    # chtext
    # compnent_sql <- soilDB::format_SQL_in_statement(full_soil_data$chkey)
    # component_sql <- sprintf("SELECT texture, stratextsflag, rvindicator, texdesc, chtgkey FROM chtexturegrp WHERE chkey IN %s", compnent_sql)
    # component_return <- soilDB::SDA_query(component_sql)

    # component_sql <- sprintf("SELECT musym, brockdepmin, wtdepannmin, wtdepaprjunmin, niccdcd FROM muaggatt WHERE mukey IN %s", mukey_sql)
    # component_return <- soilDB::SDA_query(component_sql)
    #
    # # corestrictions table
    # corestrictions_sql <- sprintf("SELECT cokey, reskind, resdept_r, resdepb_r, resthk_r FROM corestrictions WHERE cokey IN %s", compnent_sql)
    # corestrictions_return <- soilDB::SDA_query(corestrictions_sql)
    #
    # # cosoilmoist table
    # cosoilmoist_sql <- sprintf("SELECT cokey,  FROM cosoilmoist WHERE cokey IN %s", compnent_sql)
    # corestrictions_return <- soilDB::SDA_query(corestrictions_sql)
    #
    # # pores
    # chkey_sql <- soilDB::format_SQL_in_statement(unique(full_soil_data$chkey))
    # cokey_to_chkey_sql_pores <- sprintf(paste0('SELECT chkey, poresize FROM chpores WHERE chkey IN %s'), chkey_sql)
    #
    # soil_pores <- soilDB::SDA_query(cokey_to_chkey_sql_pores)

}

load_spatial_data <- function(){

    spatial_files <- googledrive::drive_ls(googledrive::as_id('1EaEjkCb_U4zvLCXrULRTU-4yPC95jS__'))

    drive_files <- str_split_fixed(spatial_files$name, '\\.', n = Inf)[, 1]

    dir.create('data/spatial',
               showWarnings = FALSE)

    held_files <- list.files('data/spatial/')
    held_files[held_files == 'bfi.tif'] <- 'bfi'

    needed_files <- drive_files[! drive_files %in% held_files]

    if(length(needed_files)){

        loginfo(glue('Spatial files {sfs} needed from GDrive',
                     sfs = paste(needed_files,
                                 collapse = ', ')),
                logger = logger_module)

    } else {

        loginfo('All spatial files from GDrive are already held locally.',
                logger = logger_module)

        return(invisible())
    }

    needed_files <- paste0(needed_files, '.zip')

    needed_sets <- spatial_files %>%
        filter(name %in% needed_files)

    for(i in 1:nrow(needed_sets)){

        zip_path <- glue('data/spatial/{n}', n = needed_sets$name[i])

        print(paste0('Downloading ', needed_sets$name[i]))
        expo_backoff(
            expr = {
                googledrive::drive_download(file = googledrive::as_id(needed_sets$id[i]),
                                            path = zip_path)
            },
            max_attempts = 5
        ) %>% invisible()

        print(paste0('Unzipping ', needed_sets$name[i]))

        if(needed_sets$name[i] == 'phenology.zip'){
            if(Sys.info()['sysname'] %in% c('Linux', 'linux')){
                system(paste0('unzip ', getwd(), '/',
                              zip_path, ' -d ', getwd(), '/data/spatial/phenology'))
            } else {
                loginfo(generate_ms_exception('Wow! This file is to big to unzip with R, use terminal to unzip'),
                        logger = logger_module)
                next
            }
        } else {
            unzip(zipfile = zip_path,
                  exdir = 'data/spatial')
        }

        file_check <- list.files('data/spatial')

        if('__MACOSX' %in% file_check){
            unlink('data/spatial/__MACOSX', recursive = T)
        }

        file.remove(zip_path)
    }
}

extract_ws_mean <- function(site_boundary, raster_path){

    rast_file <- terra::rast(raster_path)
    rast_crs <- terra::crs(rast_file)

    site_boundary_buf <- sw(sm(site_boundary %>%
                                   sf::st_buffer(., 1000) %>%
                                   sf::st_transform(., rast_crs)))

    site_boundary <- site_boundary %>%
        sf::st_transform(., rast_crs)

    site_boundary_buf <- terra::vect(site_boundary_buf)
    site_boundary <- terra::vect(site_boundary)

    rast_masked <- rast_file %>%
        terra::crop(site_boundary_buf)

    # For very small basins, cropping the raster can cause raster to be all NAs
    if(all(is.na(terra::values(rast_masked)[,1]))){
        rast_masked <- rast_file
    }

    # For every small basins that only intersect one raster cell, the extract
    # Funciton can report NAs
    if(length(terra::values(rast_masked)[,1]) == 1 && !is.na(terra::values(rast_masked)[,1])){

        weighted_results <- tibble(ID = 1,
                                   var = unname(terra::values(rast_masked)[,1]),
                                   weight = 1)

        names(weighted_results)[2] <-  names(terra::values(rast_masked)[,1])
    } else {
        weighted_results  <- terra::extract(rast_masked,
                                            site_boundary,
                                            weights = TRUE)
    }

    vals_w <- weighted_results %>%
        select(-ID) %>%
        rename(value = 1)

    ws_nas <- filter(vals_w, is.na(value))

    vals_w <- vals_w %>%
        filter(!is.na(value)) %>%
        mutate(new = value*weight)

    sd <- sd(vals_w$value)

    percent_na <- round((nrow(ws_nas)/(nrow(vals_w)+nrow(ws_nas)))*100, 2)

    val <- sum(vals_w$new)/sum(vals_w$weight)

    fin <- c(mean = val,
             sd = sd,
             pctCellErr = percent_na)

    return(fin)

}

ms_check_range <- function(d){

    if(! nrow(d)) return(d)

    d_vars <- unique(d$var)

    for(c in 1:length(d_vars)){

        var_p_frop <- drop_var_prefix(d_vars[c])

        min_val <- ms_vars %>%
            filter(variable_code == !!var_p_frop) %>%
            pull(val_min)

        if(length(min_val) == 0){
            min_val <- NA
        }
        if(! is.na(min_val)){
            d <- d %>%
                mutate(val = ifelse(var == !!d_vars[c] & as.numeric(val) < !!min_val, NA, val))
        }

        max_val <- ms_vars %>%
            filter(variable_code == !!var_p_frop) %>%
            pull(val_max)

        if(length(max_val) == 0){
            max_val <- NA
        }

        if(! is.na(max_val)){
            d <- d %>%
                mutate(val = ifelse(var == !!d_vars[c] & as.numeric(val) > !!max_val, NA, val))
        }
    }

    # d <- filter(d, ! is.na(val) | ms_status == 2)

    return(d)
}

download_from_googledrive <- function(set_details, network, domain){
    #WARNING: any modification of the following line,
    #or insertion of code lines before it, will break
    #retrieve_versionless_product()
    download_from_googledrive_function_indicator <- TRUE

    if('site_code' %in% names(set_details)) {
        sitechar <- set_details$site_code
    }

    prodname <- str_split_fixed(set_details$prodname_ms, '__', n = Inf)[1,1]
    raw_data_dest <- glue('data/{n}/{d}/raw/{p}/{s}',
                          n = network,
                          d = domain,
                          p = set_details$prodname_ms,
                          s = sitechar)

    id <- googledrive::as_id('1gugTmDybtMTbmKRq2WQvw2K1WkJjcmJr')
    gd_files <- googledrive::drive_ls(id, recursive = TRUE)

    network_id <- gd_files %>%
      filter(name == !!network)

    # choose the upper folder if domain == network
    if(domain == network) {
      files_options <- rbind(googledrive::drive_ls(googledrive::as_id(network_id[1,]$id)),
                             googledrive::drive_ls(googledrive::as_id(network_id[2,]$id)))
      network_files <- files_options[grepl(domain, files_options$name),]
      domain_files <- files_options[grepl('raw', files_options$name),]
    } else {
      network_files <- googledrive::drive_ls(googledrive::as_id(network_id$id))
      domain_id <- network_files %>%
          filter(name == !!domain)

      domain_files <- googledrive::drive_ls(googledrive::as_id(domain_id$id))
    }

    raw_files <- domain_files %>%
        filter(name == 'raw')

    raw_files <- googledrive::drive_ls(googledrive::as_id(raw_files$id))

    prod_folder <- raw_files %>%
        filter(name == !! set_details$prodname_ms)

    prod_files <- googledrive::drive_ls(googledrive::as_id(prod_folder$id))

    if(sitechar != 'sitename_NA') {

        site_files <- prod_files

        prod_folder <- site_files %>%
            filter(name == !!set_details$site_code)

        # most sites won't have ws_boundaries in gdrive
        if(nrow(prod_folder) == 0) {
            loginfo(glue('Nothing to do for {p}',
                     p = set_details$prodname_ms),
                logger = logger_module)
            return()
        }

        # but for those that do
        prod_files <- googledrive::drive_ls(googledrive::as_id(prod_folder$id))

    }

    dir.create(path = raw_data_dest,
               showWarnings = FALSE,
               recursive = TRUE)

    held_files <- list.files(raw_data_dest)

    drive_files <- prod_files$name

    if(any(!drive_files %in% held_files)) {

        loginfo(glue('Retrieving {p}',
                     p = set_details$prodname_ms),
                logger = logger_module)

        needed_files <- drive_files[! drive_files %in% held_files]

        prod_files_need <- prod_files %>%
            filter(name %in% needed_files)

        for(i in 1:nrow(prod_files_need)){

            raw_file_path <- glue('{rd}/{n}',
                                  rd = raw_data_dest,
                                  n = prod_files_need$name[i])

            status <- expo_backoff(
                expr = {
                    googledrive::drive_download(file = googledrive::as_id(prod_files_need$id[i]),
                                                path = raw_file_path,
                                                overwrite = TRUE)
                },
                max_attempts = 5
            )

        }
    } else{
        loginfo(glue('Nothing to do for {p}',
                     p = set_details$prodname_ms),
                logger = logger_module)
    }
}

download_from_gdrive_arbitrary <- function(network,
                                           domain,
                                           site_code,
                                           prodname_ms,
                                           level){

    #for getting any old file(s) from gdrive

    #There has to be a better way to do this, but drive_ls(recursive = T)
    #doesn't seem to work

    if(! level %in% c('raw', 'munged', 'derived')){
        stop('level must be one of "raw", "munged", "derived"')
    }

    loginfo(msg = glue('Downloading {n}-{d}-{s}-{p} from gdrive',
                       n = network,
                       d = domain,
                       s = site_code,
                       p = prodname_ms),
            logger = logger_module)

    ms_gdrive_url <- 'https://drive.google.com/drive/folders/178OOGxx1xM3C7m-Tdx6j5Dk_kxfWLJvw'

    tryCatch(
        {
            gdata <- googledrive::drive_ls(ms_gdrive_url)
            gdata_ntw_id <- pull(gdata[gdata$name == network, 'id'])
            gdata <- googledrive::drive_ls(googledrive::as_id(gdata_ntw_id))
            gdata_dmn_id <- pull(gdata[gdata$name == domain, 'id'])
            gdata <- googledrive::drive_ls(googledrive::as_id(gdata_dmn_id))
            gdata_der_id <- pull(gdata[gdata$name == 'derived', 'id'])
            gdata <- googledrive::drive_ls(googledrive::as_id(gdata_der_id))
            gdata_wsb_id <- pull(gdata[gdata$name == prodname_ms, 'id'])
            gdata <- googledrive::drive_ls(googledrive::as_id(gdata_wsb_id))
            gdata_sit_id <- pull(gdata[gdata$name == site_code, 'id'])
            gdata <- googledrive::drive_ls(googledrive::as_id(gdata_sit_id))
        },
        error = function(e){
            logerror(msg = 'Gdrive resource may not exist. Check arguments and visually inspect Gdrive',
                     logger = logger_module)
            stop()
        }
    )

    for(j in seq_len(nrow(gdata))){

        gdata_res_name <- pull(gdata[j, 'name'])
        gdata_res_id <- pull(gdata[j, 'id'])

        expo_backoff(
            expr = {
                googledrive::drive_download(
                    file = googledrive::as_id(gdata_res_id),
                    path = glue('data/{n}/{d}/derived/{wsb}/{s}/{f}',
                                n = network,
                                d = domain,
                                wsb = prodname_ms,
                                s = site_code,
                                f = gdata_res_name),
                    overwrite = TRUE)
            },
            max_attempts = 5
        ) %>% invisible()
    }
}

generate_watershed_summaries <- function(){

    join_if_exists <- function(x, d){

        prod_exists <- exists(x,
                              where = parent.frame(),
                              inherits = FALSE)
        if(prod_exists){
            d <- full_join(d, get(x),
                           by = 'site_code')
        } else {
            warning('could not locate product ', d, ' when generating watershed summaries')
        }

        return(d)
    }

    fils <- list.files('data',
                       recursive = TRUE,
                       full.names = TRUE)

    fils <- fils[grepl('ws_traits', fils)]

    wide_spat_data <- site_data %>%
        filter(site_type == 'stream_gauge',
               in_workflow == 1) %>%
        select(network, domain, site_code, ws_area_ha)

    # Prism precip
    precip_files <- fils[grepl('/cc_precip', fils)]
    precip_files <- precip_files[grepl('/sum_', precip_files)]

    precip <- map_dfr(precip_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'cc_cumulative_precip',
               val < 30000) %>%
        group_by(site_code) %>%
        summarize(cc_mean_annual_precip = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(cc_mean_annual_precip))

    # Prism temp
    temp_files <- fils[grepl('/cc_temp', fils)]
    temp_files <- temp_files[grepl('/sum_', temp_files)]

    temp <- map_dfr(temp_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'cc_temp_mean') %>%
        group_by(site_code) %>%
        summarize(cc_mean_annual_temp = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(cc_mean_annual_temp))

    # start of season
    sos_files <- fils[grepl('/start_season', fils)]

    sos <- map_dfr(sos_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vd_sos_mean') %>%
        group_by(site_code) %>%
        summarize(vd_mean_sos = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(vd_mean_sos))

    # end of season
    eos_files <- fils[grepl('/end_season', fils)]

    eos <- map_dfr(eos_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vd_eos_mean') %>%
        group_by(site_code) %>%
        summarize(vd_mean_eos = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(vd_mean_eos))

    # length of season
    los_files <- fils[grepl('/length_season', fils)]

    los <- map_dfr(los_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vd_los_mean') %>%
        group_by(site_code) %>%
        summarize(vd_mean_los = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(vd_mean_los))

    # maximum day of photosynthesis
    mos_files <- fils[grepl('/max_season', fils)]

    mos <- map_dfr(mos_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vd_mos_mean') %>%
        group_by(site_code) %>%
        summarize(vd_mean_mos = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(vd_mean_mos))

    # CONUS gpp
    gpp_files <- fils[grepl('/gpp_CONUS_30m', fils)]
    gpp_files <- gpp_files[grepl('/sum_', gpp_files)]

    gpp <- map_dfr(gpp_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'va_gpp_CONUS_30m_sum') %>%
        group_by(site_code) %>%
        summarize(va_mean_annual_gpp_CONUS_30m = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(!is.na(va_mean_annual_gpp_CONUS_30m))

    # CONUS npp
    npp_files <- fils[grepl('/npp_CONUS_250m', fils)]

    npp <- map_dfr(npp_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'va_npp_CONUS_250m_median') %>%
        group_by(site_code) %>%
        summarize(va_mean_annual_npp_CONUS_250m = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(! is.na(va_mean_annual_npp_CONUS_250m))

    # global gpp
    gpp_files_glob <- fils[grepl('/gpp_global_500m', fils)]
    gpp_files_glob <- gpp_files_glob[grepl('/sum_', gpp_files_glob)]

    gpp_glob <- map_dfr(gpp_files_glob, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vb_gpp_global_500m_median') %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_gpp_global_500m = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_gpp_global_500m))

    # global npp
    npp_files <- fils[grepl('/npp_global_500m', fils)]

    npp_glob <- map_dfr(npp_files, read_feather) %>%
        filter(year != substr(Sys.Date(), 0, 4),
               var == 'vb_npp_global_500m_median') %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_npp_global_500m = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_npp_global_500m))

    # terrain
    terrain_fils <- fils[grepl('/terrain', fils)]

    terrain <- map_dfr(terrain_fils, read_feather) %>%
        filter(var %in% c('te_elev_mean',
                          'te_elev_min',
                          'te_elev_max',
                          'te_aspect_mean',
                          'te_slope_mean')) %>%
        select(-year) %>%
        pivot_wider(names_from = 'var', values_from = 'val')

    # bfi
    bfi_fils <- fils[grepl('/bfi', fils)]

    bfi <- map_dfr(bfi_fils, read_feather) %>%
        filter(var %in% c('hd_bfi_mean')) %>%
        filter(pctCellErr <= 15) %>%
        select(-year, -pctCellErr) %>%
        pivot_wider(names_from = 'var', values_from = 'val')

    # nlcd
    nlcd_fils <- fils[grepl('/nlcd', fils)]

    nlcd <- map_dfr(nlcd_fils, read_feather) %>%
        filter(! grepl('1992', var)) %>%
        group_by(site_code) %>%
        mutate(max_year = max(year)) %>%
        filter(year == max_year) %>%
        ungroup() %>%
        select(-year, -max_year) %>%
        distinct(site_code, var, .keep_all = TRUE) %>%
        pivot_wider(names_from = 'var', values_from = 'val')

    if('lg_lncd_lichens' %in% colnames(nlcd)){
        colnames(nlcd)[colnames(nlcd) == 'lg_lncd_lichens'] = 'lg_nlcd_lichens'
        nlcd <- nlcd[, c('site_code', sort(setdiff(colnames(nlcd), 'site_code')))]
    }

    # soil
    soil_fils <- fils[grepl('/nrcs_soils', fils)]

    soil <- map_dfr(soil_fils, read_feather) %>%
        # filter(var %in% c('pf_soil_org',
        #                   'pf_soil_sand',
        #                   'pf_soil_silt',
        #                   'pf_soil_clay',
        #                   'pf_soil_ph')) %>%
        filter(pctCellErr <= 15) %>%
        select(-year, -pctCellErr) %>%
        pivot_wider(names_from = 'var', values_from = 'val')

    # soil thickness
    soil_thickness_fils <- fils[grepl('/pelletier_soil_thickness', fils)]

    soil_thickness <- map_dfr(soil_thickness_fils, read_feather) %>%
        filter(var %in% c('pi_soil_thickness')) %>%
        filter(pctCellErr <= 15) %>%
        select(-year, -pctCellErr) %>%
        pivot_wider(names_from = 'var', values_from = 'val') %>%
        mutate(pi_soil_thickness = round(pi_soil_thickness, 2))

    # et_ref
    et_ref_fils <- fils[grepl('/et_ref', fils)]
    et_ref_fils <- et_ref_fils[grepl('/sum_', et_ref_fils)]

    et_ref <- map_dfr(et_ref_fils, read_feather) %>%
        filter(var %in% c('ck_et_ref_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(ck_mean_annual_et = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        filter(! is.na(ck_mean_annual_et))

    # geological chem
    geochem_fils <- fils[grepl('/geochemical', fils)]

    geochem <- map_dfr(geochem_fils, read_feather) %>%
        filter(grepl('mean$', var),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val, na.rm = TRUE),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    # fpar
    ff <- fils[grepl('/fpar', fils) & grepl('/sum_', fils)]

    fpar <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('vb_fpar_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_fpar = mean(val),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_fpar))

    # lai
    ff <- fils[grepl('/lai', fils) & grepl('/sum_', fils)]

    lai <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('vb_lai_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_lai = mean(val),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_lai))

    # tcw (tesselated cap wetness)
    ff <- fils[grepl('/tcw', fils) & grepl('/sum_', fils)]

    tcw <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('vj_tcw_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(vj_mean_annual_tcw = mean(val),
                  .groups = 'drop') %>%
        filter(! is.na(vj_mean_annual_tcw))

    # ndvi
    ff <- fils[grepl('/ndvi', fils) & grepl('/sum_', fils)]

    ndvi <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('vb_ndvi_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_ndvi = mean(val),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_ndvi))

    # evi
    ff <- fils[grepl('/evi', fils) & grepl('/sum_', fils)]

    evi <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('vb_evi_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code) %>%
        summarize(vb_mean_annual_evi = mean(val),
                  .groups = 'drop') %>%
        filter(! is.na(vb_mean_annual_evi))

    # nsidc snow data
    ff <- fils[grepl('/nsidc', fils) & grepl('/sum_', fils)]

    nsidc <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('cl_snow_depth_ann_mean', 'cl_swe_ann_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    # lithology
    ff <- fils[grepl('/lithology', fils)]

    lithology <- map_dfr(ff, read_feather) %>%
        filter(grepl('geol_class', var),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    # glhymps soil porosity
    ff <- fils[grepl('/glhymps', fils)]

    glhymps <- map_dfr(ff, read_feather) %>%
        filter(var %in% c('pm_sub_surf_porosity_mean', 'pm_sub_surf_permeability_mean',
                          'pm_sub_surf_permeability_perm_mean'),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    # modis igbp
    ff <- fils[grepl('/modis_igbp', fils)]

    modis_igbp <- map_dfr(ff, read_feather) %>%
        filter(grepl('igbp', var),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    # modis GFCC
    tree_cover <- map_dfr(fils[grepl('/tree_cover', fils)], read_feather) %>%
        filter(grepl('_median', var),
               ! is.na(val)) %>%
        group_by(site_code, var) %>%
        summarize(vb_tree_cover_mean = mean(val),
                  .groups = 'drop') %>%
        select(-var)

    bare_cover <- map_dfr(fils[grepl('/bare_cover', fils)], read_feather) %>%
        filter(grepl('_median', var),
               ! is.na(val)) %>%
        group_by(site_code, var) %>%
        summarize(vb_bare_cover_mean = mean(val),
                  .groups = 'drop') %>%
        select(-var)

    veg_cover <- map_dfr(fils[grepl('/veg_cover', fils)], read_feather) %>%
        filter(grepl('_median', var),
               ! is.na(val)) %>%
        group_by(site_code, var) %>%
        summarize(vb_veg_cover_mean = mean(val),
                  .groups = 'drop') %>%
        select(-var)

    # nadp
    ff <- fils[grepl('/nadp', fils)]

    nadp <- map_dfr(ff, read_feather) %>%
        filter(grepl('_mean$', var),
               ! is.na(val)) %>%
        select(-year) %>%
        group_by(site_code, var) %>%
        summarize(mean_val = mean(val),
                  .groups = 'drop') %>%
        pivot_wider(names_from = 'var', values_from = 'mean_val')

    wide_spat_data <- join_if_exists('precip', wide_spat_data)
    wide_spat_data <- join_if_exists('temp', wide_spat_data)
    wide_spat_data <- join_if_exists('sos', wide_spat_data)
    wide_spat_data <- join_if_exists('eos', wide_spat_data)
    wide_spat_data <- join_if_exists('los', wide_spat_data)
    wide_spat_data <- join_if_exists('mos', wide_spat_data)
    wide_spat_data <- join_if_exists('gpp', wide_spat_data)
    wide_spat_data <- join_if_exists('npp', wide_spat_data)
    wide_spat_data <- join_if_exists('gpp_glob', wide_spat_data)
    wide_spat_data <- join_if_exists('npp_glob', wide_spat_data)
    wide_spat_data <- join_if_exists('terrain', wide_spat_data)
    wide_spat_data <- join_if_exists('bfi', wide_spat_data)
    wide_spat_data <- join_if_exists('nlcd', wide_spat_data)
    wide_spat_data <- join_if_exists('soil', wide_spat_data)
    wide_spat_data <- join_if_exists('soil_thickness', wide_spat_data)
    wide_spat_data <- join_if_exists('et_ref', wide_spat_data)
    wide_spat_data <- join_if_exists('geochem', wide_spat_data)

    wide_spat_data <- join_if_exists('fpar', wide_spat_data)
    wide_spat_data <- join_if_exists('lai', wide_spat_data)
    wide_spat_data <- join_if_exists('tcw', wide_spat_data)
    wide_spat_data <- join_if_exists('ndvi', wide_spat_data)
    wide_spat_data <- join_if_exists('evi', wide_spat_data)
    wide_spat_data <- join_if_exists('nsidc', wide_spat_data)
    wide_spat_data <- join_if_exists('glhymps', wide_spat_data)
    wide_spat_data <- join_if_exists('lithology', wide_spat_data)
    wide_spat_data <- join_if_exists('modis_igbp', wide_spat_data)
    wide_spat_data <- join_if_exists('tree_cover', wide_spat_data)
    wide_spat_data <- join_if_exists('veg_cover', wide_spat_data)
    wide_spat_data <- join_if_exists('bare_cover', wide_spat_data)
    wide_spat_data <- join_if_exists('nadp', wide_spat_data)

    dir.create('../portal/data/general/spatial_downloadables',
               recursive = TRUE,
               showWarnings = FALSE)

    write_csv(wide_spat_data,
              '../portal/data/general/spatial_downloadables/watershed_summaries.csv')
}

generate_watershed_raw_spatial_dataset <- function(){

    domains <- list.files('data/')
    domains <- domains[! grepl('general|spatial', domains)]

    ws_trait_folders  <- list.files('data',
                                    pattern = 'ws_traits',
                                    include.dirs = TRUE,
                                    recursive = TRUE)

    ws_trait_folders <- purrr::map(file.path('data', ws_trait_folders),
                                   ~list.files(.x)) %>%
        purrr::reduce(~unique(.x))

    all_files <- list.files('data',
                            recursive = TRUE,
                            full.names = TRUE)
    all_files <- grep('ws_traits/', all_files, value = TRUE)
    # all_files <- all_files[! grepl('general/|spatial/', all_files)]

    raw_spatial_dat <- tibble()
    for(i in 1:length(ws_trait_folders)){

        trait_files <- all_files[grepl(ws_trait_folders[i], all_files)]

        if(! length(trait_files)) next

        extention <- str_split_fixed(trait_files, '/', n = Inf)[, 6]
        check_sum_raw <- str_split_fixed(extention, '_', n = Inf)[, 1]
        sum_raw_prez <- unique(check_sum_raw)

        if((length(sum_raw_prez) == 1 && sum_raw_prez == 'sum') ||
           ! all(c('raw', 'sum') %in% sum_raw_prez)){

            all_trait <- map_dfr(trait_files, read_feather)

            if(all(c('datetime', 'year') %in% colnames(all_trait))){

                all_trait <- sw(all_trait %>%
                    mutate(datetime = case_when(
                        is.na(datetime) ~ ymd(paste(year, 1, 1, sep = '-')),
                        ! is.na(datetime) ~ datetime)) %>%
                    select(-year))

            } else if('year' %in% colnames(all_trait)){

                all_trait <- sw(all_trait %>%
                    mutate(datetime = ymd(paste(year, 1, 1, sep = '-'))) %>%
                    select(-year))

            } else NULL
        }

        if(all(c('raw', 'sum') %in% sum_raw_prez)){
            trait_files <- trait_files[grepl('raw', trait_files)]
            all_trait <- map_dfr(trait_files, read_feather)
        }

        raw_spatial_dat <- plyr::rbind.fill(raw_spatial_dat, all_trait)
    }

    site_doms <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        select(network, domain, site_code)

    raw_spatial_dat <- raw_spatial_dat %>%
        as_tibble() %>%
        filter(! is.na(val)) %>%
        left_join(site_doms,
                  by = 'site_code') %>%
        mutate(date = as.Date(datetime)) %>%
        select(network, domain, site_code, var, date, val,
               any_of('pctCellErr'))

    spat_variable <- unique(raw_spatial_dat$var)

    # universal_products_meta <- universal_products %>%
    #     select(data_class, data_source, data_class_code, data_source_code)
    #
    # meta_data <- variables %>%
    #     filter(variable_code %in% !!spat_variable) %>%
    #     select(variable_code, variable_name, unit,
    #            type = variable_type,
    #            subtype = variable_subtype) %>%
    #     mutate(data_class_code = substr(variable_code, 0, 1),
    #            data_source_code = substr(variable_code, 2, 2)) %>%
    #     left_join(universal_products_meta, by = c('data_class_code', 'data_source_code')) %>%
    #     select(-data_class_code, -data_source_code)

    wonky_varname_inds <- str_detect(string = spat_variable,
                                     pattern = '_$|__|_dian|^vb_n$')
    if(any(wonky_varname_inds)){

        wonky_varnames <- spat_variable[wonky_varname_inds]

        logwarn(glue('Wonky variable names still showing up in year.feather. ',
                     'These will be removed:\n\t{wvn}',
                     wvn = paste(wonky_varnames,
                                 collapse = ', '),
                     .trim = FALSE))

        raw_spatial_dat <- filter(raw_spatial_dat,
                                  ! var %in% wonky_varnames)
    }

    # raw_spatial_dat$var[raw_spatial_dat$var == 'cc_temp_mean_median'] <- 'cc_temp_median'
    # raw_spatial_dat$var[raw_spatial_dat$var == 'cc_temp_mean_sd'] <- 'cc_temp_sd'

    category_codes <- univ_products %>%
        select(variable_category_code = data_class_code,
               variable_category = data_class) %>%
        distinct() %>%
        arrange(variable_category_code)

    datasource_codes <- univ_products %>%
        select(data_source_code, data_source) %>%
        distinct() %>%
        arrange(data_source_code)

    # fst::write_fst(raw_spatial_dat,
    #                '../portal/data/general/spatial_downloadables/watershed_raw_spatial_timeseries.fst')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 'c') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_climate.csv')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 'h') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_hydrology.csv')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 'p') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_parentmaterial.csv')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 't') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_terrain.csv')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 'l') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_landcover.csv')
    raw_spatial_dat %>%
        filter(substr(var, 1, 1) == 'v') %>%
        write_csv('../portal/data/general/spatial_downloadables/spatial_timeseries_vegetation.csv')

    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_climate.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_climate.csv',
    #     flags = '-9Xjq')
    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_hydrology.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_hydrology.csv',
    #     flags = '-9Xjq')
    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_parentmaterial.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_parentmaterial.csv',
    #     flags = '-9Xjq')
    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_terrain.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_terrain.csv',
    #     flags = '-9Xjq')
    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_landcover.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_landcover.csv',
    #     flags = '-9Xjq')
    # zip(zipfile = '../portal/data/general/spatial_downloadables/spatial_timeseries_vegetation.csv.zip',
    #     files = '../portal/data/general/spatial_downloadables/spatial_timeseries_vegetation.csv',
    #     flags = '-9Xjq')
    #
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_climate.csv')
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_hydrology.csv')
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_parentmaterial.csv')
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_terrain.csv')
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_landcover.csv')
    # unlink('../portal/data/general/spatial_downloadables/spatial_timeseries_vegetation.csv')

    write_csv(category_codes,
              '../portal/data/general/spatial_downloadables/variable_category_codes.csv')
    write_csv(datasource_codes,
              '../portal/data/general/spatial_downloadables/data_source_codes.csv')
}

compute_yearly_summary <- function(filter_ms_interp = FALSE,
                                   filter_ms_status = FALSE){

    # this and compute_yearly_summary_ws should probably be combined at some point, but for now,
    # compute_yearly_summary_ws() appends compute_yearly_summary with ws_traits

    #does not affect published dataset, only portal data, so no worries about filter settings.

    #df = default sites for each domain
    df <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        group_by(network, domain) %>%
        summarize(site_code = first(site_code),
                  pretty_domain = first(pretty_domain),
                  pretty_network = first(pretty_network),
                  .groups = 'drop') %>%
        select(pretty_network, network, pretty_domain, domain,
               default_site = site_code)

    all_domain <- tibble()
    for(i in 1:nrow(df)){

        dom <- df$domain[i]
        net <- df$network[i]

        dom_path <- glue('../portal/data/{d}/',
                         d = dom)
        domain_files <- list.files(dom_path)

        #don't double-count when there's a custom version of a product
        custprods <- grep('CUSTOM', domain_files, value = TRUE)
        if(length(custprods)){
            for(cp in custprods){
                pname <- str_extract(cp, '(?<=CUSTOM).*')
                if(sum(grepl(pname, domain_files)) > 1){
                    domain_files <- domain_files[! domain_files == cp]
                }
            }
        }

        chem_prod <- grep('stream_chemistry', domain_files, value = TRUE)

        site_files <- list.files(glue(dom_path, chem_prod))
        sites <- str_split_fixed(site_files, pattern = '[.]', n = 2)[,1]

        stream_sites <- site_data %>%
            filter(domain == dom,
                   site_type == 'stream_gauge',
                   in_workflow == 1) %>%
            filter(site_code %in% sites) %>%
            pull(site_code)

        all_sites <- tibble()
        if(length(stream_sites) > 0){

            for(p in 1:length(stream_sites)){

                path_chem <- glue("../portal/data/{d}/{prod}/{s}.feather",
                                  d = dom,
                                  prod = grep('stream_chemistry', domain_files, value = T),
                                  s = stream_sites[p])

                path_q <- glue("../portal/data/{d}/{prod}/{s}.feather",
                               d = dom,
                               prod = grep('discharge', domain_files, value = T),
                               s = stream_sites[p])

                path_flux <- glue("../portal/data/{d}/{prod}/{s}.feather",
                                  d = dom,
                                  prod = grep('stream_flux_inst_scaled', domain_files, value = T),
                                  s = stream_sites[p])

                path_precip <- glue("../portal/data/{d}/{prod}/{s}.feather",
                                    d = dom,
                                    prod = grep('precipitation', domain_files, value = T),
                                    s = stream_sites[p])

                path_precip_chem <- glue("../portal/data/{d}/{prod}/{s}.feather",
                                         d = dom,
                                         prod = grep('precip_chemistry', domain_files, value = T),
                                         s = stream_sites[p])

                path_precip_flux <- glue("../portal/data/{d}/{prod}/{s}.feather",
                                         d = dom,
                                         prod = grep('precip_flux_inst_scaled', domain_files, value = T),
                                         s = stream_sites[p])

                #Stream discharge
                if(! file.exists(path_q) || length(path_q) == 0){
                    site_q <- tibble()
                    q_record_length <- 365
                } else {

                    site_q <- sm(read_feather(path_q)) %>%
                        mutate(Year = year(datetime),
                               Month = month(datetime),
                               Day = day(datetime)) %>%
                        filter(Year != year(Sys.Date()))

                    q_record_length <- detrmin_mean_record_length(site_q)

                    if(filter_ms_interp){
                        site_q <- site_q %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_q <- site_q %>%
                            filter(ms_status == 0)
                    }

                    if(nrow(site_q) == 0){
                        site_q <- tibble()
                        q_record_length <- 365
                    } else{

                        site_q <- site_q %>%
                            group_by(site_code, Year, Month, Day) %>%
                            summarise(val = mean(val, na.rm = T)) %>%
                            ungroup() %>%
                            mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                            mutate(val = val*86400) %>%
                            group_by(site_code, Date, Year) %>%
                            summarise(val = sum(val, na.rm = TRUE),
                                      count = n()) %>%
                            mutate(val = val/1000) %>%
                            mutate(missing = (q_record_length-count)/q_record_length) %>%
                            mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                            ungroup() %>%
                            select(-count) %>%
                            mutate(var = 'discharge') %>%
                            mutate(domain = dom)
                    }
                }

                all_sites <- rbind(all_sites, site_q)

                #Stream chemistry concentration
                if(! file.exists(path_chem) || length(path_flux) == 0) {
                    site_chem <- tibble()
                } else {

                    #first taking a monthly mean and then taking a yearly mean from monthly
                    #mean. This is to try to limit sampling bias, where 100 samples are taken
                    #in the summer but only a few in the winter

                    site_chem <- sm(read_feather(path_chem) %>%
                                        mutate(Year = year(datetime),
                                               Month = month(datetime),
                                               Day = day(datetime)) %>%
                                        select(-datetime)) %>%
                        mutate(var = drop_var_prefix(var)) %>%
                        filter(Year != year(Sys.Date()))

                    if(filter_ms_interp){
                        site_chem <- site_chem %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_chem <- site_chem %>%
                            filter(ms_status == 0)
                    }

                    site_chem <- site_chem %>%
                        group_by(site_code, Year, Month, Day, var) %>%
                        summarise(val = mean(val, na.rm = TRUE)) %>%
                        ungroup() %>%
                        mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                        select(-Month) %>%
                        group_by(site_code, Date, Year, var) %>%
                        summarise(val = mean(val, na.rm = TRUE),
                                  count = n()) %>%
                        ungroup() %>%
                        mutate(missing = (q_record_length-count)/q_record_length) %>%
                        mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                        select(-count) %>%
                        mutate(var = glue('{v}_conc', v = var)) %>%
                        mutate(domain = dom)
                }

                all_sites <- rbind(all_sites, site_chem)

                #Stream chemistry flux
                if(! file.exists(path_flux) || length(path_flux) == 0) {
                    site_flux <- tibble()
                } else {

                    site_flux <- read_feather(path_flux)  %>%
                        mutate(Year = year(datetime),
                               Month = month(datetime),
                               Day = day(datetime)) %>%
                        select(-datetime) %>%
                        mutate(var = drop_var_prefix(var)) %>%
                        filter(Year != year(Sys.Date()))

                    if(filter_ms_interp){
                        site_flux <- site_flux %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_flux <- site_flux %>%
                            filter(ms_status == 0)
                    }

                    site_flux <- site_flux %>%
                        group_by(site_code, Year, Month, Day, var) %>%
                        summarise(val = mean(val, na.rm = T)) %>%
                        ungroup() %>%
                        group_by(site_code, Year, var) %>%
                        mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                        ungroup() %>%
                        group_by(site_code, Date, Year, var) %>%
                        summarise(val = sum(val, na.rm = TRUE),
                                  count = n()) %>%
                        ungroup() %>%
                        mutate(missing = (q_record_length-count)/q_record_length) %>%
                        mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                        select(-count) %>%
                        mutate(var = glue('{v}_flux', v = var)) %>%
                        mutate(domain = dom)

                    site_flux[is.numeric(site_flux) & site_flux <= 0.00000001] <- NA
                }

                all_sites <- rbind(all_sites, site_flux)

                #Precipitation
                if(! file.exists(path_precip) || length(path_precip) == 0){
                    site_precip <- tibble()
                } else {

                    site_precip <- sm(read_feather(path_precip)) %>%
                        mutate(Year = year(datetime),
                               Month = month(datetime),
                               Day = day(datetime)) %>%
                        filter(Year != year(Sys.Date()))

                    if(filter_ms_interp){
                        site_precip <- site_precip %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_precip <- site_precip %>%
                            filter(ms_status == 0)
                    }

                    site_precip <- site_precip %>%
                        group_by(site_code, Year, Month, Day) %>%
                        summarise(val = sum(val, na.rm = T)) %>%
                        ungroup() %>%
                        mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                        group_by(site_code, Date, Year) %>%
                        summarise(val = sum(val, na.rm = TRUE),
                                  count = n()) %>%
                        ungroup() %>%
                        mutate(missing = (365-count)/365) %>%
                        mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                        select(-count) %>%
                        mutate(var = 'precip') %>%
                        mutate(domain = dom)
                }

                all_sites <- rbind(all_sites, site_precip)

                #Precipitation chemistry concentration
                if(! file.exists(path_precip_chem) || length(path_precip_chem) == 0){
                    site_precip_chem <- tibble()
                } else {

                    site_precip_chem <- sm(read_feather(path_precip_chem) %>%
                                               mutate(Year = year(datetime),
                                                      Month = month(datetime),
                                                      Day = day(datetime)) %>%
                                               select(-datetime)) %>%
                        mutate(var = drop_var_prefix(var)) %>%
                        filter(Year != year(Sys.Date()))

                    if(filter_ms_interp){
                        site_precip_chem <- site_precip_chem %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_precip_chem <- site_precip_chem %>%
                            filter(ms_status == 0)
                    }

                    site_precip_chem <- site_precip_chem %>%
                        group_by(site_code, Year, Month, Day, var) %>%
                        summarise(val = mean(val, na.rm = TRUE)) %>%
                        ungroup() %>%
                        mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                        select(-Month) %>%
                        group_by(site_code, Date, Year, var) %>%
                        summarise(val = mean(val, na.rm = TRUE),
                                  count = n()) %>%
                        ungroup() %>%
                        mutate(missing = (356-count) / 365) %>%
                        mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                        select(-count) %>%
                        mutate(var = glue('{v}_precip_conc', v = var)) %>%
                        mutate(domain = dom)
                }

                all_sites <- rbind(all_sites, site_precip_chem)

                #Precipitation chemistry flux
                if(! any(file.exists(path_precip_flux)) || length(path_precip_flux) == 0){
                    site_precip_flux <- tibble()
                } else {

                    if(length(path_precip_flux) > 1){
                        path_precip_flux <- path_precip_flux[! grepl('CUSTOM', path_precip_flux)]
                    }

                    site_precip_flux <- read_feather(path_precip_flux)  %>%
                        mutate(Year = year(datetime),
                               Month = month(datetime),
                               Day = day(datetime)) %>%
                        select(-datetime) %>%
                        mutate(var = drop_var_prefix(var)) %>%
                        filter(Year != year(Sys.Date()))

                    if(filter_ms_interp){
                        site_precip_flux <- site_precip_flux %>%
                            filter(ms_interp == 0)
                    }
                    if(filter_ms_status){
                        site_precip_flux <- site_precip_flux %>%
                            filter(ms_status == 0)
                    }

                    site_precip_flux <- site_precip_flux %>%
                        group_by(site_code, Year, Month, Day, var) %>%
                        summarise(val = mean(val, na.rm = T)) %>%
                        ungroup() %>%
                        group_by(site_code, Year, var) %>%
                        mutate(Date = ymd(paste(Year, 1, 1, sep = '-'))) %>%
                        ungroup() %>%
                        group_by(site_code, Date, Year, var) %>%
                        summarise(val = sum(val, na.rm = TRUE),
                                  count = n()) %>%
                        ungroup() %>%
                        mutate(missing = (356-count)/365) %>%
                        mutate(missing = ifelse(missing < 0, 0, missing)) %>%
                        mutate(var = glue('{v}_precip_flux', v = var)) %>%
                        mutate(domain = dom) %>%
                        select(-count)

                    site_precip_flux[is.numeric(site_precip_flux) & site_precip_flux <= 0.00000001] <- NA
                }

                all_sites <- rbind(all_sites, site_precip_flux)
            }
        }

        all_domain <-  rbind.fill(all_domain, all_sites)
    }

    all_domain <- all_domain %>%
        mutate(missing = missing * 100) %>%
        mutate(missing = as.numeric(substr(missing, 1, 2))) %>%
        mutate(val = round(val, 4))

    dir.create('../portal/data/general/biplot',
               showWarnings = FALSE)

    # if(! filter_ms_interp && ! filter_ms_status){
    write_feather(all_domain, '../portal/data/general/biplot/year.feather')
    # }
}

compute_yearly_summary_ws <- function(){

    df <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        group_by(network, domain) %>%
        summarize(site_code = first(site_code),
                  pretty_domain = first(pretty_domain),
                  pretty_network = first(pretty_network),
                  .groups = 'drop') %>%
        select(pretty_network, network, pretty_domain, domain,
               default_site = site_code)

    all_domain <- tibble()
    for(i in 1:nrow(df)){

        dom <- df$domain[i]
        net <- df$network[i]

        dom_path <- glue('data/{net}/{dom}/ws_traits')
        prod_files <- list.files(dom_path,
                                 full.names = TRUE,
                                 recursive = TRUE)

        prod_files <- prod_files[! grepl('raw_', prod_files)]
        # TODO: REMOVE IF WE ADD DAYMET TO NORMAL PRODUCTS
        prod_files <- prod_files[! grepl('daymet', prod_files)]

        all_prods <- tibble()
        if(length(prod_files) > 0){
            for(p in 1:length(prod_files)){

                prod_tib <- read_feather(prod_files[p])
                prod_names <- names(prod_tib)

                if(! 'pctCellErr' %in% prod_names){
                    prod_tib <- mutate(prod_tib, pctCellErr = NA)
                }

                all_prods <- rbind(all_prods, prod_tib)
            }

            all_prods <- sw(all_prods %>%
                mutate(Date = ymd(paste0(year, '-01', '-01'))) %>%
                mutate(domain = dom) %>%
                rename(Year = year))

            all_domain <- rbind(all_domain, all_prods)
        }
    }

    # Remove standard deviation
    all_ws_vars <- unique(all_domain$var)
    ws_vars_keep <- all_ws_vars[! grepl('sd', all_ws_vars)]
    ws_vars_keep <- ws_vars_keep[! grepl('1992', ws_vars_keep)]

    all_domain <- all_domain %>%
        filter(var %in% !!ws_vars_keep)

    summary_file_paths <- grep('year',
                               list.files('../portal/data/general/biplot',
                                          full.names = TRUE),
                               value = TRUE)

    for(s in 1:length(summary_file_paths)){

        conc_sum <- read_feather(summary_file_paths[s]) %>%
            mutate(pctCellErr = NA)

        all_domain <- all_domain %>%
            mutate(missing = 0)

        final <- rbind(conc_sum, all_domain)

        areas <- site_data %>%
            filter(site_type == 'stream_gauge',
                   in_workflow == 1) %>%
            select(site_code, domain, val = ws_area_ha) %>%
            mutate(Date = NA,
                   Year = NA,
                   var = 'area') %>%
            filter(!is.na(val)) %>%
            mutate(missing = 0) %>%
            mutate(pctCellErr = NA)

        #calc area normalized q
        area_q <- areas %>%
            select(site_code, domain, area = val) %>%
            full_join(., conc_sum, by = c('site_code', 'domain')) %>%
            mutate(discharge_a = ifelse(var == 'discharge', val / (area * 10000), NA)) %>%
            mutate(discharge_a = discharge_a * 1000) %>%
            filter(!is.na(discharge_a)) %>%
            mutate(var = 'discharge_a') %>%
            select(-val, -area) %>%
            rename(val = discharge_a)

        final <- rbind(final, areas, area_q) %>%
            filter(Year < year(Sys.Date()) | is.na(Year))

        write_feather(final, summary_file_paths[s])
    }
}

append_unprod_prefix <- function(d, prodname_ms){

    prodname_ms <- str_split_fixed(prodname_ms, '__', n = 2)[1,]
    prodname <- prodname_ms[1]
    prodcode <- prodname_ms[2]

    this_product <- univ_products %>%
        filter(prodname == !!prodname & prodcode == !!prodcode)

    data_class <- this_product %>%
        pull(data_class_code)

    data_source <- this_product %>%
        pull(data_source_code)

    d <- d %>%
        mutate(var = paste0(data_class, data_source, '_', var))


    return(d)
}

save_general_files <- function(final_file, raw_file, domain_dir){

    dir.create(domain_dir, recursive = TRUE, showWarnings = FALSE)

    raw_exists <- ! missing(raw_file)
    sites <- unique(final_file$site_code)
    for(s in 1:length(sites)){

        final_file_site <- filter(final_file, site_code == !!sites[s])

        sum_path <- file.path(domain_dir,
                              glue('sum_{sites[s]}.feather'))

        write_feather(final_file_site, sum_path)

        if(raw_exists){
            raw_file_site <- filter(raw_file, site_code == !!sites[s])

            raw_path <- file.path(domain_dir,
                                  glue('raw_{sites[s]}.feather'))

            write_feather(raw_file_site, raw_path)
        }
    }
}

run_prechecks <- function(){

    #dump routines here for checking integrity of config files, etc. Basically,
    #this should identify common issues (like duplicated variables in ms_vars)
    #that should be corrected before any processing happens.
    #this runs before the main loop in acquisition_master.R.

    dupe_siterows <- site_data %>%
        select(network, domain, site_code, site_type) %>%
        filter(duplicated(.))

    if(any(dupe_siterows)){
        stop(glue('duplicated site(s) in site_data:\n{ds}',
                  ds = paste(dupe_siterows$site_code,
                             collapse = ', ')))
        #GSMACK, N01B, N02B have dupe site_codes, but for different site_types
    }

    dupe_vars <- ms_vars %>%
        filter(duplicated(.$variable_code))

    if(nrow(dupe_vars)){
        stop(glue('duplicated variable(s) in ms_vars:\n{dv}',
                  dv = paste(dupe_vars$variable_code,
                             collapse = ', ')))
    }

    if(any(domain_detection_limits$precision == 0)){
        stop('precisions of 0 detected in domain_detection_limits')
    }
}

run_postchecks <- function(){

    warning('some of these checks will probably fail on Windows. MacOS might be okay. if they fail, use GPT to convert `system` calls to list.dirs() etc')

    require_shell_tool('find')

    domains_without_stream_gauge_locs <- system('find data/ -type d -name "derived" -exec sh -c \'find "$1" -maxdepth 1 -type d -name "stream_gauge_locations*" | grep -q . || echo "$1"\' _ {} \\; | cut -d/ -f 3',
                                                intern = TRUE)
    if(length(domains_without_stream_gauge_locs)){
        message('these domains do not have a stream_gauge_locations product in their derive folder:\n\t',
                paste(domains_without_stream_gauge_locs, collapse = ', '))
    }

    #look for neon duplicate records
    neon_dupe_check <- read_feather('data/neon/neon/derived/discharge__ms002/SYCA.feather',
                                    columns = 'site_code') %>% distinct()
    if(nrow(neon_dupe_check) > 1) stop('raw NEON Q for site SYCA contains COMO data. same with FLNT and MCDI. This is resolved in the munge kernel, but has not propagated')

    #look for derelict "year" column in some Q files
    q_files <- system("find data/ -path '*/derived/discharge*.feather'", intern = TRUE)
    for(f in q_files){
        read_result <- try(read_feather(f, columns = 'year'), silent = TRUE)
        if(! inherits(read_result, 'try-error')) stop('some Q files still have a "year" column! e.g. ', f)
    }

    check_product_existence()
    check_for_empty_derive_folders()
    check_that_ws_areas_match()
    check_for_GS_precipitation()
    check_for_dupes()
    mark_superfluous_files()
    check_for_PQ_imbalance()
    remove_some_molecular_forms()
    check_for_missing_ws_traits()
    check_for_derelict_ws_traits()
    check_for_Inf_NaN_traits()
}

check_for_Inf_NaN_traits <- function(){

    print('correcting Inf and NaN where they appear in ws_traits')
    require_shell_tool('find')

    ff <- system('find data -type f -path "*/ws_traits/*.feather"',
                 intern = TRUE)

    infs_detected <- nans_detected <- c()
    for(i in 1:length(ff)){

        f <- ff[i]
        xx <- read_feather(f)
        if('val' %in% colnames(xx)){

            rewrite_f <- FALSE
            if(any(is.infinite(xx$val))){
                infs_detected <- c(infs_detected, f)
                xx$val[is.infinite(xx$val)] <- NA
                rewrite_f <- TRUE
            }

            if(any(is.nan(xx$val))){
                nans_detected <- c(nans_detected, f)
                xx$val[is.na(xx$val)] <- NA
                rewrite_f <- TRUE
            }

            if(rewrite_f){
                write_feather(xx, f)
            }
        }
    }

    cat('the following files had Inf values. these have been corrected, but maybe fix upstream:\n',
        paste(infs_detected, collapse = '\n'))
    cat('\nthe following files had NaN values. these have been corrected, but maybe fix upstream:\n',
        paste(nans_detected, collapse = '\n'))
}

check_for_derelict_ws_traits <- function(){

    print('checking for derelict ws_traits feathers')
    require_shell_tool('find')

    attr_files <- system("find data/ -path '*/ws_traits/*.feather'", intern=T)
    attr_files <- grep('domain_climate', attr_files, value = TRUE, invert = TRUE)

    found_sites <- str_extract(attr_files, '([^/]+)\\.feather', group = 1) %>%
        str_replace('(?:sum|raw)_', '')

    forreals_sites = site_data %>%
        filter(in_workflow == 1,
               site_type == 'stream_gauge') %>%
        pull(site_code)

    to_delete <- attr_files[! found_sites %in% forreals_sites]
    if(length(to_delete)){

        print(to_delete)

        resp <- get_response_1char('Derelict ws_attrs files discovered. Okay to delete these? (Y/n)',
                                   possible_chars = c('Y', 'n'))

        if(resp == 'Y'){
            invisible(file.remove(to_delete))
            cat(paste('deleted', length(to_delete), 'files'), '\n')
        } else {
            cat('not deleting. be warned that the sites associated with these files are not in site_data!\n')
        }
    } else {
        cat('Nothing to do\n')
    }
}

check_for_missing_ws_traits <- function(){

    print('checking for missing/empty/partial ws_traits dirs')
    require_shell_tool('find')

    print('empties (some should be, e.g. nlcd outside N.Am or nsidc outside CONUS):')
    system("find . -type d -path '*/ws_traits/*' -empty")

    all_ws_traits <- c(
        'bare_cover', 'bfi', 'cc_precip', 'cc_temp', 'daymet', 'end_season',
        'et_ref', 'fpar', 'geochemical', 'glhymps', 'gpp_CONUS_30m', 'lai', 'length_season',
        'lithology', 'max_season', 'modis_igbp', 'nadp', 'ndvi', 'nlcd',
        'npp_CONUS_250m', 'nrcs_soils', 'nsidc', 'pelletier_soil_thickness', 'start_season',
        'tcw', 'terrain', 'tree_cover', 'veg_cover', 'npp_global_500m',
        'gpp_global_500m', 'evi'
    )

    cat('missing:\n')
    missings <- c()
    for(wt in all_ws_traits){

        missings_ <- system(glue("find . -type d -name \"ws_traits\" -exec sh -c 'test -d \"$1/[wt]\" || echo \"$1\"' _ {} \\;",
                                .open = '[', .close = ']'),
                           intern = TRUE)

        if(! length(missings_)){
            missings <- c(missings, paste('Got', wt))
        } else {
            missings <- c(missings, file.path(missings_,
                                              wt))
        }
    }

    cat(paste(missings, collapse = '\n'), '\n')

    # ##

    cat('looking for partial ws_trait files\n')

    ff <- system('find data -path "*/ws_traits/*.feather"', intern = TRUE)
    traits <- unique(str_extract(ff, 'data/[^/]+/[^/]+/ws_traits/([^/]+)', group = 1))
    res <- tibble(starts = Date(), ends = Date())
    for(trt in traits){

        trt_files <- str_subset(ff, glue('/{trt}/'))
        for(f in trt_files){

            sit <- str_extract(f, 'data/[^/]+/[^/]+/ws_traits/[^/]+/(.+)(?=\\.feather)', group = 1)
            dmn <- str_extract(f, 'data/[^/]+/([^/]+)/ws_traits/', group = 1)
            d <- read_feather(f)

            timecol <- d %>%
                filter(if_any(any_of(c('val', 'dayl')), ~! is.na(.))) %>%
                rename_with(~sub('year|date|datetime', 'timecol', .)) %>%
                pull(timecol)

            ex <- timecol[1]
            if(! is.na(ex) && nchar(ex) == 4){
                timecol <- as.Date(paste0(timecol, '-01-01'))
            } else {
                timecol <- as.Date(timecol)
            }

            res <- bind_rows(res,
                             tibble(domain = dmn,
                                    site_code = sit,
                                    trait = trt,
                                    starts = min(timecol),
                                    ends = max(timecol),
                                    lengths = as.numeric(diff(range(timecol)))))
        }
    }

    trait_lengths <- res %>%
        group_by(trait) %>%
        filter(! all(is.na(starts)),
               # ! all(lengths == max(lengths)))
               ! all(lengths > max(lengths) * 0.9))

    if(nrow(trait_lengths)){

        trait_lengths <<- trait_lengths %>%
            # filter(lengths != max(lengths)) %>%
            filter(lengths <= max(lengths) * 0.9) %>%
            ungroup() %>%
            group_by(domain, trait, lengths) %>%
            mutate(tempsite = sub('raw_|sum_', '', site_code)) %>%
            filter(! setequal(tempsite, c('CARI', 'CUPE', 'OKSR', 'GUIL'))) %>%
            filter(! setequal(tempsite, c('CARI', 'OKSR'))) %>%
            filter(! setequal(tempsite, c('CUPE', 'GUIL'))) %>%
            ungroup() %>%
            group_by(domain, trait, lengths) %>%
            summarize(n = n(),
                      sites = paste(site_code, collapse = ', '),
                      .groups = 'drop') %>%
            arrange(trait, domain, n) %>%
            mutate(sumf = str_detect(sites, '(?:^| )sum_'),
                   rawf = str_detect(sites, '(?:^| )raw_'),
                   sites = gsub('sum_|raw_', '', sites)) %>%
            select(trait, domain, lengths, n, sites, sumf, rawf)
    }

    # tl = trait_lengths
    # filter(tl, sumf, !rawf) %>% arrange(lengths) %>% print(n=1000)
    # filter(res, trait == 'tcw') %>% filter(domain == 'east_river') %>% arrange(lengths) %>% print(n=100)
    # filter(tl, trait == 'nlcd') %>% arrange(lengths) %>% print(n=100)

    # write_csv(trait_lengths, 'scratch/ws_traits_partials.csv')

    if(nrow(trait_lengths)){
        cat('partial ws_trait files detected. summary in trait_lengths (global). these may need to be rerun/debugged:\n')
        print(arrange(trait_lengths, lengths), n = 100)
    }

    ## check for incorrect number of ws_traits folders

    req_tools <- c('bash', 'sed', 'echo', 'wc', 'tr', 'ls', 'sort')
    invisible(sapply(req_tools, function(x) require_shell_tool(x)))
    cat('verify number of folders under ws_traits for each domain (hbef and suef missing nrcs soils as of 2024)\n')
    system("find . -type d -name ws_traits -exec bash -c 'ls \"$1\" | wc -l | tr -d \"\n\"; echo -n \" \"; echo \"$1\" | sed \"s|^\\./||\"' _ {} \\; | sort")
}

check_product_existence <- function(){

    print('checking for the existence of products that are defined in products.csv files')
    require_shell_tool('find')

    prods_csvs <- system('find src/ -type f -name "products.csv"',
                         intern = TRUE)

    domains_included <- site_data %>%
        filter(in_workflow == 1) %>%
        pull(domain) %>%
        unique()

    prods_csvs <- Filter(function(x){
        str_extract(x, '([^/]+)/products.csv$', group = 1) %in% domains_included
    }, prods_csvs)

    prods_that_should_exist <- c()
    for(pc in prods_csvs){
        prods_that_should_exist <- read_csv(pc, show_col_types = FALSE) %>%
            filter(derive_status %in% c('ready', 'linked') |
                       notes == 'automated entry') %>%
            mutate(prodname_ms = paste(prodname, prodcode, sep = '__')) %>%
            pull(prodname_ms) %>%
            {file.path(pc, .)} %>%
            str_replace('^src', 'data') %>%
            str_replace('products\\.csv', 'derived') %>%
            c(., prods_that_should_exist)
    }

    prods_that_do_exist <- system('find data/ -maxdepth 4 -type d -path "*/derived/*" ! -name "documentation"',
                                  intern = TRUE)

    maybe_missing <- setdiff(prods_that_should_exist, prods_that_do_exist)
    pkernels <- grep('precip_pchem_pflux', maybe_missing, value = TRUE)
    non_pkernels <- grep('precip_pchem_pflux', maybe_missing, value = TRUE, invert = TRUE)

    if(length(non_pkernels)){
        warning('missing products:\n\t', paste(non_pkernels, collapse = '\n\t'))
    }

    unaccounted_for <- setdiff(prods_that_do_exist, prods_that_should_exist)
    unaccounted_for <- grep('_scaled__', unaccounted_for, value = TRUE, invert = TRUE)

    if(length(unaccounted_for)) stop('following section not yet complete')
    def_missing <- c()
    for(pk in pkernels){
        srch <- str_replace(pk, 'precip_pchem_pflux__ms...', 'precip')
        matched <- grep(srch, unaccounted_for, value = TRUE)
        if(! length(matched)) def_missing <- c(def_missing, pk)
        unaccounted_for <- setdiff(unaccounted_for, matched)
    }
}

check_for_empty_derive_folders <- function(){

    print('looking for empty derived folders')
    require_shell_tool('find')

    empties <- system("find data -type d -path '*/derived/*' -empty", intern = TRUE)
    if(length(empties)){
        warning('these derived directories are empty:\n\t',
                paste(empties, collapse = '\n\t'))
    }
}

check_that_ws_areas_match <- function(){

    print('looking for ws_area discrepancies between site_data and ws_boundary shapefiles')
    require_shell_tool('find')

    ws_bnds <- system("find data -type f -path '*/derived/ws_bound*.shp'", intern = TRUE)

    discreps <- c()
    for(wb in ws_bnds){
        d <- sf::st_read(wb, quiet = TRUE)
        if(nrow(d) != 1) warning('expected one row in ', wb, '. got ', nrow(d))
        site_code <- d$site_code
        dmn <- str_split_fixed(wb, '/', n = 4)[, 3]
        area <- round(d$area, 3)

        siterow <- filter(site_data,
                          site_code == !!site_code,
                          site_type == 'stream_gauge',
                          in_workflow == 1)

        if(nrow(siterow) != 1) warning('expected one row in siterow. got ', nrow(d))

        area2 <- round(siterow$ws_area_ha, 3)
        if(area != area2){
            discreps <- c(discreps, paste0(dmn, '-', site_code, ': ', area,
                                           ' (shp); ', area2, ' (site_data)'))
        }
    }

    if(length(discreps)){
        options(warning.length = 8170)
        warning('areas differ for:\n\t',
                paste(discreps, collapse = '\n\t'),
                '.\n   For any large discrepancies, ms_general needs to be rerun.')
        options(warning.length = 1000)
    }
}

check_for_GS_precipitation <- function(){

    print('looking for questionable sampling regimes')
    require_shell_tool('find')

    prcp <- system("find data -type f -path '*/derived/precipitation*.feather'", intern = TRUE)
    problems <- c()
    for(pc in prcp){

        prefixes <- read_feather(pc, columns = 'var') %>%
            pull() %>%
            unique() %>%
            extract_var_prefix()

        if(any(prefixes != 'IS')){
            unexpected <- grep('IS', prefixes, invert = TRUE, value = TRUE)
            dmn_sit <- str_match(pc, 'data/[^/]+/([^/]+)/derived/precipitation__ms.../(.+?)\\.feather$')[, 2:3]
            problems <- c(problems, paste0(dmn_sit[1], '-', dmn_sit[2], ': ',
                                           paste(unexpected, collapse = ', ')))
        }
    }

    if(length(problems)){
        warning('unexpected sampling regimes encountered (IN and GN might be okay, but not GS):\n\t',
                paste(problems, collapse = '\n\t'))
    }
}

check_for_dupes <- function(){

    print('looking for duplicated records')
    require_shell_tool('find')

    ff <- system("find data -type f -path '*/derived/*.feather'", intern = TRUE)
    fflen <- length(ff)
    for(i in seq_along(ff)){

        f <- ff[i]
        if(i %% 100 == 0) print(glue('{i}/{fflen} files checked'))

        ostensible_sitecode <- str_extract(f, '([^/]+?)\\.feather', group = 1)

        dd <- read_feather(f, columns = c('datetime', 'site_code', 'var'))
        sites_d <- unique(dd$site_code)
        if(any(sites_d != ostensible_sitecode)){
            message(sites_d[sites_d != ostensible_sitecode], ' encountered in wrong file: ', f)
        }
        dd <- duplicated(dd)

        if(any(dd)){
            # browser()
            # zz = read_feather(f, columns = c('datetime', 'site_code', 'var'))
            # zzz = read_feather(f)
            # d2 = zzz[duplicated(zz) | duplicated(zz, fromLast = T),] %>% arrange(datetime)
            warning('duplicate record detected in ', f)
        }
    }

    fp = grep('discharge|precipitation', ff, value=T)
    # fp = grep('walker_branch', fp, value=T)
    fplen <- length(fp)
    for(i in seq_along(fp)){

        f <- fp[i]
        if(i %% 100 == 0) print(glue('{i}/{fplen} files checked'))

        dd <- read_feather(f, columns = c('datetime', 'site_code')) %>%
            duplicated()

        if(any(dd)){
            warning('duplicate record detected in ', f, ' when "var" column is ignored. This means there are multiple sampling regimes for the same date')
        }
    }
}

check_for_PQ_imbalance <- function(){

    print('Checking precipitation-discharge balance')
    require_shell_tool('find')

    qq <- system("find data -type f -path '*/derived/discharge*.feather'", intern = TRUE)
    pp <- system("find data -type f -path '*/derived/precipitation*.feather'", intern = TRUE)

    qp_sites <- inner_join(
        mutate(tibble(q = qq), nm = basename(q)),
        mutate(tibble(p = pp), nm = basename(p)),
        by = 'nm'
    )

    results <- tibble()
    for(i in seq_len(nrow(qp_sites))){
    # for(i in which(grepl('niwot', qp_sites$q))){

        ntw <- str_extract(qp_sites$q[i], 'data/([^/]+)', group = 1)
        dmn <- str_extract(qp_sites$q[i], 'data/[^/]+/([^/]+)', group = 1)
        site <- str_extract(qp_sites$nm[i], '.+(?=\\.feather$)')

        area <- site_data %>%
            filter(domain == dmn,
                   site_code == site,
                   in_workflow == 1,
                   site_type == 'stream_gauge') %>%
            pull(ws_area_ha)

        Q <- read_feather(qp_sites$q[i], columns = c('datetime', 'val'))
        P <- read_feather(qp_sites$p[i], columns = c('datetime', 'val'))
        prism_P <- try({
            read_feather(glue('data/{ntw}/{dmn}/ws_traits/cc_precip/sum_{site}.feather')) %>%
                filter(var == 'cc_cumulative_precip') %>%
                select(year, prism = val)
        }, silent = TRUE)
        if(inherits(prism_P, 'try-error')){
            prism_P <- tibble(year = numeric(), prism = numeric())
        }

        #join P and Q
        pq <- Q %>%
            full_join(P,
                      by = 'datetime',
                      suffix = c('.q', '.p')) %>%
            arrange(datetime)

        #drop leading/trailing incomplete records; make NAs explicit
        first_complete_row <- max(Position(function(x) ! is.na(x), pq$val.q),
                                  Position(function(x) ! is.na(x), pq$val.p))
        last_complete_row <- min(Position(function(x) ! is.na(x), pq$val.q,
                                          right = TRUE),
                                 Position(function(x) ! is.na(x), pq$val.p,
                                          right = TRUE))

        pq <- pq %>%
            slice(first_complete_row:last_complete_row) %>%
            tidyr::complete(datetime = seq(min(datetime),
                                           max(datetime),
                                           by = 'day')) %>%
            mutate(year = year(datetime))

        #impute gaps up to 10 days
        try({
            pq <- pq %>%
                mutate(val.q = na_interpolation(val.q, maxgap = 10),
                       val.p = na_replace(val.p, 0, maxgap = 10))
        }, silent = TRUE)

        #drop years with more than 90% missing data in either P or Q column
        #NOTE: this may increase discrepancy between p and prism_P
        na_props <- pq %>%
            group_by(year) %>%
            summarize(na_prop_q = sum(is.na(val.q)) / n(),
                      na_prop_p = sum(is.na(val.p)) / n())

        pq <- pq %>%
            left_join(na_props, by = 'year') %>%
            filter(na_prop_q < 0.9,
                   na_prop_p < 0.9) %>%
            select(-starts_with('na_prop'))

        if(! nrow(pq)){
            results <- bind_rows(results,
                                 tibble(domain = dmn, site_code = site))
            next
        }

        #drop long stretches of missing Q. these may indicate dry/frozen streams
        pq <- pq %>%
            mutate(change = cumsum(! is.na(val.q) != lag(! is.na(val.q),
                                                         default = TRUE))) %>%
            group_by(change) %>%
            mutate(na_count = sum(is.na(val.q))) %>%
            filter(! (is.na(val.q) & na_count >= 30)) %>%
            ungroup() %>%
            select(-change, -na_count)

        pq_ann <- pq %>%
            mutate(val.q = discharge_to_runoff(val.q, area)) %>%
            group_by(year = year(datetime)) %>%
            summarize(q = sum(val.q, na.rm = TRUE),
                      p = sum(val.p, na.rm = TRUE),
                      .groups = 'drop') %>%
            left_join(prism_P,
                      by = 'year') %>%
            mutate(p_minus_q = p - q,
                   prism_minus_q = prism - q) %>%
            rowwise() %>%
            mutate(pct_gt_p = (p - q) / q * 100,
                   pct_gt_prism = (prism - q) / q * 100) %>%
            ungroup() %>%
            slice(2:(nrow(.) - 1)) #ignore first and last years, which might be truncated

        results <- pq_ann %>%
            summarize(q_gt_p_pct = round(sum(p_minus_q <= 0) / n() * 100, 1),
                      q_gt_prism_pct = round(sum(prism_minus_q <= 0, na.rm = TRUE) / n() * 100, 1),
                      p_gt_10x_q_pct = round(sum(pct_gt_p >= 1000) / n() * 100, 1),
                      prism_gt_10x_q_pct = round(sum(pct_gt_prism >= 1000, na.rm = TRUE) / n() * 100, 1)) %>%
            mutate(domain = !!dmn,
                   site_code = !!site) %>%
            relocate(domain, site_code) %>%
            bind_rows(results)
    }

    #read as e.g. "percent of siteyears for which Q > P"
    print(results, n = 1000)

    smry <- results %>%
        summarize(total_sites = n(),
                  Q_gt_P = sum(q_gt_p_pct > 0, na.rm = TRUE),
                  Q_gt_PRISM = sum(q_gt_prism_pct > 0, na.rm = TRUE),
                  P_gt_10Q = sum(p_gt_10x_q_pct > 0, na.rm = TRUE),
                  PRISM_gt_10Q = sum(prism_gt_10x_q_pct > 0, na.rm = TRUE))

    print(smry)
}

mark_superfluous_files <- function(){

    glue('looking for files that correspond to unknown/untracked sites.')
    require_shell_tool('find')

    stop('in 2025: work needed here. ran this previously without filtering for site type just below. but that results in some weird sites like catalina:MG_Outlet, which is a rain gauge and also secretly has a few schem samples, to get through, which causes problems downstream. the first loop is able to handle this appropriately if the comment secions are toggled. however, cant grep on ms9xx for portal, so will have to match filenames.')
    #bonanza:C1 is the only other such problem.

    known_sites <- site_data %>%
        filter(in_workflow == 1) %>%
               # site_type != 'rain_gauge') %>%
        pull(site_code)

    ff <- system("find data -type f -path '*/derived/*.feather'", intern = TRUE)
    to_remove <- c()
    for(i in seq_along(ff)){

        site_code <- str_extract(basename(ff[i]), '.+(?=\\.feather)')
        if(! site_code %in% known_sites){
            to_remove <- c(to_remove, ff[i])
            file.rename(ff[i], paste0(ff[i], 'REMOVETHISFILE'))#
        }
    }

    # to_remove <- grep('/(?:CUSTOM)?precip[a-z_]+?ms[^89][0-9]{2}/',
    #      to_remove,
    #      value = TRUE,
    #      invert = TRUE)
    #
    # for(rr in to_remove){
    #     file.rename(rr, paste0(rr, 'REMOVETHISFILE'))
    # }

    logwarn(paste(length(to_remove),
                  'superfluous files detected in data/. These have been appended with "REMOVETHISFILE". They',
                  'can be removed with remove_superfluous_files("data")'),
            logger = logger_module)

    ffp <- system("find ../portal/data -type f -name '*.feather'", intern = TRUE)
    for(i in seq_along(ffp)){

        site_code <- str_extract(basename(ffp[i]), '.+(?=\\.feather)')
        if(! site_code %in% known_sites){
            to_remove <- c(to_remove, ffp[i])
            file.rename(ffp[i], paste0(ffp[i], 'REMOVETHISFILE'))
        }
    }

    # logwarn(paste0('SUPERFLUOUS FILES:\n\t',
    #                paste(to_remove, collapse = '\n\t'),
    #                '\n\n\tThese filenames have been appended with "REMOVETHISFILE". They ',
    #                'can be removed with remove_superfluous_files()'),
    #         logger = logger_module)
    logwarn(paste(length(to_remove),
                  'superfluous files detected in ../portal/data. These have been appended with "REMOVETHISFILE". They',
                  'can be removed with remove_superfluous_files("../portal/data")'),
            logger = logger_module)

    ff <- system("find data -type f -path '*/derived/*.shp'", intern = TRUE)
    to_remove_shp <- c()
    for(i in seq_along(ff)){

        site_code <- str_extract(basename(ff[i]), '.+(?=\\.shp)')
        if(! site_code %in% known_sites){
            to_remove_shp <- c(to_remove, ff[i])
            stop('there should not be superfluous shapefiles. investigate this')
        }
    }
}

remove_some_molecular_forms <- function(){

    print('Removing some molecular variables, e.g. NH4 (and keeping e.g. NH4-N)')
    require_shell_tool('find')

    ff <- system("find data -type f -path '*/derived/*chemistry*/*.feather' -o -path '*/derived/*flux*/*.feather'",
                 intern = TRUE)
    for(f in ff){
        read_feather(f) %>%
           filter(! drop_var_prefix(var) %in% normally_converted_molecules) %>%
            write_feather(f)
    }
}

require_shell_tool <- function(tool, path = NULL){

    if(! is.null(path)){
        tool <- file.path(path, tool)
    }

    command_check <- try({
        system(glue('{tool} --version'),
               intern = TRUE,
               ignore.stderr = TRUE)
    }, silent = TRUE)

    if(inherits(command_check, 'try-error') || ! length(command_check)){
        stop(glue("The '{tool}' command is not available. Either install it or modify this routine to be OS-agnostic.\n"))
    }

    return(invisible())
}

remove_superfluous_files <- function(path){

    require_shell_tool('find')

    file_list <- system(paste("find", path, "-type f -name '*REMOVETHISFILE'"), intern = TRUE)

    if(! length(file_list)){
        cat('No superfluous files found. Taking no action\n')
        return(invisible())
    }

    print(glue('In 10 seconds, {length(file_list)} files will be removed from {path}. Mash Esc to cancel!'))
    Sys.sleep(10)

    system(paste("find", path, "-type f -name '*REMOVETHISFILE' -delete"))
    print(glue('{length(file_list)} files removed.'))
}

count_sigfigs <- function(x){

    #x: numeric vector or character vector of numerals

    # converts x to character, separates any digits to left and right of decimal.
    #   computes number of sigfigs as digits to the left, not including
    #   trailing zeros, plus digits to the right, not including leading zeros.

    #this does not currently work for representations like "100.", 0.0100, 100.0, or '0123',
    #   but it does get the job done for our purposes

    options(scipen = 100)

    x <- as.character(abs(as.numeric(x)))

    legal_characters <- c('.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
    char_test <- sapply(x, function(z) all(str_split(z, '')[[1]] %in% legal_characters))
    if(any(! char_test)){
        stop('some characters are not numeric or decimal point')
    }

    tokens <- str_split(x, '\\.')

    if(any(sapply(tokens, function(z) length(z) > 2))){
        stop('got some wonky numbers here. multiple decimals?')
    }

    n_sigfigs <- sapply(tokens, function(z)
    {
        has_decimal <- length(z) == 2
        if(has_decimal){

            has_sigfigs_after_decimal <- any(str_split(z[2], '')[[1]] != '0')
            has_sigfigs_before_decimal <- any(str_split(z[1], '')[[1]] != '0')

            if(has_sigfigs_before_decimal && has_sigfigs_after_decimal){
                tokens_dec <- nchar(z[2])
                tokens_whole <- nchar(z[1])
            } else if(has_sigfigs_after_decimal){
                tokens_dec <- nchar(sub('^0+', '', z[2]))
                tokens_whole <- 0
            } else {
                tokens_dec <- 0
                tokens_whole <- 0
            }

        } else {
            tokens_whole <- nchar(sub('0+$', '', z[1]))
            tokens_dec <- 0
        }

        tokens_whole + tokens_dec
    })

    options(scipen = 0)

    return(n_sigfigs)
}

get_numeric_precision <- function(x){

    #x: numeric vector or character vector of numerals

    # determines numeric precision as the count of digits, or, for whole numbers,
    #   the count of digits not including trailing zeros.

    #WARNING: this does not currently work for representations like "100.", 0.0100, 100.0, or '0123',
    #   but it does get the job done for our purposes

    options(scipen = 100)

    x <- as.character(abs(as.numeric(x)))

    legal_characters <- c('.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
    char_test <- sapply(x, function(z) all(str_split(z, '')[[1]] %in% legal_characters))
    if(any(! char_test)){
        stop('some characters are not numeric or decimal point')
    }

    precision <- sapply(x, function(z)
    {
        has_decimal <- grepl('\\.', z)
        if(has_decimal){
            if(substr(z, 1, 1) == '0'){
                prec <- nchar(z) - 2
            } else {
                prec <- nchar(z) - 1
            }
        } else {
            if(all(str_split(z, '')[[1]] == '0')){
                prec <- 0
            } else {
                prec <- -nchar(str_match(z, '(0*)$')[, 2]) - 1
            }
        }
    }, USE.NAMES = FALSE)

    options(scipen = 0)

    return(precision)
}

standardize_detection_limits <- function(dls, vs, update_on_gdrive = FALSE){

    #dls: detection limits, read from gdrive
    #vs: variables, read from gdrive,
    #update_on_gdrive: logical. should the domain_detection_limits file
    #   on gdrive be updated?

    if(! 'site_code' %in% colnames(dls)) dls$site_code <- 'all'
    dls$site_code[is.na(dls$site_code)] <- 'all'

    #fix units, get sigfigs, get canonical units
    dls <- dls %>%
      filter(detection_limit_original != 'NA',
             ! is.na(detection_limit_original)) %>%
        mutate(unit_original = sub('^([a-z]+)/l', '\\1/L', unit_original),
               sigfigs = count_sigfigs(detection_limit_original)) %>%
        select(-any_of('unit_converted')) %>%
        left_join(select(vs, variable_code, unit_converted = unit),
                  by = c(variable_original = 'variable_code'))

    core_ <- function(dl_set, keep_molecular = NULL){

        #prepare detlim data to be used with ms_conversions__
        dls_ms_format <- dl_set %>%
            mutate(datetime = as.POSIXct('2000-01-01 00:00:00', tz = 'UTC'),
                   # site_code = 'a',
                   var = paste0('GN_', variable_original),
                   val = detection_limit_original) %>%
            select(datetime, site_code, var, val)

        from_units <- dl_set$unit_original
        names(from_units) <- dl_set$variable_original
        to_units <- dl_set$unit_converted
        names(to_units) <- dl_set$variable_original

        #convert detlims to canonical units
        dls_conv <- ms_conversions__(d = dls_ms_format,
                                   convert_units_from = from_units,
                                   convert_units_to = to_units,
                                   keep_molecular = keep_molecular,
                                   row_wise = TRUE)

        #round to original sigfigs
        dl_set$detection_limit_converted <- mapply(function(a, b) signif(a, b),
                                                   a = dls_conv$val,
                                                   b = dl_set$sigfigs)

        return(dl_set)
    }

    #convert detlims to MS canonical units
    if('variable_converted' %in% names(dls)){
        ap <- dls$added_programmatically
        conv_var <- dls$variable_original %in% normally_converted_molecules
        orig_form <- dls$variable_converted == dls$variable_original
        regenerate_these <- ap & conv_var & orig_form
    } else {
        regenerate_these <- rep(FALSE, nrow(dls))
    }

    dlout_a <- core_(filter(dls, ! regenerate_these))

    #update variable names for molecules that have been converted
    dlout_a$variable_converted <- dlout_a$variable_original
    varcode_change_inds <- dlout_a$variable_converted %in% normally_converted_molecules
    varcodes_to_change <- dlout_a$variable_converted[varcode_change_inds]
    new_varcodes <- normally_converted_to[match(varcodes_to_change, normally_converted_molecules)]
    dlout_a$variable_converted[varcode_change_inds] <- new_varcodes

    #also standardize detlims for the molecules that we usually convert according to
    #the masses of their primary constituents, since some of these molecules
    #are allowed to be carried through the ms processing pipeline as-is
    dlout_b <- filter(dls,
                      variable_original %in% normally_converted_molecules,
                      ! regenerate_these)

    if(nrow(dlout_b)){
        dlout_b <- dlout_b %>%
            core_(keep_molecular = normally_converted_molecules) %>%
            mutate(added_programmatically = TRUE,
                   variable_converted = variable_original)
    }

    dls <- bind_rows(dlout_a, dlout_b) %>%
        filter(! is.na(detection_limit_converted)) %>%
        mutate(precision = get_numeric_precision(detection_limit_converted)) %>%
        select(domain, prodcode, site_code, variable_converted,
               variable_original, detection_limit_converted,
               detection_limit_original, precision, sigfigs, unit_converted,
               unit_original, start_date, end_date, added_programmatically)

    dls <- dls[! duplicated(dls), ]

    if(any(duplicated(select(dls, -added_programmatically)))){
        stop(paste('we have generated detection limits for a molecule-as-atom',
                   'where a domain has already reported the same. implement',
                   'filtering of our estimate in this case'))
    }

    if(update_on_gdrive){

        ndls <- nrow(domain_detection_limits)
        nothing_to_do <- sm(nrow(semi_join(domain_detection_limits, dls)) == ndls)
        if(nothing_to_do) return(dls)
        if(nrow(dls) < ndls){
            message('this must be the case that is causing records to drop from the dl gsheet. what is going on?')
            browser()
        }

        catch <- expo_backoff(
            expr = {
                sm(googlesheets4::write_sheet(data = dls,
                                              ss = conf$dl_sheet,
                                              sheet = 1))
            },
            max_attempts = 4
        )
    }

    return(dls)
}

legal_details_scrape <- function(dataset_version){

    #this was written before we knew the full extent of IR subtlety, for both
    #timeseries and ws attribute data. rather than confuse users with 3 sources
    #of IR details (ms_generate_attribution, 01b_attribution_and_intellectual_rights_complete.docx,
    #LEGAL.csv[s]--really a subset of 05a_timeseries_LEGAL.csv that doesn't account for
    #06a_ws_attr_LEGAL.csv), let's just direct them to the first two, which are comprehensive.

    ## metadata and citation information function

    # meta_info_header <- sm(googlesheets4::read_sheet(
    #        conf$site_doi,
    #        col_types = 'c',
    #        n_max = 5,
    #        col_names = FALSE
    #    ))

    # retrieve metadata
    # meta_info <- sm(googlesheets4::read_sheet(
    #        conf$site_doi,
    #        na = c('', 'NA'),
    #        col_types = 'c',
    #        skip = 5
    #    ))

    meta_urls <- sm(googlesheets4::read_sheet(
        conf$domain_urls,
        na = c('', 'NA'),
        col_types = 'c'
    ))

    # locate domain directory
    network_dir <- file.path(getwd(), paste0('macrosheds_dataset_v', dataset_version))
    network_paths <- list.files(network_dir,
                                full.names = TRUE)

    readme <- readLines('src/templates/figshare_docfiles/ts_readme.txt')

    # loop domains, and print data .csv and guide .txt
    for(domain_name in unique(meta_info$domain)){

        # # subset all the domain metadata
        # domain_info <- unique(meta_info[meta_info$domain == domain_name, ])

        # subset the domain URLs
        domain_url <- meta_urls[meta_urls$domain == domain_name, ]
        str_url <- paste(unique(domain_url$url), collapse = ', ')

        # # merge to a single data frame
        # domain_all <- merge(domain_info, domain_url, 'domain')

        network_name <- network_domain %>%
            filter(domain == !!domain_name) %>%
            pull(network)

        if(! length(network_name)) next #domain not fully hooked up

        ntw_pth <- grep(paste0(network_name, '$'), network_paths, value = TRUE)

        dmn_pth <- list.files(ntw_pth, full.names = TRUE) %>%
            str_subset(domain_name)

        if(! length(dmn_pth)) next #there's been a network/domain change and somebody's trying to run this without rebuilding everything

        # #add column of macrosheds prodnames to clarify primary prodcodes
        # dmn_prods <- try({
        #     read_csv(glue('src/{n}/{d}/products.csv',
        #                   n = network_name,
        #                   d = domain_name),
        #              col_types = cols())
        # })
        #
        # if(inherits(dmn_prods, 'try-error')) next
        #
        # dmn_prods <- dmn_prods %>%
        #     select(prodcode,
        #            ms_prodnames = prodname) %>%
        #     group_by(prodcode) %>%
        #     summarize(ms_prodnames = paste(ms_prodnames, collapse = ', ')) %>%
        #     ungroup()
        #
        # domain_all <- domain_all %>%
        #     left_join(dmn_prods, by = c(macrosheds_prodcode = 'prodcode')) %>%
        #     select(domain, macrosheds_prodnames = ms_prodnames,
        #            macrosheds_prodcode, everything()) %>%
        #     arrange(macrosheds_prodnames, macrosheds_prodcode)

        #write legal table and accompanying readme
        # file_name <- file.path(network_dir, network_name, domain_name, 'LEGAL.csv')

        #use this to write file called READ_THIS_FIRST.txt to all figshare domain
        #folders, for packageversion too.


        readme_domain <- file.path(network_dir, network_name, domain_name,
                                   'citation_instructions.txt')

        reader <- file(readme_domain)
        headerline <- paste0('Domain: ', domain_name)
        subline <- paste0('Data Source URL: ', str_url, '\n')
        writeLines(c(headerline, subline, readme), reader)
        close(reader)

        # write_csv(domain_all, file_name)
    }
}

reformat_camels_for_ms <- function(vsn, rebuild = TRUE){

    #rebuild = FALSE assumes scratch/ already contains rebuilt data

    ms_attributes_dir <- 'scratch/camels_assembly/ms_attributes'
    daymet_dir <- 'scratch/camels_assembly/daymet_with_pet'

    if(rebuild){
        source('src/global/camels_formatting_scripts/append_pet_to_daymet.R',
               local = new.env())
        source('src/global/camels_formatting_scripts/camelsesque_ws_attrs.R',
               local = new.env())
        source('src/global/camels_formatting_scripts/camels_hydro.R',
               local = new.env())
    }

    attr_files <- list.files(ms_attributes_dir,
                             recursive = TRUE,
                             full.names = TRUE)

    daymet_files <- list.files(daymet_dir,
                               full.names = TRUE)

    ntw_dmn_join <- site_data %>%
        filter(site_type != 'rain_gauge',
               in_workflow == 1) %>%
        select(domain, network, site_code)

    soil <- map_dfr(grep('soil\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')
    clim <- map_dfr(grep('clim\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')
    topo <- map_dfr(grep('topo\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')
    geol <- map_dfr(grep('geol\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')
    vege <- map_dfr(grep('vege\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')
    hydro <- map_dfr(grep('hydro\\.', attr_files, value = TRUE), read_feather) %>%
        left_join(ntw_dmn_join, by = 'site_code') %>%
        relocate(domain, network, .after = 'site_code')

    dir.create(glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes'), showWarnings = FALSE)
    dir.create(glue('macrosheds_figshare_v{vsn}/4_CAMELS-compliant_Daymet_forcings'), showWarnings = FALSE)

    write_csv(soil, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/soil.csv'))
    write_csv(clim, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/clim.csv'))
    write_csv(topo, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/topo.csv'))
    write_csv(geol, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/geol.csv'))
    write_csv(vege, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/vege.csv'))
    write_csv(hydro, glue('macrosheds_figshare_v{vsn}/3_CAMELS-compliant_watershed_attributes/hydro.csv'))

    for(i in 1:length(daymet_files)){

        this_daymet <- read_csv(daymet_files[i], show_col_types = FALSE)

        sites <- unique(this_daymet$site_code)
        for(s in sites){

            this_daymet %>%
                filter(site_code == !!s) %>%
                mutate(date = as.Date(date),
                       pet = if_else(is.infinite(pet), NA_real_, pet)) %>%
                rename(`dayl(s)` = dayl,
                       `prcp(mm/day)` = prcp,
                       `srad(W/m2)` = srad,
                       `swe(mm)` = swe,
                       `tmax(C)` = tmax,
                       `tmin(C)` = tmin,
                       `vp(Pa)` = vp,
                       `pet(mm)` = pet) %>%
                left_join(ntw_dmn_join, by = 'site_code') %>%
                relocate(domain, network, .after = 'site_code')
                write_csv(glue('macrosheds_figshare_v{vsn}/4_CAMELS-compliant_Daymet_forcings/{s}.csv'))
        }
    }

    log_with_indent('Combining 4_CAMELS-compliant_Daymet_forcings CSVs',
                    indent = 2,
                    logger = logger_module)
    combine_daymet_csvs(glue('macrosheds_figshare_v{vsn}'))

    log_with_indent('Combining ws attrs (separately for ms and camels-compliant)',
                    indent = 2,
                    logger = logger_module)
    combine_ws_attrs(glue('macrosheds_figshare_v{vsn}'))

    get_response_enter('in 2024, i moved and edited the funcs that combine camels attrs (and daymet). check the combined files in macrosheds_figshare_vX and verify that they have "domain" and "network" columns, and that 3_ does not contain polluted "domain.y.y.y" etc cols. check again that these files appear correctly in eml/data_links at the end. [enter to continue]')
}

# helper which goes inside of ms_read_csv, this function allows for the users to assign multiple input columns to
# a single output column (e.g. filtered and unfiltered data colums for Zinc)
combine_multiple_input_cols <- function(d, data_cols, var_flagcols) {
    # takes the tibble and data_cols arguments from ms_read_csv

    # find index of all duplicate columns in data_cols input
    dc_dupes_index <- which(duplicated(data_cols) | duplicated(data_cols, fromLast = TRUE))

    # looping thru these indices
    for(index in dc_dupes_index) {
        # find the 'paired' columns - which indices are specifically duplicates of each other
        # Data
        pair_cols <- match(data_cols, data_cols[index])
        pair_colnames <- names(data_cols[!is.na(pair_cols)])
        # Flag
        if(!all(is.na(var_flagcols))) {
            pair_cols_flg <- match(var_flagcols, var_flagcols[index])
            pair_colnames_flg <- names(var_flagcols[!is.na(pair_cols)])
        }

        ms_var <- unique(unname(data_cols[!is.na(pair_cols)]))[[1]]
        warning('merging multiple input columns:', pair_colnames, '\n',
                'into ms var:', ms_var)

        # if input column names aren't in dataframe, move on
        if(!all(pair_colnames %in% colnames(d))) {
            next
        }

        # create a dummy vector
        covector <- c(rep(NA, nrow(d)))
        # for each paired input data column
        for(paircol in pair_colnames) {
            # pull just this column data as a vector
            d_pair <- d %>%
                pull(paircol) %>%
                as.vector()
            # coalesce will merge them, and where both vectors have data
            # at the saeme index, data from the the first vector argument
            # will be used
            # NOTE: replace with mean one day -- must figure out workaround on BDLs ("<0.03", etc.)
            covector = coalesce(d_pair, covector)

        }

        if(!all(is.na(var_flagcols))) {
            # create a dummy vector
            covector_flg <- c(rep(NA, nrow(d)))

            # for each paired input data column
            for(paircol_flg in pair_colnames_flg) {
                # pull just this column data as a vector
                d_pair_flg <- d %>%
                    pull(paircol_flg) %>%
                    as.vector()
                # coalesce will merge them, and where both vectors have data
                # at the saeme index, data from the the first vector argument
                # will be used
                # NOTE: replace with mean one day -- must figure out workaround on BDLs ("<0.03", etc.)
                covector_flg = coalesce(d_pair_flg, covector_flg)

            }

            # assign all variable flag data to merged data
            for(paircol_flg in pair_colnames_flg) {
                d[,which(colnames(d) == paircol_flg)] <- covector_flg
            }
        }

        # assign all variable data to merged data
        for(paircol in pair_colnames) {
            d[,which(colnames(d) == paircol)] <- covector
        }


        # keep only first pair data and flag colnames
        prefix_remove <- gsub("val_", "", pair_colnames[-1])
        try(
            d <- d %>%
            select(
                -!!pair_colnames[-1],
                -contains(prefix_remove)
            )
        )
    }

    return(d)
}

check_for_derelicts <- function(network, domain){

    all_raw <- list.files(glue('data/{network}/{domain}/raw'),
                          full.names = TRUE,
                          recursive = TRUE)
    base_raw <- basename(all_raw)
    all_filt <- all_raw[duplicated(base_raw) | duplicated(base_raw, fromLast = TRUE)]
    all_filt <- all_filt[order(basename(all_filt))]

    if(length(all_filt) %% 2 != 0){
        if(domain == 'neon'){
            warning('check_for_derelicts is not set up for neon')
            return()
        } else {
            stop('error in identifying duplicate filenames')
        }
    }

    pair_list <- split(all_filt, ceiling(seq_along(all_filt) / 2))
    pair_list <- Filter(function(x) length(unique(str_extract(x, '(?<=raw/)[^\\/]+'))) == 1,
                        pair_list)

    if(! length(pair_list)){
        return(invisible())
    } else {
        message('identically named files detected within a raw product. ',
                'this might be fine, but could indicate derelict files from an ',
                'old run sticking around:')
    }

    all_filt <- unlist(pair_list, use.names = FALSE)
    all_trunc <- str_extract(all_filt, '(?<=raw/).*')

    for(i in seq_along(all_filt)){
        item <- all_filt[i]
        if(i %% 2 == 1 && i > 2) cat('\n')
        cat('\n',
            all_trunc[i],
            ' (', str_sub(file.mtime(item), 1, 10), ')',
            sep = '')
    }
}

generate_retrieval_details <- function(url,
                                       access_note = NULL,
                                       last_mod_dt = NULL){

    #url: the url of a static file OR the page on which download queries
    #     are entered, such as http://www.czo.psu.edu/data_time_series.html
    #access_note: the only note we ever really need is "requires authentication".
    #     Otherwise, keep it NULL
    #last_mod_dt: the last-modified time of a static file, if you needed to
    #     precompute it for some reason. if NULL, it will be computed
    #     from the given url

    #returns: a list with the url and any notes appended, access time,
    #and last-modified datetime

    res <- httr::HEAD(url)

    if(is.null(last_mod_dt)){
        last_mod_dt <- strptime(x = substr(res$headers$`last-modified`,
                                           start = 1,
                                           stop = 19),
                                format = '%Y-%m-%dT%H:%M:%S') %>%
            with_tz(tzone = 'UTC')
    }

    if(! length(last_mod_dt)){
        last_mod_dt <- NA_character_
    }

    if(! is.null(access_note)){
        access_note <- paste0('(', access_note, ')')
    }

    deets_out <- list(url = stringr::str_trim(paste(url, access_note)),
                      access_time = as.character(with_tz(Sys.time(),
                                                         tzone = 'UTC')),
                      last_mod_dt = last_mod_dt)

    return(deets_out)
}

reverse_vector_pairs <- function(x){

    if(length(x) == 1) return(x)

    x_ <- tryCatch({
        x_ <- as.vector(matrix(x, nrow = 2)[2:1, ])
    }, warning = function(w){
        x <- strsplit(x, ', ') %>% unlist()
        x_ <- as.vector(matrix(x, nrow = 2)[2:1, ])
        return(x_)
    })

    return(x_)
}

# subset_successive <- function(v){
#     diff_v <- diff(v)
#     splits <- which(diff_v != 1)
#     split_list <- split(v, cumsum(c(1, diff_v != 1)))
#     successive_subsets <- split_list[sapply(split_list, length) > 1]
#     return(successive_subsets)
# }

successive_ints <- function(v){
    diff_v <- c(1, diff(v))
    group_ids <- cumsum(diff_v != 1)
    grouped_list <- split(v, group_ids)
    return(grouped_list)
}

convert_EDI_to_APA <- function(citation, provenance_row, raw = FALSE){

    #provenance_row: deprecated
    #raw: logical. If TRUE, return a list of citation components (e.g. to be converted to BibTeX),
    #   rather than a formatted citation

    # citation = 'Caine, N., J. Morse, and Niwot Ridge LTER. 2023. Streamflow data for Albion camp, 1981 - ongoing. ver 18. Environmental Data Initiative. https://doi.org/10.6073/pasta/cc7e183b27383d894709fcc3e2e8cc74 (Accessed 2024-01-15).'
    # citation = 'Wollheim, W. and Plum Island Ecosystems LTER. 2019. PIE LTER time series of nutrient grab samples from Ipswich River and Parker River watershed catchments, Masachusetts, with frequency ranging from weekly to monthly between 2001 and 2019. ver 9. Environmental Data Initiative. https://doi.org/10.6073/pasta/465825142c5393363c707b1243dd4016 (Accessed 2024-01-15).'
    # citation = 'Gooseff, M. and D. McKnight. 2021. Seasonal high-frequency measurements of discharge, water temperature, and specific conductivity from Commonwealth Stream at C1, McMurdo Dry Valleys, Antarctica (1993-2020, ongoing) ver 9. Environmental Data Initiative. https://doi.org/10.6073/pasta/f77f93be497f540ae7e262866e13970e (Accessed 2024-01-15).'
    # citation = 'Santa Barbara Coastal LTER and J. Melack. 2019. SBC LTER: Land: Hydrology: Santa Barbara County Flood Control District - Precipitation at KTYD (KTYD227) ver 8. Environmental Data Initiative. https://doi.org/10.6073/pasta/6c6ceaab7c189afc85abb893280492a8 (Accessed 2024-01-16).'
    # citation = 'Santa Barbara Coastal LTER and J. Q. Melack. 2019. SBC LTER: Land: Hydrology: Santa Barbara County Flood Control District - Precipitation at KTYD (KTYD227) ver 8. Environmental Data Initiative. https://doi.org/10.6073/pasta/6c6ceaab7c189afc85abb893280492a8 (Accessed 2024-01-16).'
    # authors <- parts[1:(titleind - 2)]
    title <- find_resource_title(citation)

    parts <- str_split(citation, "[\\.]", simplify = TRUE) %>%
        map(str_trim) %>%
        discard(~. == '') %>%
        unlist()

    if(! title %in% parts){

        ergh <- sapply(parts, function(x) grep(x, title, fixed = TRUE)) %>%
            as.list()

        ergh[[which(grepl('^[0-9]{4}$', names(ergh)))]] <- integer()

        replace_inds <- sapply(ergh, length) %>% as.logical %>% which

        parts[replace_inds[1]] <- ergh %>%
            discard(~!length(.)) %>%
            names() %>%
            reduce(paste, sep = '. ') %>%
            map(~sub('\\. ,', '.,', .))

        parts[replace_inds[1]] <- sub('^[0-9]{4}\\.', '', parts[replace_inds[1]])

        parts <- as.list(parts)
        parts[replace_inds[-1]] <- NULL
        parts <- unlist(parts)
    }

    titleind <- which(parts == title)
    if(! length(titleind)){
        stop('dang, we need to handle periods in titles... still?')
    }
    title <- sub('( ver [0-9]+)$', '.\\1', title)
    author <- format_authors_edi(parts[1:(titleind - 2)])
    year <- parts[titleind - 1]
    vsn <- parts[titleind + 1]
    if(! grepl('ver ', vsn)) vsn <- ''
    # publisher <- parts[titleind + 2]
    publisher <- 'Environmental Data Initiative'
    url <- str_extract(citation, "https?://[^ ]+")

    # ## get the letter for the publication year
    #
    # parts <- str_split(provenance_row$citation, "[\\.]", simplify = TRUE) %>%
    #     map(str_trim) %>%
    #     unlist()
    #
    # yearletter <- na.omit(str_match(parts, '^\\(([0-9]{4}[a-z]+?)\\)$')[, 2])
    # if(! length(yearletter) || is.na(yearletter) || ! grepl('^[0-9]{4}', yearletter)){
    #     stop('parsing error when determining former publication year')
    # }

    if(raw){

        components <- list(
            author = author,
            year = year,
            title = title,
            publisher = paste(vsn, publisher, sep = '. '),
            url = url
        )

        return(components)
    }

    #combine
    # apa_citation <- paste0(author, ". (", yearletter, "). ", title, ". ", vsn, ". ",
    apa_citation <- paste0(author, ". (", year, "). ", title, ". ", vsn, ". ",
                           publisher, ". ", url) %>%
        str_replace_all('\\. ?\\.', '.')

    return(apa_citation)
}

convert_hydroshare_to_APA <- function(citation, provenance_row, raw = FALSE){

    #provenance_row: deprecated
    #raw: logical. If TRUE, return a list of citation components (e.g. to be converted to BibTeX),
    #   rather than a formatted citation

    # authors = author_bits
    # citation_text->citation
    # citation = 'Anderson, S., N. Rock, D. Ragar (2023). BCCZO -- Meteorology, Air Temperature -- (BT_Met) -- Betasso -- (2009-2020), HydroShare, http://www.hydroshare.org/resource/6bf3e44b9de344749d8f665e139e7311'
    # citation = 'Chorover, J., P. Troch, A. B. McIntosh, E. F. G. Amistadi. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J., P. Troch, A. McIntosh, E. Amistadi. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J., A. B. C. Troch, A. McIntosh, E. Amistadi. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J. B. C., A. Troch, A. McIntosh, E. Amistadi. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J. B. C. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J. B. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J. B., F. Donkey. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # citation = 'Chorover, J. (2021). CJCZO -- Precipitation Chemistry -- Santa Catalina Mountains -- (2006-2019), HydroShare, http://www.hydroshare.org/resource/4ab76a12613c493d82b2df57aa970c24'
    # authors = author_bits

    parts <- str_match(citation, '^(.+?)\\(([0-9]{4})\\)\\.(.+)$')[, 2:4] %>%
        map(str_trim) %>%
        unlist()

    author_bits <- str_split(parts[1], "[\\.]", simplify = TRUE) %>%
        discard(~. == '') %>%
        map(str_trim)

    author <- format_authors_hydroshare(author_bits)

    title_etc <- sub(', HydroShare, http', '. HydroShare. http', parts[3])
    title_etc <- sub('http:', 'https:', title_etc)

    ## get the letter for the publication year

    # parts <- str_split(provenance_row$citation, "[\\.]", simplify = TRUE) %>%
    #     map(str_trim) %>%
    #     unlist()
    #
    # yearletter <- na.omit(str_match(parts, '^\\([0-9]{4}([a-z]+?)\\)$')[, 2])
    # if(! length(yearletter) || is.na(yearletter) || ! grepl('^[a-z]+$', yearletter)){
    #     stop('parsing error when determining former publication year')
    # }

    if(raw){

        more_comps <- str_split(title_etc, '\\. HydroShare. ')[[1]]

        components <- list(
            author = author,
            year = parts[2],
            title = more_comps[1],
            publisher = 'HydroShare',
            url = more_comps[2]
        )

        return(components)
    }

    #combine
    apa_citation <- paste0(author, " (", parts[2], "). ", title_etc)
    # apa_citation <- paste0(author, " (", parts[2], yearletter, "). ", title_etc)

    return(apa_citation)
}

format_authors_edi <- function(authors){

    if(length(authors) == 1){
        return(authors[[1]])
    }

    last_auth <- which(grepl('^(?:.*, )?and [A-Z]$', authors))
    organizational_author <- FALSE
    #omg so far past point of diminishing returns. just hard code the weird ones
    override <- ifelse(any(grepl('Cary Institute Of Ecosystem Studies', authors)), TRUE, FALSE)
    if(! length(last_auth) || override){
        if(any(grepl(' and ', authors[-length(authors)]))){
            case3 <- domain == 'baltimore' && authors[length(authors)] == 'Welty'
            if(case3 && all(c('Lagrosa, and C', 'Welty') %in% authors)){
                return('Cary Institute Of Ecosystem Studies, Lagrosa, J., & Welty, C')
            }
            if(! grepl(' and ', authors[1])) stop('probably need to adjust for this')
            case1 <- domain == 'santa_barbara' && authors[length(authors)] == 'Melack'
            case2 <- domain == 'niwot' && authors[length(authors)] == 'Caine'
            if(case1 || case2){
                authors <- strsplit(authors, " and ") %>% unlist()
                inits <- unlist(authors[-c(1, length(authors))])
                if(! length(inits) %in% 1:2) stop('has been e.g. J Q or just J for santa b')
                out <- paste0(authors[1], ', & ', authors[length(authors)], ', ',
                              paste(inits, collapse = '. '))
                return(out)
            }
            stop('ugh. just hardcoding this for santa barbara. if it comes up again, deal with it properly')
        }
        last_auth <- which(grepl('^(?:.*, )?and [A-Za-z ]+$', authors))
        organizational_author <- TRUE
    }
    if(length(last_auth)){
        if(grepl(', and ', authors[last_auth])){
            authors <- strsplit(authors, ", and ") %>% unlist()
            authors[last_auth + 1] <- paste(',', authors[last_auth + 1])
        } else {
            authors[last_auth] <- sub('and ', ', ', authors[last_auth])
        }
    }

    authors <- as.list(authors)

    authors <- lapply(authors, function(x){
        if(grepl('^,? ?[a-zA-Z]$', x)) toupper(x) else x
    })
    new_initial <- grep('^, [A-Z]$', authors)
    extra_initial <- grep('^[A-Z]$', authors)

    initial_groups <- successive_ints(extra_initial)
    only_single_initials <- length(initial_groups) == 1 && any(! length(initial_groups[[1]]))
    if(only_single_initials){
        first_auth_inits <- NULL
    } else {
        first_auth_inits <- unlist(keep(initial_groups, ~.[1] == 2), use.names = FALSE)
    }

    if(is.null(first_auth_inits)){
        first_auth <- authors[[1]]
    } else {
        first_auth <- paste(authors[c(1, first_auth_inits)], collapse = '. ')
    }

    if(! only_single_initials){
        for(init in rev(new_initial)){
            ig_ <- unlist(keep(initial_groups, ~.[1] == init + 1), use.names = FALSE)
            if(! is.null(ig_)){
                authors[[init]] <- paste(authors[init],
                                         paste(authors[ig_], collapse = '. '),
                                         sep = '. ')
                authors[ig_] <- NULL
            }
        }
    }

    authors[[1]] <- first_auth
    authors[first_auth_inits] <- NULL

    authors <- gsub("^, ", "", authors)
    # authors <- strsplit(authors, ", and ") %>% unlist()

    if(length(authors) %% 2 == 0 && ! organizational_author){
        stop('error parsing citation authors')
    }

    if(organizational_author){
        last_author <- authors[length(authors)]
        authors <- authors[-length(authors)]
    }

    #reorder author components
    if(length(authors) != 1){

        firstauthor <- authors[1]
        notfirst <- reverse_vector_pairs(authors[-1])
        notfirst <- split(notfirst, ceiling(seq_along(notfirst) / 2)) %>%
            map(~paste(., collapse = ', ')) %>%
            paste0(., '.')
        notfirst[length(notfirst)] <- paste('&', notfirst[length(notfirst)])
        notfirst <- paste(notfirst, collapse = ', ')
        authors <- paste0(firstauthor, '., ', notfirst)
    }

    if(organizational_author){
        authors <- sub(' &', '', authors)
        if(str_count(authors, ',') > 1){
            authors <- paste0(authors, ',')
        } else {
            authors <- paste0(authors, '.,')
        }
        authors <- paste(authors, last_author, sep = ' & ')
    }

    return(authors)
}

format_authors_hydroshare <- function(authors){

    if(length(authors) == 1){

        if(! grepl('\\.$', authors[[1]])){
            authors[[1]] <- paste0(authors[[1]], '.')
        }
        return(authors[[1]])
    }

    for(i in 2:(length(authors) - 1)){
        current_element <- authors[[i]][1]
        if(grepl("[A-Za-z]+, [A-Z]$", current_element)){
            # initial <- sub(".*,( [A-Z])$", "\\1", current_element)
            # authors[[i]][1] <- gsub(", [A-Z]$", "", current_element)
            initial <- sub(".*(, [A-Z])$", "\\1", current_element)
            authors[[i]][1] <- gsub(", [A-Z]$", "", current_element)
            authors <- c(authors[1:i], initial, authors[(i + 1):length(authors)])
            # authors[[i + 1]][1] <- paste(initial, authors[[i + 1]][1], sep = '. ')
        }
    }

    authors <- lapply(authors, function(x){
        if(grepl('^,? ?[a-zA-Z]$', x)) toupper(x) else x
    })
    new_initial <- grep('^, [A-Z]$', authors)
    extra_initial <- grep('^[A-Z]$', authors)

    initial_groups <- successive_ints(extra_initial)
    only_single_initials <- length(initial_groups) == 1 && any(! length(initial_groups[[1]]))
    if(only_single_initials){
        first_auth_inits <- NULL
    } else {
        first_auth_inits <- unlist(keep(initial_groups, ~.[1] == 2), use.names = FALSE)
    }

    if(is.null(first_auth_inits)){
        first_auth <- authors[[1]]
    } else {
        first_auth <- paste(authors[c(1, first_auth_inits)], collapse = '. ')
    }

    if(! only_single_initials){
        for(init in rev(new_initial)){
            ig_ <- unlist(keep(initial_groups, ~.[1] == init + 1), use.names = FALSE)
            if(! is.null(ig_)){
                authors[[init]] <- paste(authors[init],
                                         paste(authors[ig_], collapse = '. '),
                                         sep = '. ')
                authors[ig_] <- NULL
            }
        }
    }

    authors[[1]] <- first_auth
    authors[first_auth_inits] <- NULL

    authors <- gsub("^, ", "", authors)
    # authors <- strsplit(authors, ", and ") %>% unlist()

    if(length(authors) %% 2 == 0){
        authors <- c(authors[1], unlist(strsplit(authors[-1], ", ")))
    }

    #reorder author components
    if(length(authors) != 1){
        firstauthor <- authors[1]
        notfirst <- reverse_vector_pairs(authors[-1])
        notfirst <- split(notfirst, ceiling(seq_along(notfirst) / 2)) %>%
            map(~paste(., collapse = ', ')) %>%
            paste0(., '.')
        if(length(notfirst) != 1 || ! grepl('^(?:[A-Z]. ?)+$', notfirst)){
            notfirst[length(notfirst)] <- paste('&', notfirst[length(notfirst)])
        }
        notfirst <- paste(notfirst, collapse = ', ')
        if(length(notfirst) != 1 || ! grepl('^(?:[A-Z]. ?)+$', notfirst)){
            authors <- paste0(firstauthor, '., ', notfirst)
        } else {
            authors <- paste0(firstauthor, ', ', notfirst)
        }
    }

    if(! grepl('\\.$', authors)){
        authors <- paste0(authors, '.')
    }

    return(authors)
}

once_per_session_warning <- function(label, message){

    #label: a character string representing the warning. this string will become
    #   a variable in an environment called "warnings_"

    if(! exists('warnings_', envir = .GlobalEnv)){
        assign('warnings_', new.env(parent = .GlobalEnv), envir = .GlobalEnv)
    }

    warnings_env <- get('warnings_', envir = .GlobalEnv)

    if(exists(label, where = warnings_env)){
        return(invisible())
    } else {
        assign(label, value = 'placeholder', envir = warnings_env)
    }

    message <- paste0(message, '. This warning will appear once per session.')
    message <- sub('\\. ?\\.', '.', message)

    warning(message, call. = FALSE)
}

convert_ms_to_bib <- function(citation, list = FALSE){

    #list: logical. If TRUE, return a list of citation components (e.g. to be converted to BibTeX),
    #   rather than a formatted citation

    warning('this function needs work. get it to parse the following correctly: (it might already work with these, but not with their originals)')
    # Van Cleve, K., F.S. Chapin, R. Ruess, M.C. Mack, J.B. Jones, and Bonanza Creek LTER. 2023. Caribou-Poker Creeks Research Watershed: Daily Flow Rates for C2, C3, C4 ver 24. Environmental Data Initiative. https://doi.org/10.6073/pasta/2131d13a7a0a46abd039736e56b9f551 (Accessed 2024-09-09).
    # Carroll, R., Newman, A., Beutler, C., Williams, K., & O'Ryan, D. (2023). Stream discharge and temperature data collected within the East River, Colorado for the Lawrence Berkeley National Laboratory Watershed Function Science Focus Area (water years 2019 to 2022). Watershed Function SFA, ESS-DIVE repository. https://doi.org/10.15485/1779721
    #    (not sure about the original form of that one)
    # there's a chance these are fine already

    once_per_session_warning(
        label = 'publishers',
        message = paste('some citations may be missing publishers/urls, and will not parse.',
                        'see notes associated with known_publishers global var to find out which ones need to have these fields manually added')
    )

    title <- find_resource_title(citation)
    comps <- str_split(citation, fixed(paste0('. ', title, '. ')))[[1]]
    comps_ <- str_match(comps[1], '^(.+)?\\. \\(([0-9]{4})\\)$')[, 2:3]
    author <- comps_[1]
    year <- comps_[2]

    if(is.na(title)) stop('title missing or misformatted?')
    if(is.na(author)) stop('author missing or misformatted?')
    if(is.na(year)) stop('year missing or misformatted?')

    key <- paste(tolower(str_extract(author, '^.+?(?=,)')),
                 tolower(str_extract(title, '^.+?(?= )')),
                 year,
                 sep = '_')

    if(is.na(key)) stop('author or title missing/misformatted?')

    title <- gsub('\\b([A-Z][a-z]*)\\b', '{\\1}', title)

    author <- gsub('\\., (?:& )?', '. and ', author)
    author <- gsub(', & ', ' and ', author)
    if(grepl(' [A-Z]$', author)) author <- paste0(author, '.')
    author <- sub('\\.\\.$', '.', author)
    author <- gsub(', ([A-Z]\\.) ([A-Z]\\.)', ', \\1\\2', author)

    #prevent institutional authors from being interpreted as people
    for(ii in institutional_authors){
        author <- gsub(ii, paste0('{', ii, '}'), author,
                       fixed = TRUE)
    }

    pubid <- sapply(known_publishers,
                  function(x) str_detect(fixed(comps[2]), fixed(x)),
                  USE.NAMES = FALSE) %>%
        which()

    if(! length(pubid)) stop('unknown/missing publisher detected:\n', citation)

    pub <- known_publishers[pubid]

    url <- sub(paste0(pub, '\\. '), '', comps[2])
    url <- str_extract(url, 'https?://.+')

    if(is.na(url)) stop('url/doi missing/misformatted?')

    if(list){
        components <- list(
            author = author,
            year = year,
            title = title,
            publisher = pub,
            url = url
        )

        return(components)
    }

    doi_url <- ifelse(grepl('^https?://doi\\.org', url), 'doi', 'url')

    if(grepl('Journal|Resour\\.', pub)){

        bib <- glue('\n@article{', key,
                    ',\n\ttitle = {', title,
                    '},\n\t', doi_url, ' = {', url,
                    '},\n\tjournal = {', pub,
                    '},\n\tauthor = {', author,
                    '},\n\tyear = {', year,
                    '}\n}\n',
                    .open = '<<', .close = '>>',
                    .trim = FALSE)

    } else {

        bib <- glue('\n@misc{', key,
                    ',\n\ttitle = {', title,
                    '},\n\tpublisher = {', pub,
                    '},\n\tauthor = {', author,
                    '},\n\tyear = {', year,
                    '},\n\t', doi_url, ' = {', url,
                    '}\n}\n',
                    .open = '<<', .close = '>>',
                    .trim = FALSE)
    }

    return(bib)
}

update_prov_dt <- function(sitecd = NULL, dt, usgs = FALSE){

    #a USGS site code if usgs = TRUE, or leave empty if not
    #dt: a datetime object

    if(usgs){
        if(is.null(sitecd)) stop('sitecd must be supplied if usgs = TRUE')
        site_match <- grepl(sitecd, site_doi_license$link)
    } else {
        site_match <- TRUE
    }

    rowind <- which(
        site_doi_license$network == network &
            site_doi_license$domain == domain &
            site_doi_license$macrosheds_prodcode == prodcode_from_prodname_ms(prodname_ms) &
            site_match
    )

    if(length(rowind) == 0 && domain != 'krycklan') stop('provenance rows not yet entered?')
    if(length(rowind) > 1 && domain != 'krycklan') stop('more than one provenance row selected')

    dt <- paste(format(with_tz(dt, 'UTC'),
                       '%Y-%m-%d %H:%M:%S'),
                'UTC')

    site_doi_license$link_download_datetime[rowind] <- dt

    ms_write_confdata(site_doi_license,
                      which_dataset = 'site_doi_license',
                      to_where = 'remote',
                      overwrite = TRUE)
}

update_provenance <- function(url, last_download_dt){

    rowind <- which(
        site_doi_license$network == network &
            site_doi_license$domain == domain &
            site_doi_license$macrosheds_prodcode == prodcode_from_prodname_ms(prodname_ms)
    )

    if(length(rowind) != 1) stop('something wrong with provenance for this product')

    prov <- site_doi_license[rowind, ]

    page <- read_html(url)

    if(grepl('portal.edirepository', url)){

        doi <- page %>% html_text() %>% str_extract("10\\.\\d{4,9}/[-._;()/:A-Za-z0-9]+")
        citation_text_ <- page %>% html_node("#citation") %>% html_text()
        citation_text <- convert_EDI_to_APA(citation_text_, prov)

    } else if(grepl('hydroshare.org', url)){

        doi <- site_doi_license$doi[rowind]
        citation_text_ <- page %>% html_node('#citation-text') %>% html_text()
        citation_text <- convert_hydroshare_to_APA(citation_text_, prov)

    } else {
        warning('Provenance update required (citation_and_intellectual_rights googlesheet).')
    }

    cat('old citation:\n', citation_text_, '\n')
    cat('new citation:\n', citation_text, '\n\n')

    cites_match <- ! is.na(site_doi_license$citation[rowind]) &&
        citation_text == site_doi_license$citation[rowind]
    doi_match_or_missing <-
        ((is.na(doi) && is.na(site_doi_license$doi[rowind])) ||
             doi == site_doi_license$doi[rowind])
    url_match <- url == site_doi_license$link[rowind]

    if(cites_match && doi_match_or_missing && url_match){
        return()
    }

    site_doi_license$citation[rowind] <- citation_text
    site_doi_license$doi[rowind] <- doi
    site_doi_license$link[rowind] <- url
    site_doi_license$link_download_datetime[rowind] <- last_download_dt

    ms_write_confdata(site_doi_license, 'site_doi_license', 'remote', overwrite = TRUE)
}

check_for_updates_hydroshare <- function(oldlink, last_download_dt){

    page <- read_html(oldlink)
    nodes <- html_nodes(page, '.col-xs-12')

    newlink <- NA
    for(node in nodes){
        text <- html_text(node)
        if(str_detect(text, 'A newer version of this resource')){
            link_node <- html_node(node, 'a')
            newlink <- html_attr(link_node, 'href')
            break
        }
    }

    #if there's a link to a new version, look no further
    if(! is.na(newlink)){
        print(paste('New link:', newlink))
        return(newlink)
    }

    #otherwise check the last modified date and see if we already have it
    lastmod_ <- page %>%
        html_nodes(xpath = '//th[contains(text(), "Last updated:")]/following-sibling::td[1]') %>%
        html_text() %>%
        str_trim() %>%
        str_extract('\\w+ \\d{1,2}, \\d{4} at \\d{1,2}:?\\d* [ap].m.')

    lastmod <- suppressWarnings(try(mdy_hm(lastmod_), silent = TRUE))
    if(inherits(lastmod, 'try-error') || is.na(lastmod)){
        lastmod <- mdy_h(lastmod_)
    }

    if(! length(lastmod)){
        stop('"Last updated" date was not provided or could not be scraped for ', i)
    }

    if(! is.na(last_download_dt) && lastmod > as_datetime(last_download_dt)){
        print('old resource updated')
    }

    return('all good')
}

check_for_updates_edi <- function(oldlink, last_download_dt){

    page <- read_html(oldlink)
    node <- html_node(page, 'div h2 font[color="darkorange"] a')

    newlink <- if(!is.null(node)) html_attr(node, 'href') else NA

    #if there's a link to a new version, look no further
    if(! is.na(newlink)){
        newlink <- paste0('https://portal.edirepository.org/nis/',
                          newlink)
        print(paste('New link:', newlink))
        return(newlink)
    }

    #otherwise check the last modified date and see if we already have it
    lastmod <- page %>%
        html_node('div.table-cell > ul > li > em') %>%
        html_text() %>%
        str_trim() %>%
        str_extract('\\d{4}-\\d{2}-\\d{2}') %>%
        ymd()

    if(! length(lastmod) | is.na(lastmod)){
        stop('"Updated" date was not provided or could not be scraped for ', i)
    }

    if(! is.na(last_download_dt)){
        if(lastmod > as_date(last_download_dt)){
            print('old resource updated')
        } else if(lastmod == as_date(last_download_dt)){
            stop(paste('old resource updated? updated AND last retrieved on same date:', lastmod))
        }
    }

    return('all good')
}

is_selenium_running <- function(port){

    #check if the Selenium Server is already running
    res <- try(httr::GET(paste0("http://localhost:", port, '/wd/hub/status')),
               silent = TRUE)

    running <- ifelse(! inherits(res, 'try-error') && httr::status_code(res) == 200,
                      TRUE,
                      FALSE)
    return(running)
}

selenium_scrape <- function(url, css_selector, web_browser = 'firefox', ...){

    if(! require('RSelenium')){
        stop('RSelenium is required to use this function')
    }

    # Start a Selenium Server and open a browser
    driver <- rsDriver(browser = web_browser, ...)
    remote_driver <- driver$client

    remote_driver$navigate(url)
    Sys.sleep(7)

    page_source <- remote_driver$getPageSource()[[1]]

    # Use rvest to parse the HTML
    page <- rvest::read_html(page_source)
    string_out <- page %>%
        rvest::html_element(css_selector) %>%
        rvest::html_text()

    remote_driver$close()

    return(string_out)
}

collect_retrieval_details <- function(url){

    ##maybe still try this first?
    # res <- httr::HEAD(url)
    #
    # last_mod_dt <- strptime(x = substr(res$headers$`last-modified`,
    #                                    start = 1,
    #                                    stop = 19),
    #                         format = '%Y-%m-%dT%H:%M:%S') %>%
    #     with_tz(tzone = 'UTC')
    #
    # deets_out <- list(url = paste(url, '(requires authentication)'),
    #                   access_time = as.character(with_tz(Sys.time(),
    #                                                      tzone = 'UTC')),
    #                   last_mod_dt = last_mod_dt)

    headers <- RCurl::getURL(url,
                             nobody = 1L,
                             header = 1L,
                             httpheader = list('Accept-Encoding' = 'identity'))

    last_mod_dt <- str_match(headers, '[lL]ast-[mM]odified: (.*)')[, 2]
    last_mod_dt <- httr::parse_http_date(last_mod_dt) %>%
        with_tz('UTC')

    retrieval_details <- list(
        url = url,
        access_time = as.character(with_tz(Sys.time(),
                                           tzone = 'UTC')),
        last_mod_dt = last_mod_dt
    )

    return(retrieval_details)
}

update_detlims <- function(d, vars_units){

    #for all ms_status == 2, take the corresponding val and write it to
    #the detection_limits google sheet
    #
    #vars_units: a named vector of variables and their units as provided by the primary source.
    #e.g. c('ANC' = 'ueq/l', ...)
    #note that in MacroSheds, ANC is given in eq/l. This is determined automatically.

    #if start_date and end_date are provided, this function needs to be modified

    names_units <- tibble(variable_original = names(vars_units),
                          unit_original = unname(vars_units)) %>%
        left_join(select(ms_vars, variable_code, unit),
                  by = c(variable_original = 'variable_code'))

    detlim_pre <- d %>%
        filter(ms_status == 2) %>%
        distinct(var, val, .keep_all = TRUE) %>%
        mutate(start_date = as.Date(datetime),
               var = drop_var_prefix(var)) %>%
        select(start_date, var, val) %>%
        arrange(var, start_date) %>%
        group_by(var) %>%
        mutate(end_date = lead(start_date) - 1) %>%
        ungroup() %>%
        left_join(names_units, by = c('var' = 'variable_original')) %>%
        rename(detection_limit_original = val,
               variable_original = var) %>%
        mutate(domain = !!domain,
               prodcode = !!prodname_ms,
               # variable_converted = NA,
               # variable_original = ,
               detection_limit_converted = NA,
               detection_limit_original = abs(detection_limit_original),
               precision = NA,
               sigfigs = NA,
               # unit_converted = ,
               # unit_original = ,
               # start_date = ,
               # end_date = ,
               added_programmatically = FALSE)

    detlims <- standardize_detection_limits(
        dls = detlim_pre,
        vs = ms_vars,
        update_on_gdrive = FALSE
    ) %>%
        mutate(added_programmatically = TRUE)

    detlims_update <- anti_join(
        detlims, domain_detection_limits,
        by = c('domain', 'prodcode', 'variable_converted', 'variable_original',
               'detection_limit_original', 'start_date', 'end_date')
    )

    if(nrow(detlims_update)){
        ms_write_confdata(detlims_update,
                          which_dataset = 'domain_detection_limits',
                          to_where = 'remote',
                          overwrite = FALSE) #append
    }

    return(invisible())
}

null_device <- function(){
    if(.Platform$OS.type == 'windows'){
        return('NUL')
    } else {
        return('/dev/null')
    }
}

runoff_to_discharge <- function(x, ws_area_ha){

    #convert from mm/d to L/s

    #x: a vector of runoff in mm/d
    #ws_area_ha: watershed area in hectares

    if(is.na(ws_area_ha)) stop('ws_area_ha is missing')

    ws_area_m2 <- ws_area_ha * 10^4

    # x <- x / 1000 #m/d
    # x <- x / 86400 #m/s
    # x <- x * ws_area_m2 #m^3/s
    # x <- x * 1000 #L/s

    lps <- as.numeric(x) * ws_area_m2 / 86400

    return(lps)
}

discharge_to_runoff <- function(x, ws_area_ha){

    #x: a vector of discharge in L/s
    #ws_area_ha: watershed area in hectares

    if (is.na(ws_area_ha)) stop('ws_area_ha is missing')

    ws_area_m2 <- ws_area_ha * 10^4

    #x <- x / 1000 #m^3/s
    #x <- x / ws_area_m2 #m/s
    #x <- x * 86400 #m/d
    #x <- x * 1000 #mm/d

    mm_per_day <- as.numeric(x) * 86400 / ws_area_m2

    return(mm_per_day)
}

get_ldas_precip <- function(lat, lon, startdate = NULL, enddate = NULL){

    #lat = numeric latitude, WGS84. negative for southern hemisphere
    #lon = numeric longitude, WGS84. negative for western hemisphere
    #startdate = either a date object or a string in YYYY-MM-DD format
    #enddate = either a date object or a string in YYYY-MM-DD format

    #returns data.frame of daily precip
    startdate <- as.Date(startdate)
    enddate <- as.Date(enddate)

    message('this probably doesnt work anymore. update API calls to use v2 products here: https://disc.gsfc.nasa.gov/information/tools?title=Hydrology%20Data%20Rods. check streampulse code for air pressure example')
    browser()

    # if(startdate < as.Date('1979-01-01')) stop('use load_prism_precip for this (not yet implemented)')
    if(enddate < as.Date('1979-01-01')){
        logwarn('all precip gaps before 1979 (get_ldas_precip no-op)',
                logger = logger_module)
        return(tibble())
    }

    if(startdate < as.Date('1979-01-01')){
        logwarn('precip gaps before 1979 (get_ldas_precip will leave empty)',
                logger = logger_module)
        startdate <- as.Date('1979-01-02')
    }

    ##prep
    if(startdate == enddate) enddate <- enddate + lubridate::days(1)
    startdate <- as.character(startdate)
    enddate <- as.character(enddate)

    tmp_dir <- file.path(tempdir(), 'ldas')
    dir.create(tmp_dir,
               recursive = TRUE,
               showWarnings = FALSE)

    tempf <- file.path(tmp_dir,
                       paste0('precip', as.numeric(Sys.time()), '.dat'))

    ##make NLDAS request
    endpoint <- 'https://hydro1.gesdisc.eosdis.nasa.gov/daac-bin/access/timeseries.cgi?variable=NLDAS:NLDAS_FORA0125_H.002:'
    param <- 'APCPsfc' #hourly precip in kg/m^2
    location <- paste0('&location=GEOM:POINT(', lon, ',%20', lat, ')')
    daterange <- paste0('&startDate=', startdate, 'T00&endDate=', enddate, 'T23')
    type = '&type=asc2'
    req <- paste0(endpoint, param, location, daterange, type)

    download.file(url = req, method = 'curl', destfile = tempf)
    contents <- read_fwf(tempf,
                         skip = 40,
                         fwf_cols(datetime = 22, precip_mm = 100),
                         show_col_types = FALSE)

    if(nrow(contents) && !
       (nrow(contents) == 1 && is.na(contents$datetime[1]))){

        d <- contents %>%
            slice(-nrow(.)) %>%
            mutate(datetime = ymd_h(datetime)) %>%
            mutate(date = as.Date(datetime)) %>%
            group_by(date) %>%
            summarize(precip_mm = sum(precip_mm, na.rm = TRUE),
                      .groups = 'drop')

    } else {

        oob <- any(grepl('out of data coverage', read_lines(tempf)))
        if(oob){

            # if(startdate < as.Date('2000-01-01')) stop('need to implement something else')
            if(enddate < as.Date('2000-01-01')){
                logwarn('non-CONUS and all precip gaps before 2000 (get_ldas_precip no-op)',
                        logger = logger_module)
                return(tibble())
            }

            if(startdate < as.Date('2000-01-01')){
                logwarn('non-CONUS and precip gaps before 2000 (get_ldas_precip will leave empty)',
                        logger = logger_module)
                startdate <- '2000-01-01'
                daterange <- paste0('&startDate=', startdate, 'T00&endDate=', enddate, 'T23')
            }

            #use GLDAS instead of NLDAS
            endpoint <- 'https://hydro1.gesdisc.eosdis.nasa.gov/daac-bin/access/timeseries.cgi?variable=GLDAS2:GLDAS_NOAH025_3H_v2.1:'
            param <- 'Rainf_f_tavg' #3-hourly precip in kg/m^2/s
            req <- paste0(endpoint, param, daterange, location, type)

            download.file(url = req, method = 'curl', destfile = tempf)
            contents <- read_fwf(tempf,
                                 skip = 13,
                                 fwf_cols(datetime = 19, precip_mm_s = 100),
                                 show_col_types = FALSE)

            d <- contents %>%
                mutate(date = as.Date(datetime)) %>%
                group_by(date) %>%
                summarize(precip_mm = sum(precip_mm_s, na.rm = TRUE) * 86400,
                          .groups = 'drop')
        }
    }

    unlink(tempf)

    return(d)
}

load_prism_precip <- function(site, startdate = NULL, enddate = NULL){

    #site: macrosheds site_code
    #startdate: either a date object or a string in YYYY-MM-DD format
    #enddate: either a date object or a string in YYYY-MM-DD format

    #returns data.frame of daily precip. ms_general() must have already
    #retrieved prism_precip for this site.

    #INCOMPLETE. SEE 2025 NOTES

    if(enddate >= as.Date('1979-01-01')) stop('use get_ldas_precip for this')

    ##prep
    startdate <- as.character(startdate)
    enddate <- as.character(enddate)

    prism_file <- glue('data/{network}/{domain}/ws_traits/cc_precip/raw_{site}.feather')
    # if()
    # read_feather()
    #...

    return(d)
}

propagate_sentinel <- function(d){

    #d: a macrosheds tibble of DAILY data

    #The sentinel value -13254, within the val column, is recognized as representing
    #a meaningful NA in the original data (this only pertains to precip and pchem),
    #soon to be imputed. Whenever -13254 is encountered, all preceding days
    #(15-m data have been abandoned at the time of this writing) are given the
    #sentinel value instead of val_fill.

    stnl <- -13254 #a sentinel value that represents meaningful NAs in d.

    sentinel_indices <- which(d$val == stnl)

    for(idx in sentinel_indices){
        # Find last non-NA and non-sentinel value before the sentinel
        non_na_before <- max(c(0, na.omit(ifelse(d$val[1:(idx - 1)] != stnl, 1:(idx - 1), NA))))
        # Fill NAs from last non-NA, non-sentinel to just before the sentinel
        if(non_na_before > 0 && any(is.na(d$val[(non_na_before + 1):(idx - 1)]))){
            d$val[(non_na_before + 1):(idx - 1)] <- stnl
        }
    }

    return(d)
}

get_missing_date_ranges <- function(d){

    d$datetime <- as.Date(d$datetime)
    na_indices <- which(is.na(d$val))
    ranges <- list()

    if(length(na_indices)){

        # breaks <- c(na_indices[which(diff(na_indices) > 1)],
        #             na_indices[length(na_indices)])
        # starts <- c(na_indices[1],
        #             na_indices[which(diff(na_indices) > 1) + 1])

        # for(i in seq_along(starts)){
        for(i in seq_along(na_indices)){

            if(na_indices[i] - 1 > 0){
                first_unknown_date <- d$datetime[na_indices[i] - 1] + 1
                ranges[[i]] <- seq(first_unknown_date,
                                   d$datetime[na_indices[i]],
                                   by = 'day')
            }# else {
            #    ranges[[i]] <- NA_Date_
            #}
            # if(starts - 1 > 0){
            #     ranges[[i]] <- seq(d$datetime[starts[i] - 1],
            #                        d$datetime[breaks[i]],
            #                        by = 'day')
            # } else {
            #     ranges[[i]] <- NA_Date_
            # }
        }

        ranges <- Filter(function(x) ! is.null(x), ranges)
    }

    return(ranges)
}

split_on_date <- function(na_dates, split_date){

    #na_dates: a list of vectors of dates
    #split_date: character or Date

    #returns three lists containing the elements of na_dates, but split
    #into pre, post, and spanning the split_date

    split_date <- as.Date(split_date)

    starts_before <- sapply(na_dates, function(x) x[1] < split_date)
    ends_before <- sapply(na_dates, function(x) x[length(x)] < split_date)

    pre_ <- na_dates[starts_before & ends_before]
    post_ <- na_dates[! starts_before & ! ends_before]

    spans_ <- na_dates[starts_before & ! ends_before]
    split_segment <- list()
    if(length(spans_)){
        spn <- spans_[[1]]
        spans_ <- c(list(spn[spn < split_date]),
                    list(spn[spn >= split_date]))
    }

    out <- list(pre_ = pre_,
                post_ = post_,
                spans_ = spans_)

    return(out)
}

pre_interp_precip <- function(d){

    this_site <- d$site_code[1]

    siterow <- filter(site_data,
                      site_code == this_site,
                      site_type == 'rain_gauge',
                      in_workflow == 1)

    if(nrow(siterow) == 0) stop(this_site, ' missing from site data gsheet')
    if(nrow(siterow) > 1) stop(this_site, ' duplicated in site data gsheet')

    na_dates <- get_missing_date_ranges(d)

    if(! length(na_dates)) return(d)

    precip_fill <- get_ldas_precip(lat = siterow$latitude,
                                   lon = siterow$longitude,
                                   startdate = min(na_dates[[1]]),
                                   enddate = max(na_dates[[length(na_dates)]]))

    for(i in seq_along(na_dates)){

        na_set <- na_dates[[i]]
        if(na_set[1] < as.Date('1979-01-02')) next #NLDAS doesn't go back this far

        precip_sum <- precip_fill %>%
            filter(date >= na_set[1] & date <= na_set[length(na_set)]) %>%
            pull(precip_mm) %>%
            sum(., na.rm = TRUE)

        replacement_ind <- which(as.Date(d$datetime) == na_set[length(na_set)])

        if(length(replacement_ind) != 1) stop('should not happen')

        d$val[replacement_ind] <- precip_sum
    }

    return(d)
}

combine_precip_sources <- function(na_dates, site){

    #not finished. prism should be pulled from earth engine for each precip
    #gauge location. i was setting this up to retrieve prism by watershed from
    #our ws_traits directories, but that's crude. instead, for now, i'm just
    #letting historic precip gauge data gaps remain gaps.

    if(length(na_dates$pre_)){
        precip_pre <- load_prism_precip(site = this_site,
                                        startdate = min(na_dates$pre_[[1]]),
                                        enddate = max(na_dates$pre_[[length(na_dates$pre_)]]))
    }

    if(length(na_dates$post_)){
        precip_post <- get_ldas_precip(lat = siterow$latitude,
                                       lon = siterow$longitude,
                                       startdate = min(na_dates$post_[[1]]),
                                       enddate = max(na_dates$post_[[length(na_dates$post_)]]))
    }

    if(length(na_dates$spans_)){
        precip_span_A <- load_prism_precip(site = this_site,
                                           startdate = min(na_dates$spans_[[1]]),
                                           enddate = max(na_dates$spans_[[1]]))

        precip_span_B <- get_ldas_precip(lat = siterow$latitude,
                                         lon = siterow$longitude,
                                         startdate = min(na_dates$spans_[[2]]),
                                         enddate = max(na_dates$spans_[[2]]))
    }

    #combine etc here.
}

bind_older_ws_traits <- function(d){

    #locate existing ws_traits files and combine them with newly retrieved gee data

    if(! exists('trait_dir')){
        return(d)
    }

    if(setequal(c('datetime', 'site_code', 'var', 'val'), colnames(d))){
        datecol <- 'datetime'
        file_pre <- '^raw_'
    } else if(setequal(c('year', 'site_code', 'var', 'val'), colnames(d))){
        datecol <- 'year'
        file_pre <- '^sum_'
    } else {
        stop('something is wrong?')
    }

    fs <- list.files(trait_dir)
    if(any(grepl('raw_', fs)) && any(grepl('sum_', fs))){
        fs <- grep(file_pre, fs, value = TRUE)
    }

    d_old <- map_dfr(file.path(trait_dir, fs), read_feather)

    d_out <- bind_rows(d_old, d) %>%
        distinct() %>%
        arrange(site_code, !!datecol, var)

    if(any(duplicated(select(d_out, site_code, !!datecol, var)))){

        logwarn(paste0('updated values in ', prodname_ms,
                       '. time to fully rerun general for ', domain),
                logger = logger_module)

        d_out <- anti_join(d_old, d,
                           by = c(datecol, 'site_code', 'var')) %>%
            bind_rows(d) %>%
            arrange(site_code, !!datecol, var)
    }

    if(nrow(d_out) < nrow(d)) stop('nope')
    if(length(colnames(d_old))){
        if(nrow(anti_join(d_old, d_out, by = c(datecol, 'site_code', 'var')))) stop('nope')
        if(! setequal(colnames(d_old), colnames(d_out))) stop('nope')
    }

    return(d_out)
}

