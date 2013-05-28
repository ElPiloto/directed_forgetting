% this function will unzip any files we need
function [ ] = unzip_nifti_file_if_necessary(nifti_file)
if ~exist(nifti_file,'file')
	gzipped_file = [nifti_file '.gz'];
	if exist(gzipped_file,'file')
						current_dir = pwd;
		path_to_nifti = fileparts(gzipped_file);
										   
				if ~isempty(path_to_nifti)
		unix(['cd ' path_to_nifti]);
									end

		unix(['gunzip ' gzipped_file ]);

		if ~isempty(path_to_niftiti)
		unix(['cd ' current_dir]);
		end
	else
		error(['Tried to maxvalke sure we had an unzipped version of file: ' nifti_file ', but we couldn''t even find the zipped version of it!!!']);
	end
end

end
