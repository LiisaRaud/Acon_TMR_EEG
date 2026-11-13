%% Preprocessing
close all; clear all; clc; 

%% NB! Saving of epoched data is turned off, not to overwrite datasets that have additional been manual cleaning

%% Path to EEGLAB and ICLabel plugin

eeglabpath = '/XXX/EEG/eeglab2020_0/';
%addpath(eeglabpath)

%plugin_path = 'XXX/EEG/eeglab2020_0/plugins/ICLabel/viewprops';
%addpath(plugin_path)
%eeglab nogui


%% Paths' definitions

%input path
basepath_in = [];  % Path to raw EEG data in cluster                                                                          

%output paths
basepath_out = [];
outpath_cont_filt = [basepath_out, 'a_continuous_filt_reref/'];
outpath_epochs_artrej = [basepath_out, 'b_allepochs_artrej_ICAweights/'];
outpath_epoch_clean = [basepath_out, 'c_allepochs_clean'];


%% Preprocessing settings
%Filtering settings
highpassEEG = 0.1;
lowpassEEG = 35;

highpassEMG = 10;
lowpassEMG = 100;

highpassECG = 0.1;
lowpassECG = 70;

%Epoch length in seconds  
epochlength = [-1.5 5];

%Baseline correction periode in milliseconds
baseline = [-200 0]; 

%Threshold for probability based artifact rejection ( standard deviations);
%different for task and sleep data (as the latter has larger variation due
%to differences between sleep stages)
probthresh = 5; 
probthresh_sleep = 8; 


%Thresholds for IC rejecteion (IClabel); will only be applied to task data
ICthresh_eye = 0.7;
ICthresh_muscle = 0.9;


%% Filenames
allfiles = dir(fullfile(basepath_in, '**', '*'));  
allfiles = allfiles(~[allfiles.isdir]); % Remove directories from the list
allfiles = fullfile({allfiles.folder}, {allfiles.name})'; % Get full file paths
allfiles = allfiles(~contains(allfiles, '.fdt')); %remove .fdt files
allfiles = allfiles(~contains(allfiles, '.png')); %remove .png files
allfiles = allfiles(~contains(allfiles, 'acq-eegfmri')); %remove data collected in the fmri scanner

%Load information about bad channels
fname_badchans = ['sleep_qualitycontrol.xlsx'];
dat_badchans = readtable(fname_badchans);

%Keep fonly sleep data
allfiles = allfiles(contains(allfiles, 'task-sleep')); 


%% Initiate warninglog
warninglog = {};

%% Preprocessing pipeline
for f = 1:length(allfiles)

    %% File details
    %Extract filename
    fname = allfiles(f);

    %Extract subid, session, and task phase
    fname_split = split(fname, '/');
    fname_bids = fname_split{end};
    fname_bids = split(fname_bids, '_');
    subid = fname_bids{1};
    ses = fname_bids{2};
    task = fname_bids{4};

    %% Load data
    EEG = pop_loadset('filename', fname);
    EEG.processinginfo = [];

    %% For few datasets with wrong workspace on aquisition, change sampling rate
    if EEG.srate ~= 250
        EEG = pop_resample( EEG, 250);
    end

    %% Step1: Channel interpolations (sleep only), referencing, channel locations, filtering

    %CHANNEL LOCATIONS
    EEG = pop_chanedit(EEG, 'lookup',[eeglabpath, 'plugins/dipfit/standard_BESA/standard-10-5-cap385.elp']);

    %CHANNEL INTERPOLATION (SLEEP ONLY)
    if strcmp(task, 'task-sleep')
        %Find information for subject-ID
        tmp_badchan = dat_badchans(dat_badchans.subID == str2double(subid(5:end)),:);

        if ~(strcmp('none', tmp_badchan.finalchannels) | isempty(tmp_badchan.finalchannels))
            %Find bad channel indices
            tmp_badchan = strtrim(strsplit(tmp_badchan.finalchannels{1}, ',')); 
            [~, ~, tmp_badchan_ind] = intersect(tmp_badchan, {EEG.chanlocs.labels});

            %Interpolate channels
            EEG = pop_interp(EEG, tmp_badchan_ind, 'spherical');

            %Save information about interpolated channels
            EEG.processinginfo.interpolatedchans = tmp_badchan;
        end

    end
    

    %RE-REFERENCING
    %Default eeglab implementation seems to be buggy when trying to re-reference separate channels. Thus extract EOG and EMG channels
    %separately and then add these again to the main structrure to make sure the implementation
    %is correct

    %First, reference everything to average mastoids and add FCz an additional channel
    tmp_mastoid_chans = find(startsWith({EEG.chanlocs.labels}, 'M'));
    EEG = pop_chanedit(EEG, 'append',32,'changefield',{33,'labels','FCz'},'setref',{'1:33','FCz'});
    EEG = pop_reref(EEG, [tmp_mastoid_chans] ,'refloc',struct('labels',{'FCz'},'type',{''},'theta',{[]},'radius',{[]},'X',{[]},'Y',{[]},'Z',{[]},'sph_theta',{[]},'sph_phi',{[]},'sph_radius',{[]},'urchan',{[]},'ref',{'FCz'},'datachan',{0},'sph_theta_besa',{[]},'sph_phi_besa',{[]}));


    %Second, extract EOG channels and reference them against FP1; then add channels back to the original structure
    tmp_EOGchans = find(startsWith({EEG.chanlocs.labels}, 'EOG'));
    EOG = pop_select(EEG, 'channel',{'Fp1','EOG1','EOG2'});
    EOG = pop_reref(EOG, 1);
    EEG.data(tmp_EOGchans,:) = EOG.data;

    %Third, extract EMG channels, reference these against EMG3, add back to the original structure and delete EMG3 from the original structure
    tmp_EMGchans = find(startsWith({EEG.chanlocs.labels}, 'EMG'));
    if ~isempty(tmp_EMGchans)  %some participants are missing EMG+ECG channels due to false cap/workspace during recording
        EMG = pop_select(EEG, 'channel',{'EMG1','EMG2','EMG3'});
        EMG = pop_reref(EMG, 3);
        EEG.data(tmp_EMGchans(1:2),:) = EMG.data;
        EEG = pop_select(EEG, 'nochannel',{'EMG3'});
    else
        warningmsg = [subid, ' ' task, ' missing EMG channels; no EMG re-referencing'];
        warninglog = [warninglog; warningmsg];
    end

    %CHANNEL INDICES AFTER RE-REFERENCING
    EEGchans = find(~startsWith({EEG.chanlocs.labels}, 'EMG') & ~startsWith({EEG.chanlocs.labels}, 'ECG') & ~startsWith({EEG.chanlocs.labels}, 'EOG'));
    EEG_EOGchans = find(~startsWith({EEG.chanlocs.labels}, 'EMG') & ~startsWith({EEG.chanlocs.labels}, 'ECG'));
    EMGchans = find(startsWith({EEG.chanlocs.labels}, 'EMG'));
    EOGchans = find(startsWith({EEG.chanlocs.labels}, 'EOG'));
    ECGchan = find(startsWith({EEG.chanlocs.labels}, 'ECG'));

    %FOR A FEW PARTICIPANTS, FCz (original reference) NEEDS INTERPOLATION
    if strcmp(task, 'task-sleep') && any(strcmp('FCz', tmp_badchan))
        EEG = pop_chanedit(EEG, 'lookup',[eeglabpath, 'plugins/dipfit/standard_BESA/standard-10-5-cap385.elp']); %re-do channel locations for FCz
        tmp_badchan_ind = find(strcmp('FCz', {EEG.chanlocs.labels}));
        EEG = pop_interp(EEG, tmp_badchan_ind, 'spherical');
    end
  
    %FILTERING
    EEGoriginal = EEG;

    %EEG + EOG channels
    EEG = pop_select(EEG, 'channel',EEG_EOGchans);
    EEG = pop_eegfiltnew(EEG, 'locutoff', highpassEEG);
    EEG = pop_eegfiltnew(EEG, 'hicutoff', lowpassEEG);
    EEGoriginal.data(EEG_EOGchans,:) = EEG.data;

    %EMG channels
    if ~isempty(EMGchans) %some participants are missing EMG+ECG channels due to false cap/workspace during recording
        EMG = pop_select(EEGoriginal, 'channel',EMGchans);
        EMG = pop_eegfiltnew(EMG, 'locutoff', highpassEMG);
        EMG = pop_eegfiltnew(EMG, 'hicutoff', lowpassEMG);
        EEGoriginal.data(EMGchans,:) = EMG.data;
    else
        warningmsg = [subid, ' ' task, ' missing EMG channels; no EMG filtering'];
        warninglog = [warninglog; warningmsg];
    end

    %ECG channel
    if ~isempty(ECGchan) %some participants are missing EMG+ECG channels due to false cap/workspace during recording
        ECG = pop_select(EEGoriginal, 'channel',ECGchan);
        ECG = pop_eegfiltnew(ECG, 'locutoff', highpassECG);
        ECG = pop_eegfiltnew(ECG, 'hicutoff', lowpassECG);
        EEGoriginal.data(ECGchan,:) = ECG.data;
    else
        warningmsg = [subid, ' ' task, ' missing ECG channel, no ECG filtering'];
        warninglog = [warninglog; warningmsg];
    end
    
    EEG = EEGoriginal;
    clear EEGoriginal EMG ECG tmp*

    % intermittent saving
    tmp_fname = fullfile([char(join(fname_bids(1:4), '_')), '_ContFiltReref.set']);
    tmp_path = fullfile(outpath_cont_filt, subid);
    if ~exist(tmp_path, 'dir'); mkdir(tmp_path); end
    EEG = pop_saveset( EEG, 'filename', tmp_fname, 'filepath', tmp_path);
    clear tmp*


    %% Step 2: epoching and artifact rejection 
    % Automatic artifact rejection is only done on task data, as sleep-data
    % will be semiautomatically screened for artifacts and stimulation
    % during non-rem sleep
    
    %Find all strings with stimulus onset
    uniqueEvents = unique({EEG.event.type});
    eventInd = find(contains(uniqueEvents, 'stimonset'));
    events = uniqueEvents(eventInd);

    %Epoch to stimulus onset
    EEG = pop_epoch( EEG, events, epochlength, 'newname', 'Epoched_AllTrials', 'epochinfo', 'yes');

    %for one subject, encoding epoching results in the first trial going
    %'missing', remove from triallog
    if strcmp(subid, 'sub-XXX') && strcmp(task, 'task-encoding')
        EEG.triallog(1,:) = [];
    end

    %Baseline correction
    EEG = pop_rmbase( EEG, baseline ,[]);

    %Automatic artifact rejection
    if ~strcmp(task, 'task-sleep')
        EEG = pop_jointprob(EEG, 1, EEGchans, probthresh, probthresh, 1, 1, 1,[],0);
    elseif ~isempty(EEG.data) %saveguarding against data with no TMR
        EEG = pop_jointprob(EEG, 1, EEGchans, probthresh_sleep, probthresh_sleep, 1, 1, 1,[],0);
    end
    EEG.processinginfo.rejectedtrials = find(EEG.reject.rejjp);

    %% Step 3: run ICA (excluding sleep data)
    if ~strcmp(task, 'task-sleep')
        %Run ICA on EEG-channels
        EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','off', 'chanind', EEGchans);


        % intermittent saving
        tmp_fname = fullfile([char(join(fname_bids(1:4), '_')), '_EpochArtRejICAweights.set']);
        tmp_path = fullfile(outpath_epochs_artrej, subid);
        if ~exist(tmp_path, 'dir'); mkdir(tmp_path); end
        EEG = pop_saveset( EEG, 'filename', tmp_fname, 'filepath', tmp_path);
        clear tmp*

        % automatic eye-IC and muscle-IC rejection 
        EEG = pop_iclabel(EEG, 'default');
        EEG = pop_icflag(EEG, [NaN NaN; ICthresh_muscle 1; ICthresh_eye 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
        EEG.processinginfo.rejectedIC = find(EEG.reject.gcompreject);
        EEG = pop_subcomp( EEG, EEG.processinginfo.rejectedIC, 0);
    end

    %% Save cleaned epoched data

    tmp_fname = fullfile([char(join(fname_bids(1:4), '_')), '_EpochClean.set']);
    tmp_path = fullfile(outpath_epoch_clean, subid);
    if ~exist(tmp_path, 'dir'); mkdir(tmp_path); end
    EEG = pop_saveset( EEG, 'filename', tmp_fname, 'filepath', tmp_path);
    clear tmp*

end
%save('EEG_preprocessing_acqeeg_warninglog_sleep.mat', 'warninglog')

    
 
