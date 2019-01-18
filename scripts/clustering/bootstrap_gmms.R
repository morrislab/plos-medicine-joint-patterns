# Conducts bootstrapped Gaussian mixture modelling.

suppressPackageStartupMessages(library(argparse))

suppressPackageStartupMessages(library(mclust))

suppressPackageStartupMessages(library(data.table))

suppressPackageStartupMessages(library(plyr))

suppressPackageStartupMessages(library(doMC))



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', type = 'character', required = TRUE)

parser$add_argument('--output', type = 'character', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 930420393)

parser$add_argument('--iterations', type = 'integer', default = 25)

parser$add_argument('--processes', type = 'integer')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dat <- data.matrix(data.frame(fread(args$input, header = TRUE, data.table = FALSE), row.names = 1))



# Fill in missing values with column means.

for (j in 1:ncol(dat)) {

    dat[is.na(dat[, j]), j] <- mean(dat[, j], na.rm = TRUE)

}

# Generate seeds.

message('Generating seeds')

set.seed(args$seed)

seeds <- sample.int(.Machine$integer.max, args$iterations)

message('Generating samples')

is.parallel <- if (!is.null(args$processes)) (args$processes > 1) else FALSE

if (is.parallel) {

    registerDoMC(args$processes)

}

n.samples <- nrow(dat)

sample.indices <- 1:n.samples

g.to.test <- 1:ceiling(sqrt(nrow(dat)))

bic.samples <- aaply(1:args$iterations, 1, function (i) {

    set.seed(seeds[i])

    # Generate bootstrap indices.

    bootstrap.indices <- sample(sample.indices, n.samples, replace = TRUE)

    # Regenerate the data.

    bootstrap.data <- dat[bootstrap.indices, ]

    for (j in 1:ncol(bootstrap.data)) {

        bootstrap.data[is.na(bootstrap.data[, j]), j] <- mean(bootstrap.data[, j], na.rm = TRUE)

    }

    # Run Gaussian mixture model clustering.

    result <- Mclust(bootstrap.data, G = g.to.test, prior = priorControl(shrinkage = 0))

    if (is.parallel) {

        cat('DONE ', i, '\n', sep = '')

    }

    result$BIC

}, .progress = if (is.parallel) 'none' else 'time', .parallel = is.parallel)



# Save the samples.

save(bic.samples, file = args$output)
