function [  ] = run_classifier_word_lists( varargin )
% [  ] = RUN_CROSS_VALIDATION(varargin)
% Purpose
% 
% This function will run cross-validation
%
% INPUT
%
% classifier type
%
% OUTPUT
% 
% 
%
% EXAMPLE USAGE:
%
% 
% run_cross_validation('classifier','train_logreg')
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expm_settings;

% TODO: Add function that lists subjects
%subjects = {'042013_DFFR_0' '042113_DFFR_0' '042113_DFFR_1' '042113_DFFR_2'};
subjects = list_subjects();
subjects = {'061213_DFFR_0' '061313_DFFR_0'  '061513_DFFR_0'  '061913_DFFR_0'};
%subjects = {'061513_DFFR_0'};
regularization_values = [ 10 1];
%feature_selection_thresholds = [ 0.0000000005 0.00000005 0.00005];
feature_selection_thresholds = [ 0.00005 0.0005];
subjects_dir = '/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/%s/';
subjects_script_dir = '/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/%s/scripts';

params.feat_dir = 'ALL_RUNS.feat/';
params.mask_filename = 'temporal_occipital_mask_transformed_brain_extracted.nii';
params.classifier_fn_name = 'train_logreg';
params.feature_select_fn_name = 'statmap_anova';

all_cv_accuracy_results = zeros(numel(subjects),numel(feature_selection_thresholds),numel(regularization_values));

for subject_idx = 1:numel(subjects)
	params.subject = subjects{subject_idx};

	subject_dir = sprintf(subjects_dir,params.subject);
	subject_script_dir = sprintf(subjects_script_dir,params.subject);

	% switch to subject's script directory so we're running the correct matlab scripts
	old_dir = pwd;
	cd(subject_script_dir);
	addpath(pwd);

	for feature_select_thresh_idx = 1 : numel(feature_selection_thresholds)
		params.feature_select_thresh = feature_selection_thresholds(feature_select_thresh_idx);

		for regularization_value_idx = 1 : numel(regularization_values)

			%try
			params.regularization_value = regularization_values(regularization_value_idx);

			class_args.train_funct_name = params.classifier_fn_name;
			class_args.test_funct_name = strrep(params.classifier_fn_name,'train','test');
			class_args.penalty = params.regularization_value;

	 		calling_fn_info = expmt.funcs('run_classifier_word_lists.m');
			sorted_params = get_sorted_params_list(expmt,calling_fn_info.params);

			params_specific_path = convert_params_to_path(expmt, params, sorted_params);
			params_specific_path = fullfile(expmt.data_dir,'run_classifier_word_lists.m',params_specific_path);
			[output.results, output.forget_trs_means, output.remember_trs_means, output.list1_trs_means, output.list2_trs_means,output.all_forget_trs,output.all_remember_trs,output.all_list1_trs] = ...
			   	train_localizer_test_listblocks(params.subject,subject_dir,params_specific_path,'class_args',class_args,'feature_select_thresh',params.feature_select_thresh,'feat_dir',fullfile(subject_dir,'analysis','firstlevel',params.feat_dir),'mask_filename',params.mask_filename);
			[saved_filename] = expm_save_output(expmt,output,params);
			display(['Completed writing output to: ' saved_filename]);
% 			catch err
% 				disp(['Failed for subject: ' params.subject ' because:\n\t' err.message]);
% 			end
		end
	end

	% return to original directory
	cd(old_dir);
end




% output.wavelet_eeg = [1];
% [saved_filename] = expm_save_output(expmt, output,params);


end
