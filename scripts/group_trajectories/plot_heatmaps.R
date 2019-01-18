# Generates bubble plots between consecutive visits.

library(argparse)

library(data.table)

library(dplyr)

library(dtplyr)

library(plyr)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

parser$add_argument('--colour-scale', default = FALSE, action = 'store_true')

parser$add_argument('--reorder-axes', default = FALSE, action = 'store_true')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)

dt.data[, transition_p := pct / 100]



# Arrange the clusters on both axes based on transition probabilities.

dt.data.reformatted <- melt(dcast(dt.data, visit1 + visit2 + cls_1 ~ cls_2, value.var = 'transition_p', fill = 0), id.vars = c('visit1', 'visit2', 'cls_1'), variable.name = 'cls_2', value.name = 'p')



# Arrange the clusters using mean transition probabilities.

dt.mean.probabilities <- dt.data.reformatted[, .(mean_p = mean(p)), by = .(cls_1, cls_2)]

dt.mean.p.casted <- dcast(dt.mean.probabilities, cls_1 ~ cls_2, value.var = 'mean_p')

order.row <- if (args$reorder_axes && nrow(dt.mean.p.casted) > 1) {

	hclust.res.row <- hclust(dist(dt.mean.p.casted %>% select(-1), method = 'euclidean'), method = 'ward.D2')

	dt.mean.p.casted$source[hclust.res.row$order]

} else dt.data[, sort(unique(cls_1))]

order.col <- if (args$reorder_axes && ncol(dt.mean.p.casted) > 1) {

	hclust.res.col <- hclust(dist(t(dt.mean.p.casted %>% select(-1)), method = 'euclidean'), method = 'ward.D2')

	colnames(dt.mean.p.casted)[-1][hclust.res.col$order]

} else dt.data[, sort(unique(cls_2))]



# Generate the plot.

message('Generating plot')

make.colour <- function (r, g, b, alpha) {

	r <- r + (1 - alpha) * (1 - r)

	g <- g + (1 - alpha) * (1 - g)

	b <- b + (1 - alpha) * (1 - b)

	rgb(r, g, b)

}

alpha.breakpoints <- seq(0.25, 1, length.out = 5)

this.scale <- if (args$colour_scale) c(make.colour(0, 1, 0, alpha.breakpoints[1]), make.colour(1, 1, 0, alpha.breakpoints[2]), make.colour(1, 0.65, 0, alpha.breakpoints[3]), make.colour(1, 0, 0, alpha.breakpoints[4]), make.colour(0.625, 0.125, 0.95, alpha.breakpoints[5])) else c(grey(0.85), 'black')

theme_set(theme_classic(base_size = 8) + theme(plot.title = element_text(size = rel(1), face = 'bold', hjust = 0.5), aspect.ratio = 1, panel.spacing = unit(4.8, 'pt'), axis.text = element_text(size = rel(1)), axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1), axis.ticks.length = unit(4.8, 'pt'), strip.background = element_blank(), strip.text = element_text(size = rel(1), face = 'bold'), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1)), legend.position = 'bottom'))



# Generate individual plots.

pls.heatmaps.individual <- dlply(dt.data, .(visit1, visit2), function (df.slice) {

	ggplot(df.slice, aes(x = cls_2, y = cls_1)) + geom_tile(aes(fill = transition_p)) + scale_x_discrete(limits = order.col, expand = c(0, 0)) + scale_y_discrete(limits = rev(order.row), expand = c(0, 0)) + scale_fill_gradientn(colours = this.scale, limits = c(1e-6, 1), na.value = 'white', breaks = pretty) + labs(y = 'Source patient group', x = 'Target patient group', fill = 'Transition\nprobability', title = paste('Visit', unique(df.slice$visit1), 'to visit', unique(df.slice$visit2)))

})

pls.bubbles.individual <- dlply(dt.data, .(visit1, visit2), function (df.slice) {

	ggplot(df.slice, aes(x = cls_2, y = cls_1)) + geom_point(aes(fill = transition_p, size = count), shape = 22) + scale_x_discrete(limits = order.col) + scale_y_discrete(limits = rev(order.row)) + scale_size_continuous(breaks = pretty, trans = 'sqrt', range = c(0.1, 3)) + scale_fill_gradientn(colours = this.scale, limits = c(1e-6, 1), na.value = 'white', breaks = pretty) + labs(y = 'Source patient group', x = 'Target patient group', fill = 'Transition\nprobability', size = 'Number of\npatients', title = paste('Visit', unique(df.slice$visit1), 'to visit', unique(df.slice$visit2)))

})



# Write the plots.

message('Writing plots')

pdf(args$output, width = args$figure_width, height = args$figure_height)

l_ply(c(pls.heatmaps.individual, pls.bubbles.individual), print, .progress = 'time')

dev.off()
