%{
# neural channels on continuous recording file
  -> pacman.ContinuousRecording
  -> pacman.BrainRegion
  neural_electrode_id : tinyint unsigned # electrode number
  ---
  -> pacman.NeuralElectrodes
  neural_channel_numbers : varchar(10) # string of channel numbers
  neural_channel_notes : varchar(1000) # notes for these channels
  neural_electrode_depth = NULL : decimal(5,3) # depth of recording electrode in mm relative to tissue surface
%}

classdef NeuralChannels < dj.Manual
end