function [ subjects ] = list_subjects(  )
% [ subjects ] = LIST_SUBJECTS()
% Purpose
% 
% This function will return a cell array where each entry correspond to the subject id,
% as found in the neuropipe/subjects directory
%
% INPUT
%
% 
%
% OUTPUT
% 
% 
%
% EXAMPLE USAGE:
%
% 
% subjects = list_subjects()
%     {'042013_DFFR_0' '042113_DFFR_0' '042113_DFFR_1' '042113_DFFR_2'};
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NEUROPIPE_SUBJ_DIR = '/jukebox/norman/lpiloto/workspace/MATLAB/DF/scripts/neuropipe/subjects/';

subject_dir= dir(NEUROPIPE_SUBJ_DIR);
subjects = cell(1,0);

for subj_dir_idx = 1 : numel(subject_dir)
	subj_dir= subject_dir(subj_dir_idx);
	if ~strcmp(subj_dir.name,'.') && ~strcmp(subj_dir.name,'..')
		subjects{end+1} = subj_dir.name;
	end
end


end
