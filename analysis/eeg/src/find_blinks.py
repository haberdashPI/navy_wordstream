import progressbar
from mne.preprocessing.peak_finder import peak_finder

def epochs_for_blink_search(raw,window_size=5,window_overlap=0.05,
                            l_filter=1,h_filter=10,reject=dict(eeg=200e-6),
                            return_filtered=False):
  window_step = window_size-window_overlap/2
  window_half_size = window_size/2 + window_overlap/2

  # look only in frequencies close to the eyeblink rate
  print "copying raw data..."
  picks = mne.pick_types(raw.info,eeg=False,eog=True,selection=['IO1','IO2'])
  eye_raw = raw.copy().filter(l_freq=l_filter,h_freq=h_filter,
                              l_trans_bandwidth='auto',filter_length='auto',
                              h_trans_bandwidth='auto',
                              phase='zero',picks=picks)
  events = eye_raw.time_as_index(np.arange(raw.times[0],raw.times[-1],window_step))
  evt_mat = np.stack([events,
                      np.zeros(len(events)),
                      np.ones(len(events))]).astype('int_')

  # reject on the basis of raw info, but return filtered data
  # for peak finding
  print "epoching..."
  raw_epochs = mne.Epochs(raw,evt_mat.T,tmin=-window_half_size,tmax=window_half_size,
                          reject=reject,baseline=None)
  raw_epochs.drop_bad()

  epochs = mne.Epochs(eye_raw,evt_mat.T,tmin=-window_half_size,tmax=window_half_size,
                      baseline=None)
  epochs.drop(~np.in1d(epochs.selection,raw_epochs.selection))

  dropped = sum(map(lambda x: len(x) > 0,raw_epochs.drop_log))
  print "%2.1f%% of epochs dropped" % (100*dropped/(dropped+float(len(raw_epochs))))

  if return_filtered:
    return epochs,eye_raw
  else:
    return epochs


def search_for_blinks(epochs,window_size=5,window_overlap=0.05,thresh=25e-6,
                      min_index=None,max_index=None,return_average=False):
  window_step = window_size-window_overlap/2
  window_half_size = window_size/2 + window_overlap/2

  blinks = []
  count = 0
  bar = progressbar.ProgressBar(max_value=len(epochs.selection)-1)

  events = raw.time_as_index(np.arange(raw.times[0],raw.times[-1],window_step))
  evt_mat = np.stack([events,
                      np.zeros(len(events)),
                      np.ones(len(events))]).astype('int_')

  picks = mne.pick_types(raw.info,eeg=False,eog=True,selection=['IO1','IO2'])
  window_start = np.floor(raw.info['sfreq']*-window_half_size).astype('int_')

  oldout = sys.stdout
  null = open(os.devnull,'w')
  for evoked in epochs.iter_evoked():
    bar.update(count)
    if min_index != None and count < min_index:
      continue
    if max_index != None and count > max_index:
      break

    index_offset = evt_mat[0,epochs.selection[count]] + window_start
    # print "index_offset: ", index_offset

    channel_average = np.mean(evoked.data[picks,:],axis=0)
    sys.stdout = null
    indices,_ = peak_finder(np.abs(channel_average),thresh)
    sys.stdout = oldout
    blinks = np.concatenate([blinks,(indices + index_offset).astype('int_')])
    count += 1

    # if len(indices) > 0:
    #   print indices
    #   print count
    #   break

  null.close()

  if return_average:
    return np.unique(blinks), channel_average
  else:
    return np.unique(blinks)
