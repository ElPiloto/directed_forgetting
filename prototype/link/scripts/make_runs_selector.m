function [runs_selector, specific_runs_only_selector] = make_runs_selector(runs,run_numbers_to_make_specific_selector)

    runs_selector = [];
	specific_runs_only_selector = [];
    for run_idx = 1 : numel(runs)
        runs_selector = [runs_selector repmat(run_idx,1,runs(run_idx).num_TRs)];
		if any(run_numbers_to_make_specific_selector == run_idx)
        	specific_runs_only_selector = [specific_runs_only_selector zeros(1,runs(run_idx).num_TRs_delete) ones(1,runs(run_idx).num_TRs-runs(run_idx).num_TRs_delete)];
		else
        	specific_runs_only_selector = [specific_runs_only_selector zeros(1,runs(run_idx).num_TRs)];
		end
    end
end


