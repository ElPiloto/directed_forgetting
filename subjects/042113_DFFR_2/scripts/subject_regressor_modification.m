function [ runs ] = subject_regressor_modification( runs, subject, varargin )
% [ runs ] = SUBJECT_REGRESSOR_MODIFICATION(runs, varargin)
% Purpose
% 
% Each subject has a separate copy of this function that is catered to the idiosyncracies of their dataset
%
% INPUT
%
% runs - the output of parsing the session log
% varargin - "session_log_file" but this probably won't be used
%
% OUTPUT
% 
% runs - modified runs file
%
% EXAMPLE USAGE:
%
% 
% subject_regressor_modification(runs)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% every version of this file should contain this line so that we never lose track of the intended subject
SUBJECT='042113_DFFR_2';
num_regressor_values = size(runs(1).regressors,1);

assert(strcmpi(SUBJECT,subject));

% handle run specific things here: there hsould be a .csv or xls file that specifies that changes we're making for this subject
% demarcating thigns to do for each individual run so that it is clearer even though we could have handled cases 3,7-12 with a single swithc statement
% GETTING SLIGHTLY LESS PEDANTIC ABOUT DOCUMENTING EVERYTHING SO I'VE LUMPED THINGS TOGETHER
for run = 1 : length(runs)
	if (run >= 2 && run <= 11) || run == 15 % this should correspond to (6 through 15)-1-1epilistblock OR 19-epiimagelocalizer and we want to add a single, all-zeros TR to the regressors list
		% increase number of TRs
		runs(run).num_TRs = runs(run).num_TRs + 1;
		% add value to regressors matrix
		runs(run).regressors(:,end+1) = zeros(num_regressor_values,1);
	end

	if run == 13 || run == 14 % this shoud correspond to (17 or 18 epi word localizer and we want to remove the last TR
		runs(run).regressors = runs(run).regressors(:,1:end-1);
		runs(run).num_TRs = runs(run).num_TRs - 1;
		% just make sure we did what we think we done did
		assert(runs(run).num_TRs == size(runs(run).regressors,2));
	end
end


end
