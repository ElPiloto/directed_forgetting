function [bootleg_runs, ITI_timepts, num_blocks, block_lengths, block_starts ] = make_bootleg_runs_xvalid_img_localizer( TR_shifted_regressors )
% [bootleg_runs, ITI_timepts, num_blocks, block_lengths, block_starts ] = MAKE_BOOTLEG_RUNS_XVALID_IMG_LOCALIZER(TR_shifted_regressors)
% Purpose
% 
% This function is used to convert a single run into multiple runs.  Specifically, we identify blocks of regressor presentations, then 
% create as many runs as possible where each run contains a block from all regressors.  Additionally, we create a list of all TRs that 
% don't belong to any condition.  Those TRs are saved in output: ITI_timepts and receive a value of 1 in the newly created runs matrix
% because the MVPA toolbox complains if you give it a runs selector that has zeros in it.
%
% INPUT
%
% Description of inputs
%
% OUTPUT
% 
% Description of outputs
%
% EXAMPLE USAGE:
%
% 
% make_bootleg_runs_xvalid_img_localizer(Example inputs)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% number of regressor values
num_regressors = size(TR_shifted_regressors,1);
num_TRs = size(TR_shifted_regressors,2);

% here we get the number of blocks for each condition using run-length encoding on the regressors matrix
num_blocks = zeros(num_regressors,1);
block_starts = cell(num_regressors,1);
block_lengths = cell(num_regressors,1);
% this code is annoyingly terse, SORRY future self or others
for regressor = 1:num_regressors
	temp_rle = rle(TR_shifted_regressors(regressor,:));
	num_blocks(regressor) = sum(temp_rle{1});
	block_lengths{ regressor } = temp_rle{2}(find(temp_rle{1}));

	cumsum_tmp = cumsum(temp_rle{2});
	block_starts{ regressor } = cumsum_tmp(find(temp_rle{1}) - 1) + 1;
end

bootleg_runs = zeros(1,num_TRs);
% we do this so that we use the minimum number of blocks that include all possible regressor values
num_runs_to_make = min(num_blocks);

for run = 1 : num_runs_to_make
	for regressor = 1 : num_regressors
		start_idx = block_starts{regressor}(run);
		end_idx = start_idx + block_lengths{regressor}(run) - 1;
		bootleg_runs(start_idx:end_idx) = run;
	end

end

% one last thing: take all zero entries and append them to the first run so that mvpa toolbox doesn't complain - they should be getting filtered out anyway
% and record those zero entries so we can exclude them from runs later on
ITI_timepts = find(bootleg_runs == 0);
bootleg_runs(find(bootleg_runs == 0)) = 1;
end
