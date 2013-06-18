#!/bin/bash -e
#Author: Luis Piloto
# This script copies over session info data from the DATA_DIR specified in globals.sh to the subject's specific data folder under data/session_info/

source globals.sh
# this corresponds to the directory inside our DATA_DIR
# this lists everyon single subject in the fmri_dir directory
#!/bin/bash -e
#Author: Luis Piloto
# This script copies over session info data from the DATA_DIR specified in globals.sh to the subject's specific data folder under data/session_info/

source globals.sh
# this corresponds to the directory inside our DATA_DIR
FMRI_DIR="fmri data"
ALL_FMRI_SUBJECTS=$(ls -1d "${DATA_DIR}/$FMRI_DIR/"*/ | rev | cut -d / -f 2 | rev)
#echo "$FMRI_DIR"

for subj in $ALL_FMRI_SUBJECTS; do

	echo $subj

	 if [[ ! -d "./subjects/$subj/" ]]; then
		 echo "Scaffolding subject: $subj"
	 	./scaffold "$subj"
	 fi

	# behavioral data
	# only copy it over if it doesn't already exist
	if [[ ! -f "./subjects/$subj/data/session_info/log.txt" ]]; then
		echo "Making dir subjects/$subj/data/session_info/ and copying behavioral data into it"
		mkdir -p ./subjects/$subj/data/session_info/
		cp ${DATA_DIR}/session_log/$subj/log.txt ./subjects/$subj/data/session_info/
	fi

	# fmri data
	# only copy it over if it doesn't already exist
	if [[ ! -d "./subjects/$subj/data/nifti/" ]]; then
		echo "Making dir subjects/$subj/data/nifti/ and copying fmri data into it"
		mkdir -p ./subjects/$subj/data/nifti/
		cp "${DATA_DIR}/$FMRI_DIR/$subj/"* ./subjects/$subj/data/nifti/
	fi
done

