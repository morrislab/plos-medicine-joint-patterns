# Plots associations from clusters to outcome measures.

library(argparse)

library(plyr)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

library(ggbeeswarm)

library(cowplot)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--point-size', type = 'double', default = 1)

parser$add_argument('--trans', nargs = '+')

parser$add_argument('--seed', type = 'integer', default = 728840)

args <- parser$parse_args()



# Create the translation specification.

message('Creating translation specification')

trans.split <- sapply(args$trans, function (x) strsplit(x, '='))

trans.spec <- sapply(trans.split, '[', 2)

names(trans.spec) <- sapply(trans.split, '[', 1)



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Melt the data.

message('Melting data')

dt.melted <- melt(dt.data, id.vars = c('subject_id', 'classification'))



# Determine which variables are dichotomous. We want to plot these separately.

message('Determining dichotomous variables')

dt.dichotomous.indicator <- dt.melted[, .(
	is_dichotomous = length(unique(na.omit(value))) <= 2
), keyby = .(variable)]



# Split the data into continuous and dichotomous variables.

message('Separating data in continuous and dichotomous data')

dichotomous.vars <- dt.dichotomous.indicator[is_dichotomous == TRUE, variable]

dt.continuous <- dt.melted[!(variable %in% dichotomous.vars)]

dt.categorical <- dt.melted[variable %in% dichotomous.vars]



# Generate plot data.

message('Generating plot data')

dt.summary.continuous <- dt.continuous[, .(
	ymin = quantile(value, 0.25, na.rm = TRUE),
	y = median(value, na.rm = TRUE),
	ymax = quantile(value, 0.75, na.rm = TRUE)
), by = .(variable, classification)]



dt.summary.categorical <- dt.categorical[, .(
	count = .N
), by = .(variable, classification, value)]

dt.summary.categorical[, proportion := count / sum(count), by = .(variable, classification)]




# Trim data to ignore outliers.

# message('Trimming outliers from display')
#
# trim.outliers <- function (dt.slice) {
#
# 	dt.result <- dt.slice[!is.na(value)]
#
# 	iqr <- IQR(dt.result$value)
#
# 	qs <- quantile(dt.result$value, c(0.25, 0.75))
#
# 	dt.result[(value >= qs[1] - 3 * iqr) & (value <= qs[2] + 3 * iqr)]
#
# }
#
# dt.trimmed.continuous <- dt.continuous[, trim.outliers(.SD), by = .(variable)]



# Generate the plots.

message('Generating plots')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			plot.title = element_text(size = rel(1), face = 'bold', hjust = 0),
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(4.8, 'pt')
		)
)

get.log.breaks <- function (x) {

	pow.range <- c(log10(max(min(x), 1)), log10(max(x)))

	pow.range <- c(floor(pow.range[1]), ceiling(pow.range[2]))

	numbers <- do.call(c, lapply(c(1, 2, 5), function (coefficient) {
		sapply(seq(pow.range[1], pow.range[2]), function (exponent) {
			coefficient * 10 ^ exponent
		})
	}))

	result <- numbers[numbers >= min(x) & numbers <= max(x)]

	if (min(x) <= 0) {

		c(0, result)

	} else {

		result

	}

}

pls.continuous <- dlply(dt.continuous, .(variable), function (df.slice) {

	variable.name <- as.character(unique(df.slice$variable))

	dt.summary.slice <- dt.summary.continuous[variable == variable.name]

	trans <- if (variable.name %in% names(trans.spec)) trans.spec[variable.name] else 'identity'

	is.log <- grepl('^log', trans)

	ggplot(df.slice, aes(x = classification)) +
		geom_violin(aes(y = value), fill = grey(0.8), colour = NA, scale = 'width') +
		geom_quasirandom(aes(y = value), shape = 16, colour = grey(0.6), size = rel(args$point_size)) +
		geom_pointrange(aes(ymin = ymin, y = y, ymax = ymax), dt.summary.slice, shape = 23, fill = 'white') +
		scale_y_continuous(breaks = if (is.log) get.log.breaks else pretty, trans = trans) +
		labs(title = variable.name, x = 'Patient group', y = variable.name)

})

pls.categorical <- dlply(dt.summary.categorical[value == 1], .(variable), function (df.slice) {

	variable.name <- as.character(unique(df.slice$variable))

	ggplot(df.slice, aes(x = classification)) +
		geom_col(aes(y = proportion), width = 0.8, colour = NA, fill = grey(0.8)) +
		scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
		labs(title = variable.name, x = 'Patient group', y = 'Proportion')

})



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(plotlist = c(pls.continuous, pls.categorical), align = 'hv')



# Write the output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)
