%{
# Ephys filter parameters
filt_name : varchar(12) # short hand abbreviation (LP/HP/BP_lowCut_highCut)
---
filt_type : enum('low','high','bandpass') # filter type
low_cut = NULL : smallint unsigned # low cut frequency [Hz]
high_cut = NULL : smallint unsigned # high cut frequency
%}

classdef EphysFilterParams < dj.Lookup
end