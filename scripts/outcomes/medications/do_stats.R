# Conducts linear modelling to determine if patient groups and degree of localization predict medication status.

library(argparse)
library(feather)
library(plyr)
library(dplyr)
library(lmtest)
library(broom)
library(xlsx)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to load data from')
parser$add_argument('--output', required = TRUE, help = 'the Excel file to output statistics to')
args <- parser$parse_args()



# Load the data.

message('Loading data')
X <- read_feather(args$input)



# Conduct statistics by medication and visit.

message('Conducting statistics')

relevel.input <- function (X) {
    reference.classification <- table(X$classification) %>%
        which.max %>%
        names
    reference.localization <- table(X$localization) %>%
        which.max %>%
        names
    X %>%
        mutate(
            classification = relevel(classification, reference.classification),
            localization = relevel(localization, reference.localization)
        )
}

glm.results <- X %>%
    dlply(.(medication, visit_id), function (X) {
        
        this.medication <- X$medication %>%
            unique
        this.visit.id <- X$visit_id %>%
            unique
        
        # Relevel the factors.
        
        X <- X %>%
            relevel.input

        # Build the models.
        
        glm.partial <- . %>%
            glm(., X, family = 'binomial')
        glm.null <- glm.partial(status ~ 1)
        glm.alt <- glm.partial(status ~ classification * localization)
        
        # Conduct a log-likelihood ratio test.
        
        lrtest.res <- lrtest(glm.alt, glm.null)
        Y.summary <- lrtest.res %>%
            tail(1) %>%
            select(
                chisq = 'Chisq',
                p = 'Pr(>Chisq)'
            ) %>%
            as.data.frame
        
        # Obtain coefficients.
        
        Y.coefficients <- glm.alt %>%
            tidy %>%
            rename(
                p = 'p.value'
            )
        
        # Note reference levels.
        
        get.reference <- . %>%
            levels %>%
            '['(1)
        Y.reference.levels <- data.frame(
            classification = get.reference(X$classification),
            localization = get.reference(X$localization)
        )
        
        # Return results.
        
        list(
            summary = Y.summary,
            coefficients = Y.coefficients,
            reference.levels = Y.reference.levels
        )
        
    })



# Collect results.

message('Collecting results')

Y.summaries <- glm.results %>%
    ldply(function (x) {
        x$summary
    }) %>%
    mutate(
        p_bonferroni = p.adjust(p, method = 'bonferroni'),
        p_holm = p.adjust(p, method = 'holm'),
        p_fdr = p.adjust(p, method = 'fdr')
    )

Y.coefficients <- glm.results %>%
    ldply(function (x) {
        x$coefficients
    })

Y.reference.levels <- glm.results %>%
    ldply(function (x) {
        x$reference.levels
    })



# Write output.

message('Writing output')

Y.summaries %>%
    write.xlsx(args$output, sheetName = 'summary', row.names = FALSE)
Y.coefficients %>%
    write.xlsx(args$output, sheetName = 'coefficients', row.names = FALSE, append = TRUE)
Y.reference.levels %>%
    write.xlsx(args$output, sheetName = 'reference_levels', row.names = FALSE, append = TRUE)
