# Run the setup portion of acquisition_master (the part before the main loop)
# to load necessary packages and helper functions.

#increment this by 0.1 and a new folder will be populated with new diagnostic plots
vsn = 0.2

#setup ####
library(RColorBrewer)

ws_areas <- site_data %>%
    filter(as.logical(in_workflow)) %>%
    select(network, domain, site_name, ws_area_ha)

palettes = RColorBrewer::brewer.pal.info %>%
    filter(category == 'seq') %>%
    mutate(name = rownames(.))

domains = unique(site_data$domain[site_data$in_workflow == 1])
dmncolors = c(RColorBrewer::brewer.pal(12, 'Paired'),
              # RColorBrewer::brewer.pal(8, 'Accent')[6], #redund
              RColorBrewer::brewer.pal(8, 'Dark2')[c(4, 8)],
              RColorBrewer::brewer.pal(9, 'Pastel1')[7],
              RColorBrewer::brewer.pal(8, 'Pastel2')[-c(2:4, 6)])
# dmncolors = viridis::(n = length(domains))
# plot(1:15, 1:15, col=dmncolors, cex=5, pch=20) #test color distinctiveness
dmncolors = dmncolors[1:length(domains)]

dir.create(paste0('plots/diagnostic_plots_',  vsn), recursive = TRUE)

# all Q (line plot) ####

q_dirs <- list_all_product_dirs('discharge')

png(width=11, height=9, units='in', type='cairo', res=300,
    filename=paste0('plots/diagnostic_plots_',  vsn, '/Q_all.png'))

yr_seq = 1948:2021
ylims = c(-10, 2200)
plot(yr_seq, rep(1, length(yr_seq)), ylim=ylims, type='n', yaxs='i',
     xaxs = 'i', ylab='Runoff (mm/yr)', xlab='Year', xaxt='n',
     main='Annual Runoff Totals')
axis(1, seq(1950, 2020, 5))

legend_map = tibble(domain = character(), colors = list())
plotted_site_tally = 0
for(i in 1:length(q_dirs)){

    pd = q_dirs[i]

    ntw_dmn_prd <- str_match(string = pd,
                             pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

    d <- list.files(pd, full.names = TRUE) %>%
        purrr::map_dfr(read_feather) %>%
        select(-val_err) %>%
        # mutate(val = errors::set_errors(val, val_err),
        group_by(site_name, date = lubridate::as_date(datetime)) %>%
        summarize(val = mean(val),
                  .groups = 'drop') %>%
        mutate(year = lubridate::year(date),
               val = val * 86400) %>%
        group_by(site_name, year) %>%
        summarize(val = sum(val),
                  .groups = 'drop') %>%
        arrange(site_name, year) %>%
        mutate(network = ntw_dmn_prd[1],
               domain = ntw_dmn_prd[2]) %>%
        left_join(ws_areas,
                  by = c('network', 'domain', 'site_name')) %>%
        mutate(ws_area_mm2 = ws_area_ha * 10000 * 1e6,
               val = val / 1000 * 1e9 / ws_area_mm2,
               ntw_dmn_sit = paste(network, domain, site_name,
                                   sep = ' > ')) %>%
        select(year, ntw_dmn_sit, val) %>%
        arrange(ntw_dmn_sit, year)

    n_available_colors = palettes[i, 'maxcolors']
    colors = RColorBrewer::brewer.pal(n = n_available_colors,
                                      name = palettes[i, 'name'])

    legend_map = bind_rows(legend_map,
                           tibble(domain = paste(ntw_dmn_prd[1:2], collapse=' > '),
                                  colors = list(colors[3:9])))

    sites = unique(d$ntw_dmn_sit)
    for(j in 1:length(sites)){
        site = sites[j]
        color_ind = j %% (n_available_colors - 2) + 2
        color_ind = ifelse(color_ind == 2, n_available_colors, color_ind)
        ds = filter(d, ntw_dmn_sit == !!site)
        maxq = max(ds$val, na.rm = TRUE)
        if(i == 1 && j == 1){
            print('These sites have annual runoff values over 2000 mm:')
        }
        if(maxq > 2000) message(site, ': ', round(maxq, 1))
        if(any(! is.na(ds$val))) plotted_site_tally = plotted_site_tally + 1
        lines(ds$year, ds$val, col=alpha(colors[color_ind], 0.7), lwd = 2.5)
    }

}
graphics::text(x=median(yr_seq), y=quantile(ylims, 0.9),
    labels=paste0('sites: ', plotted_site_tally), adj=0.5)

defpar = par(lend=1)
for(k in 3:9){
    if(k == 3){
        legend(x=1949, y=2150, legend=legend_map$domain, bty = 'n',
               col = sapply(legend_map$colors, function(x) x[k]),
               lty=1, seg.len=1, lwd=5, x.intersp=6.5)
               # lty=1, seg.len=as.numeric(paste0('0.', k)), lwd=5)
    } else {
        legend(x=1946 + k, y=2150, legend=rep('', nrow(legend_map)), bty = 'n',
               # fill = sapply(legend_map$colors, function(x) x[k]),
               col = sapply(legend_map$colors, function(x) x[k]),
               lty=1, seg.len=1, lwd=5)
    }
}
par(defpar)

dev.off()

# Q by domain (line plots stitched) ####

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/Q_by_domain.pdf'))

yr_seq = 1948:2021
linetypes = 1:6

for(i in 1:length(q_dirs)){

    pd = q_dirs[i]

    ntw_dmn_prd <- str_match(string = pd,
                             pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

    d <- list.files(pd, full.names = TRUE) %>%
        purrr::map_dfr(read_feather) %>%
        select(-val_err) %>%
        # mutate(val = errors::set_errors(val, val_err),
        group_by(site_name, date = lubridate::as_date(datetime)) %>%
        summarize(val = mean(val),
                  .groups = 'drop') %>%
        mutate(year = lubridate::year(date),
               val = val * 86400) %>%
        group_by(site_name, year) %>%
        summarize(val = sum(val),
                  .groups = 'drop') %>%
        arrange(site_name, year) %>%
        mutate(network = ntw_dmn_prd[1],
               domain = ntw_dmn_prd[2]) %>%
        left_join(ws_areas,
                  by = c('network', 'domain', 'site_name')) %>%
        mutate(ws_area_mm2 = ws_area_ha * 10000 * 1e6,
               val = val / 1000 * 1e9 / ws_area_mm2,
               ntw_dmn_sit = paste(network, domain, site_name,
                                   sep = ' > ')) %>%
        select(year, ntw_dmn_sit, val) %>%
        arrange(ntw_dmn_sit, year)

    legend_map = tibble(site = character(), color = character(), lty=numeric())
    n_available_colors = palettes[i, 'maxcolors']
    colors = RColorBrewer::brewer.pal(n = n_available_colors,
                                      name = palettes[i, 'name'])

    ylims = c(0, min(2000, max(d$val, na.rm=TRUE)))
    if(is.infinite(ylims[2])){
        plot(1, 1, type='n', xlab='', ylab='',
             main=paste0('Annual Runoff Totals (', ntw_dmn_prd[1],
                              ' > ', ntw_dmn_prd[2], ')'))
        graphics::text(x=1, y=1, labels='!! :O', adj=0.5)
        next
    }

    plot(yr_seq, rep(1, length(yr_seq)), ylim=ylims,
         type='n', yaxs='i', xaxs = 'i', ylab='Runoff (mm/yr)', xlab='Year',
         xaxt='n', main=paste0('Annual Runoff Totals (', ntw_dmn_prd[1],
                               ' > ', ntw_dmn_prd[2], ')'))
    axis(1, seq(1950, 2020, 5))

    sites = unique(d$ntw_dmn_sit)
    j = 0
    while(j < length(sites)){
        j = j + 1
        site = sites[j]
        ds = filter(d, ntw_dmn_sit == !!site)
        if(all(is.na(ds$val))) next

        color_ind = j %% (n_available_colors - 3) + 3
        color_ind = ifelse(color_ind == 3, n_available_colors, color_ind)
        ltype = (j - 1) %/% length(linetypes) + 1
        legend_map = bind_rows(legend_map,
                               tibble(site = !!site,
                                      color = colors[color_ind],
                                      lty=ltype))
        lines(ds$year, ds$val, col=alpha(colors[color_ind], 0.7), lwd = 2.5,
              lty=ltype)
    }

    defpar = par(lend=1)
    legend(x=1949, y=quantile(ylims, 0.97), legend=legend_map$site, bty = 'n',
           col = legend_map$color,
           lty=legend_map$lty, seg.len=4, lwd=3)

    par(defpar)
}

dev.off()

# concentration of Ca, Si, Cl, NO3-N, DOC and SO4 (box plot, dark) ####

chemvars = c('Ca', 'Si', 'SiO2_Si', 'Cl', 'NO3_N', 'DOC', 'SO4_S')
ylim_maxes = c(455, 25, 25, 600, 20, 85, 600)
ylim_mins = c(-10, -0.5, -0.5, -10, -0.5, -1, -10)

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/chem_all.pdf'))
par(mar=c(14, 4, 4, 1))

for(i in 1:length(chemvars)){

    chemvar = chemvars[i]
    unit = ms_vars$unit[ms_vars$variable_code == 'Ca']
    d = load_entire_product('stream_chemistry', .sort=FALSE, filter_vars=chemvar)

    d_by_max = d %>%
        group_by(network, domain, site_name) %>%
        summarize(maxval = max(val),
                  .groups = 'drop') %>%
        mutate(ntw_dmn_sit = paste(network, domain, site_name,
                                   sep = ' > '))

    site_order = d_by_max$ntw_dmn_sit[order(d_by_max$maxval)]

    d_boxplot = d %>%
        mutate(val = errors::drop_errors(val)) %>%
        group_by(network, domain, site_name) %>%
        summarize(box_stats = list(boxplot.stats(val)),
                  .groups = 'drop') %>%
        mutate(color = dmncolors[match(domain, domains)],
               ntw_dmn_sit = paste(network, domain, site_name,
                                   sep = ' > '))

    included_domain_inds = which(domains %in% unique(d_by_max$domain))
    excluded_domains = domains[-included_domain_inds]
    included_domains = domains[included_domain_inds]
    included_dmncolors = dmncolors[included_domain_inds]

    d_boxplot = d_boxplot[rev(order(match(d_boxplot$ntw_dmn_sit, site_order))), ]

    nsites = nrow(d_boxplot)
    ylims = c(ylim_mins[i], ylim_maxes[i])
    plot(1:nsites, rep(0, nsites), ylim=ylims, type='n',
         ylab=paste0(chemvar, ' (', unit, ')'), xlab='', xaxt='n', yaxs='i',
         main=paste0('Concentration (', chemvar, ')'), xlim=c(1, nsites))
    corners = par("usr")
    rect(corners[1], corners[3], corners[2], corners[4], col = 'black')

    for(j in 1:nsites){
        color = slice(d_boxplot, j) %>% pull(color)
        stats = (slice(d_boxplot, j) %>% pull(box_stats))[[1]]
        outliers = stats$out
        box_whisk = stats$stats
        segments(x0=j, x1=j, y0=box_whisk[1], y1=box_whisk[2], col=color,
                 lwd=2, lend=3)
        points(x=j, y=box_whisk[3], col=color, pch=20)
        segments(x0=j, x1=j, y0=box_whisk[4], y1=box_whisk[5], col=color,
                 lwd=2, lend=3)
        points(x=rep(j, length(outliers)), y=outliers, col=color, pch=20, cex=0.2)
    }

    axis_seq_1 = seq(1, nsites, 2)
    axis_seq_2 = seq(2, nsites, 2)
    axis(1, at=axis_seq_1, labels=d_boxplot$site_name[axis_seq_1],
         las=2, cex.axis=0.6, tcl=-0.6)
    axis(1, at=axis_seq_2, labels=d_boxplot$site_name[axis_seq_2],
         las=2, cex.axis=0.6, tcl=-0.6, line=6.5, tick=FALSE)
    axis(1, at=axis_seq_2, labels=rep('', length(axis_seq_2)), tcl=-7)
    legend('topright', legend=included_domains, lty=1, col=included_dmncolors, bty='n', lwd=3,
           text.col='white')
    newline_seq = try(seq(6, length(excluded_domains), 6), silent=TRUE)
    if(! inherits(newline_seq, 'try-error')){
        excluded_domains[newline_seq] = paste0('\n', excluded_domains[newline_seq])
    }
    graphics::text(x=quantile(1:nsites, 0.15),
                   y=quantile(ylims, 0.95), adj=0, col='green',
                   labels=paste0('Sites: ', length(unique(d_boxplot$ntw_dmn_sit))))
    graphics::text(x=quantile(1:nsites, 0.15),
                   y=quantile(ylims, 0.9), adj=0, col='pink',
                   labels=paste0('Missing domains: ',
                                 paste(excluded_domains, collapse = ', ')))
}

dev.off()


# Q vs. flux of Ca, Si, Cl, NO3-N, DOC and SO4 (scatter plot, dark) ####

fluxvars = c('Ca', 'Si', 'SiO2_Si', 'Cl', 'NO3_N', 'DOC', 'SO4_S')
ylim_maxes = c(1500, 300, 3000, 11000, 800, 4000, 700)
# ylim_maxes = c(455, 25, 25, 600, 20, 85, 600)
legend_position = c('topleft', 'topright', 'topright', 'topright', 'topleft', 'topright', 'topleft')

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/Q_vs_flux_all.pdf'))
par(mar=c(14, 4, 4, 1))

q_dirs <- list_all_product_dirs('discharge')

flux_ranges = q_ranges = tibble()
for(k in 1:length(fluxvars)){

    fluxvar = fluxvars[k]

    plot(1, 1, xlim=c(0, 1700), ylim=c(0, ylim_maxes[k]), type='n', yaxs='i',
         xaxs = 'i', ylab='Annual Flux (kg/ha)', xlab='Annual Runoff (mm)',
         main=paste0('Annual Q vs. Flux (', fluxvar, ')'))
    corners = par("usr")
    rect(corners[1], corners[3], corners[2], corners[4], col = 'black')

    dflux <- load_entire_product('stream_flux_inst', .sort=FALSE,
                                 filter_vars=fluxvar)

    included_domains = c()
    for(i in 1:length(q_dirs)){

        pd = q_dirs[i]

        ntw_dmn_prd = str_match(string = pd,
                                 pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

        dflux_var_year = dflux %>%
            filter(domain == ntw_dmn_prd[2]) %>%
            mutate(ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > '),
                   year = lubridate::year(datetime),
                   month = lubridate::month(datetime),
                   val = errors::drop_errors(val)) %>%
            group_by(ntw_dmn_sit, year, month) %>%
            summarise(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(days_in_month = case_when(month %in% c(1,3,5,7,8,10,12) ~ 31,
                                             month %in% c(4,6,9,11) ~ 30,
                                             month == 2 ~ 28)) %>%
            mutate(val = val * days_in_month) %>%
            group_by(ntw_dmn_sit, year) %>%
            summarize(val = sum(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            tidyr::extract(col = ntw_dmn_sit,
                           into = c('network', 'domain', 'site_name'),
                           regex = '(.+?) > (.+?) > (.+)',
                           remove = FALSE) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(val = val / ws_area_ha) %>%
            select(year, ntw_dmn_sit, flux = val) %>%
            arrange(ntw_dmn_sit, year)

        dflow = list.files(pd, full.names = TRUE) %>%
            purrr::map_dfr(read_feather) %>%
            select(-val_err) %>%
            group_by(site_name, date = lubridate::as_date(datetime)) %>%
            summarize(val = mean(val),
                      .groups = 'drop') %>%
            mutate(year = lubridate::year(date),
                   val = val * 86400) %>%
            group_by(site_name, year) %>%
            summarize(val = sum(val),
                      .groups = 'drop') %>%
            arrange(site_name, year) %>%
            mutate(network = ntw_dmn_prd[1],
                   domain = ntw_dmn_prd[2]) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(ws_area_mm2 = ws_area_ha * 10000 * 1e6,
                   val = val / 1000 * 1e9 / ws_area_mm2,
                   ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > ')) %>%
            select(year, ntw_dmn_sit, flow = val) %>%
            arrange(ntw_dmn_sit, year)

        d = left_join(dflux_var_year, dflow, by = c('ntw_dmn_sit', 'year')) %>%
            tidyr::extract(col = 'ntw_dmn_sit',
                           into = 'domain',
                           regex = '.+? > (.+?) > .+') %>%
            mutate(color = dmncolors[match(domain, domains)])

        if(any(! is.na(d$flux) & ! is.na(d$flow))){
            included_domains = c(included_domains, ntw_dmn_prd[2])
        }

        points(d$flow, d$flux, pch=1, cex=0.8, lwd=2, col=d$color)

        flux_ranges = bind_rows(flux_ranges,
                                tibble(network = ntw_dmn_prd[1],
                                       domain = ntw_dmn_prd[2],
                                       var = fluxvar,
                                       min = min(d$flux, na.rm = TRUE),
                                       max = max(d$flux, na.rm = TRUE)))
        q_ranges = bind_rows(q_ranges,
                             tibble(network = ntw_dmn_prd[1],
                                    domain = ntw_dmn_prd[2],
                                    var = paste0('Q_of_', fluxvar, '_flux_mmyr'),
                                    min = min(d$flow, na.rm = TRUE),
                                    max = max(d$flow, na.rm = TRUE)))
    }

    legend(legend_position[k], legend=included_domains, pch=1, cex=0.8, pt.lwd=2,
           col=dmncolors[match(included_domains, domains)], bty='n',
           text.col='white')
}
flux_ranges = arrange(flux_ranges, var, network, domain)
q_ranges = arrange(q_ranges, network, domain)
write_csv(flux_ranges, paste0('plots/diagnostic_plots_', vsn, '/flux_ranges.csv'))
write_csv(q_ranges, paste0('plots/diagnostic_plots_', vsn, '/q_ranges.csv'))

dev.off()

# Q vs. flux of Ca, Si, Cl, NO3-N, DOC and SO4 (scatter plot with log axes, dark) ####

fluxvars = c('Ca', 'Si', 'SiO2_Si', 'Cl', 'NO3_N', 'DOC', 'SO4_S')
ylim_maxes = log(c(1500, 300, 3000, 11000, 800, 4000, 700))
xlim_mins = log(c(10, 10, 10, 10, 10, 0.1, 10))
# ylim_maxes = c(455, 25, 25, 600, 20, 85, 600)
# ylim_mins = log(rep(0.1, length(fluxvars)))
# legend_position = c('topleft', 'topright', 'topright', 'topright', 'topleft', 'topright', 'topleft')
legend_position = rep('topleft', length(fluxvars))
log_ticks = c(0.1, 1, 10, 100, 1000, 10000)

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/Q_vs_flux_all_log.pdf'))
par(mar=c(14, 4, 4, 1))

q_dirs <- list_all_product_dirs('discharge')

flux_ranges = q_ranges = tibble()
for(k in 1:length(fluxvars)){

    fluxvar = fluxvars[k]

    plot(1, 1, xlim=c(xlim_mins[k], log(1700)), ylim=c(0, ylim_maxes[k]), type='n', yaxs='i',
         xaxs = 'i', ylab='Annual Flux (kg/ha)', xlab='Annual Runoff (mm)',
         main=paste0('Annual Q vs. Flux (', fluxvar, ')'), xaxt='n', yaxt='n')
    axis(1, at=log(log_ticks), labels = log_ticks)
    axis(2, at=log(log_ticks), labels = log_ticks)
    corners = par("usr")
    rect(corners[1], corners[3], corners[2], corners[4], col = 'black')

    dflux <- load_entire_product('stream_flux_inst', .sort=FALSE,
                                 filter_vars=fluxvar)

    included_domains = c()
    for(i in 1:length(q_dirs)){

        pd = q_dirs[i]

        ntw_dmn_prd = str_match(string = pd,
                                 pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

        dflux_var_year = dflux %>%
            filter(domain == ntw_dmn_prd[2]) %>%
            mutate(ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > '),
                   year = lubridate::year(datetime),
                   month = lubridate::month(datetime),
                   val = errors::drop_errors(val)) %>%
            group_by(ntw_dmn_sit, year, month) %>%
            summarise(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(days_in_month = case_when(month %in% c(1,3,5,7,8,10,12) ~ 31,
                                             month %in% c(4,6,9,11) ~ 30,
                                             month == 2 ~ 28)) %>%
            mutate(val = val * days_in_month) %>%
            group_by(ntw_dmn_sit, year) %>%
            summarize(val = sum(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            tidyr::extract(col = ntw_dmn_sit,
                           into = c('network', 'domain', 'site_name'),
                           regex = '(.+?) > (.+?) > (.+)',
                           remove = FALSE) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(val = log(val / ws_area_ha)) %>%
            select(year, ntw_dmn_sit, flux = val) %>%
            arrange(ntw_dmn_sit, year)

        dflow = list.files(pd, full.names = TRUE) %>%
            purrr::map_dfr(read_feather) %>%
            select(-val_err) %>%
            group_by(site_name, date = lubridate::as_date(datetime)) %>%
            summarize(val = mean(val),
                      .groups = 'drop') %>%
            mutate(year = lubridate::year(date),
                   val = val * 86400) %>%
            group_by(site_name, year) %>%
            summarize(val = sum(val),
                      .groups = 'drop') %>%
            arrange(site_name, year) %>%
            mutate(network = ntw_dmn_prd[1],
                   domain = ntw_dmn_prd[2]) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(ws_area_mm2 = ws_area_ha * 10000 * 1e6,
                   val = log(val / 1000 * 1e9 / ws_area_mm2),
                   ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > ')) %>%
            select(year, ntw_dmn_sit, flow = val) %>%
            arrange(ntw_dmn_sit, year)

        d = left_join(dflux_var_year, dflow, by = c('ntw_dmn_sit', 'year')) %>%
            tidyr::extract(col = 'ntw_dmn_sit',
                           into = 'domain',
                           regex = '.+? > (.+?) > .+') %>%
            mutate(color = dmncolors[match(domain, domains)])

        if(any(! is.na(d$flux) & ! is.na(d$flow))){
            included_domains = c(included_domains, ntw_dmn_prd[2])
        }

        points(d$flow, d$flux, pch=1, cex=0.8, lwd=2, col=d$color)

        flux_ranges = bind_rows(flux_ranges,
                                tibble(network = ntw_dmn_prd[1],
                                       domain = ntw_dmn_prd[2],
                                       var = fluxvar,
                                       min = min(d$flux, na.rm = TRUE),
                                       max = max(d$flux, na.rm = TRUE)))
        q_ranges = bind_rows(q_ranges,
                             tibble(network = ntw_dmn_prd[1],
                                    domain = ntw_dmn_prd[2],
                                    var = paste0('Q_of_', fluxvar, '_flux_mmyr'),
                                    min = min(d$flow, na.rm = TRUE),
                                    max = max(d$flow, na.rm = TRUE)))
    }

    legend(legend_position[k], legend=included_domains, pch=1, cex=0.8, pt.lwd=2,
           col=dmncolors[match(included_domains, domains)], bty='n',
           text.col='white')
}

dev.off()

# all flux (line plot) ####

fluxvars = c('Ca', 'Si', 'SiO2_Si', 'Cl', 'NO3_N', 'DOC', 'SO4_S')
# ylim_maxes = rep(10000, length(fluxvars))
# ylim_maxes = c(455, 25, 25, 600, 20, 85, 600)
ylim_maxes = c(1500, 300, 3000, 11000, 800, 4000, 700)
# ylim_maxes = c(3000, 500, 4000, 11000, 1000, 4000, 1000)
ylim_mins = c(-10, -0.5, -0.5, -10, -0.5, -1, -10)
legend_position = rep('topleft', length(fluxvars))
# legend_position = c('topleft', 'topright', 'topright', 'topright', 'topleft', 'topright', 'topleft')

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/flux_all.pdf'))
par(mar=c(14, 4, 4, 1))

q_dirs <- list_all_product_dirs('discharge')

yr_seq = 1948:2021
for(k in 1:length(fluxvars)){

    fluxvar = fluxvars[k]

    plot(yr_seq, rep(1, length(yr_seq)), ylim=c(ylim_mins[k], ylim_maxes[k]),
         type='n', yaxs='i', xaxs = 'i', ylab='Flux (kg/ha/yr)', xlab='Year', xaxt='n',
         main=paste0('Annual Flux (', fluxvar, ')'))
    axis(1, seq(1950, 2020, 5))

    dflux <- load_entire_product('stream_flux_inst', .sort=FALSE,
                                 filter_vars=fluxvar)

    included_domains = c()
    plotted_site_tally = 0
    legend_map = tibble(domain = character(), colors = list())
    for(i in 1:length(q_dirs)){

        ntw_dmn_prd = str_match(string = q_dirs[i],
                                pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

        dflux_var_year = dflux %>%
            filter(domain == ntw_dmn_prd[2]) %>%
            mutate(ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > '),
                   year = lubridate::year(datetime),
                   month = lubridate::month(datetime),
                   val = errors::drop_errors(val)) %>%
            group_by(ntw_dmn_sit, year, month) %>%
            summarise(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(days_in_month = case_when(month %in% c(1,3,5,7,8,10,12) ~ 31,
                                             month %in% c(4,6,9,11) ~ 30,
                                             month == 2 ~ 28)) %>%
            mutate(val = val * days_in_month) %>%
            group_by(ntw_dmn_sit, year) %>%
            summarize(val = sum(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            tidyr::extract(col = ntw_dmn_sit,
                           into = c('network', 'domain', 'site_name'),
                           regex = '(.+?) > (.+?) > (.+)',
                           remove = FALSE) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(val = val / ws_area_ha) %>%
            filter(! is.na(val)) %>%
            select(year, ntw_dmn_sit, domain, flux = val) %>%
            arrange(ntw_dmn_sit, year)

        if(! nrow(dflux_var_year)){
            message(paste0('no ', fluxvar, ' flux for domain: ', ntw_dmn_prd[2]))
            next
        }

        included_domains = c(included_domains, ntw_dmn_prd[2])

        n_available_colors = palettes[i, 'maxcolors']
        colors = RColorBrewer::brewer.pal(n = n_available_colors,
                                          name = palettes[i, 'name'])

        legend_map = bind_rows(legend_map,
                               tibble(domain = paste(ntw_dmn_prd[1:2], collapse=' > '),
                                      colors = list(colors[3:9])))

        sites = unique(dflux_var_year$ntw_dmn_sit)
        for(j in 1:length(sites)){
            site = sites[j]
            color_ind = j %% (n_available_colors - 2) + 2
            color_ind = ifelse(color_ind == 2, n_available_colors, color_ind)
            ds = filter(dflux_var_year, ntw_dmn_sit == !!site)
            if(any(! is.na(ds$flux))) plotted_site_tally = plotted_site_tally + 1
            lines(ds$year, ds$flux, col=alpha(colors[color_ind], 0.7), lwd = 2.5)
        }
    }

    graphics::text(x=median(yr_seq), y=quantile(c(0, ylim_maxes[k]), 0.9),
                   labels=paste0('sites: ', plotted_site_tally), adj=0.5)

    defpar = par(lend=1)
    for(j in 3:9){
        if(j == 3){
            legend(x=1949, y=quantile(c(0, ylim_maxes[k]), 0.95),
                   legend=legend_map$domain, bty = 'n',
                   col = sapply(legend_map$colors, function(x) x[j]),
                   lty=1, seg.len=1, lwd=5, x.intersp=6.5)
        } else {
            legend(x=1946 + j, y=quantile(c(0, ylim_maxes[k]), 0.95),
                   legend=rep('', nrow(legend_map)), bty = 'n',
                   col = sapply(legend_map$colors, function(x) x[j]),
                   lty=1, seg.len=1, lwd=5)
        }
    }
    par(defpar)
}

dev.off()

# all flux (line plot with log-Y-axis) ####

fluxvars = c('Ca', 'Si', 'SiO2_Si', 'Cl', 'NO3_N', 'DOC', 'SO4_S')
# ylim_maxes = rep(10000, length(fluxvars))
# ylim_maxes = c(455, 25, 25, 600, 20, 85, 600)
ylim_maxes = log(c(1500, 300, 3000, 11000, 800, 4000, 700))
# ylim_maxes = c(3000, 500, 4000, 11000, 1000, 4000, 1000)
ylim_mins = log(c(10, 0.5, 0.5, 10, 0.5, 1, 10)) * -1
# ylim_mins = log(rep(0.1, length(fluxvars)))
legend_position = c('bottomleft', 'topleft', 'topleft', 'topleft', 'topleft', 'topleft', 'bottomleft')

pdf(width=11, height=9, onefile=TRUE,
    file=paste0('plots/diagnostic_plots_',  vsn, '/flux_all_log.pdf'))
par(mar=c(14, 4, 4, 1))

q_dirs <- list_all_product_dirs('discharge')

yr_seq = 1948:2021
log_ticks = c(0.1, 1, 10, 100, 1000, 10000)
for(k in 1:length(fluxvars)){

    fluxvar = fluxvars[k]

    plot(yr_seq, rep(1, length(yr_seq)), ylim=c(ylim_mins[k], ylim_maxes[k]),
         type='n', yaxs='i', xaxs = 'i', ylab='Flux (kg/ha/yr)', xlab='Year',
         xaxt='n', yaxt='n',
         main=paste0('Annual Flux (', fluxvar, ')'))
    axis(1, seq(1950, 2020, 5))

    dflux <- load_entire_product('stream_flux_inst', .sort=FALSE,
                                 filter_vars=fluxvar)
    axis(2, at=log(log_ticks), labels = log_ticks)

    included_domains = c()
    plotted_site_tally = 0
    legend_map = tibble(domain = character(), colors = list())
    for(i in 1:length(q_dirs)){

        ntw_dmn_prd = str_match(string = q_dirs[i],
                                pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

        dflux_var_year = dflux %>%
            filter(domain == ntw_dmn_prd[2]) %>%
            mutate(ntw_dmn_sit = paste(network, domain, site_name,
                                       sep = ' > '),
                   year = lubridate::year(datetime),
                   month = lubridate::month(datetime),
                   val = errors::drop_errors(val)) %>%
            group_by(ntw_dmn_sit, year, month) %>%
            summarise(val = mean(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            mutate(days_in_month = case_when(month %in% c(1,3,5,7,8,10,12) ~ 31,
                                             month %in% c(4,6,9,11) ~ 30,
                                             month == 2 ~ 28)) %>%
            mutate(val = val * days_in_month) %>%
            group_by(ntw_dmn_sit, year) %>%
            summarize(val = sum(val, na.rm = TRUE),
                      .groups = 'drop') %>%
            tidyr::extract(col = ntw_dmn_sit,
                           into = c('network', 'domain', 'site_name'),
                           regex = '(.+?) > (.+?) > (.+)',
                           remove = FALSE) %>%
            left_join(ws_areas,
                      by = c('network', 'domain', 'site_name')) %>%
            mutate(val = log(val / ws_area_ha)) %>%
            filter(! is.na(val)) %>%
            select(year, ntw_dmn_sit, domain, flux = val) %>%
            arrange(ntw_dmn_sit, year)

        if(! nrow(dflux_var_year)){
            message(paste0('no ', fluxvar, ' flux for domain: ', ntw_dmn_prd[2]))
            next
        }

        included_domains = c(included_domains, ntw_dmn_prd[2])

        n_available_colors = palettes[i, 'maxcolors']
        colors = RColorBrewer::brewer.pal(n = n_available_colors,
                                          name = palettes[i, 'name'])

        legend_map = bind_rows(legend_map,
                               tibble(domain = paste(ntw_dmn_prd[1:2], collapse=' > '),
                                      colors = list(colors[3:9])))

        sites = unique(dflux_var_year$ntw_dmn_sit)
        for(j in 1:length(sites)){
            site = sites[j]
            color_ind = j %% (n_available_colors - 2) + 2
            color_ind = ifelse(color_ind == 2, n_available_colors, color_ind)
            ds = filter(dflux_var_year, ntw_dmn_sit == !!site)
            if(any(! is.na(ds$flux))) plotted_site_tally = plotted_site_tally + 1
            lines(ds$year, ds$flux, col=alpha(colors[color_ind], 0.7), lwd = 2.5)
        }
    }

    graphics::text(x=median(yr_seq), y=quantile(c(0, ylim_maxes[k]), 0.9),
                   labels=paste0('sites: ', plotted_site_tally), adj=0.5)

    defpar = par(lend=1)
    for(j in 3:9){
        if(j == 3){
            legend(x=1949, y=quantile(c(0, ylim_maxes[k]), 0.95),
                   legend=legend_map$domain, bty = 'n',
                   col = sapply(legend_map$colors, function(x) x[j]),
                   lty=1, seg.len=1, lwd=5, x.intersp=6.5)
        } else {
            legend(x=1946 + j, y=quantile(c(0, ylim_maxes[k]), 0.95),
                   legend=rep('', nrow(legend_map)), bty = 'n',
                   col = sapply(legend_map$colors, function(x) x[j]),
                   lty=1, seg.len=1, lwd=5)
        }
    }
    par(defpar)
}

dev.off()


# all Q (box plot with log-Y-axis, dark) ####

q_dirs <- list_all_product_dirs('discharge')

plotted_site_tally = 0
d_by_max = d_boxplot = tibble()
for(i in 1:length(q_dirs)){

    pd = q_dirs[i]

    ntw_dmn_prd <- str_match(string = pd,
                             pattern = '^data/(.+?)/(.+?)/derived/(.+?)$')[, 2:4]

    d = list.files(pd, full.names = TRUE) %>%
        purrr::map_dfr(read_feather) %>%
        select(-val_err) %>%
        # mutate(val = errors::set_errors(val, val_err),
        group_by(site_name, date = lubridate::as_date(datetime)) %>%
        summarize(val = mean(val),
                  .groups = 'drop') %>%
        mutate(year = lubridate::year(date),
               val = val * 86400) %>%
        group_by(site_name, year) %>%
        summarize(val = sum(val),
                  .groups = 'drop') %>%
        arrange(site_name, year) %>%
        mutate(network = ntw_dmn_prd[1],
               domain = ntw_dmn_prd[2]) %>%
        left_join(ws_areas,
                  by = c('network', 'domain', 'site_name')) %>%
        mutate(ws_area_mm2 = ws_area_ha * 10000 * 1e6,
               val = val / 1000 * 1e9 / ws_area_mm2,
               ntw_dmn_sit = paste(network, domain, site_name,
                                   sep = ' > ')) %>%
        select(year, ntw_dmn_sit, val) %>%
        arrange(ntw_dmn_sit, year)

    d_by_max = d %>%
        group_by(ntw_dmn_sit) %>%
        summarize(maxval = max(val),
                  .groups = 'drop') %>%
        filter(! is.na(maxval)) %>%
        mutate(domain = ntw_dmn_prd[2]) %>%
        bind_rows(d_by_max)

    d_boxplot = d %>%
        filter(ntw_dmn_sit %in% unique(d_by_max$ntw_dmn_sit)) %>%
        group_by(ntw_dmn_sit) %>%
        summarize(box_stats = list(boxplot.stats(val)),
                  .groups = 'drop') %>%
        mutate(color = dmncolors[ntw_dmn_prd[2] == domains],
               site_name = str_match(ntw_dmn_sit, '.+? > .+? > (.+)$')[, 2]) %>%
        bind_rows(d_boxplot)
}

d_boxplot = filter(d_boxplot,
                   ntw_dmn_sit %in% d_by_max$ntw_dmn_sit)

site_order = d_by_max$ntw_dmn_sit[order(d_by_max$maxval)]

included_domain_inds = which(domains %in% unique(d_by_max$domain))
excluded_domains = domains[-included_domain_inds]
included_domains = domains[included_domain_inds]
included_dmncolors = dmncolors[included_domain_inds]

d_boxplot = d_boxplot[rev(order(match(d_boxplot$ntw_dmn_sit, site_order))), ]

par(mar=c(14, 4, 4, 1))
ylims = log(c(0.1, 2.7e6))
y_ticks = c(0.1, 1, 10, 100, 1000, 10000, 1e5, 1e6)

png(width=11, height=9, units='in', type='cairo', res=300,
    filename=paste0('plots/diagnostic_plots_',  vsn, '/Q_all_box.png'))

nsites = nrow(d_boxplot)
plot(1:nsites, rep(1, nsites), ylim=ylims, type='n',
     ylab='Runoff (mm/yr)', xlab='', xaxt='n', yaxs='i',
     main=paste0('Annual Runoff'), xlim=c(1, nsites), yaxt='n')
axis(2, log(y_ticks), y_ticks)
corners = par("usr")
rect(corners[1], corners[3], corners[2], corners[4], col = 'black')

for(j in 1:nsites){
    color = slice(d_boxplot, j) %>% pull(color)
    stats = (slice(d_boxplot, j) %>% pull(box_stats))[[1]]
    outliers = log(stats$out)
    box_whisk = log(stats$stats)
    segments(x0=j, x1=j, y0=box_whisk[1], y1=box_whisk[2], col=color,
             lwd=2, lend=3)
    points(x=j, y=box_whisk[3], col=color, pch=20)
    segments(x0=j, x1=j, y0=box_whisk[4], y1=box_whisk[5], col=color,
             lwd=2, lend=3)
    points(x=rep(j, length(outliers)), y=outliers, col=color, pch=20, cex=0.2)
}

axis_seq_1 = seq(1, nsites, 2)
axis_seq_2 = seq(2, nsites, 2)
axis(1, at=axis_seq_1, labels=d_boxplot$site_name[axis_seq_1],
     las=2, cex.axis=0.6, tcl=-0.6)
axis(1, at=axis_seq_2, labels=d_boxplot$site_name[axis_seq_2],
     las=2, cex.axis=0.6, tcl=-0.6, line=6.5, tick=FALSE)
axis(1, at=axis_seq_2, labels=rep('', length(axis_seq_2)), tcl=-7)
legend('topright', legend=included_domains, lty=1, col=included_dmncolors, bty='n', lwd=3,
       text.col='white')
newline_seq = try(seq(6, length(excluded_domains), 6), silent=TRUE)
if(! inherits(newline_seq, 'try-error')){
    excluded_domains[newline_seq] = paste0('\n', excluded_domains[newline_seq])
}
graphics::text(x=quantile(1:nsites, 0.15),
               y=quantile(ylims, 0.95), adj=0, col='green',
               labels=paste0('Sites: ', length(unique(d_boxplot$ntw_dmn_sit))))
graphics::text(x=quantile(1:nsites, 0.15),
               y=quantile(ylims, 0.9), adj=0, col='pink',
               labels=paste0('Missing domains: ',
                             paste(excluded_domains, collapse = ', ')))

dev.off()
