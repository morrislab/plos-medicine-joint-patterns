# Plots Z-test results.

library(argparse)
library(xlsx)
library(dplyr)
library(grid)
library(ggplot2)
rm(list = ls())

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Excel file to read statistics from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output file to')
parser$add_argument('--width', type = 'double', help = 'the width of the figure')
parser$add_argument('--height', type = 'double', help = 'the height of the figure')
parser$add_argument('--max-fdr', type = 'double', default = 0.05, help = 'the maximum FDR to show')
parser$add_argument('--min-fdr', type = 'double', default = 1e-3, help = 'the minimum FDR to show')
parser$add_argument('--option', default = 'D', help = 'the viridis palette to use')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- read.xlsx(args$input, sheetIndex = 1)

max.power <- -log10(args$min_fdr)

X <- X %>%
	mutate(
		log_p = pmin(-log10(p_adjusted), max.power),
		log_fdr = pmin(-log10(p_adjusted), max.power)
	)



# Plot data.

message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(4.8, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold')
		)
)

ylim <- X$factor %>%
	unique %>%
	sort %>%
	rev

pl <- X %>%
	ggplot(aes(x = classification, y = factor)) +
	geom_tile(aes(fill = log_fdr)) +
	scale_x_discrete(expand = c(0, 0)) +
	scale_y_discrete(expand = c(0, 0), limits = ylim) +
	scale_fill_viridis_c(limits = c(-log10(args$max_fdr), NA), option = args$option, direction = -1, na.value = 'white', breaks = pretty) +
	coord_fixed() +
	labs(x = 'Classification', y = 'Factor', fill = '-log(FDR)')



# Write output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
