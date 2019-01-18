# Plots patient counts for localizations by threshold.

library(argparse)
library(data.table)
library(grid)
library(ggplot2)
library(dplyr)
library(dtplyr)
library(tidyr)
library(cowplot)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read counts from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--height', type = 'double', default = 7, help = 'the figure height')
args <- parser$parse_args()



# Load the data.

message('Loading data')

X <- fread(args$input)

X <- X %>%
    complete(classification, localization, fill = list(
        count = 0
    ))

X.total <- X %>%
    group_by(localization) %>%
    summarize(
        count = sum(count)
    )



# Generate the plots.

message('Generating plots')

theme_set(
    theme_classic(base_size = 8) +
        theme(
            axis.ticks.length = unit(3.6, 'pt'),
            legend.title = element_text(face = 'bold')
        )
)

pl.total <- X.total %>%
    ggplot(aes(x = localization, y = count)) +
    geom_col(width = 0.8, fill = 'grey80') +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    labs(x = 'Localization', y = 'Number of patients') +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1)
    )

pl.individual <- X %>%
    ggplot(aes(x = classification, y = count, fill = localization)) +
    geom_col(position = 'dodge', width = 0.8) +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    scale_fill_brewer(palette = 'Set1') +
    labs(x = 'Classification', y = 'Number of patients', fill = 'Localization')



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(pl.total, pl.individual, nrow = 1, align = 'h', rel_widths = c(1, 3))



# Write the plots.

message('Writing output')

pl.combined %>%
    ggsave(args$output, ., width = args$width, height = args$height)
