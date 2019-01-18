# Plots odds ratios for co-involvements.

library(argparse)

library(data.table)

library(stringr)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--log-ratio-input', required = TRUE, help = 'the CSV file to read log ratios from')

parser$add_argument('--site-order-input', required = TRUE, help = 'the text file specifying the order of site types')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')

parser$add_argument('--clip-percentile' , type = 'double', default = 0, help = 'the minimum percentile of absolute ratios to show')

parser$add_argument('--figure-width', type = 'double', required = TRUE, default = 6, help = 'the figure width')

parser$add_argument('--figure-height', type = 'double', required = TRUE, default = 6, help = 'the figure height')

args <- parser$parse_args()



message('Loading site order')

site.order <- scan(args$site_order_input, what = 'character')



message('Loading data')

df.data <- fread(args$log_ratio_input)

df.data[, reference_side := str_extract(reference, '(left|right)$')]

df.data[, reference_type := sub('_(left|right)$', '', reference)]



message('Clipping data')

abs.ratios <- df.data[, abs(ratio)]

min.abs.ratio <- quantile(abs.ratios, args$clip_percentile / 100)

message(paste('Minimum absolute ratio:', min.abs.ratio))

df.data[abs.ratios < min.abs.ratio, ratio := 0]



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

pl.nonmatching <- ggplot(df.data[co_occurring_type != reference_type], aes(x = co_occurring_type, y = reference_type)) +
	facet_grid(. ~ reference_side, labeller = label_both) +
	geom_tile(aes(fill = ratio)) +
	scale_x_discrete(limits = site.order, expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red') +
	labs(x = 'Co-occurring site', y = 'Reference site', fill = '-log10(P[same | same] / P[opposite | same])')

pl.matching <- ggplot(df.data[co_occurring_type == reference_type], aes(x = 1, y = reference_type)) +
	facet_grid(. ~ reference_side, labeller = label_both) +
	geom_tile(aes(fill = ratio)) +
	scale_x_discrete(expand = c(0, 0)) +
	scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
	scale_fill_gradient2(low = 'blue', high = 'red') +
	labs(x = '', y = 'Site', fill = '-log10(P[same | same] / P[opposite | same])') +
	coord_fixed() +
	theme(aspect.ratio = NULL)



message('Writing plot')

pdf(args$output, width = args$figure_width, height = args$figure_height)

print(pl.nonmatching)

print(pl.matching)

dev.off()
