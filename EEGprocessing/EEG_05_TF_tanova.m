clear all; close all; clc
addpath('XXX/EEG/topographic_analyses_eeg-main');

eeglabpath = 'XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui


%% Path definitions
fname_enc = 'group_enc_TF.mat';
fname_sleep = 'group_sleep_TF.mat';
fname_fbands = 'band_definitions.mat';

outpath_figures = [];

%% Load data
load(fname_enc)
load(fname_sleep)
load(fname_fbands)

%% Ectract delta + theta bands

fulldat_enc = allTF_encoding_db_alltrials;
fulldat_sleep_learned = squeeze(allTF_sleep_db(:,:,:,1,:));
fulldat_sleep_new = squeeze(allTF_sleep_db(:,:,:,2,:));

wakemaps = nan(size(fulldat_enc, 1), size(fulldat_enc, 4), 2); %chans x subj x delta/theta
sleepmaps_learned = nan(size(fulldat_sleep_learned, 1), size(fulldat_sleep_learned, 4), 4); %chans x subj x delta/theta/lowsigma/highsigma
sleepmaps_new = nan(size(fulldat_sleep_new, 1), size(fulldat_sleep_new, 4), 4); %chans x subj x delta/theta/lowsigma/highsigma

for s = 1:3 %wake vs sleep
    if s == 1
        statefreqs = encstruct;
        fulldat = fulldat_enc;
    elseif s == 2
        statefreqs = sleepstruct;
        fulldat = fulldat_sleep_learned;
    elseif s == 3
        statefreqs = sleepstruct;
        fulldat = fulldat_sleep_new;
    end
    for b = 1:size(statefreqs,2) %loop over frequencies

        %Extract freqband information
        frband = statefreqs(b);

        %Extract time-freq data
        tidx = find(TFparams.times >= frband.timerange(1), 1) : find(TFparams.times <= frband.timerange(2), 1, 'last');
        fidx = find(TFparams.freqs >= frband.freqrange(1), 1) : find(TFparams.freqs <= frband.freqrange(2), 1, 'last');
        tmp_dat = fulldat(:, fidx, tidx, :, :);


        %Calculate mean per participant
        mean_frband = squeeze(mean(tmp_dat,[2, 3]));

        %store data
        if s == 1
            wakemaps(:,:,b) = mean_frband;
        elseif s==2
            sleepmaps_learned(:,:,b) = mean_frband;
        elseif s==3
            sleepmaps_new(:,:,b) = mean_frband;
        end


    end
end

%% TANOVA - wake vs sleep

%Data into correct format
nSub = size(wakemaps,2);
allmaps_delta = [wakemaps(:,:,1), sleepmaps_learned(:,:,1)];                       % 25 x 162  (wake block, then sleep block)
data_delta    = num2cell(allmaps_delta, 1);                          % 1x162 cell, each 25 x 1

allmaps_theta = [wakemaps(:,:,2), sleepmaps_learned(:,:,2)];                       % 25 x 162  (wake block, then sleep block)
data_theta    = num2cell(allmaps_theta, 1);  

design  = [repelem([1 2], nSub); repmat(1:nSub, 1, 2)];  % 2 x 162


cfg = [];
cfg.parameter        = 'raw';
cfg.ivar             = 1;        % row 1 of design = condition
cfg.uvar             = 2;        % row 2 of design = subject
cfg.design           = design;
cfg.normalize        = 'yes';    % test topography, not amplitude
cfg.numrandomization = 10000;
cfg.randomseed       = 1;        % reproducible

stat_delta = topostats_DEPsamplesTANOVA_LR(cfg, data_delta{:});
stat_theta = topostats_DEPsamplesTANOVA_LR(cfg, data_theta{:});
