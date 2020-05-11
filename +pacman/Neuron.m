%{
# cortical neuron
  -> pacman.NeuralChannels
  neuron_id : smallint unsigned # unique unit ID
  ---
  neuron_label : enum('good','mua')
%}

classdef Neuron < dj.Manual
    methods
        function importkilosort(self)
            PROC_PATH = '/Volumes/Churchland-locker/Jumanji/pacman-task/cousteau/processed/';
            
            % get keys for sessions with neural recordings
            neuKey = fetch(pacman.NeuralChannels);
            
            for ii = 1:length(neuKey)
                
                % skip sessions that already have neurons
                if count(self & neuKey(ii))
                    continue
                end
                % check for kilosort folder
                kilosortPath = [PROC_PATH, neuKey(ii).session_date '/kilosort-manually-sorted/'];
                if ~exist(kilosortPath,'dir')
                    continue
                end
                
                % load kilosort data
                tSpk = readNPY([kilosortPath 'spike_times.npy']);
                clus = readNPY([kilosortPath 'spike_clusters.npy']);
                label = tdfread([kilosortPath 'cluster_group.tsv'],'\t');
                label.group = mat2cell(label.group, ones(size(label.group,1),1), size(label.group,2));
                label.group = cellfun(@(x) strtrim(x), label.group, 'uni',false);
                
                for jj = 1:length(label.group)
                    if any(ismember(label.group{jj},{'good','mua'}))
                        
                        key = neuKey(ii);
                        
                        if count(self) == 0
                            key.neuron_id = 1;
                        else
                            ids = fetchn(self,'neuron_id');
                            key.neuron_id = min(setdiff(1:1+max(ids),ids));
                        end
                        key.neuron_label = label.group{jj};
                        
                        % insert neuron information
                        self.insert(key)
                        
                        % insert spike indices
                        key = rmfield(key,'neuron_label');
                        key.neuron_spike_indices = tSpk(clus==label.cluster_id(jj));
                        insert(pacman.NeuronSpikeIndices,key)
                        
                        fprintf('Inserted neuron %i\n',key.neuron_id)
                    end
                end
            end
        end
        % -----------------------------------------------------------------
        % PLOT FIRING RATES
        % -----------------------------------------------------------------
        function plotrates(obj,varargin)
            P = inputParser;
            addParameter(P,'unit',1:obj.nUnits,@(x) isnumeric(x) && min(x)>0 && max(x)<=obj.nUnits)
            addParameter(P,'trial',1:obj.nTrials,@(x) isnumeric(x) && min(x)>0 && max(x)<=obj.nTrials)
            parse(P,varargin{:})
            
            fr = obj.rate;
            t = obj.time(size(fr,1),obj.filtSamplingFrequency);
            
            nUnit = length(P.Results.unit);
            nCol = ceil(sqrt(nUnit));
            nRow = ceil(nUnit/nCol);
            nTrial = length(P.Results.trial);
            shade = linspace(0.25,0.75,nTrial);
            for ii = 1:nUnit
                if nUnit > 1
                    subplot(nRow,nCol,ii)
                end
                hold on
                for jj = 1:nTrial
                    plot(t,fr(:,P.Results.unit(ii),P.Results.trial(jj)),'color',shade(jj)*ones(1,3))
                end
            end
            set(gca,'xlim',t([1 end]))
            xlabel('time (s)')
            ylabel('firing rate (Hz)')
        end
        % -----------------------------------------------------------------
        % PLOT PSTH
        % -----------------------------------------------------------------
        function plotpsth(self,varargin)
            P = inputParser;
            addParameter(P,'unit',1:obj(1).nUnits,@(x) isnumeric(x) && min(x)>0 && max(x)<=obj(1).nUnits)
            addParameter(P,'cond',1:length(obj),@isnumeric)
            addParameter(P,'fig',[],@(x) ischar(x) && ismember(x,{'clf','new'}))
            addParameter(P,'label',[],@ischar)
            addParameter(P,'tLim',[-Inf,Inf],@(x) isnumeric(x) && length(x)==2)
            addParameter(P,'legend',true,@islogical)
            parse(P,varargin{:})
            
            if ~isempty(P.Results.fig)
                if strcmp(P.Results.fig,'clf')
                    clf
                elseif strcmp(P.Results.fig,'new')
                    figure
                end
            end
            
            nUnit = size(obj(1).psth,2);   
            cmap = obj.unit_colors;
            nCond = length(P.Results.cond);
            nCol = ceil(sqrt(nCond));
            nRow = ceil(nCond/nCol);
            
            absRMax = max(arrayfun(@(x) max(max(x.psth(:,:,1))),obj));
            for ii = 1:nCond
                if nCond > 1
                    subplot(nRow,nCol,ii)
                end
                cNo = P.Results.cond(ii);
                
                y = obj(cNo).psth;
                t = obj(cNo).time(size(y,1),obj(cNo).filtSamplingFrequency);
                
                tIdx = t>=P.Results.tLim(1) & t<=P.Results.tLim(2);
                t = t(tIdx);
                y = y(tIdx,:,:);
                
                fh = zeros(1,nUnit);
                hold on
                for jj = 1:length(P.Results.unit)
                    unitNo = P.Results.unit(jj);
                    fh(jj) = plot(t,y(:,unitNo,1),'color',cmap(unitNo,:),'linewidth',3);
                    patch([t,fliplr(t)], [permute(sum(y(:,unitNo,:),3),[2 1 3]),...
                        fliplr(permute(-diff(y(:,unitNo,:),[],3),[2 1 3]))], cmap(unitNo,:),...
                        'EdgeAlpha',0, 'FaceAlpha',0.125)
                end
                set(gca,'xlim',t([1 end]))
                set(gca,'ylim',[0 max(1,round(1.1*absRMax))]) % max(1,1.1*max(max(sum(y,3))))])
                xlabel('time (s)')
                ylabel('firing rate (Hz)')
                title(sprintf('condition %i',cNo))
                
                if ii == 1 && P.Results.legend
                    legText = cellfun(@(n) sprintf('unit %i',n),num2cell(P.Results.unit),'uni',false);
                    legend(fh(fh>0),legText(fh>0),'location','NorthWest')
                end
            end
            if ~isempty(P.Results.label)
                subplot(nRow,nCol,1+(nRow-1)*nCol)
                th = text(0,0,P.Results.label);
                th.Units = 'normalized';
                th.Position = [-.1 -.2];
                th.FontSize = 12;
            end
        end
    end
end