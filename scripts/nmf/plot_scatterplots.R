# Plots scatterplots of patient factor scores.

library(argparse)

library(data.table)

library(ks)

library(grid)

library(ggplot2)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--width', type = 'double', default = 7)

parser$add_argument('--height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.scores <- fread(args$input, header = TRUE)



message('Rescaling data')

for (j in 2:ncol(dt.scores)) {

	set(dt.scores, j = j, value = dt.scores[[j]] / max(dt.scores[[j]]))

}



message('Generating data')

factor.pairs <- combn(tail(colnames(dt.scores), -1), 2, simplify = FALSE)

dt.scores.melted <- melt(dt.scores, id.vars = 'subject_id', variable.name = 'factor')

get.densities <- function (x, y) {

	bw.x <- abs(do.call('-', as.list(range(x)))) / 10
	bw.y <- abs(do.call('-', as.list(range(y)))) / 10
	H <- diag(c(bw.x, bw.y), nrow = 2, ncol = 2)

	kde.res <- kde(cbind(x, y), eval.points = cbind(x, y), H = H)
	kde.res$estimate / max(kde.res$estimate)

}

dt.plot.data <- rbindlist(llply(factor.pairs, function (pair) {

	data.table(factor1 = pair[1], score1 = dt.scores[[pair[1]]], factor2 = pair[2], score2 = dt.scores[[pair[[2]]]])

}))



message('Generating densities')

dt.plot.data[, density := get.densities(score1, score2), by = .(factor1, factor2)]

# Ensure that higher densities are plotted last (i.e., on top of everything else).

setorder(dt.plot.data, density)

# Drop duplicate x and y values -- plotting them is pointless.

dt.plot.data <- unique(dt.plot.data, by = c('factor1', 'score1', 'factor2', 'score2'))



message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			aspect.ratio = 1,
			panel.spacing = unit(9.6, 'pt'),
			axis.ticks.length = unit(3.6, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold'),
			legend.title = element_text(size = rel(1), face = 'bold')
		)
)

pl <- ggplot(dt.plot.data, aes(x = score2 * 100, y = score1 * 100)) +
	facet_grid(factor1 ~ factor2, scales = 'free') +
	geom_point(aes(colour = density), shape = 16) +
	scale_x_continuous(breaks = c(0, 50, 100)) +
	scale_y_continuous(breaks = c(0, 50, 100)) +
	scale_colour_gradientn(colours = sapply(seq(1, 0, length.out = 10), grey), limits = c(0, 1), breaks = pretty) +
	labs(x = '% of maximum score on factor b', y = '% of maximum score on factor a', colour = 'Normalized\ndensity')



# Write the output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
