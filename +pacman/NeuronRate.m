%{
  # trialized and aligned neural firing rates
  -> pacman.NeuronSpikes
  ---
  neuron_rate : longblob # aligned firing rates (logical)
%}

classdef NeuronRate < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch sample rates
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            FsCont = fetch1(pacman.ContinuousRecording & key,'continuous_sample_rate');
            
            % fetch time vectors
            tSg = maketarget(pacman.TaskConditions & (pacman.TaskTrials & key),FsSg);
            tCont = maketarget(pacman.TaskConditions & (pacman.TaskTrials & key),FsCont);
            
            % fetch spikes
            s = fetch1(pacman.NeuronSpikes & key,'neuron_spikes');
            
            if ~any(s)
                key.neuron_rate = zeros(size(tSg));
            else
                % filter
                r = FsCont * smooth1D(double(s),FsCont,'gau','sd',25e-3);
                
                % downsample
                key.neuron_rate = interp1(tCont,r,tSg);
            end
            
            % save results and insert
            self.insert(key);
        end
    end
end