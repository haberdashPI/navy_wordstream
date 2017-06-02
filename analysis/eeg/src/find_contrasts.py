# TODO: try backends other than wxpython
# TODO: find a way to save the results of averaging for each participant
# to cache most of the work
import pandas as pd
import numpy as np
import os.path as op
import mne
import collections

def contrast_apply(fn,contrasts):
  for cond in contrasts['mean'].keys():
    contrasts['mean'][cond] = fn(contrasts['mean'][cond])

    for i in range(len(contrasts['ind'][cond])):
      contrasts['ind'][cond][i] = fn(contrasts['ind'][cond][i])

def re_reference(contrasts,ref_channels):
  fn = lambda x: mne.set_eeg_reference(x,ref_channels=ref_channels,copy=False)[0].apply_proj()
  contrast_apply(fn,contrasts)

def find_contrasts(names,stim_files,contrasts,suffix="_noblink",**params):
  contrast_labels = {}
  for i,key in enumerate(contrasts.keys()):
    contrast_labels[key] = 2**i

  evoked = collections.defaultdict(list)
  coverage = collections.defaultdict(list)
  counts = collections.defaultdict(list)

  for name,stim in zip(names,stim_files):
    events = pd.read_table(op.join(data_dir,"events",stim))
    events['samples'] = np.floor(events.Tmu * 1e-6 * 512)
    events['dummy'] = 0
    events['contrasts'] = 0
    for i,vals in enumerate(contrasts.values()):
      events['contrasts'] += (2**i)*events['TriNo'].isin(vals)

    event_mat = events[['samples','dummy','contrasts']].as_matrix().astype('int_')
    raw = mne.io.read_raw_fif(op.join(temp_dir,name+suffix+".fif"))
    picks = mne.pick_types(raw.info,eeg=True)

    epochs = mne.Epochs(raw,event_mat,event_id = contrast_labels,
                        picks=picks,**params)

    # import pdb; pdb.set_trace()

    means = {}
    for key,val in contrast_labels.items():
      evoked_dir = op.join(temp_dir,"evokeds")
      if not op.isdir(evoked_dir): os.mkdir(evoked_dir)

      evoked_file = op.join(evoked_dir,name+"_"+key+".fif")
      if op.isfile(evoked_file):
        print evoked_file,"already generated, skipping..."
        means[key] = mne.Evoked(evoked_file,key)
      else:
        means[key] = epochs[key].average()
        means[key].comment = key
        means[key].save(evoked_file)

      N = (event_mat[:,2] == contrast_labels[key]).sum()
      percent = (float(means[key].nave) / N)
      print "%2.1f%% of %s kept" % (100*percent,key)
      coverage[key].append(percent)
      counts[key].append(N)

    for key,val in means.items():
      evoked[key].append(val)

    keys = list(means.keys())
    for i in range(len(keys)-1):
      for j in range(i+1,len(keys)):
        a = keys[i]
        b = keys[j]
        ab = mne.combine_evoked([evoked[a][-1],evoked[b][-1]],[1,-1])
        print "Working on: ",a+' - '+b
        evoked[a+' - '+b].append(ab)

  grand_average = {}
  for key,val in evoked.items():
    grand_average[key] = mne.grand_average(val)
    grand_average[key].comment = key

  return dict(ind=evoked,mean=grand_average,coverage=coverage,counts=counts)
