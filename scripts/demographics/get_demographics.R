# Obtains demographics.

library(argparse)
library(data.table)
library(feather)
library(summarytools)
library(plyr)
library(dplyr)
library(dtplyr)



# Get arguments.

parser <- ArgumentParser()
parser$add_argument('--data-input', required = TRUE, help = 'the Feather file to read input data from')
parser$add_argument('--diagnosis-input', required = TRUE, help = 'the CSV file to read diagnoses from')
parser$add_argument('--joint-input', required = TRUE, help = 'the CSV file to read joint involvement data from')
parser$add_argument('--columns', required = TRUE, nargs = '+', help = 'the columns to summarize')
parser$add_argument('--output', required = TRUE, help = 'the text file to write demographics to')
args <- parser$parse_args()



# Load the files.

message('Loading data')

X <- read_feather(args$data_input)

X.diagnoses <- fread(args$diagnosis_input)

X.joints <- fread(args$joint_input)



# Calculate joint counts.

message('Getting joint counts')

ids <- X.joints$subject_id

joint.counts <- X.joints %>%
    select(-subject_id) %>%
    rowSums

joint.counts <- data.table(
    subject_id = ids,
    num_active_joints = joint.counts
)

X <- X %>%
    inner_join(joint.counts, by = 'subject_id')



# Add diagnoses.

message('Adding diagnoses')

X <- X %>%
    inner_join(X.diagnoses, by = 'subject_id')



# Select data.

message('Selecting data')

X <- X %>%
    select(
        subject_id,
        one_of(args$columns)
    )



# Generate and output the summary.

message('Generating and outputting summary')

path <- dfSummary(X) %>%
    view(method = 'browser') %>%
    file.copy(args$output, overwrite = TRUE)
