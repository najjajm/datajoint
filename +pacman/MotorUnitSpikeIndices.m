%{
# motor unit spike indices
  -> pacman.MotorUnit
  ---
  motor_unit_spike_indices : longblob # spike indices
%}

classdef MotorUnitSpikeIndices < dj.Part
    properties(SetAccess=protected)
        master = pacman.MotorUnit
    end
    methods
        function Spk = loadmyosort(~,sessionDate)
            myosortPath = ['/Volumes/Churchland-locker/Jumanji/pacman-task/cousteau/processed/',...
                sessionDate '/myosort-out/'];
            load([myosortPath 'spikes'],'Spk');
        end
    end
end