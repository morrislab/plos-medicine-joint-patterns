# Generates square bubble plots showing transition probabilities from a
# reference visit to any future visit.

library(argparse)

library(data.table)

library(dplyr)

library(dtplyr)

library(plyr)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--stats-input')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--colour-scale', default = FALSE, action = 'store_true')

parser$add_argument('--reorder-axes', default = FALSE, action = 'store_true')

parser$add_argument('--normalize-rows', default = FALSE, action = 'store_true')

parser$add_argument('--max-size', type = 'double', default = 3)

parser$add_argument('--max-size-limit', type = 'double')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input, colClasses = c(source = 'character', target = 'character'))

setkey(dt.data, source, target)

has.significance <- !is.null(args$stats_input)

if (has.significance) {

	dt.stats <- fread(args$stats_input, colClasses = c(source = 'character', target = 'character'))

	dt.stats[, p_adjusted := p.adjust(p, method = 'holm'), by = .(source)]

	dt.stats[, significant := p_adjusted < 0.05]

	setkey(dt.stats, source, target)

	dt.data <- dt.data[dt.stats, nomatch = 0]

}



# Arrange the clusters on both axes based on transition probabilities.

dt.data.reformatted <- dcast(dt.data, source ~ target, value.var = 'probability', fill = 0)



# Arrange the clusters using mean transition probabilities.

order.row <- if (args$reorder_axes && nrow(dt.data.reformatted) > 1) {

	hclust.res.row <- hclust(dist(dt.data.reformatted %>% select(-1), method = 'euclidean'), method = 'ward.D2')

	dt.data.reformatted$source[hclust.res.row$order]

} else dt.data[, sort(unique(source))]

order.col <- if (args$reorder_axes && ncol(dt.data.reformatted) > 1) {

	hclust.res.col <- hclust(dist(t(dt.data.reformatted %>% select(-1)), method = 'euclidean'), method = 'ward.D2')

	colnames(dt.data.reformatted)[-1][hclust.res.col$order]

} else dt.data[, sort(unique(target))]



# Normalize boxes by row if required.

if (args$normalize_rows) {

	message('Normalizing rows')

	dt.data[, count_normalized := count / max(count), by = .(source)]

}



# Generate the plot.

message('Generating plot')

make.colour <- function (r, g, b, alpha) {

	r <- r + (1 - alpha) * (1 - r)

	g <- g + (1 - alpha) * (1 - g)

	b <- b + (1 - alpha) * (1 - b)

	rgb(r, g, b)

}

alpha.breakpoints <- seq(0.25, 1, length.out = 5)

this.scale <- if (args$colour_scale) c(make.colour(0, 1, 0, alpha.breakpoints[1]), make.colour(1, 1, 0, alpha.breakpoints[2]), make.colour(1, 0.65, 0, alpha.breakpoints[3]), make.colour(1, 0, 0, alpha.breakpoints[4]), make.colour(0.625, 0.125, 0.95, alpha.breakpoints[5])) else c(grey(0.85), 'black')

theme_set(theme_classic(base_size = 8) + theme(plot.title = element_text(size = rel(1), face = 'bold', hjust = 0.5), panel.spacing = unit(4.8, 'pt'), axis.text = element_text(size = rel(1)), axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1), axis.ticks.length = unit(4.8, 'pt'), strip.background = element_blank(), strip.text = element_text(size = rel(1), face = 'bold'), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1)), legend.position = 'bottom'))

pl.bubbleplot <-
	ggplot(dt.data[probability > 0], aes(x = target, y = source)) +
	{
		aes.size <- if (args$normalize_rows) ~count_normalized else ~count
		if (has.significance) {
			geom_point(aes_(fill = ~probability, size = aes.size, colour = ~significant), shape = 22, stroke = 1)
		} else {
			geom_point(aes_(fill = ~probability, size = aes.size), shape = 22)
		}
	} +
	scale_x_discrete(limits = rev(order.col), expand = c(0, 0.5)) +
	scale_y_discrete(limits = rev(order.row), expand = c(0, 0.5)) +
	scale_size_continuous(breaks = pretty, limits = c(0, if (is.null(args$max_size_limit)) NA else args$max_size_limit), range = c(0, args$max_size)) +
	scale_fill_gradientn(colours = this.scale, limits = c(1e-6, 1), na.value = 'white', breaks = pretty) +
	scale_colour_manual(values = c('FALSE' = 'transparent', 'TRUE' = 'black'), guide = FALSE) +
	labs(
		y = 'Reference patient group',
		x = 'Target patient group',
		fill = 'Transition\nprobability',
		size = if (args$normalize_rows) 'Number of patients,\nnormalized to highest count\nper reference patient group' else 'Number of\npatients'
	) +
	guides(size = guide_legend(nrow = 1)) +
	coord_fixed()



# Write the plots.

message('Writing plots')

ggsave(pl.bubbleplot, file = args$output, width = args$figure_width, height = args$figure_height)
