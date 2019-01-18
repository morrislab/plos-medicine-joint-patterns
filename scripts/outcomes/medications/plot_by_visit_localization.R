# Plots an alternate view of medication involvement, with cluster on the x-axis,
# localization as colours, and visit number as columns.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(stringr)

library(tidyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to read medication frequencies from')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to output the figure to')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)

dt.data <- dt.data[cls_type == 'classification' & status == TRUE]

dt.data[, `:=`(
	cluster = sub('_(limited|undifferentiated)$', '', cls),
	localization = str_to_title(sub('^[A-Z]_', '', cls))
)]

dt.data <- complete(dt.data, visit_id, medication, cluster, localization, fill = list(proportion = 0))



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 0.625,
			panel.spacing = unit(9.6, 'pt'),
			axis.text = element_text(size = 8),
			axis.ticks.length = unit(4.8, 'pt'),
			strip.text = element_text(size = 8, face = 'bold'),
			strip.background = element_blank(),
			legend.title = element_text(size = 8, face = 'bold'),
			legend.text = element_text(size = 8),
			legend.position = 'bottom'
		)
)

pl <- ggplot(dt.data, aes(x = cluster, y = proportion, fill = localization)) +
	facet_grid(medication ~ visit_id) +
	geom_col(width = 0.8, position = 'dodge') +
	scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
	scale_fill_manual(values = sapply(c(0.7, 0.3), grey)) +
	labs(x = 'Patient group', y = 'Frequency', fill = 'Localization')



# Write the output.

message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
