# Plots ratios of co-involvement frequencies.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(dplyr)

library(dtplyr)

rm(list = ls())

parser <- ArgumentParser()

parser$add_argument('--ratio-input', required = TRUE, help = 'the CSV file to read ratios from')

parser$add_argument('--stats-input', required = TRUE, help = 'the CSV file to read stats from')

parser$add_argument('--site-order-input', help = 'the text file to read the site order from')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--plot-all', default = FALSE, action = 'store_true', help = 'plot all ratios regardless of significance')

parser$add_argument('--figure-width', type = 'double', default = 7, help = 'the width of the figure')

parser$add_argument('--figure-height', type = 'double', default = 7, help = 'the height of the figure')

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.ratios <- fread(args$ratio_input)

df.stats <- fread(args$stats_input)

site.order <- if (!is.null(args$site_order_input)) scan(args$site_order_input, what = 'character') else NULL



# Filter the ratios.

message('Joining data')

df.stats <- df.stats %>%
	mutate(significant = p < 0.05 & q_n_fp < 1)

df.joined <- df.ratios %>%
	merge(df.stats, by.x = c('reference_joint', 'co_occurring_root'), by.y = c('reference', 'conditional'))

if (!args$plot_all) {

	df.joined[
		significant == FALSE,
		ratio := NA
	]

}



# Take care of clipping the data.

message('Clipping data')

ratios <- df.joined[, ratio]

ratios <- ratios[is.finite(ratios) & ratios > 0]

pow <- max(abs(log(range(ratios))))

df.joined[
	ratio == 0.0 | is.infinite(ratio),
	ratio := exp((sign(ratio) * 2 - 1) * pow)
]

fill.range <- log10(exp(c(-1, 1) * pow))

message('Range: ', paste(fill.range, collapse = ', '))



# Generate the plot.

message('Generating plot')

if (is.null(site.order)) {

	site.order <- sort(unique(df.joined$reference_root))

}

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 1,
			panel.spacing = unit(9.6, 'pt'),
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(3.6, 'pt'),
			strip.text = element_text(size = rel(1), face = 'bold'),
			strip.background = element_blank(),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			legend.position = 'right'
		)
)

pl <- ggplot(df.joined, aes(x = co_occurring_root, y = reference_root)) +
	facet_grid(reference_side ~ .) +
	{
		if (args$plot_all) {
			geom_tile(aes(fill = log10(ratio), colour = significant), size = rel(1))
		} else {
			geom_tile(aes(fill = log10(ratio)))
		}
	} +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_colour_manual(values = c('TRUE' = 'black', 'FALSE' = 'transparent')) +
	scale_fill_gradient2(low = 'blue', high = 'red', na.value = 'white', breaks = pretty, limits = fill.range) +
	labs(x = 'Co-occurring site', y = 'Reference site', fill = 'log10(ratio)', colour = 'P < 0.05\nand\nE[FP] < 1')



message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)

