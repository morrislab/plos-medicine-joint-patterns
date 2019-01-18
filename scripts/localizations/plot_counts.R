# Plots patient counts for localizations by threshold.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--ncol', type = 'integer')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)

dt.data[, proportion := count / sum(count), by = .(classification, threshold)]



# Summarize data for all patients.

message('Summarizing data')

dt.summary <- dt.data[, .(count = sum(count)), by = .(localization, threshold)]

dt.summary[, proportion := count / sum(count), by = .(threshold)]



# Generate the plot.

theme_set(
    theme_classic(base_size = 8) +
        theme(
            aspect.ratio = 0.625,
            plot.title = element_text(size = rel(1), face = 'bold'),
            panel.spacing = unit(9.6, 'pt'),
            axis.text = element_text(size = rel(1)),
            axis.ticks.length = unit(4.8, 'pt'),
            strip.background = element_blank(),
            strip.text = element_text(size = rel(1), face = 'bold')
        )
)

pl.summary <- ggplot(dt.summary[localization == 'limited'], aes(x = threshold, y = proportion)) +
    geom_line() +
    geom_point(shape = 21, fill = 'white') +
    scale_x_continuous(breaks = pretty) +
    scale_y_continuous(breaks = pretty, limits = c(0, NA)) +
    labs(title = 'Overall', x = 'Threshold', y = 'Proportion of patients')

pl.clusters <- ggplot(dt.data[localization == 'limited'], aes(x = threshold, y = proportion)) +
    facet_wrap(~ classification, ncol = args$ncol) +
    geom_line() +
    geom_point(shape = 21, fill = 'white') +
    scale_x_continuous(breaks = function (x) pretty(x, n = 4)) +
    scale_y_continuous(breaks = function (x) pretty(x, n = 3), limits = c(0, NA)) +
    labs(title = 'By patient group', x = 'Threshold', y = 'Proportion of patients')



# Write the plots.

message('Writing output')

pdf(args$output, width = args$figure_width, height = args$figure_height)

print(pl.summary)

print(pl.clusters)

dev.off()
