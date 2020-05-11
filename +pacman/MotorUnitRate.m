%{
  # trialized and aligned motor unit firing rates
  -> pacman.MotorUnitSpikes
  ---
  motor_unit_rate : longblob # aligned firing rates (logical)
%}

classdef MotorUnitRate < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch sample rates
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            FsCont = fetch1(pacman.ContinuousRecording & key,'continuous_sample_rate');
            
            % fetch time vectors
            tSg = maketarget(pacman.TaskConditions & (pacman.TaskTrials & key),FsSg);
            tCont = maketarget(pacman.TaskConditions & (pacman.TaskTrials & key),FsCont);
            
            % fetch spikes
            s = fetch1(pacman.MotorUnitSpikes & key,'motor_unit_spikes');
            
            if ~any(s)
                key.motor_unit_rate = zeros(size(tSg));
            else
                % filter
                r = FsCont * smooth1D(double(s),FsCont,'gau','sd',25e-3);
                
                % downsample
                key.motor_unit_rate = interp1(tCont,r,tSg);
            end
            
            % save results and insert
            self.insert(key);
        end
    end
    methods
        function plot(self,varargin)
            P = inputParser;
            addParameter(P,'chan',[],@(x) isempty(x) || isnumeric(x))
            addParameter(P,'cond',1,@isscalar)
            addParameter(P,'trial',1,@(x) isnumeric(x) || (ischar(x) && strcmp(x,'rand')))
            addParameter(P,'unit',[],@(x) isempty(x) || isscalar(x))
            addParameter(P,'newFig',true,@islogical)
            parse(P,varargin{:})
            
            % get condition key
            condKey = sort(pacman.TaskConditions & (pacman.TaskTrials & self & sessKey));
            condKey = condKey(P.Results.cond);
            
            % fetch trial
            trialIndices = fetchn(pacman.GoodTrials & (pacman.TaskTrials & (pacman.TaskConditions & sessKey & condKey)),'trial_index');
            if strcmp(P.Results.trial,'rand')
                
            end
            
            % assign target
            targKey = sort(pacman.TaskConditions & (pacman.TaskTrials & self));
            targKey = targKey(P.Results.cond);
            
            % assign trials
            trials = fetchn(pacman.TaskTrials & self & targKey,'trial_number');
            if isnumeric(P.Results.trial)
                trialIdx = unique(min(max(1,P.Results.trial),length(trials)));
            else
                trialIdx = datasample(trials,1);
            end
            
            % motor unit colormap
            muKey = fetch(pacman.MotorUnit & targKey,'motor_unit_id');
            cmap = brewermap(length(muKey),'Spectral');
            cmap = max([0 0 0],cmap-.2);
            fh = zeros(1,size(cmap,1));
            
            if P.Results.newFig
                figure
            else
                clf
            end
            hold on
            
            for tr = 1:length(trialIdx)
                
                key = targKey;
                key.trial_number = trials(trialIdx(tr));
                
                % fetch target time
                FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
                t = maketarget(pacman.TaskConditions & self & key,FsSg);
                
                for un = 1:length(muKey)
                    r = fetch1(self & key & muKey(un),'motor_unit_rate');
                    plot(t,r,'color',cmap(un,:))
                end
            end            
        end
    end
end