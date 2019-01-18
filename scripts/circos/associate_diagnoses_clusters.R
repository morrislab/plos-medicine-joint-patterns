# Establishes relationships between the ILAR subtypes and patient groups.

library(argparse)

library(data.table)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--diagnosis-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--chisq-output', required = TRUE)

parser$add_argument('--posthoc-output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 90823737)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.diagnoses <- fread(args$diagnosis_input)

dt.diagnoses <- dt.diagnoses[diagnosis != '']

dt.diagnoses[, `:=`(
    diagnosis = sub('^\\d+\\s+', '', diagnosis)
)]

setkey(dt.diagnoses, subject_id)

dt.clusters <- fread(args$cluster_input)

setkey(dt.clusters, subject_id)

dt.merged <- dt.diagnoses[dt.clusters, nomatch = 0]



# Conduct the analysis.

message('Running analysis')

set.seed(args$seed)

tab <- table(dt.merged[, .(diagnosis, classification)])

chisq.result <- chisq.test(tab, simulate.p.value = TRUE, B = 20000)

dt.chisq.result <- data.table(x2 = chisq.result$statistic, p = chisq.result$p.value)

dt.posthoc <- data.table(chisq.result$stdres)

dt.posthoc[, N_abs := abs(N)]

dt.posthoc[, stars := ifelse(N_abs > qnorm(0.9995), '***', ifelse(N_abs > qnorm(0.995), '**', ifelse(N_abs > qnorm(0.975), '*', '')))]



# Write the output.

message('Writing output')

write.csv(dt.chisq.result, file = args$chisq_output, row.names = FALSE)

write.csv(dt.posthoc, file = args$posthoc_output, row.names = FALSE)

message('Done')
