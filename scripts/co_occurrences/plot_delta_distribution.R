# Plots distributions of delta values.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.deltas <- fread(args$input)

dt.deltas[, is_same_site := reference_site_root == co_occurring_site_root]



# Generate the plots.

message('Generating plots')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(4.8, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold')
		)
)

pl <- ggplot(dt.deltas, aes(x = delta)) +
	geom_density(colour = NA, fill = grey(0.8)) +
	scale_x_continuous(breaks = pretty) +
	scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
	labs(x = 'Delta', y = 'Density')



# Write the plot.

message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
