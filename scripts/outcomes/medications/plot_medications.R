# Conducts linear modelling to determine if patient groups and degree of localization predict medication status.

library(argparse)
library(feather)
library(plyr)
library(dplyr)
library(tidyr)
library(grid)
library(ggplot2)
library(cowplot)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to load data from')
parser$add_argument('--output', required = TRUE, help = 'the Excel file to output statistics to')
parser$add_argument('--width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--height', type = 'double', default = 7, help = 'the figure height')
args <- parser$parse_args()



# Load the data.

message('Loading data')
X <- read_feather(args$input)
X <- X %>%
    mutate(
        visit_id = factor(visit_id)
    )



# Generate overall patient counts.

message('Generating overall counts')
Y.summary <- X %>%
    select(subject_id, visit_id, classification, localization) %>%
    unique %>%
    group_by(visit_id, classification, localization) %>%
    summarize(
        total = n()
    ) %>%
    ungroup %>%
    complete(visit_id, classification, localization, fill = list(total = 0))



# Count patients on medications.

message('Counting patients on medications')
Y.counts <- X %>%
    filter(status == TRUE) %>%
    group_by(visit_id, medication, classification, localization) %>%
    summarize(
        count = n()
    ) %>%
    ungroup %>%
    complete(visit_id, medication, classification, localization, fill = list(count = 0))



# Calculate proportions.

message('Calculating proportions')
Y.proportions <- Y.summary %>%
    right_join(Y.counts) %>%
    mutate(
        proportion = ifelse(total == 0, 0, count / total)
    )
    


# Generate the plot.

message('Generating plots')

theme_set(
    theme_classic(base_size = 8) +
        theme(
            aspect.ratio = 1,
            panel.spacing = unit(9.6, 'pt'),
            axis.ticks.length = unit(3.6, 'pt'),
            strip.background = element_blank(),
            strip.text = element_text(size = rel(1), face = 'bold'),
            legend.title = element_text(size = rel(1), face = 'bold'),
            legend.position = 'bottom'
        )
)

pl.summary <- Y.summary %>%
    ggplot(aes(x = visit_id, y = total, fill = localization)) +
    facet_grid(1 ~ classification) +
    geom_col(width = 0.8, position = 'dodge') +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    scale_fill_manual(values = grey(seq(0.2, 0.8, length.out = 3) %>% rev)) +
    labs(x = 'Visit ID', y = 'Number of patients', fill = 'Degree of localization')

pl.proportions <- Y.proportions %>%
    ggplot(aes(x = visit_id, y = proportion, fill = localization)) +
    facet_grid(medication ~ classification) +
    geom_col(width = 0.8, position = 'dodge') +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    scale_fill_manual(values = grey(seq(0.2, 0.8, length.out = 3) %>% rev)) +
    labs(x = 'Visit ID', y = 'Proportion of patients', fill = 'Degree of localization')


pl.combined <- plot_grid(pl.summary, pl.proportions, ncol = 1, axis = 't', align = 'v')



# Write output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$width, height = args$height)
