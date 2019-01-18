# Plot distributions of scores.

library(argparse)
library(feather)
library(dplyr)
library(grid)
library(ggplot2)
rm(list = ls())

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to read input data from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output file to')
parser$add_argument('--width', type = 'double', help = 'the width of the figure')
parser$add_argument('--height', type = 'double', help = 'the height of the figure')
parser$add_argument('--aspect-ratio', type = 'double', default = 0.625, help = 'the aspect ratio for each subpanel')
parser$add_argument('--point-size', type = 'double', default = 1, help = 'the point size')
parser$add_argument('--ncol', type = 'integer', default = 3, help = 'the number of columns to display')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- read_feather(args$input)



# Calculate summaries.

message('Calculating summaries')

X.summary <- X %>%
	group_by(factor, classification) %>%
	summarize(
		ymin = quantile(z_score, 0.25),
		y = median(z_score),
		ymax = quantile(z_score, 0.75)
	)



# Plot data.

message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = args$aspect_ratio,
			panel.spacing = unit(4.8, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
			strip.text = element_text(size = rel(1), face = 'bold'),
			strip.background = element_blank()
		)
)

pl <- X %>%
	ggplot(aes(x = factor(factor), y = z_score)) +
	facet_wrap(~ classification, ncol = args$ncol, scales = 'free') +
	geom_violin(scale = 'width', fill = 'grey80', colour = NA) +
	geom_pointrange(aes(ymin = ymin, y = y, ymax = ymax), X.summary, shape = 23, fill = 'white', size = args$point_size) +
	scale_y_continuous(breaks = pretty) +
	labs(x = 'Factor', y = 'Patient-normalized Z-score')



# Write output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
