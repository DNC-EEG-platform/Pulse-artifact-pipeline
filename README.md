# Pulse-artifact-pipeline

REFERENCE
The following script performs the necessary preprocessing steps of raw EEG data 
% described in https://doi.org/10.1101/2025.11.20.689416

DEPENDENCIES
MATLAB (version 2019b or later; The MathWorks, Natick, MA)
Fieldtrip (version 20231015; https://www.fieldtriptoolbox.org/download)
EEGLAB (version 13_4_4b; https://sccn.ucsd.edu/eeglab/download.php)

CONTENTS
Preprocessing_CFA_PA.m: Main costum MATLAB script that performs all pre-processing steps for EEG data
eeglab2fieldtrip_JC.m (in ../code/Functions): Modified MATLAB function for data conversion from eeglab to fieldtrip version
inputsdlg.m (in ../code/Functions): Costum MATLAB function for input dialog box
pan_tompkin.m (in ../code/Functions): Pubblic MATLAB function for Rpeaks detection on ECG data
createMyTrl.m (in ../code/Functions): Costum MATLAB function to create a Nx3 matrix with the trial definition, useful for the trial segmentation fieldtrip function "ft_redefinetrial"

INPUT
One .mat eeg raw data files for each subject per vigilance state
eeg_data: 64xN matrix where N is the number of samples at 1024 Hz sampling rate with 64 channels
ecg_data: 1xN matrix where N is the number of samples at 1024 Hz sampling rate with 1 ECG channel

AUTHORS
Copyright (c) 2026 Jacinthe Cataldi
Brain-body and consciousness laboratory
Department of Clinical Neurosciences (DNC)
Lausanne University Hospital (CHUV) and University of Lausanne (UNIL)
Mont-Paisible 16, CH-1011 Lausanne, Switzerland
Email: jacinthe.cataldi@chuv.ch, Marzia.De-Lucia@chuv.ch
Last updated: November 2026
