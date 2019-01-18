# Plots frequencies.

library(argparse)
library(data.table)
library(grid)
library(ggplot2)
library(reshape2)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read frequencies from')
parser$add_argument('--output', required = TRUE, help = 'the CSV file to write output to')
parser$add_argument('--width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--height', type = 'double', default = 7, help = 'the figure height')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- fread(args$input)



# Generate the plot.

message('Generating plot')

theme_set(
    theme_classic(base_size = 8) +
    theme(
        aspect.ratio = 1 / 1.618,
        axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
        axis.ticks.length = unit(3.6, 'pt'),
        legend.title = element_text(size = rel(1), face = 'bold'),
        strip.background = element_blank(),
        strip.text = element_text(size = rel(1), face = 'bold')
    )
)

pl <- ggplot(X, aes(x = diagnosis, y = frequency)) +
    geom_col(aes(fill = criteria), position = 'dodge', colour = NA, width = 0.8) +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    labs(x = 'Category', y = '% of patients under given criteria', fill = 'Criteria')



# Write output.

message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)
