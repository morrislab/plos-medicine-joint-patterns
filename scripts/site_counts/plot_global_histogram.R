# Plots a histogram of joint counts.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(cowplot)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input, header = TRUE)



# Plot the data.

message('Plotting data')

theme_set(
    theme_classic(base_size = 8) +
        theme(
            aspect.ratio = 0.625,
            axis.text = element_text(size = rel(1)),
            axis.ticks.length = unit(4.8, 'pt')
        )
)

pl.hist <- ggplot(dt.data, aes(x = count)) +
    geom_histogram(bins = 20, fill = grey(0.8)) +
    scale_x_continuous(breaks = pretty, expand = c(0, 0)) +
    scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
    labs(x = 'Site count', y = 'Number of patients')

pl.ecdf <- ggplot(dt.data, aes(x = count)) +
    stat_ecdf() +
    scale_x_continuous(breaks = pretty) +
    scale_y_continuous(breaks = pretty) +
    labs(x = 'Site count', y = 'f(x)')



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(pl.hist, pl.ecdf, ncol = 1, align = 'v')



# Write the output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)
