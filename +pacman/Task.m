%{
# Speedgoat task data parser
  -> pacman.SpeedgoatRecording
  ---
%}

classdef Task < dj.Imported
    methods(Access=protected)
        function makeTuples(self,key)
            
            % temporarily copy Speedgoat data to local directory
            [filePath,filePrefix] = fetch1(pacman.SpeedgoatRecording & key,...
                'speedgoat_file_path','speedgoat_file_prefix');
%             LOCAL_PATH = '~/Desktop/speedgoat/';
%             if ~exist(LOCAL_PATH,'dir')
%                 mkdir(LOCAL_PATH)
%             end
%             delete([LOCAL_PATH '*'])
%             files = dir([filePath,filePrefix,'*']);
%             fileNames = arrayfun(@(x) x.name,files,'uni',false);
%             filePath = files(1).folder;
%             for jj = 1:length(fileNames)
%                 copyfile([filePath '/' fileNames{jj}],LOCAL_PATH)
%             end
            
            % parse speedgoat data
            T = parsespeedgoatdata([filePath,filePrefix]); %[LOCAL_PATH, filePrefix]);
            
            % populate new task states
            states = T.Properties.UserData.TaskStates;
            for ii = 1:size(states,1)
                if count(pacman.TaskStates & ['task_state_id=' num2str(states{ii,1})]) == 0
                    insert(pacman.TaskStates,{states{ii,1},states{ii,2}});
                end
            end
            
            % populate condition data
            %
            % session key
            sessKey = key;
            
            % insert session key to self
            self.insert(sessKey)
            
            for trialNo = 1:height(T)
                
                if isempty(T.simTime{trialNo})
                    continue
                end
                
                if trialNo==11
                    disp('')
                end
                
                % assign target and stim keys
                key = sessKey;
                targKey = self.writetargetkey(T.trialParams{trialNo});
                stimKey = self.writestimkey(T.trialParams{trialNo});
                
                if count(pacman.TaskConditions & sessKey & targKey & stimKey) > 0
                    continue
                end
                
                % assign target ID
                if count(pacman.TaskConditions & targKey) == 0  % check for entries across sessions
                    if count(pacman.TaskConditions) == 0
                        targKey.targ_id = 1;
                    else
                        tid = fetchn(pacman.TaskConditions,'targ_id');
                        targKey.targ_id = min(setdiff(1:1+max(tid),unique(tid)));
                    end
                else
                    targKey.targ_id = unique(fetchn(pacman.TaskConditions & targKey, 'targ_id'));
                end
                
                % assign unique stim ID (within sessions)
                if count(pacman.TaskConditions & sessKey & stimKey) == 0
                    if stimKey.stim_electrode == 0 && stimKey.stim_current == 0
                        stimKey.stim_id = 0;
                    else
                        if count(pacman.TaskConditions & sessKey) == 0
                            stimKey.stim_id = 1;
                        else
                            stimKey.stim_id = 1+max(fetchn(pacman.TaskConditions & sessKey,'stim_id'));
                        end
                    end
                else
                    stimKey.stim_id = unique(fetchn(pacman.TaskConditions & sessKey & stimKey, 'stim_id'));
                end
                
                % aggregate keys
                targFields = fieldnames(targKey);
                for ii = 1:length(targFields)
                    key.(targFields{ii}) = targKey.(targFields{ii});
                end
                stimFields = fieldnames(stimKey);
                for ii = 1:length(stimFields)
                    key.(stimFields{ii}) = stimKey.(stimFields{ii});
                end
                
                % insert key data
                insert(pacman.TaskConditions,key);
            end
            
            % populate trial data
            for trialNo = 1:height(T)
                
                if isempty(T.simTime{trialNo})
                    continue
                end
                
                % assign key data
                key = sessKey;
                key.trial_number = trialNo;
                key.save_tag = uint8(T.saveTag(trialNo));
                key.valid_trial = uint8(T.validTrial(trialNo));
                key.successful_trial = uint8(T.success(trialNo));
                key.simulation_time = T.simTime{trialNo};
                key.task_state = T.taskState{trialNo};
                key.force_raw_online = T.forceRaw{trialNo};
                key.force_filt_online = T.forceFilt{trialNo};
                key.stim = T.stim{trialNo};
                key.reward = T.reward{trialNo};
                key.photobox = T.photobox{trialNo};
                
                % fetch target and stim ID
                targKey = self.writetargetkey(T.trialParams{trialNo});
                stimKey = self.writestimkey(T.trialParams{trialNo});
                [targID, stimID] = fetchn(pacman.TaskConditions...
                    & stimKey & targKey, 'targ_id','stim_id');
                key.targ_id = targID(1);
                key.stim_id = stimID(1);
                
                % insert key data
                insert(pacman.TaskTrials,key);
            end
            
%             % clear local copy of speedgoat files
%             delete([LOCAL_PATH '*'])
%             rmdir(LOCAL_PATH)
        end
    end
    methods(Access=private)
        function targKey = writetargetkey(~,trialParams)
            targKey.force_polarity = int8(trialParams.frcPol);
            targKey.force_max = uint8(trialParams.frcMax);
            targKey.force_offset = round(trialParams.frcOff,4);
            targKey.target_type = char(trialParams.type);
            targKey.target_offset = round(trialParams.offset(1),4);
            targKey.target_amplitude = round(trialParams.amplitude(1),4);
            targKey.target_duration = round(trialParams.duration,4);
            targKey.target_frequency1 = round(trialParams.frequency(1),4);
            targKey.target_frequency2 = round(trialParams.frequency(2),4);
            targKey.target_power = round(trialParams.power,4);
            targKey.target_pad = round(trialParams.padDur,4);
        end
        function stimKey = writestimkey(~,trialParams)
            stimKey = struct(...
                'stim_polarity',0,...
                'stim_pulses',0,...
                'stim_width1',0,...
                'stim_width2',0,...
                'stim_interphase',0,...
                'stim_frequency',0,...
                'stim_current',0,...
                'stim_electrode',0);
            if isfield(trialParams,'stim')
                stimFields = fieldnames(stimKey);
                for ii = 1:length(stimFields)
                    fnSG = erase(regexprep(stimFields{ii},'_\w','${upper($0)}'),'_');
                    stimKey.(stimFields{ii}) = round(trialParams.(fnSG));
                end
            end
        end
    end
    methods
       % -----------------------------------------------------------------
        % GET CONDITION/TRIAL KEYS
        % -----------------------------------------------------------------
        function key = getkey(self,level,varargin)
            iscode = @(x,codes) ischar(x) && ismember(x,codes);
            P = inputParser;
            addRequired(P, 'level', @(x) iscode(x,{'cond','trial'}))
            addParameter(P, 'block', 1, @(x) isnumeric(x) || (ischar(x) && strcmp(x,'all')))
            addParameter(P, 'cond', 1, @isnumeric)
            addParameter(P, 'condType', 'index', @(x) iscode(x,{'index','rand','first','last','all'}))
            addParameter(P, 'trialSet', 'good', @(x) iscode(x,{'good','bad','all'}))
            addParameter(P, 'trial', 1, @isnumeric)
            addParameter(P, 'trialType', 'index', @(x) iscode(x,{'index','rand','first','last','all'}))
            parse(P,level,varargin{:})
            
            % session keys
            sessKey = fetch(pacman.Session & self);
            key = cell(length(sessKey),1);
            
            for iSess = 1:length(sessKey)
                
                % save tag keys for condition block
                blockRel = pacman.SessionBlock & sessKey(iSess);
                if isnumeric(P.Results.block)
                    blockRel = blockRel & ['block_id=' num2str(P.Results.block)];
                    blockKey = saveTagStr2Key(pacman.SessionBlock, fetch1(blockRel,'save_tag_set'));
                else
                    saveTags = fetchn(blockRel,'save_tag_set');
                    blockKey = cellfun(@(tag) saveTagStr2Key(pacman.SessionBlock,tag),saveTags,'uni',false);
                    blockKey = cat(1,blockKey{:});
                end
            
                % sample conditions
                condKey = sort(pacman.TaskConditions & sessKey(iSess) & (pacman.TaskTrials & blockKey));
                switch P.Results.condType
                    case 'all'
                        condIdx = 1:length(condKey);

                    case 'rand'
                        condIdx = datasample(1:length(condKey),P.Results.cond,'Replace',false);
                        
                    case 'index'
                        condIdx = P.Results.cond;
                        
                    case 'first'
                        condIdx = 1:P.Results.cond;
                        
                    case 'last'
                        condIdx = (length(condKey)-(P.Results.cond-1)):length(condKey);
                end
                condKey = condKey(condIdx);
                nCond = length(condKey);
                
                % trial keys
                key{iSess} = cell(nCond,1);
                for iCond = 1:nCond
                    
                    % append condition index
                    condKey(iCond).condition_index = condIdx(iCond);
                    
                    if strcmp(level,'cond')
                        key{iSess}{iCond} = condKey(iCond);
                        
                    else
                        % restrict by trial set
                        trialRel = pacman.TaskTrials & blockKey & (pacman.TaskConditions & condKey(iCond));
                        switch P.Results.trialSet
                            case 'good'
                                trialRel = trialRel & pacman.GoodTrials;
                                
                            case 'bad'
                                trialRel = trialRel - pacman.GoodTrials;
                        end
                        
                        % sample trials
                        trialKey = fetch(trialRel);
                        nTrial = length(trialKey);
                        switch P.Results.trialType
                            case 'all'
                                trialIdx = 1:length(trialKey);
                                
                            case 'rand'
                                trialIdx = datasample(1:nTrial,P.Results.trial,'Replace',false);
                                
                            case 'index'
                                trialIdx = P.Results.trial;
                                
                            case 'first'
                                trialIdx = 1:P.Results.trial;
                                
                            case 'last'
                                trialIdx = (nTrial-(P.Results.trial-1)):nTrial;
                        end
                        trialKey = trialKey(trialIdx);
                        nTrial = length(trialKey);
                        
                        % merge condition and trial key data
                        key{iSess}{iCond} = repmat(condKey(iCond),nTrial,1);
                        for iTrial = 1:nTrial
                            key{iSess}{iCond}(iTrial).trial_index = trialIdx(iTrial);
                            
                            fn = fieldnames(trialKey(iTrial));
                            for iField = 1:length(fn)
                                key{iSess}{iCond}(iTrial).(fn{iField}) = trialKey(iTrial).(fn{iField});
                            end
                        end
                    end
                end
                
                % concatenate keys across conditions
                key{iSess} = cat(1,key{iSess}{:});
            end
            
            % concatenate keys across sessions
            key = cat(1,key{:});
        end 
    end
end