#Packages
from pathlib import Path
import mne
import yasa
import pandas as pd
import numpy as np
import os

#Filenames (continuous sleep files, preprocessed)
root_directory = 'XXX/a_continuous_filt_reref' 
all_filenames = [
    str(file) for file in Path(root_directory).rglob('*') 
    if file.is_file() and 'acq-eeg_task-sleep' in file.name and '.set' in file.name
]
print(all_filenames)

#root_directory = 'XXX'
#all_filenames = [
#    str(file) for file in Path(root_directory).rglob('*') 
#    if file.is_file() and 'acq-eegfmri_task-sleep_eeg.set' in file.name 
#]
#print(all_filenames)


for filename in all_filenames: 

    #Split filename into components
    fname_split = filename.split("/")                                   
    fname_bids = fname_split[-1].split('_')
    outpath_base = '/'.join(fname_split[1:10])
    outpath_base = os.path.join("/", outpath_base, "automatic_sleep_scoring")
    subid = fname_bids[0]

    #Load continuous sleep EEG
    raw = mne.io.read_raw_eeglab(filename, preload=True)
    #raw.plot(show=True)
    #print('The channels are:', raw.ch_names)


    #Sleep stage classification on C4 and C3
    sls_C4 = yasa.SleepStaging(raw, eeg_name="C4", eog_name="EOG1", emg_name="EMG1")
    hypno_str_C4 = sls_C4.predict() #hypnogramm in string
    hypno_int_C4 = yasa.hypno_str_to_int(hypno_str_C4) #hypnogram to integer
    confidence_C4 = sls_C4.predict_proba().max(1)  #confidence of the hypnogram

    sls_C3 = yasa.SleepStaging(raw, eeg_name="C3", eog_name="EOG1", emg_name="EMG1")
    hypno_str_C3 = sls_C3.predict() #hypnogramm in string
    hypno_int_C3 = yasa.hypno_str_to_int(hypno_str_C3) #hypnogram to integer
    confidence_C3 = sls_C3.predict_proba().max(1)  #confidence of the hypnogram

    #Merge hypnograms based on higher confidence
    hypno_merged = np.where(confidence_C3 >= confidence_C4, hypno_int_C3, hypno_int_C4)
    confidence_merged = np.where(confidence_C3 >= confidence_C4, confidence_C3, confidence_C4)


    #Artifact detection (sleep stage specific)
    hypno_int_upsampled = yasa.hypno_upsample_to_data(hypno_merged, 1/30, raw)
    art = yasa.art_detect(raw, window=30, hypno=hypno_int_upsampled, include=(0, 1, 2, 3, 4)) #results in artifact determination in 30-sec epochs

    #Merge hypnogram with artifact detection
    #hypno_int[art[0] == True] = -1

    #Sleep statistics
    #sleep_stat = yasa.sleep_statistics(hypno_int, sf_hyp=1/30)    # Setup sleep statistics in 30s epochs

    #Merge hypnogram with confidence
    ass_output = pd.DataFrame({'stage_C4': hypno_int_C4, 'stage_C3': hypno_int_C3, 'confidence_C4': confidence_C4, 'confidence_C3': confidence_C3, 'artifact': art[0]})

    #Save to path
    pathout = os.path.join(outpath_base, subid)
    os.makedirs(pathout, exist_ok=True)

    #Save hypno to CSV
    ass_output.to_csv(pathout + "/" + '_'.join(fname_bids[0:4]) + '_hypno_raw.csv') 

    #Save hypno figures per channels
    #hypno_plot_C4 = yasa.plot_hypnogram(hypno_int_C4, sf_hypno=1/30)
    #hypno_plot_C4 = hypno_plot_C4.figure
    #hypno_plot_C4.savefig(pathout + "/" + '_'.join(fname_bids[0:4]) + '_hypno_CF.jpg')
    #hypno_plot_C4.clf() 


    #Save confidence
    #confidence_plot = sls.plot_predict_proba()
    #confidence_plot = confidence_plot.figure
    #confidence_plot.savefig(pathout + "/" + '_'.join(fname_bids[0:4]) + '_confidenceinit.jpg')
    #confidence_plot.clf() 

    #Print progress
    print("processed: " + subid)

