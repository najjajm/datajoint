%{
# motor unit
  -> pacman.EmgChannels
  motor_unit_id : smallint unsigned # unique unit ID
  ---
%}

classdef MotorUnit < dj.Imported
    properties(Dependent)
        keySource
    end
    methods(Static)
        function pth = getsortpath(~)
            pth = '/Volumes/Churchland-locker/Jumanji/pacman-task/cousteau/processed/hpc/%s/myosort-out/';
        end 
    end
    methods        
        function source = get.keySource(self)           
            % check for summary file
            sourceKeys = fetch(pacman.EmgChannels & 'session_date>="2018-10-02"' & 'session_date<="2018-10-03"');
            hasSortedData = false(length(sourceKeys),1);
            for ii = 1:length(sourceKeys)
                sortPath = sprintf(self.getsortpath(), sourceKeys(ii).session_date);
                if exist(sortPath,'dir')
                    if exist([sortPath 'summary.txt'],'file')
                        hasSortedData(ii) = true;
                    else
                        fprintf('%s: missing summary file\n', sourceKeys(ii).session_date);
                    end
                else
                    fprintf('%s: missing myosort directory\n', sourceKeys(ii).session_date);
                end
            end
            source = pacman.EmgChannels & sourceKeys(hasSortedData);
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            
            sortPath = sprintf(self.getsortpath(), key.session_date);
            
            % load data
            load([sortPath 'spikes'],'Spk');
            load([sortPath 'labels'],'Lab');
            load([sortPath 'templates'],'W');
            
            templateFields = fieldnames(W);
            importIdx = length(templateFields);
            while size(W.(templateFields{importIdx}),3)==0
                importIdx = importIdx-1;
            end
            templateImportField = templateFields{importIdx};
            
            if strcmp(templateImportField,'manual') && isfield(Lab,'template_matching')
                labelImportField = 'template_matching';
            else
                labelImportField = templateImportField;
            end
            
            spkFields = fieldnames(Spk);
            spkImportField = spkFields{end};
            
            spkIdx = Spk.(spkImportField);
            label = Lab.(labelImportField);
            w = W.(templateImportField);
            
            uql = unique(label);
            nUnit = size(w,3);
            
            % fetch channel numbers
            [chanNo,corruptChan] = fetch1(pacman.EmgChannels & key,...
                'emg_channel_numbers','corrupted_emg_channels');
            chanNo = setdiff(str2num(chanNo),str2num(corruptChan));
            
            % print import source
            fprintf('Importing spikes from %s, labels from %s, and templates from %s\n',...
                spkImportField, labelImportField, templateImportField)
            
            % insert motor unit data
            for unit = 1:nUnit
                
                unitKey = key;
                
                % assign smallest unoccupied id
                if count(self) == 0
                    unitKey.motor_unit_id = 1;
                else
                    ids = fetchn(self,'motor_unit_id');
                    unitKey.motor_unit_id = min(setdiff(1:1+max(ids),ids));
                end
                
                % insert new unit
                self.insert(unitKey);
                
                % insert spike indices
                unitKey.motor_unit_spike_indices = spkIdx(label==uql(unit));
                insert(pacman.MotorUnitSpikeIndices,unitKey)
                unitKey = rmfield(unitKey,'motor_unit_spike_indices');
                
                % insert template information
                for chIdx = 1:size(w,2)
                    unitKey.emg_channel = chanNo(chIdx);
                    unitKey.motor_unit_waveform = w(:,chIdx,unit)';
                    insert(pacman.MotorUnitTemplate,unitKey)
                end
                
                fprintf('Inserted motor unit %i\n',unitKey.motor_unit_id)
            end
        end
    end
    methods
        function populatedependents(~)
            populate(pacman.MotorUnitSpikes)
            populate(pacman.MotorUnitRate)
            populate(pacman.MotorUnitPsth)
        end
        function rmmyosort(self,sessRel)
            sessKey = fetch(sessRel);
            for iSess = 1:length(sessKey)
                sortPath = sprintf(self.getsortpath(), sessKey(iSess).session_date); 
                if exist(sortPath,'dir')
                    delete([sortPath '*']);
                    rmdir(sortPath)
                end                
            end            
        end
        function [Spk,Lab,W,Cinv] = loadmyosort(self,sessionDate)
            sortPath = sprintf(self.getsortpath(), sessionDate);
            load([sortPath 'spikes'],'Spk');
            load([sortPath 'labels'],'Lab');
            load([sortPath 'templates'],'W');
            load([sortPath 'noise_cov'],'Cinv');
        end
        function cmap = getcolormap(self,varargin)
            P = inputParser;
            addParameter(P,'mapFcn','brewermap',@(x) ischar(x) && ismember(x,{'brewermap','colorcet'}))
            addParameter(P,'mapName','spectral',@ischar)
            addParameter(P,'brightness',-0.1,@isscalar)
            parse(P,varargin{:})
            
            % get map
            nUnit = count(self);
            switch P.Results.mapFcn
                case 'brewermap'
                    cmap = brewermap(nUnit,P.Results.mapName);
                case 'colorcet'
                    cmap = colorcet(P.Results.mapName,'N',nUnit);
            end
            
            % adjust brightness
            cmap = max([0 0 0],cmap+P.Results.brightness);
        end       
        function curatetemplates(self,sessionDate)
            
            sessKey = struct('session_date',sessionDate);
            
            % plot forces
            plot(pacman.Force & sessKey)
            
            % sample rate
            Fs = fetch1(pacman.ContinuousRecording & sessKey, 'continuous_sample_rate');
            
            % load templates
            sortPath = sprintf(self.getsortpath(), sessionDate);
            load([sortPath 'templates'],'W');
            load([sortPath 'noise_cov'],'Cinv');
            
            % plot myosort results
            fn = fieldnames(W);
            for ii = 1:length(fn)
                plotwavetemplate(W.(fn{ii}));
                title(fn{ii})
                set(gcf,'Name',sprintf('MU templates: %s (%s)',fn{ii},sessKey.session_date))
            end
            
            % initialize working templates
            str = fn{1};
            for ii = 2:length(fn)
                if ii < length(fn)
                    str = [str ', '];
                else
                    str = [str ' or '];
                end
                str = [str, fn{ii}];
            end
            initSource = '';
            while ~ismember(initSource,fn)
                initSource = input(sprintf('Enter initialization source (%s): ',str));
                if ~ischar(initSource) || ~ismember(initSource,fn)
                    fprintf('Input not recognized. Try again.\n')
                end
            end
            w = W.(initSource);
            plotwavetemplate(w);
            fhTemplates = gcf;
            set(gcf,'Name','Working templates')
            
            newFigs = [];
            
            runLoop = true;
            while runLoop
                
                action = [];
                while ~ischar(action)
                    action = lower(input('Add new (N), delete (D), test (T), or exit (E)?: '));
                    if ~ischar(action)
                        fprintf('Input string. Try again.\n')
                    end
                end
                switch action
                    
                    case 'n'
                        unitList = input('Enter unit list {{"block1",indices}, {"block2",indices}, ...}: ');
                        for ii = 1:length(unitList)
                           w = cat(3,w,W.(unitList{ii}{1})(:,:,unitList{ii}{2}));                            
                        end
                        figure(fhTemplates)
                        clf
                        plotwavetemplate(w,'axes',gca)
                        
                    case 'd'
                        figure(fhTemplates)
                        unitList = input('Enter unit indices: ');
                        w(:,:,unitList) = [];
                        figure(fhTemplates)
                        clf
                        plotwavetemplate(w,'axes',gca)
                        
                    case 't'
                        args = input('Enter condition and trial indices: ');
                        if ~isempty(newFigs)
                            close(newFigs)
                        end                        
                        openFigs = get(groot,'Children');
                        testfit(pacman.Emg,sessKey.session_date,'w',w,'Cinv',Cinv,'cond',args{1},'trial',args{2})
                        newFigs = setdiff(get(groot,'Children'),openFigs);
                        
                    case 'e'
                        
                        % sort templates by energy
                        load([sortPath 'noise_std'],'noiseStd');
                        wEnv = smooth1D(abs(w./noiseStd'),Fs,'gau','sd',5e-4,'dim',1);
                        [~,srtIdx] = sort(squeeze(max(mean(wEnv,2),[],1)));
                        w = w(:,:,srtIdx);
                        
                        % save progress
                        W.manual = w;
                        save([sortPath 'templates'],'W')
                        
                        runLoop = false;
                        
                    otherwise
                        fprintf('Input not recognized. Try again.\n')
                end
            end
        end
    end
end