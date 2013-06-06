% this 
subj_id = '042013_DFFR_0';
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

EPI_NIFTI_FILENAME = 'filtered_func_data.nii';

% here we load run information - useful for creating our run selector and
% our regressors 
[runs] = parse_session_log('session_log_file',options.session_log_file);
% here we make any subject specific modifications to the regressors struct we created from the session log
runs = subject_regressor_modification(runs,subj_id);

old_dir = pwd;


% at this point, our runs vector should only contain runs we care about. should have the correct number of TRs
% and should be in the correct order.  We will now make sure the file exists, ensure the number of TRs match, and split the pre-processed file.
% TODO: we could add a unit_test here that looks at the run-order.txt file for a particular subject and makes sure our runs struct matches the actual volumes on a per run basis
% but in the meantime we'll do a simple check where we verify that the total number of volumes in the fsl preprocessed file matches the total number of TRs we have
% in our runs structure
% TODO: Make "idimpotent" - only make run files if they don't already exist
% TESTS
cd(options.feat_dir);
unzip_nifti_file_if_necessary(EPI_NIFTI_FILENAME);
assert((~~exist(EPI_NIFTI_FILENAME,'file'))); % the ~~ converts from a numeric value to a logical (mapping anyhing not zero to true)
[~,num_TRs_in_nifti_file] = unix(['fslinfo ' EPI_NIFTI_FILENAME ' | grep ''^dim4.*[0-9]*$'' | sed ''s/dim4\s*\([0-9]\)/\1/g''']);
num_TRs_in_nifti_file = str2num(num_TRs_in_nifti_file);
num_TRs_in_runs_struct = sum([runs.num_TRs]);
assert(num_TRs_in_nifti_file == num_TRs_in_runs_struct);
% now actually do splitting up
% this will keep track of how many TRs we've consumed
TR_start_idx = 0; % TRs/Volumes in FSL are zero-indexed
for run = 1 : numel(runs)
	run_length = runs(run).num_TRs;
	output_file_name = ['filtered_func_run_' num2str(run)];

	% put it all together to use unix command + fslroi to split up the file
	split_file_cmd = ['fslroi ' EPI_NIFTI_FILENAME ' ' output_file_name ' ' num2str(TR_start_idx) ' ' num2str(run_length)];

	[failed] = unix(split_file_cmd);

	% we can't continue if we've failed
	if failed
		error(['Couldn''t split run #' num2str(run)]);
	else
		TR_start_idx = TR_start_idx + run_length;
	end
end

disp(['Successfully split file' EPI_NIFTI_FILENAME ' into the following runs']);

ls('filtered_func_run_*');

cd(old_dir);
