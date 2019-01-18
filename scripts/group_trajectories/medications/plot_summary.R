# Plots a summary of medications comparing patients who fail to achieve zero
# joints versus those who do.

library(argparse)

library(data.table)

library(dplyr)

library(dtplyr)

library(grid)

library(ggplot2)

library(cowplot)

rm(list = ls())

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

df.data <- fread(args$input)

df.data <- df.data %>% filter(!(medication %in% c('ivig', 'nsaid')))



message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			legend.position = 'top',
			strip.text = element_text(size = rel(1), face = 'bold'),
			strip.background = element_blank()
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

pl.proportions <- ggplot(df.data, aes(x = zero_joints, y = proportion)) +
	facet_grid(medication ~ baseline_classification + visit_id) +
	geom_col(aes(fill = log10(total)), width = 0.8, colour = NA) +
	scale_x_discrete(limits = c(TRUE, FALSE), labels = c('Y', 'N')) +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_gradientn(colours = weather.colours(), breaks = pretty, limits = c(0, NA)) +
	labs(x = 'Zero joint involvement', y = 'Proportion of patients followed', fill = 'log10(Number of patients)')

df.totals <- df.data %>%
	select(-medication, -count, -proportion) %>%
	unique()

pl.totals <- ggplot(df.totals, aes(x = zero_joints, y = total)) +
	facet_grid(I(1) ~ baseline_classification + visit_id) +
	geom_col(width = 0.8, fill = grey(0.8), colour = NA) +
	scale_x_discrete(limits = c(TRUE, FALSE), labels = c('Y', 'N')) +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	labs(x = 'Zero joint involvement', y = 'Number of patients')



message('Combining plots')

pl.combined <- plot_grid(pl.proportions, pl.totals, ncol = 1, rel_heights = c(4, 1), align = 'v')



message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)

