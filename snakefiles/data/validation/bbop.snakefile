# BBOP data.

from pathlib import Path

BBOP_DATA = Path('data/validation/bbop')



# Basics.

rule data_validation_bbop_basics:
    output:
        'tables/data/validation/bbop/basics.feather'
    input:
        expand(str(BBOP_DATA / '{filename}'), filename='20120703_enrolment_6mo_clinical_lab_facepain.csv')
    version:
        v('scripts/data/bbop/extract_basics.py')
    shell:
        'python scripts/data/bbop/extract_basics.py --input {input} --output {output}'



rule data_validation_bbop_medications:
    output:
        'tables/data/validation/bbop/medications.feather'
    input:
        data=expand(str(BBOP_DATA / '{filename}'), filename='20120703_enrolment_6mo_physicalactivity_anthropometric_medications_etc.csv'),
        codes=expand(str(BBOP_DATA / '{filename}'), filename='medication_codes.csv')
    version:
        v('scripts/data/bbop/extract_medications.py')
    shell:
        'python scripts/data/bbop/extract_medications.py --data-input {input.data} --code-input {input.codes} --output {output}'



rule data_validation_bbop_sites:
    output:
        'tables/data/validation/bbop/sites.feather'
    input:
        expand(str(BBOP_DATA / '{filename}'), filename='20120703_enrolment_6mo_joints.csv')
    version:
        v('scripts/data/bbop/extract_sites.py')
    shell:
        'python scripts/data/bbop/extract_sites.py --input {input} --output {output}'



# rule data_validation_bbop_medications_casted_types:
#     output:
#         'tables/data/validation/bbop/medications_casted_types.csv'
#     input:
#         rules.data_validation_bbop_medications.output
#     version:
#         v('scripts/data/bbop/cast_medication_types.py')
#     shell:
#         'python scripts/data/bbop/cast_medication_types.py --input {input} --output {output}'



rule data_validation_bbop_filter:
    output:
        'tables/data/validation/bbop/filter.csv'
    input:
        basics=rules.data_validation_bbop_basics.output,
        sites=rules.data_validation_bbop_sites.output,
        medications=rules.data_validation_bbop_medications.output
    version:
        v('scripts/data/bbop/make_filter.py')
    shell:
        'python scripts/data/bbop/make_filter.py --basics-input {input.basics} --sites-input {input.sites} --medications-input {input.medications} --output {output}'



rule data_validation_bbop_filtered_data:
    output:
        'tables/data/validation/bbop/filtered_data.feather'
    input:
        data=rules.data_validation_bbop_sites.output,
        filter=rules.data_validation_bbop_filter.output
    version:
        v('scripts/data/bbop/filter_sites.py')
    shell:
        'python scripts/data/bbop/filter_sites.py --data-input {input.data} --filter-input {input.filter} --output {output}'



# Targets.

rule data_validation_bbop_tables:
    input:
        rules.data_validation_bbop_basics.output,
        rules.data_validation_bbop_sites.output,
        rules.data_validation_bbop_medications.output,
        # rules.data_validation_bbop_medications_casted_types.output,
        rules.data_validation_bbop_filter.output,
        rules.data_validation_bbop_filtered_data.output



rule data_validation_bbop_figures:
    input:



rule data_validation_bbop:
    input:
        rules.data_validation_bbop_tables.input,
        rules.data_validation_bbop_figures.input
