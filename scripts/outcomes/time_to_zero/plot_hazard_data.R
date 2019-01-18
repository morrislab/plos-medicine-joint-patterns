# Plots log-log hazards data.

library(argparse)

library(data.table)

library(feather)

library(survival)

library(grid)

library(ggplot2)

library(plyr)

library(cowplot)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the Feather file to read data from')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write the output to')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load all data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))

surv <- dt.data[, Surv(duration, event_status)]

dt.data[, `:=`(
	subject_id = NULL,
	duration = NULL,
	event_status = NULL,
	threshold = NULL
)]



# Generate the curves.

message('Generating curves')

curves <- llply(colnames(dt.data), function (j) {

	list(variable = j, fit = survfit(surv ~ dt.data[[j]]))

})

dt.plot <- rbindlist(llply(curves, function (x) {

	strata <- do.call(c, llply(seq(x$fit$strata), function (k) {

		n <- tail(strsplit(names(x$fit$strata)[k], '=')[[1]], 1)

		rep(n, x$fit$strata[k])

	}))

	time <- x$fit$time

	S <- -log(-log(x$fit$surv))

	dt.points <- data.table(variable = x$variable, stratum = strata, time = time, surv = S)

	dt.points[time > 0 & is.finite(surv)]

}))



# Generate the plots.

message('Generating plots')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			aspect.ratio = 0.625,
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(4.8, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1)),
			plot.title = element_text(size = rel(1), face = 'bold')
		)
)

pls <- dlply(dt.plot, .(variable), function (X) {

	ggplot(X, aes(x = time, y = surv)) +
		geom_line(aes(colour = stratum)) +
		geom_point(aes(colour = stratum), shape = 21, fill = 'white') +
		scale_x_continuous(trans = 'log', breaks = pretty) +
		scale_y_continuous(breaks = pretty) +
		labs(title = paste('Variable:', unique(X$variable)), x = 'log(Time)', y = '-log(-log(Survival))', colour = 'Stratum')

})



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(plotlist = pls, ncol = 1, align = 'v')



# Write the output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)
