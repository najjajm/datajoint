%{
# full session EMG channel data
-> pacman.EmgChannel
---
sample_rate : smallint unsigned # sampling frequency [Hz]
emg_channel : tinyint unsigned # channel number
emg_channel_data : longblob # channel data
%}

classdef EmgChannelData < dj.Imported
    
    methods(Access=protected)
        function makeTuples(self,key)
            
            % fetch file prefix
            [fileName,chanNo] = fetch1(pacman.EmgRecording & key,'file_name','channel_numbers');
            
            % open NSx file
            nsx = openNSx(fileName,['c:' chanNo]);
            
            key.sample_rate = nsx.MetaTags.SamplingFreq;
            
            for ii = 1:size(nsx.Data,1)
                key.emg_channel = ii;
                key.emg_channel_data = nsx.Data(ii,:);
                
                % insert key to self
                self.insert(key)
            end
            
            sprintf('Populated EMG channel data for session %s',key.session_date)
        end
    end
end