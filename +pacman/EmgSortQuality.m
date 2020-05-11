%{
  # EMG sort quality
  -> pacman.Emg
  -> pacman.MotorUnitSpikes
  ---
  residual_energy : decimal(6,4) # normalized residual energy
%}

classdef EmgSortQuality < dj.Computed
%     properties(Dependent)
%         keySource
%     end
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch spikes
            s = fetch1(pacman.MotorUnitSpikes & key,'motor_unit_spikes');
            
            % compute normalized residual
            if any(s)
                chanKey = fetchdata(pacman.Emg & key);
                X = double(chanKey.emg_data);
                w = fetch1(pacman.MotorUnitTemplate & key,'motor_unit_waveform');
                res = X - conv(double(s),w,'same');
                key.residual_energy = sum(res.^2)/sum(X.^2);
            else
                key.residual_energy = 1;
            end
            
            % save key data
            self.insert(key);
        end
    end
    methods
%         function source = get.keySource(~)
%             source = pacman.Emg * pacman.MotorUnitSpikes & 'session_date<="2018-04-20"';
%         end
        function plot(self)
            sessKey = fetch(pacman.Session & self);
            % sessions
            % channels
            % muscles
            % motor units
            % trials
            % conditions
            
            % plot mean normalized residual by channel per session
            maxChan = max(fetchn(self,'emg_channel'));
            resEner = cell(length(sessKey),maxChan);
            for ii = 1:length(sessKey)      
                trialKey = fetch(pacman.TaskTrials & (self & sessKey(ii)));
                trialRes = zeros(length(trialKey),1);
                for jj = 1:maxChan
                    rel = self & sessKey(ii) & ['emg_channel=' num2str(jj)];
                    if count(rel)
                        for kk = 1:length(trialKey)
                            resid = fetchn(rel & trialKey(kk),'residual_energy');
                            trialRes(kk) = 1-sum(1-resid);
                        end
                        resEner{ii,jj} = trialRes;
                    end
                end
            end     
            
        end
    end
end