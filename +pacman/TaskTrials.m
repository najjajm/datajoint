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
        % -----------------------------------------------------------------
        % PLOT TRIAL COUNTS
        % -----------------------------------------------------------------
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