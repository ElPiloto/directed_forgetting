 #!/bin/bash

 #== SET SUBJECT PARAMS HERE!! ==#
 subjnum=129
 FR_epi_run_numbers="2 4 6 8"
 CT_epi_run_numbers="10 12"
 structural_run_number="14"

 make_videos=false



homedir=$PWD

if false
then
    ''
fi

# dynamically determine our MPRAGE file assuming it has it's own filename defined in globals.sh
mprage_file=`ls $SUBJECT_DIR/$NIFTI_DIR/ | grep "$MPRAGE_FILENAME_REGEX"`

# fslswapdim ${structural_run_number}-1-1longmprage.nii.gz z -x y structural
fslswapdim $mprage_file z -x y $SUBJECT_DIR/$NIFTI_DIR/structural
fslorient -swaporient $SUBJECT_DIR/$NIFTI_DIR/structural # switch from 'radiological' to 'neurological'

	 echo '====> SWAPPING DIMENSIONS AND ORIENTATION' $(date +%H:%M:%S)
	 cd nifti
	 fslswapdim ${structural_run_number}-1-1longmprage.nii.gz z -x y structural
         fslorient -swaporient structural # switch from 'radiological' to 'neurological'


	 #==QUALITY CONTROL==#

	 # for automation XX, add a pause and display text.

	 # Now take a look at the structurals for quality control, using fslview.
	 # - check for wraparound/cutoff
	 # NOTES: some wraparound, but not into the brain

	 # Then take a look at the functionals.
	 # - check for motion using the 'Movie' function
	 # - look at individual voxels using Tools>Timeseries
	 # - check for dropout
	 # NOTES: a little motion

	 #==BET BRAIN EXTRACTION==#
	 # creates (a) skull-stripped anatomical (b) a binary whole-brain mask

	 # NOTES: includes brainstem and cerebellum

	 echo '====> BET BRAIN EXTRACTION... ' $(date +%H:%M:%S)
	 bet structural.nii.gz structural_brain.nii.gz -f 0.4 -R



	 #==MOTION CORRECTION==#

	 echo '====> CONCATENATION INTO BIG4D, FRONLY, CTONLY...' $(date +%H:%M:%S)
	 # concatenate into one file so that we can align all runs together
	 # need to changge specific to jeremy' naming convention
	 for run in $FR_epi_run_numbers
	 do
		 FRstring="${FRstring} ${run}-1-1epi*"
	 done

	 for run in $CT_epi_run_numbers
	 do
		 CTstring="${CTstring} ${run}-1-1epi*"
	 done

	 echo $FRstring
	 echo $CTstring

	 fslmerge -a FRonly $FRstring
	 fslmerge -a CTonly $CTstring
	 fslmerge -a big4D $FRstring $CTstring

	 # Quality control: check for motion across runs using the 'Movie' function
	 # NOTES:

	 echo '====> MOTION CORRECTION...' $(date +%H:%M:%S)
	 # motion correction - align to first measurement
	 mcflirt -in big4D -o big4D_mc -refvol 0 -plots
	 mcflirt -in CTonly -o CTonly_mc -refvol 0 -plots
	 mcflirt -in FRonly -o FRonly_mc -refvol 0 -plots
	 mkdir ../motion_correction
	 mv *.par ../motion_correction/

	 # plot the motion
	 cd ../motion_correction
	 fsl_tsplot -i big4D_mc.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png
	 fsl_tsplot -i big4D_mc.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png
	 # take a look at these two plots, and at the motion corrected 4D image
	 # NOTES: not bad
	 cd ..


if $make_videos
then

	 #==MAKE VIDEOS USING FFMPEG==#

	 echo '====> MAKING VIDEOS...' $(date +%H:%M:%S)
	 cd $homedir
	 scratchdir=~/mnt/scratch/scychan/temp/CLO${subjnum}_video
	 mkdir ${scratchdir}
	 mkdir ${scratchdir}/dcm
	 mkdir ${scratchdir}/jpg
	 mkdir ${scratchdir}/video
	 for run in $structural_run_number $FR_epi_run_numbers $CT_epi_run_numbers
	 do
		 for file in $(ls dicom/${run}-*)
		 do
		         filename=$(basename ${file} .dcm.gz)
			 cp ${file} ${scratchdir}/dcm/
			 gunzip ${scratchdir}/dcm/${filename}.dcm.gz
			 ind=${filename#${run}-}
			 if [ $(expr length $ind) = 1 ]
			 then
			     ind=00${ind}
			 elif [ $(expr length $ind) = 2 ]
			 then
			     ind=0${ind}
		         fi
			 outname=${run}-${ind}
			 dcmj2pnm +oj +Jq 90 +Wi 1 ${scratchdir}/dcm/${filename}.dcm ${scratchdir}/jpg/${outname}.jpg
		 done
		 ffmpeg -r 5 -i ${scratchdir}/jpg/${run}-%03d.jpg ${scratchdir}/video/run${run}.mp4
	 done

fi




#==SPLIT FILES?==#

split_files=false
if ${split_files}; then
# split the big file back up into individual runs?
#--CLO101--#
fslroi big4D_mc run1_mc 0 57
fslroi big4D_mc run2_mc 57 249
fslroi big4D_mc run3_mc 306 4
fslroi big4D_mc run4_mc 310 18
fslroi big4D_mc run5_mc 328 4
fslroi big4D_mc run6_mc 332 301
#--CLO102--#
fslroi big4D_mc run1_mc 0 351
fslroi big4D_mc run2_mc 351 10
fslroi big4D_mc run3_mc 361 351
fslroi big4D_mc run4_mc 712 349
fslroi big4D_mc run5_mc 1061 43
fslroi big4D_mc run6_mc 1104 13
fslroi big4D_mc run7_mc 1117 399
fi



#==PREPROCESSING==#

#cd ..
#
#Feat &
#
# params to change: Pre-stats only
#
#Select 4D data: CTonly_mc.nii.gz
#Output directory: CLOXXX_XXXXXX/CTonly.feat
#TR - 2.0
#High pass filter - 128s
#
#Motion correction - None
#Slice timing correction - interleaved?
#BET brain extraction - yes
#
#Registration - Main structural image (structural_brain.nii.gz)
#
# look at results
# http://www.fmrib.ox.ac.uk/fsl/feat5/output.html




