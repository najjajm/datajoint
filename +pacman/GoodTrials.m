%{
  # trials with satisfactory performance
  -> pacman.BehaviorQuality
  ---
  trial_index : smallint unsigned # index of the trial number in its condition/block
%}

classdef GoodTrials < dj.Computed
    properties(Dependent)
        keySource
    end
    methods
        function source = get.keySource(~)
%             MIN_TRIAL = 10;
%             
%             QualLim = struct(...
%                 'max_err_target', [1.5, 2.5],...
%                 'max_err_mean',   [2.5, 3.5],...
%                 'mah_dist_target',[2.5, 3.5],...
%                 'mah_dist_mean',  [2.5, 3.5]);
%             fnQual = fieldnames(QualLim);
%             
%             % initialize source and compute quality score
%             source = pacman.BehaviorQuality;
%             source = source.proj('max_err_target','max_err_mean','mah_dist_target','mah_dist_mean',...
%                 '(max_err_target+max_err_mean+mah_dist_target+mah_dist_mean)/4->score');
%             
%             sessKey = fetch(pacman.Session & pacman.BehaviorQuality);
%             for iSess = 1:length(sessKey)
%                 condKey = fetch(pacman.TaskConditions & sessKey(iSess) & pacman.TaskTrials & pacman.BehaviorQuality);
%                 for iCond = 1:length(condKey)
%                     rel = source & (pacman.TaskTrials & condKey(iCond));
%                     if count(rel & cellfun(@(fn) [fn '<=' num2str(QualLim.(fn)(1))],fnQual,'uni',false)) >= MIN_TRIAL
%                         rmvKey = cellfun(@(fn) fetch(rel & [fn '>' num2str(QualLim.(fn)(1))]), fnQual,'uni',false);
%                         rmvKey = cat(1,rmvKey{:});
%                     else
%                         relKey = fetch(rel,'*');
%                         relScore = arrayfun(@(k) k.score,relKey);
%                         [~,srtIdx] = sort(relScore);
%                         rmvKey = relKey(srtIdx(min(MIN_TRIAL,count(rel)):end));
%                     end
%                     source = source-rmvKey;
%                 end
%             end
           source = pacman.BehaviorQuality & 'max_err_target<1.5' & 'max_err_mean<3' & 'mah_dist_target<3' & 'mah_dist_mean<3';
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            condKey = fetch(pacman.TaskConditions & (pacman.TaskTrials & key));
            saveTagKey = saveTagStr2Key(pacman.SessionBlock, fetch1(pacman.SessionBlock & key,'save_tag_set'));
            allTrialNo = fetchn((self.getKeySource * pacman.TaskTrials) & condKey & saveTagKey,'trial_number');
            key.trial_index = find(key.trial_number == allTrialNo);
            self.insert(key)
        end
    end
end