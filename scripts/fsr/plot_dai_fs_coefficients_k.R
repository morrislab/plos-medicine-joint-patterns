# Plots out coefficient from forward sequential regression at chosen stopping
# points.

library(argparse)

library(data.table)

library(selectiveInference)

library(grid)

library(ggplot2)

library(plyr)

library(magrittr)

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




message('Obtaining stops')

dt.stops <- data.table(k = fsInf(fs.fit$result, type = 'active', alpha = args$alpha)$khat, alpha = args$alpha)



message('Constructing data')

k <- dt.stops$k

model <- fsInf(fs.fit$result, type = 'all', k = k, alpha = args$alpha)

var.indices <- model$vars

dt.plot.data <- data.table(variable = fs.fit$predictors[var.indices], coefficient = fs.fit$result$beta[var.indices, k + 1])

dt.plot.data[, variable := factor(variable)]



message('Plotting data')

theme_set(
	theme_classic(base_size = 8) +
  	theme(
  		panel.spacing = unit(9.6, 'pt'),
  		plot.title = element_text(size = rel(1), face = 'bold'),
  		axis.text = element_text(size = rel(1)),
  		axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
  		axis.line.x = element_line(),
  		axis.line.y = element_line(),
  		axis.ticks.length = unit(4.8, 'pt'),
  		strip.text = element_text(size = rel(1), face = 'bold'),
  		strip.background = element_blank()
  	)
)

pl <- ggplot(dt.plot.data, aes(x = variable, y = coefficient)) +
	geom_col(width = 0.8, fill = grey(0.8)) +
	labs(x = 'Variable', y = 'Coefficient')

if (min(dt.plot.data$coefficient) >= 0) {

	pl <- pl + scale_y_continuous(limits = c(0, NA), expand = c(0, 0), breaks = pretty)

} else {

	pl <- pl +
		geom_hline(yintercept = 0) +
		scale_y_continuous(breaks = pretty)

}



message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)



message('Done')
