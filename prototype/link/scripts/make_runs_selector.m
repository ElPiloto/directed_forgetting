function [runs_selector] = make_runs_selector(runs)
    runs_selector = [];
    for run_idx = 1 : numel(runs)
        runs_selector = [runs_selector repmat(run_idx,1,runs(run_idx).num_TRs)];
    end
end


