# Plots the probability of involvement for each site.

library(argparse)
library(data.table)
library(grid)
library(ggplot2)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to load data from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--figure-width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--figure-height', type = 'double', default = 7, help = 'the figure height')
parser$add_argument('--option', default = 'D', help = 'the viridis palette')
args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.data <- fread(args$input, header = TRUE)

setnames(dt.data, 1, 'patient_id')

dt.data[, patient_id := NULL]



message('Calculating summary statistics')

sums <- colSums(dt.data)

means <- colMeans(dt.data)

dt.summary <- data.table(site = colnames(dt.data), n = sums, probability = means)



message('Determining y-axis limits')

probabilities.boundary <- with(dt.summary, quantile(probability, 0.75) + 1.5 * IQR(probability))

dt.summary[, probability := pmin(probability, probabilities.boundary)]

limits.y <- c(0, max(dt.summary$probability))



message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(3.6, 'pt'),
			axis.text.x = element_blank(),
			axis.title.x = element_blank(),
			axis.ticks.x = element_blank(),
			legend.title = element_text(size = rel(1), face = 'bold')
		)
)

pl <- ggplot(dt.summary, aes(x = 1, y = site, fill = n)) +
	geom_tile(aes(fill = probability)) +
	geom_text(aes(label = n), size = 3) +
	scale_x_continuous(expand = c(0, 0)) +
	scale_y_discrete(expand = c(0, 0)) +
	scale_fill_viridis_c(option = args$option, breaks = pretty, limits = limits.y) +
	coord_fixed(ratio = 1 / 3) +
	labs(y = 'Site', fill = 'P(involvement)')



message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
