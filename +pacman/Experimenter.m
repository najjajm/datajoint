%{
# experimenter
experimenter_initials : char(3)        # unique experimenter initials
---
first_name : varchar(40)                                 # experimenter first name
middle_initial: char(1)                                  # experimenter middle initial
last_name : varchar(40)                                  # experimenter first name
%}

classdef Experimenter < dj.Manual
end