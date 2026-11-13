clear all; close all; clc

%% eeglab path
%eeglabpath = 'XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui

%% Paths' definitions

base_path = [];

%input paths
eeg_path = [base_path, /a_continuous_filt_reref/'];
hypno_path = [base_path, /automatic_sleep_scoring/'];
beh_path = [base_path, 'BEHAV/'];

%output path
figpath = [];

%% Filenames (hypnos)

allfiles = dir(fullfile(hypno_path, '**', '*'));
allfiles = allfiles(~[allfiles.isdir]); % Remove directories from the list
allfiles = fullfile({allfiles.folder}, {allfiles.name})'; % Get full file paths
allfiles = allfiles(contains(allfiles, 'raw')); %ronly keep "raw" files (yasa output)

%% Initialize sleep statistics across participants

sleepstats_all = table();


%% Loop over participants

for f = 1:length(allfiles)
    fname = allfiles{f};

    %% Extract subject information

    fname_split = split(fname, '/');
    fname_bids = fname_split{end};
    fname_bids = split(fname_bids, '_');
    subid = fname_bids{1};
    ses = fname_bids{2};
    task = fname_bids{4};

    %% Define hypnogram

    %Load hypnogram
    hypno = readtable(fname);
    hypno_orig = hypno;

    %Merge hypnograms over C3 and C4 (highest confidence determines the stage)
    confidence_bool = hypno.confidence_C4 >= hypno.confidence_C3;
    %hypno.stage_merged = hypno.stage_C3;
    %hypno.stage_merged(confidence_bool) = hypno.stage_C4(confidence_bool);
    %hypno.confidence_merged = max([hypno.confidence_C3, hypno.confidence_C4], [], 2);
    hypno.timevec_sec = hypno.epoch*30;
    hypno.hours =  (hypno.epoch * 0.5)./60;

    %Re-save hypnogram
    fname_newhypno = [fname(1:end-7), 'merged.csv'];
    writetable(hypno, fname_newhypno);

    %% Merge hypnogram with behavior

    %load EEG
    fname_eeg = [eeg_path, subid, '/', ...
        subid, '_', ses, '_acq-eeg_task-sleep_ContFiltReref.set']
    EEG = pop_loadset('filename', fname_eeg);

    if isfield(EEG,'triallog') %safeguard against no-TMR recordings
        %find trial onsets timings, relative to the recording start
        eventInd = find(contains({EEG.event.type}, 'stimonset'));
        eventlatencies = [EEG.event.latency];
        eventlatencies = eventlatencies(eventInd);
        EEG.triallog.onset_recEEG_sec = (eventlatencies./EEG.srate)';

        %match with the hypnogram
        EEG.triallog.sleepstage = nan(size(EEG.triallog,1),1);
        EEG.triallog.sleepstage_confidence = nan(size(EEG.triallog,1),1);
        EEG.triallog.yasa_artefact = zeros(size(EEG.triallog,1),1);
        EEG.triallog.sleepepoch = nan(size(EEG.triallog,1),1);
        for tr = 1:size(EEG.triallog,1)
            tmp_TMRtime = EEG.triallog.onset_recEEG_sec(tr);
            stage_ind = find(hypno.timevec_sec <= tmp_TMRtime, 1, 'last');
            EEG.triallog.sleepstage(tr) = hypno.stage_merged(stage_ind);
            EEG.triallog.sleepstage_confidence(tr) = hypno.confidence_merged(stage_ind);
            EEG.triallog.sleepepoch(tr) = hypno.epoch(stage_ind);
            if strcmp(hypno.artifact{stage_ind}, 'True')
                EEG.triallog.yasa_artefact(1);
            end
        end
        clear tmp* tr

        %For epochs associated with awakenings, N1, or REM sleep, only assign the last
        %three trials in the epoch as such (on the assumption that the
        %experimenters stopped TMR after sudden stage change); assign previous
        %trial's sleep stage


        %match with retrieval behavioral files: RETRIEVAL
        fname_beh_retr = [beh_path, subid, '/', ses, '/', 'with_eeg_timing/', ...
            subid, '_', ses, '_acq-eeg_task-retrieval_log.csv'];

        if exist(fname_beh_retr) %safeguard agains lacking retrieval
            behlog_retr = readtable(fname_beh_retr);

            behlog_retr.n_notNREM = nan(size(behlog_retr,1),1);
            for tr = 1:size(behlog_retr,1)
                itemId = behlog_retr.itemID(tr);
                tmp_TMRlog = EEG.triallog(EEG.triallog.itemID == itemId,:);
                if ~isempty(tmp_TMRlog)
                    behlog_retr.n_notNREM(tr) = sum(tmp_TMRlog.sleepstage~=2 & tmp_TMRlog.sleepstage~=3);
                end
            end
            clear tmp* itemId

            %Save behavioral logs with sleep stage information
            fname_beh_tmr = [beh_path, subid, '/', ses, '/', 'with_eeg_timing/', ...
                subid, '_', ses, '_acq-eeg_task-sleep_log_sleepstages.csv'];
            writetable(EEG.triallog, fname_beh_tmr)

            fname_beh_retr_new = [beh_path, subid, '/', ses, '/', 'with_eeg_timing/', ...
                subid, '_', ses, '_acq-eeg_task-retrieval_log_sleeptages.csv'];
            writetable(behlog_retr, fname_beh_retr_new)
        end
    end

    %% Sleep summaries - acording to AASM

    %adjust hypnograms to resting state end (serves as 'lights-off' event)
    lightsoff_event_ind = find(strcmp('rest_off', {EEG.event.type}));
    if ~isempty(lightsoff_event_ind) %for one participant, recording started from the middle of the night (no rest period)
        lightsoff_event = EEG.event(lightsoff_event_ind);
        lightsoff_latency_sec = lightsoff_event.latency./EEG.srate;
        epochcut_ind = find(lightsoff_latency_sec <= hypno.timevec_sec, 1);
    else
        lightsoff_latency_sec = 1;
        epochcut_ind = 1;
    end
    hypno_adjusted = hypno(epochcut_ind:end,:);

    %Save hypnogram without resting state
    fname_newhypno = [fname(1:end-7), 'merged_wo_rest.csv'];
    writetable(hypno_adjusted, fname_newhypno);

    %initialize sleep stats (# of epochs are multiplied with 0.5 for
    %sleep stats in minutes)
    sleepstats = table();
    sleepstats.subid = subid;
    sleepstats.session = ses;

    %total sleep time (minutes)
    sleepstats.TST = sum(hypno_adjusted.stage_merged~=0)*0.5;

    %total recording time (minutes)
    sleepstats.TRT = size(hypno_adjusted,1)*0.5;

    %sleep lateny (minutes)
    sleepstats.SL = find(hypno_adjusted.stage_merged~=0, 1)*0.5;

    %REM latency (minutes)
    sleepstats.RL = find(hypno_adjusted.stage_merged==4, 1)*0.5;

    %Wake after sleep onset (minutes)
    sleepstats.WASO = sleepstats.TRT - sleepstats.SL - sleepstats.TST;

    %Sleep efficiency (%)
    sleepstats.SE = (sleepstats.TST ./ sleepstats.TRT)*100;

    %Time in each stage (min)
    sleepstats.N1min = sum(hypno_adjusted.stage_merged==1)*0.5;
    sleepstats.N2min = sum(hypno_adjusted.stage_merged==2)*0.5;
    sleepstats.N3min = sum(hypno_adjusted.stage_merged==3)*0.5;
    sleepstats.REMmin = sum(hypno_adjusted.stage_merged==4)*0.5;

    %Percentage spent in each stage
    sleepstats.N1perc = (sleepstats.N1min ./ sleepstats.TST)*100;
    sleepstats.N2perc = (sleepstats.N2min ./ sleepstats.TST)*100;
    sleepstats.N3perc = (sleepstats.N3min ./ sleepstats.TST)*100;
    sleepstats.REMperc = (sleepstats.REMmin ./ sleepstats.TST)*100;

    %Save sleep statistics
    fname_sleepstats = [fname(1:end-13), 'statistics.csv'];
    writetable(sleepstats, fname_sleepstats);

    %Store sleep statitics across participants into a single file
    sleepstats_all = [sleepstats_all; sleepstats];

    %% Visualization

    %create new variables for plotting
    %wakefulness as -1 and REM sleep as 0
    hypno.plotstage = hypno.stage_merged;
    hypno.plotstage(hypno.stage_merged==0) = -1;
    hypno.plotstage(hypno.stage_merged==4) = 0;

    hypno.plotstage_C3 = hypno.stage_C3;
    hypno.plotstage_C3(hypno.stage_C3==0) = -1;
    hypno.plotstage_C3(hypno.stage_C3==4) = 0;

    hypno.plotstage_C4 = hypno.stage_C4;
    hypno.plotstage_C4(hypno.stage_C4==0) = -1;
    hypno.plotstage_C4(hypno.stage_C4==4) = 0;


    fig = figure;
    %Hypnogram - C3
    subplot(2,2,1); hold all
    plot(hypno.hours, hypno.plotstage_C3, 'k');
    scatter(hypno.hours, hypno.plotstage_C3, 30, hypno.confidence_C3, 'filled');
    xline(lightsoff_latency_sec/3600, 'k--') %resting state off (lights off)
    caxis([0 1]);
    colormap(parula)
    colorbar;
    ylabel('Sleep Stage');
    xlabel('Time');
    title({subid, 'C3'})
    set(gca, 'YDir','reverse');
    ylim([-1.5 3.5])
    yticks([ -1 0 1 2 3]);
    yticklabels({'W', 'R', 'N1', 'N2', 'N3'});

    %Hypnogram - C4
    subplot(2,2,2); hold all
    plot(hypno.hours, hypno.plotstage_C4, 'k');
    scatter(hypno.hours, hypno.plotstage_C4, 30, hypno.confidence_C4, 'filled');
    xline(lightsoff_latency_sec/3600, 'k--') %resting state off (lights off)
    caxis([0 1]);
    colormap(parula)
    colorbar;
    ylabel('Sleep Stage');
    xlabel('Time');
    title({subid, 'C4'})
    set(gca, 'YDir','reverse');
    ylim([-1.5 3.5])
    yticks([ -1 0 1 2 3]);
    yticklabels({'W', 'R', 'N1', 'N2', 'N3'});

    %Hypnogram - merged
    subplot(2,2,3:4); hold all
    plot(hypno.hours, hypno.plotstage, 'k');
    scatter(hypno.hours, hypno.plotstage, 30, hypno.confidence_merged, 'filled');
    xline(lightsoff_latency_sec/3600, 'k--') %resting state off (lights off)
    caxis([0 1]);
    colormap(parula)
    colorbar;
    ylabel('Sleep Stage');
    xlabel('Time');
    title({subid, 'merged C3 & C4'})
    set(gca, 'YDir','reverse');


    %TMR events
    if isfield(EEG,'triallog') %safeguard against no-TMR recordings
    nREM_trials = EEG.triallog.sleepstage == 2 | EEG.triallog.sleepstage == 3;
    scatter(EEG.triallog.onset_recEEG_sec(nREM_trials)./3600, 3.5*ones(sum(nREM_trials),1), '*')
    scatter(EEG.triallog.onset_recEEG_sec(~nREM_trials)./3600, 3.5*ones(sum(~nREM_trials),1), '*')
    end

    %Artefacts
    artef_ind = strcmp('True', hypno.artifact);
    scatter(hypno.hours(artef_ind), -1.5*ones(sum(artef_ind)), '*')

    %Tick-marks
    ylim([-2 4])
    yticks([-1.5 -1 0 1 2 3 3.5]);
    yticklabels({'art', 'W', 'R', 'N1', 'N2', 'N3', 'TMR'});

    % Apply size settings
    width_cm = 30;
    height_cm = 20;
    set(fig, 'Units', 'centimeters');
    set(fig, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

    set(fig, 'PaperUnits', 'centimeters');
    set(fig, 'PaperSize', [width_cm, height_cm]);
    set(fig, 'PaperPositionMode', 'manual');
    set(fig, 'PaperPosition', [0, 0, width_cm, height_cm]);

    %Save figure
    figname = [figpath, subid, '_', ses, '_hypnogram.png'];
    exportgraphics(fig, figname, 'ContentType', 'image', 'Resolution', 300, ...
        'BackgroundColor','white');
    close

end

%% Save sleep statistics (all subjects)
all_sleepstats_fname = 'sleepstatistics_allsubs_acq_eeg.csv';
writetable(sleepstats_all, all_sleepstats_fname)