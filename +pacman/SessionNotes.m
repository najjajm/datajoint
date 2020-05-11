%{
# save tag data
  -> pacman.Session
  ---
  session_notes : varchar(5000) # notes
%}

classdef SessionNotes < dj.Part
    properties(SetAccess=protected)
        master = pacman.Session
    end
end