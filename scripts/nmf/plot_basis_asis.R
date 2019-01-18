# Plots loadings.

library(data.table)
library(grid)
library(ggplot2)
library(reshape2)
library(plyr)
library(argparse)

parser <- ArgumentParser()
parser$add_argument('--input', type = 'character', required = TRUE, help = 'the CSV file to read the basis from')
parser$add_argument('--site-order', type = 'character', help = 'the text file to load the site order from')
parser$add_argument('--output', type = 'character', required = TRUE, help = 'the PDF file to write output to')
parser$add_argument('--colour-scale', default = FALSE, action = 'store_true', help = 'use a colour scale')
parser$add_argument('--max-scaling', default = FALSE, action = 'store_true', help = 'scale the basis on a per-factor basis')
parser$add_argument('--width', type = 'double', default = 7, help = 'the width of the figure')
parser$add_argument('--height', type = 'double', default = 9, help = 'the height of the figure')
parser$add_argument('--option', default = 'D', help = 'the viridis palette')
args <- parser$parse_args()



message('Loading data')

dt.loadings <- fread(args$input, header = TRUE)

site.order <- if (!is.null(args$site_order)) scan(args$site_order, what = 'character') else NULL



message('Melting data')

dt.melted <- melt(dt.loadings, id.var = 'variable', variable.name = 'factor', value.name = 'loading')



if (args$max_scaling) {

	message('Scaling loadings factor-wise')

	dt.melted[, loading := loading / max(loading) * 100, by = .(factor)]

}



message('Generating plot')

theme_set(
    theme_classic(base_size = 8) +
    theme(
        axis.ticks.length = unit(3.6, 'pt'),
        legend.title = element_text(size = rel(1), face = 'bold'),
    )
)

pl <- ggplot(dt.melted, aes(x = factor, y = variable)) +
    geom_tile(aes(fill = loading)) +
    labs(x = 'Factor', y = 'Variable', fill = if (args$max_scaling) '% maximum\nloading\nper factor' else 'Loading') +
    scale_x_discrete(expand = c(0, 0)) +
    scale_y_discrete(limits = rev(site.order), expand = c(0, 0)) +
    scale_fill_viridis_c(option = args$option, direction = -1, limits = c(1e-6, NA), na.value = 'white', breaks = pretty)



message('Writing output')

ggsave(args$output, pl, width = args$width, height = args$height)



message('Done')
