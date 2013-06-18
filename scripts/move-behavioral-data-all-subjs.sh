#!/bin/bash -e
#Author: Luis Piloto
# This script copies over session info data from the DATA_DIR specified in globals.sh to the subject's specific data folder under data/session_info/

source globals.sh

# this is a 

for subj in $ALL_SUBJECTS; do
	mkdir -p ./subjects/$subj/data/session_info/
	# only copy it over if it doesn't already exist
	if [[ ! -f "./subjects/$subj/data/session_info/log.txt" ]]; then
		cp ${DATA_DIR}/session_log/$subj/log.txt ./subjects/$subj/data/session_info/
	fi
done
