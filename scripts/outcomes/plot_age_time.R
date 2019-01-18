# Plots out age of diagnosis and time to diagnosis for patients.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

library(ggbeeswarm)

library(cowplot)

rm(list = ls())



# Obtain arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--classification-input', required = TRUE)

parser$add_argument('--diagnosis-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Run the analysis.

message('Loading data')

dt.data <- setDT(read_feather(args$data_input))

dt.data[, `:=`(
    time_to_diagnosis = symptom_onset_to_diagnosis_days / 30.4368499,
    age_of_diagnosis = diagnosis_age_days / 365.242199
)]

dt.data <- dt.data[, .(subject_id, time_to_diagnosis, age_of_diagnosis)]

setkey(dt.data, subject_id)



message('Loading and mapping classifications')

dt.classifications <- fread(args$classification_input)

setkey(dt.classifications, subject_id)



message('Loading and mapping diagnoses')

dt.diagnoses <- fread(args$diagnosis_input)

dt.diagnoses <- dt.diagnoses[diagnosis != '']

diagnosis.map <- c(
    "Oligoarthritis" = 'O',
    "RF-positive polyarthritis" = 'P+',
    "RF-negative polyarthritis" = 'P-',
    "Enthesitis-related arthritis" = 'ERA',
    "Psoriatic arthritis" = 'Ps',
    "Systemic arthritis" = 'S',
    "Undifferentiated arthritis" = 'U'
    )

dt.diagnoses[, diagnosis := diagnosis.map[diagnosis]]

setkey(dt.diagnoses, subject_id)



message('Merging data')

dt.data <- dt.data[J(dt.classifications$subject_id)]

dt.merged.classifications <- dt.classifications[dt.data, nomatch = 0]

dt.merged.diagnoses <- dt.diagnoses[dt.data, nomatch = 0]



message('Melting data')

dt.melted.classifications <- melt(dt.merged.classifications[, .(subject_id, classification, time_to_diagnosis, age_of_diagnosis)], id.vars = c('subject_id', 'classification'), na.rm = TRUE)

setnames(dt.melted.classifications, 'classification', 'cls')

dt.melted.diagnoses <- melt(dt.merged.diagnoses[, .(subject_id, diagnosis, time_to_diagnosis, age_of_diagnosis)], id.vars = c('subject_id', 'diagnosis'), na.rm = TRUE)

setnames(dt.melted.diagnoses, 'diagnosis', 'cls')



message('Concatenating data')

dt.melted.classifications[, cls_type := 'Patient groups']

dt.melted.diagnoses[, cls_type := 'ILAR classifications']

dt.plot <- rbindlist(list(dt.melted.classifications, dt.melted.diagnoses))

limits.x <- c(dt.classifications[, sort(unique(classification))], diagnosis.map)

dt.plot[, `:=`(
    cls = factor(cls, levels = limits.x),
    cls_type = factor(cls_type, levels = c('Patient groups', 'ILAR classifications'))
)]

dt.plot[, cls := factor(cls, levels = c(sort(unique(dt.melted.classifications$cls)), 'S', 'O', 'P-', 'P+', 'Ps', 'ERA', 'U'))]



message('Generating box plot statistics')

dt.stats <- dt.plot[, .(
    lower = quantile(value, 0.25),
    middle = quantile(value, 0.5),
    upper = quantile(value, 0.75)
), by = .(variable, cls, cls_type)]



message('Generating plot')

theme_set(theme_classic(base_size = 8) + theme(panel.spacing = unit(9.6, 'pt'), axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt'), strip.background = element_blank(), strip.text = element_text(size = rel(1), face = 'bold')))

make.plot <- function (v, ylab, trans) {

    breaks <- pretty

    if (trans == 'log1p') {

        breaks <- function (limits.x) {

        	pow.range <- 0:ceiling(log10(limits.x[2]))

        	ticks <- do.call(c, lapply(c(1, 2, 5), function (x) x * 10 ^ pow.range))

        	ticks <- c(0, ticks)

        	ticks[ticks > limits.x[1] & ticks < limits.x[2]]

        }

    }

    dt.plot.this <- dt.plot[variable == v]

    dt.stats.this <- dt.stats[variable == v]

    set.seed(84375636)

    ggplot(dt.plot.this, aes(x = cls)) + facet_grid(~ cls_type, drop = TRUE, scales = 'free_x', space = 'free_x') + geom_violin(aes(y = value), fill = grey(0.8), colour = NA, scale = 'width') + geom_quasirandom(aes(y = value), colour = grey(0.6), size = 1 / 2) + geom_pointrange(aes(ymin = lower, ymax = upper, y = middle), dt.stats.this, shape = 23, size = 1 / 2, fill = 'white') + labs(x = 'Patient group / ILAR subtype', y = ylab) + scale_y_continuous(trans = trans, breaks = breaks)

}

pl.age <- make.plot('age_of_diagnosis', 'Age of diagnosis (years)', 'identity')

pl.time <- make.plot('time_to_diagnosis', 'Time to diagnosis (months)', 'log1p')



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(pl.age, pl.time, ncol = 1, align = 'hv')



# Write the output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)



message('Done')
