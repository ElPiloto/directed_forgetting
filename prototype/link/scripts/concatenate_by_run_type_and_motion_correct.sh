source globals.sh

olddir=$(pwd)
cd $SUBJECT_DIR/$NIFTI_DIR/
#################################################### CONCATENATE WORDLIST FILES, IMAGE LOCALIZER, and WORD LOCALIZER 

if [ ! -f ALL_RUNS.nii.gz ]; then
	echo '====> CONCATENATION INTO FOUR GROUPS ALL_RUNS, WORDLISTS, IMG_LOCALIZERS, WORD_LOCALIZERS...' $(date +%H:%M:%S)

	# dynamically grab all of our WORDLIST files
	# NOTE: we sort the output files numerically, so we preserve ordering as long as the file names are correct
	wordlist_files=`ls  | grep "$WORDLIST_FILENAME_REGEX" | sort -n`
	word_localizer_files=`ls  | grep "$WORD_LOCALIZER_FILENAME_REGEX" | sort -n`
	image_localizer_files=`ls  | grep "$IMAGE_LOCALIZER_FILENAME_REGEX" | sort -n`

	for run in $wordlist_files
	do
		wordlist_string="${wordlist_string} $run"
	done

	for run in "$word_localizer_files"
	do
		word_localizer_string="${word_localizer_string} $run"
	done

	for run in $image_localizer_files
	do
		image_localizer_string="${image_localizer_string} $run"
	done


	echo 'Runs combined as follows:'
	echo 'WORDLISTS RUNS'
	echo $wordlist_string
	echo '---------------------------------------------'
	echo 'WORD LOCALIZER RUNS'
	echo $word_localizer_string 
	echo '---------------------------------------------'
	echo 'IMAGE LOCALIZER RUNS'
	echo $image_localizer_string

	fslmerge -a WORDLISTS $wordlist_string 
	fslmerge -a WORD_LOCALIZERS $word_localizer_string 
	fslmerge -a IMG_LOCALIZERS $image_localizer_string 
	fslmerge -a ALL_RUNS $wordlist_string $word_localizer_string $image_localizer_string
fi
 

if [ ! -f WORDLISTS_mc.nii.gz ]
then
	echo '====> MOTION CORRECTION FOR GROUP:  WORDLISTS...' $(date +%H:%M:%S)
	mcflirt -in WORDLISTS -o WORDLISTS_mc -refvol 0 -plots
fi

if [ ! -f WORD_LOCALIZERS_mc.nii.gz ]
then
	echo '====> MOTION CORRECTION FOR GROUP  WORD_LOCALIZERS...' $(date +%H:%M:%S)
	mcflirt -in WORD_LOCALIZERS -o WORD_LOCALIZERS_mc -refvol 0 -plots
fi

if [ ! -f IMG_LOCALIZERS_mc.nii.gz ]
then
	echo '====> MOTION CORRECTION FOR  IMG_LOCALIZERS...' $(date +%H:%M:%S)
	mcflirt -in IMG_LOCALIZERS -o IMG_LOCALIZERS_mc -refvol 0 -plots
fi

if [ ! -f ALL_RUNS_mc.nii.gz ]
then
	echo '====> MOTION CORRECTION FOR GROUP ALL_RUNS...' $(date +%H:%M:%S)
	mcflirt -in ALL_RUNS -o ALL_RUNS_mc -refvol 0 -plots
fi

cd "$olddir"

