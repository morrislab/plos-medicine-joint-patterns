# Plots deltas in co-involvements.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--delta-input', required = TRUE)

parser$add_argument('--site-order-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.deltas <- fread(args$delta_input)

site.order <- scan(args$site_order_input, what = 'character')



# Plot the data.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			plot.title = element_text(size = rel(1), face = 'bold'),
			axis.text = element_text(size = rel(1)),
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(4.8, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			legend.position = 'bottom'
		)
)

pl.off.diagonal <- ggplot(dt.deltas[co_occurring_site_root != reference_site_root], aes(x = co_occurring_site_root, y = reference_site_root, fill = delta)) +
	geom_tile() +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red', breaks = pretty) +
	labs(title = 'Off-diagonals', x = 'Co-occurring site', y = 'Reference site', fill = 'Delta') +
	theme(aspect.ratio = 1)



pl.on.diagonal <- ggplot(dt.deltas[co_occurring_site_root == reference_site_root], aes(x = 1, y = reference_site_root, fill = delta)) +
	geom_tile() +
	scale_x_discrete(expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red', breaks = pretty) +
	coord_fixed() +
	labs(title = 'Diagonals', x = NA, y = 'Site', fill = 'Delta')



# Write the figure.

message('Writing output')

pdf(args$output, width = args$figure_width, height = args$figure_height)

print(pl.off.diagonal)

print(pl.on.diagonal)

dev.off()
