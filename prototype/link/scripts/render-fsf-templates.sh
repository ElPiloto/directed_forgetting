#!/bin/bash
#
# render-fsf-templates.sh fills in templated fsf files so FEAT can use them
# original author: mason simon (mgsimon@princeton.edu)
# this script was provided by NeuroPipe. modify it to suit your needs
#
# refer to the secondlevel neuropipe tutorial to see an example of how
# to use this script

set -e

source globals.sh

 
function render_firstlevel {
  fsf_template=$1
  output_dir=$2
  standard_brain=$3
  data_file_prefix=$4
  initial_highres_file=$5
  highres_file=$6
  number_volumes=$7

  subject_dir=$(pwd)

  # note: the following replacements put absolute paths into the fsf file. this
  #       is necessary because FEAT changes directories internally
  cat $fsf_template \
    | sed "s:<?= \$OUTPUT_DIR ?>:$subject_dir/$output_dir:g" \
    | sed "s:<?= \$STANDARD_BRAIN ?>:$standard_brain:g" \
    | sed "s:<?= \$DATA_FILE_PREFIX ?>:$subject_dir/$data_file_prefix:g" \
    | sed "s:<?= \$INITIAL_HIGHRES_FILE ?>:$subject_dir/$initial_highres_file:g" \
    | sed "s:<?= \$HIGHRES_FILE ?>:$subject_dir/$highres_file:g" \
    | sed "s:<?= \$NUM_VOLUMES ?>:$number_volumes:g" \

}

function render_firstlevel_glm {
  fsf_template=$1
  output_dir=$2
  standard_brain=$3
  data_file_prefix=$4
  initial_highres_file=$5
  highres_file=$6
  number_volumes=$7
  scenes_regressors_file=$8
  objects_regressors_file=$9
  scrambled_scenes_regressors_file=${10}

  subject_dir=$(pwd)

  # note: the following replacements put absolute paths into the fsf file. this
  #       is necessary because FEAT changes directories internally
  cat $fsf_template \
    | sed "s:<?= \$OUTPUT_DIR ?>:$subject_dir/$output_dir:g" \
    | sed "s:<?= \$STANDARD_BRAIN ?>:$standard_brain:g" \
    | sed "s:<?= \$DATA_FILE_PREFIX ?>:$subject_dir/$data_file_prefix:g" \
    | sed "s:<?= \$INITIAL_HIGHRES_FILE ?>:$subject_dir/$initial_highres_file:g" \
    | sed "s:<?= \$HIGHRES_FILE ?>:$subject_dir/$highres_file:g" \
    | sed "s:<?= \$NUM_VOLUMES ?>:$number_volumes:g" \
    | sed "s:<?= \$SCENES_REGRESSORS_FILE ?>:$subject_dir/$scenes_regressors_file:g" \
    | sed "s:<?= \$OBJECTS_REGRESSORS_FILE ?>:$subject_dir/$objects_regressors_file:g" \
    | sed "s:<?= \$SCRAMBLED_SCENES_REGRESSORS_FILE ?>:$subject_dir/$scrambled_scenes_regressors_file:g" 


}

img_names=("ALL_RUNS" "WORD_LOCALIZERS" "WORDLISTS")
for img in ${img_names[@]}
do
	# this gives us an automatic way of grabbing the number of volumes in an image and setting the 
	# correct value in our .fsf file, otherwise we get an error a pre-stats  part of feat
	num_TRs=`fslinfo $NIFTI_DIR/${img}_mc | grep '^dim4.*[0-9]*$' | sed 's/dim4\s*\([0-9]\)/\1/g'`
	render_firstlevel $FSF_DIR/just_register.fsf.template \
		$FIRSTLEVEL_DIR/$img.feat \
		$FSL_DIR/data/standard/MNI152_T1_2mm_brain \
		$NIFTI_DIR/${img}_mc \
		$NIFTI_DIR/flash_brain \
		$NIFTI_DIR/structural_brain \
		${num_TRs} \
		> $FSF_DIR/$img.fsf
	# echo "Number of volumes in ${img}_mc is ${num_TRs}"
	echo "Rendered images: ${img}"
done

img_names=("IMG_LOCALIZERS")
for img in ${img_names[@]}
do
	# this gives us an automatic way of grabbing the number of volumes in an image and setting the 
	# correct value in our .fsf file, otherwise we get an error a pre-stats  part of feat
	num_TRs=`fslinfo $NIFTI_DIR/${img}_mc | grep '^dim4.*[0-9]*$' | sed 's/dim4\s*\([0-9]\)/\1/g'`
	render_firstlevel_glm $FSF_DIR/IMG_LOCALIZERS_GLM.fsf.template \
		$FIRSTLEVEL_DIR/$img.feat \
		$FSL_DIR/data/standard/MNI152_T1_2mm_brain \
		$NIFTI_DIR/${img}_mc \
		$NIFTI_DIR/flash_brain \
		$NIFTI_DIR/structural_brain \
		${num_TRs} \
		/data/regressors/scenes.txt \
		/data/regressors/objects.txt \
		/data/regressors/scrambled_scenes.txt \
		> $FSF_DIR/$img.fsf
	# echo "Number of volumes in ${img}_mc is ${num_TRs}"
	echo "Rendered images: ${img}"
done

