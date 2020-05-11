%{
  # sync indices for aligning continuous acquisition data with Speedgoat trial data
  -> pacman.SyncChannel
  trial_number : smallint unsigned # trial number (within session; only includes those with valid alignment indices)
  ---
  alignment_index : int unsigned # alignment index (in Speedgoat time base)
  speedgoat_alignment : longblob # alignment indices for speedgoat data
  continuous_alignment : longblob # alignment indices for continuous data
%}

classdef Sync < dj.Imported
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch file name and channel number
            [filePath,fileName,chanNo,timeStamp] = fetch1(...
                pacman.ContinuousRecording * pacman.SyncChannel & key,...
                'continuous_file_path','continuous_file_name','sync_channel_number','time_stamp');
            
            % open NSx file ** NEED TO HANDLE CASES WITH MULTIPLE DATA
            % ARRAYS (E.G. 2018-10-09) **
            nsx = openNSx([filePath,fileName], ['c:' chanNo]);
            if iscell(nsx.Data)
                syncSignal = cat(2,nsx.Data{:});
            else
                syncSignal = nsx.Data;
            end
            syncSignal(1:timeStamp) = [];
            FsCont = fetch1(pacman.ContinuousRecording & key,'continuous_sample_rate');
            
            % fetch Speedgoat simulation times
            [trialNo, tSim] = fetchn(pacman.TaskTrials & key, 'trial_number', 'simulation_time');
            FsSG = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            
            % fetch trial results
            [validTrial, successfulTrial] = fetchn(pacman.TaskTrials & key, 'valid_trial', 'successful_trial');
            
            % get trial indices for continuous data
            idxLim = parsesyncsignal(FsCont, syncSignal, FsSG, tSim, validTrial&successfulTrial);
            
            % gain settings on FUTEK amplifier
            MAX_FORCE_POUNDS = 5;
            MAX_FORCE_VOLTS = 5.095;
            
            % unit conversion
            NEWTONS_PER_POUND = 4.44822;
            
            % assign key data
            for ii = 1:length(trialNo)                
                if idxLim(ii,1) > 0 && all(isfinite(idxLim(ii,:)))
                    
                    key.trial_number = trialNo(ii);
                    
                    % set alignment index
                    if fetch1(pacman.TaskTrials & key,'stim_id') > 0
                        alignIdx = find(fetch1(pacman.TaskTrials & key, 'stim'));
                    else
                        alignStateID = fetch1(pacman.TaskStates & 'task_state_name="InTarget"', 'task_state_id');
                        taskState = fetch1(pacman.TaskTrials & key, 'task_state');
                        alignIdx = find(taskState == alignStateID,1);
                    end
                    
                    if isfinite(alignIdx)

                        rel = pacman.TaskConditions & (pacman.TaskTrials & key);
                        
                        % trial time and target
                        [tSg,targFrc] = maketarget(rel,FsSG);
                        tCont = maketarget(rel,FsCont);
                        trIdxSG = round(FsSG*tSg);
                        trIdxCont = round(FsCont*tCont);
                        
                        % phase correction for dynamic conditions
                        if ~strcmp(fetch1(rel,'target_type'),'STA')
                            
                            % fetch force data
                            [frcMax,frcOff,frcRaw] = fetch1(rel * (pacman.TaskTrials & key),...
                                'force_max','force_offset','force_raw_online');
                            makeForce = @(ai,idx) frcMax*(((MAX_FORCE_POUNDS*NEWTONS_PER_POUND)/frcMax...
                                * (frcRaw(ai+idx)/MAX_FORCE_VOLTS)) - frcOff);
                            
                            % normalized mean squared error as a function of lag
                            MAX_LAG = 0.2;
                            maxLagSamp = round(FsSG*MAX_LAG);
                            lags = -maxLagSamp:maxLagSamp;
                            tIdx = find(tSg>=(tSg(1)+MAX_LAG) & tSg<=(tSg(end)-MAX_LAG));
                            targFrcTrunc = targFrc(tIdx);
                            [~,zeroIdx] = min(abs(tSg));
                            aIdx = tIdx - zeroIdx;
                            
                            normMSE = -Inf(length(lags),1);
                            for ll = 1:length(lags)
                                if (alignIdx+lags(ll)+aIdx(end)) <= length(frcRaw)
                                    forceNorm = makeForce(alignIdx+lags(ll),aIdx);
                                    forceFilt = smooth1D(forceNorm,FsSG,'gau','sd',25e-3);
                                    normMSE(ll) = 1 - sqrt(mean((forceFilt-targFrcTrunc).^2)/var(targFrcTrunc));
                                end
                            end
                            
                            % shift alignent index to maximize NMSE
                            [~,maxIdx] = max(normMSE);
                            alignIdx = alignIdx + lags(maxIdx);
                        end
                        
                        contTrialIdx = idxLim(ii,1):idxLim(ii,2);
                        contAlignment = alignIdx*round(FsCont/FsSG) + trIdxCont;
                        if contAlignment(1)>0 && contAlignment(end)<=length(contTrialIdx)
                            key.alignment_index = alignIdx;
                            key.speedgoat_alignment = alignIdx + trIdxSG;
                            key.continuous_alignment = contTrialIdx(contAlignment);
                            self.insert(key);
                        else
                            disp('')
                        end
                    end
                end
            end
        end
    end
end