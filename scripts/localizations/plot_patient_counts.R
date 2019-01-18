# Plots patient counts for localizations.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

library(tidyr)

library(cowplot)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to read patient count data from')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- fread(args$input)

df.data <- data.table(df.data %>% complete(classification, localization, fill = list(count = 0)))



# Also calculate proportions.

message('Calculating proportions')

df.data[, proportion := count / sum(count), by = .(classification)]



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 0.625,
			panel.spacing = unit(9.6, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			strip.text = element_text(size = rel(1), face = 'bold', hjust = 0),
			strip.background = element_blank()
		)
)

fill.cols <- sapply(seq(0.2, 0.8, length.out = length(unique(df.data$localization))), grey)

pl.counts <- ggplot(df.data, aes(x = classification)) +
	geom_col(aes(y = count, fill = localization), position = 'dodge', width = 2 / 3) +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_manual(values = fill.cols) +
	labs(x = 'Patient group', y = '# of patients', fill = 'Localization')

pl.proportions <- ggplot(df.data, aes(x = classification)) +
	geom_col(aes(y = proportion * 100, fill = localization), position = 'dodge', width = 2 / 3) +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_manual(values = fill.cols) +
	labs(x = 'Patient group', y = '% of patient group', fill = 'Localization')

pl.merged <- plot_grid(pl.counts, pl.proportions, ncol = 1, align = 'v')



# Write the output.

message('Writing output')

ggsave(args$output, pl.merged, width = args$figure_width, height = args$figure_height)
