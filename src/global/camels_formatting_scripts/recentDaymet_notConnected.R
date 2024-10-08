#this is handled by daymet general kernel, but there is code below for
#retrieving newer daymet data than are available on GEE

# library(googledrive)
# library(geojsonio)
# library(rgee)

# boundaries <- st_read('in/NEON/NEONAquaticWatershed/NEON_Aquatic_Watershed.shp') %>%
#     filter(SiteID %in% neon_sites) %>%
#     select(site_code = SiteID, geometry)
#
# # load authorization email for Google Earth Engine and Google Drive.
# # same account must have access to both.
# gee_login <- read_lines('cfg/google_auth.cfg', skip_empty_rows = TRUE, n_max = 1) %>%
#     str_extract('^([^ #])+')
#
# if(gee_login == 'your_address@gmail.com') stop('you need to authorize google drive and google earth engine, and then put your authorization email in /cfg/google_auth.cfg')
#
# googledrive::drive_auth(email = gee_login)
# rgee::ee_Initialize(user = gee_login, drive = TRUE)
# user_info <- rgee::ee_user_info(quiet = TRUE)
#
# #create remote folder to hold watershed boundaries and daymet summaries
# asset_folder <- glue('{a}/neon_daymet', a = user_info$asset_home)
# rgee::ee_manage_create(asset_folder)
#
# print('uploading NEON watershed boundaries to Google Earth Engine')

# #upload boundaries one at a time (too large altogether)
# for(i in 1:nrow(boundaries)){
#     one_boundary <- boundaries[i, ]
#     asset_path <- file.path(asset_folder, one_boundary$site_code)
#     sf_as_ee(one_boundary,
#              via = 'getInfo_to_asset',
#              assetId = asset_path,
#              overwrite = TRUE,
#              quiet = TRUE)
# }

# ## set up daymet summary job
#
# asset_path <- rgee::ee_manage_assetlist(asset_folder)
#
# ws_boundary_asset <- ee$FeatureCollection(asset_path$ID[1])
# for(i in 2:nrow(asset_path)){
#     one_ws <- ee$FeatureCollection(asset_path$ID[i])
#     ws_boundary_asset <- ws_boundary_asset$merge(one_ws)
# }
#
# imgcol <- ee$ImageCollection('NASA/ORNL/DAYMET_V4')$
#     filterBounds(ws_boundary_asset)$
#     select('dayl','prcp', 'tmin', 'tmax', 'srad', 'swe', 'vp')
#
# results <- ws_boundary_asset$map(function(f){
#     fin = imgcol$map(function(i){
#         mean = i$reduceRegion(
#             geometry = f$geometry(),
#             reducer = ee$Reducer$mean(),
#             scale = 1000
#         )
#         f$setMulti(mean)$set(list(date = i$date()))
#     })
# })$flatten()
#
# gee <- results$select(
#     propertySelectors = c('site_code', 'date', 'dayl', 'prcp', 'srad', 'swe',
#                           'tmax', 'tmin', 'vp'),
#     retainGeometry = FALSE
# )
#
# ee_task <- ee$batch$Export$table$toDrive(
#     collection = gee,
#     description = 'neon_daymet_out',
#     fileFormat = 'CSV',
#     folder = 'GEE',
#     fileNamePrefix = 'rgee'
# )
#
# print('summarizing Daymet layers for NEON watersheds. may take hours or even days depending on demand.')

# #run job
# ee_task$start()
# ee_monitoring(ee_task, max_attempts = Inf)
#
# #retrieve results from google drive
# temp_rgee <- tempfile(fileext = '.csv')
# googledrive::drive_download(file = 'GEE/rgee.csv', temp_rgee)
# read_csv(temp_rgee) %>%
#     select(date, site_code, dayl, prcp, srad, swe, tmax, tmin, vp) %>%
#     write_csv('in/NEON/neon_forcings.csv')
#
# #remove remote file
# googledrive::drive_rm('GEE/rgee.csv')

# part 2 (not necessary if Daymet 2022 is on GEE by now) ####

warning('not running part 2 of summarize_neon_daymet.R, assuming Daymet 2022 is now on GEE')
do_not_run_the_following <- TRUE

if(! do_not_run_the_following){

    dir.create('in/CAMELS/daymet2022')

    #wget is one of the recommended ways to download THREDDS files (https://adc.met.no/node/95),
    #   but i think it's unix-like only? you can also use curl, download.file, etc.
    #   in the below commands, the following argument has been added:
    #       `-P in/CAMELS/daymet2022/`

    #continental USA (including Alaska)
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_dayl_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_prcp_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_srad_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_swe_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_tmin_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_tmax_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_na_vp_2022.nc'")

    #Puerto Rico
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_dayl_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_prcp_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_srad_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_swe_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_tmin_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_tmax_2022.nc'")
    system("wget -e robots=off -nH --cut-dirs 4 -nc -r -l5 -A '*.nc' -R 'catalog*' -P in/CAMELS/daymet2022/ -I /thredds/fileServer/,/thredds/catalog/ 'https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.html?dataset=2129/daymet_v4_daily_pr_vp_2022.nc'")

    #Hawaii not needed. no NEON sites


    library(terra)
    library(doFuture)
    registerDoFuture()

    ncores <- future::availableCores()

    dir.create('log', showWarnings = FALSE)
    logfile <- 'log/daymet2022.log'

    neon_sheds <- st_read('in/NEON/NEONAquaticWatershed/NEON_Aquatic_Watershed.shp') %>%
        filter(SiteID %in% !!neon_sites)
    dayf <- list.files('in/CAMELS/daymet2022') %>%
        str_subset('daily_na')

    daymet_2022 <- foreach(
        df = dayf,
        .combine = function(x, y) left_join(x, y, by = c('date', 'site_code'))) %do% {

        var <- str_extract(df, '([a-z]+)_2022\\.nc$', 1)
        rst <- terra::rast(glue('in/CAMELS/daymet2022/daymet_v4_daily_na_{var}_2022.nc'))
        rst_pr <- terra::rast(glue('in/CAMELS/daymet2022/daymet_v4_daily_pr_{var}_2022.nc'))

        var_d <- foreach(
            i = seq_len(nrow(neon_sheds)),
            .combine = bind_rows) %dopar% {

            shed_i <- neon_sheds[i, ]
            site <- shed_i$SiteID

            if(site %in% c('CUPE', 'GUIL')){
                var_d_ <- terra::extract(rst_pr, shed_i, mean, ID = FALSE)
            } else {
                var_d_ <- terra::extract(rst, shed_i, mean, ID = FALSE)
            }

            var_d_ <- tibble(date = names(var_d_),
                            !!var := unlist(var_d_, use.names = FALSE)) %>%
                mutate(date = paste('2022', str_extract(date, '[0-9]+$')),
                       date = as.POSIXct(date, format = '%Y %j'),
                       site_code = site)

            write_lines(paste(var, site, '[done]'), logfile, append = TRUE)

            return(var_d_)
        }

        return(var_d)
    }

    read_csv('in/NEON/neon_forcings.csv') %>%
        bind_rows(daymet_2022) %>%
        arrange(site_code, date) %>%
        write_csv('in/NEON/neon_forcings.csv')
}

