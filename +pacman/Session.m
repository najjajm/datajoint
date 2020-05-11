%{
# session
  session_date : date # session date
  -> pacman.Monkey
  ---
  -> pacman.Experimenter
  experimenter2_initials = NULL : char(3) # secondary experimenter initials
%}

classdef Session < dj.Manual
    methods    
        function populate(self)
            
            MONKEY = 'Cousteau';
            rawPath = self.getrawpath(MONKEY);
            
            % load data log
            logPath = '/Users/Najja/Documents/code/data-synthesis/DataLog.xlsx';
            opts = detectImportOptions(logPath, 'Sheet', lower(MONKEY));
            opts.VariableTypes(cellfun(@(x) strcmp(x,'saveTags'), opts.VariableNames)) = {'char'};
            Log = readtable(logPath, opts);
            fmtDate = datestr(datenum(Log.date),'yyyy-mm-dd');
            Log.date = mat2cell(fmtDate, ones(height(Log),1), length('yyyy-mm-dd'));
            
            % get dates list
            files = dir(rawPath);
            fileNames = arrayfun(@(x) x.name,files,'uni',false);
            isDate = cellfun(@(x) regexp(x,'\d{4}-\d{2}-\d{2}'),fileNames,'uni',false);
            dates = fileNames(~cellfun(@isempty,isDate));
            
            for ii = 1:length(dates)
                
                % check for speedgoat and continuous directories
                sgPath = [rawPath, dates{ii} '/speedgoat/'];
                contPath = [rawPath, dates{ii} '/blackrock/'];
                
                if exist(sgPath,'dir') && exist(contPath,'dir')
                    
                    % primary session key
                    sessKey = struct('session_date',dates{ii},'monkey_name',MONKEY);
                    if count(self & sessKey) ~= 0
                        continue
                    end
                    
                    logIdx = cellfun(@(x) strcmp(x,dates{ii}), Log.date);
                    
                    % insert new session
                    key = sessKey;
                    key.experimenter_initials = 'njm';
                    if datetime(dates{ii},'InputFormat','yyyy-MM-dd') >= datetime(2019,11,01)
                        key.experimenter2_initials = 'emt';
                    end
                    self.insert(key)
                    
                    % insert session notes
                    textFilePath = [rawPath,dates{ii} '/' self.getfileprefix(key.session_date,key.monkey_name) 'notes.txt'];
                    if exist(textFilePath,'file')
                        key = sessKey;
                        key.session_notes = fileread(textFilePath);
                        insert(pacman.SessionNotes,key)
                    end
                    
                    % populate dependents
                    populate(pacman.SpeedgoatRecording)
                    populate(pacman.ContinuousRecording)
                    populate(pacman.SyncChannel)
                    
                    % fetch continuous file name and channel count
                    [contName,nChan] = fetch1(pacman.ContinuousRecording & key,...
                        'continuous_file_name','continuous_channel_count');
                    
                    % insert EMG channel data
                    if contains(contName,'emg')
                        key = sessKey;
                        switch Log.head{logIdx}
                            case 'AD'
                                key.muscle_abbrev = 'DelAnt';
                            case 'LD'
                                key.muscle_abbrev = 'DelLat';
                            case 'CP'
                                key.muscle_abbrev = 'PecCla';
                            case 'PEC'
                                key.muscle_abbrev = 'PecSte';
                            case 'LTRI'
                                key.muscle_abbrev = 'TriLat';
                            case 'MTRI'
                                key.muscle_abbrev = 'TriMed';
                            otherwise
                                key.muscle_abbrev = [];
                        end
                        if ~isempty(key.muscle_abbrev)
                            if datetime(dates{ii},'InputFormat','yyyy-MM-dd') >= datetime(2019,11,01)
                                key.emg_electrode_abbrev = 'HookPair';
                            else
                                key.emg_electrode_abbrev = 'HookQuad';
                            end
                            if contains(contName,'emg') && ~contains(contName,'neu')
                                if strcmp(Log.expCode{logIdx},'mur-icms') && nChan == 2+Log.nLeads(logIdx)
                                    key.emg_channel_numbers = ['1:' num2str(nChan-2)];
                                    stimKey = sessKey;
                                    stimKey.stim_channel_number = num2str(nChan-1);
                                    insert(pacman.StimChannel,stimKey)
                                else
                                    key.emg_channel_numbers = ['1:' num2str(nChan-1)];
                                end
                            else
                                key.emg_channel_numbers = '129:136';
                            end
                            key.emg_channel_notes = '';
                            insert(pacman.EmgChannels,key)
                        end
                    end
                    
                    % insert neural channel data
                    if contains(contName,'neu')
                        key = sessKey;
                        key.brain_abbrev = 'M1';
                        if datetime(dates{ii},'InputFormat','yyyy-MM-dd') >= datetime(2019,11,01)
                            key.neural_electrode_abbrev = 'Neu128';
                        else
                            key.neural_electrode_abbrev = 'S32';
                        end
                        if contains(contName,'emg')
                            key.neural_channel_numbers = '1:128';
                        else
                            key.neural_channel_numbers = ['1:' num2str(nChan-1)];
                        end
                        key.neural_electrode_id = 1;
                        key.neural_electrode_depth = Log.probeDepth(logIdx);
                        key.neural_channel_notes = '';
                        insert(pacman.NeuralChannels,key)
                    end
                end
            end
        end
        function populatedependents(~)
            populate(pacman.Task)
            populate(pacman.Sync)
            populate(pacman.BehaviorQuality)
            populate(pacman.GoodTrials)
            populate(pacman.Force)
            populate(pacman.Emg)
%             importkilosort(pacman.Neuron)
%             importmyosort(pacman.MotorUnit)
%             populate(pacman.NeuronSpikes)
%             populate(pacman.NeuronRate)
%             populate(pacman.NeuronPsth)

        end
    end
    methods(Static)
        function rawPath = getrawpath(monkeyName)
            rawPath = ['/Volumes/NJM5TB/data/' lower(monkeyName) '/raw/']; %['/Volumes/Churchland-locker/Jumanji/pacman-task/' lower(monkeyName) '/raw/'];
        end
        function procPath = getprocpath(monkeyName)
            procPath = ['/Volumes/Churchland-locker/Jumanji/pacman-task/' lower(monkeyName) '/processed/']; 
        end
        function filePrefix = getfileprefix(sessionDate,monkeyName)
            filePrefix = ['pacman-task_' lower(monkeyName(1)) '_' sessionDate([3,4,6,7,9,10]) '_'];
        end
        function stampfig(sessionDate)
            ax = gca;
            ax.Units = 'pixels';
            fh = gcf;
            th = text;
            th.Units = 'pixels';
            th.HorizontalAlignment = 'center';
            th.FontSize = 15;
            th.Position = [fh.Position(1), -ax.Position(2)/2];
            th.String = sessionDate;            
        end
    end
end