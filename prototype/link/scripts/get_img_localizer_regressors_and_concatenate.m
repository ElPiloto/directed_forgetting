function [regressors] = get_img_localizer_regressors_and_concatenate(runs)
    global IMG_LOCALIZER_IDCS;
    temp_all_runs = [runs.regressors];
    regressors = temp_all_runs(IMG_LOCALIZER_IDCS,:);
end


