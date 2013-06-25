source globals.sh

# this runs our registration on four different groups of images we have:
feat $FSF_DIR/ALL_RUNS.fsf
feat $FSF_DIR/WORDLISTS.fsf
feat $FSF_DIR/WORD_LOCALIZERS.fsf
feat $FSF_DIR/IMG_LOCALIZERS.fsf

bash ./scripts/wait-for-feat.sh $FIRSTLEVEL_DIR/ALL_RUNS.feat
bash ./scripts/wait-for-feat.sh $FIRSTLEVEL_DIR/WORDLISTS.feat
bash ./scripts/wait-for-feat.sh $FIRSTLEVEL_DIR/WORD_LOCALIZERS.feat
bash ./scripts/wait-for-feat.sh $FIRSTLEVEL_DIR/IMG_LOCALIZERS.feat

# register temporal occipital masks
bash scripts/transform_temporal_occipital_mask

# TODO: Add calls to GLM here
