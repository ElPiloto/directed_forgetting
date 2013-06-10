#!/bin/bash
# this script assumes we're running from the SUBJECT_DIR

# this script assumes MASKDIR has been set by neuropipe's globals function
source globals.sh

old_dir=$(pwd)
#cd ${DATADIR}


#TODO: Add smarter detection of correct .feat output directory to use (i.e. sometimes we have ALL_RUNS.feat+++ instead of ALL_RUNS.feat) this could be easily done by piping ls'ing ALL_RUNS* and grabbing the last one created
img_names=("ALL_RUNS" "IMG_LOCALIZERS" "WORD_LOCALIZERS" "WORDLISTS")
for img in ${img_names[@]}
do
	# change to the appropriate feat output folder
	cd "${FIRSTLEVEL_DIR}/$img.feat"

	# compute the transform
	flirt -in $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -ref mean_func.nii.gz -omat MNI2mm2func.transform

	# apply the transform to the mask
	flirt -in ${MASKDIR}/temporal_occipital_mask.nii.gz -ref mean_func.nii.gz -applyxfm -init MNI2mm2func.transform -out temporal_occipital_mask_transformed

	# this code ensures we only have the unzipped version of the original temporal mask - otherwise the fslmaths command will break
	if [ -f temporal_occipital_mask_transformed.nii -a -f temporal_occipital_mask_transformed.nii.gz ]; then
		echo "removing temporal_occipital_mask_transformed.nii.gz"
		rm -f temporal_occipital_mask_transformed.nii.gz
	fi

	# threshold the mask at 0.5
	fslmaths temporal_occipital_mask_transformed -thr 0.5 temporal_occipital_mask_transformed

	# binarize the mask
	fslmaths temporal_occipital_mask_transformed.nii.gz -bin temporal_occipital_mask_transformed


	# here we zero out any entries that are in the transformed mask but are zeroed out in the mean_functional
	fslmaths mean_func.nii.gz -bin -mul temporal_occipital_mask_transformed.nii.gz temporal_occipital_mask_transformed_brain_extracted

	# de-compress the mask
	gunzip temporal_occipital_mask_transformed_brain_extracted.nii.gz

	# remove the uncompressed versoin
	rm -f temporal_occipital_mask_transformed_brain_extracted.nii.gz

	# check your mask
	#fslview&

	cd ${old_dir}
done
