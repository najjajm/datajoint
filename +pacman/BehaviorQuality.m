%{
  # behavioral quality metrics
  -> pacman.TaskTrials
  -> pacman.Sync
  -> pacman.SessionBlock
  ---
  max_err_target : decimal(6,4) # maximum (over time) absolute normalized error relative to the target force
  max_err_mean : decimal(6,4) # maximum (over time) absolute z-scored error
  mah_dist_target : decimal(6,4) # Mahalanobis distance relative to the target force
  mah_dist_mean : decimal(6,4) # Mahalanobis distance relative to the trial average
%}

classdef BehaviorQuality < dj.Computed
    properties(Dependent)
        keySource
    end
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch save tag keys for this block
            blockKeys = saveTagStr2Key(pacman.SessionBlock,...
                fetch1(pacman.SessionBlock & key,'save_tag_set'));

            % append block key data to save tag keys
            for ii = 1:length(blockKeys)
                keyFields = fieldnames(fetch(pacman.SessionBlock & key));
                for jj = 1:length(keyFields)
                    blockKeys(ii).(keyFields{jj}) = key.(keyFields{jj});
                end
            end
            
            % fetch key for this target
            targKey = fetch(pacman.TaskConditions & (pacman.TaskTrials & key));
            
            % make target force
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            [~,y] = maketarget(pacman.TaskConditions & targKey, FsSg);
            y = y';
            
            % fetch all trial forces and trial numbers for this block
            rel = pacman.TaskTrials & pacman.Sync & pacman.SessionBlock & blockKeys & targKey;
            [X,trialKeys] = convertforce(rel);
            
            if length(trialKeys) < 3
                for ii = 1:length(trialKeys)
                    key.trial_number = trialKeys(ii).trial_number;
                    key.max_err_target = 0;
                    key.max_err_mean = 0;
                    key.mah_dist_target = 0;
                    key.mah_dist_mean = 0;
                    self.insert(key);
                end
            else
                X = cell2mat(X)';
                
                % compute absolute error relative to the target
                maxErr = zeros(size(trialKeys));
                for ii = 1:length(maxErr)
                    maxErr(ii) = max(abs(X(:,ii)-y))/max(2,range(y));
                end
                
                % compute absolute z-scored error
                errZScore = max(abs(X-mean(X,2))./std(X,[],2),[],1);
                
                % compute Mahalanobis distance relative to target
                Z = X-y;
                [~,pcs] = pca(Z);
                Zp = pcs(:,1:3)'*Z;
                Zpc = Zp - mean(Zp,2);
                Sinv = cov(Zpc')^(-1);
                dMahTarg = zeros(size(Zp,2),1);
                for ii = 1:length(dMahTarg)
                    dMahTarg(ii) = sqrt(Zpc(:,ii)'*Sinv*Zpc(:,ii));
                end
                
                % compute Mahalanobis distance relative to trial average
                Z = X-mean(X,2);
                [~,pcs] = pca(Z);
                Zp = pcs(:,1:3)'*Z;
                Zpc = Zp - mean(Zp,2);
                Sinv = cov(Zpc')^(-1);
                dMahMean = zeros(size(Zp,2),1);
                for ii = 1:length(dMahMean)
                    dMahMean(ii) = sqrt(Zpc(:,ii)'*Sinv*Zpc(:,ii));
                end
                
                % save results and insert
                for ii = 1:length(trialKeys)
                    key.trial_number = trialKeys(ii).trial_number;
                    key.max_err_target = maxErr(ii);
                    key.max_err_mean = errZScore(ii);
                    key.mah_dist_target = dMahTarg(ii);
                    key.mah_dist_mean = dMahMean(ii);
                    self.insert(key);
                end
            end
        end
    end
    methods
        % restrict force trials that belong to defined session blocks
        function source = get.keySource(self)
            blockKeys = fetch(pacman.SessionBlock);
            sourceKeys = cell(size(blockKeys));
            for ii = 1:length(blockKeys)
                % add save tag keys
                sourceKeys{ii} = saveTagStr2Key(pacman.SessionBlock,...
                    fetch1(pacman.SessionBlock & blockKeys(ii),'save_tag_set'));
                % copy block key data to save tag keys
                blockFields = fieldnames(blockKeys(ii));
                for jj = 1:length(sourceKeys{ii})
                    for kk = 1:length(blockFields)
                        sourceKeys{ii}(jj).(blockFields{kk}) = blockKeys(ii).(blockFields{kk});
                    end
                end
            end
            sourceKeys = cat(1,sourceKeys{:});
            source = pacman.TaskTrials * pacman.Sync * pacman.SessionBlock & sourceKeys;
        end
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