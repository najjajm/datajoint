%{
  # trialized and aligned motor unit spikes
  -> pacman.MotorUnitSpikeIndices
  -> pacman.Sync
  ---
  motor_unit_spikes : longblob # aligned spike raster (logical)
%}

classdef MotorUnitSpikes < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch alignment indices
            alignIdx = fetch1(pacman.Sync & key, 'continuous_alignment');
            
            % fetch spikes
            spkIdx = fetch1(pacman.MotorUnitSpikeIndices & key, 'motor_unit_spike_indices');
            
            % bin spike counts
            key.motor_unit_spikes = logical(histcounts(spkIdx,[alignIdx,1+alignIdx(end)]));
            
            % save results and insert
            self.insert(key);
        end
    end
    methods
        function plot(self)
            
        end
        function plotcv(self,sessionDate)
            sessKey = struct('session_date',sessionDate);
            muKey = fetch(pacman.MotorUnit & self & sessKey);
            targID = sort(pacman.TaskConditions & sessKey);
            nCond = length(targID);
            nTrials = zeros(nCond,1);
            for ii = 1:nCond
                nTrials(ii) = count(pacman.GoodTrials & (pacman.TaskTrials & sessKey & struct('targ_id',targID(ii))));
            end
            Fs = fetch1(pacman.ContinuousRecording & sessKey,'continuous_sample_rate');
            allCV = [];
            grp = [];
            for ii = 1:nCond
                targKey = struct('targ_id',targID(ii));
                rel = pacman.GoodTrials & (pacman.TaskTrials & sessKey & targKey);
                for jj = 1:length(muKey)
                    s = fetchn(self & muKey(jj) & rel, 'motor_unit_spikes');
                    isi = cellfun(@(x) diff(find(x))'/Fs,s,'uni',false);
                    isi = cellfun(@(x) x(x<=0.2),isi,'uni',false);
                    isi(cellfun(@length,isi)<=1) = [];
                    cv = cellfun(@(x) std(x)/mean(x),isi);
                    allCV = [allCV;cv];
                    grp = [grp; [ii*ones(length(cv),1), muKey(jj).motor_unit_id*ones(length(cv),1)]];
                end
            end
            yl = [0 ceil(max(allCV))];
            
            % plot pooled across units or conditions
            titleStr = {'all motor units','all conditions'};
            xLabStr = {'condition number','motor unit ID'};
            figure
            for ii = 1:2
                subplot(2,1,ii)
                boxplot(allCV,grp(:,ii))
                title(titleStr{ii})
                xlabel(xLabStr{ii})
                ylim(yl)
                box off
            end
            set(gcf,'Name',sprintf('MU CoV. %s. (1/2)',sessionDate))
            
            % plot for each unit and condition
            figure
            nCol = ceil(sqrt(nCond));
            nRow = ceil(nCond/nCol);
            for ii = 1:nCond
                subplot(nRow,nCol,ii)
                idx = grp(:,1)==ii;
                boxplot(allCV(idx),grp(idx,2))
                ylim(yl)
                title(sprintf('condition %i\n(ID: %i)',ii,targID(ii)))
                box off
                xlabel('motor unit ID')
            end
            set(gcf,'Name',sprintf('MU CoV. %s. (2/2)',sessionDate))
        end
    end
end