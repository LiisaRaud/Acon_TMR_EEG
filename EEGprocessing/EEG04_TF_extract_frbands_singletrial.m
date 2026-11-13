clear all; close all; clc

%eeglabpath = 'XXX/EEG/eeglab2025.0.0/';
%addpath(eeglabpath)
%eeglab nogui

%% Path definitions
basepath = [];
inpath_eeg = [basepath,'d_timefrequency/singletrial/'];

pathout = [];
outpath_subfigures = [];

%% Load pre-defined chan-time-frequency bins
fname_bands = [pathout, 'band_definitions.mat'];
load(fname_bands)


%% filenames
filenames = dir(fullfile(inpath_eeg, '**', '*'));  
filenames = filenames(~[filenames.isdir]); % Remove directories from the list
filenames = fullfile({filenames.folder}, {filenames.name})'; % Get full file paths
filenames = filenames(~contains(filenames, '.fdt')); %remove .fdt files
filenames_sleep = filenames(contains(filenames, 'task-sleep')); %split sleep and encoding filenames
filenames_encoding = filenames(contains(filenames, 'task-encoding')); %split sleep and encoding filenames

%% Parameters
baseline = [-800 -500];
tf_clim_db = [-5 5]; 
tf_clim_subtr = [-1000 1000]; 

%% Loop over sleep-filenames
all_enc = [];
all_sleep = [];
for f = 1:length(filenames_sleep)
    fname_sleep = filenames_sleep(f);

    %% ectract subid, session, and task phase
    fname_split = split(fname_sleep, '/');
    fname_bids = fname_split{end};
    fname_bids = split(fname_bids, '_');
    subid = fname_bids{1};
    ses = fname_bids{2};
    task = fname_bids{4};

    %% Load data
    %find corresponding encoding data
    fname_encoding = filenames_encoding(contains(filenames_encoding, subid));


    %Load EEG data
    EEG_encoding = pop_loadset('filename', fname_encoding);
    EEG_sleep = pop_loadset('filename', fname_sleep);

    %% Power and baseline calculation
    %Calculate power
    EEG_encoding.TF.tfdata_power = real(EEG_encoding.TF.tfdata).^2 + imag(EEG_encoding.TF.tfdata).^2;
    EEG_sleep.TF.tfdata_power = real(EEG_sleep.TF.tfdata).^2 + imag(EEG_sleep.TF.tfdata).^2;


    %Extract data from baseline timewindow (in sleep, separately for N2 and
    %N3 trials)
    bl_tidx = find(EEG_encoding.TF.times >= baseline(1), 1) : find(EEG_encoding.TF.times <= baseline(2), 1, 'last');
    N2_idx = find(EEG_sleep.triallog_clean.sleepstage == 2);
    N3_idx = find(EEG_sleep.triallog_clean.sleepstage == 3);    
    
    data_bl_encoding = EEG_encoding.TF.tfdata_power(:,:, bl_tidx, :);
    data_bl_sleep = EEG_sleep.TF.tfdata_power(:,:, bl_tidx, :);
    data_bl_sleep_N2 = EEG_sleep.TF.tfdata_power(:,:, bl_tidx, N2_idx);
    data_bl_sleep_N3 = EEG_sleep.TF.tfdata_power(:,:, bl_tidx, N3_idx);
    
    %For db conversion,calculate baseline over concatenated baselines
    %across all trials
    data_bl_encoding_r = reshape(data_bl_encoding, size(data_bl_encoding,1), size(data_bl_encoding,2), []);
    data_bl_sleep_N2_r = reshape(data_bl_sleep_N2, size(data_bl_sleep_N2,1), size(data_bl_sleep_N2,2), []);
    data_bl_sleep_N3_r = reshape(data_bl_sleep_N3, size(data_bl_sleep_N3,1), size(data_bl_sleep_N3,2), []);

    %Average baseline over time - concatenated trials (for db baseline)
    data_bl_encoding_conc = mean(data_bl_encoding_r,3);
    data_bl_sleep_N2_conc = mean(data_bl_sleep_N2_r, 3); 
    data_bl_sleep_N3_conc = mean(data_bl_sleep_N3_r, 3); 
  
    
    %Average baseline over time - trialwise (for subtr baseline)
    data_bl_encoding_tw = mean(data_bl_encoding,3);
    data_bl_sleep_tw = mean(data_bl_sleep, 3);

    %visualization of baseline power
    fig = figure; 
    subplot(1,2,1); hold all
    plot(EEG_encoding.TF.freqs, 10*log10(mean(data_bl_encoding_conc,1)));
    plot(EEG_encoding.TF.freqs, 10*log10(mean(data_bl_sleep_N2_conc,1)));
    plot(EEG_encoding.TF.freqs, 10*log10(mean(data_bl_sleep_N3_conc,1)));
    legend('encoding', 'sleep-N2', 'sleep-N3')
    title({subid, 'baseline power; concatenated baseline'})
    ylabel('Power [10*log10(uV)]');
    xlabel('Frequency (Hz)');

    subplot(1,2,2); hold all
    plot(EEG_encoding.TF.freqs, squeeze(10*log10(mean(mean(data_bl_encoding_tw,4),1))));
    plot(EEG_encoding.TF.freqs, squeeze(10*log10(mean(mean(data_bl_sleep_tw(:,:,:, N2_idx),4),1))));
    plot(EEG_encoding.TF.freqs, squeeze(10*log10(mean(mean(data_bl_sleep_tw(:,:,:, N3_idx),4),1))));
    legend('encoding', 'sleep-N2', 'sleep-N3')
    title({subid, 'baseline power; trialwise baseline'})
    ylabel('Power [10*log10(uV)]');
    xlabel('Frequency (Hz)');

    %Apply size settings
    width_cm = 10;
    height_cm = 10;

    set(fig, 'Units', 'centimeters');
    set(fig, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

    set(fig, 'PaperUnits', 'centimeters');
    set(fig, 'PaperSize', [width_cm, height_cm]);
    set(fig, 'PaperPositionMode', 'manual');
    set(fig, 'PaperPosition', [0, 0, width_cm, height_cm]);

    %Save figure
    figname = [outpath_subfigures, subid, '_singletrial_baseline_power.pdf'];
    exportgraphics(fig, figname, 'ContentType', 'vector', 'Resolution', 300, ...
        'BackgroundColor','white');
    close all


    %replicate baseline to match single-trial data size
    data_bl_encoding_conc = repmat(data_bl_encoding_conc, [1, 1, size(EEG_encoding.TF.tfdata_power,3), size(EEG_encoding.TF.tfdata_power,4)]);    
    data_bl_sleep_N2_conc = repmat(data_bl_sleep_N2_conc, [1, 1, size(EEG_sleep.TF.tfdata_power,3), length(N2_idx)]);
    data_bl_sleep_N3_conc = repmat(data_bl_sleep_N3_conc, [1, 1, size(EEG_sleep.TF.tfdata_power,3), length(N3_idx)]);

    data_bl_encoding_tw = repmat(data_bl_encoding_tw, [1, 1, size(EEG_encoding.TF.tfdata_power,3), 1]);    
    data_bl_sleep_tw = repmat(data_bl_sleep_tw, [1, 1, size(EEG_sleep.TF.tfdata_power,3), 1]);    


   %baseline division (do not do the log-conversion, as this will mess up
   %later averaging! log-conversion should be done after frex-time
   %averaging
   EEG_encoding.TF.tfdata_power_db = EEG_encoding.TF.tfdata_power ./ data_bl_encoding_conc; 
   %EEG_encoding.TF.tfdata_power_db = 10*(log10(EEG_encoding.TF.tfdata_power_db));

   EEG_sleep.TF.tfdata_power_db = EEG_sleep.TF.tfdata_power;
   EEG_sleep.TF.tfdata_power_db(:,:,:, N2_idx) = EEG_sleep.TF.tfdata_power_db(:,:,:, N2_idx) ./ data_bl_sleep_N2_conc; 
   EEG_sleep.TF.tfdata_power_db(:,:,:, N3_idx) = EEG_sleep.TF.tfdata_power_db(:,:,:, N3_idx) ./ data_bl_sleep_N3_conc; 
   %EEG_sleep.TF.tfdata_power_db = 10*(log10(EEG_sleep.TF.tfdata_power_db));


   %subtractive baseline
   EEG_encoding.TF.tfdata_power_subtr = EEG_encoding.TF.tfdata_power - data_bl_encoding_tw; 
   EEG_sleep.TF.tfdata_power_subtr = EEG_sleep.TF.tfdata_power - data_bl_sleep_tw;

   %% Visualization of participant data (sanity check)
   chanind = find(strcmp('Cz', EEG_encoding.TF.chans));
   %encoding db
   tmp_enc_dat = 10*log10(mean(EEG_encoding.TF.tfdata_power_db,4)); %mean across trials, encoding
   fig = figure; subplot(2,2,1)
   imagesc(EEG_encoding.TF.times, EEG_encoding.TF.freqs, squeeze(tmp_enc_dat(chanind,:,:)))
   clim(tf_clim_db)
   axis xy;
   colormap("jet")
   colorbar
   xlabel('Time (ms)');
   ylabel('Frequency (Hz)');
   xlim([-500 2000])
   title({subid, 'encoding', 'db baseline'})

   %sleep db
   tmp_sleep_dat = 10*log10(mean(EEG_sleep.TF.tfdata_power_db,4)); %mean across trials, all sleep
   subplot(2,2,2)
   imagesc(EEG_sleep.TF.times, EEG_sleep.TF.freqs, squeeze(tmp_sleep_dat(chanind,:,:)))
   clim(tf_clim_db)
   axis xy;
   colormap("jet")
   colorbar
   xlabel('Time (ms)');
   ylabel('Frequency (Hz)');
   xlim([-500 2000])
   title({subid, 'sleep', 'db baseline'})


   %encoding subtr
   tmp_enc_dat = mean(EEG_encoding.TF.tfdata_power_subtr,4); %mean across trials, encoding
   subplot(2,2,3)
   imagesc(EEG_encoding.TF.times, EEG_encoding.TF.freqs, squeeze(tmp_enc_dat(chanind,:,:)))
   clim(tf_clim_subtr)
   axis xy;
   colormap("jet")
   colorbar
   xlabel('Time (ms)');
   ylabel('Frequency (Hz)');
   xlim([-500 2000])
   title({subid, 'encoding', 'subtr baseline'})

   %sleep subtr
   tmp_sleep_dat = mean(EEG_sleep.TF.tfdata_power_subtr,4); %mean across trials, all sleep
   subplot(2,2,4)
   imagesc(EEG_sleep.TF.times, EEG_sleep.TF.freqs, squeeze(tmp_sleep_dat(chanind,:,:)))
   clim(tf_clim_subtr)
   axis xy;
   colormap("jet")
   colorbar
   xlabel('Time (ms)');
   ylabel('Frequency (Hz)');
   xlim([-500 2000])
   title({subid, 'sleep', 'subtr baseline'})



    %Save subject TF figure
    % Apply size settings
    width_cm = 25;
    height_cm = 20;

    set(fig, 'Units', 'centimeters');
    set(fig, 'Position', [2, 2, width_cm, height_cm]);  % [x y width height]

    set(fig, 'PaperUnits', 'centimeters');
    set(fig, 'PaperSize', [width_cm, height_cm]);
    set(fig, 'PaperPositionMode', 'manual');
    set(fig, 'PaperPosition', [0, 0, width_cm, height_cm]);

    %Save figure
    figname = [outpath_subfigures, subid, '_TF_singletrial_db.pdf'];
    exportgraphics(fig, figname, 'ContentType', 'vector', 'Resolution', 300, ...
        'BackgroundColor','white');
    close all

    %% Extract encoding valuese
    enc_values_db = nan(EEG_encoding.trials, length(encstruct));
    enc_values_subtr = nan(EEG_encoding.trials, length(encstruct));
    bl_pow_enc = nan(EEG_encoding.trials, length(encstruct));
    peaklat_db_enc = nan(EEG_encoding.trials, length(encstruct));
    peaklat_subtr_enc = nan(EEG_encoding.trials, length(encstruct));

    for b = 1:length(encstruct) %loop over encoding freq-bands

        %Extract freqband information
        frband = encstruct(b);


        %Extract chan-freq indices
        tidx = find(EEG_encoding.TF.times >= frband.timerange(1),1) : find(EEG_encoding.TF.times <= frband.timerange(2),1, 'last');
        fidx = find(EEG_encoding.TF.freqs >= frband.freqrange(1), 1) : find(EEG_encoding.TF.freqs <= frband.freqrange(2), 1, 'last');
        chidx = find(contains(EEG_encoding.TF.chans, frband.chans));

                %Extract chan-frec-times-trial data
        tmp_dat_db = EEG_encoding.TF.tfdata_power_db(chidx, fidx, tidx, :);
        tmp_dat_subtr = EEG_encoding.TF.tfdata_power_subtr(chidx, fidx, tidx, :);

        %Avg over chan and freq
        enc_values_db(:,b)  = squeeze(mean(tmp_dat_db, [1 2 3]));
        enc_values_subtr(:,b) = squeeze(mean(tmp_dat_subtr, [1 2 3]));
        
        % % Commented part for finding peaks in single trial data - but
        % % likely too noisy
        % %Extract chan-frec-trial data
        % tmp_dat_db = EEG_encoding.TF.tfdata_power_db(chidx, fidx, :, :);
        % tmp_dat_subtr = EEG_encoding.TF.tfdata_power_subtr(chidx, fidx, :, :);
        % 
        % %Avg over chan and freq
        % tmp_dat_db = squeeze(mean(tmp_dat_db, [1 2]));
        % tmp_dat_subtr = squeeze(mean(tmp_dat_subtr, [1 2]));
        % 
        % 
        % %Find the time-window for peak activity (+/- 250 ms around post-stimulus 0-3000ms peak)
        % tidx_poststim = find(EEG_encoding.TF.times >= 0, 1) : find(EEG_encoding.TF.times <= 3000, 1, 'last');
        % 
        % [~, peak_tidx_db] = max(tmp_dat_db(tidx_poststim,:));
        % peak_tidx_db = tidx_poststim(1) + peak_tidx_db - 1;
        % peak_lats_db = EEG_encoding.TF.times(peak_tidx_db);
        % 
        % [~, peak_tidx_subtr] = max(tmp_dat_subtr(tidx_poststim,:));
        % peak_tidx_subtr = tidx_poststim(1) + peak_tidx_subtr - 1;
        % peak_lats_subtr = EEG_encoding.TF.times(peak_tidx_subtr);
        % 
        % %Average across time, individual peaks per trial
        % for tr = 1:size(tmp_dat_db,2)
        %     tr_tidx_db = find(EEG_encoding.TF.times >= (peak_lats_db(tr) - 250),1) : find(EEG_encoding.TF.times <= (peak_lats_db(tr) + 250),1, 'last');
        %     enc_values_db(tr,b) = mean(tmp_dat_db(tr_tidx_db, tr));
        % 
        %    tr_tidx_subtr = find(EEG_encoding.TF.times >= (peak_lats_subtr(tr) - 250),1) : find(EEG_encoding.TF.times <= (peak_lats_subtr(tr) + 250),1, 'last');
        %    enc_values_subtr(tr,b) = mean(tmp_dat_subtr(tr_tidx_subtr, tr));
        % end
        % clear tr
        % 
        % %store latency values
        % peaklat_db_enc(:,b) = peak_lats_db';
        % peaklat_subtr_enc(:,b) = peak_lats_subtr';

        %Raw baseline power values
        tmp_bl_pow = EEG_encoding.TF.tfdata_power(chidx,fidx, bl_tidx, :);
        bl_pow_enc(:,b) = squeeze(mean(tmp_bl_pow, [1 2 3]));



    end

    %create variable names per baseline method
    varnames_db = {};
    varnames_subtr = {};
    varnames_blpow = {};
    varnames_peaklat_db = {};
    varnames_peaklat_subtr = {};
    for v = 1:size(enc_values_db,2);
        varnames_db{v} = [encstruct(v).name, '_db'];
        varnames_subtr{v} = [encstruct(v).name, '_subtr'];
        varnames_blpow{v} = [encstruct(v).name, '_plow'];
        varnames_peaklat_db{v} = [encstruct(v).name, '_peaklat_db'];
        varnames_peaklat_subtr{v} = [encstruct(v).name, '_peaklat_subtr'];
    end

    %Store values in a table
    enc_values = [enc_values_db, enc_values_subtr, bl_pow_enc, peaklat_db_enc, peaklat_subtr_enc];
    enc_varnames = [varnames_db, varnames_subtr, varnames_blpow, varnames_peaklat_db, varnames_peaklat_subtr];

    enc_values = array2table(enc_values, "VariableNames", enc_varnames);
    enc_triallog = EEG_encoding.triallog_clean;
    enc_triallog.subID = repmat(subid, size(enc_triallog,1),1);
    enc_triallog = [enc_triallog, enc_values];

    %% Extract sleep values
    sleep_values_db = nan(EEG_sleep.trials, length(sleepstruct));
    sleep_values_subtr = nan(EEG_sleep.trials, length(sleepstruct));
    bl_pow_sleep = nan(EEG_sleep.trials, length(sleepstruct));
    peaklat_db_sleep = nan(EEG_sleep.trials, length(sleepstruct));
    peaklat_subtr_sleep = nan(EEG_sleep.trials, length(sleepstruct));

    for b = 1:length(sleepstruct) %loop over sleep freq-bands

        %Extract freqband information
        frband = sleepstruct(b);

       %Extract chan-freq indices
       tidx = find(EEG_sleep.TF.times >= frband.timerange(1),1) : find(EEG_sleep.TF.times <= frband.timerange(2),1, 'last');
       fidx = find(EEG_sleep.TF.freqs >= frband.freqrange(1), 1) : find(EEG_sleep.TF.freqs <= frband.freqrange(2), 1, 'last');
       chidx = find(contains(EEG_sleep.TF.chans, frband.chans));

        %Extract chan-frec-times-trial data
        tmp_dat_db = EEG_sleep.TF.tfdata_power_db(chidx, fidx, tidx, :);
        tmp_dat_subtr = EEG_sleep.TF.tfdata_power_subtr(chidx, fidx, tidx, :);

        %Avg over chan and freq
        sleep_values_db(:,b)  = squeeze(mean(tmp_dat_db, [1 2 3]));
        sleep_values_subtr(:,b) = squeeze(mean(tmp_dat_subtr, [1 2 3]));

        
        % Commented part for finding peaks in single trial data - but
        % likely too noisy
        % %Extract chan-frec-trial data
        % tmp_dat_db = EEG_sleep.TF.tfdata_power_db(chidx, fidx, :, :);
        % tmp_dat_subtr = EEG_sleep.TF.tfdata_power_subtr(chidx, fidx, :, :);
        % 
        % %Avg over chan and freq
        % tmp_dat_db = squeeze(mean(tmp_dat_db, [1 2]));
        % tmp_dat_subtr = squeeze(mean(tmp_dat_subtr, [1 2]));
        % 
        % 
        % %Find the time-window for peak activity (+/- 250 ms around post-stimulus peak from 0 to 300 ms)
        % tidx_poststim = find(EEG_sleep.TF.times >= 0, 1) : find(EEG_sleep.TF.times <= 3000, 1, 'last');
        % 
        % [~, peak_tidx_db] = max(tmp_dat_db(tidx_poststim,:));
        % peak_tidx_db = tidx_poststim(1) + peak_tidx_db - 1;
        % peak_lats_db = EEG_sleep.TF.times(peak_tidx_db);
        % 
        % [~, peak_tidx_subtr] = max(tmp_dat_subtr(tidx_poststim,:));
        % peak_tidx_subtr = tidx_poststim(1) + peak_tidx_subtr - 1;
        % peak_lats_subtr = EEG_sleep.TF.times(peak_tidx_subtr);
        % 
        % %Average across time, individual peaks per trial
        % for tr = 1:size(tmp_dat_db,2)
        %     tr_tidx_db = find(EEG_sleep.TF.times >= (peak_lats_db(tr) - 250),1) : find(EEG_sleep.TF.times <= (peak_lats_db(tr) + 250),1, 'last');
        %     sleep_values_db(tr,b) = mean(tmp_dat_db(tr_tidx_db, tr));
        % 
        %    tr_tidx_subtr = find(EEG_sleep.TF.times >= (peak_lats_subtr(tr) - 250),1) : find(EEG_sleep.TF.times <= (peak_lats_subtr(tr) + 250),1, 'last');
        %    sleep_values_subtr(tr,b) = mean(tmp_dat_subtr(tr_tidx_subtr, tr));
        % end
        % clear tr

        %%store latency values
        %peaklat_db_sleep(:,b) = peak_lats_db';
        %peaklat_subtr_sleep(:,b) = peak_lats_subtr';

        %Raw baseline power values
        tmp_bl_pow = EEG_sleep.TF.tfdata_power(chidx,fidx, bl_tidx, :);
        bl_pow_sleep(:,b) = squeeze(mean(tmp_bl_pow, [1 2 3]));


    end

    %create variable names per baseline method
    varnames_db = {};
    varnames_subtr = {};
    varnames_blpow = {};
    varnames_peaklat_db = {};
    varnames_peaklat_subtr = {};
    for v = 1:size(sleep_values_db,2);
        varnames_db{v} = [sleepstruct(v).name, '_db'];
        varnames_subtr{v} = [sleepstruct(v).name, '_subtr'];
        varnames_plpow{v} = [sleepstruct(v).name, '_plow'];
        varnames_peaklat_db{v} = [sleepstruct(v).name, '_peaklat_db'];
        varnames_peaklat_subtr{v} = [sleepstruct(v).name, '_peaklat_subtr'];
    end

    %Stpre values into a table
    sleep_values = [sleep_values_db, sleep_values_subtr, bl_pow_sleep, peaklat_db_sleep, peaklat_subtr_sleep];
    sleep_varnames = [varnames_db, varnames_subtr, varnames_plpow, varnames_peaklat_db, varnames_peaklat_subtr];
    sleep_values = array2table(sleep_values, "VariableNames", sleep_varnames);    
    
    sleep_triallog = EEG_sleep.triallog_clean;
    sleep_triallog.subID = repmat(subid, size(sleep_triallog,1),1);
    sleep_triallog = [sleep_triallog, sleep_values];

    %% For sleep data, find matching item encoding data
    sleep_triallog.enc_delta_db = nan(size(sleep_triallog,1), 1);
    sleep_triallog.enc_theta_db = nan(size(sleep_triallog,1), 1);
    sleep_triallog.enc_delta_subtr = nan(size(sleep_triallog,1), 1);
    sleep_triallog.enc_theta_subtr = nan(size(sleep_triallog,1), 1);

    for str = 1:size(sleep_triallog,1)
        if sleep_triallog.condition(str) ~= 3 %exlude "new" items

            item_idx_enc = find(sleep_triallog.itemID(str) == enc_triallog.itemID);

            %double check that item information matches (and that it exists
            %in encoding - could have been EEG artefact)
            if ~isempty(item_idx_enc)
                if enc_triallog.tmr_cued(item_idx_enc) == 1 && enc_triallog.afc_correctresp(item_idx_enc) == sleep_triallog.afc_correctresp(str)
                    sleep_triallog.enc_delta_db(str) = enc_triallog.delta_db(item_idx_enc) ;
                    sleep_triallog.enc_theta_db(str) = enc_triallog.theta_db(item_idx_enc) ;
                    sleep_triallog.enc_delta_subtr(str) = enc_triallog.delta_subtr(item_idx_enc) ;
                    sleep_triallog.enc_theta_subtr(str) = enc_triallog.theta_subtr(item_idx_enc) ;
                else
                    error("sleep and encoding triallogs do not match")
                end
            end

        end
    end

    %store participant files
    all_enc = [all_enc; enc_triallog];
    all_sleep = [all_sleep; sleep_triallog];

end %end filenames

%Save data
fname_enc = [pathout, 'encoding_singletrial_TF.csv'];
writetable(all_enc, fname_enc);

fname_sleep = [pathout, 'sleep_singletrial_TF.csv'];
writetable(all_sleep, fname_sleep);
