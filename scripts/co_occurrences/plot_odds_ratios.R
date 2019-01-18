# Plots odds ratios for co-involvements.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE, help = 'the CSV file to read odds ratios from')

parser$add_argument('--site-order-input', required = TRUE, help = 'the text file specifying the order of site types')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--figure-width', type = 'double', required = TRUE, default = 6, help = 'the figure width')

parser$add_argument('--figure-height', type = 'double', required = TRUE, default = 6, help = 'the figure height')

args <- parser$parse_args()



message('Loading site order')

site.order <- scan(args$site_order_input, what = 'character')



message('Loading data')

df.data <- fread(args$data_input)



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

pl.odds.ratios <- ggplot(df.data, aes(x = site_b, y = site_a)) +
	geom_tile(aes(fill = log10(odds_ratio))) +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradientn(colours = weather.colours(), na.value = 'black') +
	labs(x = 'Co-occurring site', y = 'Reference site', fill = 'log10(Odds ratio)')

pl.p.values <- ggplot(df.data, aes(x = site_b, y = site_a)) +
	geom_tile(aes(fill = log10(-log10(p)))) +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradientn(colours = weather.colours(), limits = c(log10(-log10(0.0499)), NA), na.value = 'white') +
	labs(x = 'Co-occurring site', y = 'Reference site', fill = 'log10(-log10(P-value))')



message('Writing plot')

pdf(args$output, width = args$figure_width, height = args$figure_height)

print(pl.odds.ratios)

print(pl.p.values)

dev.off()
