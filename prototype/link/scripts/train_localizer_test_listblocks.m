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
subj_id = '042113_DFFR_2';
neuropipe_subj_dir = ['/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/' subj_id '/'];
IMG_LOCALIZER_RUN_NUMBER = 15;
varargin = {};


defaults.exp_name = 'directed_forgetting';
defaults.nifti_dir = fullfile(neuropipe_subj_dir,'data','nifti');
%defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','ALL_RUNS.feat/');
defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','ALL_RUNS.feat/');
defaults.data_dir = fullfile(neuropipe_subj_dir,'data');
defaults.session_log_file = fullfile(neuropipe_subj_dir,'data','session_info','log.txt');
defaults.output_dir = fullfile(neuropipe_subj_dir,'data','mvpa_results');
defaults.class_args.train_funct_name = 'train_logreg';
defaults.class_args.test_funct_name = 'test_logreg';
defaults.class_args.penalty = 1;

options = parsepropval(defaults,varargin{:});

% here we hard-code some values which should be self-explanatory. IT IS QUITE LIKELY
% THAT WE WILL WANT TO CHANGE SOME OF THESE VALUES INTO PARAMETERS
% MASK_NAME = 'WHOLE_BRAIN';
% MASK_NIFTI_FILENAME = 'mask.nii';
% MASK_NIFTI_FILE = fullfile(options.feat_dir,MASK_NIFTI_FILENAME);
%FEATURE_SELECT_PVAL_THRESH = 0.001;
%FEATURE_SELECT_PVAL_THRESH = 0.0005; ~ 3500
%FEATURE_SELECT_PVAL_THRESH = 0.0000005; ~ 2700
%FEATURE_SELECT_PVAL_THRESH = 0.0000000005; ~ 900
%FEATURE_SELECT_PVAL_THRESH = 0.000000000005; ~ 367 voxels
FEATURE_SELECT_PVAL_THRESH = 0.000000000005;
MASK_NAME = 'TEMPORAL_OCCIPITAL';
MASK_NIFTI_FILENAME = 'temporal_occipital_mask_transformed.nii';
MASK_NIFTI_FILE = fullfile(options.feat_dir,MASK_NIFTI_FILENAME);
EPI_NAME = 'EPI';
EPI_NIFTI_FILENAME = 'filtered_func_data.nii';
EPI_NIFTI_FILE = fullfile(options.feat_dir,EPI_NIFTI_FILENAME);
NUM_TRS_SHIFT = 2;
NUM_BLOCK1_TRS = 12; % this is the number of list pair presentations we have

% the next few lines refer to what rows in our regressor matrix correspond to which conditions
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [11 12 13];
global PRESENT_LIST1_IDX; PRESENT_LIST1_IDX = [1];
global PRESENT_LIST2_IDX_FORGET_LIST1; PRESENT_LIST2_IDX_FORGET_LIST1 = [2];
global PRESENT_LIST2_IDX_REMEMBER_LIST1; PRESENT_LIST2_IDX_REMEMBER_LIST1 = [3];
global RECALL_LIST1_IDX; RECALL_LIST1_IDX = [4];
global RECALL_LIST2_REMEMBER_LIST1_IDX; RECALL_LIST2_REMEMBER_LIST1_IDX = [5];
global RECALL_LIST2_FORGET_LIST1_IDX; RECALL_LIST2_FORGET_LIST1_IDX = [6];


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
subj = set_mat(subj,'regressors','conds',get_img_localizer_regressors_and_concatenate(runs,IMG_LOCALIZER_IDCS));

% make a selector to indicate which runs each TR belongs to as well as make a single localizer
% that specifies which runs are for the localizer
[runs_selector, localizer_only_selector] = make_runs_selector(runs,IMG_LOCALIZER_RUN_NUMBER);

% initialize our run selector
subj = init_object(subj,'selector','runs')
subj = set_mat(subj,'selector','runs',runs_selector);

subj = init_object(subj,'selector','localizer_runs_only');
subj = set_mat(subj,'selector','localizer_runs_only',localizer_only_selector);

%shift our regressors
shifted_regressors_name = ['runs_shift' num2str(NUM_TRS_SHIFT)];
subj = shift_regressors(subj,'conds','runs', NUM_TRS_SHIFT,'new_regsname',shifted_regressors_name);

% now we make our "cross-validation" selector which requires three steps:
% 		1. set all time points to 2 (indicating, by default each time point should be tested on)
% 		2. set all time points belonging to the img_localizer run to 1 (indicating they should be trained on)
% 		3. set all time points in the img_localizer run with shifted regressors values that don't correspond to 
% 		any condition to zero (indicating we don't want to train OR test) on these values
% Step 1.
train_localizer_test_all_other_TRs_selector = 2 * ones(1,numel(runs_selector));
% Step 2.
localizer_TR_idcs = find(runs_selector == IMG_LOCALIZER_RUN_NUMBER);
train_localizer_test_all_other_TRs_selector(localizer_TR_idcs) = 1;
% Step 3.
combined_regressors = sum(get_mat(subj,'regressors',shifted_regressors_name));
combined_regressors = combined_regressors(localizer_TR_idcs);
% this is for dealing with the fact that we're trying to find 0-values in a subset of our regressors matrix,
% but we want to change values on a selector with a different length
tmp_selector = train_localizer_test_all_other_TRs_selector(localizer_TR_idcs);
zero_valued_localizer_TR_idcs = find(combined_regressors == 0);
tmp_selector(zero_valued_localizer_TR_idcs) = 0;
train_localizer_test_all_other_TRs_selector(localizer_TR_idcs) = tmp_selector;
clear tmp_selector;

% finally, we can actually add the selector
subj = initset_object(subj,'selector','train_localizer_test_all_other_TRs_1',train_localizer_test_all_other_TRs_selector,...
			'group_name','train_localizer_test_all_other_TRs');

% load up our EPI
unzip_nifti_file_if_necessary(EPI_NIFTI_FILE);
subj = load_spm_pattern(subj, EPI_NAME, MASK_NAME, EPI_NIFTI_FILE);

% zscore our data
subj = zscore_runs(subj,EPI_NAME,'runs');

% we can get rid of our initial pattern now

% feature selection
subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,'train_localizer_test_all_other_TRs','thresh',FEATURE_SELECT_PVAL_THRESH);

summarize(subj);

subj = move_pattern_to_hd(subj,EPI_NAME);

% classification
% finally, we actually do cross-validation
[subj results] = cross_validation(subj,[EPI_NAME '_z'],shifted_regressors_name,'train_localizer_test_all_other_TRs',[EPI_NAME '_z_thresh' num2str(FEATURE_SELECT_PVAL_THRESH)],options.class_args);

% here we create a regressor, shift it, then select the time points of interest on a run-by-run basis
% add regressor containing all regressors (as opposed to truncated regressors that only had image localizer)
all_regressors = [runs.regressors];
subj = initset_object(subj,'regressors','all_regressors',all_regressors);
% now shift our regressors
shifted_all_regressors_name = ['all_runs_shift' num2str(NUM_TRS_SHIFT)];
subj = shift_regressors(subj,'all_regressors','runs', NUM_TRS_SHIFT,'new_regsname',shifted_all_regressors_name);

% grab list 2 - forget list 1
shifted_all_regressors = get_mat(subj,'regressors',shifted_all_regressors_name);
trs_of_interest = find(shifted_all_regressors(RECALL_LIST2_FORGET_LIST1_IDX,:));

% plot run by run
figure; hold all;

for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	forget_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_FORGET_LIST1,:)),run_TRs);
	remember_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_REMEMBER_LIST1,:)),run_TRs);
    
    forget_classifier_values = [results.iterations.acts(1,forget_trs)];
    remember_classifier_values = [results.iterations.acts(1,remember_trs)];
    if ~isempty(forget_classifier_values)
        subplot(2,1,1);
        hold all;
        plot(forget_classifier_values);
        disp(['Forget:' num2str(mean(forget_classifier_values))]);
    end
    if ~isempty(remember_classifier_values)
        subplot(2,1,2); hold all;
        plot(remember_classifier_values);
        disp(['Remember:' num2str(mean(remember_classifier_values))]);
    end

end

DEBUG_LIST1 = true;
% print out a plot, run-by-run
if DEBUG_LIST1
    %figure; hold all;
    for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	list1_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);
    
    list1_classifier_values = [results.iterations.acts(1,list1_trs)];

    plot(list1_classifier_values);
    pause(1.5)
    end
end

DEBUG_ENTIRE_LIST = true;
% print out a plot, run-by-run
if DEBUG_ENTIRE_LIST
    %figure; hold all;
    for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	%list_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);
    list_trs = run_TRs;
    
    list_classifier_values = [results.iterations.acts(1,list_trs)];

    plot(list_classifier_values);
    pause(1.5)
    end
end


%end


