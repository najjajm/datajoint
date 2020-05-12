%{
# raw, trialized, and aligned EMG data
  -> pacman.EmgChannels
  -> pacman.Sync
  emg_channel : tinyint unsigned # channel number
  ---
  emg_channel_data : longblob # channel data
%}

classdef Emg < dj.Imported
    methods(Access=protected)
        function makeTuples(self,key)

            rel = pacman.ContinuousRecording * pacman.EmgChannels * pacman.SyncChannel & key;
            [allChanStr,corruptChanStr,filePath,fileName,timeStamp]...
                = fetch1(rel,'emg_channel_numbers','corrupted_emg_channels',...
                'continuous_file_path','continuous_file_name','time_stamp');
            
            % restrict to good channels
            allChanNo = str2num(allChanStr);
            corruptChan = str2num(corruptChanStr);
            chanNo = setdiff(allChanNo,allChanNo(corruptChan));
            
            % fetch alignment indices
            alignIdx = fetch1(pacman.Sync & key,'continuous_alignment');
            
            % load NSx file
            nsx = openNSx([filePath,fileName],['c:' num2str(chanNo)],['t:' int2str(alignIdx(1)) ':' int2str(alignIdx(end))]);
            
            % remove leading time stamp
            nsx.Data(:,1:timeStamp) = [];
            
            for ii = 1:length(chanNo)
                key.emg_channel = chanNo(ii)-(allChanNo(1)-1);
                key.emg_channel_data = nsx.Data(ii,:);
                self.insert(key);
            end
        end
        function keys = gettrialkeys(self,cond,trial)
            
            % condition keys
            condKey = sort(pacman.TaskConditions & (pacman.TaskTrials & self));
            if strcmp(cond{1},'all')
                condIdx = 1:length(condKey);
            else
                switch cond{2}
                    case 'index'
                        condIdx = cond{1};
                    case 'first'
                        condIdx = 1:cond{1};
                    case 'last'
                        condIdx = (length(condKey)-(cond{1}-1)):length(condKey);
                    case 'rand'
                        condIdx = datasample(1:length(condKey),cond{1},'Replace',false);
                end
            end
            condKey = condKey(condIdx);
            nCond = length(condKey);
            
            keys = cell(nCond,1);
            
            for iCond = 1:nCond
                
                % trial keys
                trialKey = fetch(pacman.GoodTrials & (pacman.TaskTrials & (pacman.TaskConditions & condKey(iCond))),'*'); 
                if strcmp(trial{1},'all')
                    trialIdx = 1:length(trialKey);
                else
                    switch trial{2}
                        case 'index'
                            trialIdx = trial{1};
                        case 'first'
                            trialIdx = 1:trial{1};
                        case 'last'
                            trialIdx = (length(trialKey)-(trial{1}-1)):length(trialKey);
                        case 'rand'
                            trialIdx = datasample(1:length(trialKey),trial{1},'Replace',false);
                    end
                end
                trialKey = trialKey(trialIdx);
                nTrial = length(trialKey);
                
                % merge condition and trial key data                
                keys{iCond} = repmat(condKey(iCond),nTrial,1);
                for iTrial = 1:nTrial
                    keys{iCond}(iTrial).condition_index = condIdx(iCond);
                    
                    fn = fieldnames(trialKey(iTrial));
                    for iField = 1:length(fn)
                        keys{iCond}(iTrial).(fn{iField}) = trialKey(iTrial).(fn{iField});
                    end
                end
            end
            
            keys = cat(1,keys{:});
        end
    end
    methods
        function plot(self,sessionDate,varargin)
            validindices = @(x) iscell(x) &&...
                (strcmp(x{1},'all') || isnumeric(x{1})) &&...
                ismember(x{2},{'index','first','last','rand'});
            P = inputParser;
            addRequired(P, 'sessionDate', @ischar)
            addParameter(P, 'cond', {1,'index'}, @(x) validindices(x))
            addParameter(P, 'trial', {1,'index'}, @(x) validindices(x))
            addParameter(P, 'emg_channel', [], @(x) isempty(x) || isnumeric(x))
            addParameter(P, 'filtOrd', 2, @isnumeric)
            addParameter(P, 'filtCut', 500, @isnumeric)
            addParameter(P, 'filtType', 'high', @(x) ischar(x) && ismember(x,{'low','high','bandpass'}))
            addParameter(P, 'group', [], @ischar)
            addParameter(P, 'showTrialforce', false, @islogical)
            addParameter(P, 'showMeanforce', false, @islogical)
            parse(P,sessionDate,varargin{:})
            
            sessKey = struct('session_date',sessionDate);
            
            % get trial keys
            trialKeys = gettrialkeys(self & sessKey, P.Results.cond, P.Results.trial);
            nTrial = length(trialKeys);
            
            for iTrial = 1:nTrial
                
                rel = self & ((pacman.GoodTrials * pacman.TaskTrials & sessKey) & trialKeys(iTrial));
                
                % restrict channels
                if ~isempty(P.Results.emg_channel)
                    chanKey = cell2struct(num2cell(P.Results.emg_channel),'emg_channel');
                    rel = rel & chanKey;
                end
                
                % fetch trial data
                key = fetchdata(rel,...
                    'filtOrd',P.Results.filtOrd,...
                    'filtCut',P.Results.filtCut,...
                    'filtType',P.Results.filtType);
                
                % plot channel data
                figure
                ax = [];
                for ii = 1:length(key)
                    ax(ii) = subplot(length(key),1,ii);
                    
                    FsCont = fetch1(pacman.ContinuousRecording & key(ii),'continuous_sample_rate');
                    t = maketarget(pacman.TaskConditions & (pacman.TaskTrials & key(ii)), FsCont);
                    
                    plot(t,key(ii).emg_data,'k')
                    
                    title(sprintf('channel %i',key(ii).emg_channel))
                    box off
                end
                linkaxes(ax,'x')
                set(gcf,'Name',sprintf('EMG. %s. Condition %i. Trial %i',...
                    sessKey.session_date,trialKeys(iTrial).condition_index,trialKeys(iTrial).trial_index)) 
            end
        end
        function plotfit(self,sessionDate,varargin)
            P = inputParser;
            addParameter(P,'chan',[],@(x) isempty(x) || isnumeric(x))
            addParameter(P,'cond',1,@isscalar)
            addParameter(P,'trial',1,@(x) isnumeric(x) || (ischar(x) && strcmp(x,'rand')))
            addParameter(P,'unit',[],@(x) isempty(x) || isscalar(x))
            addParameter(P,'newFig',true,@islogical)
            parse(P,varargin{:})
            
            % assign target
            targKey = sort(pacman.TaskConditions & (pacman.TaskTrials & self & ['session_date="' sessionDate '"']));
            targKey = targKey(P.Results.cond);
            
            % assign trials
            trials = fetchn(pacman.TaskTrials & self & targKey,'trial_number');
            if isnumeric(P.Results.trial)
                trialIdx = unique(min(max(1,P.Results.trial),length(trials)));
            else
                trialIdx = randi(length(trials),1);
            end
            
            % motor unit waveform colormap
            muID = fetchn(pacman.MotorUnit & targKey,'motor_unit_id');
            cmap = brewermap(length(muID),'Spectral');
            cmap = max([0 0 0],cmap-.2);
            fh = zeros(1,size(cmap,1));
            
            for tr = 1:length(trialIdx)
                
                key = targKey;
                key.trial_number = trials(trialIdx(tr));
                
                % assign channels
                channels = P.Results.chan;
                if isempty(channels)
                    channels = unique(fetchn(self & key,'emg_channel'));
                end
                
                % fetch target time
                FsCont = fetch1(pacman.ContinuousRecording & key,'continuous_sample_rate');
                t = maketarget(pacman.TaskConditions & self & key,FsCont);
                
                % plot channel data
                if P.Results.newFig
                    figure
                else
                    clf
                end
                ax = [];
                for ii = 1:length(channels)
                    
                    chanKey = key;
                    
                    % plot channel data
                    ax(ii) = subplot(length(channels),1,ii);
                    chanKey.emg_channel = channels(ii);
                    chanKey = fetchdata(self & chanKey);
                    plot(t,chanKey.emg_data,'k')
                    title(sprintf('channel %i',channels(ii)))
                    
                    % overlay waveforms
                    hold on
                    for jj = 1:length(muID)                        
                        chanKey.motor_unit_id = muID(jj);
                        s = fetch1(pacman.MotorUnitSpikes & chanKey,'motor_unit_spikes');                        
                        if any(s)
                            spkIdx = find(s);
                            w = fetch1(pacman.MotorUnitTemplate & chanKey,'motor_unit_waveform');
                            waveLen = length(w)+mod(length(w),2);
                            frame = -waveLen/2:waveLen/2-1;
                            spkIdx = spkIdx(spkIdx>-frame(1) & spkIdx<length(t)-frame(end));
                            for kk = 1:length(spkIdx)
                                fh(jj) = plot(t(spkIdx(kk)+frame),w,'color',cmap(jj,:),'linewidth',2);
                            end
                        end
                    end
                    box off
                end
                linkaxes(ax,'x')
                xlim(t([1 end]))
                unitTxt = cellfun(@(n) sprintf('MU %i',n),num2cell(muID),'uni',false);
                legend(fh(fh~=0),unitTxt(fh~=0),'location','best')
                set(gcf,'Name',sprintf('EMG fit. %s. Condition %i (ID %i). Trial %i (%i/%i)',...
                    key.session_date,P.Results.cond,key.targ_id,key.trial_number,trialIdx(tr),length(trials)))
            end
        end
        function testfit(self,sessionDate,varargin)
            validindices = @(x) iscell(x) &&...
                (strcmp(x{1},'all') || isnumeric(x{1})) &&...
                ismember(x{2},{'index','first','last','rand'});
            P = inputParser;
            addRequired(P, 'sessionDate', @ischar)
            addParameter(P, 'cond', {1,'index'}, @(x) validindices(x))
            addParameter(P, 'trial', {1,'index'}, @(x) validindices(x))
            addParameter(P, 'w', [], @(x) isempty(x) || isnumeric(x))
            addParameter(P, 'Cinv', [], @(x) isempty(x) || isnumeric(x))
            addParameter(P, 'filtOrd', 2, @isnumeric)
            addParameter(P, 'filtCut', 500, @isnumeric)
            addParameter(P, 'filtType', 'high', @(x) ischar(x) && ismember(x,{'low','high','bandpass'}))
            parse(P,sessionDate,varargin{:})
            
            sessKey = struct('session_date',sessionDate);
            
            % load missing data
            sortPath = sprintf(pacman.MotorUnit.getsortpath(), sessKey.session_date);
            if isempty(P.Results.w)
                load([sortPath 'templates'],'W')
                fn = fieldnames(W);
                w = W.(fn{end});
            else
                w = P.Results.w;
            end
            if isempty(P.Results.Cinv)
                load([sortPath 'noise_cov'],'Cinv')
            else
                Cinv = P.Results.Cinv;
            end
            
            % sample rate
            Fs = fetch1(pacman.ContinuousRecording & sessKey, 'continuous_sample_rate');
            
            % get trial keys
            trialKeys = gettrialkeys(self & sessKey, P.Results.cond, P.Results.trial);
            nTrial = length(trialKeys);
            
            for iTrial = 1:nTrial
                
                rel = self & ((pacman.GoodTrials * pacman.TaskTrials & sessKey) & trialKeys(iTrial));
                
                % fetch trial data
                key = fetchdata(rel,...
                    'filtOrd',P.Results.filtOrd,...
                    'filtCut',P.Results.filtCut,...
                    'filtType',P.Results.filtType);
                X = cell2mat(arrayfun(@(x) x.emg_data, key, 'uni', false))';
                
                % run BOTM
                botm(X,Fs,w,Cinv,'plot',{'fit'},'refDur',1e-3);
                
                set(gcf,'Name',sprintf('EMG fit. %s. Condition %i. Trial %i',...
                    sessKey.session_date,trialKeys(iTrial).condition_index,trialKeys(iTrial).trial_index)) 
            end
        end
        function Q = quantifysort(self,sessionDate) % compare with EmgSortQuality
           primaryKey = struct('session_date',sessionDate);
           targKey = sort(pacman.TaskConditions & primaryKey);
           chanNo = unique(fetchn(self & primaryKey,'emg_channel'));
           unitID = fetchn(pacman.MotorUnit & primaryKey,'motor_unit_id');
           
           % quality metrics
           Q = struct('resEner',{cell(length(chanNo),length(unitID),length(targKey))});
           
           for ii = 1:length(targKey)
               key = targKey(ii);
               trialNo = fetchn(pacman.TaskTrials & self & key,'trial_number');
               Q.resEner(:,:,ii) = {zeros(1,length(trialNo))};
               for jj = 1:length(trialNo)
                   key.trial_number = trialNo(jj);
                   for kk = 1:length(chanNo)
                       key.emg_channel = chanNo(kk);
                       X = fetch1(self & key,'emg_data');
                       Xener = sum(X.^2);
                       for ll = 1:length(unitID)
                           key.motor_unit_id = unitID(ll);
                           res = X;
                           s = fetch1(pacman.MotorUnitSpikes & key,'motor_unit_spikes');
                           w = fetch1(pacman.MotorUnitTemplate & key,'motor_unit_waveform');
                           if any(s)
                               res = res - conv(s,w,'same');
                           end
                           Q.resEner{kk,ll,ii}(jj) = sum(res.^2)/Xener;
                       end
                   end
               end
           end
        end
    end
end