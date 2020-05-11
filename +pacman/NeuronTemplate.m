%{
# neuron waveform templates
-> pacman.Neuron
neural_channel : tinyint unsigned # channel number
---
neuron_waveform : longblob # waveform signature
%}

classdef NeuronTemplate < dj.Part
    properties(SetAccess=protected)
        master = pacman.Neuron
    end
end