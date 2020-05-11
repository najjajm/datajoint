%{
# arm postures
  -> pacman.Monkey
  posture_id : tinyint unsigned # unique posture ID number
  ---
  elbow_angle : tinyint unsigned # elbow flexion angle (0 = fully flexed)
  shoulder_angle : tinyint unsigned # shoulder flexion angle (0 = arm by side)
%}

classdef Postures < dj.Manual
end