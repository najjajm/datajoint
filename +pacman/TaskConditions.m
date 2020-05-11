%{
# task conditions
  -> pacman.Task
  targ_id : smallint unsigned # target condition ID (unique across sessions)
  stim_id : tinyint unsigned # stim condition ID (unique within sessions)
  ---
  force_polarity : tinyint # indicates whether pushing (polarity = 1) or pulling (polarity = -1) moves Pac-Man upwards
  force_max : tinyint unsigned # maximum force [Newtons]
  force_offset : decimal(5,4) # force offset to compensate for arm weight [Newtons]
  target_type : char(3) # type code
  target_offset : decimal(5,4) # offset
  target_amplitude : decimal(5,4) # amplitude
  target_duration : decimal(5,4) # duration
  target_frequency1 : decimal(5,4) # primary frequency (initial, for chirp forces)
  target_frequency2 : decimal(5,4) # secondary frequency (final, for chirp forces)
  target_power : decimal(5,4) # power exponent
  target_pad : decimal(5,4) # pad duration
  stim_current : smallint unsigned # stim current (uA)
  stim_electrode : smallint unsigned # stim electrode number
  stim_polarity : tinyint unsigned # stim polarity
  stim_pulses : tinyint unsigned # number of pulses in stim train
  stim_width1 : smallint unsigned # first pulse duration (us)
  stim_width2 : smallint unsigned # second pulse duration (us)
  stim_interphase : smallint unsigned # interphase duration (us)
  stim_frequency : smallint unsigned # stim frequency (Hz)
%}

classdef TaskConditions < dj.Part
    properties(SetAccess=protected)
        master = pacman.Task
    end
    methods
        function [t,targetForce,targID] = maketarget(self,Fs)
            
            targID = unique(fetchn(self,'targ_id'));
            [t,targetForce] = deal(cell(length(targID),1));
            
            for ii = 1:length(targID)
                
                key = fetch(self & ['targ_id=' num2str(targID(ii))],'*');
                
                t{ii} = -key.target_pad:1/Fs:(key.target_pad+key.target_duration);
                
                % indices of target and post-pad zones
                targDur = key.target_duration;
                targIdx = t{ii}>=0 & t{ii}<=targDur;
                postPadIdx = t{ii}>targDur;
                
                % construct target function
                A = double(key.force_max) * key.target_amplitude;
                targetForce{ii} = zeros(size(t{ii}));
                switch key.target_type
                    case 'RMP'
                        m = A/targDur;
                        
                        targetForce{ii} = targIdx .* (m*t{ii}) + ...
                            postPadIdx .* (A+targetForce{ii});
                        
                    case 'TRI'
                        m = A/(targDur/2);
                        
                        targetForce{ii} = (t{ii}>=0 & t{ii}<=(targDur/2)) .* (m*t{ii}) + ...
                            (t{ii}>(targDur/2) & t{ii}<=targDur) .* (-m*t{ii} + m*targDur);
                        
                    case 'POW'
                        pow = Cond.power;
                        
                        targetForce{ii} = A*(t{ii}/t{ii}(end)).^pow;
                        
                    case 'SIN'
                        om = 2*pi*key.target_frequency1;
                        
                        targetForce{ii} = targIdx .* (A/2 * (1-cos(om*t{ii}))) + ...
                            postPadIdx .* (A/2 * (1-cos(om*targDur)));
                        
                    case 'CHP'
                        k = (key.target_frequency2-key.target_frequency1)/targDur;
                        f0 = key.target_frequency1;
                        iFin = floor(1+(key.target_pad+targDur)/(t{ii}(2)-t{ii}(1)));
                        
                        targetForce{ii} = targIdx .* (A/2 * (1-cos(2*pi*t{ii}.*(f0+k/2*t{ii})))) + ...
                            postPadIdx .* ((A/2 * (1-cos(2*pi*t{ii}(iFin)*(f0+k/2*t{ii}(iFin))))) + targetForce{ii});
                end
                targetForce{ii} = targetForce{ii} + double(key.force_max) * key.target_offset;
            end
            if length(targID) == 1
                t = t{1};
                targetForce = targetForce{1};
            end
        end
        % sort target condition IDs
        function keys = sort(self)
            
            % extract all target information
            rel = self.proj('target_type','target_offset','target_frequency1',...
                'target_frequency2','stim_current','stim_electrode',...
                'abs((force_max*target_amplitude)/target_duration)->absNps',...
                'sign(target_amplitude)->ampSgn');
            [type,offset,freq1,freq2,stimCurr,stimElec,absNps,ampSgn] = ...
                fetchn(rel,'target_type','target_offset','target_frequency1',...
                'target_frequency2','stim_current','stim_electrode','absNps','ampSgn');
            
            % replace condition code with rank
            COND_RANK = {'STA','RMP','SIN','CHP'};
            for ii = 1:length(COND_RANK)
                repIdx = cellfun(@(x) strcmp(x,COND_RANK{ii}),type);
                type(repIdx) = cellfun(@(x) replace(x,COND_RANK{ii},num2str(ii)),type(repIdx),'uni',false);
            end
            type = cellfun(@str2num,type,'uni',false);
            
            % sort target values
            val = [type,num2cell(offset),num2cell(freq1),num2cell(freq2),...
                num2cell(stimCurr),num2cell(stimElec),num2cell(absNps),num2cell(ampSgn)];
            [~,sortIdx] = sortrows(val,[1 7 8 2 6 5 3 4],...
                {'ascend','ascend','descend','ascend','ascend','ascend','ascend','ascend'});
            
            % re-order keys
            keys = fetch(self);
            keys = keys(sortIdx);
        end
        function plotgrid(self)
            sessKey = fetch(pacman.Session & self);
            targID = unique(fetchn(self,'targ_id'));
            
            % mark which sessions have which targets
            X = zeros(length(sessKey),length(targID));
            for ii = 1:length(sessKey)
                for jj = 1:length(targID)
                    X(ii,jj) = count(self & sessKey(ii) & ['targ_id=' num2str(targID(jj))]);
                end
            end
            
            % plot grid
            clf
            set(gcf,'Name','Session Target Conditions')
            imagesc(X)
            colormap bone
            box off
            ax = gca;
            ax.YTick = 1:length(sessKey);
            ax.YTickLabel = arrayfun(@(x) x.session_date,sessKey,'uni',false);
            ax.XTick = 1:length(targID);
            ax.XTickLabel = cellfun(@num2str,num2cell(targID),'uni',false);
            ax.XTickLabel(1:2:end) = {[]};
            xlabel('target ID')
            title('Membership of target conditions per session')
        end
        function plotlines(self)
            targKey = sort(self);
            frcMax = max(fetchn(self,'force_max'));
            yl = [-2 ceil(1.05*frcMax)];
            nTarg = length(targKey);
            clf
            nCol = ceil(sqrt(nTarg));
            nRow = ceil(nTarg/nCol);
            for ii = 1:nTarg
                subplot(nRow,nCol,ii)
                [t,y] = maketarget(self & targKey(ii),1e3);
                plot(t,y,'k')
                xlim(t([1 end]))
                ylim(yl)
                title(sprintf('condition %i',targKey(ii).targ_id))
                drawnow
            end
        end
    end
end