#complete this list with any common, globally (across macrosheds) used funcs.
#refer to everything else explicity with ::
#this will make packaging easier and more professional

read_csv = readr::read_csv
read_feather = feather::read_feather
write_feather = feather::write_feather
glue = glue::glue
filter = dplyr::filter
select = dplyr::select
mutate = dplyr::mutate
mutate_all = dplyr::mutate_all
mutate_at = dplyr::mutate_at
mutate_if = dplyr::mutate_if
group_by = dplyr::group_by
ungroup = dplyr::ungroup
summarize = dplyr::summarize
summarize_all = dplyr::summarize_all
summarize_at = dplyr::summarize_at
summarize_if = dplyr::summarize_if
left_join = dplyr::left_join
right_join = dplyr::right_join
full_join = dplyr::full_join
vars = dplyr::vars
pull = dplyr::pull
distinct = dplyr::distinct
one_of = dplyr::one_of
any_of = dplyr::any_of #supersedes one_of
spread = tidyr::spread
gather = tidyr::gather
`%>%` = magrittr::`%>%`
`.` = plyr::`.`
sm = suppressMessages
sw = suppressWarnings
str_match = stringr::str_match
loginfo = logging::loginfo
logwarn = logging::logwarn
logerror = logging::logerror
with_tz = lubridate::with_tz
force_tz = lubridate::force_tz
as_datetime = lubridate::as_datetime
ymd_hms = lubridate::ymd_hms
as_tibble = tibble::as_tibble
bind_cols = dplyr::bind_cols
bind_rows = dplyr::bind_rows
map = purrr::map
map2 = purrr::map
errors = errors::errors
