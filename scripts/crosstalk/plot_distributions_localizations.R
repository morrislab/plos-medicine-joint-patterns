# Plot distributions of scores across localizations.

library(argparse)
library(feather)
library(dplyr)
library(grid)
library(ggplot2)
library(ggforce)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to read input data from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output file to')
parser$add_argument('--width', type = 'double', help = 'the width of the figure')
parser$add_argument('--height', type = 'double', help = 'the height of the figure')
parser$add_argument('--point-size', type = 'double', default = 1, help = 'the point size')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- read_feather(args$input)



# Calculate summaries.

message('Calculating summaries')

X.summary <- X %>%
	group_by(factor, classification, localization) %>%
	summarize(
		ymin = quantile(score, 0.25, na.rm = TRUE),
		y = median(score, na.rm = TRUE),
		ymax = quantile(score, 0.75, na.rm = TRUE)
	)



# Plot data.

message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 0.625,
			panel.spacing = unit(4.8, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
			strip.text = element_text(size = rel(1), face = 'bold'),
			strip.background = element_blank()
		)
)

pl <- X %>%
	ggplot(aes(x = factor(factor), y = score)) +
	facet_grid(classification ~ localization) +
	geom_violin(scale = 'width', fill = 'grey80', colour = NA) +
	geom_pointrange(aes(ymin = ymin, y = y, ymax = ymax), X.summary, shape = 23, fill = 'white', size = args$point_size) +
	scale_y_continuous(breaks = pretty) +
	labs(x = 'Factor', y = 'Patient-normalized score')



# Write output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
