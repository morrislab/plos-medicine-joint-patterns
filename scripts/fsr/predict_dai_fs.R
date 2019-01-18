# Conducts forward sequential regression to predict PC 2 scores.

library(argparse)

library(data.table)

library(feather)

library(selectiveInference)

library(plyr)

library(dplyr)

library(dtplyr)

library(feather)

library(psych)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--projection-input', required = TRUE)

parser$add_argument('--medication-input', required = TRUE)

parser$add_argument('--score-input', required = TRUE)

parser$add_argument('--diagnosis-input', required = TRUE)

parser$add_argument('--age-time-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--visits', type = 'integer', nargs = '+', default = c(2, 3))

parser$add_argument('--ignore', nargs = '+')

parser$add_argument('--seed', type = 'integer', default = 89347934)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.projections <- fread(args$projection_input)

dt.medications <- setDT(read_feather(args$medication_input))

dt.scores <- fread(args$score_input, header = TRUE)

setnames(dt.scores, 1, 'patient_id')

setnames(dt.scores, 2:ncol(dt.scores), paste0('factor', tail(colnames(dt.scores), -1)))

dt.dx <- fread(args$diagnosis_input)

dt.dx[, diagnosis := sub('^\\d+\\s*', '', diagnosis)]

dt.age.time <- setDT(read_feather(args$age_time_input))[, .(subject_id, diagnosis_age_days, symptom_onset_to_diagnosis_days)]



message('Filtering medications to visits of interest')

dt.medications <- dt.medications[visit_id %in% args$visits]



if (!is.null(args$ignore)) {

    message('Removing blacklisted medications')

    dt.medications <- dt.medications[, setdiff(colnames(dt.medications), args$ignore), with = FALSE]

}



message('Filtering data')

setkey(dt.scores, patient_id)

dt.patient.ids <- dt.scores[, .(patient_id)]

dt.projections <- setkey(dt.projections, subject_id)[dt.patient.ids, nomatch = 0]

dt.medications <- setkey(dt.medications[visit_id > 1], subject_id)[dt.patient.ids, nomatch = 0]

dt.dx <- setkey(dt.dx, subject_id)[dt.patient.ids, nomatch = 0]

dt.age.time <- setkey(dt.age.time, subject_id)[dt.patient.ids, nomatch = 0]



message('Transforming medication statuses')

for (j in ncol(dt.medications):3) {

    set(dt.medications, j = j, value = !(dt.medications[[j]] %in% c('NONE', 'NEW')))

}



message('Removing uninformative medications')

for (j in ncol(dt.medications):3) {

    if (sum(dt.medications[[j]]) < 1) {

        set(dt.medications, j = j, value = NULL)

    }

}



message('Coercing medications to R names')

setnames(dt.medications, sub('\\.', '_', make.names(tolower(colnames(dt.medications)))))



message('Dummy-encoding diagnoses')

dx.renamed <- paste('diagnosis', tolower(gsub('[^A-Za-z0-9_]', '_', dt.dx$diagnosis)), sep = '_')

dt.dx.recoded <- data.table(patient_id = dt.dx$subject_id, dummy.code(dx.renamed))

setkey(dt.dx.recoded, patient_id)



message('Filtering and scaling age of and time to diagnosis')

dt.age.time <- dt.age.time[!(is.na(symptom_onset_to_diagnosis_days) | is.na(diagnosis_age_days))]

dt.age.time[, `:=`(
    symptom_onset_to_diagnosis_days = scale(symptom_onset_to_diagnosis_days),
    diagnosis_age_days = scale(diagnosis_age_days)
)]



message('Scaling projections with respect to baseline')

param.shift <- dt.projections[visit_id == 1, mean(PC2)]

param.scale <- dt.projections[visit_id == 1, sd(PC2)]

dt.projections[, pc2_scaled := (PC2 - param.shift) / param.scale]

dt.projections[, PC2 := NULL]



message('Scaling factor scores')

for (j in 2:ncol(dt.scores)) {

    set(dt.scores, j = j, value = scale(dt.scores[[j]]))

}



message('Reformatting projection data')

dt.projections.baseline <- select(dt.projections[visit_id == 1], -visit_id)

setnames(dt.projections.baseline, 'pc2_scaled', 'pc2_scaled_baseline')

dt.projections.reformatted <- dt.projections.baseline[dt.projections[visit_id > 1]]



message('Filtering underrepresented treatments')

dt.medications.melted <- melt(dt.medications, id.vars = c('subject_id', 'visit_id'), variable.name = 'treatment', value.name = 'status', variable.factor = FALSE)

dt.medications.melted <- dt.medications.melted[, if (sum(status) > 0) .SD else NULL, keyby = .(treatment, visit_id)]

dt.medication.counts <- dt.medications.melted[, .(count = sum(status)), keyby = .(treatment, visit_id)]

# Locate the biggest cut in counts and filter to above that threshold.

setorder(dt.medication.counts, count)

lagging.diffs <- dt.medication.counts$count - shift(dt.medication.counts$count)

# Keep track of which medications and counts we are removing -- we need to
# remove corresponding patient-visits.

dt.medications.to.remove <- select(head(dt.medication.counts, which.max(lagging.diffs) - 1), -count)

dt.medication.counts <- tail(dt.medication.counts, -which.max(lagging.diffs) + 1)

# Remove affected patient-visits.

dt.medication.patient.mask <- setkey(dt.medications.melted, treatment, visit_id)[setkey(dt.medications.to.remove, treatment, visit_id)][, .(retain = all(status == 0)), keyby = .(subject_id, visit_id)]

dt.medication.patient.mask <- select(dt.medication.patient.mask[retain == TRUE], -retain)

dt.medications.melted <- setkey(dt.medications.melted, subject_id, visit_id)[dt.medication.patient.mask]

# Recast the medications.

dt.medications.melted <- setkey(dt.medications.melted, treatment, visit_id)[setkey(dt.medication.counts[, .(treatment, visit_id)], treatment, visit_id), nomatch = 0]

dts.medications.casted <- dlply(dt.medications.melted, .(visit_id), function (df.slice) {

    dcast(df.slice, subject_id + visit_id ~ treatment, value.var = 'status', fun.aggregate = function (x) {

        result <- Reduce('|', x)

        if (is.null(result)) 0 else as.integer(result)

    }) %>% select(-visit_id)

})



message('Merging data')

dts.merged <- llply(args$visits, function (v) {

    # For the given visit, generate data containing PC 2 projections for all prior visits.

    dt.projections.this <- dt.projections.reformatted[visit_id == v]

    setkey(dt.projections.this, subject_id)

    if (v > 2) {

        dt.projections.previous <- dt.projections.reformatted[visit_id < v]

        dt.projections.previous[, column_name := paste0('pc2_scaled_', visit_id)]

        dt.projections.previous <- dcast(dt.projections.previous, subject_id ~ column_name, value.var = 'pc2_scaled')

        dt.scores[dt.dx.recoded][dt.age.time, nomatch = 0][dt.projections.reformatted[visit_id == v], nomatch = 0][dt.projections.previous, nomatch = 0][dts.medications.casted[[v - 1]], nomatch = 0]

    } else {

        dt.scores[dt.dx.recoded][dt.age.time, nomatch = 0][dt.projections.reformatted[visit_id == v], nomatch = 0][dts.medications.casted[[v - 1]], nomatch = 0]

    }

})



message('Running forward sequential regression')

outcomes <- llply(dts.merged, function (dt.slice) {

    dt.slice$pc2_scaled

})

predictors <- llply(dts.merged, function (dt.slice) {

    select(dt.slice, -patient_id, -pc2_scaled, -visit_id)

})

set.seed(args$seed)

fs.fits <- llply(1:length(outcomes), function (i) {

    visit.number <- unique(dts.merged[[i]]$visit_id)

    predictor.names = colnames(predictors[[i]])

    list(
        visit_id = visit.number,
        predictors = predictor.names,
        result = fs(as.matrix(predictors[[i]]), outcomes[[i]], maxsteps = 2000, intercept = TRUE, normalize = TRUE)
    )

})



message('Saving results')

save(fs.fits, file = args$output)



message('Done')
