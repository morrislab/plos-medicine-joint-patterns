# Plots joint involvements of individual sites.

library(argparse)

library(data.table)

library(pcaMethods)

library(grid)

library(ggplot2)

library(plyr)

library(dplyr)

library(dtplyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--site-order-input')

parser$add_argument('--representative-site-input')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.data <- fread(args$data_input)

dt.clusters <- fread(args$cluster_input)

site.order <- if (!is.null(args$site_order_input)) scan(args$site_order_input, what = 'character') else NULL

dt.representative.sites <- if (!is.null(args$representative_site_input)) fread(args$representative_site_input) else NULL



message('Merging data')

dt.merged <- setkey(dt.data, subject_id)[setkey(dt.clusters, subject_id)]



message('Melting data')

dt.melted <- melt(dt.merged, id.vars = c('subject_id', 'classification'), variable.name = 'site')

dt.melted <- dt.melted[value > 0]



if (!is.null(dt.representative.sites)) {

	message('Calculating colours for sites')

	dt.colours <- data.table(expand.grid(classification = dt.clusters[, unique(classification)], site = tail(colnames(dt.data), -1)))

	setkey(dt.colours, classification, site)

	dt.representative.sites[, colour := 'black']

	setkey(dt.representative.sites, factor, site)

	dt.colours <- dt.representative.sites[dt.colours]

	dt.colours[is.na(colour), colour := grey(0.8)]

	setkey(dt.melted, classification, site)

	setkey(dt.colours, factor, site)

	dt.melted <- dt.colours[dt.melted]

}



message('Calculating order of patients')

patient.order <- dt.merged %>% dlply(.(classification), function (df.slice) {

	if (nrow(df.slice) == 1) {

		return(df.slice$subject_id)

	}

	df.slice.data <- df.slice %>% select(-subject_id, -classification)

	col.sums <- colSums(df.slice.data)

	col.vars <- sapply(df.slice.data, var)

	if (all(col.vars == 0)) {

		return(df.slice$subject_id)

	}

	df.slice.subset <- df.slice.data[, (col.sums > 0) & (col.vars > 0)]

	if (is.data.frame(df.slice.subset) && ncol(df.slice.subset) > 1) {

		pca.res <- scores(pca(df.slice.subset, nPcs = 1, center = TRUE, scale = 'uv'))

		df.slice[order(pca.res), 'subject_id']

	} else {

		df.slice[order(df.slice.subset), 'subject_id']

	}

})

dt.melted[, subject_id := factor(subject_id, as.character(Reduce(c, patient.order)))]



message('Generating plot')

theme_set(theme_classic(base_size = 8) + theme(panel.spacing = unit(4.8, 'pt'), panel.border = element_rect(fill = NA), axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt'), axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.line = element_blank(), strip.text = element_text(size = rel(1), face = 'bold'), strip.background = element_blank()))

pl <- ggplot(dt.melted, aes(x = subject_id, y = site)) +
	facet_grid(~ factor, scales = 'free_x', space = 'free_x') +
	geom_tile(aes(fill = I(colour))) + labs(x = 'Individual patients', y = 'Site') +
	scale_x_discrete(expand = c(0, 0)) +
	scale_y_discrete(expand = c(0, 0))

if (!is.null(site.order)) {

	pl <- pl + scale_y_discrete(limits = rev(site.order), expand = c(0, 0))

}



message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)

