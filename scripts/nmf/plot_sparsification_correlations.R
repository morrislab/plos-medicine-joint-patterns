# Plots correlations between unsparsified scores and sparsified scores.

library(argparse)
library(data.table)
library(grid)
library(ggplot2)
library(ks)

parser <- ArgumentParser()
parser$add_argument('--unsparsified-input', required = TRUE, help = 'the CSV file to read the unsparsified basis from')
parser$add_argument('--sparsified-input', required = TRUE, help = 'the CSV file to read the sparsified basis from')
parser$add_argument('--output', help = 'the PDF file to write output to')
parser$add_argument('--figure-width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--figure-height', type = 'double', default = 7, help = 'the figure height')
parser$add_argument('--ncol', type = 'integer', help = 'the number of columns')
parser$add_argument('--nrow', type = 'integer', help = 'the number of rows')
parser$add_argument('--colour-scale', default = FALSE, action = 'store_true', help = 'use a colour scale')
parser$add_argument('--option', default = 'D', help = 'the viridis palette')
args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.unsparsified <- fread(args$unsparsified_input, header = TRUE)

setnames(dt.unsparsified, c('patient_id', seq(ncol(dt.unsparsified) - 1)))

dt.sparsified <- fread(args$sparsified_input, header = TRUE)

setnames(dt.sparsified, c('patient_id', seq(ncol(dt.sparsified) - 1)))



message('Melting data')

dt.unsparsified.melted <- melt(dt.unsparsified, id.var = 'patient_id', variable.name = 'factor', value.name = 'score_unsparsified', variable.factor = FALSE)

dt.unsparsified.melted[, factor := as.integer(factor)]

setkey(dt.unsparsified.melted, patient_id, factor)

dt.sparsified.melted <- melt(dt.sparsified, id.var = 'patient_id', variable.name = 'factor', value.name = 'score_sparsified', variable.factor = FALSE)

dt.sparsified.melted[, factor := as.integer(factor)]

setkey(dt.unsparsified.melted, patient_id, factor)



message('Merging data')

dt.merged <- dt.unsparsified.melted[dt.sparsified.melted]



message('Calculating densities')

get.densities <- function (unsparsified_scores, sparsified_scores) {

	bw <- abs(do.call('-', as.list(range(unsparsified_scores, sparsified_scores)))) / 10

	kde.res <- kde(cbind(unsparsified_scores, sparsified_scores), eval.points = cbind(unsparsified_scores, sparsified_scores), H = diag(bw, nrow = 2, ncol = 2))

	kde.res$estimate / max(kde.res$estimate)

}

dt.merged[, density := get.densities(score_unsparsified, score_sparsified), by = .(factor)]

setorder(dt.merged, density)

dt.merged <- unique(dt.merged, by = c('factor', 'score_unsparsified', 'score_sparsified'))



message('Plotting scores')

theme_set(
	theme_classic(base_size = 8) +
	theme(
		aspect.ratio = 1,
		panel.spacing = unit(4.8, 'pt'),
		axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
		axis.ticks.length = unit(3.6, 'pt'),
		strip.text = element_text(size = rel(1), face = 'bold'),
		strip.background = element_blank(),
		legend.title = element_text(size = rel(1), face = 'bold'),
		legend.position = 'bottom'
	)
)

pl <- ggplot(dt.merged, aes(x = score_unsparsified, y = score_sparsified)) +
	facet_wrap(~ factor, ncol = args$ncol, nrow = args$nrow, scales = 'free') +
	geom_point(aes(colour = density)) +
	geom_smooth(method = 'lm', colour = 'black', se = FALSE) +
	scale_x_continuous(breaks = pretty) +
	scale_y_continuous(breaks = pretty) +
	scale_colour_viridis_c(option = args$option, direction = -1, breaks = pretty) +
	labs(x = 'Unsparsified score', y = 'Sparsified score', colour = 'Normalized density')



message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
