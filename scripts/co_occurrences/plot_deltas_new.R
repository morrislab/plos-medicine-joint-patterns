# Plots sums of differences in co-occurrence matrix entries.

library(argparse)

library(data.table)

library(feather)

library(stringr)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE, help = 'the Feather file to read input from')

parser$add_argument('--site-order-input', required = TRUE, help = 'the text file specifying the order of site types')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--figure-width', type = 'double', required = TRUE, default = 6, help = 'the figure width')

parser$add_argument('--figure-height', type = 'double', required = TRUE, default = 6, help = 'the figure height')

args <- parser$parse_args()



message('Loading site order')

site.order <- scan(args$site_order_input, what = 'character')



message('Loading data')

df.data <- setDT(read_feather(args$data_input))

df.data[, co_occurring_side := str_extract(co_occurring_joint, '(left|right)$')]

df.data[, co_occurring_type := sub('_(left|right)$', '', co_occurring_joint)]

# Ignore the diagonal, as this quantity is 1 - whatever the opposite side is.

df.data <- df.data[co_occurring_type != reference_type]



message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			aspect.ratio = 1,
			axis.text = element_text(size = rel(0.75)),
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(4.8, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			legend.position = 'bottom'
		)
)

pl <- ggplot(df.data, aes(x = co_occurring_type, y = reference_type)) +
	facet_grid(. ~ co_occurring_side) +
	geom_tile(aes(fill = delta)) +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red') +
	labs(x = 'Co-occurring site type', y = 'Reference site type', fill = 'P(same side | same side) - P(same side | opposite side)')



message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
