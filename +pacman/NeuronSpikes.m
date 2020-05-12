%{
  # trialized and aligned neural spikes
  -> pacman.NeuronSpikeIndices
  -> pacman.Sync
  ---
  neuron_spikes : longblob # aligned spike raster (logical)
%}

classdef NeuronSpikes < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch alignment indices
            alignIdx = fetch1(pacman.Sync & key, 'continuous_alignment');
            
            % fetch spikes
            spkIdx = fetch1(pacman.NeuronSpikeIndices & key, 'neuron_spike_indices');
            
            % bin spike counts
            key.neuron_spikes = logical(histcounts(spkIdx,[alignIdx,1+alignIdx(end)]));
            
            % save results and insert
            self.insert(key);
        end
    end
    methods
       % -----------------------------------------------------------------
        % PLOT SPIKE RASTERS
        % -----------------------------------------------------------------
        function plotrast(self,varargin)
            P = inputParser;
            addParameter(P,'buffer',0.5,@(x) isnumeric(x) && x>0)
            addParameter(P,'legend',true,@islogical)
            addParameter(P,'tickDur',[],@(x) isempty(x) || isnumeric(x))
            addParameter(P,'lineWidth',1,@isnumeric)
            parse(P,varargin{:})
            
            rel = self * pacman.TaskTrials * pacman.TaskConditions;
            targID = unique(fetchn(rel,'targ_id'));
            
            for ii = 1:length(targID)
                
                targKey = struct('targ_id',targID(ii));
                
                keys = fetch(pacman.TaskConditions & targKey);
                FsCont = fetch1(pacman.ContinuousRecording & keys(1),'continuous_sample_rate');
                t = maketarget(pacman.TaskConditions & keys(1), FsCont);
                
                unitID = unique(fetchn(rel & targKey,'neuron_id'));
                
                for jj = 1:length(unitID)
                    figure
                    hold on
                    s = fetchn(rel & targKey & ['neuron_id=' num2str(unitID(jj))],'neuron_spikes');
                    for kk = 1:length(s)
                        plot(t(s{kk}==1),(kk-1),'k.')
                    end
                end
            end
            
            
%             s = obj.spikes;
%             t = obj.time;
%             
%             cmap = obj.unit_colors(-0.2);
%             hold on
%             
%             unitNo = P.Results.unit;
%             nUnit = length(unitNo);
%             unitNo = fliplr(unitNo);
%             
%             [trialNo,lineNo] = deal(repmat((1:obj.nTrials)',1,nUnit));
%             
%             ySpace = ceil(P.Results.buffer*obj.nTrials);
%             lineBuff = (obj.nTrials+ySpace)*(0:nUnit-1);
%             lineBuff(2:end) = lineBuff(2:end)-1;
%             lineNo = lineNo + lineBuff;
%             
%             trialNo = trialNo(:);
%             lineNo = fliplr(lineNo);
%             lineNo = lineNo(:);
%             
%             ySampIdx = repmat(round(linspace(1,obj.nTrials,min(obj.nTrials,3)))',1,nUnit);
%             ySampIdx = ySampIdx + (obj.nTrials)*(0:nUnit-1);
%             ySampIdx = fliplr(ySampIdx);
%             ySampIdx = ySampIdx(:);
%             
%             if ~isempty(P.Results.tickDur)
%                 tickLen = round(P.Results.tickDur*obj.Fs);
%             end
%             
%             fh = zeros(1,nUnit);
%             for ii = 1:nUnit
%                 for jj = 1:obj.nTrials
%                     sIdx = find(s(:,unitNo(ii),jj));
%                     if isempty(sIdx)
%                         continue
%                     end
%                     lNo = lineNo(jj+obj.nTrials*(ii-1));
%                     if isempty(P.Results.tickDur)
%                         fh(ii) = plot(t(sIdx),lNo*ones(1,length(sIdx)),'.','color',cmap(unitNo(ii),:));
%                     else
%                         sIdx(sIdx+(tickLen-1) > length(t)) = [];
%                         for kk = 1:length(sIdx)
%                             fh(ii) = plot(t(sIdx(kk)+[0 tickLen-1]),lNo*[1 1],'color',cmap(unitNo(ii),:),'linewidth',P.Results.lineWidth);
%                         end
%                     end
%                 end
%             end
%             set(gca,'xlim',t([1 end]))
%             set(gca,'ylim',[0 1+max(lineNo)])
%             
%             set(gca,'ytick',lineNo(ySampIdx))
%             set(gca,'yticklabel',cellfun(@num2str,num2cell(trialNo(ySampIdx)),'uni',false))
%             ylabel('trial')
%             
%             if P.Results.legend
%                 legTxt = cellfun(@(n) sprintf('MU %i',n), num2cell(unitNo), 'uni',false);
%                 legend(fh(fh~=0),legTxt(fh~=0),'location','best')
%             end
        end 
    end
end