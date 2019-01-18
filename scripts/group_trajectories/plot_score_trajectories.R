# Plots score trajectories.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--score-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.scores <- fread(args$score_input)

dt.clusters <- fread(args$cluster_input)

dt.clusters[, classification := LETTERS[classification]]



message('Merging data')

dt.merged <- merge(dt.scores, dt.clusters, by.x = 'SubjectID', by.y = 'patient_id')



message('Summarizing data')

dt.summary <- dt.merged[, .(
    ymin = quantile(score, 0.025),
    lower = quantile(score, 0.25),
    middle = quantile(score, 0.5),
    upper = quantile(score, 0.75),
    ymax = quantile(score, 0.975)
), by = .(classification, visit_number, factor)]



message('Generating alpha values')

dt.alphas <- dt.merged[visit_number == 1][, .(
    alpha = 1 / .N,
    sqrt_alpha = sqrt(1 / .N)
), by = .(classification, factor)]

dt.merged <- merge(dt.merged, dt.alphas, by = c('classification', 'factor'))



message('Plotting data')

theme_set(theme_classic(base_size = 8) + theme(aspect.ratio = 1, axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt'), axis.line.x = element_line(), axis.line.y = element_line(), strip.text = element_text(size = rel(1), face = 'bold'), strip.background = element_blank(), legend.position = 'bottom', legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1))))

pl.lines <- ggplot(dt.merged, aes(x = visit_number)) + facet_grid(factor ~ classification, switch = 'y') + stat_summary(aes(y = score), fun.y = median, geom = 'line', colour = 'red', size = 1) + geom_line(aes(y = score, group = SubjectID, alpha = I(sqrt_alpha))) + labs(x = 'Visit number', y = 'Factor score', colour = 'Factor') + scale_x_continuous(breaks = dt.summary[, sort(unique(visit_number))]) + scale_y_continuous(breaks = pretty, trans = 'log1p')

# pl.lines <- ggplot(dt.summary, aes(x = visit_number)) + facet_grid(. ~ classification) + geom_line(aes(y = middle, colour = factor(factor)), size = 1) + labs(x = 'Visit number', y = 'Factor score', colour = 'Factor') + scale_x_continuous(breaks = dt.summary[, sort(unique(visit_number))]) + scale_y_continuous(breaks = pretty)



message('Writing output')

ggsave(args$output, pl.lines, width = args$figure_width, height = args$figure_height)



message('Done')
