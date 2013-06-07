function [runs] = parse_session_log(varargin)
	%TODO: ADD SPECIFICATION / PLACE FOR SUBJECT
%specify session log file here, will do this more intelligently when there gets to be some structure behind this analysis pipeline
%session_log_file = '../example_code_data/session.log'
defaults.session_log_file  = '../example_code_data/session_042113_DFFR_2.log';
options = parsepropval(defaults, varargin{:});

% this function assumes our localizer sequence of interest is directly preceded by a line in the following format:
% time Instructions ONEBACK_INSTRUCTIONS.txt
LOCALIZER_INDICATOR_STRING = 'ONEBACK_INSTRUCTIONS.txt';

% open our file
fid = fopen(options.session_log_file,'r');

% these will function as enumerated types to indicate what state/block our "parser" thinks it should be in
global BEGIN_EXP; BEGIN_EXP = 0;
global BLOCK0; BLOCK0 = 1;
global BLOCK1; BLOCK1 = 2;
global BLOCK2; BLOCK2 = 3;
global BLOCK3; BLOCK3 = 4;
global STATE; STATE = BEGIN_EXP;

global SUBJECT; SUBJECT ='';
global TR_LENGTH_MSECS; TR_LENGTH_MSECS = 2000;

global DEBUG_FLAG; DEBUG_FLAG = false;

% the global variable below tells us that we've reached the end of BLOCK1 - there is no clean cut transition between the BLOCKS unfortunately
% because the current session file has the following:
% STOP_RECORD 12_0.wav ----correctly part of BLOCK1 parsing, finished parsing the current wordlist block for block 1
% SET_LIST 0  ---------at this point, this is starting off just like any other wordlist block for block 1
% SET LISTBLOCK 13  -----only when we get here do we know that we're no longer in BLOCK 1 and should increment our state counter
% SET BLOCK 2
global MAX_LISTBLOCKS_IN_BLOCK1;MAX_LISTBLOCKS_IN_BLOCK1 = 13; 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DEFINE REGRESSOR VALUES/MAPPINGS HERE
% correspondonce of row to regressor value is specified here to explain code:
% regressor rows correspond to: list 1, list2, and recall TRs respectively
% 1 = block1, present list1
% 2 = block1, present list2, REMEMBER_CUE
% 3 = block1, present list2, FORGET_CUE
% 4 = block1, recall list1 REMEMBER_CUE
% 5 = block1, recall list2 REMEMBER_CUE
% 6 = block1, recall list2 FORGET_CUE
% 7 = block2, present list1
% 8 = block2, recall list1
% 9 = block2, present list2
% 10 = block2, recall list2
% 11 = block3, present scene img
% 12 = block3, present objects img
% 13 = block3, present scambled_scene img

% for each block where we collect scan information BLOCK1 and BLOCK2 we specify a regressor column for the partitcular phase in that particular block
% for example, BLOCK1 starts with WAITING_START_LIST1 and so the first columns of the REGRESSOR_COLUMNS_PER_PHASE_BLOCK1 has all zeros because
% we're not in a scan condition, but when we move to the LIST1 phase which is the next PHASE (and therefore the next column) we have the first row set to 1
% to indicate, as commented above, that we are in the block1, present list1 scan
global REGRESSOR_COLUMNS_PER_PHASE_BLOCK1; REGRESSOR_COLUMNS_PER_PHASE_BLOCK1 = ...
[ 0 0 0 0 0 0 0 0 0 0 0 0 0; ... % phase = WAITING_START_LIST1
1 0 0 0 0 0 0 0 0 0 0 0 0; ... % phase = LIST1
0 0 0 0 0 0 0 0 0 0 0 0 0; ... % phase = WAITING_START_LIST2
0 1 0 0 0 0 0 0 0 0 0 0 0; ... % phase = LIST2 - although in actuality this will get deferred to the values specified by REGRESSOR_COLUMNS_LIST2_BLOCK1
% 0 0 1 0 0 0 0 0 0 0 0 0 0; ... % phase = LIST2
0 0 0 0 0 0 0 0 0 0 0 0 0; ... % phase = WAITING_START_RECALL
0 0 0 1 0 0 0 0 0 0 0 0 0; ... % phase = RECALL - although in actuality this will get deferred to the values specified by REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1
0 0 0 0 0 0 0 0 0 0 0 0 0]'; % phase = FINISHED - i don't think this even gets used, but i should double-check


global REGRESSOR_COLUMNS_PER_PHASE_BLOCK2; REGRESSOR_COLUMNS_PER_PHASE_BLOCK2 = ...
[ 0 0 0 0 0 0 0 0 0 0 0 0 0 ; ... % phase = WAITING_START_LIST1
0 0 0 0 0 0 1 0 0 0 0 0 0 ; ... % phase = LIST1
0 0 0 0 0 0 0 0 0 0 0 0 0 ; ... % phase = WAITING_START_RECALL1
0 0 0 0 0 0 0 1 0 0 0 0 0 ; ... % phase = RECALL1
0 0 0 0 0 0 0 0 0 0 0 0 0 ; ... % phase = WAITING_START_LIST2
0 0 0 0 0 0 0 0 1 0 0 0 0 ; ... % phase = LIST2
0 0 0 0 0 0 0 0 0 0 0 0 0 ; ... % phase = WAITING_START_RECALL2
0 0 0 0 0 0 0 0 0 1 0 0 0 ; ... % phase = RECALL2
0 0 0 0 0 0 0 0 0 0 0 0 0 ;... % phase = WAITING_START_IMG_LOCALIZER
0 0 0 0 0 0 0 0 0 0 1 0 0]'; ... % phase = IMG_LOCALIZER - although in actuality this will get deferred to the values specified by REGRESSOR_COLUMNS_PER_IMG_TYPE

% NOTE: FOR BLOCK1, PHASE = RECALL(or PHASE = LIST2) and BLOCK2, PHASE = IMG_LOCALIZER, we have cannot easily map phase to regressor value, bc there are other factors
% that determine the regressor value (configuration of FORGET_CUE and RECALL_CUE for the former and PRES_IMG type in the latter) so here we define
% some constants to use later for these custom phase-regressor mappings
% this will be used in BLOCK1, PHASE = LIST2 - the first row should correspond to forget list1, remember list1
global REGRESSOR_COLUMNS_LIST2_BLOCK1; REGRESSOR_COLUMNS_LIST2_BLOCK1 = [ 0 1 0 0 0 0 0 0 0 0 0 0 0; 0 0 1 0 0 0 0 0 0 0 0 0 0]';
% this will be used in BLOCK1, PHASE = RECALL
global REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1; REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1 = [ 0 0 0 1 0 0 0 0 0 0 0 0 0; 0 0 0 0 1 0 0 0 0 0 0 0 0;  0 0 0 0 0 1 0 0 0 0 0 0 0]';
% this will be used in BLOCK2, PHASE = IMG_LOCALIZER
% this should match the order of IMG_IDENTIFIERS below AND it should have the same number of columns as the other REGRESSOR_COLUMNS variables
global REGRESSOR_COLUMNS_PER_IMG_TYPE; REGRESSOR_COLUMNS_PER_IMG_TYPE = [0 0 0 0 0 0 0 0 0 0 1 0 0; 0 0 0 0 0 0 0 0 0 0 0 1 0; 0 0 0 0 0 0 0 0 0 0 0 0 1]';
% NOTE: IF YOU EVER CHANGE ANYTHING HERE, MAKE SURE YOU *THOROUGHLY* UPDATE THE COMMENTS HERE
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% this is assumed to be a UNIQUE string in the PRES_IMG event third argument that will tell us what type of localizer img we're dealing with
% NOTE: we include the slashes before and after otherwise "scenes" could match both scenes and scrambled_scenes
global IMG_IDENTIFIERS; IMG_IDENTIFIERS = {'/scenes/' '/objects/' '/scrambled_scenes/'};

global NUM_IMG_PRESENTATIONS_PER_BLOCK; NUM_IMG_PRESENTATIONS_PER_BLOCK = 8;

% actually start programming now that we have more comments than an internet thread on kitten pictures
while true
	[event_type, event_time, parts] = get_next_event(fid);

    switch(STATE) 
		case BEGIN_EXP
			outputs = handle_begin_exp(event_type, event_time, parts, fid);
			SUBJECT = outputs.subject;
			STATE = BLOCK0;
			continue;
		case BLOCK0
			handle_block0(event_type, event_time, parts, fid);
			STATE = BLOCK1;
			continue;
		case BLOCK1
			outputs = handle_block1(event_type, event_time, parts, fid);
			num_runs = numel(outputs.runs);
			runs = outputs.runs;
			STATE = BLOCK2;
            % TODO: Grab output runs/lists
			continue;
        case BLOCK2
            outputs = handle_block2(event_type, event_time, parts, fid);
			num_runs = numel(outputs.runs);
			runs(end+1:end+num_runs) = outputs.runs;
			break;
            continue;
	end

end

fclose(fid);

%%%%%%%%%%% Here we handle each individual state
function [outputs] = handle_begin_exp(event_type, event_time, parts, opened_fid)
	
	% read until we find begin_exp marker
	[event_type, event_time, parts] = read_until_find_string(opened_fid,'BEGIN_EXP',...
		'File has ended without us finding a BEGIN_EXP event type, unable to parse. In other words, it''s not me, it''s you',event_type, event_time, parts);
	if strcmp(parts{3},'EXISTING_SUBJ')
			outputs.sesnum = str2num(parts{4});
			outputs.block = str2num(parts{5});
			outputs.repnum = str2num(parts{6});
			outputs.listnum = str2num(parts{7});
		elseif strcmp(parts{3},'NEW_SUBJ')
			outputs.subject = parts{4};
		end
	end

	

end

function [outputs] = handle_block0(event_type,event_time,parts,opened_fid)
	% here we just have to read until we find SET_BLOCK 0 and then until we find PREP_STIMULI
	[event_type, event_time, parts] = read_until_find_string(opened_fid,'SET_BLOCK','No SET_BLOCK found while handling BLOCK 0.',event_type, event_time, parts);
	if ~strcmpi(parts{3},'0')
		error(['Encountered SET_BLOCK ' parts{3} ' but expecting SET_BLOCK 0']);
	else
		[event_type, event_time, parts] = read_until_find_string(opened_fid,'PREP_STIMULI','No PREP_STIMULI found to end BLOCK 0.',event_type, event_time, parts);
	end
	outputs = '';

end

function [outputs] = handle_block1(event_type, event_time, parts, opened_fid)
	% find SET BLOCK 1
	[event_type, event_time, parts] = read_until_find_string(opened_fid,'SET_BLOCK','No SET_BLOCK found while handling BLOCK 0.',event_type, event_time, parts);
	if ~strcmpi(parts{3},'1')
		error(['Encountered SET_BLOCK ' parts{3} ' but expecting SET_BLOCK 1']);
    else 
            outputs.runs = struct('first_pulse_time_for_scan',NaN,'num_TRs_delete',NaN,'num_TRs',NaN,'regressors',{});
            outputs.lists = struct('type','','list_idx',NaN,'listblock',NaN,'list_file','','forget_cue','','words',{},'times',[]);
            [ run, lists ] = handle_listblock_for_block1(opened_fid);
            % we know we can transition to the next block of the file after handle_listblock has returned an empty list
            while(~isempty(lists))
                outputs.runs(end+1) = run;
                outputs.lists(1:3,end+1) = lists(:)';
                [ run, lists ] = handle_listblock_for_block1(opened_fid);
            end
	end
end

% this function makes certain assumptions about how the log file progresses which 
% are encoded through if statements and flags. a terribly obscure way of doing this,
% but we can't do this in a compartmentalized, nested fashion because the log file isn't
% perfectly nested.  here are the assumptions:
% 		- starts with a set list or set list_block command (they can happen in either order)
% 		- a single run starts with "FUNCTIONAL_SCAN_START" event, ends at STOP_RECORD with the following key values inbetween:
% 		- 		START_LIST
% 		- if we ever encounter a SET_LISTBLOCK # command where the # is greater than MAX_LISTBLOCKS_IN_BLOCK1, we will exit this function
% 		- it assumes that the first functional_scan_start corresponds to the first run number 
% 		  indicated by the *-1-1epilistblock1953x3x32s.nii.gz files
% 		-
function [ run, lists] = handle_listblock_for_block1(opened_fid)
	global SUBJECT; global MAX_LISTBLOCKS_IN_BLOCK1;
	global REGRESSOR_COLUMNS_PER_PHASE_BLOCK1;
	last_recall_cue = -1;
	% this will be used to fill in missing TRs
	last_TR_time = NaN;

	list_idx = 0;
	listblock_idx = 0;
	have_seen_fixate = false;
    % initialize our list structures
	list1.type = 'list1';
    list1.list_idx = NaN;
    list1.listblock = NaN;
    list1.list_file = '';
    list1.forget_cue = '';
    list1.words = {};
    list1.times = [];
    
	list2.type = 'list2';
    list2.list_idx = NaN;
    list2.listblock = NaN;
    list2.list_file = '';
    list2.forget_cue = '';
    list2.words = {};
    list2.times = [];
    
    recall.type = 'recall';
    recall.list_idx = NaN;
    recall.listblock = NaN;
    recall.list_file = '';
    recall.forget_cue = '';
    recall.words = {};
    recall.times = [];

	run = struct();
	run.first_pulse_time_for_scan = NaN;
	run.num_TRs_delete = 0;
	run.num_TRs = 0;
	% regressor rows correspond to list 1, list2, and recall TRs respectively
	run.regressors = zeros(13,0);

	% PHASES = 1 = waiting to start list, 2 = list1, 3 = waiting to start list2, 4 = list2, 5 = waiting to start recall, 6 = recall
	WAITING_START_LIST1 = 1;
	LIST1 = 2;
	WAITING_START_LIST2 = 3;
	LIST2 = 4;
	WAITING_START_RECALL = 5;
	RECALL = 6;
    FINISHED = 7;
	PHASE = WAITING_START_LIST1;
	REGRESSOR_COLUMNS_PER_PHASE = REGRESSOR_COLUMNS_PER_PHASE_BLOCK1;

	while PHASE ~= FINISHED
		[event_type,event_time,parts] = get_next_event(opened_fid);
	    next_event = struct('subject',SUBJECT,'type',parts{2},...
                        'mstime',1000*str2double(parts{1}),'list',list_idx,...
                        'item','X','itemno',-999,'recalled',-999,'rectime',-999); %,...
                        %'intrusion',-999,'pulsenum',pulsenum,'pulsefile',pulsefile,'pulseoffset',pulseoffset);

		switch event_type
			case{'SET_LISTBLOCK'}
				listblock_idx = str2num(parts{3});
				% handle breaking out of BLOCK1 mode
				if listblock_idx >= MAX_LISTBLOCKS_IN_BLOCK1
					lists = {};
                    run = {};
					return
				end
				continue;
			case{'SET_LIST'}
				list_idx = str2num(parts{3});
				continue;
			case{'FUNCTIONAL_SCAN_START'}
				% this indicates we will discard any PULSE_INFERRED values until we get a first PULSE_RECEIVED
				first_true_pulse = false;
				look_for_next_pulse = true;
				continue;
			case{'START_LIST'}
				PHASE = PHASE + 1;
				list_file = parts{3};
				switch PHASE
					case LIST1
						% this is because any PULSE_RECEIVED events received up until this point were being discarded,
						% but encountering a START_LIST event indicates we're done discarding volumes and the next
						% PULSE_RECEIVED event we get will be a volume we care about
						run.num_TRs_delete = run.num_TRs;
						list1(1).list_file = list_file;
						list1(1).listblock = listblock_idx;
						list1(1).list_idx = list_idx;
					case LIST2
						list2(1).list_file = list_file;
						list2(1).listblock = listblock_idx;
						list2(1).list_idx = list_idx;
				end
				continue;
			case {'END_LIST'}
				PHASE = PHASE + 1;
				continue;
			case {'FORGET_CUE'}
				list1.forget_cue = parts{3};
				continue;
			case{'PULSE_RECEIVED' 'PULSE_INFERRED'}
				% more accurate time
				event_time = 1000*str2double(parts{3});
				switch PHASE
					% waiting to start list: skip past pulse inferred values, til our first pulse received, mark the start time for that, add an entry for that and all subsequent pulse_received
					% events in our run array, filling in 0's for all regressors and stay in this phase until we hit a START_LIST event
					case WAITING_START_LIST1
						if strcmp(event_type,'PULSE_RECEIVED')
							if ~first_true_pulse
								first_true_pulse = true;
								run.first_pulse_time_for_scan = event_time;
							end
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
							run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
							last_TR_time = event_time;
							run.regressors(:,end+1:end+num_TRs_to_add + 1) = repmat(REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST1),1, 1 + num_TRs_to_add);
						end
						continue;
					% list 1 mode: if we receive a pulse_received now, this means we have TR for list1 and that the next line should be a word presentation
					% so we'll add a run with the appropriate regressor value, add the current word, and stay in this phase until we reach a END_LIST command
					case LIST1
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
						run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
						last_TR_time = event_time;
						run.regressors(:,end+1:end+num_TRs_to_add + 1) = repmat(REGRESSOR_COLUMNS_PER_PHASE(:,LIST1),1, 1 + num_TRs_to_add);
						list1.words{end+1} = get_next_presented_word(opened_fid);
						list1.times(end+1) = event_time;
						continue;
					case WAITING_START_LIST2
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
						run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
						last_TR_time = event_time;
						run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST2), 1, 1 + num_TRs_to_add);
						continue;
					% list 2 mode: identical to list 1 mode since we're not parsing 
					case LIST2
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
						run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
						last_TR_time = event_time;
						%run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,LIST2), 1, 1 + num_TRs_to_add);
						run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( get_regressor_for_present_list2(list1.forget_cue), 1, 1 + num_TRs_to_add);
						list2.words{end+1} = get_next_presented_word(opened_fid);
						list2.times(end+1) = event_time;
						continue;
					case WAITING_START_RECALL
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
						run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
						last_TR_time = event_time;
						run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_RECALL), 1, 1 + num_TRs_to_add);
						continue;
                    case RECALL
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,run.first_pulse_time_for_scan);
						run.num_TRs = run.num_TRs + 1 + num_TRs_to_add;
						last_TR_time = event_time;
						if last_recall_cue == -1
							run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_RECALL), 1, 1 + num_TRs_to_add);
						else
							run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( get_regressor_for_recall_list1(list1.forget_cue,last_recall_cue), 1, 1 + num_TRs_to_add);
						end
						%run.regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,RECALL), 1, 1 + num_TRs_to_add);
                        recall(1).times(end+1) = event_time;
				end % PHASE switch
				continue; % for event_type switch
            % the next three cases handle most of the record / recall
            % related code
            % THIS CODE DEPENDS ON US HITTING THIS BEFORE WE GET OUR FIRST
            % RECALL PHASE PULSE_RECEIVED
            case {'RECALL_CUE'}
				last_recall_cue = str2num(parts{3});
                continue;
			case {'START_RECORD'}
                PHASE = PHASE + 1;
                recall(1).listblock = -Inf;
                continue;
            case {'STOP_RECORD'}
                PHASE = PHASE + 1;
                [recall(1).listblock recall(1).list_idx] = parse_record_filename(parts{3});
				recall(1).list_file = parts{3};
				last_recall_cue = -1;
                continue;
		end % end event_type switch

	end

	lists = [ list1 list2 recall ];

end

function [regressor_value] = get_regressor_for_present_list2(forget_cue)
	% works under these assumptions which are reiterated from above
	% 3 = block1, present list2, FORGET_CUE
	% 4 = block1, present list2, REMEMBER_CUE
	% and that the values in REGRESSOR_COLUMNS_LIST2_BLOCK1 are (forget, remember)
	global REGRESSOR_COLUMNS_LIST2_BLOCK1;
	received_forget_cue = ~isempty(strfind(lower(forget_cue),'forget'));
	if received_forget_cue
		regressor_value = REGRESSOR_COLUMNS_LIST2_BLOCK1(:,1);
	else
		regressor_value = REGRESSOR_COLUMNS_LIST2_BLOCK1(:,2);
	end
end

function [regressor_value] = get_regressor_for_recall_list1(forget_cue, recall_list_cue)
	% works under these assumptions which are reiterated from above
	% 4 = block1, recall list1 REMEMBER_CUE
	% 5 = block1, recall list2 REMEMBER_CUE
	% 6 = block1, recall list2 FORGET_CUE
	global REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1;
	received_forget_cue = ~isempty(strfind(lower(forget_cue),'forget'));
	if ~received_forget_cue
		if recall_list_cue == 0 % recall cue 0 means recall listid=0 means recall list1
			regressor_value = REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1(:,1);
			return;
		elseif recall_list_cue == 1 % recall cue 1 means recall listid=1 means recall list2
			regressor_value = REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1(:,2);
			return;
		end
	else
		if recall_list_cue == 1
			regressor_value = REGRESSOR_COLUMNS_RECALL_CUE_BLOCK1(:,3);
			return;
		end
	end

	% if we've reached here then we have some invalid recall_cues and we need to see what's going on here
	error(['Not sure what our recall cue list_idx / forget_cue combination is instructing us to do here.  FORGET_CUE = ' forget_cue ', recall list idx = ' num2str(recall_list_cue)]);
end

function [outputs] = handle_block2(event_type, event_time, parts, opened_fid)
	% find SET BLOCK 1
	[event_type, event_time, parts] = read_until_find_string(opened_fid,'SET_BLOCK','No SET_BLOCK found while handling BLOCK 2.',event_type, event_time, parts);
	if ~strcmpi(parts{3},'2')
		error(['Encountered SET_BLOCK ' parts{3} ' but expecting SET_BLOCK 2']);
    else 
		% HERE WE WILL CALL HANDLE_LISTBLOCKS_FOR_BLOCK2
		[runs lists] = handle_listblocks_for_block2(opened_fid);
		outputs.runs = runs;
		outputs.lists = lists;
	end
end

function [runs, lists] = handle_listblocks_for_block2(opened_fid)
	global SUBJECT; global MAX_LISTBLOCKS_IN_BLOCK1;
	global REGRESSOR_COLUMNS_PER_PHASE_BLOCK2;
	global NUM_IMG_PRESENTATIONS_PER_BLOCK;
	% this will be used to fill in missing TRs
	last_TR_time = NaN;
	% we need a run_counter because this function handles multiple runs
	run_counter = 0;
	list_idx = 0;
	listblock_idx = MAX_LISTBLOCKS_IN_BLOCK1;
	% this is used to keep track of which img presentation we're on within a block.
	% this is ultimately used to determine when we should place zeros in our regressors
	% matrix for the interblock intervals
	img_presentation_counter = 0;

    % initialize our list structures
	% could vectorize this code, but i think this way gives
	% the program a bit more clarity about which phase it's in.
	list1.type = 'list1';
    list1.list_idx = NaN;
    list1.listblock = NaN;
    list1.list_file = '';
    list1.forget_cue = '';
    list1.words = {};
    list1.times = [];
    
	list2.type = 'list2';
    list2.list_idx = NaN;
    list2.listblock = NaN;
    list2.list_file = '';
    list2.forget_cue = '';
    list2.words = {};
    list2.times = [];
    
    recall1.type = 'recall1';
    recall1.list_idx = NaN;
    recall1.listblock = NaN;
    recall1.list_file = '';
    recall1.forget_cue = '';
    recall1.words = {};
    recall1.times = [];

    recall2.type = 'recall2';
    recall2.list_idx = NaN;
    recall2.listblock = NaN;
    recall2.list_file = '';
    recall2.forget_cue = '';
    recall2.words = {};
    recall2.times = [];

	% regressor rows correspond to list1, recall1, list2, recall2, scenes, objects, scrambled scenes
	% TRs respectively
	runs = repmat(struct('first_pulse_time_for_scan',NaN,'num_TRs_delete',0,'num_TRs',0,'regressors',zeros(13,0)),1,0);

	% PHASES = 1 = waiting to start list, 2 = list1, 3 = waiting to start list2, 4 = list2, 5 = waiting to start recall, 6 = recall
	WAITING_START_LIST1 = 1;
	LIST1 = 2;
	WAITING_START_RECALL1 = 3;
	RECALL1 = 4;
	WAITING_START_LIST2 = 5;
	LIST2 = 6;
	WAITING_START_RECALL2 = 7;
	RECALL2 = 8;
	WAITING_START_IMG_LOCALIZER = 9;
	IMG_LOCALIZER = 10;
    FINISHED = 11;


	PHASE = WAITING_START_LIST1;
	% TODO: Consider adding empty rows here for the possible regressor values in BLOCK 1 - would also have to do the "opposite"
	% for the regressors built in BLOCK 1 to accomodate the rows designated here
	% regressor columns correspond to 1 : 9 = PHASES, 10 = SCENES, 11 = objects, 12 = scrambled scenes
	REGRESSOR_COLUMNS_PER_PHASE = REGRESSOR_COLUMNS_PER_PHASE_BLOCK2;
	%REGRESSOR_COLUMNS_PER_PHASE = [ 0 0 0 0 0 0 0; 1 0 0 0 0 0 0; 0 0 0 0 0 0 0; 0 1 0 0 0 0 0; 0 0 0 0 0 0 0; 0 0 1 0 0 0 0; ...
	%									0 0 0 0 0 0 0; 0 0 0 1 0 0 0; 0 0 0 0 0 0 0; ];
	
	first_true_pulse = false;
	look_for_next_pulse = false;
	while PHASE ~= FINISHED
		try 
			[event_type,event_time,parts] = get_next_event(opened_fid);
			next_event = struct('subject',SUBJECT,'type',parts{2},...
							'mstime',1000*str2double(parts{1}),'list',list_idx,...
							'item','X','itemno',-999,'recalled',-999,'rectime',-999); 
		catch
			event_type = 'EOF';
		end
		% forced to do something ugly here

		switch event_type
			case {'SET_LIST'}
				list_idx = str2num(parts{3});
				continue;
			case {'FUNCTIONAL_SCAN_START'}
				% this indicates we will discard any PULSE_INFERRED values until we get a first PULSE_RECEIVED
				first_true_pulse = false;
				look_for_next_pulse = true;
				run_counter = run_counter + 1;
				runs(run_counter).num_TRs = 0;
                runs(run_counter).num_TRs_delete = 0;
				last_TR_time = NaN;
				continue;
			case{'START_LIST'}
				PHASE = PHASE + 1;
				list_file = parts{3};
				% this is because up until thi
				runs(run_counter).num_TRs_delete = runs(run_counter).num_TRs;
				switch PHASE
					case LIST1
						list1(1).list_file = list_file;
						list1(1).listblock = listblock_idx;
						list1(1).list_idx = list_idx;
					case LIST2
						list2(1).list_file = list_file;
						list2(1).listblock = listblock_idx;
						list2(1).list_idx = list_idx;
				end
				continue;
			case {'END_LIST'}
				PHASE = PHASE + 1;
				continue;
			case {'START_RECORD'}
                PHASE = PHASE + 1;
				if strcmpi(PHASE,'RECALL1')
                	recall1(1).listblock = 1;
				elseif strcmpi(PHASE,'RECALL2')
                	recall2(1).listblock = 2;
				end
                continue;

            case {'STOP_RECORD'}
				if strcmpi(PHASE,'RECALL1')
					[recall1(1).listblock recall(1).list_idx] = parse_record_filename(parts{3});
					recall1(1).list_file = parts{3};
				elseif strcmpi(PHASE,'RECALL2')
					[recall2(1).listblock recall(1).list_idx] = parse_record_filename(parts{3});
					recall2(1).list_file = parts{3};
				end
				PHASE = PHASE + 1;
				continue;
				% any one of these should mark the end of block2
			case {'SET_BLOCK' 'END_EXP' 'EOF'}
				PHASE = FINISHED;
				continue;

			case {'PULSE_RECEIVED' 'PULSE_INFERRED'}
				event_time = 1000*str2double(parts{3});
				switch PHASE
					% waiting to start list: skip past pulse inferred values, til our first pulse received, mark the start time for that, add an entry for that and all subsequent pulse_received
					% events in our runs array, filling in 0's for all regressors and stay in this phase until we hit a START_LIST event
					case WAITING_START_LIST1
						if strcmp(event_type,'PULSE_RECEIVED')
							if ~first_true_pulse
								first_true_pulse = true;
								runs(run_counter).first_pulse_time_for_scan = event_time;
							end
							% runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1);
							% runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST1);

							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST1), 1, 1 + num_TRs_to_add);


						end
						continue;
					case LIST1
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,LIST1), 1, 1 + num_TRs_to_add);
						%runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
						%runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,LIST1);
						list1.words{end+1} = get_next_presented_word(opened_fid);
						list1.times(end+1) = event_time;

						continue;
                    case RECALL1
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,RECALL1), 1, 1 + num_TRs_to_add);
                        % runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
                        % runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,RECALL1);
                        recall1(1).times(end+1) = event_time;
						continue;
					case WAITING_START_LIST2
						if strcmp(event_type,'PULSE_RECEIVED')
							if ~first_true_pulse
								first_true_pulse = true;
								runs(run_counter).first_pulse_time_for_scan = event_time;
							end
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST2), 1, 1 + num_TRs_to_add);
							% runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
							% runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_LIST2);
						end
						continue;
					case LIST2
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,LIST2), 1, 1 + num_TRs_to_add);
						% runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
						% runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,LIST2);
						list2.words{end+1} = get_next_presented_word(opened_fid);
						list2.times(end+1) = event_time;

						continue;
                    case RECALL2
                        % runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
                        % runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,RECALL2);
							num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
							last_TR_time = event_time;
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( REGRESSOR_COLUMNS_PER_PHASE(:,RECALL2), 1, 1 + num_TRs_to_add);
                        recall2(1).times(end+1) = event_time;
						continue;
					% this case is particularly ugly because we need to absorb all of the PULSE_RECEIVED events until we get 
					% to a PRES_IMG event which will officially start the image localizer - all other scan sequences have a unique identifier
					% to indicate that we should treat PULSE_RECEIVED values differently
					case WAITING_START_IMG_LOCALIZER
						if strcmp(event_type,'PULSE_RECEIVED')
							% we will consume the first pulse receive we encounter, use this for out start time, 
							% call a function to consume all the TRs until the one linked to an PRES_IMG event
							% add empty regressor columns for the TRs consumed (except the last one) and then 
							% add the regressor for the encountered img (based on its type) and increment num_TRs appropriately
							runs(run_counter).first_pulse_time_for_scan = event_time;
							runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
							runs(run_counter).regressors(:,end+1) = REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_IMG_LOCALIZER);

							% this function takes care of
							[num_TRs_consumed regressor_value_first_word last_TR_time] = handle_start_img_localizer(opened_fid, runs(run_counter).first_pulse_time_for_scan);

							% add in the TRs consumed, we subtract one because the last TR is an image presentation TR that needs a different regressor
							runs(run_counter).regressors(:,end+1:end+num_TRs_consumed - 1) = repmat(REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_IMG_LOCALIZER),1,num_TRs_consumed - 1);
							runs(run_counter).regressors(:,end+1) = regressor_value_first_word;
							runs(run_counter).num_TRs = (runs(run_counter).num_TRs + num_TRs_consumed);
							% this line here indicates that all but the very last TR we just grabbed shuld be deleted
							runs(run_counter).num_TRs_delete = runs(run_counter).num_TRs - 1;
							% finally increase the phase to IMG_LOCALIZER
							PHASE = PHASE + 1;
							% this keeps track of how many image presentations we've seen from this category
							img_presentation_counter = img_presentation_counter + 1;
						end
						continue;
					case IMG_LOCALIZER
						img_presentation_counter = img_presentation_counter + 1;
						ith_img_presentation_in_block = mod(img_presentation_counter,NUM_IMG_PRESENTATIONS_PER_BLOCK);
						%runs(run_counter).num_TRs = runs(run_counter).num_TRs + 1;
						num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,runs(run_counter).first_pulse_time_for_scan);
						runs(run_counter).num_TRs = (runs(run_counter).num_TRs + 1 + num_TRs_to_add);
						last_TR_time = event_time;
						% TODO: Deal with  possibility of PRES_IMG being off from last_TR_TIME
						% grab next event which should be a PRES_IMG and extract the correct regressor type based on the img filename 
						[event_type,event_time,parts] = get_next_event(opened_fid);
						% this is the case where we have extra TRs to add because we've switched from one block to another,
						% and thus the appropriate thing to do is to fill in the missing TRs with zeros for the blocks between these;
						% TODO: Safest way of doing this would actually check if we've decreased our ith_img_presentation since last time, that way we 
						% can account for something like 6th_scrambled = last TR seen, then get next TR indicating 6 TRs have passed...the first two being
						% the 7th and 8th scrambled TRs, the next 3 being inter-block , and the last being the first of the next block
						if ith_img_presentation_in_block == 1 && num_TRs_to_add > 0
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add) =repmat(REGRESSOR_COLUMNS_PER_PHASE(:,WAITING_START_IMG_LOCALIZER), 1,  num_TRs_to_add);
							runs(run_counter).regressors(:,end+1) =get_regressor_for_pres_img(parts{3});
						else
							runs(run_counter).regressors(:,end+1:end+num_TRs_to_add + 1) =repmat( get_regressor_for_pres_img(parts{3}), 1, 1 + num_TRs_to_add);
							% img_presentation_counter = img_presentation_counter + num_TRs_to_add;
						end
						%runs(run_counter).regressors(:,end+1) = get_regressor_for_pres_img(parts{3});
						continue;

				end

				continue;
		end % end event_type switch

	end
	

	lists = [ list1 recall1 list2 recall2 ];

end



% this function will return the total number of TRs that have been processed
% the regressor values for however many number of TRs have been consumed
% the first picture read in
function [ num_TRs_consumed regressor_column_for_first_img_TR event_time ] = handle_start_img_localizer(opened_fid,last_TR_time)
	num_TRs_consumed = 0;
	[event_type,event_time,parts] = get_next_event(opened_fid);
	while(strcmpi(event_type,'PULSE_RECEIVED'))
		% here we accoutn for any skipped TRs
		num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,0);
		num_TRs_consumed = num_TRs_consumed + 1 + num_TRs_to_add;
		last_TR_time = event_time;
		[event_type,event_time,parts] = get_next_event(opened_fid);
	end

	% here we accoutn for any skipped TRs
	num_TRs_to_add = fill_in_missing_TRs(last_TR_time,event_time,0);
	num_TRs_consumed = num_TRs_consumed + num_TRs_to_add;

	% this means we finally have loaded an event_type that ISN'T a PULSE RECEIVED, which SHOULD
	% indicate that we've reached a PRES_IMG event - if this isn't the case, we're going to throw an error
	% because something is fishy with this session log and programs can only do so much
	if strcmpi(event_type,'PRES_IMG')
		regressor_column_for_first_img_TR = get_regressor_for_pres_img(parts{3});
	else
		error(['Parser believes we should be expecting a PRES_IMG event_type as the first marker of entering the img_localizer phase, but we have received ' event_type]);
	end


end

function [ regressor_value ]  = get_regressor_for_pres_img(img_filename_string)
	global IMG_IDENTIFIERS;
	global REGRESSOR_COLUMNS_PER_IMG_TYPE;

	% parts(3) should contain a file path, which should have one of three identifiers specified by IMG_IDENTIFIERS
	img_type_idx = 1;
	for img_type = IMG_IDENTIFIERS
		img_type = img_type{:};
		% check if the passed in string matches our img identifier
		if ~isempty(strfind(img_filename_string,img_type))
			regressor_value = REGRESSOR_COLUMNS_PER_IMG_TYPE(:,img_type_idx);
			return;
		end
		img_type_idx = img_type_idx + 1;
	end
	
	% if we've gotten here, it means we didn't match an img_type and we should throw an error
	error(['Couldn''t determine the img type for ' img_filename_string ' Either you have a crappy session log file OR you have an error with IMG_IDENTIFIERS global variable']);
end











%%%%%%%%%% Utility functions for reading in line from file or searching for thigns, etc


% this function will accept two times for a TR (the 
function [num_TRs_to_add] = fill_in_missing_TRs(last_TR_time, current_TR_time,first_TR_time)
	global TR_LENGTH_MSECS;
	global DEBUG_FLAG;

	if isnan(last_TR_time)
		num_TRs_to_add = 0;
		return;
	end

	%tr_time_diff = current_TR_time - last_TR_time;
	tr_time_diff = (current_TR_time - first_TR_time) - (last_TR_time - first_TR_time);
	%
	% here we check if the time between TRs is greater than the twice the TR_LENGTH_MSECS which would indicate we skipped at least one TR
	% NOTE: we do 1.95 (instead of 2) to give us a little leeway. however, to counteract this, we end up having to round up to the nearest whole second
	% which is what dividing by 1000, doing the ceiling, and then multiplying by 1000 accomplishes
	if tr_time_diff >= (1.95 * TR_LENGTH_MSECS)
		num_TRs_to_add = floor(ceil(tr_time_diff / 1000) * 1000 / TR_LENGTH_MSECS) - 1;
		if DEBUG_FLAG
			disp(['Adding ' num2str(num_TRs_to_add) ' because TR diff = ' num2str(tr_time_diff)]);
		end
	else
		num_TRs_to_add = 0;
	end
end

% format is %d_%d.wav, first blank = listblock idx (1-indexed), list idx
% (0-indexed)
function [listblock_idx, list_idx] = parse_record_filename(filename)
    results = textscan(filename,'%d_%d');
    listblock_idx = results{1};
    list_idx = results{2};
end

% this function throws an error if we don't find a PRES_WORD
function [ word ] = get_next_presented_word(opened_fid)
	[event_type,event_time,parts] = get_next_event(opened_fid);
	if ~strcmpi(event_type, 'PRES_WORD')
		error('Expected a PRES_WORD event to be next, but didn''t find one.  Presumably an error because this means we don''t know how to label a previous PULSE_RECEIVED event.');
	end
	if ~isempty(parts{3}) && ischar(parts{3})
		word = parts{3};
	else
		error('PRES_WORD event expected and grabbed, but the presented word is empty.');
	end
end

function [ event_type,event_time,parts] = read_until_find_string(opened_fid,string_to_find, error_msg, event_type, event_time, parts)
	% read until we find the string of interest or until we hit the end of file
	while ~strcmpi(event_type,string_to_find)

		% if we have an empty string here, it means we've reached the end of the file and we should error out
		if ~ischar(event_type)
			fclose(opened_fid);
			error(error_msg);
		end

		[event_type, event_time, parts] = get_next_event(opened_fid);
	end

end

function [event_type,event_time,parts] = get_next_event(opened_fid)
	nextline = fgetl(opened_fid);
    if ~ischar(nextline)
	   	event_type = nextline;
		event_time = NaN;
		parts = {};
		return;
	end
    parts = regexp(nextline,'\t','split');       
	event_time = 1000*str2double(parts{1});
	event_type = parts{2};

end



