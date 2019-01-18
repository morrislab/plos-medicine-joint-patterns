# Plots distributions of -log10 P-value ratios.

library(argparse)

library(data.table)

library(stringr)

library(grid)

library(ggplot2)

library(cowplot)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to read log ratios from')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--figure-width', type = 'double', required = TRUE, default = 6, help = 'the figure width')

parser$add_argument('--figure-height', type = 'double', required = TRUE, default = 6, help = 'the figure height')

args <- parser$parse_args()



message('Loading -log10 P-value ratios')

df.data <- fread(args$input)

df.data[, reference_type := str_match(reference, '^(.+)_(left|right)?$')[, 2]]

df.data[, reference_side := str_extract(reference, '(left|right)$')]



message('Generate the plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			aspect.ratio = 0.625,
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(4.8, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			legend.position = 'bottom',
			plot.title = element_text(size = rel(1))
		)
)

pl.matching.density <- ggplot(df.data[reference_type == co_occurring_type], aes(x = ratio)) +
	geom_density(aes(colour = reference_side)) +
	scale_x_continuous(expand = c(0, 0)) +
	scale_y_continuous(expand = c(0, 0)) +
	labs(title = 'Non-matching joint types', x = '-log10 P-value ratio', y = 'Density', colour = 'Side of body')

pl.nonmatching.density <- ggplot(df.data[reference_type != co_occurring_type], aes(x = ratio)) +
	geom_density(aes(colour = reference_side)) +
	scale_x_continuous(expand = c(0, 0)) +
	scale_y_continuous(expand = c(0, 0)) +
	labs(title = 'Matching joint types', x = '-log10 P-value ratio', y = 'Density', colour = 'Side of body')

pl.matching.ecdf <- ggplot(df.data[reference_type == co_occurring_type], aes(x = ratio)) +
	stat_ecdf(aes(colour = reference_side)) +
	labs(title = 'Non-matching joint types', x = '-log10 P-value ratio', y = 'f(x)', colour = 'Side of body')

pl.nonmatching.ecdf <- ggplot(df.data[reference_type != co_occurring_type], aes(x = ratio)) +
	stat_ecdf(aes(colour = reference_side)) +
	labs(title = 'Matching joint types', x = '-log10 P-value ratio', y = 'f(x)', colour = 'Side of body')



message('Writing output')

pl.combined <- plot_grid(pl.matching.density, pl.nonmatching.density, pl.matching.ecdf, pl.nonmatching.ecdf, ncol = 2, align = 'v')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)
