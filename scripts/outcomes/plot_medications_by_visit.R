# Plots out medication statuses, facetting by visit, with clusters on the x-axes
# and localizations as colours.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(gridExtra)

library(stringr)

library(dplyr)

library(dtplyr)

library(tidyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading medications')

dt.medications <- fread(args$input)



# Drop diagnoses.

message('Dropping diagonses')

dt.medications <- dt.medications[cls_type == 'classification']



# Obtain clusters and localizations.

message('Calculating clusters and localizations')

dt.medications[, `:=`(
	classification = str_extract(cls, '^[A-Z]'),
	localization = sub('_', '', str_extract(cls, '_.+$'))
)]



# Calculate the number of patients followed.

message('Calculating number of patients followed')

dt.patients.followed <- dt.medications[, .(total = sum(count)), by = .(classification, localization, visit_id, medication)]

dt.patients.followed <- dt.patients.followed[, .(total = max(total)), keyby = .(classification, localization, visit_id)]



# Filter the statuses.

message('Filtering statuses')

dt.medications <- dt.medications[status == TRUE]



# Remove NSAIDs.

message('Removing NSAIDs')

dt.medications <- dt.medications[medication != 'nsaid']



# Fill missing data.

message('Filling missing combinations of independent variables')

dt.medications <- dt.medications %>% complete(visit_id, medication, classification, localization, status, fill = list(count = 0, proportion = 0))



# Generate the plot.

message('Generating plots')

theme_set(theme_classic(base_size = 8) +
		  	theme(
		  		plot.title = element_text(size = rel(1), face = 'bold'),
		  		panel.spacing = unit(9.6, 'pt'),
		  		axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
		  		axis.ticks.length = unit(3.6, 'pt'),
		  		legend.position = 'bottom',
		  		legend.title = element_text(size = rel(1), face = 'bold'),
		  		legend.text = element_text(size = rel(1)), strip.background = element_blank(),
		  		strip.text = element_text(size = rel(1), face = 'bold')
		  	))

bar.colours <- sapply(seq(0.2, 0.8, length.out = length(unique(dt.medications$localization))), grey)

pl.proportions <- ggplot(dt.medications) +
	facet_grid(medication ~ classification, scales = 'free', space = 'free_x') +
	geom_col(aes(x = factor(visit_id), y = proportion, fill = localization), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), limits = c(0, 1), breaks = pretty) +
	scale_fill_manual(values = bar.colours, guide = 'none') +
	labs(title = 'Proportions', y = 'Proportion of patients') +
	theme(axis.ticks.x = element_blank(), axis.text.x = element_blank(), axis.title.x = element_blank())

pl.counts <- ggplot(dt.patients.followed) +
	facet_grid(I(1) ~ classification, scales = 'free', space = 'free_x') +
	geom_col(aes(x = factor(visit_id), y = total, fill = localization), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_manual(values = bar.colours) +
	labs(title = 'Patient counts', x = 'Visit number', y = 'Number of patients', fill = 'Visit') +
	theme(strip.text = element_blank())



# Write the plot.

message('Writing plot')

pdf(args$output, width = args$figure_width, height = args$figure_height)

grob.proportions <- ggplotGrob(pl.proportions)

grob.counts <- ggplotGrob(pl.counts)

grid.draw(rbind(grob.proportions, grob.counts))

dev.off()
