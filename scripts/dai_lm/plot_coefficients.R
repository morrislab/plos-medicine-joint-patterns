# Plots significant coefficients from linear regression.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.coefficients <- fread(args$input)



# Filter the coefficients.

message('Filtering coefficients')

dt.coefficients <- dt.coefficients[p < 0.05 & term != '(Intercept)']



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			axis.text = element_text(size = rel(1)),
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(4.8, 'pt')
		)
)

pl <- ggplot(dt.coefficients, aes(x = term, y = estimate)) +
	geom_col(colour = NA, fill = grey(0.8), width = 0.8) +
	labs(x = 'Term', y = 'Coefficient')

if (min(dt.coefficients$estimate) >= 0) {

	pl <- pl + scale_y_continuous(limits = c(0, NA), expand = c(0, 0), breaks = pretty)

} else {

	pl <- pl +
		scale_y_continuous(breaks = pretty) +
		geom_hline(yintercept = 0)

}



# Write the plot.

message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
