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
subj_id = '042013_DFFR_0';
neuropipe_subj_dir = ['/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/' subj_id '/'];
varargin = {};


defaults.exp_name = 'directed_forgetting';
defaults.nifti_dir = fullfile(neuropipe_subj_dir,'data','nifti');
defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','ALL_RUNS.feat/');
defaults.data_dir = fullfile(neuropipe_subj_dir,'data');
defaults.session_log_file = fullfile(neuropipe_subj_dir,'data','session_info','log.txt');
defaults.output_dir = fullfile(neuropipe_subj_dir,'data','mvpa_results');
defaults.class_args.train_funct_name = 'train_ridge';
defaults.class_args.test_funct_name = 'test_ridge';
defaults.class_args.penalty = 1;

options = parsepropval(defaults,varargin{:});

% here we hard-code some values which should be self-explanatory. it is quite likely
% that we will want to parametrize these values 
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [10 11 12];
MASK_NAME = 'WHOLE_BRAIN';
MASK_NIFTI_FILENAME = 'mask.nii';
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

% initialize our regressors
subj = init_object(subj,'regressors','conds');
subj = set_mat(subj,'regressors','conds',get_img_localizer_regressors_and_concatenate(runs));

% initialize our run selector
subj = init_object(subj,'selector','runs');
subj = set_mat(subj,'selector','runs',make_runs_selector(runs));

%shift our regressors
shifted_regressors_name = ['runs_shift' num2str(NUM_TRS_SHIFT)];
subj = shift_regressors(subj,'conds','runs', NUM_TRS_SHIFT,'new_regsname',shifted_regressors_name);

% load up our super large epi - woof
unzip_nifti_file_if_necessary(EPI_NIFTI_FILE);
subj = load_spm_pattern(subj, EPI_NAME, MASK_NAME, EPI_NIFTI_FILE);

% zscore our data
subj = zscore_runs(subj,EPI_NAME,'runs');

% create cross-validation indices
subj = create_xvalid_indices(subj,'runs');

% feature selection
subj = feature_select(subj,[EPI_NAME '_z'],'conds','runs_xval')

% classification
[subj results] = cross_validation(subj,[EPI_NAME '_z'],'conds','runs_xval',[EPI_NAME '_z_thresh0.05'],options.class_args);

%end


