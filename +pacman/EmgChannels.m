%{
# EMG channels on continuous recording file
  -> pacman.ContinuousRecording
  -> pacman.Muscle
  ---
  -> pacman.EmgElectrodes
  emg_channel_numbers : varchar(10) # string of channel numbers (indexed by continuous recording)
  emg_channel_notes : varchar(1000) # notes for these channels
  corrupted_emg_channels = NULL : varchar(50) # string of corrupted emg channels (indexed by EMG channels)
%}

classdef EmgChannels < dj.Manual
    methods
        % load EMG data from file into an Ephys object
        function Eph = load(self,tLim,mode)
            if count(self) ~= 1
                error('Expecting one entry')
            end
            [filePath,fileName,chanNo,timeStamp,corruptChan] = fetch1(pacman.ContinuousRecording * self * pacman.SyncChannel,...
                'continuous_file_path','continuous_file_name','emg_channel_numbers','time_stamp','corrupted_emg_channels');
            fullFile = [filePath,fileName];
            chanNo = num2str(setdiff(str2num(chanNo),str2num(corruptChan)));
            if nargin == 1
                nsx = openNSx(fullFile,['c:' chanNo]);
            elseif nargin == 2
                nsx = openNSx(fullFile,['c:' chanNo],['t:' tLim]);
            else
                nsx = openNSx(fullFile,['c:' chanNo],['t:' tLim],mode);
            end
            nsx.Data(:,1:timeStamp) = [];
            Eph = Ephys(nsx.MetaTags.SamplingFreq,nsx.Data');
        end
        % export EMG recording data
        function export(self,savePath)
            EmgRec = struct2table(fetch(pacman.ContinuousRecording * self,'*'));
            if nargin == 1
                savePath = [pwd, filesep];
            end
            save([savePath 'emg_recording_data'],'EmgRec')
        end
        % update list of corrupted channels
        function updatecorrupted(self)
            primaryKeys = fetch(self);
            corruptedChannels = cell(length(primaryKeys),1);
            corruptedChannels(:) = {''};
            for ii = 1:length(primaryKeys)
                % plot forces
                plottrials(pacman.Force & primaryKeys(ii))
                
                % get conditions
                condKeys = fetch(pacman.TaskConditions & primaryKeys(ii));
                targIDs = arrayfun(@(x) x.targ_id,condKeys);
                
                action = 'replot';
                while strcmp(action,'replot')
                    
                    % plot EMG for random condition
                    plot(pacman.Emg,'session_date',primaryKeys(ii).session_date,...
                        'targ_id',datasample(targIDs,1));
                    
                    res = input('Next session (1), new plot (2), updated corrupted channels (3), or exit loop (4)?: ');
                    while ~any(ismember(res,1:4))
                        fprintf('Error. Action not recognized. Try again\n')
                        res = input('Next session (1), new plot (2), updated corrupted channels (3), or exit loop (4)?: ');
                    end
                    switch res
                        case 1
                            action = 'break';
                            close all
                            pause(1)
                            
                        case 2
                            action = 'replot';
                            close(gcf)
                            pause(1)
                            
                        case 3
                            action = 'break';
                            corruptedChannels{ii} = input('Enter new list of corrupted channels: ');
                            close all
                            pause(1)
                            
                        case 4
                            action = 'exit';
                    end
                end
                
                if strcmp(action,'exit')
                    break
                end
            end
            
            fullKeys = cell(length(primaryKeys),1);
            for ii = 1:length(primaryKeys)
                fullKeys{ii} = fetch(self & primaryKeys(ii),'*');
                fullKeys{ii}.corrupted_emg_channels = corruptedChannels{ii};
            end
            fullKeys = cell2mat(fullKeys);
            
            updatedKey = ~arrayfun(@(x) strcmp(x.corrupted_emg_channels,''),fullKeys);
            
            del(self & primaryKeys(updatedKey))
            insert(self,fullKeys(updatedKey))
        end
    end
end