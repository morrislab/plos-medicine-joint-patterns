# Generates a joint ordering from the given joint co-occurrence data.

library(argparse)

library(data.table)

library(feather)

# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--dist-method', default = 'euclidean')

parser$add_argument('--hclust-method', default = 'average')

args <- parser$parse_args()

# Load the data.

message('Loading data')

dt.data <- read_feather(args$input)

setDT(dt.data)

dt.data[, conditional_frequency := NULL]

# Cast the data.

message('Casting data')

dt.casted <- dcast(dt.data, conditioned_joint ~ dependent_joint, value.var = 'conditional_count')

# Cluster the data.

message('Clustering data')

hclust.res <- hclust(dist(dt.casted[, -1, with = FALSE], method = args$dist_method), method = args$hclust_method)

ordered.joints <- dt.casted[hclust.res$order, conditioned_joint]

# Output the joint order.

message('Outputting joint order')

cat(ordered.joints, sep = '\n', file = args$output)

message('Done')
