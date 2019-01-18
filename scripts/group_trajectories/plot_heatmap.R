# Generates square bubble plots showing transition probabilities from a
# reference visit to any future visit.

library(argparse)
library(data.table)
library(plyr)
library(dplyr)
library(dtplyr)
library(grid)
library(ggplot2)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read heat map data from')
parser$add_argument('--output', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--stats-input', help = 'the CSV file to read statistics from')
parser$add_argument('--width', type = 'double', default = 7, help = 'the figure width')
parser$add_argument('--height', type = 'double', default = 7, help = 'the figure height')
parser$add_argument('--colour-scale', default = FALSE, action = 'store_true', help = 'use a colour scale')
parser$add_argument('--option', default = 'D', help = 'the viridis palette')
parser$add_argument('--reorder-axes', default = FALSE, action = 'store_true', help = 'cluster the axes')
args <- parser$parse_args()



# Load the data.

message('Loading data')

X <- fread(args$input, colClasses = c(source = 'character', target = 'character'))

has.significance <- !is.null(args$stats_input)

if (has.significance) {

	X.stats <- fread(args$stats_input, colClasses = c(source = 'character', target = 'character'))
	
	X.stats <- X.stats %>%
	    group_by(source) %>%
	    mutate(
	        p_adjusted = p.adjust(p, method = 'holm')
	    ) %>%
	    mutate(
	        significant = p_adjusted < 0.05
	    )
	
	X <- X %>%
	    inner_join(X.stats, by = c('source', 'target'))

}



# Arrange the clusters on both axes based on transition probabilities.

message('Arranging clusters')

X.reformatted <- X %>%
    dcast(source ~ target, value.var = 'probability', fill = 0)



# Arrange the clusters using mean transition probabilities.

order.row <- if (args$reorder_axes && nrow(X.reformatted) > 1) {
    
    message('Arranging rows')
    
    hclust.res.row <- X.reformatted %>%
        select(-1) %>%
        dist(method = 'euclidean') %>%
        hclust(method = 'ward.D2')

	X.reformatted$source[hclust.res.row$order]

} else {
    
    X$source %>%
        unique %>%
        sort
    
}

order.col <- if (args$reorder_axes && ncol(X.reformatted) > 1) {
    
    message('Arranging colummns')
    
    hclust.res.col <- X.reformatted %>%
        select(-1) %>%
        t %>%
        dist(method = 'euclidean') %>%
        hclust(method = 'ward.D2')

	colnames(X.reformatted)[-1][hclust.res.col$order]

} else {
    
    X$target %>%
        unique %>%
        sort
    
}



# Generate the plot.

message('Generating plot')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			plot.title = element_text(size = rel(1), face = 'bold', hjust = 0),
			panel.spacing = unit(9.6, 'pt'),
			axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
			axis.ticks.length = unit(3.6, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.position = 'bottom')
)

limits.fill <- c(1e-6, 1)

make.colour <- function (r, g, b, alpha) {

	r <- r + (1 - alpha) * (1 - r)

	g <- g + (1 - alpha) * (1 - g)

	b <- b + (1 - alpha) * (1 - b)

	rgb(r, g, b)

}

alpha.breakpoints <- seq(0.25, 1, length.out = 5)

this.scale <- if (args$colour_scale) c(make.colour(0, 1, 0, alpha.breakpoints[1]), make.colour(1, 1, 0, alpha.breakpoints[2]), make.colour(1, 0.65, 0, alpha.breakpoints[3]), make.colour(1, 0, 0, alpha.breakpoints[4]), make.colour(0.625, 0.125, 0.95, alpha.breakpoints[5])) else c(grey(0.85), 'black')

pl <- X %>%
    filter(
        probability > 0
    ) %>%
	ggplot(aes(x = target, y = source)) +
	geom_tile(aes(fill = probability, colour = significant), size = 1) +
	scale_x_discrete(limits = rev(order.col), expand = c(0, 0)) +
	scale_y_discrete(limits = rev(order.row), expand = c(0, 0)) +
	scale_fill_gradientn(colours = this.scale, limits = c(1e-6, 1), na.value = 'white', breaks = pretty) +
	scale_colour_manual(values = c('FALSE' = NA, 'TRUE' = 'black'), guide = FALSE) +
	labs(
		y = 'Reference patient group',
		x = 'Future patient group',
		fill = 'Transition\nprobability'
	) +
	coord_fixed()



# Write the plots.

message('Writing plots')

pl %>%
    ggsave(args$output, ., width = args$width, height = args$height)
