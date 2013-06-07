#!/bin/bash
# get_num_runs.sh - will get the number of runs in all .nii.gz files
#

for file in `ls *epi*.nii.gz | sort -n`
do
	num_TRs=$(fslinfo $file | grep '^dim4.*[0-9]*$' | sed 's/dim4\s*\([0-9]\)/\1/g')
	echo "$file: $num_TRs volumes"
done
