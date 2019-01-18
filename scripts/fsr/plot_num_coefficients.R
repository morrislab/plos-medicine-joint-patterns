# Plots the number of coefficients identified by forward stepwise regression.

library(argparse)

library(data.table)

library(selectiveInference)

library(grid)

library(ggplot2)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--types', nargs = '+', default = c('active', 'all', 'aic'))

parser$add_argument('--alpha', type = 'double', nargs = '+', default = c(0.001, 0.01, 0.05, 0.1, 0.2))

args <- parser$parse_args()



# Calculate numbers of coefficients for each type of inference at set alpha
# thresholds.

message('Loading data')

load(args$input)



message('Obtaining stops')

dt.stops <- rbindlist(llply(args$types, function (type) {

	rbindlist(llply(args$alpha, function (alpha) {

		k <- fsInf(fs.fit$result, alpha = alpha, type = 'active')$khat

		data.table(type = type, alpha = alpha, k = k)

	}))

}))



message('Generating plot')

text.normal <- element_text(size = rel(1))

text.rotated <- element_text(angle = 45, hjust = 1, vjust = 1)

text.bold <- element_text(size = rel(1), face = 'bold')

theme_set(theme_classic(base_size = 8) + theme(panel.spacing = unit(9.6, 'pt'), axis.text = text.normal, axis.text.x = text.rotated, axis.ticks.length = unit(4.8, 'pt'), legend.position = 'bottom', legend.title = text.bold, legend.text = text.normal, strip.background = element_blank(), strip.text = text.bold))

pl <- ggplot(dt.stops, aes(x = log10(alpha), y = k, colour = type)) + geom_line() + geom_point(shape = 21, fill = 'white') + scale_x_continuous(breaks = pretty) + scale_y_continuous(breaks = pretty, limits = c(0, NA)) + labs(x = 'log10(Alpha)', y = 'Number of coefficients', colour = 'Criterion')



message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
