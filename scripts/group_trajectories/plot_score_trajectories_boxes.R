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



message('Plotting data')

theme_set(theme_classic(base_size = 8) + theme(aspect.ratio = 1, axis.text = element_text(size = rel(1)), axis.text.x = element_text(angle = 60, hjust = 1, vjust = 1), axis.ticks.length = unit(4.8, 'pt'), axis.line.x = element_line(), axis.line.y = element_line(), strip.text = element_text(size = rel(1), face = 'bold'), strip.background = element_blank(), legend.position = 'bottom', legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1))))

labeller.this <- labeller(
    classification = function (vec) {

        paste0('[', vec, ']')

    }
)

pl.boxes <- ggplot(dt.summary, aes(x = visit_number)) + facet_grid(classification ~ factor, switch = 'y', labeller = labeller.this, scales = 'free_y') + geom_boxplot(aes(ymin = lower, lower = lower, middle = middle, upper = upper, ymax = upper), stat = 'identity') + labs(x = 'Visit number', y = 'Factor score', colour = 'Factor') + scale_x_continuous(breaks = dt.summary[, sort(unique(visit_number))], labels = c('0', '6 m', '1 y', '18 m', '2 y')) + scale_y_continuous(breaks = pretty, trans = 'log1p')



message('Writing output')

ggsave(args$output, pl.boxes, width = args$figure_width, height = args$figure_height)



message('Done')
