clear; close all; clc

%% eeglab path
%eeglabpath = 'XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui

%% Path definition
basepath = [];
inpath_eeg = [basepath, '/singletrial/'];

outpath_subTF = [];
outpath_subfigures = [];
outpath_groupfigures = [];

%% filenames


filenames = dir(fullfile(inpath_eeg, '**', '*'));  
filenames = filenames(~[filenames.isdir]); % Remove directories from the list
filenames = fullfile({filenames.folder}, {filenames.name})'; % Get full file paths
filenames = filenames(~contains(filenames, '.fdt')); %remove .fdt files

%task = 'task-sleep';
%filenames = filenames(contains(filenames, task)); %rkeep only encoding and/or sleep data


%% Matching trials numbers

matchtrials = "yes"; %flag, if yes, match the number of trials per participant between contrast levels
min_nrtials = 10;

if strcmp(matchtrials, "yes")
    %Load tf info, including trial numbers
    inpath_TF = [];
    fname_enc = [inpath_TF, 'group_enc_TF_redo.mat'];
    load(fname_enc, 'TFparams');

    %For 1st 4 enc-contrasts, take the  min over the first 4 conditions per
    %participants, and for the last 4 (i.e. vividness ratings)
enc_ntrials = [repmat(min(TFparams.trialcounts_enc(:,1:4), [], 2), 1,4), ...
    repmat(min(TFparams.trialcounts_enc(:,5:8), [], 2), 1,4)];


sleep_ntrials = [repmat(min(TFparams.trialcounts_sleep(:,1:3), [], 2), 1,3), ...
    repmat(min(TFparams.trialcounts_sleep(:,4:7), [], 2), 1,4)];


    clear TFparams 
end


%% Define conditions

%Encoding
% 1. hit-hit-hit faces
% 2. hit-hit-hit places
% 3. any miss faces
% 4. any miss places
% 5-8. all trials at each vividness level


%Sleep
% 1. new
% 2. all strongly learned (cat-correct, afc1-correct)
% 3. all weakly learned (cat-correct, afc1-incorrect)
% 4. strongly learned, hit-hit
% 5. strongly learned, any-miss
% 6. weakly learned, hit-hit
% 7. weakly learned, any-miss



%ENCODING 
COND_enc_allhits_face = ['find('...
    'EEG.triallog_clean.condition == 1 &' ... 
    'EEG.triallog_clean.afc1_accuracy == 1 &' ...
    'EEG.triallog_clean.afc2_accuracy == 1 &' ...
    '(EEG.triallog_clean.afc5_accuracy == 1 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take hit-hits

COND_enc_allhits_place = ['find('...
    'EEG.triallog_clean.condition == 2 &' ... 
    'EEG.triallog_clean.afc1_accuracy == 1 &' ...
    'EEG.triallog_clean.afc2_accuracy == 1 &' ...
    '(EEG.triallog_clean.afc5_accuracy == 1 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take hit-hits


COND_enc_anymiss_face = ['find('...
    'EEG.triallog_clean.condition == 1 &' ...
    '(EEG.triallog_clean.afc1_accuracy == 0 |' ...
    'EEG.triallog_clean.afc2_accuracy == 0) |' ...
    '(EEG.triallog_clean.afc5_accuracy == 0 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take any miss-miss

COND_enc_anymiss_place = ['find('...
    'EEG.triallog_clean.condition == 2 &' ...
    '(EEG.triallog_clean.afc1_accuracy == 0 |' ...
    'EEG.triallog_clean.afc2_accuracy == 0) |' ...
    '(EEG.triallog_clean.afc5_accuracy == 0 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take any miss-miss

%each vividness level
COND_enc_vivid1 = 'find(EEG.triallog_clean.vividness == 1)';
COND_enc_vivid2 = 'find(EEG.triallog_clean.vividness == 2)';
COND_enc_vivid3 = 'find(EEG.triallog_clean.vividness == 3)';
COND_enc_vivid4 = 'find(EEG.triallog_clean.vividness == 4)';




%SLEEP
COND_sleep_new = 'find(EEG.triallog_clean.learned == 0)';

COND_sleep_learnedstrong = ['find(EEG.triallog_clean.learned == 1 &', ...
    'EEG.triallog_clean.afc1_accuracy == 1)'];

COND_sleep_learnedweak = ['find(EEG.triallog_clean.learned == 1 &', ...
    'EEG.triallog_clean.afc1_accuracy == 0)'];


COND_sleep_learnedstrong_allhits = ['find('...
    'EEG.triallog_clean.afc1_accuracy == 1 &' ...
    'EEG.triallog_clean.afc2_accuracy == 1 &' ...
    '(EEG.triallog_clean.afc5_accuracy == 1 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take hit-hits

COND_sleep_learnedstrong_anymiss = ['find('...
    'EEG.triallog_clean.afc1_accuracy == 1 &' ...
    '(EEG.triallog_clean.afc2_accuracy == 0 |' ...
    '(EEG.triallog_clean.afc5_accuracy == 0 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy))))']; %if participant doesn't have afc5, only take any miss-miss

COND_sleep_learnedweak_allhits = ['find('...
    'EEG.triallog_clean.afc1_accuracy == 0 &' ...
    'EEG.triallog_clean.afc2_accuracy == 1 &' ...
    '(EEG.triallog_clean.afc5_accuracy == 1 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy)))']; %if participant doesn't have afc5, only take hit-hits

COND_sleep_learnedweak_anymiss = ['find('...
    'EEG.triallog_clean.afc1_accuracy == 0 &' ...
    '(EEG.triallog_clean.afc2_accuracy == 0 |' ...
    '(EEG.triallog_clean.afc5_accuracy == 0 |'...
    'isnan(EEG.triallog_clean.afc5_accuracy))))']; %if participant doesn't have afc5, only take any miss-miss


%COMBiNE CONTRASTS
cond_enc_names = {...
    'COND_enc_allhits_face', 'COND_enc_allhits_place', ...
    'COND_enc_anymiss_face', 'COND_enc_anymiss_place', ...
    'COND_enc_vivid1', 'COND_enc_vivid2', 'COND_enc_vivid3', 'COND_enc_vivid4'};

cond_sleep_names = {...
    'COND_sleep_new', 'COND_sleep_learnedstrong', 'COND_sleep_learnedweak', ...
    'COND_sleep_learnedstrong_allhits',...
    'COND_sleep_learnedstrong_anymiss', ...
    'COND_sleep_learnedweak_allhits', ...
    'COND_sleep_learnedweak_anymiss'
    };

% nr of conditions
n_cond_enc = length(cond_enc_names);
n_cond_sleep = length(cond_sleep_names);


%% Loop over filenames

n_files_encoding = sum(contains(filenames, 'task-encoding'));
n_files_sleep = sum(contains(filenames, 'task-sleep'));

%Condition-specific files for all participants
allTF_encoding_db = nan(25,40,200,n_cond_enc, n_files_encoding);
allTF_sleep_db = nan(25,40,200,n_cond_sleep, n_files_sleep);

allTF_encoding_subtr = nan(25,40,200,n_cond_enc, n_files_encoding);
allTF_sleep_subtr = nan(25,40,200, n_cond_sleep, n_files_sleep);

allTF_encoding_perc = nan(25,40,200,n_cond_enc, n_files_encoding);
allTF_sleep_perc = nan(25,40,200, n_cond_sleep, n_files_sleep);

%All-trials files for all participants
allTF_encoding_db_alltrials = nan(25,40,200, n_files_encoding);
allTF_sleep_db_alltrials = nan(25,40,200, n_files_sleep);

allTF_encoding_subtr_alltrials = nan(25,40,200, n_files_encoding);
allTF_sleep_subtr_alltrials = nan(25,40,200, n_files_sleep);

allTF_encoding_perc_alltrials = nan(25,40,200, n_files_encoding);
allTF_sleep_perc_alltrials = nan(25,40,200, n_files_sleep);

%collect trial counts
trialcounts_enc = nan(n_files_encoding, n_cond_enc);
trialcounts_sleep = nan(n_files_encoding, n_cond_sleep);


enc_counter = 0;
sleep_counter = 0;

enc_subid = {};
sleep_subid = {};

for f = 1:length(filenames)
    fname = filenames(f);

    %ectract subid, session, and task phase
    fname_split = split(fname, '/');
    fname_bids = fname_split{end};
    fname_bids = split(fname_bids, '_');
    subid = fname_bids{1};
    ses = fname_bids{2};
    task = fname_bids{4};

    %Switch variables base on tasks
    if strcmp('task-encoding', task)
        cond_names = cond_enc_names;
        subTF.data_db = nan(25,40,200, n_cond_enc); %chans x freqs x times x conditions
        subTF.data_subtr = nan(25,40,200, n_cond_enc); %chans x freqs x times x conditions   
        subTF.data_perc = nan(25,40,200, n_cond_enc); %chans x freqs x times x conditions   
        enc_counter = enc_counter + 1;
        enc_subid = [enc_subid, subid];
        tmp_trialcounts = nan(1,n_cond_enc);
    elseif strcmp('task-sleep', task)
        cond_names = cond_sleep_names;
        subTF.data_db = nan(25,40,200, n_cond_sleep); %chans x freqs x times x conditions
        subTF.data_subtr = nan(25,40,200, n_cond_sleep); %chans x freqs x times x conditions
        subTF.data_perc = nan(25,40,200, n_cond_sleep); %chans x freqs x times x conditions
        sleep_counter = sleep_counter + 1;
        sleep_subid = [sleep_subid, subid];
        tmp_trialcounts = nan(1,n_cond_sleep);
    end


    %Load EEG data
    EEG = pop_loadset('filename', fname);

    %Store average values across all trials
    [all_TF_db, all_TF_subtr, all_TF_perc] = tf_baseline(EEG.TF.tfdata, EEG.TF.times);
    if strcmp('task-encoding', task)
        allTF_encoding_db_alltrials(:,:,:,enc_counter) = all_TF_db;
        allTF_encoding_subtr_alltrials(:,:,:,enc_counter) = all_TF_subtr;     
        allTF_encoding_perc_alltrials(:,:,:,enc_counter) = all_TF_perc;        

    elseif strcmp('task-sleep', task)
        allTF_sleep_db_alltrials(:,:,:,sleep_counter) = all_TF_db;
        allTF_sleep_subtr_alltrials(:,:,:,sleep_counter) = all_TF_subtr;
        allTF_sleep_perc_alltrials(:,:,:,sleep_counter) = all_TF_perc;

    end    
  
    contr_counter = 0;
    % fig_db = figure;
    % fig_subtr = figure;
    % fig_perc = figure;

    %Loop over conditions
    for c = 1:length(cond_names)


            %Extract condition
            tmp_condition = eval(eval(cond_names{c}));
            tmp_condname = cond_names{c}; tmp_condname = tmp_condname(6:end);

            %Double check that the contrast selection is meaningful
            %EEG.epoch(tmp_condition).eventtype
            %EEG.triallog_clean(tmp_contrast,[6 13 19 22])


            %Extract TF data per contrast
            tmp_TF = EEG.TF.tfdata(:,:,:, tmp_condition);

            %if trial matching, select predefined nr of trials randomly,
            %before averaging
            if strcmp(matchtrials, "yes")
                %Extract the minimum nr of trials per contrast
                if strcmp('task-encoding', task)
                    tmp_ntrials = enc_ntrials(enc_counter, c);
                elseif strcmp('task-sleep', task)
                    tmp_ntrials = sleep_ntrials(sleep_counter, c);
                end

                %Check that there are enough trials per contrast
                if tmp_ntrials >= min_nrtials
                    %only apply for the condition with the highest nr of
                    %trials
                    if size(tmp_TF,4) ~= tmp_ntrials 
                        tmp_selectrials = randperm(size(tmp_TF,4));
                        tmp_TF = tmp_TF(:,:,:, tmp_selectrials(1:tmp_ntrials));

                    end
                else 
                    tmp_TF = tmp_TF(:,:,:,[]);
                end
            end

            %Trial average + baseline normalization
            [tmp_TF_db, tmp_TF_subtr, tmp_TF_perc] = tf_baseline(tmp_TF, EEG.TF.times);

            %Store subject TF averages
            subTF.data_db(:,:,:,c) = tmp_TF_db;
            subTF.data_subtr(:,:,:,c) = tmp_TF_subtr;
            subTF.data_perc(:,:,:,c) = tmp_TF_perc;
            tmp_trialcounts(c) = size(tmp_TF,4);
            
            % %Visualization - chan Cz, db baseline
            % chanind = find(strcmp('Cz', EEG.TF.chans));
            % 
            % figure(fig_db); subplot(4,2,c)
            % imagesc(EEG.TF.times, EEG.TF.freqs, squeeze(tmp_TF_db(chanind,:,:))) %DOUBLE CHECK THAT CHANIND IS AT CHANNELS, NOT FREQS
            % clim([-8 8])
            % axis xy;
            % colormap("jet")
            % colorbar
            % xlabel('Time (ms)');
            % ylabel('Frequency (Hz)');
            % xlim([-500 2000])
            % title({subid, tmp_condname, ['n=', num2str(size(tmp_TF,4))]})
            % 
            % %Visualization - Chan Cz, subtractive baseline
            % figure(fig_subtr); subplot(4,2,c)
            % imagesc(EEG.TF.times, EEG.TF.freqs, squeeze(tmp_TF_subtr(chanind,:,:)))
            % clim([-800 800])
            % axis xy;
            % colormap("jet")
            % colorbar
            % xlabel('Time (ms)');
            % ylabel('Frequency (Hz)');
            % xlim([-500 2000])
            % title({subid, tmp_condname, ['n=', num2str(size(tmp_TF,4))]})     
            % 
            % %Visualization - Chan Cz, percentage change baseline
            % figure(fig_perc); subplot(4,2,c)
            % imagesc(EEG.TF.times, EEG.TF.freqs, squeeze(tmp_TF_perc(chanind,:,:)))
            % clim([-500 500])
            % axis xy;
            % colormap("jet")
            % colorbar
            % xlabel('Time (ms)');
            % ylabel('Frequency (Hz)');
            % xlim([-500 2000])
            % title({subid, tmp_condname, ['n=', num2str(size(tmp_TF,4))]})  


    end %end condition

    %% Store all subjects for visualization
    if strcmp('task-encoding', task)
        allTF_encoding_db(:,:,:,:,enc_counter) = subTF.data_db;
        allTF_encoding_subtr(:,:,:,:,enc_counter) = subTF.data_subtr;  
        allTF_encoding_perc(:,:,:,:,enc_counter) = subTF.data_perc;  
        trialcounts_enc(enc_counter,:) = tmp_trialcounts;
    elseif strcmp('task-sleep', task)
        allTF_sleep_db(:,:,:,:,sleep_counter) = subTF.data_db;
        allTF_sleep_subtr(:,:,:,:,sleep_counter) = subTF.data_subtr;
        allTF_sleep_perc(:,:,:,:,sleep_counter) = subTF.data_perc;
        trialcounts_sleep(sleep_counter,:) = tmp_trialcounts;
    end


    %% Save subject TF data
    subTF.times = EEG.TF.times;
    subTF.freqs = EEG.TF.freqs;
    subTF.condnames = cond_names;

    %tmp_path = [outpath_subTF, subid, '/'];
    %mkdir tmp_path
    tmp_fname = [outpath_subTF, char(join(fname_bids(1:4), '_')), '_TFconditions_redo.mat']
    save(tmp_fname, 'subTF')


    % %% Save subject TF figure
    % % Apply size settings
    % width_cm = 15;
    % height_cm = 40;
    % 
    % set(fig_db, 'Units', 'centimeters');
    % set(fig_db, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]
    % 
    % set(fig_db, 'PaperUnits', 'centimeters');
    % set(fig_db, 'PaperSize', [width_cm, height_cm]);
    % set(fig_db, 'PaperPositionMode', 'manual');
    % set(fig_db, 'PaperPosition', [0, 0, width_cm, height_cm]);
    % 
    % %Save figure
    % if strcmp(matchtrials, "yes")
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_db_baseline_matchedtrials_redo.pdf'];
    % else
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_db_baseline_redo.pdf'];
    % end
    % exportgraphics(fig_db, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    %     'BackgroundColor','white');
    % 
    % set(fig_subtr, 'Units', 'centimeters');
    % set(fig_subtr, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]
    % 
    % set(fig_subtr, 'PaperUnits', 'centimeters');
    % set(fig_subtr, 'PaperSize', [width_cm, height_cm]);
    % set(fig_subtr, 'PaperPositionMode', 'manual');
    % set(fig_subtr, 'PaperPosition', [0, 0, width_cm, height_cm]);
    % 
    % %Save figure
    % if strcmp(matchtrials, "yes")
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_subtr_baseline_matchedtrials_redo.pdf'];
    % else
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_subtr_baseline_redo.pdf'];
    % end
    % exportgraphics(fig_subtr, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    %     'BackgroundColor','white');
    % 
    % 
    % 
    % set(fig_perc, 'Units', 'centimeters');
    % set(fig_perc, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]
    % 
    % set(fig_perc, 'PaperUnits', 'centimeters');
    % set(fig_perc, 'PaperSize', [width_cm, height_cm]);
    % set(fig_perc, 'PaperPositionMode', 'manual');
    % set(fig_perc, 'PaperPosition', [0, 0, width_cm, height_cm]);
    % 
    % %Save figure
    % if strcmp(matchtrials, "yes")
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_perc_baseline_matchedtrials_redo.pdf'];
    % else
    %     figname = [outpath_subfigures, subid, '_', task, '_TF_perc_baseline_redo.pdf'];
    % end
    % exportgraphics(fig_perc, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    %     'BackgroundColor','white');
    % 
    % close all
end %end filenames

%% Save group data
TFparams.times = EEG.TF.times;
TFparams.freqs = EEG.TF.freqs;
TFparams.enc_conditions = cond_enc_names;
TFparams.sleep_conditions = cond_sleep_names;
TFparams.labels = {EEG.chanlocs.labels};
TFparams.chanlocs = EEG.chanlocs;
TFparams.encsubid = enc_subid;
TFparams.sleepsubid = sleep_subid;
TFparams.trialcounts_enc = trialcounts_enc;
TFparams.trialcounts_sleep = trialcounts_sleep;

if strcmp(matchtrials, "yes")
    fname_enc = [outpath_subTF, 'group_enc_TF_matchedtrials_redo.mat'];
else
    fname_enc = [outpath_subTF, 'group_enc_TF_redo.mat'];
end
save(fname_enc, 'TFparams', ...
    'allTF_encoding_db', 'allTF_encoding_subtr', 'allTF_encoding_perc', ...
    'allTF_encoding_db_alltrials', 'allTF_encoding_subtr_alltrials', 'allTF_encoding_perc_alltrials', '-v7.3')

if strcmp(matchtrials, "yes")
    fname_sleep = [outpath_subTF, 'group_sleep_TF_matchedtrials_redo.mat'];
else
    fname_sleep = [outpath_subTF, 'group_sleep_TF_redo.mat'];
end
save(fname_sleep, 'TFparams', ...
    'allTF_sleep_db', 'allTF_sleep_subtr', 'allTF_sleep_perc', ...
    'allTF_sleep_db_alltrials', 'allTF_sleep_subtr_alltrials', 'allTF_sleep_perc_alltrials', '-v7.3')


%% Visualize group data: db baseline

channame = 'Cz';

%Encoding-db
fig_db = figure;
for c = 1:8
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_encoding_db(chanind, :, :, c, :),5, "omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-5 5])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 2000])
    title({cond_enc_names{c}, channame})
end

width_cm = 15;
height_cm = 20;

set(fig_db, 'Units', 'centimeters');
set(fig_db, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_db, 'PaperUnits', 'centimeters');
set(fig_db, 'PaperSize', [width_cm, height_cm]);
set(fig_db, 'PaperPositionMode', 'manual');
set(fig_db, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'encoding_TF_baseline_db_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'encoding_TF_baseline_db_redo.pdf'];
end
exportgraphics(fig_db, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');


%Sleep-db
fig_db = figure;
for c = 1:7
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_sleep_db(chanind, :, :, c, :),5,"omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-3 3])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 3000])
    title({cond_sleep_names{c}, channame})
end

width_cm = 20;
height_cm = 20;

set(fig_db, 'Units', 'centimeters');
set(fig_db, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_db, 'PaperUnits', 'centimeters');
set(fig_db, 'PaperSize', [width_cm, height_cm]);
set(fig_db, 'PaperPositionMode', 'manual');
set(fig_db, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'sleep_TF_baseline_db_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'sleep_TF_baseline_db_redo.pdf'];
end
exportgraphics(fig_db, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');

%% Visualize group data: subtractive baseline


%Encoding-db
fig_subtr = figure;
for c = 1:8
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_encoding_subtr(chanind, :, :, c, :),5, "omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-1500 1500])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 2000])
    title({cond_enc_names{c}, channame})
end

width_cm = 15;
height_cm = 20;

set(fig_subtr, 'Units', 'centimeters');
set(fig_subtr, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_subtr, 'PaperUnits', 'centimeters');
set(fig_subtr, 'PaperSize', [width_cm, height_cm]);
set(fig_subtr, 'PaperPositionMode', 'manual');
set(fig_subtr, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'encoding_TF_baseline_subtr_matchedtrials_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'encoding_TF_baseline_subtr_matchedtrials_redo.pdf'];

end
exportgraphics(fig_subtr, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');


%Sleep-db
fig_subtr = figure;
for c = 1:7
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_sleep_subtr(chanind, :, :, c, :),5,"omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-500 500])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 3000])
    title({cond_sleep_names{c}, channame})
end

width_cm = 20;
height_cm = 20;

set(fig_subtr, 'Units', 'centimeters');
set(fig_subtr, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_subtr, 'PaperUnits', 'centimeters');
set(fig_subtr, 'PaperSize', [width_cm, height_cm]);
set(fig_subtr, 'PaperPositionMode', 'manual');
set(fig_subtr, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'sleep_TF_baseline_subtr_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'sleep_TF_baseline_subtr_redo.pdf'];
end
exportgraphics(fig_subtr, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');

%% Visualize group data: percentage change baseline


%Encoding-perc
fig_perc = figure;
for c = 1:8
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_encoding_perc(chanind, :, :, c, :),5, "omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-500 500])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 2000])
    title({cond_enc_names{c}, channame})
end

width_cm = 15;
height_cm = 20;

set(fig_perc, 'Units', 'centimeters');
set(fig_perc, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_perc, 'PaperUnits', 'centimeters');
set(fig_perc, 'PaperSize', [width_cm, height_cm]);
set(fig_perc, 'PaperPositionMode', 'manual');
set(fig_perc, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'encoding_TF_baseline_perc_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'encoding_TF_baseline_perc_redo.pdf'];
end
exportgraphics(fig_perc, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');


%Sleep-perc
fig_perc = figure;
for c = 1:7
    %Visualization - chan Cz
    chanind = find(strcmp(channame, EEG.TF.chans));

    %Extract data
    tmpdata = squeeze(mean(allTF_sleep_perc(chanind, :, :, c, :),5,"omitnan"));

    subplot(4,2,c)
    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    clim([-500 500])
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 3000])
    title({cond_sleep_names{c}, channame})
end

width_cm = 20;
height_cm = 20;

set(fig_perc, 'Units', 'centimeters');
set(fig_perc, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(fig_perc, 'PaperUnits', 'centimeters');
set(fig_perc, 'PaperSize', [width_cm, height_cm]);
set(fig_perc, 'PaperPositionMode', 'manual');
set(fig_perc, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'sleep_TF_baseline_perc_matchedtrials_redo.pdf'];
else
    figname = [outpath_groupfigures,'sleep_TF_baseline_perc_redo.pdf'];
end
exportgraphics(fig_perc, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');

%% Visualize all trials (independent of conditions)

figall = figure;

fignames = {'allTF_encoding_db_alltrials', 'allTF_sleep_db_alltrials', ...
    'allTF_encoding_subtr_alltrials', 'allTF_sleep_subtr_alltrials', ...
    'allTF_encoding_perc_alltrials', 'allTF_sleep_perc_alltrials'};
figtitles = {'encoding (db)', 'sleep (db)', 'encoding (µV2)', 'sleep (µV2)', 'encoding (%)', 'sleep (%)'};

for sp = 1:6
    subplot(3,2,sp)

    tmpdata = eval(fignames{sp});
    tmpdata = squeeze(mean(tmpdata(chanind, :, :, :),4,"omitnan"));

    imagesc(EEG.TF.times, EEG.TF.freqs, tmpdata)
    axis xy;
    colormap("jet")
    colorbar
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    xlim([-500 3000])

    if sp < 3
        clim([-5 5])
    elseif sp >= 3 & sp < 5
        clim([-800 800])
    else
        clim([-100 100])
    end


    title(figtitles{sp})
end

width_cm = 25;
height_cm = 20;

set(figall, 'Units', 'centimeters');
set(figall, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

set(figall, 'PaperUnits', 'centimeters');
set(figall, 'PaperSize', [width_cm, height_cm]);
set(figall, 'PaperPositionMode', 'manual');
set(figall, 'PaperPosition', [0, 0, width_cm, height_cm]);

%Save figure
if strcmp(matchtrials, "yes")
    figname = [outpath_groupfigures,'group_alltrials_TF_matchedtrials.pdf'];
else
    figname = [outpath_groupfigures,'group_alltrials_TF.pdf'];
end
exportgraphics(figall, figname, 'ContentType', 'vector', 'Resolution', 300, ...
    'BackgroundColor','white');


%% Function for trial averaging and baseline corrections
function [data_normalized_db data_normalized_subt data_normalized_perc] = tf_baseline(data, timevec)
%Input is ch x times x trials matrix

%Find baseline period (delta (1-4Hz) post-stimuls inflantation to
%pre-stimulus baseline -500 to -250 ms)
baseline = [-800 -500];
baseline_ind = find(timevec >= baseline(1),1): find(timevec <= baseline(2), 1, 'last');

%Calculate power
data_power = real(data).^2 + imag(data).^2;


%Average across trials
data_power = mean(data_power, 4);

%average baseline activity
TF_baseline = squeeze(mean(data_power(:,:,baseline_ind),3));
TF_baseline = repmat(TF_baseline, [1, 1, size(data_power,3), 1]);

%Percentage change
data_normalized_perc =  ((data_power - TF_baseline) ./ TF_baseline)*100;

%Division by baseline + log conversion (gain model)
data_normalized_db = data_power ./ TF_baseline;
data_normalized_db = 10*(log10(data_normalized_db));

%Subtractive baseline (additive model)
data_normalized_subt = data_power - TF_baseline;

end