# Bobbi Berard's cohort combined with BBOP.

rule data_validation_combined_concatenated:
    output:
        'tables/data/validation/combined/data.csv'
    input:
        rules.data_validation_filtered.output,
        rules.data_validation_bbop_filtered_data.output
    version:
        v('scripts/data/combined/concatenate_data.py')
    run:
        inputs = ' '.join('--input {}'.format(x) for x in input)
        shell('python scripts/data/combined/concatenate_data.py ' + inputs + ' --output {output}')



# Targets.

rule data_validation_combined_tables:
    input:
        rules.data_validation_combined_concatenated.output



rule data_validation_combined_figures:
    input:



rule data_validation_combined:
    input:
        rules.data_validation_combined_tables.input,
        rules.data_validation_combined_figures.input
