# Plots BICs from bootstrapped GMM analysis.

suppressPackageStartupMessages(library(argparse))

suppressPackageStartupMessages(library(plyr))

suppressPackageStartupMessages(library(reshape2))

suppressPackageStartupMessages(library(ggplot2))

suppressPackageStartupMessages(library(gtools))

suppressPackageStartupMessages(library(grid))

# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', type = 'character', required = TRUE)

parser$add_argument('--output', type = 'character', required = TRUE)

parser$add_argument('--max-k', type = 'integer')

parser$add_argument('--ignore-models', nargs = '+')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()

# Load the input file.

message('Loading inputs')

load.input <- function (filename) {

    n <- load(args$input)

    get(n)

}

bic.samples <- load.input(n)

if (!is.null(args$max_k)) {

    bic.samples <- bic.samples[, 1:args$max_k, ]

}

# Prune the samples.

if (!is.null(args$ignore_models)) {

    message('Pruning samples')

    bic.samples <- bic.samples[, , !(dimnames(bic.samples)[[3]] %in% args$ignore_models)]

}

# Calculate means BICs and confidence interval widths.

message('Calculating statistics')

mean.bics <- apply(bic.samples, c(2, 3), mean, na.rm = TRUE)

ci.widths <- apply(bic.samples, c(2, 3), function (x) {

    qt(0.975, df = length(x) - 1) * sd(x) / sqrt(length(x))

})

mean.bics.melted <- melt(mean.bics, varnames = c('k', 'model'), value.name = 'mean.bic')

ci.widths.melted <- melt(ci.widths, varnames = c('k', 'model'), value.name = 'ci.width')

merged.stats <- merge(mean.bics.melted, ci.widths.melted, by = c('k', 'model'))

# Determine which combination has the highest BIC.

max.bic <- max(mean.bics, na.rm = TRUE)

max.ind <- which(mean.bics == max.bic, arr.ind = TRUE)

max.k <- as.integer(rownames(mean.bics)[max.ind[, 'row']])

# Restrict our display to the top 25% of mean BICs.

limits.y <- c(quantile(mean.bics, p = 0.5, na.rm = TRUE), max.bic)

# Generate the plot.

message('Generating plot')

theme_set(theme_classic(base_size = 8) + theme(aspect.ratio = 0.625, axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt'), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1)), legend.key = element_blank(), legend.background = element_blank()))

pl <- ggplot(merged.stats, aes(x = k, y = mean.bic, colour = model)) + annotate('point', fill = 'black', size = rel(1.2 ^ 10), stroke = rel(1.2), x = max.k, y = max.bic, shape = 1) + geom_line() + geom_errorbar(aes(ymin = mean.bic - ci.width, ymax = mean.bic + ci.width), width = 0.5) + geom_point(shape = 21, fill = 'white') + ylim(limits.y) + labs(x = 'Number of clusters', y = 'Bayesian information criterion', colour = 'Model')

# Output the plot.

message('Writing output')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)

message('Done')
