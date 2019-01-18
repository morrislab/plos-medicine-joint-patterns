# Plots out medication statuses at later time points.

library(argparse)
library(data.table)
library(dplyr)
library(dtplyr)
library(tidyr)
library(grid)
library(ggplot2)
library(cowplot)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE)
parser$add_argument('--output', required = TRUE)
parser$add_argument('--width', type = 'double', default = 7)
parser$add_argument('--height', type = 'double', default = 7)
args <- parser$parse_args()



# Load the data.

message('Loading medications')

X.medications <- fread(args$input)



# Calculate the number of patients followed.

message('Calculating number of patients followed')

df.patients.followed <- X.medications %>%
    group_by(cls_type, cls, visit_id, medication) %>%
    summarize(
        total = sum(count)
    ) %>%
    group_by(cls_type, cls, visit_id) %>%
    summarize(
        total = max(total)
    )



# Filter the statuses.

message('Filtering statuses')

X.medications <- X.medications %>%
    filter(status == TRUE)



# Remove NSAIDs.

message('Removing NSAIDs')

X.medications <- X.medications %>%
    filter(medication != 'nsaid')



# Fill missing data.

message('Filling missing combinations of factor levels')

X.medications <- X.medications %>%
    right_join(df.patients.followed %>% select(cls_type, cls)) %>%
    mutate(
        status = ifelse(!is.na(status), status, TRUE)
    ) %>%
    complete(visit_id, medication, nesting(cls_type, cls), fill = list(status = TRUE, count = 0, proportion = 0)) %>%
    filter(
        !is.na(visit_id),
        !is.na(medication)
    )



# Convert patient groups and diagnoses to factors.

message('Converting classifications to factors')

factor.order.clusters <- X.medications %>%
    filter(cls_type == 'classification') %>%
    '$'('cls') %>%
    unique %>%
    sort

factor.order.diagnoses <- c('Systemic', 'Oligoarthritis', 'RF-negative polyarthritis', 'RF-positive polyarthritis', 'Psoriatic', 'Enthesitis-related arthritis', 'Undifferentiated')

factor.order <- c(factor.order.clusters, factor.order.diagnoses)

X.medications <- X.medications %>%
    mutate(
        cls = factor(cls, levels = factor.order)
    )

df.patients.followed <- df.patients.followed %>%
    mutate(
        cls_factor = factor(cls, levels = factor.order)
    ) %>%
    select(
        -cls
    ) %>%
    rename(
        cls = 'cls_factor'
    )



# Generate the plot.

message('Generating plots')

theme_set(theme_classic(base_size = 8) +
  	theme(
  		plot.title = element_text(size = rel(1), face = 'bold'),
  		panel.spacing = unit(9.6, 'pt'),
  		axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1),
  		axis.ticks.length = unit(4.8, 'pt'),
  		legend.position = 'bottom',
  		legend.title = element_text(size = rel(1), face = 'bold'),
  		strip.background = element_blank(),
  		strip.text = element_text(size = rel(1), face = 'bold')
))

pl.proportions <- X.medications %>%
    ggplot() +
	facet_grid(medication ~ cls_type, scales = 'free', space = 'free_x') +
	geom_col(aes(x = cls, y = proportion, fill = factor(visit_id)), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), limits = c(0, 1), breaks = pretty) +
	scale_fill_manual(values = c(`2` = 'grey20', `3` = 'grey80'), guide = 'none') +
	labs(title = 'Proportions', x = 'Patient group / ILAR classification', y = 'Proportion of patients', fill = 'Visit') +
	theme(axis.ticks.x = element_blank(), axis.text.x = element_blank(), axis.title.x = element_blank())

pl.counts <- df.patients.followed %>%
    ggplot() +
	facet_grid(I(1) ~ cls_type, scales = 'free', space = 'free_x') +
	geom_col(aes(x = cls, y = total, fill = factor(visit_id)), width = 0.8, colour = NA, position = 'dodge') +
	scale_y_continuous(expand = c(0, 0), breaks = pretty) +
	scale_fill_manual(values = c(`2` = 'grey20', `3` = 'grey80')) +
	labs(title = 'Patient counts', x = 'Patient group / ILAR classification', y = 'Number of patients with medication information', fill = 'Visit') +
	theme(strip.text = element_blank())



# Combine plots.

message('Combining plots')

pl.combined <- plot_grid(pl.proportions, pl.counts, ncol = 1, rel_heights = c(3, 2))



# Write the plot.

message('Writing plot')

pl.combined %>%
    ggsave(args$output, ., width = args$width, height = args$height)
