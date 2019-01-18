# Important note

The code in this package is intended to specifically run the analysis as it appears in
Eng, Aeschlimann, van Veenendaal et al., PLOS Medicine 2019. We will be releasing a
generalized version of our multilayer non-negative matrix factorization (NMF) workflow
with a subsequent paper.

# Data access

For data access, please contact [Dr. Susanne
Benseler](Susanne.Benseler@albertahealthservices.ca), chair of the Canadian Association
of Paediatric Rheumatology (CAPRI), who will forward your request to the CAPRI
Scientific Protocol Evaluation Committee/Data Access Committee.

# Installation

## Python

This analysis requires Python 3.6 or higher.

We recommend managing your Python installation using [conda](https://conda.io),
especially as we provide an `environment.yml` file for your convenience.

## R

Please install R 3.5.0+ with the following packages:

- `car`
- `ggbeeswarm`
- `lmtest`
- `moments`

## Circos

To generate the wheel figure, Circos 0.69+ is needed. The most straightforward way to do
so is to install `coreutils` through [Homebrew](https://brew.sh) and then issuing the
command

    brew install circos

## coreutils (macOS only)

On macOS, `coretools` must be installed (due to the `gln` command, required for properly
linking inputs and outputs). The most straightforward way to do so is to install
`coreutils` through [Homebrew](https://brew.sh) and then issuing the command

    brew install coreutils

# Running the analysis

To preview what rules will be run, type

    snakemake --dry-run everything

To run the analysis, type

    snakemake everything

If you wish to run the analysis on a cluster, type

    snakemake --cmd '<command>' everything

where `<command>` is the command you would use to submit a job (e.g., `qsub`).

To clean all output files, type

    snakemake --delete-all-output