% The following script performs the necessary preprocessing steps of raw EEG data 
% described in https://doi.org/10.1101/2025.11.20.689416
%
% %
% Requires MATLAB (version 2019b or later; The MathWorks, Natick, MA)
% %
% Requires modification of data paths according to user
%
% %
% Dependencies
% Toolboxes
% Fieldtrip toolbox (version 20231015; https://www.fieldtriptoolbox.org/download)
% EEGLAB toolbox (version 13_4_4b; https://sccn.ucsd.edu/eeglab/download.php)

% Functions
% eeglab2fieldtrip_JC.m (in ../code/Functions): Modified MATLAB function for data conversion from eeglab to fieldtrip version
% inputsdlg.m (in ../code/Functions): Costum MATLAB function for input dialog box
% pan_tompkin.m (in ../code/Functions): Pubblic MATLAB function for Rpeaks
% detection on ECG data
% createMyTrl.m (in ../code/Functions): Costum MATLAB function to create a
% Nx3 matrix with the trial definition, useful for the trial segmentation
% fieldtrip function "ft_redefinetrial"

% Input
% One .mat eeg raw data files for each subject per vigilance state
% eeg_data: 64xN matrix where N is the number of samples at 1024 Hz sampling rate with 64 channels
% ecg_data: 1xN matrix where N is the number of samples at 1024 Hz sampling rate with 1 ECG channel

% ant64_elec.mat (in ../code/Layouts/)
%   Contains elec structure for electrodes in fieldtrip
% ant64_lay.mat (in ../code/Layouts/)
%   Contains lay structure for layout in fieldrip
% chanlocs64.mat (in ../code/Layouts/)
%   Contains chanlocs 64 for electrodes and layout in eeglab
% %
% Copyright (C) 2026  Jacinthe Cataldi 
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% %
%

%% Paths
%%%%% Path for fieldtrip and eeglab: insert here your paths
addpath /scripts/eeglab13_4_4b/; 
addpath /scripts/fieldtrip-20231015;
datapath = '/data/';

%% INIT:

%%%% change here with your infos
sr = 1024; % sampling rate
bandpass   = [0.5 30]; % bandpass filter frequencies

%% Filenames to save

%%%% initialize var names for saving
badchannelfilename = [];
icafilename = [];
ppcfilename = [];
rejcompfilename = [];

%% Prepare layouts

%%% load electrode layout and electrodes position
%%%% change here your paths
load('code/Layouts/ant64_lay.mat')
load('code/Layouts/ant64_elec.mat')
load('code/Layouts/chanlocs64.mat');

%%%% prepare layout
cfg = [];
cfg.channel         = lay.label;
cfg.layout          = 'standard_1020.elc';%
lay                 = ft_prepare_layout(cfg);

%%% extract neighbours
cfg=[];
cfg.method         = 'template';%, 'triangulation' or 'template'
cfg.template       = 'ant64_neighbours.mat';%name of the template file, e.g. CTF275_neighb.mat
cfg.layout         = lay;%filename of the layout
neighbours         = ft_prepare_neighbours(cfg);

%% load data
datafilename = 'data_s001'; %%% insert here your filename
data = []; data = load([datapath datafilename]);
varname = []; varname = fieldnames(data);

%% create fieldtrip data structure
data_eeg = []; data_eeg = data.(varname); % data: channels x timepoints
time = []; time = (1:length(data_eeg)).*(1/sr);

%%%%% create header structure
hdr = [];
hdr.Fs = sr;
hdr.nChans = length(lay.label);
hdr.label = lay.label;
hdr.nSamples = size(data_eeg,2);
hdr.nSamplesPre = 0;
hdr.nTrials = 1;
hdr.orig = [];
hdr.chantype = [];
hdr.chanunit = [];

data_eeg = [];
data_eeg.hdr = hdr;
data_eeg.fsample = sr;
data_eeg.sampleinfo = [1 size(data_eeg,2)];
data_eeg.trial = {double(data_eeg)};
data_eeg.time = {double(time)};
data_eeg.label = lay.label;
data_eeg.cfg = [];
% 
% %%%%% save fieldtrip structure
save([yourpath yourfilename],'data_eeg','-v7.3')

%% filtering
%%% This step is performed on continous data (for sleep on the entire
%%% night)
datainput = []; datainput = data_eeg.trial{1};
[nchan,nsp] = size(datainput);

%%%% filtersettings
low                     = bandpass(1);
high                    = bandpass(2);
sr                      = data_eeg.fsample;
filtorder               = 3*fix(sr/low);
revfilt                 = [];
usefft                  = 0;

%%%% eeglab format
eeglab;

EEGinput                     = eeg_emptyset;
EEGinput.data                = data_eeg;
EEGinput.times               = [1:nsp].*(1/sr);
EEGinput.nbchans             = nchan;
EEGinput.srate               = sr;
EEGinput                     = eeg_checkset(EEGinput);
EEGinput.setname             = 'test';
EEGinput                     = eeg_checkset(EEGinput);
EEGinput.trials = 1;
EEGinput.event = [];
EEGinput.event(1).eventtype = 'boundary';
EEGinput.event(1).eventlatency  = 1;
EEGinput.event(1).eventduration = 0;
EEGinput.pnts = nsp;

%%%% run filter
EEGout = []; EEGout = pop_eegfiltnew(EEGinput,  low, high, filtorder, revfilt, usefft);

%%%% put back in fieldtrip structure the filtered data
data_eeg.trial{1} = EEGout.data;

%% The following steps are run separately for each vigilance state
% where each vigilance state is contatenated

%% Bad channel inspection

%%%%%%%%%%%%%% settings
%%%to chose the mode check fieldtrip documentation for the function "ft_rejectvisual"
cnt.badChannelMode      = 2; %0 = trial mode, 1 = summary mode, 2 = both;
%%% insert here nseconds for visualzation for badchannel inspection (meaningful for the trial mode)
cnt.visual_inspect = 30; % n seconds

% Segment data in n seconds
cfg = []; data4vis = [];
cfg.length = cnt.visual_inspect;
data4vis = ft_redefinetrial(cfg, data_eeg);
                    
%%%%% Trial Mode
if cnt.badChannelMode ~= 1   
    cfg = [];
    cfg.method              = 'trial';
    cfg.keepchannel         = 'nan';
    cfg.keeptrial           = 'yes';
    cfg.metric              = 'maxabs';
    cfg.trial               = 'all';
    cfg.channel             = 'EEG';
    cfg.ylim                 ='maxmin';
    cfg.box = 'no';
    data4vis               = ft_rejectvisual(cfg,data4vis);
    badchannels_trials    = data4vis.cfg.badchannel;
    clear data4vis
end

%%%%%% Summary mode
if cnt.badChannelMode ~= 0    
    cfg = [];
    cfg.method              = 'summary';
    cfg.keeptrial           = 'yes';
    cfg.metric              = 'maxabs';
    cfg.trial               = 'all';
    cfg.channel             = 'EEG';
    cfg.neighbours          = neighbours;
    cfg.ylim                 ='maxmin';
    cfg.box = 'no';
    data4vis               = ft_rejectvisual(cfg,data4vis);
    badchannels_summary     = data4vis.cfg.badchannel;
    clear data4vis
end

%%%%%%% merge the badchannels of the 2 modes
badchannels = [];
if cnt.badChannelMode == 0
    badchannels = badchannels_trials; clear badchannels_trials
    
elseif cnt.badChannelMode == 1
    badchannels     = badchannels_summary; clear badchannels_summary
    
elseif cnt.badChannelMode == 2
    badchannels = unique(cat(1,badchannels_trials,badchannels_summary));
    clear badchannels_summary badchannels_trials
end

%%%%% save badchannels
datapath = '/subj/'; %%%% put here your path
filename = 'badchans'; %%%% put here your filename
save([datapath '/' badchannelfilename],'badchannels');

%% RunIca with eeglab
eeglab;

%%%% initialize and fill EEG struct
EEG                     = eeg_emptyset;
EEG.data                = data_eeg.trial{1};
EEG.subject             = subj;
EEG.srate               = data_eeg.fsample;

%%%%%%%% Chanlocs settings
chanlocs64 = struct2table(chanlocs64);
[~, idx] = ismember(data_eeg.label,chanlocs64.labels);
chanlocs64 = chanlocs64(idx,:);
chanlocs64 = table2struct(chanlocs64);

EEG.chanlocs            = chanlocs64; clear chanlocs64
EEG                     = eeg_checkset(EEG); eeglab redraw;

%%%%%%% extract bad channels
nbadchans = []; nbadchans  = unique(badchannels);

%%%%%%%% extracting good channels
allchans = []; idx = []; goodchans = [];
allchans = [1:size(EEG.data,1)];
idx = cellfun(@(A) find(strcmp(A, badchannels)), data_eeg.label, 'UniformOutput', false);
goodchans = allchans(find(cellfun('isempty',idx)));

%%%%%%%% RunICA
EEG = pop_runica(EEG, 'icatype', 'runica', 'chanind', goodchans);
    
%%%%%% save
save([finalpath icafilename],'EEG','-v7.3') %%%% change here your filename
clear badchannels data_eeg

%% PPC (taken from Buot et al, DOI:10.1016/j.biopsycho.2021.108165)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% settings
ecg_sr = 1024; %%%% insert here your ecg samplig frequency
%%%%%%%% insert here your PPC window
cnt.preStim             = 0.1; % expressed in seconds
cnt.postStim            = 0.5; % expressed in seconds
%%%%% insert here numbers of R-peaks that will constitute the windows
cnt.PPCWindowlength     = 1000; % expressed in r peaks

%%%% load ECG data in the fieldtrip format
load([datapath ecgfilename],'data_ecg')
ecg = []; ecg = data_ecg.trial{1};

%%%%%%% Detect Rpeaks
rpeaks = zeros(1,size(ecg,2));
[~,r,~] = pan_tompkin(ecg,ecg_sr,0);

%%%%%%% convert EEG struct (ICs) from eeglab to fieldtrip
ic_data = []; ic_data = eeglab2fieldtrip_JC(EEG, 'comp'); clear EEG

%%%%%%% Append the ecg data to the components
cfg = [];
comp = ft_appenddata(cfg, data_ecg, ic_data); clear ic_data

%%%%%% Segment around Rpeak
cfg = [];
cfg.prestim = cnt.preStim;
cfg.poststim = cnt.postStim;
trl = createMyTrl(cfg,r,sr);

cfg = [];
cfg.trl = trl;
comp = ft_redefinetrial(cfg,comp);
clear trl r

%%%%%% segment into time windows
num_windows = floor(length(comp.trial)/cnt.PPCWindowlength);

if num_windows < 1
    num_windows = 1;
end

%%%%%%% loop of windows
meanppc_window = [];
for i = 1:num_windows % windows loop

    %%%%%%% segment data 
    start_idx =  []; end_idx = [];
    start_idx = (i - 1) * (cnt.PPCWindowlength) + 1;

    if i == num_windows
        end_idx = length(comp.trial);
    else
        end_idx = min(start_idx + cnt.PPCWindowlength - 1,length(comp.trial));
    end

    temp_window = []; freq_temp = []; fdcomp_temp = [];
    cfg             = [];
    cfg.trials      = [start_idx : end_idx];
    temp_window = ft_selectdata(cfg, comp);

    %%%%%%% Compute a frequency decomposition of all components and the ECG
    cfg            = [];
    cfg.method     = 'mtmfft';
    cfg.output     = 'fourier';
    cfg.foilim     = [0 100];
    cfg.taper      = 'hanning';
    freq_temp      = ft_freqanalysis(cfg, temp_window);

    %%%%%%% Compute ppc between all components and the ECG
    cfg            = [];
    cfg.jackknife  = 'no';
    cfg.method     = 'ppc';  % pairwise phase consistency method: better than "coh" when reduced number of trials
    cfg.channelcmb = {'all' 'ECG'};
    fdcomp_temp    = ft_connectivityanalysis(cfg, freq_temp);

    %%%%%%% select cardiac components with ppc value in [0-25Hz]
    indfreq_temp = find(fdcomp_temp.freq <= 25);
    for ncomp = 1:size(fdcomp_temp.ppcspctrm,1)
        meanppc_window(ncomp,i) = mean(fdcomp_temp.ppcspctrm(ncomp,1:indfreq_temp(end)));
    end

end % windows loop

 %%%% save
 save([datapath ppcfilename],'meanppc_window')

%% Continous ICA inspection for Basic and CFA ICs

%%%%% complete here if you want visualize with fieldtrip or eeglab
cnt.fieldtripVis        = 1; %1 = visualize with fieldtrip mode
cnt.eeglabVis           = 0; %1 = visualize with eeglab mode
freq1 = 0.5; %%%%% insert here your freq range
freq2 = 30;
comptype = {'Basic_IC','CFA_IC'}; % types of rejected comps, useful to store the ICs ids separately

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% eeglab
if cnt.eeglabVis == 1
    %%%%%%% Plot components
    typecomp = 0;
    pop_prop_extended(EEG,typecomp,3,{ 'freqrange' [freq1 freq2] });
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Fieldtrip
%%%%%% visualize with fieldtrip
if cnt.fieldtripVis == 1
    
    %%%%%%% convert EEG struct to fieldtrip
    ic_data = eeglab2fieldtrip_JC(EEG, 'comp');
    
    %%%%%%% prepare a layout
    cfg = [];
    cfg.channel         = elec.label;
    cfg.layout          = 'standard_1020.elc';%
    cfg.feedback        = 'no';
    lay                 = ft_prepare_layout(cfg);
    
    %%%%%%% chanlocs
    cfg = [];
    cfg.layout         = lay;
    cfg.senstype       = 'eeg';
    cfg.elec =         chanlocs;
    
    %%%%%%% plot
    dataFig = figure('Name', 'Data Browser');
    cfg               = [];
    cfg.viewmode      = 'component';
    cfg.continuous    = 'yes';
    cfg.blocksize     = 20;
    cfg.channels      = [1:15];
    cfg.layout        = lay;
    cfg.compscale     = 'local';
    ft_databrowser(cfg,ic_data);
    
    %%%%%% Wait to close browser
    waitfor(dataFig);
end % fieldtrip

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Report ICs you want to reject
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BASIC
Prompt(1,:) = {'Enter Basic ICs to be rejected (space-sep-e.g. 1 4 7)', 'comp',[]};
name='Component Rejection'; formats(1,1).type = 'edit'; formats(1,1).format = 'text';
formats(1,1).limits = [0 1];
DefAns = struct([]); DefAns(1).comp = [];
basic_comps = []; [basic_comps,~] = inputsdlg(Prompt,name,formats,DefAns);
compID.(comptype{1}) = basic_comps.comp;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CFA
Prompt(1,:) = {'Enter CFA ICs to be rejected (space-sep-e.g. 1 4 7)', 'comp',[]};
name='Component Rejection'; formats(1,1).type = 'edit'; formats(1,1).format = 'text';
formats(1,1).limits = [0 1];
DefAns = struct([]); DefAns(1).comp = [];
cfa_comps = []; [cfa_comps,~] = inputsdlg(Prompt,name,formats,DefAns);
compID.(comptype{2}) = cfa_comps.comp;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% save
save([datapath '/' rejcompfilename], 'compID')

%% Calculate PPC threshold

subjectlist = [1:30]; %%% insert here your subjects

for subj = subjectlist
    %%%% load components
    load([finalpath compfile],'compID')
    %%%% load ppc values
    load([datapath ppcfile],'meanppc_window')

    %%%% extract ppc value of cfa comps
    if ~isempty(compID.CFA_IC)
        cfa_ppc(subj) = nanmedian(meanppc_window(str2num(compID.CFA_IC),:));
    else
        cfa_ppc(subj) = NaN;
    end
end

threshold = []; threshold = min(cfa_ppc(:));

%% Recostruct data after IC inspection for pipeline 1: CFA only
%%%% load EEGlab ICA data
load([finalpath icafilename],'EEG')
% isolate info
temp = []; temp = EEG.reject.gcompreject;

%%%%% load your fieldtrip structure to fill it with reconstruct data
load([yourpath yourfilename],'data_eeg')
data_eeg.trial = [];

%%%%% reconstruct signal
Rej_comp = [];
if ~isempty(compID.comp)
    % extract basic and CFA components
    Basic_comp = []; Basic_comp = sort(unique(str2num(compID.Basic_IC)));
    Cfa_comp = []; Cfa_comp = sort(unique(str2num(compID.CFA_IC)));

    % merge components
    Rej_comp = []; Rej_comp = sort(cat(2,Basic_comp,Cfa_comp));

    % fill the eeglab field
    EEG.reject.gcompreject(Rej_comp) = 1;
    
    % reconstruct signal
    EEG = pop_subcomp( EEG, [], 0);
end

% save into fieldtrip structure
data_eeg.trial = []; data_eeg.trial = {EEG.data};

% save data
save([yourpath '/' yourfilename.mat],'data_eeg','Rej_comp','-v7.3') %% this is the output of pipeline 1

%% For pipeline 2 (CFA & PA): Inspect PA flagged components only for the "bad" windows

%%%%%%% calculating max value per component
max_pccovertime = [];
for n = 1:size(meanppc_window,1)
    max_pccovertime(n) = max(meanppc_window(n,:));
end
%%%% finding components > threshold
comp_PPC = find(max_pccovertime>threshold);

%%%%%% load rpeaks
%%%%% extract r timepoints (beg and end) for each window of 1000 rpeaks
r_beg = []; r_beg = r(1:cnt.PPCWindowlength:end);
r_end = []; r_end = r(cnt.PPCWindowlength:cnt.PPCWindowlength:end);

%%%%%% checkings
if length(r)/(cnt.PPCWindowlength) > 0 && length(r)/(cnt.PPCWindowlength)<1
    num_windows =1 ;
    r_end = r(end);
else
    r_end(end) = r(end);
end
if length(r_beg)<length(num_windows)
                r_beg(end) = [];
end

%%%%% loop of windows
for w = 1:length(meanppc_window,2)

    % extract comp > threshold
    currcomps = []; currcomps = find(meanppc_window(:,w)>threshold);
    if isempty(currcomps)
        continue
    end

    %%%%% remove comps identified as basic and CFA
    comm_comp = []; [comm_comp,id_currcomps,~] = intersect(currcomps,comps.Basic_IC);
    currcomps(id_currcomps) = [];
    if ~isempty(comps.CFA_IC)
        comm_comp = []; [comm_comp,id_currcomps,~] = intersect(currcomps,comps.CFA_IC);
        currcomps(id_currcomps) = [];
    end

    if isempty(currcomps)
        continue
    end

    %%%%% start and end for w window
    start_data = []; start_data = r_beg(w)-round(cnt.preStim*cnt.fs);
    end_data = []; end_data = r_end(w)+round(cnt.postStim*cnt.fs);

    %%%% segment data
    trl = [start_data,end_data,end_data-end_data];
    cfg = [];
    cfg.trl = trl;
    wnd_data = ft_redefinetrial(cfg,ic_data); %%%%% ic_data: components in fieldtrip format
    r_seg = []; r_seg = r(r>start_data & r<end_data);

    %%%%% create events based on R peaks for visualization
    event = struct;
    for r_p = 1:length(r_seg)
        event(r_p).sample = r_seg(r_p,1);
        event(r_p).duration = 1;
        event(r_p).offset = 0;
        event(r_p).type = 'r';
        event(r_p).value = 'R';
    end

    %%%% extract component 2 plot
    complabel = []; complabel = wnd_data.label(currcomps);

    % plot bad components for w window
    %%%%%%% plot
    dataFig = figure('Name', 'Data Browser');

    cfg               = [];
    cfg.viewmode      = 'component';
    cfg.continuous    = 'yes';
    cfg.blocksize     = 20;
    cfg.channel      = complabel';
    cfg.layout        = 'EEG1010.lay';
    cfg.compscale     = 'local';
    cfg.event         = event;
    cfg.linewidth     = 0.03;
    cfg.axisfontsize            = 6;
    cfg.ploteventlabels = 'colorvalue';
    ft_databrowser(cfg,wnd_data);


    %%%%% ask for comp 2 reject
    Prompt(1,:) = {['Enter ICs with pulse (space-sep-e.g. 1 4 7)'], 'comp',[]};
    name='Pulse Component Rejection'; formats(1,1).type = 'edit'; formats(1,1).format = 'text';
    formats(1,1).limits = [0 1];
    DefAns = struct([]); DefAns(1).comp = 'None';
    pulse_comps = []; [pulse_comps,~] = inputsdlg(Prompt,name,formats,DefAns);

    compID_pulse.(['wnd' num2str(w)]) = pulse_comps.comp;
end

 save([yourpath 'yourfilename'],'compID_pulse')

 %% ectract Pulse components
 %%%% load file
 load([yourpath 'yourfilename'],'compID_pulse')

 %%%%% time-windows loop
 wnd_all = []; wnd_all = fieldnames(compID_pulse);
 pulseIC = [];
 for w = 1:length(wnd_all) % window loop
     temp = []; temp = sort(unique(str2num(compID_pulse.(wnd_all{w}))));
     if isempty(temp)
         temp = [];
     end
     pulseIC = cat(2,pulseIC,temp);
 end % window loop

 Pulsecomp = []; Pulsecomp = sort(unique(pulseIC));

 save([yourpath 'yourfilename'],'Pulsecomp')

%% Reconstruct the signal for pipeline 2 (CFA & PA)

% load info about rej components (basic + cfa), extracted already for pipeline 1
load([yourpath '/' yourfilename.mat],'Rej_comp')

% load info of pulse components
load([finalpath '/' filename],'Pulsecomp')

% merge all the components 2 reject
Rej_comp_pulse = []; Rej_comp_pulse = sort(unique(cat(2,Rej_comp,Pulsecomp)));

% load EEG data 2 reconstruct (same input that pipeline 1)
load([finalpath icafilename],'EEG')

% fill info for comps
EEG.reject.gcompreject(Rej_comp_pulse) = 1;

% reconstruct signal
EEG = pop_subcomp( EEG, [], 0);

% save into fieldtrip structure
data_eeg.trial = []; data_eeg.trial = {EEG.data};

% save data
save([yourpath 'yourfilename'],'data_eeg', 'Rej_comp_pulse','-v7.3')

%% The following steps need to be run for both outputs of the 2 pipelines

% Interpolate badchannels

%%%% load badchannels
load([finalpath '/' filename],'badchannels');

cfg = [];
cfg.layout       = lay;
cfg.method       = 'spline';
cfg.badchannel   = allbadchans;
cfg.neighbours   = neighbours;
cfg.elec         = chanlocs;
data_eeg         = ft_channelrepair(cfg, data_eeg);

%%%% save data
save([yourpath '/' yourfilename],'data_eeg','-v7.3');

%% Trial segmentation and rejection

cnt.pre     = 0.1; % in second
cnt.post    = 0.6; % in second
cnt.fs      = 1024;

%%%% load or extract stimtimes
load([path filename],'trg_times'); %in timepoint

%%%%% prepare segmentation and create the trl
trl = [];
trg_times_beg = (trg_times-round(cnt.pre*cnt.fs+1));
trg_times_end = (trg_times+round(cnt.post*cnt.fs));
trl = cat(2,trg_times_beg,trg_times_end,repmat(round(cnt.pre*cnt.fs+1)+round(cnt.post*cnt.fs),length(trg_times),1));
            
%%%% segment data
cfg = []; data_seg = [];
cfg.trl = trl;
data_seg = ft_redefinetrial(cfg,data_eeg);

%%%%% visualize bad trial
cfg = []; temp = [];
cfg.method              = 'summary';%'channel';
cfg.keeptrial           = 'no';
cfg.metric              = 'maxabs';%'var';
cfg.channel             = 'EEG';
cfg.ylim                = 'maxmin';
temp                    = ft_rejectvisual(cfg,data_seg);
good_trials(1,:) = find(ismember(data_seg.sampleinfo(:,1),temp.sampleinfo(:,1)));

%%%% save
save([finalpath 'filename.mat'],'data_seg','good_trials', 'trl','-v7.3')