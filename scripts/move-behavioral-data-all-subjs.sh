#!/bin/bash -e
#Author: Luis Piloto
# This script copies over session info data from the DATA_DIR specified in globals.sh to the subject's specific data folder under data/session_info/

source globals.sh

# this is a 

for subj in $ALL_SUBJECTS; do
	mkdir -p ./subjects/$subj/data/session_info/
	cp ${DATA_DIR}/session_log/$subj/log.txt ./subjects/$subj/data/session_info/
done
