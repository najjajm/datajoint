%{
# brain regions
brain_abbrev : varchar(10) # short hand abbreviation
---
brain_name : varchar(50) # full brain region name
%}

classdef BrainRegion < dj.Lookup
end