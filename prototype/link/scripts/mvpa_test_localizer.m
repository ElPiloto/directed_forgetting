%function [  ] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, data_dir, nifti_dir, feat_output_dir, session_log_file, varargin )
function [ subj results] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, varargin )
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
%subj_id = '042113_DFFR_2';
%neuropipe_subj_dir = ['/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/' subj_id '/'];
IMG_LOCALIZER_RUN_NUMBER = get_subj_specific_img_localizer_run_idx();
%varargin = {};


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
defaults.feature_select_thresh = 0.0005;
defaults.mask_filename = 'temporal_occipital_mask_transformed_brain_extracted.nii';

options = parsepropval(defaults,varargin{:});

% here we hard-code some values which should be self-explanatory. it is quite likely
% that we will want to change some of these values into parameters
%global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [11 12 13];
% TODO: also turn this into a function so that we make it explicit that these values are used in multiple places
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [12 13 14];
% MASK_NAME = 'WHOLE_BRAIN';
% options.mask_filename = 'mask.nii';
% MASK_NIFTI_FILE = fullfile(options.feat_dir,options.mask_filename);
%FEATURE_SELECT_PVAL_THRESH = 0.001;
%FEATURE_SELECT_PVAL_THRESH = 0.0005;
MASK_NAME = 'TEMPORAL_OCCIPITAL';
%options.mask_filename = 'temporal_occipital_mask_transformed.nii';
MASK_NIFTI_FILE = fullfile(options.feat_dir,options.mask_filename);
%EPI_NAME = 'EPI';
EPI_NAME = ['IMG_LOCALIZER_' MASK_NAME '_MASKED'];
EPI_NIFTI_FILENAME = 'filtered_func_data.nii';
EPI_NIFTI_FILE = fullfile(options.feat_dir,EPI_NIFTI_FILENAME);
NUM_TRS_SHIFT = 2;
SUBJECT_MAT_SAVE_FILE = fullfile(options.output_dir,'subject.mat');

% the two extra tildes are to convert to logical form
if ~~~exist(options.output_dir,'dir')
    mkdir(options.output_dir);
end

% init subject
if exist(SUBJECT_MAT_SAVE_FILE,'file')
	load(SUBJECT_MAT_SAVE_FILE);
end
% this covers us in case the SUBJECT_MAT_SAVE_FILE gets corrupted 
% and no longer contains the subj variable
if ~exist('subj','var')
	subj = init_subj(options.exp_name,subj_id);
end


% load mask
if ~exist_object(subj,'mask',MASK_NAME)
	unzip_nifti_file_if_necessary(MASK_NIFTI_FILE);
	subj = load_spm_mask(subj,MASK_NAME,MASK_NIFTI_FILE);
end

% TODO: TODO: TODO: Need to modify options.img to appropriate item
% AND need to add third item
regressors_suffix = [num2str(IMG_LOCALIZER_IDCS(1)) '_' num2str(IMG_LOCALIZER_IDCS(2)) '_' num2str(IMG_LOCALIZER_IDCS(3))];
regressor_name = ['conds_' regressors_suffix];


if ~exist_object(subj,'regressors',regressor_name)
    
    % here we load run information - useful for creating our run selector and
	% our regressors 
	[runs] = parse_session_log('session_log_file',options.session_log_file);
	% here we make any subject specific modifications to the regressors struct we created from the session log
	runs = subject_regressor_modification(runs,subj_id);
	% here we only grab the image localizer run
	runs = runs(IMG_LOCALIZER_RUN_NUMBER);
    
	% initialize our regressors
% 	subj = init_object(subj,'regressors','conds');
% 	subj = set_mat(subj,'regressors','conds',get_img_localizer_regressors_and_concatenate(runs,options.img_localizer_idcs));
    subj = init_object(subj,'regressors',regressor_name);
	subj = set_mat(subj,'regressors',regressor_name,get_img_localizer_regressors_and_concatenate(runs,IMG_LOCALIZER_IDCS));
end

% initialize our run selector
if ~exist_object(subj,'selector','runs')
    % only parse if we need to parse
    if ~exist('runs','var')
        % here we load run information - useful for creating our run selector and
        % our regressors 
        [runs] = parse_session_log('session_log_file',options.session_log_file);
        % here we make any subject specific modifications to the regressors struct we created from the session log
        runs = subject_regressor_modification(runs,subj_id);
        % here we only grab the image localizer run
        runs = runs(IMG_LOCALIZER_RUN_NUMBER);
    end
    
	% initialize our run selector
	% the 1 value below is due to a switch we made to load in the IMG_LOCALIZERS runs only (as opposed to having the img localizer run be part of a single 
	% the 1 value below is due to a switch we made to load in the IMG_LOCALIZERS runs only (as opposed to having the img localizer run be part of a single 
	% file with multiple runs in it...therefore we pass in 1 because we only have 1 run in the file we load.
	[runs_selector, localizer_only_selector] = make_runs_selector(runs,1);
	subj = init_object(subj,'selector','runs')
	subj = set_mat(subj,'selector','runs',runs_selector);

	subj = init_object(subj,'selector','localizer_runs_only');
	subj = set_mat(subj,'selector','localizer_runs_only',localizer_only_selector);
end

%shift our regressors
shifted_regressors_name = ['runs_shift' num2str(NUM_TRS_SHIFT) '_' regressors_suffix];

if ~exist_object(subj,'regressors',shifted_regressors_name)
	subj = shift_regressors(subj,regressor_name,'runs', NUM_TRS_SHIFT,'new_regsname',shifted_regressors_name);
end

bootleg_runs_name = ['bootleg_runs_' regressors_suffix];
if ~exist_object(subj,'selector',bootleg_runs_name)
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
    ignore_ITI_block_name = ['ignore_ITI_block_' regressors_suffix];
	subj = init_object(subj,'selector',ignore_ITI_block_name);
	subj = set_mat(subj,'selector',ignore_ITI_block_name,ignore_ITI_blocks_selector);
	subj = init_object(subj,'selector',bootleg_runs_name);
	subj = set_mat(subj,'selector',bootleg_runs_name,bootleg_runs_for_xvalidation);
end

% load up our EPI
if ~exist_object(subj,'pattern',EPI_NAME)
	unzip_nifti_file_if_necessary(EPI_NIFTI_FILE);
	subj = load_spm_pattern(subj, EPI_NAME, MASK_NAME, EPI_NIFTI_FILE);
	subj = move_pattern_to_hd(subj,EPI_NAME);
end

% zscore our data
if ~exist_object(subj,'pattern',[EPI_NAME '_z'])
	subj = zscore_runs(subj,EPI_NAME,'runs');
	subj = move_pattern_to_hd(subj,[EPI_NAME '_z']);
end

% create cross-validation indices
if ~exist_group(subj,'selector',[bootleg_runs_name '_xval'])
	subj = create_xvalid_indices(subj,bootleg_runs_name,'actives_selname',ignore_ITI_block_name,'ignore_jumbled_runs',1);
end

thresholded_mask_feature_select_group_name = [EPI_NAME '_z_' regressors_suffix '_thresh'];
full_thresholded_mask_feature_select_group_name = [thresholded_mask_feature_select_group_name num2str(options.feature_select_thresh)];
threshold_pattern_feature_select_group_name = [EPI_NAME '_z_' regressors_suffix '_anova'];

if ~exist_group(subj,'mask',full_thresholded_mask_feature_select_group_name)
	% feature selection
	% TODO: find out if this change is appropriate - using shifted regressors instead of initial regressors
	% subj = feature_select(subj,[EPI_NAME '_z'],'conds','runs_xval')
	%subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,'runs_xval')
    if ~exist_group(subj,'pattern',threshold_pattern_feature_select_group_name)
        subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,[bootleg_runs_name '_xval'],'thresh',options.feature_select_thresh, ...
            'new_maskstem',thresholded_mask_feature_select_group_name, 'new_map_patname', threshold_pattern_feature_select_group_name);
        pat_names = find_group(subj,'pattern',threshold_pattern_feature_select_group_name);
        for pat_name = pat_names
            pat_name = pat_name{:};
            subj = move_pattern_to_hd(subj,pat_name);
        end
    else % this is the case where we've ALREADY created the anova patterns for each fold for this particular combination, but we want to threshold it differently
         
         subj = create_thresh_mask(subj,threshold_pattern_feature_select_group_name,full_thresholded_mask_feature_select_group_name,options.feature_select_thresh);
    end
    
end

summarize(subj,'display_groups',true);

%subj = move_pattern_to_hd(subj,EPI_NAME);

% classification
%[subj results] = cross_validation(subj,[EPI_NAME '_z'],'conds','runs_xval',[EPI_NAME '_z_thresh0.05'],options.class_args);
% finally, we actually do cross-validation
[subj results] = cross_validation(subj,[EPI_NAME '_z'],shifted_regressors_name,[bootleg_runs_name '_xval'],full_thresholded_mask_feature_select_group_name,options.class_args);

%TODO: We eventually want to automatically save our results
save(SUBJECT_MAT_SAVE_FILE,'subj','-v7.3');

end


