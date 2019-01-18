# Plots distributions of -log10 P-value ratios.

library(argparse)

library(data.table)

library(stringr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to read log ratios from')

parser$add_argument('--output', required = TRUE, help = 'the text file to write output to')

args <- parser$parse_args()



message('Loading -log10 P-value ratios')

df.data <- fread(args$input)

df.data[, reference_side := str_extract(reference, '(left|right)$')]



message('Conducting tests')

wilcox.result <- wilcox.test(df.data[reference_side == 'left', ratio], df.data[reference_side == 'right', ratio])



message('Writing output')

sink(args$output)

print(wilcox.result)

sink()
