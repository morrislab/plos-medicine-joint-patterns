# Plots bootstrapped stats for the limited-undifferentiated analysis.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--denominator', type = 'double', required = TRUE, help = 'the denominator to divide all counts by')

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)

dt.data[, count := count / args$denominator]



# Calculate stats.

message('Calculating statistics')

dt.stats <- dt.data[, .(
    mean = mean(count),
    se = sd(count)
), by = .(threshold)]



# Generate the plot.

message('Generating plot')

theme_set(
    theme_classic(base_size = 8) +
        theme(
            aspect.ratio = 1 / 1.6,
            axis.ticks.length = unit(4.8, 'pt')
        )
    )

pl <- ggplot(dt.stats, aes(x = threshold)) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.02) +
    geom_line(aes(y = mean)) +
    geom_point(aes(y = mean), shape = 21, fill = 'white') +
    scale_x_continuous(breaks = pretty) +
    scale_y_continuous(breaks = pretty) +
    labs(x = 'Threshold', y = 'Proportion of patients with limited involvement')



# Write the plot.

message('Writing plot')

ggsave(args$output, pl, width = args$figure_width, height = args$figure_height)
