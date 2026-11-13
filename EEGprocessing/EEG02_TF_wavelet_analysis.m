clear; close all; clc

%% eeglab path
%eeglabpath = '/XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui

%% Path definition
basepath = [];

inpath_eeg = [basepath,'c_allepochs_clean/'];
inpath_stageinfo = [data/BEHAV/'];

outpath = [basepath,'d_timefrequency/singletrial/'];
mkdir(outpath)



%% filenames

filenames = dir(fullfile(inpath_eeg, '**', '*'));  
filenames = filenames(~[filenames.isdir]); % Remove directories from the list
filenames = fullfile({filenames.folder}, {filenames.name})'; % Get full file paths
filenames = filenames(~contains(filenames, '.fdt')); %remove .fdt files
filenames = filenames(contains(filenames, 'task-sleep') | contains(filenames, 'task-encoding')); %rkeep only encoding and/or sleep data


%% discard participants

%no TMR
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));
filenames = filenames(~contains(filenames, 'sub-XXX'));


%% TF parameters
tf_freqrange = [1 20]; %the lower limit is decided by the freq resolution fitting into the intertrial interval
tf_cycles = [1, 0.5]; %linearly increasing cycles, starting with 1 at the lowest frequency and 10 at the highest
tf_ntimesout = 200;
tf_nfreqsout = 40;
tf_baseline = NaN; %tf is run on all trials without condition information, so no baseline correction is necessary at this point

tf_chaninds = [1:24, 30]; %run TF in all EEG channels (excl. EOG, EMG, ECG)
tf_numchans = length(tf_chaninds);

%% Initiate warninglog
warninglog = {};

%%

for f = 1:length(filenames)
    %Process filenames
    fname = filenames(f);

    %ectract subid, session, and task phase
    fname_split = split(fname, '/');
    fname_bids = fname_split{end};
    fname_bids = split(fname_bids, '_');
    subid = fname_bids{1};
    ses = fname_bids{2};
    task = fname_bids{4};

    %load eeg data
    EEG = pop_loadset('filename', fname);


    %for some participants, wrong workspace was used and the channels don't
    %match with the rest; create empty channels to match with the previous
    %channels
    if EEG.nbchan == 27
        EEG.data = cat(1,...  %conatenate along channels
            EEG.data(1:26,:,:), ...
            nan(3, size(EEG.data,2), size(EEG.data,3)), ... %add EMG + ECG channels as nans
            EEG.data(27,:,:));
    end

    if strcmp(task, 'task-sleep')
        %for sleep data,  load triallogs with sleep stage info
        fname_stageinfo = [inpath_stageinfo, subid, '/', ses, '/with_eeg_timing/', ...
            char(join(fname_bids(1:4), '_')), '_log_sleepstages.csv'];
        stageinfo = readtable(fname_stageinfo);

        %Replace EEG.triallog with stage info
        EEG.triallog = stageinfo;

        %Reject trials in triallogs that were previously rejected as
        %artefacts (EEG) from data
        EEG.triallog_clean = EEG.triallog;
        EEG.triallog_clean(EEG.processinginfo.rejectedtrials,:) = [];

        %Additionally reject trials marked for manual rejection
        if isfield(EEG.processinginfo, 'rejectedtrials_manuals') && ~isempty(EEG.processinginfo.rejectedtrials_manuals)
            EEG.data(:,:,EEG.processinginfo.rejectedtrials_manuals) = [];
            EEG.triallog_clean(EEG.processinginfo.rejectedtrials_manuals,:) = [];
            EEG.epoch(EEG.processinginfo.rejectedtrials_manuals) = [];
            EEG.trials = size(EEG.data,3);
        end

        %check that triallog matches with eeg
        if size(EEG.triallog_clean, 1) == EEG.trials
        else
            warningmsg = [subid, ' ' task, ' trials do not match (step1 sleep), do not trust the data'];
            warninglog = [warninglog; warningmsg];
        end


        %find trials that were not played during NREM
        trials_not_nrem = find(~(EEG.triallog_clean.sleepstage == 2 | EEG.triallog_clean.sleepstage == 3));

        %find trials marked as artifacts by YASA
        trials_yasa_art = find(EEG.triallog_clean.yasa_artefact == 1);

        %combine trils to discard
        trials_discard= unique([trials_not_nrem; trials_yasa_art]);

        %Discard actual trials
        EEG.data(:,:,trials_discard) = [];
        EEG.triallog_clean(trials_discard,:) = [];
        EEG.trials = size(EEG.data,3);
        EEG.epoch(trials_discard) = [];

    else %for encoding
        %Reject trials in triallogs that were previously rejected as
        %artefacts (EEG) from data
        EEG.triallog_clean = EEG.triallog;
        EEG.triallog_clean(EEG.processinginfo.rejectedtrials,:) = [];

        %Additionally reject trials marked for manual rejection
        if isfield(EEG.processinginfo, 'rejectedtrials_manuals') && ~isempty(EEG.processinginfo.rejectedtrials_manuals)
            EEG.data(:,:,EEG.processinginfo.rejectedtrials_manuals) = [];
            EEG.triallog_clean(EEG.processinginfo.rejectedtrials_manuals,:) = [];
            EEG.epoch(EEG.processinginfo.rejectedtrials_manuals) = [];
            EEG.trials = size(EEG.data,3);           
        end
    end



    if checktrialmatching(EEG) %check that the triallog matched with the data


        %Initialize subject TF data
        EEG.TF.tfdata = nan(tf_numchans, tf_nfreqsout, tf_ntimesout, size(EEG.data,3));

        for ch = 1:length(tf_chaninds) %loop over channels
            %Extract channel data
            tmpdata = EEG.data(tf_chaninds(ch),:,:);

            %wavelet decomposition
            [ersp,itc,powbase,times,freqs,erspboot,itcboot,tfdata] = ...
                newtimef(tmpdata, size(tmpdata,2), [EEG.times(1)  EEG.times(end)], EEG.srate, tf_cycles,...
                'timesout',tf_ntimesout , 'freqs', tf_freqrange, 'nfreqs', tf_nfreqsout, 'baseline', tf_baseline, ...
                'plotersp', 'off', 'plotitc', 'off');

            %store channel data (single trials)
            EEG.TF.tfdata(ch,:,:,:) = tfdata;

        end %end channels

        %Store other TF infor
        EEG.TF.times = times;
        EEG.TF.freqs = freqs;
        if EEG.nbchan == 27 %a few participants were collected with a wrong workspace, missing EMG channels
            tmp_tf_chaninds = [1:24, 27];
            EEG.TF.chans = {EEG.chanlocs(tmp_tf_chaninds).labels};
        else
            EEG.TF.chans = {EEG.chanlocs(tf_chaninds).labels};
        end
        toc
    else
        warningmsg = [subid, ' ' task, ' trials do not match, do not trust the data'];
        warninglog = [warninglog; warningmsg];


    end %end checking that trials match

    %Save TF data
    tmp_fname = fullfile([char(join(fname_bids(1:4), '_')), '_TFsingletrial.set']);
    tmp_path = fullfile(outpath, subid);
    if ~exist(tmp_path, 'dir'); mkdir(tmp_path); end
    EEG = pop_saveset( EEG, 'filename', tmp_fname, 'filepath', tmp_path, 'version', '7.3');
    clear tmp* EEG

end

%% Save warninglog

%save('TF_trialmatching_warninglog.mat', 'warninglog')




