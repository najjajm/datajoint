%{
  # session blocks
  -> pacman.Session
  block_id : tinyint unsigned # block number (unique within session)
  ---
  -> pacman.Postures
  save_tag_set : varchar(30) # list of save tags associated with each block
%}

classdef SessionBlock < dj.Manual
    methods
        % convert a list of save tags to an array of keys
        function key = saveTagStr2Key(~,str)
            val = str2num(str);
            if isempty(val)
                fprintf('Invalid string: %s. Ensure convertable to numeric array\n',str)
                key = [];
                return
            end
            key = cellfun(@(n) struct('save_tag',n),num2cell(val(:)));
        end
        function populate(self)
            keys = fetch(pacman.Session-self);
            for ii = 1:length(keys)
                
                % display notes
                if count(pacman.SessionNotes & keys(ii)) > 0
                    fetch1(pacman.SessionNotes & keys(ii),'session_notes')
                else
                    fprintf('Missing notes\nSession: %s',keys(ii).session_date)
                end
                fprintf('\n')
                
                % display trial counts per save tag
                [saveTags,validTrial,successfulTrial] = fetchn(pacman.TaskTrials & keys(ii),...
                    'save_tag','valid_trial','successful_trial');
                saveTags = saveTags(validTrial & successfulTrial);
                uqTag = unique(saveTags);
                uqTagCount = cellfun(@(st) nnz(saveTags==st), num2cell(uqTag));
                fprintf('Save Tag -- Trial Count\n')
                for jj = 1:length(uqTag)
                    fprintf('%i -- %i\n',uqTag(jj),uqTagCount(jj))
                end
                fprintf('\n')
                
                % prompt session block
                res = input('Enter session block {{postureID_block1, saveTagStr_block1}, {postureID_block2, saveTagStr_block2}, ...}: ');
                for jj = 1:length(res)
                    insert(self,{keys(ii).session_date, keys(ii).monkey_name, jj, res{jj}{1}, res{jj}{2}})
                end
                fprintf('\n')
            end
        end
        function export(self)
            
        end
    end
end