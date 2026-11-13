clear all; close all; clc

eeglabpath = 'XXX\eeglab2025.0.0\';
%addpath(eeglabpath)
%eeglab nogui


%% Load data
load("TFfigurdata.mat")

%% Combined figure: TF maps (wake, sleep) + topography grid — manual layout
% 
% channame = 'Cz';
% chanind = find(strcmp(channame, TFparams.labels));
% 
fignames    = {'fulldat_enc', 'fulldat_sleep_learned', 'fulldat_sleep_new'};
figtitles   = {'encoding', 'sleep-learned', 'sleep-new'};
% structnames = {encstruct, sleepstruct, sleepstruct};
% 
% EEGchans = [1:24,30];
% chanlocs = TFparams.chanlocs(EEGchans);
% 
% allmaps  = cat(3, wakemaps, sleepmaps_learned, sleepmaps_new);
% meanmaps = squeeze(mean(allmaps,2));
% topotitles = {{'wake','delta'}, {'wake','theta'}, {'sleep','delta'}, ...
%               {'sleep-learned','theta'}, {'sleep-learned','low sigma'}, {'sleep-learned','high sigma'}, ...
%               {'sleep-new','theta'}, {'sleep-new','low sigma'}, {'sleep-new','high sigma'}};

%% ===================== Settings (edit these) ==========================
width_cm  = 15;
height_cm = 12;
fs = 8;    % base font size

tf_clim = [-3 3];       % colour limits TF maps

% TF maps (top row): fignames/figtitles/structnames{1:3} in the order
% wake, sleep-learned, sleep-new

% Topography grid: rows = states, columns = frequency bands
row_labels = {{'wake'}, {'sleep', 'learned'}, {'sleep', 'new'}};
col_labels = {{'delta', '1-4 Hz'}, {'theta', '4-8 Hz'}, {'low sigma', '9-12 Hz'}, {'high sigma', '12-16 Hz'}};

% Column of meanmaps for each slot (NaN = leave empty)
topo_idx = [ 1   2   NaN NaN ;    % wake:          delta theta  -     -
             3   4   5    6  ;   % sleep-learned: delta theta  lowS  highS
             7   8   9    10 ];   % sleep-new:     delta theta  lowS  highS

% Colour limits per frequency band (one row per column of topo_idx).
% NaN = automatic (min/max of all maps in that band)
topo_clims = [ NaN NaN ;    % delta
               NaN NaN ;    % theta
               NaN NaN ;    % low sigma
               NaN NaN ];   % high sigma

tf_cb_label   = 'Power (dB)';     % adjust to your units
topo_cb_label = 'dB';

%% ===================== Layout geometry (normalized) ===================
x0     = 0.12;              % left edge of panels (room for row labels)
x1     = 0.87;              % right edge of panels
cb_x   = 0.90;              % TF colour bar
cb_w   = 0.015;

tf_y   = 0.64;              % top row
tf_h   = 0.30;
tf_gap = 0.04;
tf_w   = (x1 - x0 - 2*tf_gap) / 3;

tp_y0  = 0.10;              % topo grid: bottom (room for colour bars below)
tp_y1  = 0.50;              % topo grid: top
n_r    = size(topo_idx, 1);
n_c    = size(topo_idx, 2);
cell_w = (x1 - x0) / n_c;
cell_h = (tp_y1 - tp_y0) / n_r;

%% ===================== Colour limits per band =========================
for c = 1:n_c
    idx  = topo_idx(~isnan(topo_idx(:, c)), c);
    vals = meanmaps(:, idx);
    auto = [min(vals(:)), max(vals(:))];
    for j = 1:2
        if isnan(topo_clims(c, j)), topo_clims(c, j) = auto(j); end
    end
end

%% ===================== Figure ==========================================
figall = figure('Color', 'w', 'Units', 'centimeters', ...
                'Position', [2 2 width_cm height_cm], ...
                'DefaultAxesFontSize', fs, 'DefaultTextFontSize', fs);

%% ---- Top row: TF maps at Cz ----
for sp = 1:3
    ax = axes('Position', [x0 + (sp-1)*(tf_w + tf_gap), tf_y, tf_w, tf_h]);

    tmpdata = eval(fignames{sp});
    tmpdata = squeeze(mean(tmpdata(chanind, :, :, :), 4, 'omitnan'));
    imagesc(TFparams.times, TFparams.freqs, tmpdata);
    axis xy;
    colormap(ax, 'jet');
    clim(ax, tf_clim);
    xlim([-500 3000]);
    xlabel('Time (ms)');
    if sp == 1
        ylabel('Frequency (Hz)');
    else
        set(ax, 'YTickLabel', []);
    end
    title(figtitles{sp});

    hold on
    thisstruct = structnames{sp};
    for k = 1:numel(thisstruct)
        tr = thisstruct(k).timerange;
        fr = thisstruct(k).freqrange;
        rectangle('Position', [tr(1), fr(1), diff(tr), diff(fr)], ...
                  'EdgeColor', 'k', 'LineWidth', 1.5, 'FaceColor', 'none');
    end
    hold off
end
pos = ax.Position;
cb1 = colorbar(ax);
cb1.Position = [cb_x, tf_y, cb_w, tf_h];
ax.Position  = pos;
ylabel(cb1, tf_cb_label);

%% ---- Bottom: topography grid, one colour scale per band ----
for c = 1:n_c
    ax_bottom = [];
    for r = 1:n_r
        idx = topo_idx(r, c);
        if isnan(idx), continue; end
        ax_t = axes('Position', [x0 + (c-1)*cell_w, tp_y1 - r*cell_h, cell_w, cell_h]);
        topoplot(meanmaps(:, idx), chanlocs, 'maplimits', topo_clims(c, :), ...
                 'plotrad', 0.5, 'electrodes', 'off');
        ax_bottom = ax_t;
    end

    % horizontal colour bar under this column
    pos = ax_bottom.Position;
    cb = colorbar(ax_bottom, 'southoutside');
    cb.Position = [x0 + (c-1)*cell_w + 0.15*cell_w, tp_y0 - 0.035, 0.7*cell_w, 0.012];
    ax_bottom.Position = pos;
    xlabel(cb, topo_cb_label);

    % column header
    annotation('textbox', [x0 + (c-1)*cell_w, tp_y1, cell_w, 0.04], ...
               'String', col_labels{c}, 'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
               'FontSize', fs, 'FontWeight', 'bold');
end

% row labels
for r = 1:n_r
    annotation('textbox', [0, tp_y1 - r*cell_h, x0 - 0.01, cell_h], ...
               'String', row_labels{r}, 'EdgeColor', 'none', ...
               'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
               'FontSize', fs, 'FontWeight', 'bold');
end

%% ---- Panel letters ----
annotation('textbox', [0.01, tf_y + tf_h, 0.04, 0.04], 'String', 'A', ...
           'EdgeColor', 'none', 'FontSize', fs+3, 'FontWeight', 'bold');
annotation('textbox', [0.01, tp_y1, 0.04, 0.04], 'String', 'B', ...
           'EdgeColor', 'none', 'FontSize', fs+3, 'FontWeight', 'bold');

%% ===================== Save ===========================================
figname =  'TFmap.png';
exportgraphics(figall, figname, 'ContentType', 'image', 'Resolution', 300, ...
               'BackgroundColor', 'white');

% Vector version:
 exportgraphics(figall,  'TFmap.pdf', 'ContentType', 'vector', ...
                'BackgroundColor', 'white');