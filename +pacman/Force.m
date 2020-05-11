%{
  # aligned force data
  -> pacman.Sync
  ---
  force_raw = NULL : longblob # aligned raw force data
  force_filt = NULL : longblob # offline filtered, aligned, and calibrated force data [Newtons]
%}

classdef Force < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            % assign aligned raw force to key
            [key.force_filt,~,key.force_raw] = convertforce(pacman.TaskTrials & key);
            
%             % fetch block ID
%             blockRel = pacman.SessionBlock & key;
%             if count(blockRel) == 1
%                 key.block_id = fetch1(blockRel, 'block_id');
%             else
%                 saveTag = fetch1(pacman.TaskTrials & key, 'save_tag');
%                 saveTagKey = fetch(blockRel,'*');
%                 key.block_id = saveTagKey(arrayfun(@(stk) ismember(saveTag,str2num(stk.save_tag_set)), saveTagKey)).block_id;
%             end
            
            % save results and insert
            self.insert(key);
        end
    end
    methods
        function plot(self,varargin)
            P = inputParser;
            addParameter(P, 'cond', [], @(x) isempty(x) || isnumeric(x))
            addParameter(P, 'trials', true, @islogical)
            addParameter(P, 'mean', true, @islogical)
            addParameter(P, 'sem', false, @islogical)
            addParameter(P, 'target', false, @islogical)
            addParameter(P, 'fig', 'figure', @(x) ischar(x) && ismember(x,{'figure','clf'}))
            addParameter(P, 'showCount', true, @islogical)
            addParameter(P, 'yInt', 4, @isscalar)
            parse(P,varargin{:})
            
            sessKey = fetch(pacman.Session & self);
            
            for iS = 1:length(sessKey) % loop sessions
                
                % trial sample frequency
                tSim = fetchn(pacman.TaskTrials & sessKey(iS), 'simulation_time');
                FsSG = mode(round(1./diff(tSim{1})));
                
                % target condition table
                rel = pacman.TaskConditions & (self * pacman.TaskTrials & sessKey(iS));
                
                % get condition keys
                condKey = sort(rel);
                nCond = length(condKey);
                
                % subplot settings
                eval(P.Results.fig)
                nCol = ceil(sqrt(nCond));
                nRow = ceil(nCond/nCol);
                
                % force range
                X = fetchn(self & sessKey(iS),'force_filt');
                frcMax = max(cellfun(@max,X));
                forceRange = [-P.Results.yInt, P.Results.yInt+(frcMax-rem(frcMax,P.Results.yInt))];
                
                for jC = 1:nCond % loop conditions
                    subplot(nRow,nCol,jC)
                    hold on
                    [t,targFrc] = maketarget(rel & condKey(jC),FsSG);
                    X = cell2mat(fetchn((self & sessKey(iS)) * pacman.TaskTrials & condKey(jC),'force_filt'));
                    if P.Results.trials
                        plot(t,X','color',0.8*ones(1,3));
                    end
                    if P.Results.sem
                        mu = mean(X,1);
                        ste = std(X,[],1)/sqrt(max(1,size(X,1)-1));
                        plot(t,mu-ste,'r--')
                        plot(t,mu+ste,'r--')
                    end
                    if P.Results.mean
                        plot(t,mean(X,1),'k','LineWidth',2)
                    end
                    if P.Results.target
                        plot(t,targFrc,'c--','linewidth',2)
                    end
                    if P.Results.showCount
                       text(t(1)+0.025*range(t), mean([forceRange(1),0]), sprintf('n = %i',size(X,1)))
                    end
                    plot(t([1 end]),[0 0],'color',.8*[1 1 1])
                    title(sprintf('condition %i\n(ID: %i)',jC,condKey(jC).targ_id))
                    xlim(t([1 end]))
                    ylim(forceRange);
                    box off
                    drawnow
                end
                subplot(nRow,nCol,1+(nRow-1)*nCol);
                pacman.Session.stampfig(sessKey(iS).session_date);
                set(gcf,'Name',['Forces (' sessKey(iS).session_date ')'])
            end
        end
        
    end
end