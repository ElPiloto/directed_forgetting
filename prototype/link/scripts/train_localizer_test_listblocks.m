%function [  ] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, data_dir, nifti_dir, feat_output_dir, session_log_file, varargin )
function [ results, forget_trs_means, remember_trs_means, list1_trs_means, list2_trs_means,all_forget_trs,all_remember_trs,all_list1_trs] = mvpa_test_localizer( subj_id, neuropipe_subj_dir, plots_save_dir, varargin )
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
IMG_LOCALIZER_RUN_NUMBER = get_subj_specific_img_localizer_run_idx;
%varargin = {};


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
defaults.mask_filename = 'temporal_occipital_mask_transformed_brain_extracted.nii';
defaults.feature_select_thresh = 0.0005;

options = parsepropval(defaults,varargin{:});

% TODO: generate outputs for lists, 
% 
% here we hard-code some values which should be self-explanatory. IT IS QUITE LIKELY
% THAT WE WILL WANT TO CHANGE SOME OF THESE VALUES INTO PARAMETERS
% MASK_NAME = 'WHOLE_BRAIN';
% options.mask_filename = 'mask.nii';
% MASK_NIFTI_FILE = fullfile(options.feat_dir,options.mask_filename);
%options.feature_select_thresh = 0.001;
%options.feature_select_thresh = 0.0005; ~ 3500
%options.feature_select_thresh = 0.0000005; ~ 2700
%options.feature_select_thresh = 0.0000000005; ~ 900
%options.feature_select_thresh = 0.000000000005; ~ 367 voxels
%options.feature_select_thresh = 0.000000000005;
MASK_NAME = 'TEMPORAL_OCCIPITAL';
options.mask_filename = 'temporal_occipital_mask_transformed.nii';
MASK_NIFTI_FILE = fullfile(options.feat_dir,options.mask_filename);
%EPI_NAME = 'EPI';
EPI_NAME = ['ALL_RUNS_' MASK_NAME '_MASKED'];
EPI_NIFTI_FILENAME = 'filtered_func_data.nii';
EPI_NIFTI_FILE = fullfile(options.feat_dir,EPI_NIFTI_FILENAME);
NUM_TRS_SHIFT = 2;
%NUM_BLOCK1_TRS = 12; % this is the number of list pair presentations we have
NUM_BLOCK1_TRS = get_subj_specific_num_listblocks(); % this is the number of list pair presentations we have
SUBJECT_MAT_SAVE_FILE = fullfile(options.output_dir,'subject.mat');

% the next few lines refer to what rows in our regressor matrix correspond to which conditions
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [12 13 14];
global PRESENT_LIST1_IDX; PRESENT_LIST1_IDX = [1];
global PRESENT_LIST2_IDX_FORGET_LIST1; PRESENT_LIST2_IDX_FORGET_LIST1 = [2];
global PRESENT_LIST2_IDX_REMEMBER_LIST1; PRESENT_LIST2_IDX_REMEMBER_LIST1 = [3];
global RECALL_LIST1_IDX; RECALL_LIST1_IDX = [4];
global RECALL_LIST2_REMEMBER_LIST1_IDX; RECALL_LIST2_REMEMBER_LIST1_IDX = [5];
global RECALL_LIST2_FORGET_LIST1_IDX; RECALL_LIST2_FORGET_LIST1_IDX = [6];

% the two extra tildes are to convert to logical from scalar result of exist fn
if ~~~exist(options.output_dir,'dir')
	mkdir(options.output_dir);
end

% init subject
if exist(SUBJECT_MAT_SAVE_FILE,'file')
	try
		load(SUBJECT_MAT_SAVE_FILE);
	catch
	end
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
regressors_suffix = [num2str(IMG_LOCALIZER_IDCS(1)) '_' num2str(IMG_LOCALIZER_IDCS(2)) '_' num2str(IMG_LOCALIZER_IDCS(3))];

shifted_regressors_name = ['runs_shift' num2str(NUM_TRS_SHIFT) '_all_runs_' regressors_suffix];
if ~exist_object(subj,'regressors',shifted_regressors_name)
	% here we load run information - useful for creating our run selector and
	% our regressors 
	[runs] = parse_session_log('session_log_file',options.session_log_file);
	% here we make any subject specific modifications to the regressors struct we created from the session log
	runs = subject_regressor_modification(runs,subj_id);

	cond_all_runs_regressors = ['conds_all_runs_' regressors_suffix];
	% initialize our regressors
	subj = init_object(subj,'regressors',cond_all_runs_regressors);
	subj = set_mat(subj,'regressors',cond_all_runs_regressors,get_img_localizer_regressors_and_concatenate(runs,IMG_LOCALIZER_IDCS));

	% make a selector to indicate which runs each TR belongs to as well as make a single localizer
	% that specifies which runs are for the localizer
	[runs_selector, localizer_only_selector] = make_runs_selector(runs,IMG_LOCALIZER_RUN_NUMBER);

	% initialize our run selector
	subj = init_object(subj,'selector','runs_all_runs')
	subj = set_mat(subj,'selector','runs_all_runs',runs_selector);

	subj = init_object(subj,'selector','localizer_runs_only_all_runs');
	subj = set_mat(subj,'selector','localizer_runs_only_all_runs',localizer_only_selector);

	%shift our regressors
	subj = shift_regressors(subj,cond_all_runs_regressors,'runs_all_runs', NUM_TRS_SHIFT,'new_regsname',shifted_regressors_name);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
selector_name = ['train_localizer_test_all_other_TRs_' regressors_suffix];
if ~exist_group(subj,'selector',selector_name)
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
	subj = initset_object(subj,'selector',[selector_name '_1'],train_localizer_test_all_other_TRs_selector,...
				'group_name',selector_name);
end

if ~exist_object(subj,'pattern',EPI_NAME)
	% load up our EPI
	unzip_nifti_file_if_necessary(EPI_NIFTI_FILE);
	subj = load_spm_pattern(subj, EPI_NAME, MASK_NAME, EPI_NIFTI_FILE);
end

if ~exist_object(subj,'pattern',[EPI_NAME '_z'])
	% zscore our data
	subj = zscore_runs(subj,EPI_NAME,'runs_all_runs');
end


% we can get rid of our initial pattern now
thresholded_mask_feature_select_group_name = [EPI_NAME '_z_' regressors_suffix '_thresh'];
full_thresholded_mask_feature_select_group_name = [thresholded_mask_feature_select_group_name num2str(options.feature_select_thresh)];
threshold_pattern_feature_select_group_name = [EPI_NAME '_z_' regressors_suffix '_anova'];

if ~exist_group(subj,'mask',full_thresholded_mask_feature_select_group_name)
% feature selection
	if ~exist_group(subj,'pattern',threshold_pattern_feature_select_group_name)
		subj = feature_select(subj,[EPI_NAME '_z'],shifted_regressors_name,selector_name,'thresh',options.feature_select_thresh, ...
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
% finally, we actually do cross-validation
[subj results] = cross_validation(subj,[EPI_NAME '_z'],shifted_regressors_name,selector_name,full_thresholded_mask_feature_select_group_name,options.class_args);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% here we create a regressor, shift it, then select the time points of interest on a run-by-run basis
% add regressor containing all regressors (as opposed to truncated regressors that only had image localizer)
all_regressors = [runs.regressors];
subj = initset_object(subj,'regressors','all_regressors',all_regressors);
% now shift our regressors
shifted_all_regressors_name = ['all_runs_shift' num2str(NUM_TRS_SHIFT)];
subj = shift_regressors(subj,'all_regressors','runs_all_runs', NUM_TRS_SHIFT,'new_regsname',shifted_all_regressors_name);

% grab list 2 - forget list 1
shifted_all_regressors = get_mat(subj,'regressors',shifted_all_regressors_name);
trs_of_interest = find(shifted_all_regressors(RECALL_LIST2_FORGET_LIST1_IDX,:));

% plot run by run
figure('Visible','Off'); hold all;

set(gcf, 'Position', get(0,'Screensize'));

all_list1_trs = cell(0,1);
all_forget_trs = cell(0,1);
all_remember_trs = cell(0,1);

forget_trs_means = [];
remember_trs_means = [];
list1_trs_means = [];
list2_trs_means = [];
for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	forget_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_FORGET_LIST1,:)),run_TRs);
	remember_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_REMEMBER_LIST1,:)),run_TRs);
	list1_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);

    forget_classifier_values = [results.iterations.acts(1,forget_trs)];
    remember_classifier_values = [results.iterations.acts(1,remember_trs)];
    list1_classifier_values = [results.iterations.acts(1,list1_trs)];
    if ~isempty(list1_classifier_values)
        subplot(3,1,1);
        hold all;
        plot(list1_classifier_values,'-o','LineWidth',2);
        title(['List 1:' num2str(mean(list1_classifier_values))]);
        disp(['List 1:' num2str(mean(list1_classifier_values))]);
		list1_trs_means(end+1) = mean(list1_classifier_values);
		all_list1_trs{ end+1 } = list1_classifier_values;
    end

	if ~isempty(forget_classifier_values)
        subplot(3,1,2);
        hold all;
        plot(forget_classifier_values,'-o','LineWidth',2);
        title(['Forget:' num2str(mean(forget_classifier_values))]);
        disp(['Forget:' num2str(mean(forget_classifier_values))]);
		forget_trs_means(end+1) = mean(forget_classifier_values);
		list2_trs_means(end+1) = mean(forget_classifier_values);
		all_forget_trs{end+1} = forget_classifier_values;
    end

    if ~isempty(remember_classifier_values)
        subplot(3,1,3); hold all;
        plot(remember_classifier_values,'-o','LineWidth',2);
        title(['Remember:' num2str(mean(remember_classifier_values))]);
        disp(['Remember:' num2str(mean(remember_classifier_values))]);
		remember_trs_means(end+1) = mean(remember_classifier_values);
		list2_trs_means(end+1) = mean(remember_classifier_values);
		all_remember_trs{end+1} = remember_classifier_values;
    end

end
% plot means
subplot(3,1,1);
title(['List 1:' num2str(mean(list1_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier readout');

subplot(3,1,2);
title(['Forget:' num2str(mean(forget_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier readout');

subplot(3,1,3);
title(['Remember:' num2str(mean(remember_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier readout');
			
if ~exist(plots_save_dir,'dir')
	mkdir(plots_save_dir);
end

saveas(gcf, fullfile(plots_save_dir,'list1_vs_list2.png'), 'png');
disp(['Saved plot at: ' fullfile(plots_save_dir,'list1_vs_list2.png')]);
close(gcf);

%%%%%%%%%%%%%%%%%%%%%%%%%%%% here we plot scene - object

% plot run by run
figure('Visible','Off'); hold all;

set(gcf, 'Position', get(0,'Screensize'));

all_list1_trs = cell(0,1);
all_forget_trs = cell(0,1);
all_remember_trs = cell(0,1);

forget_trs_means = [];
remember_trs_means = [];
list1_trs_means = [];
list2_trs_means = [];
for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	forget_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_FORGET_LIST1,:)),run_TRs);
	remember_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_REMEMBER_LIST1,:)),run_TRs);
	list1_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);

    forget_classifier_values = [results.iterations.acts(1,forget_trs)] - [results.iterations.acts(2,forget_trs)];
    remember_classifier_values = [results.iterations.acts(1,remember_trs)] - [results.iterations.acts(2,remember_trs)];
    list1_classifier_values = [results.iterations.acts(1,list1_trs)] - [results.iterations.acts(2,list1_trs)];
    if ~isempty(list1_classifier_values)
        subplot(3,1,1);
        hold all;
        plot(list1_classifier_values,'-o','LineWidth',2);
        title(['List 1:' num2str(mean(list1_classifier_values))]);
        disp(['List 1:' num2str(mean(list1_classifier_values))]);
		list1_trs_means(end+1) = mean(list1_classifier_values);
		all_list1_trs{ end+1 } = list1_classifier_values;
    end

	if ~isempty(forget_classifier_values)
        subplot(3,1,2);
        hold all;
        plot(forget_classifier_values,'-o','LineWidth',2);
        title(['Forget:' num2str(mean(forget_classifier_values))]);
        disp(['Forget:' num2str(mean(forget_classifier_values))]);
		forget_trs_means(end+1) = mean(forget_classifier_values);
		list2_trs_means(end+1) = mean(forget_classifier_values);
		all_forget_trs{end+1} = forget_classifier_values;
    end

    if ~isempty(remember_classifier_values)
        subplot(3,1,3); hold all;
        plot(remember_classifier_values,'-o','LineWidth',2);
        title(['Remember:' num2str(mean(remember_classifier_values))]);
        disp(['Remember:' num2str(mean(remember_classifier_values))]);
		remember_trs_means(end+1) = mean(remember_classifier_values);
		list2_trs_means(end+1) = mean(remember_classifier_values);
		all_remember_trs{end+1} = remember_classifier_values;
    end

end
% plot means
subplot(3,1,1);
title(['List 1:' num2str(mean(list1_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Objects classifier readout');

subplot(3,1,2);
title(['Forget:' num2str(mean(forget_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Objects classifier readout');

subplot(3,1,3);
title(['Remember:' num2str(mean(remember_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Objects classifier readout');
			
if ~exist(plots_save_dir,'dir')
	mkdir(plots_save_dir);
end

saveas(gcf, fullfile(plots_save_dir,'list1_vs_list2_scene_minus_obj.png'), 'png');
disp(['Saved plot at: ' fullfile(plots_save_dir,'list1_vs_list2_scene_minus_obj.png')]);
close(gcf);

%%%%%%%% here we plot scene minus scrambled

% plot run by run
figure('Visible','Off'); hold all;

set(gcf, 'Position', get(0,'Screensize'));

all_list1_trs = cell(0,1);
all_forget_trs = cell(0,1);
all_remember_trs = cell(0,1);

forget_trs_means = [];
remember_trs_means = [];
list1_trs_means = [];
list2_trs_means = [];
for run = 1 : NUM_BLOCK1_TRS
	run_TRs = find(runs_selector == run);
	forget_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_FORGET_LIST1,:)),run_TRs);
	remember_trs = intersect(find(shifted_all_regressors(PRESENT_LIST2_IDX_REMEMBER_LIST1,:)),run_TRs);
	list1_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);

    forget_classifier_values = [results.iterations.acts(1,forget_trs)] - [results.iterations.acts(3,forget_trs)];
    remember_classifier_values = [results.iterations.acts(1,remember_trs)] - [results.iterations.acts(3,remember_trs)];
    list1_classifier_values = [results.iterations.acts(1,list1_trs)] - [results.iterations.acts(3,list1_trs)];
    if ~isempty(list1_classifier_values)
        subplot(3,1,1);
        hold all;
        plot(list1_classifier_values,'-o','LineWidth',2);
        title(['List 1:' num2str(mean(list1_classifier_values))]);
        disp(['List 1:' num2str(mean(list1_classifier_values))]);
		list1_trs_means(end+1) = mean(list1_classifier_values);
		all_list1_trs{ end+1 } = list1_classifier_values;
    end

	if ~isempty(forget_classifier_values)
        subplot(3,1,2);
        hold all;
        plot(forget_classifier_values,'-o','LineWidth',2);
        title(['Forget:' num2str(mean(forget_classifier_values))]);
        disp(['Forget:' num2str(mean(forget_classifier_values))]);
		forget_trs_means(end+1) = mean(forget_classifier_values);
		list2_trs_means(end+1) = mean(forget_classifier_values);
		all_forget_trs{end+1} = forget_classifier_values;
    end

    if ~isempty(remember_classifier_values)
        subplot(3,1,3); hold all;
        plot(remember_classifier_values,'-o','LineWidth',2);
        title(['Remember:' num2str(mean(remember_classifier_values))]);
        disp(['Remember:' num2str(mean(remember_classifier_values))]);
		remember_trs_means(end+1) = mean(remember_classifier_values);
		list2_trs_means(end+1) = mean(remember_classifier_values);
		all_remember_trs{end+1} = remember_classifier_values;
    end

end
% plot means
subplot(3,1,1);
title(['List 1:' num2str(mean(list1_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Scrambled Scene classifier readout');

subplot(3,1,2);
title(['Forget:' num2str(mean(forget_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Scrambled Scene classifier readout');

subplot(3,1,3);
title(['Remember:' num2str(mean(remember_trs_means))]);
ylim([0 1]);
xlabel('TRs');
ylabel('Scene classifier minus Scrambled Scene classifier readout');
			
if ~exist(plots_save_dir,'dir')
	mkdir(plots_save_dir);
end

saveas(gcf, fullfile(plots_save_dir,'list1_vs_list2_scene_minus_scrambled_scene.png'), 'png');
disp(['Saved plot at: ' fullfile(plots_save_dir,'list1_vs_list2_scene_minus_scrambled_scene.png')]);
close(gcf);



















 % DEBUG_LIST1 = true;
 % % print out a plot, run-by-run
 % if DEBUG_LIST1
 % 	list1_trs_means = [];
 % 	list2_trs_means = [];
 %     %figure; hold all;
 %     for run = 1 : NUM_BLOCK1_TRS
 % 		run_TRs = find(runs_selector == run);
 % 		list1_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);
 % 		% we don't have a single list2 regressor (we split them up previously)
 % 		list2_trs = union(find(shifted_all_regressors(PRESENT_LIST2_IDX_FORGET_LIST1,:)), find(shifted_all_regressors(PRESENT_LIST2_IDX_REMEMBER_LIST1,:)));
 % 		list2_trs = intersect(list2_trs,run_TRs);
 % 
 % 		list1_classifier_values = [results.iterations.acts(1,list1_trs)];
 % 		list1_trs_means(end+1) = mean(list1_classifier_values);
 % 
 % 		list2_classifier_values = [results.iterations.acts(1,list2_trs)];
 % 		list2_trs_means(end+1) = mean(list2_classifier_values);
 % 
 % 		plot(list1_classifier_values);
 % 		pause(1.5)
 %     end
 % end
 % 
 % DEBUG_ENTIRE_LIST = true;
 % % print out a plot, run-by-run
 % if DEBUG_ENTIRE_LIST
 %     %figure; hold all;
 %     for run = 1 : NUM_BLOCK1_TRS
 % 	run_TRs = find(runs_selector == run);
 % 	%list_trs = intersect(find(shifted_all_regressors(PRESENT_LIST1_IDX,:)),run_TRs);
 %     list_trs = run_TRs;
 %     
 %     list_classifier_values = [results.iterations.acts(1,list_trs)];
 % 
 %     plot(list_classifier_values);
 %     pause(1.5)
 %     end
 % end


%end


