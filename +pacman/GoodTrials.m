%{
  # trials with satisfactory performance
  -> pacman.BehaviorQuality
  ---
%}

classdef GoodTrials < dj.Computed
    properties(Dependent)
        keySource
    end
    methods
        % filter keys by pre-defined trial blocks and behavior quality
        function source = get.keySource(~)
            
            blockKey = fetch(pacman.SessionBlock,'*');
            fn = fieldnames(blockKey(1));
            blockTag = arrayfun(@(k) saveTagStr2Key(pacman.SessionBlock,k.save_tag_set), blockKey, 'UniformOutput', false);
            for ii = 1:length(blockTag)
                for jj = 1:length(blockTag{ii})
                    for kk = 1:length(fn)
                       blockTag{ii}(jj).(fn{kk}) = blockKey(ii).(fn{kk}); 
                    end
                end
            end
            blockKey = cat(1,blockTag{:});
            
            source = pacman.BehaviorQuality & (pacman.TaskTrials & blockKey) & 'max_err_target<1.5' & 'max_err_mean<3' & 'mah_dist_target<3' & 'mah_dist_mean<3';
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            self.insert(key)
        end
    end
end