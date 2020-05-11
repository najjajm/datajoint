%{
# Speedgoat Recording
  -> pacman.Session
  ---
  speedgoat_file_path : varchar(500) # file path
  speedgoat_file_prefix : varchar(200) # file name
  speedgoat_sample_rate : smallint unsigned # sample rate
%}

classdef SpeedgoatRecording < dj.Imported
    methods(Access=protected)
        function makeTuples(self, key)
                        
            % fetch raw data path
            rawPath = pacman.Session.getrawpath(key.monkey_name);
            
            % path to speedgoat files
            key.speedgoat_file_path = [rawPath, key.session_date '/speedgoat/'];
            
            % speedgoat file prefix
            key.speedgoat_file_prefix = [pacman.Session.getfileprefix(key.session_date,key.monkey_name) 'beh'];
            
            % sample rate in samples/sec (should be consistent across sessions)
            key.speedgoat_sample_rate = 1e3;
            
            % save results and insert
            self.insert(key);
        end
    end
end