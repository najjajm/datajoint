%{
  # neuron trial-averaged firing rates
  -> pacman.NeuronSpikeIndices
  -> pacman.TaskConditions
  -> pacman.SessionBlock
  ---
  neuron_psth : longblob # aligned psth
%}

classdef NeuronPsth < dj.Computed
    properties(Dependent)
        keySource
    end
    methods
        % restrict to conditions and session blocks with defined "good trials"
        function source = get.keySource(~)
            source = (pacman.NeuronSpikeIndices * pacman.TaskConditions * pacman.SessionBlock)...
                & pacman.GoodTrials;
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch alignment indices for this block
            rel = pacman.Sync & (pacman.GoodTrials * pacman.TaskTrials & key);
            alignIdx = fetchn(rel, 'speedgoat_alignment');
            
            % fetch spikes
            spkIdx = fetch1(pacman.NeuronSpikeIndices & key, 'neuron_spike_indices');
            
            % bin spike counts
            s = cell2mat(cellfun(@(ai) histcounts(spkIdx,[ai,1+ai(end)]),alignIdx,'uni',false));
            
            % fetch sample rates
            FsSg = fetch1(pacman.SpeedgoatRecording & key,'speedgoat_sample_rate');
            
            % trial-average and filter
            key.neuron_psth = FsSg * smooth1D(mean(s,1),FsSg,'gau','sd',25e-3);
            
            % save results and insert
            self.insert(key);
        end
    end
end