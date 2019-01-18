# Compares the distribution of included and excluded patients.

library(argparse)
library(data.table)
library(magrittr)
library(dplyr)
library(tidyr)
library(broom)
library(tibble)
library(xlsx)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read frequencies from')
parser$add_argument('--output', required = TRUE, help = 'the Excel file to output statistics to')
parser$add_argument('--iterations', type = 'integer', default = 2000, help = 'the number of bootstrap iterations')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- fread(args$input)

X <- X %>%
    complete(diagnosis, criteria, fill = list(frequency = 0))



# Conduct statistics.

message('Conducting statistics')

fn.counts <- function (X) {
    X$count %>%
        set_names(X$diagnosis)
}

n.included <- X %>%
    filter(criteria == 'included') %>%
    fn.counts

n.excluded <- X %>%
    filter(criteria == 'excluded') %>%
    fn.counts

chisq.res <- chisq.test(n.excluded, p = n.included, rescale.p = TRUE, simulate.p.value = TRUE, B = args$iterations)

Y.overall <- chisq.res %>%
    tidy

Y.stdres <- chisq.res$stdres %>%
    enframe



# Write output.

message('Writing output')

Y.overall %>%
    as.data.frame %>%
    write.xlsx(args$output, sheetName = 'overall', row.names = FALSE)

Y.stdres %>%
    as.data.frame %>%
    write.xlsx(args$output, sheetName = 'residuals', row.names = FALSE, append = TRUE)
