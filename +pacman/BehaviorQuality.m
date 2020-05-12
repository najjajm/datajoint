%{
  # behavioral quality metrics
  -> pacman.Force
  ---
  max_err_target : decimal(6,4) # maximum (over time) absolute error, normalized by the range of the target force
  max_err_mean : decimal(6,4) # maximum (over time) absolute z-scored error
  mah_dist_target : decimal(6,4) # Mahalanobis distance relative to the target force
  mah_dist_mean : decimal(6,4) # Mahalanobis distance relative to the trial average
%}

classdef BehaviorQuality < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            N_FEAT = 3;
            
            % condition key
            condKey = fetch(pacman.TaskConditions & (pacman.TaskTrials & key));
            
            % make target force
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            [~,y] = maketarget(pacman.TaskConditions & condKey, FsSg);
            y = y';
            
            % fetch all trial forces and trial numbers for this block
            [X,trialNo] = fetchn(pacman.Force & (pacman.TaskTrials & condKey),'force_filt','trial_number');
            if iscell(X)
                X = cell2mat(X)';
            end
            nTrial = length(trialNo);
            
            % max absolute error relative to the target range
            maxErr = max(abs(X-y)/max(2,range(y)),[],1);
            
            % absolute z-scored error
            sd = std(X,[],2);
            sd(sd==0) = 1;
            errZScore = max(abs(X-mean(X,2))./sd,[],1);
            
            % Mahalanobis distance relative to target
            if nTrial <= N_FEAT
                dMahTarg = zeros(size(trialNo));
            else
                Z = X-y;
                [~,pcs] = pca(Z);
                Zp = pcs(:,1:3)'*Z;
                Zpc = Zp - mean(Zp,2);
                Sinv = cov(Zpc')^(-1);
                dMahTarg = zeros(size(Zp,2),1);
                for ii = 1:length(dMahTarg)
                    dMahTarg(ii) = sqrt(Zpc(:,ii)'*Sinv*Zpc(:,ii));
                end
            end
            
            % compute Mahalanobis distance relative to trial average
            if nTrial <= N_FEAT
                dMahMean = zeros(size(trialNo));
            else
                Z = X-mean(X,2);
                [~,pcs] = pca(Z);
                Zp = pcs(:,1:3)'*Z;
                Zpc = Zp - mean(Zp,2);
                Sinv = cov(Zpc')^(-1);
                dMahMean = zeros(size(Zp,2),1);
                for ii = 1:length(dMahMean)
                    dMahMean(ii) = sqrt(Zpc(:,ii)'*Sinv*Zpc(:,ii));
                end
            end
            
            % save results and insert
            for ii = 1:nTrial
                key.trial_number = trialNo(ii);
                key.max_err_target = maxErr(ii);
                key.max_err_mean = errZScore(ii);
                key.mah_dist_target = dMahTarg(ii);
                key.mah_dist_mean = dMahMean(ii);
                self.insert(key);
            end
        end
    end
    methods
        function ploterrdist(self)
            % get secondary attributes
            keys = fetch(self);
            secondaryAttr = setdiff(fieldnames(fetch(self & keys(1),'*')),...
                fieldnames(fetch(self & keys(1))));
            nColumns = 1+length(secondaryAttr);
            % plot            
            sessKey = fetch(pacman.Session & self);
            for iS = 1:length(sessKey)
                FsSg = fetch1(pacman.SpeedgoatRecording & sessKey(iS),'speedgoat_sample_rate');
                targID = sort(pacman.TaskConditions & sessKey(iS));
                maxForce = fetchn(pacman.TaskConditions & sessKey(iS),'force_max');
                yl = [-4 ceil(1.2*max(maxForce))];
                figure
                nRows = length(targID);
                for row = 1:nRows
                    key = sessKey(iS);
                    key.targ_id = targID(row);
                    rel = self & (pacman.TaskTrials * (pacman.TaskConditions & key));
                    [t,targFn] = maketarget(pacman.TaskConditions & key,FsSg);
                    for col = 1:nColumns
                        subplot(nRows,nColumns,col+(row-1)*nColumns)
                        if col == 1
                            plot(t,targFn,'k')
                            xlim(t([1 end]))
                            ylim(yl)
                            ylabel(sprintf('targ: %i',key.targ_id))
                            if row == 1
                                title('target force')
                            end
                        else
                            attr = secondaryAttr{col-1};
                            X = fetchn(rel,attr);
                            if contains(attr,'mah')
                                edges = 0:0.5:6;
                            else
                                edges = 0:0.1:2;
                            end
                            histogram(X,edges)
                            if row == 1
                                title(replace(attr,'_',' '))
                            end
                        end
                        drawnow
                    end
                end
                subplot(nRows,nColumns,1+(nRows-1)*nColumns)
                pacman.Session.stampfig(sessKey(iS).session_date);
                set(gcf,'Name',['Behavior Quality (' sessKey(iS).session_date ')'])
            end
        end
    end
end