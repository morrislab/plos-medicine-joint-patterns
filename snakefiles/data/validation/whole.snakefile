# Whole validation data.

rule data_validation_whole_data:
    output:
        'tables/data/validation/whole/data.csv'
    input:
        rules.data_validation_sites.output
    version:
        v('scripts/data/validation/get_whole_data.py')
    shell:
        'python scripts/data/validation/get_whole_data.py --input {input} --output {output}'



rule data_validation_whole_selected:
    output:
        'tables/data/validation/whole/selected.csv'
    input:
        rules.data_validation_whole_data.output
    version:
        v('scripts/data/select_useful_data.py')
    shell:
        'python scripts/data/select_useful_data.py --input {input} --output {output}'



# Targets.

rule data_validation_whole_tables:
    input:
        rules.data_validation_whole_data.output,
        rules.data_validation_whole_selected.output



rule data_validation_whole_figures:
    input:



rule data_validation_whole:
    input:
        rules.data_validation_whole_tables.input,
        rules.data_validation_whole_figures.input
