%{
# EMG recording electrodes
  emg_electrode_abbrev : varchar(20) # unique electrode abbreviation
  ---
  emg_electrode_manufacturer : varchar(50) # electrode manufacturer
  emg_electrode_name : varchar(100) # full electrode name
  emg_electrode_channel_count : smallint unsigned # total number of active recording channels on the electrode
%}

classdef EmgElectrodes < dj.Lookup
end