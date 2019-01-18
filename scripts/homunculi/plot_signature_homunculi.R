# Plots base colours for the homunculi for individual patterns.

library(gdata)
library(scales)
library(reshape2)
library(plyr)
library(dplyr)
library(ggplot2)
library(argparse)
library(xlsx)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to load joint data from')
parser$add_argument('--clusters', required = TRUE, help = 'the CSV file to load clusters from')
parser$add_argument('--joint-positions', required = TRUE, help = 'the Excel file to load joint positions from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--figure-width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--figure-height', type = 'double', default = 7, help = 'the figure height')
parser$add_argument('--trans', default = 'identity', help = 'the type of transformation to apply to proportions')
parser$add_argument('--min-point-size', type = 'double', default = 0.01, help = 'the minimum point size')
parser$add_argument('--max-point-size', type = 'double', default = 3, help = 'the maximum point size')
parser$add_argument('--clip', type = 'double', help = 'the highest value to clip proportions at')
parser$add_argument('--mirror', default = FALSE, action = 'store_true', help = 'mirror the homunculi')
parser$add_argument('--option', default = 'D', help = 'the viridis palette')
args <- parser$parse_args()



# Read in the classifications and data.

classifications <- read.csv(args$clusters)

joint.data <- read.csv(args$input)

colnames(joint.data)[1] <- 'patient_id'

merged.data <- merge(classifications, joint.data, by.x = 'subject_id', by.y = 'patient_id')

melted.data <- melt(merged.data, id.vars = c('subject_id', 'classification'))

summarized.data <- ddply(melted.data, .(classification, variable), summarize, proportion = mean(value))

# Read in the positions.

positions <- read.xlsx(args$joint_positions, sheetIndex = 1)

positions[, 'Joint'] <- sub('^Active\\.', '', positions[, 'Joint'])

plot.data <- merge(summarized.data, positions, by.x = 'variable', by.y = 'Joint')



# Adjust proportions if necessary so that those higher than the specified cutoff
# are displayed.

if (!is.null(args$clip)) {

    plot.data <- plot.data %>% transform(proportion = ifelse(proportion > args$clip, args$clip, proportion))

}



# Create the plots.

weather.colours.mod <- function (n = 4) {

	# Generate adjustment breakpoints.

	adjust.breakpoints <- seq(0.25, 1, length.out = n)

	# Obtain base RGB values to modify.

	get.values <- function (x) approx(1:4, x, n = n)$y

	values <- list(
		r = get.values(c(0, 1, 1, 1)),
		g = get.values(c(1, 1, 0.65, 0)),
		b = get.values(c(0, 0, 0, 0))
	)

	# Generate the scale.

	sapply(1:n, function (i) {
		adjust.i <- adjust.breakpoints[i]
		values.i <- sapply(values, '[', i)
		do.call(rgb, as.list(values.i + (1 - adjust.i) * (1 - values.i)))
	})

}

this.scale <- weather.colours.mod()

power_two_thirds_trans <- function () {

    trans_new('power_two_thirds', function (x) x ^ (2 / 3), function (x) x ^ (3 / 2))

}

scale.limits <- c(1e-6, if (!is.null(args$clip)) args$clip else NA)

theme_set(
	theme_minimal(base_size = 8) +
		theme(
			axis.title = element_blank(),
			axis.text = element_blank(),
			axis.ticks = element_blank(),
			panel.grid = element_blank(),
			legend.title = element_text(size = rel(1), face = 'bold'),
			strip.text = element_text(size = rel(1), face = 'bold'),
			strip.background = element_blank()
		)
)

pl <- ggplot(plot.data, aes(x = x, y = y, fill = proportion, size = proportion)) +
	facet_wrap(~ classification) +
	geom_point(shape = 21, colour = grey(0.95)) +
	scale_y_reverse() +
	scale_fill_viridis_c(option = args$option, direction = -1, limits = scale.limits, trans = args$trans, na.value = 'white', breaks = pretty) +
	scale_size_continuous(range = c(args$min_point_size, args$max_point_size), limits = scale.limits, guide = FALSE) +
	coord_fixed() +
	labs(fill = 'Frequency')

if (!args$mirror) {

	pl <- pl + scale_x_reverse()

}

ggsave(args$output, pl, colormode = 'cmyk', width = args$figure_width, height = args$figure_height)
