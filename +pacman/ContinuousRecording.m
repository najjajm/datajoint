%{
# continuous recording
  -> pacman.Session
  ---
  continuous_file_path : varchar(500) # file path
  continuous_file_name : varchar(200) # file name
  continuous_sample_rate : smallint unsigned # sample rate in Hz
  continuous_channel_count : smallint unsigned # total channel count on the recording file
%}

classdef ContinuousRecording < dj.Imported
    methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch raw data path
            rawPath = pacman.Session.getrawpath(key.monkey_name);
            
            % path to speedgoat files
            key.continuous_file_path = [rawPath, key.session_date '/blackrock/'];
            
            % speedgoat file prefix
            filePrefix = pacman.Session.getfileprefix(key.session_date,key.monkey_name);
            
            % get full blackrock file name
            files = arrayfun(@(x) x.name,dir(key.continuous_file_path),'uni',false);
            matchIdx = ~cellfun(@isempty,cellfun(@(s) regexp(s,[filePrefix 'emg_001.ns\d'],'once'), files,'uni',false));
            matchIdx = matchIdx | ~cellfun(@isempty,cellfun(@(s) regexp(s,[filePrefix 'neu_001.ns\d'],'once'), files,'uni',false));
            matchIdx = matchIdx | ~cellfun(@isempty,cellfun(@(s) regexp(s,[filePrefix 'neu_emg_001.ns\d'],'once'), files,'uni',false));
            key.continuous_file_name = files{matchIdx};
            
            % get continuous sample rate
            nsx = openNSx('noread',[key.continuous_file_path, key.continuous_file_name]);
            key.continuous_sample_rate = nsx.MetaTags.SamplingFreq;
            key.continuous_channel_count = nsx.MetaTags.ChannelCount;
            
            % save results and insert
            self.insert(key);
        end
    end
end