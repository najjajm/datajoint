%{
  # trialized and aligned neural spikes
  -> pacman.TaskTrials
  -> pacman.SessionBlock
  ---
%}

classdef TrialBlocks < dj.Computed
    properties(Dependent)
        keySource
    end
    methods
        function source = get.keySource(~)

            source = pacman.TaskTrials * pacman.SessionBlock;
            sessKey = fetch(pacman.Session & source);
            for iSess = 1:length(sessKey)
                
                % get all unique block ID/save tag combinations in source
                sessRel = source & sessKey(iSess);
                idTag = zeros(count(sessRel),2);
                [idTag(:,1),idTag(:,2)] = fetchn(sessRel,'block_id','save_tag');
                unqIdTag = unique(idTag,'rows');
                
                % get valid block ID/save tag combinations
                blockRel = pacman.SessionBlock & sessKey(iSess);
                [validIds,validTags] = fetchn(blockRel,'block_id','save_tag_set');
                validIds = num2cell(validIds);
                validTags = cellfun(@str2num,validTags,'uni',false);
                validIdTags = cellfun(@(id,tags) [repmat(id,length(tags),1),tags(:)], validIds, validTags, 'uni',false);
                validIdTags = cat(1,validIdTags{:});
                
                % make keys from invalid ID/tag combinations
                invalidIdTags = setdiff(unqIdTag,validIdTags,'rows');
                invalidKeys = repmat(sessKey(iSess),size(invalidIdTags,1),1);
                for ii = 1:length(invalidKeys)
                    invalidKeys(ii).block_id = invalidIdTags(ii,1);
                    invalidKeys(ii).save_tag = invalidIdTags(ii,2);
                end
                
                % remove invalid keys from source 
                source = source - invalidKeys;
            end
        end
    end
    methods(Access=protected)
        function makeTuples(self, key)
            self.insert(key);
        end 
    end
end