# Plots out outcome measures for individual visits.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(plyr)

library(cowplot)

# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()

# Load the data.

dt.data <- fread(args$input)

dt.data[, subject_id := as.character(subject_id)]

setkey(dt.data, subject_id)

dt.clusters <- fread(args$cluster_input)

dt.clusters[, `:=`(
    patient_id = as.character(patient_id),
    classification = LETTERS[classification]
    )]

setkey(dt.clusters, patient_id)

dt.merged <- dt.data[dt.clusters]

# Melt the data.

dt.melted <- melt(dt.merged, id.vars = c('subject_id', 'visit_number', 'classification'), variable.name = 'measurement', value.name = 'value', na.rm = TRUE)

dt.stats <- dt.melted[, .(
    ymin = quantile(value, 0.025),
    lower = quantile(value, 0.25),
    middle = median(value),
    upper = quantile(value, 0.75),
    ymax = quantile(value, 0.975)
), keyby = .(classification, measurement, visit_number)]

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.line.x = element_line(), axis.line.y = element_line(), axis.ticks.length = unit(4.8, 'pt'), strip.background = element_blank(), strip.text = element_text(size = rel(1), face = 'bold')))

# Define some transforms.

y.trans <- c(
    num_active_joints = 'log1p',
    num_lrom_joints = 'log1p',
    esr = 'log1p',
    chaq_correct_score = 'log1p',
    pain_vas = 'log1p',
    pgada = 'log1p'
)

y.labels <- c(
    num_active_joints = '# of active joints',
    num_lrom_joints = '# of joints with LROM',
    esr = 'ESR',
    chaq_correct_score = 'CHAQ score',
    pain_vas = 'Pain VAS',
    pgada = 'PGADA'
)

y.limits <- list(
    num_active_joints = c(0, NA),
    num_lrom_joints = c(0, NA),
    esr = c(NA, NA),
    chaq_correct_score = c(0, 3),
    pain_vas = c(0, 10),
    pgada = c(0, 10)
)

# Plot things.

message('Generating plots')

labeller.visit <- labeller(visit_number = function (vec) {

    paste((as.integer(vec) - 1) * 6, 'months')

})

pls <- dlply(dt.melted, .(measurement), function (df.slice) {

    m <- unique(df.slice$measurement)

    dt.slice.stats <- dt.stats[measurement == m]

    ggplot(df.slice, aes(x = classification)) + facet_grid(. ~ visit_number, scale = 'free_y', labeller = labeller.visit) + geom_violin(aes(y = value), colour = NA, fill = grey(0.8), scale = 'width') + geom_boxplot(aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax, width = 0.2), dt.slice.stats, stat = 'identity') + scale_y_continuous(trans = y.trans[m], limits = y.limits[[m]], breaks = pretty) + labs(x = 'Cluster', y = y.labels[m])

}, .progress = 'time')

message('Combining plots')

pl.combined <- plot_grid(plotlist = pls, ncol = 1, align = 'v')

# Write the plots.

message('Writing plots')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)

message('Done')
