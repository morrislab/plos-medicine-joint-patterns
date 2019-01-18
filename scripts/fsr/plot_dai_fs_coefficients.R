# Plots out coefficient traces from forward sequential regression.

library(argparse)

library(data.table)

library(selectiveInference)

library(grid)

library(ggplot2)

library(ggrepel)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--alpha', type = 'double', default = 0.1)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

load(args$input)



message('Preparing data')

dt.plot.data <- {

    dt.coefficients <- data.table(variable = fs.fit$predictors, fs.fit$result$beta)

    dt.result <- melt(dt.coefficients, id.var = c('variable'), variable.name = 'iteration', value.name = 'coefficient', variable.factor = FALSE)

    dt.result[, iteration := as.integer(iteration)]

}

get.variable.order <- function (dt.plot.data) {

    dt.first.appearances <- dt.plot.data[coefficient != 0, .(
        iteration = min(iteration)
    ), by = .(variable)]

    dt.first.appearances$variable

}

dt.variable.order <- dt.plot.data[, .(variable = get.variable.order(.SD))]



message('Obtaining stops')

dt.stops <- data.frame(k = fsInf(fs.fit$result, type = 'active')$khat, alpha = args$alpha)



message('Plotting data')

theme_set(theme_classic(base_size = 8) + theme(plot.title = element_text(size = rel(1), face = 'bold'), axis.text = element_text(size = rel(1)), axis.line.x = element_line(), axis.line.y = element_line(), axis.ticks.length = unit(4.8, 'pt')))



dt.annotations <- dt.plot.data[coefficient != 0]

dt.annotations <- dt.annotations[!duplicated(dt.annotations$variable)]

variable.order <- dt.variable.order$variable

k.stop <- dt.stops$k

pl <- ggplot(dt.plot.data, aes(x = iteration - 1, y = coefficient)) +
	geom_vline(xintercept = k.stop, linetype = 'dotted') +
	geom_line(aes(colour = variable)) +
	geom_point(data = dt.annotations, shape = 21, fill = 'white') +
	geom_text_repel(aes(label = variable), dt.annotations, size = 3) +
	labs(x = 'Number of variables', y = 'Coefficient') +
	scale_x_continuous(breaks = pretty, limits = c(0, dt.plot.data[, max(iteration)] * 1.1)) +
	scale_y_continuous(breaks = pretty) +
	scale_colour_grey(guide = FALSE, limits = variable.order, start = 0, end = 0.9, na.value = 'transparent')



message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
