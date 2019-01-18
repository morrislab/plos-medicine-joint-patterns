# Plots patient counts.

library(argparse)
library(data.table)
library(grid)
library(ggplot2)
library(dplyr)
library(tidyr)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read counts from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--width', type = 'double', default = 7)
parser$add_argument('--height', type = 'double', default = 7)
args <- parser$parse_args()



# Load the data.

message('Loading data')

X <- fread(args$input)



# Complete the data.

message('Completing data')

times <- c(0, 0.5, 1, 1.5, 2, 3, 4, 5)

X <- X %>%
    complete(visit_id, classification, fill = list(count = 0)) %>%
    mutate(
        time = times[visit_id]
    )



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
		    panel.spacing = unit(9.6, 'pt'),
			aspect.ratio = 1,
			axis.ticks.length = unit(3.6, 'pt'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			strip.text = element_text(face = 'bold', hjust = 0),
			strip.background = element_blank()
		)
)

pl <- ggplot(X, aes(x = time, y = count)) +
    facet_wrap(. ~ classification, scales = 'free_y', nrow = 1) +
    geom_line() +
    geom_point(shape = 21, fill = 'white') +
	scale_x_continuous(breaks = pretty) +
	scale_y_continuous(breaks = pretty, limits = c(0, NA)) +
	labs(x = 'Time (years)', y = 'Number of patients', fill = 'Visit')



# Write the output.

message('Writing output')

pl %>%
    ggsave(args$output, ., width = args$width, height = args$height)
