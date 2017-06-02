import sys
import os
import os.path as op
import numpy as np
import mne
import collections
from scipy.ndimage.filters import maximum_filter1d as maxfilter
from scipy.signal import butter, filtfilt

execfile("local_settings.py")
execfile("src/findpeak.py")
execfile("src/normalize.py")

name = "Jared_04_03_17"

data_dir = op.realpath(op.join("..","..","data"))

raw = mne.io.read_raw_fif(op.join(temp_dir,name+"_noblink.fif"))
events = raw.copy().load_data().pick_channels(['Erg1'])
events.filter(l_freq=40,h_freq=None,picks=[0],phase='zero')

x = events.get_data()
y = np.maximum(0,x)

sample_rate = 512
b,a = butter(2,2.5 / (512.0/2), 'low')
y = filtfilt(b,a,y)

yd = np.hstack([[[0]],np.diff(y)])
peaks = findpeaks(np.squeeze(yd),0.99,512*3)

# plt.plot(np.hstack([x.T/np.max(x),yd.T/np.max(yd)]))
# for i in peaks:
#   plt.axvline(x=i,color='red')
