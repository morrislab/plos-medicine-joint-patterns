# Plots probabilities of gaining non-representative joints per patient group.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--site-order')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)



# Load the site order, if specified.

site.order <- if (!is.null(args$site_order)) scan(args$site_order, what = 'character') else NULL



# Generate the plot.

message('Generating plot')

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt'), legend.position = 'bottom', legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1))))

weather.colours <- function (n = 5) {

	# Generate adjustment breakpoints.

	adjust.breakpoints <- seq(0.25, 1, length.out = n)

	# Obtain base RGB values to modify.

	get.values <- function (x) approx(1:5, x, n = n)$y

	values <- list(
		r = get.values(c(0, 1, 1, 1, 0.625)),
		g = get.values(c(1, 1, 0.65, 0, 0.125)),
		b = get.values(c(0, 0, 0, 0, 0.95))
	)

	# Generate the scale.

	sapply(1:n, function (i) {
		adjust.i <- adjust.breakpoints[i]
		values.i <- sapply(values, '[', i)
		do.call(rgb, as.list(values.i + (1 - adjust.i) * (1 - values.i)))
	})

}

this.pal <- weather.colours()

pl <- ggplot(dt.data, aes(x = classification, y = site)) +
	geom_tile(aes(fill = probability)) +
	scale_x_discrete(expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradientn(colours = this.pal, limits = c(1e-6, 1), na.value = 'white', breaks = pretty) +
	labs(x = 'Classification', y = 'Site', fill = 'Gain\nprobability')



# Write the output.

message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
