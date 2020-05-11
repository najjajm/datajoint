%{
# neuron spike indices
  -> pacman.Neuron
  ---
  neuron_spike_indices : longblob # spike indices
%}

classdef NeuronSpikeIndices < dj.Part
    properties(SetAccess=protected)
        master = pacman.Neuron
    end
end