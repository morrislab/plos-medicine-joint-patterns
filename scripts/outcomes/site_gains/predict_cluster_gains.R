# Determines which patient groups predict gains in sites.

library(argparse)

library(data.table)

library(feather)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Conduct logistic regression.

message('Conducting logistic regression')

set.seed(2397434)

get.predictions <- function(classification, value) {

	value <- pmax(0, value)

	lm.null <- glm(value ~ 1, family = 'binomial')

	lm.res <- glm(value ~ classification)

	anova.res <- anova(lm.null, lm.res, test = 'Chisq')

	p.anova <- tail(anova.res$`Pr(>Chi)`, 1)

	summary.res <- summary(lm.res)

	mat.coef <- coef(summary.res)

	dt.coef <- data.table(sort(unique(classification)), mat.coef)

	setnames(dt.coef, c('classification', 'estimate', 'std_error', 'z', 'p'))

	dt.coef[, p_model := p.anova]

}

dt.results <- dt.data[, get.predictions(classification, value), keyby = .(site)]

dt.p.models <- unique(dt.results[, .(site, p_model)], by = c('site', 'p_model'))

dt.p.models[, `:=`(
	p_model_adjust = p.adjust(p_model),
	p_model = NULL
)]



dt.results <- merge(dt.results, dt.p.models, by = 'site')



# Write the output.

message('Writing output')

write.csv(dt.results, file = args$output, row.names = FALSE)
