%{
  # aligned force data
  -> pacman.TaskTrials
  -> pacman.Sync
  ---
  force_raw = NULL : longblob # aligned raw force data
  force_filt = NULL : longblob # offline filtered, aligned, and calibrated force data [Newtons]
%}

classdef Force < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            rel = pacman.TaskTrials * pacman.Sync & key;
            
            % gain settings on FUTEK amplifier
            MAX_FORCE_POUNDS = 5;
            MAX_FORCE_VOLTS = 5.095;
            
            % unit conversion
            NEWTONS_PER_POUND = 4.44822;
            
            % conversion function (Volts to Newtons)
            frcV2N = @(frc,frcMax,frcOff) frcMax*(((MAX_FORCE_POUNDS*NEWTONS_PER_POUND)/frcMax...
                * (frc/MAX_FORCE_VOLTS)) - frcOff);
            
            % assign aligned raw force to key
            [alignIdx, frcRaw] = fetch1(rel,'speedgoat_alignment','force_raw_online');
            frcRaw = frcRaw(alignIdx);
            
            % convert raw force to Newtons
            [forceMax,forceOffset] = fetch1(pacman.TaskConditions & rel,'force_max','force_offset');
            frcRaw = frcV2N(frcRaw,forceMax,forceOffset);
            
            % filter force
            FsSg = fetch1(pacman.SpeedgoatRecording & key, 'speedgoat_sample_rate');
            frcFilt = smooth1D(frcRaw,FsSg,'gau','sd',25e-3);
            
            % assign forces to key
            key.force_raw = frcRaw;
            key.force_filt = frcFilt;
            self.insert(key);
        end
    end
    methods
        function plot(self,varargin)
            iscode = @(x,codes) ischar(x) && ismember(x,codes);
            P = inputParser;
            addOptional(P, 'layers', {'trials','mean','count'}, @(x) iscell(x) && all(ismember(x,{'trials','mean','sem','target','count'})))
            % key selection
            addParameter(P, 'block', 'all', @(x) isnumeric(x) || (ischar(x) && strcmp(x,'all')))
            addParameter(P, 'cond', 1, @isnumeric)
            addParameter(P, 'condType', 'all', @(x) iscode(x,{'index','rand','first','last','all'}))
            addParameter(P, 'trialSet', 'good', @(x) iscode(x,{'good','bad','all'}))
            addParameter(P, 'trial', 1, @isnumeric)
            addParameter(P, 'trialType', 'all', @(x) iscode(x,{'index','rand','first','last','all'}))
            % figure setup
            addParameter(P, 'fig', 'figure', @(x) ischar(x) && ismember(x,{'figure','clf'}))
            addParameter(P, 'yInt', 4, @isscalar)
            parse(P,varargin{:})
            
            % session keys
            sessKey = fetch(pacman.Session & self);
            for iSe = 1:length(sessKey)
                
                % condition keys
                condKey = getkey(pacman.Task & sessKey(iSe),'cond','block',P.Results.block,...
                    'cond',P.Results.cond,'condType',P.Results.condType);
                nCond = length(condKey);
                
                % subplot settings
                eval(P.Results.fig)
                nCol = ceil(sqrt(nCond));
                nRow = ceil(nCond/nCol);
                
                % trial sample frequency
                tSim = fetchn(pacman.TaskTrials & sessKey(iSe), 'simulation_time');
                FsSG = mode(round(1./diff(tSim{1})));
                
                % force range
                X = fetchn(self & sessKey(iSe),'force_filt');
                frcMax = max(cellfun(@max,X));
                forceRange = [-P.Results.yInt, P.Results.yInt+(frcMax-rem(frcMax,P.Results.yInt))];
                
                for iCo = 1:nCond
                    
                    subplot(nRow,nCol,iCo)
                    hold on
                    
                    % get time vector and target force profile
                    [t,targFrc] = maketarget(pacman.TaskConditions & condKey(iCo),FsSG);
                    
                    % fetch forces from good trials
                    trialKey = getkey(pacman.Task & sessKey(iSe),'trial',...
                        'block',P.Results.block,...
                        'cond',condKey(iCo).condition_index,'condType','index',...
                        'trial',P.Results.trial,'trialType',P.Results.trialType,'trialSet',P.Results.trialSet);
                    X = cell2mat(fetchn(((self & sessKey(iSe)) * pacman.TaskTrials) & trialKey,'force_filt'));

                    if ~isempty(X)
                        if ismember('trials',P.Results.layers)
                            plot(t,X','color',0.8*ones(1,3));
                        end
                        if ismember('sem',P.Results.layers)
                            mu = mean(X,1);
                            ste = std(X,[],1)/sqrt(max(1,size(X,1)-1));
                            plot(t,mu-ste,'r--')
                            plot(t,mu+ste,'r--')
                        end
                        if ismember('mean',P.Results.layers)
                            plot(t,mean(X,1),'k','LineWidth',2)
                        end
                    end
                    if ismember('target',P.Results.layers)
                        plot(t,targFrc,'c--','linewidth',2)
                    end
                    if ismember('count',P.Results.layers)
                       text(t(1)+0.025*range(t), mean([forceRange(1),0]), sprintf('n = %i',size(X,1)))
                    end
                    plot(t([1 end]),[0 0],'color',.8*[1 1 1])
                    title(sprintf('condition %i\n(ID: %i)',iCo,condKey(iCo).targ_id))
                    xlim(t([1 end]))
                    ylim(forceRange);
                    box off
                    drawnow
                end
                subplot(nRow,nCol,1+(nRow-1)*nCol);
                pacman.Session.stampfig(sessKey(iSe).session_date);
                set(gcf,'Name',['Forces (' sessKey(iSe).session_date ')'])
            end
        end
        
    end
end