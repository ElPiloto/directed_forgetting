subj_id = '042113_DFFR_1';
neuropipe_subj_dir = ['/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/' subj_id '/'];
IMG_LOCALIZER_RUN_NUMBER = 15;
varargin = {};
TR_LENGTH = 2.0;

defaults.exp_name = 'directed_forgetting';
defaults.nifti_dir = fullfile(neuropipe_subj_dir,'data','nifti');
%defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','ALL_RUNS.feat/');
defaults.feat_dir = fullfile(neuropipe_subj_dir,'analysis','firstlevel','IMG_LOCALIZERS.feat/');
defaults.data_dir = fullfile(neuropipe_subj_dir,'data');
defaults.regressor_output_dir = fullfile(defaults.data_dir,'regressors');
defaults.session_log_file = fullfile(neuropipe_subj_dir,'data','session_info','log.txt');
defaults.output_dir = fullfile(neuropipe_subj_dir,'data','mvpa_results');

options = parsepropval(defaults,varargin{:});

% here we hard-code some values which should be self-explanatory. it is quite likely
% that we will want to change some of these values into parameters
global IMG_LOCALIZER_IDCS; IMG_LOCALIZER_IDCS = [11 12 13];
img_localizer_names = {'scenes' 'objects' 'scrambled_scenes'};



% here we load run information - useful for creating our run selector and
% our regressors 
[runs] = parse_session_log('session_log_file',options.session_log_file);
% here we make any subject specific modifications to the regressors struct we created from the session log
runs = subject_regressor_modification(runs,subj_id);
% here we only grab the image localizer run
runs = runs(IMG_LOCALIZER_RUN_NUMBER);

img_localizer_regressors = get_img_localizer_regressors_and_concatenate(runs,IMG_LOCALIZER_IDCS);

num_regressors = size(img_localizer_regressors,1);
num_TRs = size(img_localizer_regressors,2);

% make sure that our regressors folder actually exists
if ~exist(options.regressor_output_dir,'dir')
	display(['Making directory: ' options.regressor_output_dir ' because it doesn''t exist']);
	mkdir(options.regressor_output_dir);
end

for regressor_idx = 1 : num_regressors
	start_time = 0.0;
	% our file will be saved to somwething like subject_dir/data/regressors/scenes.txt
	regressor_file = fullfile(options.regressor_output_dir,[img_localizer_names{regressor_idx} '.txt']);
	fid = fopen(regressor_file, 'w');
	for TR_idx = 1 : num_TRs
		if img_localizer_regressors(regressor_idx,TR_idx)
			% FSL/FEAT format is onset time, duration, 1 per line
			fprintf(fid,'%s %s 1\n',num2str(start_time),num2str(TR_LENGTH));
		end
		start_time = start_time + TR_LENGTH;
	end
	fclose(fid);
	display(['Completed writing out regressors to ' regressor_file]);
end


