%{
# motor unit waveform templates
  -> pacman.MotorUnit
  emg_channel : tinyint unsigned # EMG channel number
  ---
  motor_unit_waveform : longblob # waveform signature
%}

classdef MotorUnitTemplate < dj.Part
    properties(SetAccess=protected)
        master = pacman.MotorUnit
    end
    methods
        function plotmyosort(~,sessRel)
            sessKey = fetch(sessRel);
            for iSess = 1:length(sessKey)
                sortPath = sprintf(pacman.MotorUnit.getsortpath(), sessKey(iSess).session_date);
                if exist([sortPath 'templates.mat'],'file')
                    load([sortPath 'templates'],'W');
                    fn = fieldnames(W);
                    for ii = 1:length(fn)
                        plotwavetemplate(W.(fn{ii}));
                        title(fn{ii})
                        set(gcf,'Name',sprintf('MU templates: %s (%s)',fn{ii},sessKey(iSess).session_date))
                    end
                end
            end
        end
        function plot(self)
            sessKey = fetch(pacman.Session & self);
            for iSess = 1:length(sessKey)
               unitKey = fetch(pacman.MotorUnit & sessKey(iSess));
               w = cell(1,1,length(unitKey));
               for iUnit = 1:length(unitKey)
                   w{iUnit} = fetchn(self & sessKey(iSess) & unitKey(iUnit),'motor_unit_waveform');
                   if iscell(w{iUnit})
                       w{iUnit} = cell2mat(w{iUnit});
                   end
                   w{iUnit} = w{iUnit}';
               end
               w = cell2mat(w);
               plotwavetemplate(w);
               set(gcf,'Name',sprintf('MU templates (%s)',sessKey(iSess).session_date))
            end
        end
    end
end