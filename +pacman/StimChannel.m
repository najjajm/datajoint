%{
# stim TTL channel on continuous recording file
  -> pacman.ContinuousRecording
  ---
  stim_channel_number : varchar(4) # channel number [char]
%}

classdef StimChannel < dj.Manual
end