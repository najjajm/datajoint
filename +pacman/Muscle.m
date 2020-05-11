%{
# muscle list
muscle_abbrev : char(6) # short hand abbreviation (NameHead)
---
muscle_name : varchar(30) # full muscle name
muscle_head : varchar(30) # head of muscle
%}

classdef Muscle < dj.Lookup
end