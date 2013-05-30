function [runs_selector, localizer_runs_only_selector] = make_runs_selector(runs)

	localizer_runs = [1];
    runs_selector = [];
	localizer_runs_only_selector = [];
    for run_idx = 1 : numel(runs)
        runs_selector = [runs_selector repmat(run_idx,1,runs(run_idx).num_TRs)];
		if any(localizer_runs == run_idx)
        	localizer_runs_only_selector = [localizer_runs_only_selector zeros(1,runs(run_idx).num_TRs_delete) ones(1,runs(run_idx).num_TRs-runs(run_idx).num_TRs_delete)];
		else
        	localizer_runs_only_selector = [localizer_runs_only_selector zeros(1,runs(run_idx).num_TRs)];
		end
    end
end


