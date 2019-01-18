# Plots the number of patients in each cluster.

library(argparse)

library(plyr)

library(dplyr)

library(grid)

library(ggplot2)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the files.

message('Loading cluster assignments')

df.clusters <- read.csv(args$input)

message('Loaded a ', nrow(df.clusters), ' x ', ncol(df.clusters), ' table')

# Create the plot.

message('Creating plot')

df.counts <- ddply(df.clusters, .(classification), summarize, count = n())

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = 8), axis.ticks.length = unit(4.8, 'pt'), axis.line.x = element_line(), axis.line.y = element_line()))

(pl <- ggplot(df.counts, aes(x = factor(classification), y = count)) + geom_col(colour = NA, fill = grey(0.8), width = 0.8) + scale_y_continuous(breaks = pretty, expand = c(0, 0)) + labs(x = 'Cluster', y = 'Number of patients'))

# Write the plot.

message('Writing plot')

ggsave(args$output, width = args$figure_width, height = args$figure_height)
