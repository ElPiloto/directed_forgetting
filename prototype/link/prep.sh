#!/bin/bash
#
# prep.sh prepares for analysis of the subject's data
# original author: mason simon (mgsimon@princeton.edu)
# this script was provided by NeuroPipe. modify it to suit your needs

set -e

source globals.sh

# we don't want to do this because our data is already in nifti format
#bash scripts/convert-and-wrap-raw-data.sh $DICOM_ARCHIVE $NIFTI_DIR $SUBJ $RUNORDER_FILE
#bash scripts/qa-wrapped-data.sh $NIFTI_DIR $QA_DIR
#bash scripts/reorient-to-las.sh $NIFTI_DIR
bash scripts/reorient_mprage_and_BET_structurals.sh
bash scripts/concatenate_by_run_type_and_motion_correct.sh
# here we run a matlab script that will generate our regressor files for us 
# so that we can use them in a Feat GLM analysis 
cd scripts;
pni_matlab -r "try generate_regressors_for_glm('${SUBJ}'); catch; end; quit"
cd ..;

# here we actually render our fsf templates
bash scripts/render-fsf-templates.sh

