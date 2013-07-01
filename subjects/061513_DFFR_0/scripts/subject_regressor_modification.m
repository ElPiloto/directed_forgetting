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
SUBJECT='061513_DFFR_0';
num_regressor_values = size(runs(1).regressors,1);

assert(strcmpi(SUBJECT,subject));

% handle run specific things here: there hsould be a .csv or xls file that specifies that changes we're making for this subject
% demarcating thigns to do for each individual run so that it is clearer even though we could have handled cases 3,7-12 with a single swithc statement
for run = 1 : length(runs)
	if (run >= 1 && run <= 4) || run == 9 || run == 10 % this should correspond to (5-8)-1-1epilistblock OR (13-14)-1-1epiuwordlocalizer and we want to remove the last TR

		% decrease number of TRs
		runs(run).num_TRs = runs(run).num_TRs - 1;
		% remove an entry from regressors matrix
		runs(run).regressors(:,end) = [];

	end

	if run == 5 % this should correspond to 9-1-1epilistblock and we want to remove two TRs from the regressors
		% decrease number of TRs
		runs(run).num_TRs = runs(run).num_TRs - 2;
		% remove an entry from regressors matrix
		runs(run).regressors(:,end-1:end) = [];

	end

	if run == 11 % this should correspond to 15-1-1epiimagelocalizer and we want to add a two all-zeros TRs to the regressors list
		% increase number of TRs
		runs(run).num_TRs = runs(run).num_TRs + 2;
		% add value to regressors matrix
		runs(run).regressors(:,end+1:end+2) = zeros(num_regressor_values,2);
	end
	
end


end
