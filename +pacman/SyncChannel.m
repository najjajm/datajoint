%{
# sync channel on continuous recording file
  -> pacman.ContinuousRecording
  ---
  sync_channel_number : varchar(4) # channel number [char]
  time_stamp : double # clock start time
  data_duration : double # recording duration in seconds
%}

classdef SyncChannel < dj.Imported
     methods(Access=protected)
        function makeTuples(self, key)
            
            % fetch continuous file path and name
            [contPath,contName] = fetch1(pacman.ContinuousRecording & key,...
                'continuous_file_path','continuous_file_name');
            
            % read NSx file
            nsx = openNSx('noread',[contPath, contName]);
            
            % save sync channel number as last channel
            key.sync_channel_number = num2str(nsx.MetaTags.ChannelCount);
            
            % read timestamp and data duration
            key.time_stamp = nsx.MetaTags.Timestamp(1);
            key.data_duration = nsx.MetaTags.DataDurationSec(1);
            
            % save results and insert
            self.insert(key);
        end
    end
end