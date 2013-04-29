
source globals.sh


# dynamically determine our MPRAGE file assuming it has it's own filename defined in globals.sh
mprage_file=`ls $SUBJECT_DIR/$NIFTI_DIR/ | grep "$MPRAGE_FILENAME_REGEX"`

##################################### REORIENT FROM RADIOLOGICAL to NEUROLOGICAL AND SWAP DIMENSIONS ON STRUCTURAL (MPRAGE)
# only swap dimensions if the structural doesn't exist already
if [ ! -f "$SUBJECT_DIR/$NIFTI_DIR/structural.nii.gz" ];
then

	echo '====> SWAPPING DIMENSIONS AND ORIENTATION' $(date +%H:%M:%S) 'USING ' $mprage_file ' OUTPUTTING TO: ' $SUBJECT_DIR/$NIFTI_DIR/structural
	fslswapdim $SUBJECT_DIR/$NIFTI_DIR/$mprage_file z -x y $SUBJECT_DIR/$NIFTI_DIR/structural
	fslorient -swaporient $SUBJECT_DIR/$NIFTI_DIR/structural # switch from 'radiological' to 'neurological'
fi

###################################### BET BRAIN EXTRACTION FOR MPRAGE AND FLASH 
# ONLY PERFORM THIS STEP IF we don't have it yet
if [ ! -f "$SUBJECT_DIR/$NIFTI_DIR/structural_brain.nii.gz" ];
then
	 echo '====> BET BRAIN EXTRACTION of MPRAGE... ' $(date +%H:%M:%S) ' OUTPUTTING TO: ' $SUBJECT_DIR/$NIFTI_DIR/structural_brain.nii.gz
	 bet $SUBJECT_DIR/$NIFTI_DIR/structural.nii.gz $SUBJECT_DIR/$NIFTI_DIR/structural_brain.nii.gz -f 0.4 -R
fi

# dynamically determine our FLASH file assuming it has it's own filename defined in globals.sh
flash_file=`ls $SUBJECT_DIR/$NIFTI_DIR/ | grep "$FLASH_FILENAME_REGEX"`

# ONLY PERFORM THIS STEP IF we don't haven't done it yet
if [ ! -f "$SUBJECT_DIR/$NIFTI_DIR/flash_brain.nii.gz" ];
then
	 echo '====> BET BRAIN EXTRACTION of FLASH... ' $(date +%H:%M:%S) ' OUTPUTTING TO: ' $SUBJECT_DIR/$NIFTI_DIR/flash_brain.nii.gz
	 bet $SUBJECT_DIR/$NIFTI_DIR/$flash_file $SUBJECT_DIR/$NIFTI_DIR/flash_brain.nii.gz -f 0.4 -R
fi



