# Generates a Cox proportional hazards model by adding terms sequentially in terms of
# variance explained.

library(argparse)
library(data.table)
library(feather)
library(survival)
library(plyr)
library(dplyr)
library(dtplyr)
library(magrittr)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE)
parser$add_argument('--output', required = TRUE)
parser$add_argument('--include', nargs = '+')
args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- read_feather(args$input) %>%
    setDT

dt.data <- if (!is.null(args$include)) {
	dt.data %>% select(subject_id, event_status, duration, one_of(args$include))
} else {
	dt.data %>% select(subject_id, event_status, duration)
}



# Re-level all factors so that the most represented one is the base level.

message('Re-ordering factors')

for (j in args$include) {

    if (is.factor(dt.data[[j]])) {

        tab <- table(dt.data[[j]])

        ix <- which.max(tab)

        set(dt.data, j = j, value = relevel(dt.data[[j]], names(ix)))

    }

}



# Generate the model by sequentially adding terms.

message('Generating model')

current.terms <- NULL

remaining.terms <- args$include

coxph.model <- NULL

if (is.null(args$include)) {
    
	coxph.model <- coxph(Surv(duration, event_status) ~ 1, dt.data)
    
} else {

    while (length(remaining.terms) > 0) {
        
        test.models <- remaining.terms %>%
            llply(function (term) {
                coxph(as.formula(paste0('Surv(duration, event_status) ~ ', paste(c(current.terms, term), collapse = ' + '))), dt.data)
            })
        
        # See https://stats.stackexchange.com/questions/30731/what-is-the-r2-value-given-in-the-summary-of-a-coxph-model-in-r
        
        log.tests <- test.models %>%
            llply(function (res) {
                with(res, -2 * (loglik[1] - loglik[2]))
            })
        
        rsqs <- seq(remaining.terms) %>%
            ldply(function (i) {
                data.frame(
                    rsq = 1 - exp(-log.tests[[i]] / test.models[[i]]$n),
                    maxrsq = 1 - exp(2 * test.models[[i]]$loglik[1] / test.models[[i]]$n)
                )
            }) %>%
            set_rownames(remaining.terms)
        
        print(rsqs)
        
        max.i <- which.max(rsqs$rsq)
        
        term.to.add <- remaining.terms[max.i]
        
        message('Adding term: ', term.to.add)
        
        current.terms <- c(current.terms, term.to.add)
        
        remaining.terms <- setdiff(remaining.terms, term.to.add)
        
        coxph.model <- test.models[[max.i]]
                
    }
    
}



# Write the output.

message('Writing output')

save(coxph.model, dt.data, file = args$output)
