%% Manual artefact rejection for selected sleep data
close all; clear all; clc; 


%% eeglab path
%eeglabpath = 'XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui

%% path definitions

basepath = [];
in_outpath = [basepath, 'c_allepochs_clean'];


%% filenames
allfiles = dir(fullfile(in_outpath, '**', '*'));  
allfiles = allfiles(~[allfiles.isdir]); % Remove directories from the list
allfiles = fullfile({allfiles.folder}, {allfiles.name})'; % Get full file paths
allfiles = allfiles(~contains(allfiles, '.fdt')); %remove .fdt files
allfiles = allfiles(~contains(allfiles, '.png')); %remove .png files
allfiles = allfiles(~contains(allfiles, 'acq-eegfmri')); %remove data collected in the fmri scanner
%allfiles = allfiles(contains(allfiles, 'task-sleep')); %only keep sleep data


%% participant data
% changed manually to load data only from participants (one-by-one) for
% whom TF data looked noisy

%Define subID
subid = ['XXX'];
%task = 'task-encoding';
task = 'task-sleep';

%find participant data
fname = allfiles(contains(allfiles, subid)); 
fname = fname(contains(fname, task)); 


%load data
EEG = pop_loadset('filename', fname);

%copy data and temporariliy discard ECG/EMG for better visualization
EEGcopy = EEG;
EEGcopy = pop_select( EEGcopy, 'rmchannel',{'EMG1','EMG2','ECG', 'EOG1', 'EOG2'});


%open GUI for visualization/artefact rejection
pop_eegplot( EEGcopy, 1, 1, 0);

%---MANUAL INSPECTION, MARK TO-REJECT-EPOCHS---

%save epoch-indices marked for manual rejection (it appears eeglab-gui
%saves these into the EEG structure by default, not into the EEGcopy)
EEG.processinginfo.rejectedtrials_manuals = find(EEG.reject.rejmanual);

%re-save data (no artefacts rejected, but information stored in
%EEG.processinginfo)
EEG = pop_saveset(EEG, 'savemode', 'resave');

