# Plots out medication statuses at later time points.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(gridExtra)

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



# Calculate the number of patients followed.

message('Calculating number of patients followed')

dt.patients.followed <- dt.medications[, .(total = sum(count)), by = .(cls_type, cls, visit_id, medication)]

dt.patients.followed <- dt.patients.followed[, .(total = max(total)), keyby = .(cls_type, cls, visit_id)]



# Filter the statuses.

message('Filtering statuses')

dt.medications <- dt.medications[status == TRUE]



# Remove NSAIDs.

message('Removing NSAIDs')

dt.medications <- dt.medications[medication != 'nsaid']



# Fill missing data.

message('Filling missing combinations of factor levels')

dt.keys <- data.table(with(dt.medications, expand.grid(visit_id = unique(visit_id), medication = unique(medication), cls = unique(cls), status = unique(status))))

dt.cls.types <- unique(dt.medications[, .(cls_type, cls)])

dt.keys <- setkey(dt.keys, cls)[setkey(dt.cls.types, cls)]

dt.medications <- setkey(dt.medications, visit_id, medication, cls_type, cls, status)[setkey(dt.keys, visit_id, medication, cls_type, cls, status)]

dt.medications[is.na(count), count := 0]



# Calculate proportions.

message('Calculating proportions')

setkey(dt.medications, cls, visit_id)

dt.patients.followed.selected <- dt.patients.followed[, .(cls, visit_id, total)]

setkey(dt.patients.followed.selected, cls, visit_id)

dt.medications <- dt.medications[dt.patients.followed.selected]

dt.medications[, proportion := count / total]



# Convert patient groups and diagnoses to factors.

message('Converting classifications to factors')

factor.order <- dt.medications[, .(cls_order = {
	if (cls_type == 'diagnosis') {
		c('Systemic', 'Oligoarthritis', 'RF-negative polyarthritis', 'RF-positive polyarthritis', 'Psoriatic', 'Enthesitis-related arthritis', 'Undifferentiated')
	} else {
		sort(unique(cls))
	}
}), by = .(cls_type)]

factor.order <- factor.order$cls_order

dt.medications[, cls := factor(cls, levels = factor.order)]

dt.patients.followed[, cls := factor(cls, levels = factor.order)]



# Generate the plot.

message('Generating plots')

theme_set(theme_classic(base_size = 8) +
		  	theme(
		  		plot.title = element_text(size = rel(1), face = 'bold'),
		  		panel.spacing = unit(9.6, 'pt'),
		  		axis.text = element_text(size = rel(1)),
		  		axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
		  		axis.ticks.length = unit(4.8, 'pt'),
		  		legend.position = 'bottom',
		  		legend.title = element_text(size = rel(1), face = 'bold'),
		  		legend.text = element_text(size = rel(1)), strip.background = element_blank(),
		  		strip.text = element_text(size = rel(1), face = 'bold')
))

pl.proportions <- ggplot(dt.medications) +
	facet_grid(medication ~ cls_type, scales = 'free', space = 'free_x') +
	geom_col(aes(x = cls, y = proportion, fill = factor(visit_id)), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), limits = c(0, 1), breaks = pretty) +
	scale_fill_manual(values = c(`2` = grey(0.2), `3` = grey(0.8)), guide = 'none') +
	labs(title = 'Proportions', x = 'Patient group / ILAR classification', y = 'Proportion of patients', fill = 'Visit') +
	theme(axis.ticks.x = element_blank(), axis.text.x = element_blank(), axis.title.x = element_blank())

pl.counts <- ggplot(dt.patients.followed) +
	facet_grid(I(1) ~ cls_type, scales = 'free', space = 'free_x') +
	geom_col(aes(x = cls, y = total, fill = factor(visit_id)), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_manual(values = c(`2` = grey(0.2), `3` = grey(0.8))) +
	labs(title = 'Patient counts', x = 'Patient group / ILAR classification', y = 'Number of patients with medication information', fill = 'Visit') +
	theme(strip.text = element_blank())



# Write the plot.

message('Writing plot')

pdf(args$output, width = args$figure_width, height = args$figure_height)

grob.proportions <- ggplotGrob(pl.proportions)

grob.counts <- ggplotGrob(pl.counts)

grid.draw(rbind(grob.proportions, grob.counts))

dev.off()
