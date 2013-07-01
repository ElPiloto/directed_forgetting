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
SUBJECT='061213_DFFR_0';
num_regressor_values = size(runs(1).regressors,1);

assert(strcmpi(SUBJECT,subject));

% handle run specific things here: there hsould be a .csv or xls file that specifies that changes we're making for this subject
% demarcating thigns to do for each individual run so that it is clearer even though we could have handled cases 3,7-12 with a single swithc statement
for run = 1 : length(runs)
	if (run >= 1 && run <= 3) || (run >= 5 && run <= 7) || run == 9 % this should correspond to (9-11 or 13-15)-1-1epilistblock OR 17-epiwordlocalizer and we want to add the last TR of the regressors list

		% decrease number of TRs
		runs(run).num_TRs = runs(run).num_TRs - 1;
		% remove an entry from regressors matrix
		runs(run).regressors(:,end) = [];

	end

	if run == 11 % this should correspond to 19-1-1epiimage and we want to add a single, all-zeros TR to the regressors list
		% increase number of TRs
		runs(run).num_TRs = runs(run).num_TRs + 1;
		% add value to regressors matrix
		runs(run).regressors(:,end+1) = zeros(num_regressor_values,1);
	end

end


end
