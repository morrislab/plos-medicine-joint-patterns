# Plots the co-occurrence matrix, given optional cluster assignments.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

library(RColorBrewer)

library(scales)



# Obtain arguments.

parser <- ArgumentParser()

parser$add_argument('--co-occurrence-input', required = TRUE)

parser$add_argument('--joint-order', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--what', default = 'raw', choices = c('raw', 'conditional', 'jaccard'))

parser$add_argument('--show-labels', default = FALSE, action = 'store_true')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--colour-scale', default = FALSE, action = 'store_true')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.co.occurrences <- setDT(read_feather(args$co_occurrence_input))

dt.co.occurrences[, classification_str := c('0', LETTERS)[classification + 1]]

joint.order <- scan(args$joint_order, what = 'character')



# Plot the data.

message('Generating plot')

make.colour <- function (r, g, b, alpha) {

	r <- r + (1 - alpha) * (1 - r)

	g <- g + (1 - alpha) * (1 - g)

	b <- b + (1 - alpha) * (1 - b)

	rgb(r, g, b)

}

alpha.breakpoints <- seq(0.25, 1, length.out = 5)

this.scale <- if (args$colour_scale) c(make.colour(0, 1, 0, alpha.breakpoints[1]), make.colour(1, 1, 0, alpha.breakpoints[2]), make.colour(1, 0.65, 0, alpha.breakpoints[3]), make.colour(1, 0, 0, alpha.breakpoints[4]), make.colour(0.625, 0.125, 0.95, alpha.breakpoints[5])) else c(grey(0.85), 'black')

theme_set(theme_classic(base_size = 8) + theme(aspect.ratio = 1, panel.spacing = unit(9.6, 'pt'), panel.border = element_rect(fill = NA), plot.title = element_text(size = rel(1), face = 'bold'), axis.line = element_blank(), axis.text = element_blank(), axis.ticks = element_blank(), strip.text = element_text(size = rel(1), face = 'bold'), strip.background = element_blank(), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1))))

aes.fill <- if (args$what == 'conditional') aes(fill = conditional_probability) else if (args$what == 'jaccard') aes(fill = jaccard) else aes(fill = probability)

lab.x <- if (args$what == 'conditional') 'Co-occurring joint, x' else 'Joint'

lab.y <- if (args$what == 'conditional') 'Reference joint, y' else 'Joint'

lab.fill <- if (args$what == 'conditional') 'P(x|y)' else if (args$what == 'jaccard') 'P(x and y)/\nP(x or y)' else 'P(xy)'

pl.counts <- ggplot(dt.co.occurrences, aes(x = co_occurring_site, y = reference_site)) + facet_wrap(~ classification) + geom_tile(aes.fill) + scale_x_discrete(limits = joint.order, expand = c(0, 0)) + scale_y_discrete(limits = rev(joint.order), expand = c(0, 0)) + scale_fill_gradientn(colours = this.scale, na.value = 'white', limits = c(1e-6, 1), breaks = pretty) + labs(x = lab.x, y = lab.y, fill = lab.fill)

if (args$show_labels) {

    pl.counts <- pl.counts + theme(axis.text = element_text(size = rel(0.8)), axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

}



# Write the outputs.

message('Writing output')

ggsave(args$output, pl.counts, width = args$figure_width, height = args$figure_height)
