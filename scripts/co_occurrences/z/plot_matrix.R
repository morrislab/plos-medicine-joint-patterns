# Plots Z-scores.

library(argparse)
library(data.table)
library(feather)
library(grid)
library(ggplot2)
library(dplyr)
library(dtplyr)
rm(list = ls())

parser <- ArgumentParser()
parser$add_argument('--data-input', required = TRUE, help = 'the Feather file to read data from')
parser$add_argument('--statistics-input', required = TRUE, help = 'the CSV file to read statistics from')
parser$add_argument('--site-order-input', help = 'the text file to read the site order from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--width', type = 'double', default = 7, help = 'the width of the figure')
parser$add_argument('--height', type = 'double', default = 7, help = 'the height of the figure')
parser$add_argument('--percentile-threshold', type = 'double', default = 0.9995, help = 'the (1 - percentile) to use to clip Z-values')
parser$add_argument('--z-score-threshold', type = 'double', default = 1, help = 'the absolute Z-score under which values are zeroed')
args <- parser$parse_args()



# Load the data.

message('Loading data')

X <- read_feather(args$data_input)

X.stats <- fread(args$statistics_input)

site.order <- if (!is.null(args$site_order_input)) scan(args$site_order_input, what = 'character') else NULL



# Calculate which cells are significant.

message('Calculating significant cells')

X.stats <- X.stats %>%
	mutate(
		reference_type = reference_type,
		conditional_type = conditional_type,
		significant = p_fdr < 0.1
	)



# Take care of clipping the data.

message('Clipping data')

threshold <- qnorm(1 - args$percentile_threshold)

X <- X %>%
	mutate(
		z_clipped = ifelse(abs(z) > threshold, sign(z) * threshold, z)
	) %>%
	mutate(
		z_clipped = ifelse(abs(z) < args$z_score_threshold, 0, z)
	)



# Join data.

message('Joining data')

X.joined <- X %>%
	select(reference_type, conditional_type, z_clipped) %>%
	left_join(
		X.stats %>%
			select(reference_type, conditional_type, significant),
		by = c('reference_type', 'conditional_type')
	)



# Plot data.

message('Plotting data')

if (is.null(site.order)) {

	site.order <- sort(unique(df.joined$reference_root))

}

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 1,
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(3.6, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.position = 'right'
		)
)

pl <- ggplot(X.joined, aes(x = conditional_type, y = reference_type, colour = significant)) +
	geom_tile(aes(fill = z_clipped), size = rel(1)) +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red', na.value = 'white', breaks = pretty, limits = c(-threshold, threshold)) +
	scale_colour_manual(values = c('TRUE' = 'black', 'FALSE' = NA, 'NA' = NA)) +
	labs(x = 'Co-occurring site', y = 'Reference site', fill = 'Z', colour = 'Significant')



message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)

