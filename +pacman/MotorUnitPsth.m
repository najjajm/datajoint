%{
  # motor unit trial-averaged firing rates
  -> pacman.MotorUnitSpikeIndices
  -> pacman.TaskConditions
  -> pacman.SessionBlock
  ---
  motor_unit_psth : longblob # aligned psth (mean)
  motor_unit_psth_ste : longblob # aligned psth standard error
%}

classdef MotorUnitPsth < dj.Computed
    properties(Dependent)
        keySource
    end
    methods
        % restrict to conditions and session blocks with defined "good trials"
        function source = get.keySource(~)
            source = (pacman.MotorUnitSpikeIndices * pacman.TaskConditions * pacman.SessionBlock) & (pacman.TaskTrials & pacman.GoodTrials);
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch alignment indices for this block
            rel = pacman.Sync & (pacman.GoodTrials & (pacman.TaskTrials & key));
            alignIdx = fetchn(rel, 'continuous_alignment');
            
            % fetch spikes
            spkIdx = fetch1(pacman.MotorUnitSpikeIndices & key, 'motor_unit_spike_indices');
            
            % bin spike counts
            s = cell2mat(cellfun(@(ai) histcounts(spkIdx,[ai,1+ai(end)]),alignIdx,'uni',false));
            
            % fetch sample rates
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            FsCont = fetch1(pacman.ContinuousRecording & key,'continuous_sample_rate');
            
            % fetch time vectors
            tSg = maketarget(pacman.TaskConditions & key,FsSg);
            tCont = maketarget(pacman.TaskConditions & key,FsCont);
            
            % filter spikes
            r = FsCont * smooth1D(s,FsCont,'gau','sd',25e-3,'dim',2);
            
            % downsample
            sampIdx = round(interp1(tCont,1:length(tCont),tSg));
            r = r(:,sampIdx);
            
            % compute mean and standard error
            key.motor_unit_psth = mean(r,1);
            key.motor_unit_psth_ste = std(r,[],1)/max(1,sqrt(size(r,1)-1));
            
            % save results and insert
            self.insert(key);
        end
    end
    methods
        function plot(self,sessionDate,varargin)
            P = inputParser;
            addRequired(P,'sessionDate',@ischar)
            addParameter(P,'cond',[],@isscalar)
            addParameter(P, 'unit', [], @(x) isempty(x) || isnumeric(x))
            parse(P,sessionDate,varargin{:})
            
            sessKey = struct('session_date',sessionDate);
            
            % condition key
            condKey = sort(pacman.TaskConditions & (pacman.TaskTrials & self & sessKey));
            if ~isempty(P.Results.cond)
                condKey = condKey(P.Results.cond);
            end
            nCond = length(condKey);
            
            nCol = ceil(sqrt(nCond));
            nRow = ceil(nCond/nCol);
            
            rMax = -Inf;
            
            clf
            for iCond = 1:nCond
                
                % unit keys
                muKey = fetch(self & condKey(iCond));
                if ~isempty(P.Results.unit)
                    muKey = muKey(P.Results.unit);
                end
                
                % colormap
                cmap = getcolormap(pacman.MotorUnit & muKey);
                
                % time vector
                t = maketarget(pacman.TaskConditions & condKey(iCond),...
                    fetch1(pacman.SpeedgoatRecording & sessKey,'speedgoat_sample_rate'));
                
                % plot
                subplot(nRow,nCol,iCond)
                hold on
                for iUnit = 1:length(muKey)
                    [mu,ste] = fetch1(self & muKey(iUnit),'motor_unit_psth','motor_unit_psth_ste');
                    patch([t,fliplr(t)],[mu-ste,fliplr(mu+ste)],cmap(iUnit,:),'EdgeAlpha',0,'FaceAlpha',0.125);
                    plot(t,mu,'color',cmap(iUnit,:),'LineWidth',2)
                    rMax = max(rMax,max(mu+ste));
                end
                xlim(t([1 end]))
                title(sprintf('Condition %i\n(targ ID: %i, stim ID: %i)',...
                    iCond,condKey(iCond).targ_id,condKey(iCond).stim_id))
            end
            for iCond = 1:nCond
                subplot(nRow,nCol,iCond)
                ylim([0 ceil(1.1*rMax)])
            end
            set(gcf,'Name',sprintf('MU PSTHs (%s)',sessKey.session_date))
        end
    end
end