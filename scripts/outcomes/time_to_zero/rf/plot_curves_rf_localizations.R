# Plots hazard curves from the Cox regression, split by RF status and with overlapping
# localizations.

library(argparse)
library(data.table)
library(feather)
library(grid)
library(ggplot2)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to read curve data')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--width', type = 'double', default = 7)
parser$add_argument('--height', type = 'double', default = 7)
args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- setDT(read_feather(args$input))

setorder(df.data, time)



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 1,
			panel.spacing = unit(9.6, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1))
		)
)

pl <- ggplot(df.data, aes(x = time)) +
    facet_wrap(~ rf) +
	geom_line(aes(y = survival, colour = localization)) +
	scale_x_continuous(breaks = pretty(sort(unique(df.data$time)))) +
	scale_y_continuous(breaks = pretty, limits = c(0, 1)) +
	scale_colour_brewer(palette = 'Set1') +
	labs(x = 'Time (months)', y = 'P(non-zero involvement)', colour = 'Localization') +
	theme(aspect.ratio = 1, legend.position = 'bottom')



# Write the output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
