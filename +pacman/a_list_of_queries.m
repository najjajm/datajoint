%% List of schema queries
%
%% Sessions

% recorded neural data and EMG
pacman.Session & (pacman.EmgChannel & pacman.NeuralChannel);

% recorded from the deltoid
pacman.Session & (pacman.EmgChannel * pacman.Muscle & 'muscle_name="deltoid"');

% recorded using a neural pixels probe
pacman.Session & (pacman.NeuralChannel * pacman.NeuralElectrodes & 'neural_electrode_name="Neuropixels"');

% sessions for which we have sorted neurons

% sessions for which we have sorted motor units

% did NOT record neural data
pacman.Session - pacman.NeuralChannel;

%% Behavior Quality

% plot forces for all sessions whose Mahalanobis distance relative to the
% mean was less than 3
plottrials(pacman.Force & (pacman.BehaviorQuality & 'mah_dist_mean<3'))


%% Emg

% plot trials where the sort error was less than X