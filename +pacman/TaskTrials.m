%{
# task trial data
  -> pacman.Task
  trial_number : smallint unsigned # trial number (within session)
  ---
  -> pacman.TaskConditions
  save_tag : tinyint unsigned # save tag
  valid_trial : tinyint unsigned # is valid trial (1=yes, 0=no)
  successful_trial : tinyint unsigned # is successful trial (1=yes, 0=no)
  simulation_time : longblob # absolute simulation time
  task_state : longblob # task state IDs
  force_raw_online : longblob # amplified output of load cell
  force_filt_online : longblob # online (boxcar) filtered and normalized force used to control Pac-Man
  stim : longblob # ICMS delivery
  reward : longblob # reward delivery
  photobox : longblob # photobox signal
%}

classdef TaskTrials < dj.Part
    properties(SetAccess=protected)
        master = pacman.Task
    end
    methods
        % convert raw force from volts to Newtons and filter
        function [forceFilt,keys,forceRaw] = convertforce(self)
            
            % gain settings on FUTEK amplifier
            MAX_FORCE_POUNDS = 5;
            MAX_FORCE_VOLTS = 5.095;
            
            % unit conversion
            NEWTONS_PER_POUND = 4.44822;
            
            % conversion function
            frcV2N = @(frc,frcMax,frcOff) frcMax*(((MAX_FORCE_POUNDS*NEWTONS_PER_POUND)/frcMax...
                    * (frc/MAX_FORCE_VOLTS)) - frcOff);
            
            keys = fetch(self);
            
            if isempty(keys)
                forceFilt = [];
                return
            end
            
            [forceFilt,forceRaw] = deal(cell(length(keys),1));
            for ii = 1:length(keys)
                
                FsSg = fetch1(pacman.SpeedgoatRecording & keys(ii),'speedgoat_sample_rate');
                
                % fetch alignment indices
                alignIdx = fetch1(pacman.Sync & keys(ii), 'speedgoat_alignment');
                
                % assign aligned raw force to key
                forceRaw{ii} = fetch1(self & keys(ii), 'force_raw_online');
                forceRaw{ii} = forceRaw{ii}(alignIdx);
                
                % convert raw force to Newtons
                [forceMax,forceOffset] = fetch1(pacman.TaskConditions & (self & keys(ii)),'force_max','force_offset');
                forceRaw{ii} = frcV2N(forceRaw{ii},forceMax,forceOffset);
                
                % filter force
                forceFilt{ii} = smooth1D(forceRaw{ii},FsSg,'gau','sd',25e-3);
            end
            if length(keys)==1
                forceRaw = forceRaw{1};
                forceFilt = forceFilt{1};
            end
        end
        function plottrialcounts(self)
            keys = fetch(pacman.Session & self);
            n = zeros(length(keys),1);
            for ii = 1:length(keys)
                n(ii) = count(self & keys(ii));
            end
            clf
            bar(n)
            ax = gca;
            ax.XTickLabel = arrayfun(@(x) x.session_date,keys,'uni',false);
            ax.XTickLabelRotation = 45;
            box off
        end
    end
end