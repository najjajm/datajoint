%{
# neural recording electrodes
  neural_electrode_abbrev : varchar(20) # unique electrode abbreviation
  ---
  neural_electrode_manufacturer : varchar(50) # electrode manufacturer
  neural_electrode_name : varchar(100) # full electrode name
  neural_electrode_channel_count : smallint unsigned # total number of active recording channels on the electrode
%}

classdef NeuralElectrodes < dj.Lookup
end