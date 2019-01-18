# Obtains linear model coefficients.

library(argparse)

library(data.table)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

load(args$input)



# Generate a P-value for improvement over the null model (with the intercept
# only).

message('Generating model P-value')

anova.res <- anova(lm.model.null, lm.model.res)

f.model <- tail(anova.res$F, 1)

p.model <- tail(anova.res$`Pr(>F)`, 1)



# Obtain coefficients.

message('Obtaining coefficients')

mat.coefs <- coef(summary(lm.model.res))

dt.coefs <- data.table(rownames(mat.coefs), mat.coefs, f.model, p.model)

setnames(dt.coefs, c('term', 'estimate', 'std_error', 't', 'p', 'f_model', 'p_model'))



# Write the output.

message('Writing output')

write.csv(dt.coefs, file = args$output, row.names = FALSE)
