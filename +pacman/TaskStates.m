%{
# task states
task_state_id : tinyint unsigned # unique task state ID number
---
task_state_name : varchar(30) # task state name
%}

classdef TaskStates < dj.Lookup
    methods
        function populate(self)
            sessKey = fetch(pacman.Session);
            for ii = 1:length(sessKey)
                rel = pacman.SpeedgoatRecording & sessKey(ii);
                if count(rel) == 1
                    T = parsespeedgoatdata(fetch1(rel,'file_prefix'),2);
                    states = T.Properties.UserData.TaskStates;
                    for jj = 1:size(states,1)
                        if count(self & ['task_state_id=' num2str(states{jj})]) == 0
                            insert(self,states(jj,:))
                        end
                    end
                end
            end
        end
    end
end