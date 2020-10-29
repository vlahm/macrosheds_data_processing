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
                              prodname_ms){

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
        dir.create(sampling_dir, recursive = TRUE)
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

    site_names <- unique(df$site_name)

    for(p in 1:length(data_cols)){

        # var_name <- str_split_fixed(data_cols[p], '__', 2)[1]

        # df_var <- df %>%
        #     select(datetime, !!var_name := .data[[data_cols[p]]], site_name)

        all_sites <- tibble()
        for(i in 1:length(site_names)){

            # df_site <- df_var %>%
            df_site <- df %>%
                filter(site_name == !!site_names[i]) %>%
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
                    site_name = !!site_names[i],
                    starts := dates[starts],
                    stops := dates[stops],
                    # sum = sum(lengths, na.rm = TRUE), #superfluous
                    porportion = lengths / sum(lengths, na.rm = TRUE),
                    time = difftime(stops, starts, units = 'days'))

            # Sites with no record
            if(nrow(run_table) == 0){

                g_a <- tibble('site_name' = site_names[i],
                              'type' = 'NA',
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

                    g_a <- tibble('site_name' = site_names[i],
                                  'type' = 'G',
                                  'starts' = min(run_table$starts,
                                                 na.rm = TRUE),
                                  'interval' = round(Mode(run_table$values,
                                                          na.rm = TRUE)))
                }

                #Sites with consecutive samples are have a consistent interval
                if(nrow(test) != 0 && nrow(run_table) < 20){

                    g_a <- test %>%
                        select(site_name, starts, interval = values) %>%
                        group_by(site_name, interval) %>%
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
                    (nrow(test) == 0 && mean(run_table$values, na.rm = TRUE) < 1440) ||
                    (nrow(test) != 0 && nrow(run_table) > 20)
                ){ #could this be handed with else?

                    table_ <- run_table %>%
                        filter(porportion >= 0.05) %>%
                        mutate(type = 'I') %>%
                        select(starts, site_name, type, interval = values) %>%
                        mutate(interval = as.character(round(interval)))

                    table_var <- run_table %>%
                        filter(porportion <= 0.05)  %>%
                        group_by(site_name) %>%
                        summarise(starts = min(starts,
                                               na.rm = TRUE)) %>%
                        mutate(
                            type = 'I',
                            interval = 'variable') %>%
                        select(starts, site_name, type, interval)

                    g_a <- rbind(table_, table_var) %>%
                        arrange(starts)
                }
            }

            var_name_base <- str_split(string = data_cols[p],
                                       pattern = '__\\|')[[1]][1]

            interval_changes <- rle2(g_a$interval)$starts

            g_a <- g_a %>%
                mutate(
                    type = paste0(type,
                                  !!is_sensor[var_name_base]),
                    var = as.character(glue('{ty}_{vb}',
                                            ty = type,
                                            vb = var_name_base))) %>%
                slice(interval_changes)

            master[[prodname_ms]][[var_name_base]][[site_names[i]]] <-
                list('startdt' = g_a$starts,
                     'type' = g_a$type,
                     'interval' = g_a$interval)

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
                              prodname_ms){

    #This case is used (primarily for neon) when use of ms_read_raw and
    # ms_cast_flag are not used because of incaomptable data structures

    #checks
    if(!is.logical(is_sensor)){
        stop('is_sensor must be logical.')
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

    if(file.exists(sampling_file)){
        master <- jsonlite::fromJSON(readr::read_file(sampling_file))
    } else {
        dir.create(sampling_dir, recursive = TRUE)
        file.create(sampling_file)
        master <- list()
    }

    site_names <- unique(df$site_name)

    variables <- unique(df$var)

    all_vars <- tibble()
    for(p in 1:length(variables)){

        all_sites <- tibble()
        for(i in 1:length(site_names)){

            # df_site <- df_var %>%
            df_site <- df %>%
                filter(site_name == !!site_names[i]) %>%
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
                    site_name = !!site_names[i],
                    starts := dates[starts],
                    stops := dates[stops],
                    # sum = sum(lengths, na.rm = TRUE), #superfluous
                    porportion = lengths / sum(lengths, na.rm = TRUE),
                    time = difftime(stops, starts, units = 'days'))

            # Sites with no record
            if(nrow(run_table) == 0){

                g_a <- tibble('site_name' = site_names[i],
                              'type' = 'NA',
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

                    g_a <- tibble('site_name' = site_names[i],
                                  'type' = 'G',
                                  'starts' = min(run_table$starts,
                                                 na.rm = TRUE),
                                  'interval' = round(Mode(run_table$values,
                                                          na.rm = TRUE)))
                }

                #Sites with consecutive samples are have a consistent interval
                if(nrow(test) != 0 && nrow(run_table) < 20){

                    g_a <- test %>%
                        select(site_name, starts, interval = values) %>%
                        group_by(site_name, interval) %>%
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
                    (nrow(test) == 0 && mean(run_table$values, na.rm = TRUE) < 1440) ||
                    (nrow(test) != 0 && nrow(run_table) > 20)
                ){ #could this be handed with else?

                    table_ <- run_table %>%
                        filter(porportion >= 0.05) %>%
                        mutate(type = 'I') %>%
                        select(starts, site_name, type, interval = values) %>%
                        mutate(interval = as.character(round(interval)))

                    table_var <- run_table %>%
                        filter(porportion <= 0.05)  %>%
                        group_by(site_name) %>%
                        summarise(starts = min(starts,
                                               na.rm = TRUE)) %>%
                        mutate(
                            type = 'I',
                            interval = 'variable') %>%
                        select(starts, site_name, type, interval)

                    g_a <- rbind(table_, table_var) %>%
                        arrange(starts)
                }
            }

            interval_changes <- rle2(g_a$interval)$starts

            g_a <- g_a %>%
                mutate(
                    type = paste0(type,
                                  !!is_sensor),
                    new_var = glue('{ty}_{vb}',
                               ty = type,
                               vb = variables[p]),
                    var = variables[p]) %>%
                slice(interval_changes)

            master[[prodname_ms]][[variables[p]]][[site_names[i]]] <-
                list('startdt' = g_a$starts,
                     'type' = g_a$type,
                     'interval' = g_a$interval)

            all_sites <- rbind(all_sites, g_a)
        }
        all_vars <- rbind(all_sites, all_vars) %>%
            distinct(var, .keep_all = TRUE)
    }

    correct_names <- all_vars %>%
        select(site_name, new_var, var)

    df <- left_join(df, correct_names, by = c("site_name", "var")) %>%
        select(datetime, site_name, var=new_var, val, ms_status)

    readr::write_file(jsonlite::toJSON(master), sampling_file)

    return(df)
}

drop_var_prefix <- function(x){

    unprefixed <- substr(x, 4, nchar(x))

    return(unprefixed)
}

extract_var_prefix <- function(x){

    prefix <- substr(x, 1, 2)

    return(prefix)
}

ms_read_raw_csv <- function(filepath,
                            preprocessed_tibble,
                            datetime_cols,
                            datetime_tz,
                            datetime_optional_chars = ':',
                            site_name_col,
                            alt_site_name,
                            data_cols,
                            data_col_pattern,
                            alt_datacol_pattern,
                            is_sensor,
                            set_to_NA,
                            var_flagcol_pattern,
                            alt_varflagcol_pattern,
                            summary_flagcols){

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
    #site_name_col should eventually work like datetime_cols (in case site_name is
    #   separated into multiple components)

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
    #datetime_optional_chars: see "optional" argument to dt_format_to_regex
    #site_name_col: name of column containing site name information
    #alt_site_name: optional list. Names of list elements are desired site_names
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
    #   output_x, output_y, output_....
    #is_sensor: either a single logical value, which will be applied to all
    #   variable columns OR a named logical vector with the same length and names as
    #   data_cols. If the latter, names correspond to variable names in the file to be read.
    #   TRUE means the corresponding variable(s) was/were
    #   measured with a sensor (which may be susceptible to drift and/or fouling),
    #   FALSE means the measurement(s) was/were not recorded by a sensor. This
    #   category includes analytical measurement in a lab, visual recording, etc.
    #set_to_NA: For values such as 9999 that are proxies for NA values.
    #var_flagcol_pattern: optional string with same mechanics as the other
    #   pattern parameters. this one is for columns containing flag
    #   information that is specific to one variable. If there's only one
    #   data column, omit this argument and use summary_flagcols for all
    #   flag information.
    #alt_varflagcol_pattern: optional string with same mechanics as the other
    #   pattern parameters. just in case there are two naming conventions for
    #   variable-specific flag columns
    #summary_flagcols: optional unnamed vector of column names for flag columns
    #   that pertain to all variables

    #return value: a tibble of ordered and renamed columns, omitting any columns
    #   from the original file that do not contain data, flag/qaqc information,
    #   datetime, or site_name. All-NA data columns and their corresponding
    #   flag columns will also be omitted, as will rows where all data values
    #   are NA. Rows with NA in the datetime or site_name column are dropped.
    #   data columns are given type double. all other
    #   columns are given type character. data and flag/qaqc columns are
    #   given two-letter prefixes representing sample regimen
    #   (I = installed vs. G = grab; S = sensor vs N = non-sensor).
    #   Data and flag/qaqc columns are also given
    #   suffixes (__|flg and __|dat) that allow them to be cast into long format
    #   by ms_cast_and_reflag. ms_read_raw_csv does not parse datetimes.

    #checks
    filepath_supplied <- ! missing(filepath) && ! is.null(filepath)
    tibble_supplied <- ! missing(preprocessed_tibble) && ! is.null(preprocessed_tibble)
    if(filepath_supplied && tibble_supplied){
        stop(glue('Only one of filepath and preprocessed_tibble can be supplied. ',
                  'preprocessed_tibble is for rare circumstances only.'))
    }


    if(! datetime_tz %in% OlsonNames()){
        stop('datetime_tz must be included in OlsonNames()')
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

    #parse args; deal with missing args
    datetime_colnames <- names(datetime_cols)
    datetime_formats <- unname(datetime_cols)

    alt_datacols <- var_flagcols <- alt_varflagcols <- NA
    alt_datacol_names <- var_flagcol_names <- alt_varflagcol_names <- NA
    if(missing(summary_flagcols)){
        summary_flagcols <- NULL
    }

    if(missing(set_to_NA)) {
        set_to_NA <- NULL
    }

    if(missing(alt_site_name)) {
        alt_site_name <- NULL
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

    #combine all available column name mappings; assemble new name vector
    colnames_all <- c(data_cols, alt_datacols, var_flagcols, alt_varflagcols)
    na_inds <- is.na(colnames_all)
    colnames_all <- colnames_all[! na_inds]

    suffixes <- rep(c('__|dat', '__|dat', '__|flg', '__|flg'),
                    times = c(length(data_cols),
                              length(alt_datacols),
                              length(var_flagcols),
                              length(alt_varflagcols)))
    colnames_new <- paste0(colnames_all, suffixes)
    colnames_new <- colnames_new[! na_inds]

    colnames_all <- c(datetime_colnames, colnames_all)
    names(colnames_all)[1:length(datetime_cols)] <- datetime_colnames
    colnames_new <- c(datetime_colnames, colnames_new)

    if(! missing(site_name_col) && ! is.null(site_name_col)){
        colnames_all <- c('site_name', colnames_all)
        names(colnames_all)[1] <- site_name_col
        colnames_new <- c('site_name', colnames_new)
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

    if(! missing(site_name_col) && ! is.null(site_name_col)){
        class_sn <- 'character'
        names(class_sn) <- site_name_col
    }

    classes_all <- c(class_dt, class_sn, classes_d1, classes_d2, classes_f1,
                     classes_f2, classes_f3)
    classes_all <- classes_all[! is.na(names(classes_all))]

    if(filepath_supplied){
        d <- read.csv(filepath,
                      stringsAsFactors = FALSE,
                      colClasses = "character")
    } else {
        d <- preprocessed_tibble
    }

    d <- d %>%
        as_tibble() %>%
        select(one_of(c(names(colnames_all), 'NA.'))) #for NA as in sodium
    if('NA.' %in% colnames(d)) class(d$NA.) = 'character'

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


    #Set correct class to each column
    # suppressWarnings because it warns that NA are created by changing the class
    # of a column, this is what is wanted when there are character is a numeric
    d[] <- sw(Map(`class<-`, d, classes_all))

    #rename cols to canonical names
    colnames_d <- colnames(d)

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
    d <- resolve_datetime(d = d,
                          datetime_colnames = datetime_colnames,
                          datetime_formats = datetime_formats,
                          datetime_tz = datetime_tz,
                          optional = datetime_optional_chars)

    #remove rows with NA in datetime or site_name
    d <- filter(d,
                across(any_of(c('datetime', 'site_name')),
                       ~ ! is.na(.x)))

    #remove all-NA data columns and rows with NA in all data columns.
    #also remove flag columns for all-NA data columns.
    all_na_cols_bool <- apply(select(d, ends_with('__|dat')),
                              MARGIN = 2,
                              function(x) all(is.na(x)))
    all_na_cols <- names(all_na_cols_bool[all_na_cols_bool])
    all_na_cols <- c(all_na_cols,
                     sub(pattern = '__\\|dat',
                         replacement = '__|flg',
                         all_na_cols))

    d <- d %>%
        select(-one_of(all_na_cols)) %>%
        filter_at(vars(ends_with('__|dat')),
                  any_vars(! is.na(.)))

    #for duplicated datetime-site_name pairs, keep the row with the fewest NA
    #   values. We could instead do something more sophisticated.
    d <- d %>%
        rowwise(one_of(c('datetime', 'site_name'))) %>%
        mutate(NAsum = sum(is.na(c_across(ends_with('__|dat'))))) %>%
        ungroup() %>%
        arrange(datetime, site_name, NAsum) %>%
        select(-NAsum) %>%
        distinct(datetime, site_name, .keep_all = TRUE) %>%
        arrange(site_name, datetime)

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

    #fix sites names if multiple names refer to the same site
    if(! is.null(alt_site_name)){

        for(z in 1:length(alt_site_name)){

            d <- mutate(d,
                        site_name = ifelse(site_name %in% !!alt_site_name[[z]],
                                           !!names(alt_site_name)[z],
                                           site_name))
        }
    }

    #prepend two-letter code to each variable representing sample regimen and
    #record sample regimen metadata
    d <- sm(identify_sampling(df = d,
                              is_sensor = is_sensor,
                              domain = domain,
                              network = network,
                              prodname_ms = prodname_ms))

    return(d)
}

resolve_datetime <- function(d,
                             datetime_colnames,
                             datetime_formats,
                             datetime_tz,
                             optional){

    #d is a data.frame or tibble with at least one date or time column
    #   (all date and/or time columns must contain character strings,
    #   not parsed date/time/datetime objects)
    #datetime_colnames is a character vector of column names that contain
    #   relevantdatetime information
    #datetime_formats is a character vector of datetime parsing tokens
    #   (like '%A, %Y-%m-%d %I:%M:%S %p' or '%j') corresponding to the
    #   elements of datetime_colnames
    #   datetime_tz is the time zone of the returned datetime column
    #optional: see dt_format_to_regex

    #return value: d, but with a "datetime" column containing POSIXct datetimes
    #   and without the input datetime columns

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

    dt_col_order <- match(paste0('%',
                                 colnames(dt_tb)),
                          datetime_formats_split)

    dt_tb <- dt_tb %>%
        tidyr::unite(col = 'datetime',
                     everything(),
                     sep = ' ',
                     remove = TRUE) %>%
        mutate(datetime = as_datetime(datetime,
                                      format = paste(datetime_formats_split[dt_col_order],
                                                     collapse = ' '),
                                      tz = datetime_tz) %>%
                   with_tz(tz = 'UTC'))

    d <- d %>%
        bind_cols(dt_tb) %>%
        select(-one_of(datetime_colnames), datetime) %>%#in case 'datetime' is in datetime_colnames
        relocate(datetime)

    return(d)
}

dt_format_to_regex <- function(fmt, optional){

    #fmt is a character vector of datetime formatting strings, such as
    #   '%A, %Y-%m-%d %I:%M:%S %p' or '%j'. each element of fmt that is a
    #   datetime token is replaced with a regex string that matches
    #   the what the token represents. For example, '%Y' matches a 4-digit
    #   year and '[0-9]{4}' matches a 4-digit numeric sequence. non-token
    #   characters (anything not following a %) are not modified. Note that
    #   tokens B, b, h, A, and a are replaced by '[a-zA-Z]+', which matches
    #   any sequence of one or more alphabetic characters of either case,
    #   not just meaningful month/day names 'Weds' or 'january'. Also note
    #   that these tokens are not currently accepted: g, G, n, t, c, r, R, T.
    #optional is a character vector of characters that should be made
    #   optional in the exported regex (succeeded by a ?). This is useful if
    #   e.g. fmt is '%H:%M:%S' and elements to be matched may either appear in
    #   HH:MM:SS or HH:MM format. making the ":" character optional here
    #   (via optional = ':') allows the hour and minute data to be retained,
    #   whereas the regex engine would otherwise expect two ":"s, find
    #   only one, and return NA.

    dt_format_regex <- list(Y = '([0-9]{4})?',
                            y = '([0-9]{2})?',
                            B = '([a-zA-Z]+)?',
                            b = '([a-zA-Z]+)?',
                            h = '([a-zA-Z]+)?',
                            m = '([0-9]{1,2})?',
                            e = '([0-9]{1,2})?',
                            d = '([0-9]{2})?',
                            j = '([0-9]{3})?',
                            A = '([a-zA-Z]+)?',
                            a = '([a-zA-Z]+)?',
                            u = '([0-9]{1})?',
                            w = '([0-9]{1})?',
                            U = '([0-9]{2})?',
                            W = '([0-9]{2})?',
                            V = '([0-9]{2})?',
                            C = '([0-9]{2})?',
                            H = '([0-9]{2})?',
                            I = '([0-9]{2})?',
                            M = '([0-9]{2})?',
                            S = '([0-9]{2})?',
                            p = '([AP]M)?',
                            z = '([+\\-][0-9]{4})?',
                            `F` = '([0-9]{4}-[0-9]{2}-[0-9]{2})')

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
                               summary_flags_to_drop,
                               summary_flags_clean,
                               summary_flags_dirty){

    #TODO: add a silent = TRUE option. this would hide all warnings
    #allow for alternative pattern specifications.

    #d is a df/tibble with ONLY a site_name column, a datetime column,
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
    #   included in variable_flags_clean. This parameter is optional,
    #   though at least 2 of variable_flags_to_drop, variable_flags_clean,
    #   and variable_flags_dirty must be supplied if varflag_col_pattern is not
    #   set to NA.
    #   If '#*#' is used, variable_flags_clean must be supplied.
    #variable_flags_clean: a character vector of values that might appear in
    #   the variable flag columns. Elements of this vector are given an
    #   ms_status of 0, meaning clean. This parameter is optional, though at least 2
    #   of variable_flags_to_drop, variable_flags_clean, and variable_flags_dirty
    #   must be supplied if varflag_col_pattern is not
    #   set to NA. This parameter does not use the '#*#' wildcard.
    #variable_flags_dirty: a character vector of values that might appear in
    #   the variable flag columns. Elements of this vector are given an
    #   ms_status of 1, meaning dirty. This parameter is optional, though at least 2
    #   of variable_flags_to_drop, variable_flags_clean, and variable_flags_dirty
    #   must be supplied if varflag_col_pattern is not
    #   set to NA. This parameter does not use the '#*#' wildcard.
    #summary_flags_to_drop: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in
    #   the summary flag/status columns. Elements of these vectors are treated as
    #   bad data and are removed. Use '#*#' to refer to all values not
    #   included in summary_flags_clean. This parameter is optional, though
    #   if there are summary flag columns, at least 2
    #   of summary_flags_to_drop, summary_flags_clean, and summary_flags_dirty
    #   must be supplied (omit this argument otherwise).
    #   If '#*#' is used, summary_flags_clean must be supplied.
    #   make sure list elements for summary flags are in the same order!
    #   there is currently no check for this.
    #summary_flags_clean: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in the summary flag/status columns.
    #   Elements of these vectors are given an ms_status of 0, meaning clean.
    #   This parameter is optional, though
    #   if there are summary flag columns, at least 2 of summary_flags_to_drop,
    #   summary_flags_clean, and summary_flags_dirty must be supplied
    #   (omit this argument otherwise).
    #   make sure list elements for summary flags are in the same order!
    #   there is currently no check for this.
    #   Note: This parameter does not use the '#*#' wildcard.
    #summary_flags_dirty: a named list. names correspond to columns in d that
    #   contain summary flag/status information. List elements must be character vectors
    #   of values that might appear in the summary flag/status columns.
    #   Elements of these vectors are given an ms_status of 1, meaning dirty.
    #   This parameter is optional, though
    #   if there are summary flag columns, at least 2 of summary_flags_to_drop,
    #   summary_flags_clean, and summary_flags_dirty must be supplied
    #   (omit this argument otherwise).
    #   make sure list elements for summary flags are in the same order!
    #   there is currently no check for this.
    #   Note: This parameter does not use the '#*#' wildcard.

    #return value: a long-format tibble with 5 columns: datetime, site_name,
    #   var, val, ms_status. Rows with NA in any column are removed.

    #arg checks
    if(! input_shape == 'wide'){
        stop('ms_cast_and_reflag only implemented for input_shape = "wide"')
    }

    sumdrop <- ! missing(summary_flags_to_drop) && ! is.null(summary_flags_to_drop)
    sumclen <- ! missing(summary_flags_clean) && ! is.null(summary_flags_clean)
    sumdirt <- ! missing(summary_flags_dirty) && ! is.null(summary_flags_dirty)
    no_sumflags <- all(c(sumdrop, sumclen, sumdirt) == FALSE)

    if(sum(c(sumdrop, sumclen, sumdirt)) == 1){
        stop(paste0('Must supply 2 (or none) of summary_flags_to_drop, ',
                    'summary_flags_clean, summary_flags_dirty'))
    }

    if(sumclen){
        if(any(sapply(summary_flags_clean, function(x) '#*#' %in% x))){
            stop(glue('the #*# wildcard may only be used in ',
                      'summary_flags_to_drop and variable_flags_to_drop'))
        }
    }
    if(sumdirt){
        if(any(sapply(summary_flags_dirty, function(x) '#*#' %in% x))){
            stop(glue('the #*# wildcard may only be used in ',
                      'summary_flags_to_drop and variable_flags_to_drop'))
        }
    }

    if(sumdrop){

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
    }

    vardrop <- ! missing(variable_flags_to_drop) && ! is.null(variable_flags_to_drop)
    varclen <- ! missing(variable_flags_clean) && ! is.null(variable_flags_clean)
    vardirt <- ! missing(variable_flags_dirty) && ! is.null(variable_flags_dirty)
    no_varflags <- is.na(varflag_col_pattern)

    if(sum(c(vardrop, varclen, vardirt)) < 2 && ! no_varflags){
        stop(paste0('Must supply at least 2 of variable_flags_to_drop, ',
                    'variable_flags_clean, variable_flags_dirty (or set ',
                    'varflag_col_pattern = NA)'))
    }

    if(vardrop){

        if('#*#' %in% variable_flags_to_drop && length(variable_flags_to_drop) > 1){
            stop(glue('if #*# wildcard is used in variable_flags_to_drop,',
                      ' it must be the only element in its argument vector'))
        }

        if(variable_flags_to_drop == '#*#' && ! varclen){
            stop(glue('if #*# wildcard is used in variable_flags_to_drop, ',
                      'variable_flags_clean must be supplied'))
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

    #remove rows with NA in the value column (these take up space and can be
    #reconstructed by casting to wide form
    d <- filter(d, ! is.na(dat))

    #filter rows with summary flags indicating bad data (data to drop)
    if(! no_sumflags){
        if(sumdrop){
            for(i in 1:length(summary_flags_to_drop)){

                smtd <- summary_flags_to_drop[i]

                if(length(smtd[[1]]) == 1 && smtd[[1]] == '#*#'){
                    d <- filter(d, (!!sym(names(smtd))) %in%
                                    summary_flags_clean[[i]])
                } else {
                    d <- filter(d, ! (!!sym(names(smtd))) %in% smtd)
                }
            }

        } else {

            for(i in 1:length(summary_flags_clean)){
                d <- filter(d, (!!sym(names(summary_flags_clean)[i])) %in%
                                c(summary_flags_clean[[i]],
                                  summary_flags_dirty[[i]]))
            }
        }
    }

    #filter rows with variable flags indicating bad data (data to drop)
    if(! no_varflags){
        if(vardrop){

            if(variable_flags_to_drop == '#*#'){
                d <- filter(d, flg %in% variable_flags_clean)
            } else {
                d <- filter(d, ! flg %in% variable_flags_to_drop)
            }

        } else {
            d <- filter(d, flg %in% c(variable_flags_clean, variable_flags_dirty))
        }
    }

    #binarize remaining flag information (0 = clean, 1 = dirty)
    if(! no_varflags){
        if(varclen){
            d <- mutate(d, ms_status = case_when(
                flg %in% variable_flags_clean ~ 0,
                TRUE ~ 1))
        } else {
            d <- mutate(d, ms_status = case_when(
                flg %in% variable_flags_dirty ~ 1,
                TRUE ~ 0))
        }
    } else {
        d$ms_status <- 0
    }

    if(! no_sumflags){
        if(sumclen){
            for(i in 1:length(summary_flags_clean)){
                si <- summary_flags_clean[i]
                flg_bool <- ! d[[names(si)]] %in% si[[1]]
                d$ms_status[flg_bool] <- 1
            }
        } else {
            for(i in 1:length(summary_flags_dirty)){
                si <- summary_flags_dirty[i]
                flg_bool <- d[[names(si)]] %in% si[[1]]
                d$ms_status[flg_bool] <- 1
            }
        }
    }

    #rearrange columns (this also would have to be flexified if we ever want
    #   to pass something other than the default for data_col_pattern or
    #   varflag_col_pattern
    d <- d %>%
        select(-one_of(c(summary_colnames, 'flg'))) %>%
        select(datetime, site_name, var, dat, ms_status) %>%
        rename(val = dat) %>%
        arrange(site_name, var, datetime)

    return(d)
}

ms_conversions <- function(d,
                           convert_molecules = c('NO3', 'SO4', 'PO4', 'SiO2',
                                                 'NH4', 'NH3'),
                           convert_units_from,
                           convert_units_to){

    #d: a macrosheds tibble that has aready been through ms_cast_and_reflag
    #convert molecules: a character vector of molecular formulae to be
    #   converted from molecular mass to atomic mass of the main constituent.
    #   for example, NO3 should be converted to NO3-N within macrosheds, so pass
    #   'NO3' to convert_molecules and it will take care of everything. by default,
    #   all molecules we want to convert are already passed. The only time
    #   you might want to change this default argument is if a domain provides
    #   both forms (e.g. PO4 and PO4-P). In that case, we might want to keep both,
    #   so we would omit 'PO4' from the argument vector to convert_molecules.
    #convert_units_from: a named character vector. Names are variable names
    #   without their sample-regimen prefixes (e.g. 'DIC', not 'GN_DIC'),
    #   and values are the units of those variables. Omit variables that don't
    #   need to be converted.
    #convert_units_to: a named character vector. Names are variable names
    #   without their sample-regimen prefixes (e.g. 'DIC', not 'GN_DIC'),
    #   and values are the units those variables should be converted to.
    #   Omit variables that don't need to be converted.

    #checks
    cm <- ! missing(convert_molecules)
    cuF <- ! missing(convert_units_from) && ! is.null(convert_units_from)
    cuT <- ! missing(convert_units_to) && ! is.null(convert_units_to)

    if(sum(cuF, cuT) == 1){
        stop('convert_units_from and convert_units_to must be supplied together')
    }
    if(length(convert_units_from) != length(convert_units_to)){
        stop('convert_units_from and convert_units_to must have the same length')
    }
    cu_shared_names <- base::intersect(names(convert_units_from),
                                       names(convert_units_to))
    if(length(cu_shared_names) != length(convert_units_to)){
        stop('names of convert_units_from and convert_units_to must match')
    }

    vars <- drop_var_prefix(d$var)

    # Converts input to grams (even if the final unit is moles or eq, it will be
    # converted to grams so it can be converted from NO3 to NO3 in N)
    for(i in 1:length(convert_units_from)) {

        if(grepl('mol|eq', convert_units_from[i]) && grepl('g', convert_units_to[i])) {

            v = names(convert_units_from)[i]

            d$val[vars == v] <- convert_to_gl(x = d$val[vars == v],
                                              input_unit = convert_units_from[i],
                                              molecule = v)
        }
    }

    #convert units
    if(cuF){
        for(i in 1:length(convert_units_from)){
            v = names(convert_units_from)[i]
            d$val[vars == v] <- convert_unit(x = d$val[vars == v],
                                             input_unit = convert_units_from[i],
                                             output_unit = convert_units_to[i])
        }
    }

    #handle molecular conversions, like NO3 -> NO3_N
    if(cm){
        molecular_conversion_map <- list(
            NH4 = 'N',
            NO3 = 'N',
            NH3 = 'N',
            SiO2 = 'Si',
            SO4 = 'S',
            PO4 = 'P')
        if(! all(convert_molecules %in% names(molecular_conversion_map))){
            miss <- convert_molecules[! convert_molecules %in%
                                          names(molecular_conversion_map)]
            stop(glue('These molecules either need to be added to ',
                      'molecular_conversion_map, or they should not be converted: ',
                      paste(miss, collapse = ', ')))
        }

    }

    for(m in convert_molecules){
        d$val[vars == m] <- convert_molecule(x = d$val[vars == m],
                                             from = m,
                                             to = unname(molecular_conversion_map[m]))
    }

    #Convert to mol or eq if that is the output unit
    for(i in 1:length(convert_units_from)) {

        if(grepl('mol|eq', convert_units_to[i])) {
            v = names(convert_units_from)[i]

            d$val[vars == v] <- convert_from_gl(x = d$val[vars == v],
                                                input_unit = convert_units_from[i],
                                                output_unit = convert_units_to[i],
                                                molecule = v)
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

    #return()
}

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

generate_blacklist_indicator = function(text=1){
    indobj = text
    class(indobj) = 'blacklist_indicator'
    return(indobj)
}

is_ms_err <- function(x){
    return('ms_err' %in% class(x))
}

is_ms_exception <- function(x){
    return('ms_exception' %in% class(x))
}

is_blacklist_indicator <- function(x){
    return('blacklist_indicator' %in% class(x))
}

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

email_err <- function(msgs, addrs, pw){

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

insert_site_skeleton <- function(tracker, prodname_ms, site_name,
                                 site_components){

    tracker[[prodname_ms]][[site_name]] =
        make_tracker_skeleton(retrieval_chunks=site_components)

    return(tracker)
}

product_is_tracked <- function(tracker, prodname_ms){
    bool = prodname_ms %in% names(tracker)
    return(bool)
}

site_is_tracked <- function(tracker, prodname_ms, site_name){
    bool = site_name %in% names(tracker[[prodname_ms]])
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

    #return()
}

update_data_tracker_m <- function(network = domain,
                                  domain,
                                  tracker_name,
                                  prodname_ms,
                                  site_name,
                                  new_status){

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

    #return()
}

update_data_tracker_d <- function(network = domain,
                                  domain,
                                  tracker = NULL,
                                  tracker_name = NULL,
                                  prodname_ms = NULL,
                                  site_name = NULL,
                                  new_status = NULL){

    #this updates the derive section of a data tracker in memory and on disk.
    #see update_data_tracker_r for the retrieval section and
    #update_data_tracker_m for the munge section

    #if tracker is supplied, it will be used to write/overwrite the one on disk.
    #if it is omitted or set to NULL, the appropriate tracker will be loaded
    #from disk, updated, and then written back to disk. tracker_name, set_details,
    #and new_status must be supplied if tracker is not.

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

    #return()
}

update_data_tracker_g <- function(network = domain,
                                  domain,
                                  tracker = NULL,
                                  tracker_name = NULL,
                                  prodname_ms = NULL,
                                  site_name = NULL,
                                  new_status = NULL){

    #this updates the general section of a data tracker in memory and on disk.
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

        dt = tracker[[prodname_ms]][[site_name]]$general

        if(is.null(dt)){
            return(generate_ms_exception('Product not yet tracked; no action taken.'))
        }

        dt$status = new_status
        dt$mtime = as.character(Sys.time())

        tracker[[prodname_ms]][[site_name]]$general = dt

        assign(tracker_name, tracker, pos=.GlobalEnv)
    }

    trackerfile = glue('data/{n}/{d}/data_tracker.json', n=network, d=domain)
    readr::write_file(jsonlite::toJSON(tracker), trackerfile)
    backup_tracker(trackerfile)

    #return()
}

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

    #return()
}

extract_retrieval_log <- function(tracker, prodname_ms, site_name,
                                  keep_status='ok'){

    retrieved_data = tracker[[prodname_ms]][[site_name]]$retrieve %>%
        tibble::as_tibble() %>%
        filter(status == keep_status)

    return(retrieved_data)
}

get_munge_status <- function(tracker, prodname_ms, site_name){
    munge_status = tracker[[prodname_ms]][[site_name]]$munge$status
    return(munge_status)
}

get_derive_status <- function(tracker, prodname_ms, site_name){
    derive_status = tracker[[prodname_ms]][[site_name]]$derive$status
    return(derive_status)
}

get_general_status <- function(tracker, prodname_ms, site_name){
    general_status = tracker[[prodname_ms]][[site_name]]$general$status
    return(general_status)
}

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

ms_retrieve <- function(network=domain, domain){
    source(glue('src/{n}/{d}/retrieve.R', n=network, d=domain))
    #return()
}

ms_munge <- function(network=domain, domain){
    source(glue('src/{n}/{d}/munge.R', n=network, d=domain))
    #return()
}

ms_delineate <- function(network, domain,
                         dev_machine_status,
                         verbose = FALSE){

    #dev_machine_status: either '1337', indicating that your machine has >= 16 GB
    #   RAM, or 'n00b', indicating < 16 GB RAM. DEM resolution is chosen
    #   accordingly. passed to delineate_watershed_apriori
    #verbose: logical. determines the amount of informative messaging during run

    loginfo(msg = 'Beginning watershed delineation',
            logger = logger_module)

    site_locations <- sm(read_csv('data/general/site_data.csv')) %>%
        filter(
            as.logical(in_workflow),
            network == !!network,
            domain == !!domain,
            # ! is.na(latitude),
            # ! is.na(longitude),
            site_type == 'stream_gauge') %>%
        select(site_name, latitude, longitude, CRS, ws_area_ha)

    #checks
    if(any(is.na(site_locations$latitude) | is.na(site_locations$longitude))){

        missing_loc <- is.na(site_locations$latitude) |
            is.na(site_locations$longitude)

        missing_site_names <- site_locations$site_name[missing_loc]

        stop(glue('Missing/incomplete site location for:\nnetwork: {n}\ndomain: {d}\n',
                  'site(s): {ss}\n(data/general/site_data.csv)',
                  n = network,
                  d = domain,
                  ss = paste(missing_site_names,
                             collapse = ', ')))
    }

    if(any(is.na(site_locations$CRS))){

        missing_site_names <- site_locations$site_name[is.na(site_locations$CRS)]

        stop(glue('Missing CRS for:\nnetwork: {n}\ndomain: {d}\n',
                  'site(s): {ss}\n(data/general/site_data.csv)',
                  n = network,
                  d = domain,
                  ss = paste(missing_site_names,
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
        dir.create(glue('data/{n}/{d}/munged/{w}',
                        n = network,
                        d = domain,
                        w = ws_boundary_dir))
    }

    #for each stream gauge site, check for existing wb file. if none, delineate
    for(i in 1:nrow(site_locations)){

        site <- site_locations$site_name[i]

        if(verbose){
            print(glue('delineating {n}-{d}-{s} (site {sti} of {sl})',
                       n = network,
                       d = domain,
                       s = site,
                       sti = i,
                       sl = nrow(site_locations)))
        }

        site_dir <- glue('data/{n}/{d}/munged/{w}/{s}',
                         n = network,
                         d = domain,
                         w = ws_boundary_dir,
                         s = site)

        if(dir.exists(site_dir) && length(dir(site_dir))){
            message(glue('{s} already delineated ({d})',
                         s = site,
                         d = site_dir))
            next
        }

        dir.create(site_dir,
                   showWarnings = FALSE)

        specs <- read_wb_delin_specs(network = network,
                                     domain = domain,
                                     site_name = site) %>%
            filter(
                network == !!network,
                domain == !!domain,
                site_name == !!site)

        if(nrow(specs) == 1){

            message('Delineating from stored specifications')

            catch <- delineate_watershed_by_specification(
                lat = site_locations$latitude[i],
                long = site_locations$longitude[i],
                crs = site_locations$CRS[i],
                buffer_radius = specs$buffer_radius_m,
                snap_dist = specs$snap_distance_m,
                snap_method = specs$snap_method,
                dem_resolution = specs$dem_resolution,
                write_dir = site_dir)

            loginfo(msg = glue('Delineation complete: {n}-{d}-{s}',
                               n = network,
                               d = domain,
                               s = site),
                    logger = logger_module)

            next
            #everything that follows pertains to interactive selection of an
            #appropriate delineation

        } else if(nrow(specs) == 0){

            if(ms_instance$instance_type != 'dev'){
                stop(glue('Missing delineation specs for {n}-{d}-{s}. ',
                          'Delineate locally and push changes.',
                          n = network,
                          d = domain,
                          s = site))
            }

            inspection_dir <- delineate_watershed_apriori(
                lat = site_locations$latitude[i],
                long = site_locations$longitude[i],
                crs = site_locations$CRS[i],
                dev_machine_status = dev_machine_status,
                verbose = verbose)

        } else {
            stop('Multiple entries for same network/domain/site in site_data.csv')
        }

        files_to_inspect <- list.files(path = inspection_dir,
                                       pattern = '.shp')

        #if only one delineation, write it into macrosheds storage
        if(length(files_to_inspect) == 1){

            selection <- files_to_inspect[1]

            move_shapefiles(shp_files = selection,
                            from_dir = inspection_dir,
                            to_dir = site_dir)

            message(glue('Delineation successful. Shapefile written to ',
                         site_dir))

            #otherwise, technician must inspect all delineations and choose one
        } else {

            nshapes <- length(files_to_inspect)

            wb_selections <- paste(paste0('[',
                                          c(1:nshapes, 'A'),
                                          ']'),
                                   c(files_to_inspect, 'Abort delineation'),
                                   sep = ': ',
                                   collapse = '\n')

            helper_code <- glue('mapview::mapview(sf::st_read("{wd}/{f}"))',
                                wd = inspection_dir,
                                f = files_to_inspect) %>%
                paste(collapse = '\n\n')

            msg <- glue('Visually inspect the watershed boundary candidate shapefiles ',
                        'in {td}, then enter the number corresponding to the ',
                        'one that looks most legit. Here\'s some ',
                        'helper code you can paste into an R instance running ',
                        'in a shell (terminal):\n\n{hc}\n\nIf you aren\'t ',
                        'sure which is correct, get a site manager to verify:\n',
                        'request_site_manager_verification(type=\'wb delin\', ',
                        'network, domain)\n\nChoices:\n{sel}\n\nEnter choice here > ',
                        hc = helper_code,
                        sel = wb_selections,
                        td = inspection_dir)

            resp <- get_response_1char(msg = msg,
                                       possible_chars = c(1:nshapes, 'A'))

            if(resp == 'A'){
                message('Aborted. Completed delineations have been saved')
                return()
            }

            selection <- files_to_inspect[as.numeric(resp)]

            move_shapefiles(shp_files = selection,
                            from_dir = inspection_dir,
                            to_dir = site_dir,
                            new_name_vec = site)

            message(glue('Selection {s}:\n\t{sel}\nwas written to:\n\t{sdr}',
                         s = resp,
                         sel = selection,
                         sdr = site_dir))
        }

        #write the specifications of the correctly delineated watershed
        rgx <- str_match(selection,
                         paste0('^wb[0-9]+_BUF([0-9]+)(standard|jenson)',
                                'DIST([0-9]+)RES([0-9]+)\\.shp$'))

        write_wb_delin_specs(network = network,
                             domain = domain,
                             site_name = site,
                             buffer_radius = as.numeric(rgx[, 2]),
                             snap_method = rgx[, 3],
                             snap_distance = as.numeric(rgx[, 4]),
                             dem_resolution = as.numeric(rgx[, 5]))

        #calculate watershed area and write it to site_data.csv
        catch <- ms_calc_watershed_area(network = network,
                                        domain = domain,
                                        site_name = site,
                                        update_site_file = TRUE)
    }

    message(glue('Delineation specifications were written to:\n\t',
                 'data/general/watershed_delineation_specs.csv\n',
                 'watershed areas were written to:\n\t',
                 'data/general/site_data.csv'))

    loginfo(msg = 'Delineations complete',
            logger = logger_module)


    #return()
}

delineate_watershed_apriori <- function(lat, long, crs,
                                        dev_machine_status = 'n00b',
                                        verbose = FALSE){

    #lat: numeric representing latitude in decimal degrees
    #   (negative indicates southern hemisphere)
    #long: numeric representing longitude in decimal degrees
    #   (negative indicates west of prime meridian)
    #crs: numeric representing the coordinate reference system (e.g. WSG84)
    #dev_machine_status: either '1337', indicating that your machine has >= 16 GB
    #   RAM, or 'n00b', indicating < 16 GB RAM. DEM resolution is chosen accordingly
    #verbose: logical. determines the amount of informative messaging during run

    #returns the location of candidate watershed boundary files

    tmp <- tempdir()
    inspection_dir <- glue(tmp, '/INSPECT_THESE')
    dem_f <- glue(tmp, '/dem.tif')
    point_f <- glue(tmp, '/point.shp')
    d8_f <- glue(tmp, '/d8_pntr.tif')
    flow_f <- glue(tmp, '/flow.tif')

    dir.create(path = inspection_dir,
               showWarnings = FALSE)

    proj <- choose_projection(lat = lat,
                              long = long)

    site <- tibble(x = lat,
                   y = long) %>%
        sf::st_as_sf(coords = c("y", "x"),
                     crs = crs) %>%
        sf::st_transform(proj)
    # sf::st_transform(4326) #WGS 84 (would be nice to do this unprojected)

    #prepare for delineation loops
    buffer_radius <- 100
    dem_coverage_insufficient <- FALSE
    while_loop_begin <- TRUE

    #snap site to flowlines 3 different ways. delineate watershed boundaries (wb)
    #for each unique snap. if the delineations get cut off, get more elevation data
    #and try again
    while(while_loop_begin || dem_coverage_insufficient){

        while_loop_begin <- FALSE

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

        site_buf <- sf::st_buffer(x = site,
                                  dist = buffer_radius)
        dem <- elevatr::get_elev_raster(locations = site_buf,
                                        z = dem_resolution,
                                        verbose = verbose)

        raster::writeRaster(x = dem,
                            filename = dem_f,
                            overwrite = TRUE)

        sf::st_write(obj = site,
                     dsn = point_f,
                     delete_layer = TRUE,
                     quiet = TRUE)

        whitebox::wbt_fill_single_cell_pits(dem = dem_f,
                                            output = dem_f)

        whitebox::wbt_breach_depressions(dem = dem_f,
                                         output = dem_f,
                                         flat_increment = 0.01)

        whitebox::wbt_d8_pointer(dem = dem_f,
                                 output = d8_f)

        whitebox::wbt_d8_flow_accumulation(input = dem_f,
                                           output = flow_f,
                                           out_type = 'catchment area')

        snap1_f <- glue(tmp, '/snap1_jenson_dist150.shp')
        whitebox::wbt_jenson_snap_pour_points(pour_pts = point_f,
                                              streams = flow_f,
                                              output = snap1_f,
                                              snap_dist = 150)
        snap2_f <- glue(tmp, '/snap2_standard_dist50.shp')
        whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                       flow_accum = flow_f,
                                       output = snap2_f,
                                       snap_dist = 50)
        snap3_f <- glue(tmp, '/snap3_standard_dist150.shp')
        whitebox::wbt_snap_pour_points(pour_pts = point_f,
                                       flow_accum = flow_f,
                                       output = snap3_f,
                                       snap_dist = 150)

        #the site has been snapped 3 different ways. identify unique snap locations.
        snap1 <- sf::st_read(snap1_f, quiet = TRUE)
        snap2 <- sf::st_read(snap2_f, quiet = TRUE)
        snap3 <- sf::st_read(snap3_f, quiet = TRUE)
        unique_snaps_f <- snap1_f
        if(! identical(snap1, snap2)) unique_snaps_f <- c(unique_snaps_f, snap2_f)
        if(! identical(snap1, snap3)) unique_snaps_f <- c(unique_snaps_f, snap3_f)

        #good for experimenting with snap specs:
        # delineate_watershed_test2(tmp, point_f, flow_f,
        #                           d8_f, 'standard', 1000)

        #delineate each unique location
        for(i in 1:length(unique_snaps_f)){

            rgx <- str_match(unique_snaps_f[i],
                             '.*?_(standard|jenson)_dist([0-9]+)\\.shp$')
            snap_method <- rgx[, 2]
            snap_distance <- rgx[, 3]

            wb_f <- glue('{path}/wb{n}_buffer{b}_{typ}_dist{dst}.tif',
                         path = tmp,
                         n = i,
                         b = buffer_radius,
                         typ = snap_method,
                         dst = snap_distance)

            whitebox::wbt_watershed(d8_pntr = d8_f,
                                    pour_pts = unique_snaps_f[i],
                                    output = wb_f)

            wb <- raster::raster(wb_f)

            #check how many wb cells coincide with the edge of the DEM.
            #If > 0.1% or > 5, broader DEM needed
            smry <- raster_intersection_summary(wb = wb,
                                                dem = dem)

            if(verbose){
                print(glue('buffer radius: {br}; snap: {sn}/{tot}; ',
                           'n intersecting cells: {ni}; pct intersect: {pct}',
                           br = buffer_radius,
                           sn = i,
                           tot = length(unique_snaps_f),
                           ni = round(smry$n_intersections, 2),
                           pct = round(smry$pct_wb_cells_intersect, 2)))
            }

            if(smry$pct_wb_cells_intersect > 0.1 || smry$n_intersections > 5){
                buffer_radius_new <- buffer_radius * 10
                dem_coverage_insufficient <- TRUE
            } else {
                buffer_radius_new <- buffer_radius

                #write and record temp files for the technician to visually inspect
                wb_sf <- wb %>%
                    raster::rasterToPolygons() %>%
                    sf::st_as_sf() %>%
                    sf::st_buffer(dist = 0.1) %>%
                    sf::st_union() %>%
                    sf::st_as_sf()#again? ugh.

                wb_sf <- sf::st_transform(wb_sf, 4326) #EPSG for WGS84

                wb_sf_f <- glue('{path}/wb{n}_BUF{b}{typ}DIST{dst}RES{res}.shp',
                                path = inspection_dir,
                                n = i,
                                b = buffer_radius,
                                typ = snap_method,
                                dst = snap_distance,
                                res = dem_resolution)

                sf::st_write(obj = wb_sf,
                             dsn = wb_sf_f,
                             delete_dsn = TRUE,
                             quiet = TRUE)
            }
        }

        buffer_radius <- buffer_radius_new
    } #end while loop

    if(verbose){
        message(glue('Candidate delineations are in: ', inspection_dir))
    }

    return(inspection_dir)
}

delineate_watershed_by_specification <- function(lat, long, crs, buffer_radius,
                                                 snap_dist, snap_method,
                                                 dem_resolution, write_dir){

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
    #write_dir: character. the directory to write shapefile watershed boundary to

    #returns the location of candidate watershed boundary files

    require(whitebox) #can't do e.g. whitebox::func in do.call

    tmp <- tempdir()
    inspection_dir <- glue(tmp, '/INSPECT_THESE')
    dem_f <- glue(tmp, '/dem.tif')
    point_f <- glue(tmp, '/point.shp')
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
    # sf::st_transform(4326) #WGS 84 (would be nice to do this unprojected)

    site_buf <- sf::st_buffer(x = site,
                              dist = buffer_radius)
    dem <- sm(elevatr::get_elev_raster(locations = site_buf,
                                       z = dem_resolution))

    raster::writeRaster(x = dem,
                        filename = dem_f,
                        overwrite = TRUE)

    sf::st_write(obj = site,
                 dsn = point_f,
                 delete_layer = TRUE,
                 quiet = TRUE)

    whitebox::wbt_fill_single_cell_pits(dem = dem_f,
                                        output = dem_f)

    whitebox::wbt_breach_depressions(dem = dem_f,
                                     output = dem_f,
                                     flat_increment = 0.01)

    whitebox::wbt_d8_pointer(dem = dem_f,
                             output = d8_f)

    whitebox::wbt_d8_flow_accumulation(input = dem_f,
                                       output = flow_f,
                                       out_type = 'catchment area')

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
                            output = wb_f)

    wb_sf <- raster::raster(wb_f) %>%
        raster::rasterToPolygons() %>%
        sf::st_as_sf() %>%
        sf::st_buffer(dist = 0.1) %>%
        sf::st_union() %>%
        sf::st_as_sf() %>% #again? ugh.
        sf::st_transform(4326) #EPSG for WGS84

    site_name <- str_match(write_dir, '.+?/([^/]+)$')[, 2]

    sf::st_write(obj = wb_sf,
                 dsn = glue('{d}/{s}.shp',
                            d = write_dir,
                            s = site_name),
                 delete_dsn = TRUE,
                 quiet = TRUE)

    message(glue('Watershed boundary written to ',
                 write_dir))

    #return()
}

ms_derive <- function(network = domain, domain){

    #generate derived products (derive.R)
    source(glue('src/{n}/{d}/derive.R',
                n = network,
                d = domain))

    #for any munged product that needs no further processing, recursively
    #hardlink its entire directory from data/[network]/[domain]/munged/
    #to data/[network]/[domain]/derived/

    prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                              n = network,
                              d = domain)))

    is_actually_derived <- grepl('^ms[0-9]{3}$',
                                 prods$prodcode,
                                 perl = TRUE) &
        (is.na(prods$type) |
             prods$type != 'linked')

    is_linked <- prods$type == 'linked'

    derived_prods <- paste(prods$prodname[is_actually_derived],
                           prods$prodcode[is_actually_derived],
                           sep = '__')

    munged_prods <- paste(prods$prodname[! is_actually_derived & ! is_linked],
                          prods$prodcode[! is_actually_derived & ! is_linked],
                          sep = '__')

    #already linked prods will be relinked
    prods_to_link <- munged_prods[! munged_prods %in% derived_prods]

    #figure out what the new prodname_ms's will be
    prodcodes_num <- as.numeric(substr(
        prods$prodcode[is_actually_derived],
        start = 3,
        stop = 5))

    new_prodcodes_num <- seq(max(prodcodes_num) + 1,
                             max(prodcodes_num) + length(prods_to_link))

    new_prodcodes <- stringr::str_pad(string = new_prodcodes_num,
                                      width = 3,
                                      side = 'left',
                                      pad = 0) %>%
                                      {paste0('ms', .)}

    names(new_prodcodes) <- rep('unclaimed',
                                length(new_prodcodes))

    for(p in prods_to_link){

        prodname <- prodname_from_prodname_ms(p)

        if(prodname %in% prods$prodname[is_linked]){

            matched_prodcode <- prods %>%
                filter(
                    !!is_linked,
                    prodname == !!prodname) %>%
                pull(prodcode)

            if(! matched_prodcode %in% new_prodcodes){
                stop(glue('attempt to match already linked product with its ',
                          'prodcode was not successful. investigate.'))
            }

            names(new_prodcodes)[new_prodcodes == matched_prodcode] <- 'taken'

        } else {

            matched_prodcode <- new_prodcodes[which(names(new_prodcodes) ==
                                                        'unclaimed')][1]

            if(any(is.na(matched_prodcode))){
                stop('No unclaimed prodcodes left. something is wrong. investigate')
            }

            append_to_productfile(
                network = network,
                domain = domain,
                prodcode = unname(matched_prodcode),
                prodname = prodname,
                type = 'linked',
                notes = 'automated entry')

            names(new_prodcodes)[new_prodcodes == matched_prodcode] <- 'taken'
        }

        create_derived_links(network = network,
                             domain = domain,
                             prodname_ms = p,
                             new_prodcode = unname(matched_prodcode))
    }

    #link all derived products to the data portal directory
    create_portal_links(network = network,
                        domain = domain)
}

append_to_productfile <- function(network,
                                  domain,
                                  prodcode,
                                  prodname,
                                  type,
                                  retrieve_status,
                                  munge_status,
                                  derive_status,
                                  precursor_of,
                                  notes,
                                  components){

    #add a line to the products.csv file for a particular network and domain.
    #any fields omitted will be populated with NA.

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

    prods <- sm(read_csv(prodfile))

    new_row <- unlist(passed_args)

    new_row <- new_row[names(new_row) %in% colnames(prods)]

    prods <- bind_rows(prods, new_row)

    write_csv(x = prods,
              path = prodfile)
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
    }

    #return()
}

get_response_1char <- function(msg, possible_chars, subsequent_prompt = FALSE){

    #msg: character. a message that will be used to prompt the user
    #possible_chars: character vector of acceptable single-character responses

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
        get_response_1char(msg, possible_chars, subsequent_prompt = TRUE)
    }
}

ms_calc_watershed_area <- function(network, domain, site_name, update_site_file){

    #reads watershed boundary shapefile from macrosheds directory and calculates
    #   watershed area with sf::st_area

    #update_site_file: logical. if true, calculated watershed area is written
    #   to the ws_area_ha column in data/general/site_data.csv

    #returns area in hectares

    munge_dir <- glue('data/{n}/{d}/munged',
                      n = network,
                      d = domain)

    munged_dirs <- list.dirs(munge_dir,
                             recursive = FALSE,
                             full.names = FALSE)

    ws_boundary_dir <- grep(pattern = '^ws_boundary.*',
                            x = munged_dirs,
                            value = TRUE)

    if(! length(ws_boundary_dir)){
        stop(glue('No ws_boundary directory found in ', munge_dir))
    }

    site_dir <- glue('data/{n}/{d}/munged/{w}/{s}',
                     n = network,
                     d = domain,
                     w = ws_boundary_dir,
                     s = site_name)

    if(! dir.exists(site_dir) || ! length(dir(site_dir))){
        stop(glue('{s} directory missing or absent (data/{n}/{d}/munged/{w})',
                  s = site_name,
                  n = network,
                  d = domain,
                  w = ws_boundary_dir))
    }

    wb <- sf::st_read(glue('data/{n}/{d}/munged/{w}/{s}/{s}.shp',
                           n = network,
                           d = domain,
                           w = ws_boundary_dir,
                           s = site_name),
                    quiet = TRUE)

    ws_area_ha <- as.numeric(sf::st_area(wb)) / 10000

    if(update_site_file){

        site_data <- sm(read_csv('data/general/site_data.csv'))

        site_data$ws_area_ha[site_data$domain == domain &
                                 site_data$network == network &
                                 site_data$site_name == site_name] <- ws_area_ha

        write.csv(site_data,
                  file = 'data/general/site_data.csv',
                  row.names = FALSE)
    }

    return(ws_area_ha)
}

write_wb_delin_specs <- function(network, domain, site_name, buffer_radius,
                                 snap_method, snap_distance, dem_resolution){

    new_entry <- tibble(network = network,
                        domain = domain,
                        site_name = site_name,
                        buffer_radius_m = buffer_radius,
                        snap_method = snap_method,
                        snap_distance_m = snap_distance,
                        dem_resolution = dem_resolution)

    ds <- tryCatch(sm(read_csv('data/general/watershed_delineation_specs.csv')),
                   error = function(e) tibble())

    ds <- bind_rows(ds, new_entry)

    write_csv(ds, 'data/general/watershed_delineation_specs.csv')

    #return()
}

read_wb_delin_specs <- function(network, domain, site_name){

    ds <- tryCatch(sm(read_csv('data/general/watershed_delineation_specs.csv')),
                   error = function(e){
                       empty_tibble <- tibble(network = 'a',
                                              domain = 'a',
                                              site_name = 'a',
                                              buffer_radius_m = 1,
                                              snap_method = 'a',
                                              snap_distance_m = 1,
                                              dem_resolution = 1)

                       return(empty_tibble[-1, ])
                   })

    ds <- filter(ds,
                 network == !!network,
                 domain == !!domain,
                 site_name == !!site_name)

    return(ds)
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

    from_mass <- calculate_molar_mass(from)
    to_mass <- calculate_molar_mass(to)
    converted_mass <- x * to_mass / from_mass

    return(converted_mass)
}

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

    #return()
}

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

    #return()
}

convert_to_gl <- function(x, input_unit, molecule) {

    if(grepl('eq', input_unit)) {
        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]

        if(length(valence) == 0) {stop('Varible is likely missing from ms_vars')}

        if(molecule %in% c('POC', ))

        x = (x * calculate_molar_mass(molecule)) / valence

        return(x)
    }

    if(grepl('mol', input_unit)) {
        x = x * calculate_molar_mass(molecule)

        return(x)
    }

    return(x)

}

convert_from_gl <- function(x, input_unit, output_unit, molecule) {

    if(grepl('eq', output_unit) && grepl('g', input_unit)) {

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0) {stop('Varible is likely missing from ms_vars')}
        x = (x * valence) / calculate_molar_mass(molecule)

        return(x)
    }

    if(grepl('mol', output_unit) && grepl('g', input_unit)) {

        x = x / calculate_molar_mass(molecule)

        return(x)
    }

    if(grepl('mol', output_unit) && grepl('eq', input_unit)) {

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0) {stop('Varible is likely missing from ms_vars')}
        x = (x * calculate_molar_mass(molecule)) / valence

        x = x / calculate_molar_mass(molecule)

        return(x)
    }

    if(grepl('eq', output_unit) && grepl('mol', input_unit)) {

        x = x * calculate_molar_mass(molecule)

        valence = ms_vars$valence[ms_vars$variable_code %in% molecule]
        if(length(valence) == 0) {stop('Varible is likely missing from ms_vars')}
        x = (x * valence)/calculate_molar_mass(molecule)

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
    }

    new_fraction <- as.vector(str_split_fixed(output_unit, "/", n = Inf))
    new_top <- as.vector(str_split_fixed(new_fraction[1], "", n = Inf))

    if(length(new_fraction == 2)) {
        new_bottom <- as.vector(str_split_fixed(new_fraction[2], "", n = Inf))
    }

    old_top_unit <- str_split_fixed(old_top, "", 2)[1]

    if(old_top_unit %in% c('g', 'e', 'q', 'l') || old_fraction[1] == 'mol') {
        old_top_conver <- 1
    } else {
        old_top_conver <- as.numeric(filter(units, prefix == old_top_unit)[,2])
    }

    old_bottom_unit <- str_split_fixed(old_bottom, "", 2)[1]

    if(old_bottom_unit %in% c('g', 'e', 'q', 'l') || old_fraction[2] == 'mol') {
        old_bottom_conver <- 1
    } else {
        old_bottom_conver <- as.numeric(filter(units, prefix == old_bottom_unit)[,2])
    }

    new_top_unit <- str_split_fixed(new_top, "", 2)[1]

    if(new_top_unit %in% c('g', 'e', 'q', 'l') || new_fraction[1] == 'mol') {
        new_top_conver <- 1
    } else {
        new_top_conver <- as.numeric(filter(units, prefix == new_top_unit)[,2])
    }

    new_bottom_unit <- str_split_fixed(new_bottom, "", 2)[1]

    if(new_bottom_unit %in% c('g', 'e', 'q', 'l') || new_fraction[2] == 'mol') {
        new_bottom_conver <- 1
    } else {
        new_bottom_conver <- as.numeric(filter(units, prefix == new_bottom_unit)[,2])
    }

    new_val <- x*old_top_conver
    new_val <- new_val/new_top_conver

    new_val <- new_val/old_bottom_conver
    new_val <- new_val*new_bottom_conver

    return(new_val)
}

write_ms_file <- function(d, network, domain, prodname_ms, site_name,
                          level = 'munged', shapefile = FALSE,
                          link_to_portal = FALSE){

    #write an ms tibble or shapefile to its appropriate destination based on
    #network, domain, prodname_ms, site_name, and processing level. If a tibble,
    #write as a feather file (site_name.feather). Uncertainty (error) associated
    #with the val column will be extracted into a separate column called
    #val_err. Write the file to the appropriate location within the data
    #acquisition repository if link_to_portal == TRUE, create a hard link to the
    #file from the portal repository, which is assumed to be a sibling of the
    #data_acquision directory and to be named "portal".

    if(link_to_portal){
        stop("we're not linking to portal this way anymore. see create_portal_links()")
    }

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

        #separate uncertainty into a new column.
        #remove errors attribute from val column if it exists (it always should)
        d$val_err <- errors(d$val)
        if('errors' %in% class(d$val)){
            d$val <- errors::drop_errors(d$val)
        } else {
            warning(glue('Uncertainty missing from val column ({n}-{d}-{s}-{p}). ',
                         'That means this dataset has not passed through ',
                         'carry_uncertainty yet. it should have.',
                         n = network,
                         d = domain,
                         s = site_name,
                         p = prodname_ms))
        }

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

    #return()
}

#deprecated (old form of this function is in helper_scrapyard.R)
create_portal_link <- function(network, domain, prodname_ms, site_name,
                               level = 'derived', dir = FALSE){

    #remove this once enough time has passed to be sure all devs are up to speed.

    stop(glue('create_portal_link has been deprecated. use create_portal_links ',
              '(plural)'))
}

create_derived_links <- function(network, domain, prodname_ms, new_prodcode){

    #for hardlinking munged products to the derive directory. this applies to all
    #munged products that require no derive-level processing.

    #new_prodcode is the derive-style prodcode (e.g. ms920) that will be
    #   given to the new links in the derive directory. this is determined
    #   programmatically by ms_derive

    new_prodname_ms <- paste(prodname_from_prodname_ms(prodname_ms),
                             new_prodcode,
                             sep = '__')

    munge_dir <- glue('data/{n}/{d}/munged/{p}',
                      n = network,
                      d = domain,
                      p = prodname_ms)

    derive_dir <- glue('data/{n}/{d}/derived/{p}',
                       n = network,
                       d = domain,
                       p = new_prodname_ms)

    dir.create(derive_dir,
               showWarnings = FALSE,
               recursive = TRUE)

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

    #return()
}

create_portal_links <- function(network, domain){

    #for hardlinking derived products to the portal directory. this applies to all
    #derived products.

    derive_dir <- glue('data/{n}/{d}/derived',
                       n = network,
                       d = domain)

    portal_dir <- glue('../portal/data/{d}',
                       d = domain)

    dir.create(portal_dir,
               showWarnings = FALSE,
               recursive = TRUE)

    dirs_to_build <- list.dirs(derive_dir,
                               recursive = TRUE)
    dirs_to_build <- dirs_to_build[dirs_to_build != derive_dir]

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

    files_to_link_to <- convert_derive_path_to_portal_path(
        paths = files_to_link_from)

    for(i in 1:length(files_to_link_from)){
        unlink(files_to_link_to[i])
        invisible(sw(file.link(to = files_to_link_to[i],
                               from = files_to_link_from[i])))
    }

    #return()
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

ms_list_files <- function(network, domain, level, prodname_ms){

    #level is either "munged" or "derived"
    #prodname_ms can be a single string or a vector

    if(! level %in% c('munged', 'derived')){
        stop('level must be either "munged" or "derived".')
    }

    files <- glue('data/{n}/{d}/{l}/{p}',
                  n = network,
                  d = domain,
                  l = level,
                  p = prodname_ms) %>%
        list.files(full.names = TRUE)

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
        fnames <- str_match(fnames,'(.*?)\\..*')[, 2]
    }

    return(fnames)
}

#still in progress
delineate_watershed_nhd <- function(lat, long) {

    #this function delineates a watershed from a point first using NHD tools.
    #if that fails, it falls back on a more general whitebox method, which is
    #implemented in delineate_watershed. the NHD method, if implemented, should
    #correct for reach proportional distance of each site location. see
    # https://github.com/vlahm/watershed_tools/blob/master/2_batch_summary_nhd.R
    #also at that link, there's a function for retrieving COMID by lat/long, which
    #could replace discover_nhdplus_id below (which doesn't always seem to work?)

    #there's also this streamstats approach (fully packaged),
    #   but that's incomplete even for CONUS
    # x = streamstats::delineateWatershed(xlocation = long,
    #                                     ylocation = lat,
    #                                     crs = crs)
    # streamstats::leafletWatershed(x)

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

calc_inst_flux <- function(chemprod, qprod, site_name){

    #chemprod is the prodname_ms for stream or precip chemistry.
    #   it can be a munged or a derived product.
    #qprod is the prodname_ms for stream discharge or precip volume over time.
    #   it can be a munged or derived product/

    if(! prodname_from_prodname_ms(qprod) %in% c('precipitation', 'discharge')){
        stop('Could not determine stream/precip')
    }

    flux_vars <- ms_vars %>% #ms_vars is global
        filter(flux_convertible == 1) %>%
        pull(variable_code)

    chem <- read_combine_feathers(network = network,
                                  domain = domain,
                                  prodname_ms = chemprod) %>%
        filter(site_name == !!site_name) %>%
        pivot_wider(names_from = 'var',
                    values_from = 'val') %>%
        select(datetime, ms_status, ms_interp,
               matches(paste0('^[A-Z]{2}_',
                              flux_vars),
                       ignore.case = FALSE))

    daterange <- range(chem$datetime)

    flow <- read_combine_feathers(network = network,
                                  domain = domain,
                                  prodname_ms = qprod) %>%
        filter(
            site_name == !!site_name,
            datetime >= !!daterange[1],
            datetime <= !!daterange[2]) %>%
        rename(flow = val) %>% #quick and dirty way to convert to wide
        # rename(!!drop_var_prefix(.$var[1]) := val) %>%
        select(-var, -site_name)

    #a few commented remnants from the old wide-format days have been left here,
    #because they might be instructive in other endeavors
    flux <- chem %>%
        full_join(flow,
                  by = 'datetime') %>%
        select_if(~(! all(is.na(.)))) %>%
        rowwise(datetime) %>%
        mutate(
            ms_interp = numeric_any(c_across(c(ms_interp.x, ms_interp.y))),
            ms_status = numeric_any(c_across(c(ms_status.x, ms_status.y)))) %>%
        ungroup() %>%
        select(-ms_status.x, -ms_status.y, -ms_interp.x, -ms_interp.y) %>%
        mutate_at(vars(-datetime, -flow, -ms_status, -ms_interp),
                  ~(. * flow)) %>%
        select(-flow) %>%
        pivot_longer(cols = ! c(datetime, ms_status, ms_interp),
                     names_pattern = '(.*)',
                     names_to = 'var') %>%
        rename(val = value) %>%
        filter(! is.na(val)) %>%
        # filter_at(vars(-all_of(c('datetime', 'ms_status', 'ms_interp'))),
        #           any_vars(! is.na(.))) %>%
        mutate(site_name = !!site_name) %>%
        arrange(site_name, var, datetime) %>%
        select(datetime, site_name, var, val, ms_status, ms_interp)
        # select(datetime, site_name, everything()) %>%
        # relocate(ms_status, .after = last_col()) %>%
        # relocate(ms_interp, .after = last_col())

    flux <- apply_detection_limit_t(flux, network, domain, chemprod)

    return(flux)
}

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
    #row bind them, arrange by site_name, var, datetime. insert val_err column
    #into the val column as errors attribute and then remove val_err column
    #(error/uncertainty is handled by the errors package as an attribute,
    #so it must be written/read as a separate column).

    #the processing level is determined automatically from prodname_ms.
    #   If the product code is "msXXX" where X is a numeral, the processing
    #   level is assumed to be "derived". otherwise "munged"

    level <- ifelse(is_derived_product(prodname_ms),
                    'derived',
                    'munged')

    prodpaths <- ms_list_files(network = network,
                               domain = domain,
                               level = level,
                               prodname_ms = prodname_ms)

    combined <- tibble()
    for(i in 1:length(prodpaths)){
        part <- read_feather(prodpaths[i])
        combined <- bind_rows(combined, part)
    }

    combined <- combined %>%
        mutate(val = errors::set_errors(val, val_err)) %>%
        select(-val_err) %>%
        arrange(site_name, var, datetime)

    return(combined)
}

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
        errors(d_idw) <- weightmat %*% matrix(errors(dk),
                                              nrow = nrow(dk))

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
                      var = output_varname,
                      val = ws_mean,
                      # !!output_varname := ws_mean,
                      ms_status = d_status,
                      ms_interp = d_interp)

    return(ws_mean)
}

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
        errors(p_idw) <- weightmat %*% matrix(errors(pk),
                                              nrow = nrow(pk))
        errors(c_idw) <- weightmat %*% matrix(errors(ck),
                                              nrow = nrow(ck))

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

synchronize_timestep <- function(d, desired_interval, impute_limit = 30){

    #d is a df/tibble with columns: datetime (POSIXct), site_name, var, val, ms_status
    #desired_interval is a character string that can be parsed by the "by"
    #   parameter to base::seq.POSIXt, e.g. "5 mins" or "1 day"
    #impute_limit is the maximum number of consecutive points to
    #   inter/extrapolate. it's passed to imputeTS::na_interpolate

    #output will include a numeric binary column called "ms_interp".
    #0 for not interpolated, 1 for interpolated

    uniq_sites <- unique(d$site_name)

    if(nrow(d) < 2 || sum(! is.na(d$val)) < 2){
        stop('no data to synchronize. bypassing processing.')
    }

    #round to desired_interval
    d <- sw(d %>%
        mutate(datetime = lubridate::round_date(datetime,
                                                desired_interval)) %>%
        group_by(site_name, var, datetime) %>%
        summarize(
            val = if(n() > 1) mean(val, na.rm = TRUE) else first(val),
            ms_status = numeric_any(ms_status)) %>%
        ungroup() %>%
        select(datetime, site_name, var, val, ms_status))

    #fill in missing timepoints with NAs
    fulldt <- d %>%
        group_by(site_name, var) %>%
        summarize(
            dtmin = min(datetime),
            dtmax = max(datetime)) %>%
        ungroup() %>%
        rowwise() %>%
        do(tibble(site_name = .$site_name,
                  var = .$var,
                  datetime = seq(.$dtmin,
                                 .$dtmax,
                                 by = desired_interval))) %>%
        ungroup()

    #interpolate up to impute_limit; populate ms_interp column; remove unfilled NAs
    d_adjusted <- d %>%
        full_join(fulldt, #fill in missing datetime intervals
                  by = c('datetime', 'site_name', 'var')) %>%
        group_by(site_name, var) %>%
        arrange(datetime) %>%
        mutate(
            ms_interp = case_when(
                is.na(ms_status) ~ 1,
                TRUE ~ 0), #add binary column to track which points are interped
            ms_status = imputeTS::na_locf(ms_status, #carry status to interped rows
                                          na_remaining = 'rev'),
            val = if(sum(! is.na(val)) > 1){
                    imputeTS::na_interpolation(val, #linear interp NA vals
                                               maxgap = impute_limit)
                } else val, #unless not enough data in group; then do nothing
            err = errors(val), #extract error from data vals
            err = case_when(
                err == 0 ~ NA_real_, #change 0 errors (default) to NA...
                TRUE ~ err),
            val = set_errors(val, #and then carry error to interped rows
                             imputeTS::na_locf(err,
                                               na_remaining = 'rev'))) %>%
        ungroup() %>%
        select(-err) %>%
        # group_by(datetime, site_name) %>%
        # filter(any(! is.na(val))) %>%
        # ungroup() %>%
        filter(! is.na(val)) %>%
        arrange(site_name, var, datetime)

    return(d_adjusted)
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

idw_log_wb <- function(verbose, site_name, i, nw){

    if(! verbose) return()

    msg <- glue('site: {s} ({ii}/{w})',
                s = site_name,
                ii = i,
                w = nw)

    loginfo(msg,
            logger = logger_module)

    #return()
}

idw_log_var <- function(verbose, site_name, v, j, nvars){

    if(! verbose) return()

    msg <- glue('site: {s} (_/__); var: {vv} ({jj}/{nv})',
                s = site_name,
                vv = v,
                jj = j,
                nv = nvars)

    loginfo(msg,
            logger = logger_module)

    #return()
}

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

    #return()
}

precip_idw <- function(precip_prodname, wb_prodname, pgauge_prodname,
                       precip_prodname_out, verbose = TRUE){

    #load watershed boundaries, rain gauge locations, precip data
    wb <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = wb_prodname)
    rg <- read_combine_shapefiles(network = network,
                                  domain = domain,
                                  prodname_ms = pgauge_prodname)
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

    #this avoids a lot of slow summarizing during the next step
    status_cols <- precip %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    #clean precip and arrange for matrixification
    precip <- precip %>%

        #this block is for testing only (makes dataset smaller)
        # mutate(datetime = lubridate::year(datetime)) %>% #by year
        # # # mutate(datetime = lubridate::as_date(datetime)) %>% #by day
        # group_by(site_name, datetime) %>%
        # summarize(
        #     precip = mean(precip, na.rm=TRUE),
        #     ms_status = numeric_any(ms_status),
        #     ms_interp = numeric_any(ms_status)) %>%
        # ungroup() %>%

        select(-ms_status, -ms_interp, -var) %>%
        tidyr::pivot_wider(names_from = site_name,
                           values_from = val) %>%
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

        ws_mean_precip <- shortcut_idw(encompassing_dem = dem,
                                       wshd_bnd = wbi,
                                       data_locations = rg,
                                       data_values = precip,
                                       stream_site_name = site_name,
                                       output_varname = 'precip',
                                       elev_agnostic = FALSE,
                                       verbose = verbose)

        # ws_mean_precip$precip <- apply_detection_limit_s(ws_mean_precip$precip,
        #                                                 detlim)
        # identify_detection_limit_s(ws_mean_precip$val)
        precursor_prodname <- get_detlim_precursors(network = network,
                                                    domain = domain,
                                                    prodname_ms = prodname_ms)

        ws_mean_precip <- apply_detection_limit_t(ws_mean_precip,
                                                  network = network,
                                                  domain = domain,
                                                  prodname_ms = precursor_prodname)

        #interp final precip to a desirable interval?
        write_ms_file(ws_mean_precip,
                      network = network,
                      domain = domain,
                      prodname_ms = precip_prodname_out,
                      site_name = site_name,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = FALSE)
    }

    parallel::stopCluster(clst)

    #return()
}

get_detlim_precursors <- function(network, domain, prodname_ms){

    #this gets the prodname_ms for the direct precursor of a derived
    #product. for example, for hjandrews 'precipitation__ms001' it would return
    #'precipitation__5482'. This is necessary when applying detection limits
    #to a derived product, because those limits were defined on the direct
    #precursor

    #for precip flux products, the direct precursor is considered to be precip
    #chem. for derived products that aggregate two or more munged products of
    #the same type (e.g. discharge__9, discharge__10, etc. from
    #lter/konza), this returns all of those products as precursors.

    if(network == domain){
        prods <- sm(read_csv(glue('src/{n}/products.csv',
                                  n = network)))
    } else {
        prods <- sm(read_csv(glue('src/{n}/{d}/products.csv',
                                  n = network,
                                  d = domain)))
    }

    prodname <- prodname_from_prodname_ms(prodname_ms)
    if(grepl('precip_flux', prodname)) prodname <- 'precip_chemistry'

    precursor <- prods %>%
        filter(
            !!prodname == prodname,
            ! grepl('^ms[0-9]{3}$', prodcode)) %>%
        mutate(prodname_ms = paste(prodname, prodcode, sep = '__')) %>%
        pull(prodname_ms)

    return(precursor)
}

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

    #this avoids a lot of slow summarizing
    status_cols <- pchem %>%
        select(datetime, ms_status, ms_interp) %>%
        group_by(datetime) %>%
        summarize(
            ms_status = numeric_any(ms_status),
            ms_interp = numeric_any(ms_interp))

    #clean pchem one variable at a time, matrixify it, insert it into list
    pchem_vars <- unique(pchem$var)
    nvars <- length(pchem_vars)
    pchem_setlist <- as.list(rep(NA, nvars))
    for(i in 1:nvars){

        v <- pchem_vars[i]

        #clean data and arrange for matrixification
        pchem_setlist[[i]] <- pchem %>%
            filter(var == v) %>%
            select(-var, -ms_status, -ms_interp) %>%
            tidyr::pivot_wider(names_from = site_name,
                               values_from = val) %>%
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

        # for(j in 1:nvars){q
        ws_mean_d <- foreach::foreach(j = 1:nvars,
                                      .combine = idw_parallel_combine,
                                      .init = 'first iter') %dopar% {
                                      # .packages = idw_pkg_export,
                                      # .export = idw_var_export,
                                      # .errorhandling = 'remove',
                                      # .verbose = TRUE) %dopar% {

            v <- pchem_vars[j]

            idw_log_var(verbose = verbose,
                        site_name = site_name,
                        v = v,
                        j = j,
                        nvars = nvars)

            # ws_mean <- shortcut_idw(encompassing_dem = dem, (handled by foreach now)
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

        precursor_prodname <- get_detlim_precursors(network = network,
                                                    domain = domain,
                                                    prodname_ms = prodname_ms)
        ws_mean_d <- apply_detection_limit_t(ws_mean_d,
                                             network = network,
                                             domain = domain,
                                             prodname_ms = precursor_prodname)

        write_ms_file(ws_mean_d,
                      network = network,
                      domain = domain,
                      prodname_ms = pchem_prodname_out,
                      site_name = site_name,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = FALSE)
    }

    parallel::stopCluster(clst)

    #return()
}

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
        select(-ms_status, -ms_interp, -var) %>%
        tidyr::pivot_wider(names_from = site_name,
                           values_from = val) %>%
        left_join(status_cols,
                  by = 'datetime') %>%
        arrange(datetime)

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
    nvars_fluxable <- length(pchem_vars_fluxable)
    pchem_setlist_fluxable <- as.list(rep(NA, nvars_fluxable))
    for(i in 1:nvars_fluxable){

        v <- pchem_vars_fluxable[i]

        #clean data and arrange for matrixification
        pchem_setlist_fluxable[[i]] <- pchem %>%
            filter(var == v) %>%
            select(-var, -ms_status, -ms_interp) %>%
            tidyr::pivot_wider(names_from = site_name,
                               values_from = val) %>%
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
        #                  link_to_portal = FALSE))

        precursor_prodname <- get_detlim_precursors(network = network,
                                                    domain = domain,
                                                    prodname_ms = prodname_ms)
        ws_mean_flux <- apply_detection_limit_t(ws_mean_flux,
                                                network = network,
                                                domain = domain,
                                                prodname_ms = precursor_prodname)

        write_ms_file(ws_mean_flux,
                      network = network,
                      domain = domain,
                      prodname_ms = flux_prodname_out,
                      site_name = site_name,
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = FALSE)
    }

    parallel::stopCluster(clst)

    #return()
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
                                       site_name = 'sitename_NA',
                                       new_status = 'pending')
    }

    #return()
}

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

    #return()
}

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

    metadata_r <- read_metadata_r(network = network,
                                  domain = domain,
                                  prodname_ms = prodname_ms)

    code_m <- document_kernel_code(network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms,
                                   level = 1)

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

    #return()
}

write_metadata_d <- function(network, domain, prodname_ms){

    #this writes the metadata file for derived macrosheds data
    #see write_metadata_r for retrieved macrosheds data and write_metadata_m
    #for munged macrosheds data

    #also see read_metadata_r

    #assemble metadata
    display_args <- list(network = paste0("'", network, "'"),
                         domain = paste0("'", domain, "'"),
                         prodname_ms = paste0("'", prodname_ms, "'"))

    precursors <- get_precursors(network = network,
                                 domain = domain,
                                 prodname_ms = prodname_ms)

    code_d <- document_kernel_code(network = network,
                                   domain = domain,
                                   prodname_ms = prodname_ms,
                                   level = 2)

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

    #return()
}

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

Mode <- function(x, na.rm = TRUE){

    if(na.rm){
        x <- na.omit(x)
    }

    ux <- unique(x)
    mode_out <- ux[which.max(tabulate(match(x, ux)))]
    return(mode_out)

}

identify_detection_limit_t <- function(X, network, domain, prodname_ms,
                                       return_detlims = FALSE){

    #this is the temporally explicit version of identify_detection_limit (_t).
    #it supersedes the scalar version (identify_detection_limit_s).
    #that version just returns its output. This version relies on stored data,
    #so automatically writes to data/<network>/<domain>/detection_limits.json,
    #and, if return_detlims = TRUE, returns its output as an integer vector
    #of detection limits with length equal to the number of rows in X, where each
    #value holds the detection limit of its corresponding data value in X$val

    #X is a 2d array-like object. must have datetime,
    #site_name, var, and val columns. if X was generated by ms_cast_and_reflag,
    #you're good to go.

    #the detection limit (number of decimal places)
    #of each column is written to data/<network>/<domain>/detection_limits.json
    #as a nested list:
    #prodname_ms
    #    variable
    #        startdt: datetime1, datetime2, datetimeN...
    #        lim:     limit1,    limit2,    limitN...

    #detection limit (detlim) is computed as the
    #number of characters following the decimal. NA detlims are filled
    #by locf, followed by nocb. Then, to account for false detlims arising from
    #trailing zeros, positive monotonicity is forced by carrying forward
    #cumulative maximum detlims. Each time the detlim increases,
    #a new startdt and limit are recorded.

    #X will be sorted ascendingly by site_name, var, and then datetime. If
    #   return_detlims = TRUE and you'll be using the output to establish
    #   uncertainty, be sure that X is already sorted in this way, or detlims
    #   won't line up with their corresponding data values.
    #   If X was generated by ms_cast_and_reflag, you're good to go.

    X <- as_tibble(X) %>%
        arrange(site_name, var, datetime)

    identify_detection_limit_ <- function(X, v, output = 'list'){

        if(! output %in% c('vector', 'list')){
            stop('output must be "vector" or "list"')
        }

        x <- filter(X, var == v)

        if(nrow(x) == 0){
            return(NULL)
        }

        sn = x$site_name
        dt = x$datetime

        options(scipen = 100)
        nas <- is.na(x$val) | x$val == 0

        val <- as.character(x$val)
        nsigdigs <- stringr::str_split_fixed(val, '\\.', 2)[, 2] %>%
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

    variables <- unique(X$var)

    detlim <- lapply(variables,
                     function(z) identify_detection_limit_(X, z))
    detlim <- detlim[! sapply(detlim, is.null)]
    names(detlim) <- variables

    write_detection_limit(detlim,
                          network = network,
                          domain = domain,
                          prodname_ms = prodname_ms)

    if(return_detlims){

        detlim_v <- rep(NA, nrow(X))

        for(v in variables){
            for(s in unique(X$site_name)){
                x <- filter(X, site_name == s)
                dlv <- identify_detection_limit_(x, v, output = 'vector')
                if(is.null(dlv)) next
                detlim_v[X$site_name == s & X$var == v] <- dlv
            }
        }

        return(detlim_v)
    }

    #return()
}

apply_detection_limit_t <- function(X, network, domain, prodname_ms){

    #this is the temporally explicit version of apply_detection_limit (_t).
    #it supersedes the scalar version (apply_detection_limit_s).
    #that version just returns its output. This version relies on stored data,
    #so automatically reads from data/<network>/<domain>/detection_limits.json.

    #X is a 2d array-like object. must have datetime,
    #site_name, var, and val columns. if X was generated by ms_cast_and_reflag,
    #you should be good to go.

    #Attempting to apply detection
    #limits to a variable for which detection limits are not known (not present
    #in detection_limits.json) results in error. Superfluous variable entries in
    #detection_limits.json are ignored.

    X <- as_tibble(X) %>%
        arrange(site_name, var, datetime)

    if(is_derived_product(prodname_ms)){

        #if there are multiple precursors (rare), just use the first
        prodname_ms <- get_detlim_precursors(network = network,
                                             domain = domain,
                                             prodname_ms = prodname_ms)[1]
    }

    detlim <- read_detection_limit(network, domain, prodname_ms)
    if(is_ms_err(detlim)){
        stop('problem reading detection limits from file')
    }

    apply_detection_limit_ <- function(x, varnm, detlim){


        #plenty of code superfluity in this function. adapted from a previous
        #   version and there's negligible efficiency loss if any

        if(! varnm %in% names(detlim)){
            stop(glue('Missing detection limits for var: {v}', v = varnm))
        }

        detlim_var <- detlim[[varnm]]

        x <- filter(x, var == varnm)

        if(nrow(x) == 0){
            return(NULL)
        }

        sn = x$site_name
        dt = x$datetime

        site_lst <- tibble(dt, sn, val = x$val) %>%
            base::split(sn)

        Xerr <- lapply(X = site_lst,
                       FUN = function(z) errors(z$val)) %>%
            unlist() %>%
            unname()

        rounded <- lapply(X = site_lst,
                          FUN = function(z){

                              if(all(is.na(z$val))) return(z$val)

                              detlim_varsite <- detlim_var[[z$sn[1]]]
                              if(all(is.na(detlim_varsite$lim))) return(z$val)

                              cutvec <- c(as.POSIXct(detlim_varsite$startdt,
                                                     tz = 'UTC'),
                                          as.POSIXct('2900-01-01 00:00:00'))

                              roundvec <- cut(x = z$dt,
                                              breaks = cutvec,
                                              include.lowest = TRUE,
                                              labels = detlim_varsite$lim) %>%
                                              as.character() %>%
                                              as.numeric()

                              #sometimes synchronize_timestep will adjust a point
                              #to a time before the earliest startdt recorded
                              #in detection_limits.json. this handles that.
                              roundvec <- imputeTS::na_locf(x = roundvec,
                                                            option = 'nocb')

                              rounded <- mapply(FUN = function(a, b){
                                                    round(a, b)
                                                },
                                                a = z$val,
                                                b = roundvec,
                                                USE.NAMES = FALSE)

                              return(rounded)
                          }) %>%
            unlist() %>%
            unname()

        errors(rounded) <- Xerr

        return(rounded)
    }

    variables <- unique(X$var)

    for(v in variables){
        for(s in unique(X$site_name)){
            x <- filter(X, site_name == s)
            dlv <- apply_detection_limit_(x, v, detlim)
            if(is.null(dlv)) next
            X$val[X$site_name == s & X$var == v] <- dlv
        }
    }

    return(X)
}

read_detection_limit <- function(network, domain, prodname_ms){

    detlims <- glue('data/{n}/{d}/detection_limits.json',
                    n = network,
                    d = domain) %>%
        readr::read_file() %>%
        jsonlite::fromJSON()

    detlims_prod <- detlims[[prodname_ms]]

    return(detlims_prod)
}

write_detection_limit <- function(detlim, network, domain, prodname_ms){

    detlims_file <- glue('data/{n}/{d}/detection_limits.json',
                         n = network,
                         d = domain)

    if(file.exists(detlims_file)){
        x <- jsonlite::fromJSON(readr::read_file(detlims_file))
        x[[prodname_ms]] <- detlim
    } else {
        x <- list(placeholder = detlim)
        names(x) <- prodname_ms
    }

    readr::write_file(jsonlite::toJSON(x), detlims_file)

    #return()
}

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

get_gee_imgcol <- function(gee_id, band, prodname, start, end) {

    col_name <- paste0(prodname, 'X')

    gee_imcol <- ee$ImageCollection(gee_id)$
        filterDate(start, end)$
        select(band)$
        map(function(x){
            date <- ee$Date(x$get("system:time_start"))$format('YYYY_MM_dd')
            x$set("RGEE_NAME", date)
        })
}

clean_gee_tabel <- function(ee_ws_table, sheds, com_name) {

    table_nrow <- sheds %>%
        mutate(nrow = row_number()) %>%
        as.data.frame() %>%
        select(site_name, nrow)

    sm(table <- ee_ws_table %>%
        mutate(nrow = row_number()) %>%
        full_join(table_nrow) %>%
        select(-nrow))

    col_names <- colnames(table)

    leng <- length(col_names) -1

    table_time <- table %>%
        pivot_longer(col_names[1:leng])

    for(i in 1:nrow(table_time)) {
        table_time[i,'date'] <- stringr::str_split_fixed(table_time[i,2],
                                                         pattern = 'X', n = 2)[2]
    }

    table_fin <- table_time %>%
        dplyr::select(-name) %>%
        mutate(date = ymd(date)) %>%
        rename(!!com_name := value)

    return(table_fin)
}

get_gee_standard <- function(network, domain, gee_id, band, prodname, rez,
                             ws_prodname) {

    sheds <- try(read_combine_shapefiles(network=network, domain=domain,
                                     prodname_ms=ws_prodname))

    if(class(sheds)[1] == 'ms_err') {
        stop('Watershed boundaries are required for gee products')
    }
    sheds <- sheds %>%
        as.data.frame() %>%
        sf::st_as_sf() %>%
        select(site_name) %>%
        sf::st_transform(4326) %>%
        sf::st_set_crs(4326)

    imgcol <- get_gee_imgcol(gee_id, band, prodname, '1957-10-04', '2040-01-01')

    median <- ee_extract(
        x = imgcol,
        y = sheds,
        scale = rez,
        fun = ee$Reducer$median(),
        sf = FALSE
    )

    sd <- ee_extract(
        x = imgcol,
        y = sheds,
        scale = rez,
        fun = ee$Reducer$stdDev(),
        sf = FALSE
    )

    count <- ee_extract(
        x = imgcol,
        y = sheds,
        scale = rez,
        fun = ee$Reducer$count(),
        sf = FALSE
    )
    median_name <- glue('{c}_median', c = prodname)
    count_name <- glue('{c}_count', c = prodname)

    median <- clean_gee_tabel(median, sheds, median_name)

    sd <- clean_gee_tabel(sd, sheds, glue('{c}_sd', c = prodname))

    count <- clean_gee_tabel(count, sheds, count_name)

    fin <- sm(full_join(median, sd)) %>%
        sm(full_join(count))

    return(fin)

}

get_gee_large <- function(network, domain, gee_id, band, prodname, rez,
                          start, ws_prodname) {

     sheds <- try(read_combine_shapefiles(network=network, domain=domain,
                                         prodname_ms=ws_prodname))

    if(class(sheds)[1] == 'ms_err') {
        stop('Watershed boundaries are required for gee products')
    }

    sheds <- sheds %>%
        as.data.frame() %>%
        sf::st_as_sf() %>%
        select(site_name) %>%
        sf::st_transform(4326) %>%
        sf::st_set_crs(4326)

    start <- pull(gee[1,4])
    current <- Sys.Date() + years(5)
    dates <- seq(start, current, by = 'years')

    date_ranges <- dates[seq(0, 100, by = 5)]
    date_ranges <- date_ranges[!is.na(date_ranges)]
    date_ranges <- append(start, date_ranges)

    for(i in 1:(length(date_ranges)-1)) {
        imgcol <- get_gee_imgcol(pull(gee[1,1]), pull(gee[1,2]), pull(gee[1,3]),
                                 paste0(date_ranges[i]), paste0(date_ranges[i+1]))


        median <- ee_extract(
            x = imgcol,
            y = sheds,
            scale = rez,
            fun = ee$Reducer$median(),
            sf = FALSE
        )

        sd <- ee_extract(
            x = imgcol,
            y = sheds,
            scale = rez,
            fun = ee$Reducer$stdDev(),
            sf = FALSE
        )

        count <- ee_extract(
            x = imgcol,
            y = sheds,
            scale = rez,
            fun = ee$Reducer$count(),
            sf = FALSE
        )

        median_name <- glue('{c}_median', c = var)
        count_name <- glue('{c}_count', c = var)

        median <- clean_gee_tabel(median, sheds, median_name)

        sd <- clean_gee_tabel(sd, sheds, glue('{c}_sd', c = var))

        count <- clean_gee_tabel(count, sheds, count_name)

        fin <- sm(full_join(median, sd)) %>%
            sm(full_join(count))

        if(i == 1) {
            final <- filter(fin, date == '1900-01-1')
        }

        final <- rbind(final, fin)
    }

    return(final)

}

detection_limit_as_uncertainty <- function(detlim){

    # uncert <- lapply(detlim,
    #                  FUN = function(x) 1 / 10^x) %>%
    #               as_tibble()

    uncert <- 1 / 10^detlim

    return(uncert)
}

carry_uncertainty <- function(d, network, domain, prodname_ms){

    u <- identify_detection_limit_t(d,
                                    network = network,
                                    domain = domain,
                                    prodname_ms = prodname_ms,
                                    return_detlims = TRUE)
    u <- detection_limit_as_uncertainty(u)
    errors(d$val) <- u
    # d <- insert_uncertainty_df(d, u)

    return(d)
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

get_relative_uncert <- function(x){

    if(any(class(x) %in% c('list', 'data.frame', 'array'))){
        stop(glue('this function not yet adapted for class {cl}',
                  cl = paste(class(tibble(x=1:3)),
                             collapse = ', ')))
    }

    ru <- errors(x) / abs(errors::drop_errors(x)) * 100

    return(ru)
}

get_phonology <- function(network, domain, prodname_ms, time, ws_boundry) {

    sheds <- ws_boundry %>%
        as.data.frame() %>%
        sf::st_as_sf() %>%
        select(site_name) %>%
        sf::st_transform(4326) %>%
        sf::st_set_crs(4326)

    sheds_point <- sheds[1,] %>%
        sf::st_centroid() %>%
        sf::st_bbox()

    long <- as.numeric(sheds_point[2])

    place <- ifelse(long > 97.5, 'west', 'east')

    year_files <- list.files(glue('data/general_raw/phenology/{u}/{p}',
                             p = place,
                             u = time))

    years <- as.numeric(str_split_fixed(year_files, '[.]', n = 2)[,1])

    final <- tibble()
        for(y in 1:length(years)) {

            path <- glue('data/general_raw/phenology/{u}/{p}/{t}.tif',
                         u = time, p = place, t = years[y])

            phenology <- terra::rast(path)

            terra::crs(phenology) <- '+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs'

            sheds_vect <- sheds %>%
                terra::vect() %>%
                terra::project('+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs')

            look <- terra::extract(phenology, sheds_vect) %>%
                as.data.frame()

            name <- names(look)[2]

            col_name <- case_when(time == 'start_season' ~ 'sos',
                                   time == 'end_season' ~ 'eos',
                                   time == 'max_season' ~ 'mos')

            mean_name <- glue('{n}_mean', n = col_name)
            sd_name <- glue('{n}_sd', n = col_name)

            look <- look %>%
                group_by(ID) %>%
                summarize(!!mean_name := round(mean(.data[[name]], na.rm = TRUE)),
                          !!sd_name := sd(.data[[name]], na.rm = TRUE))

            sheds_name <- sheds %>%
                as_tibble() %>%
                select(-geometry) %>%
                mutate(ID = row_number()) %>%
                mutate(year = !!years[y])

            final_y <- full_join(look, sheds_name, by = 'ID') %>%
                select(-ID)

            final <- rbind(final, final_y)
        }

    final_path <- glue('data/{n}/{d}/ws_traits/{p}.feather',
                       n = network,
                       d = domain,
                       p = time)

    write_feather(final, final_path)

    #return()
}

detection_limit_as_uncertainty <- function(detlim){

    # uncert <- lapply(detlim,
    #                  FUN = function(x) 1 / 10^x) %>%
    #               as_tibble()

    uncert <- 1 / 10^detlim

    return(uncert)
}

carry_uncertainty <- function(d, network, domain, prodname_ms){

    u <- identify_detection_limit_t(d,
                                    network = network,
                                    domain = domain,
                                    prodname_ms = prodname_ms,
                                    return_detlims = TRUE)
    u <- detection_limit_as_uncertainty(u)
    errors(d$val) <- u
    # d <- insert_uncertainty_df(d, u)

    return(d)
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

get_relative_uncert <- function(x){

    if(any(class(x) %in% c('list', 'data.frame', 'array'))){
        stop(glue('this function not yet adapted for class {cl}',
                  cl = paste(class(tibble(x=1:3)),
                             collapse = ', ')))
    }

    ru <- errors(x) / errors::drop_errors(x) * 100

    return(ru)

}

raster_intersection_summary <- function(wb, dem){

    #wb is a delineated watershed boundary as a rasterLayer
    #dem is a DEM rasterLayer

    summary_out <- list()

    #convert wb to sf object
    wb <- wb %>%
        raster::rasterToPolygons() %>%
        sf::st_as_sf()

    #get edge of DEM as sf object
    dem_edge <- raster::boundaries(dem) %>%
        raster::reclassify(matrix(c(0, NA),
                                  ncol = 2)) %>%
        raster::rasterToPolygons() %>%
        sf::st_as_sf()

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
        group_by(site_name, var) %>%
        summarise(non_na = sum(na))

    d <- left_join(d, d_test, by = c("site_name", "var")) %>%
        filter(non_na > 10) %>%
        select(-non_na)
}

combine_munged_products <- function(network, domain, prodname_ms,
                                    munged_prodname_ms) {

    #Used to combine multiple products into one. Used when discharge, chemistry,
    #or other products are split into multiple products and we want them in one.

    files <- list_munged_files(network = network,
                                    domain = domain,
                                    prodname_ms = munged_prodname_ms)

    dir <- glue('data/{n}/{d}/derived/{p}',
                n = network,
                d = domain,
                p = prodname_ms)

    dir.create(dir, showWarnings = FALSE)

    site_feather <- str_split_fixed(files, '/', n = Inf)[,6]
    sites <- unique(str_split_fixed(site_feather, '[.]', n = Inf)[,1])

    for(i in 1:length(sites)) {
        site_files <- grep(sites[i], files, value = TRUE)

        sile_full <- map_dfr(site_files, read_feather)

        write_ms_file(d = sile_full,
                      network = network,
                      domain = domain,
                      prodname_ms = prodname_ms,
                      site_name = sites[i],
                      level = 'derived',
                      shapefile = FALSE,
                      link_to_portal = TRUE)
    }
}
