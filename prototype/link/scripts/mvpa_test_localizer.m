%function [  ] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, data_dir, nifti_dir, feat_output_dir, session_log_file, varargin )
%function [ subj results] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, varargin )
% [  ] = MVPA_TEST_LOCALIZER(subj_id, save_dir, varargin)
% Purpose
% 
% This function will train a cross-validated localizer using a whole brain mask
%
% INPUT
%
% subj_id - string
% data_dir - this should be a directory where we will store our results
% nifti_dir - where we can find our EPIs, functionals, concatenated, etc
% feat_output_dir - where we can find the feat output, specifically our mask.nii.gz file
% session_log_file - path to a session log file for the particular subject which we can pass to parse_sesion_log.m to grab regressors for
%
% OUTPUT
% 
% Description of outputs
%
% EXAMPLE USAGE:
%
% 
% mvpa_test_localizer(Example inputs)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subj_id = '042113_DFFR_1';
neuropipe_subj_dir = ['/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/' subj_id '/'];
IMG_LOCALIZER_RUN_NUMBER = 15;
varargin = {};


defaults.exp_name = 'directed_forgetting';
defaults.nifti_dir = fullfile(neuropipe_subj_dir,'data','nifti');
%defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','ALL_RUNS.feat/');
defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','IMG_LOCALIZERS.feat/');
defaults.data_dir = fullfile(neuropipe_subj_dir,'data');
defaults.session_log_file = fullfile(neuropipe_subj_dir,'data','session_info','log.txt');
defaults.output_dir = fullfile(neuropipe_subj_dir,'data','mvpa_results');
defaults.class_args.train_funct_name = 'train_logreg';
defaults.class_args.test_funct_name = 'test_logreg';
defaults.class_args.penalty = 1;

options = parsepropval(defaults,varargin{:});

% here we hard-code some values which should be self-explanatory. it is quite likely
% that we will want to change some of these values into parameters
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [11 12 13];
% MASK_NAME = 'WHOLE_BRAIN';
% MASK_NIFTI_FILENAME = 'mask.nii';
% MASK_NIFTI_FILE = fullfile(options.feat_dir,MASK_NIFTI_FILENAME);
%FEATURE_SELECT_PVAL_THRESH = 0.001;
FEATURE_SELECT_PVAL_THRESH = 0.00005;
MASK_NAME = 'TEMPORAL_OCCIPITAL';
MASK_NIFTI_FILENAME = 'temporal_occipital_mask_transformed.nii';
MASK_NIFTI_FILE = fullfile(options.feat_dir,MASK_NIFTI_FILENAME);
EPI_NAME = 'EPI';
EPI_NIFTI_FILENAME = 'filtered_func_data.nii';
EPI_NIFTI_FILE = fullfile(options.feat_dir,EPI_NIFTI_FILENAME);
NUM_TRS_SHIFT = 2;

% init subject
subj = init_subj(options.exp_name,subj_id);


% load mask
unzip_nifti_file_if_necessary(MASK_NIFTI_FILE);
subj = load_spm_mask(subj,MASK_NAME,MASK_NIFTI_FILE);

% here we load run information - useful for creating our run selector and
% our regressors 
[runs] = parse_session_log('session_log_file',options.session_log_file);
% here we make any subject specific modifications to the regressors struct we created from the session log
runs = subject_regressor_modification(runs,subj_id);
% here we only grab the image localizer run
runs = runs(IMG_LOCALIZER_RUN_NUMBER);


% initialize our regressors
subj = init_object(subj,'regressors','conds');
subj = set_mat(subj,'regressors','conds',get_img_localizer_regressors_and_concatenate(runs,IMG_LOCALIZER_IDCS));

% initialize our run selector
% the 1 value below is due to a switch we made to load in the IMG_LOCALIZERS runs only (as opposed to having the img localizer run be part of a single 
% file with multiple runs in it...therefore we pass in 1 because we only have 1 run in the file we load.
[runs_selector, localizer_only_selector] = make_runs_selector(runs,1);
subj = init_object(subj,'selector','runs')
subj = set_mat(subj,'selector','runs',runs_selector);

subj = init_object(subj,'selector','localizer_runs_only');
subj = set_mat(subj,'selector','localizer_runs_only',localizer_only_selector);

%shift our regressors
shifted_regressors_name = ['runs_shift' num2str(NUM_TRS_SHIFT)];
subj = shift_regressors(subj,'conds','runs', NUM_TRS_SHIFT,'new_regsname',shifted_regressors_name);

% here we will create two selectors:
% bootleg_runs_for_xvalidation selector: is to run cross-validation on a single run.  this will make it look
% 		like our single run is actually multiple runs (allowing us to use create_xvalid_indices.m)
% ignore_ITI_block selector: this selector uses the shifted_regressors matrix to set zeros for TRs that fall between
% 		blocks.  This selector will subsequently be used so that we ignore those TRs in creating cross-validation indices
%
% generate the matrices
[bootleg_runs_for_xvalidation,ITI_timepts] = make_bootleg_runs_xvalid_img_localizer( get_mat(subj,'regressors',shifted_regressors_name) );
ignore_ITI_blocks_selector = ones(size(bootleg_runs_for_xvalidation));
ignore_ITI_blocks_selector(ITI_timepts) = 0;
% actually add the selectors to our subject struct
subj = init_object(subj,'selector','ignore_ITI_block');
subj = set_mat(subj,'selector','ignore_ITI_block',ignore_ITI_blocks_selector);
subj = init_object(subj,'selector','bootleg_runs');
subj = set_mat(subj,'selector','bootleg_runs',bootleg_runs_for_xvalidation);

% load up our EPI
unzip_nifti_file_if_necessary(EPI_NIFTI_FILE);
subj = load_spm_pattern(subj, EPI_NAME, MASK_NAME, EPI_NIFTI_FILE);

% zscore our data
subj = zscore_runs(subj,EPI_NAME,'runs');

% create cross-validation indices
subj = create_xvalid_indices(subj,'bootleg_runs','actives_selname','ignore_ITI_block','ignore_jumbled_runs',1);

% feature selection
% TODO: find out if this change is appropriate - using shifted regressors instead of initial regressors
% subj = feature_select(subj,[EPI_NAME '_z'],'conds','runs_xval')
%subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,'runs_xval')
subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,'bootleg_runs_xval','thresh',FEATURE_SELECT_PVAL_THRESH);

summarize(subj);

subj = move_pattern_to_hd(subj,EPI_NAME);

% classification
%[subj results] = cross_validation(subj,[EPI_NAME '_z'],'conds','runs_xval',[EPI_NAME '_z_thresh0.05'],options.class_args);
% finally, we actually do cross-validation
[subj results] = cross_validation(subj,[EPI_NAME '_z'],shifted_regressors_name,'bootleg_runs_xval',[EPI_NAME '_z_thresh' num2str(FEATURE_SELECT_PVAL_THRESH)],options.class_args);

%TODO: We eventually want to automatically save our results
 
%end


