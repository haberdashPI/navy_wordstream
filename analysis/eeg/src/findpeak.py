from warnings import warn

# a 'peak' is the maximum value from a region of values that stands
# out above the other values

from numba import jit, void, float64, int64
@jit(void(float64[:],float64,int64,int64[:]))
def findpeaks__(xs,t,window,peak_indices):
  peakstart = -1
  peak_count = 0
  cursum = 0
  curN = 0
  for i in range(len(xs)):
    cursum += max(0,xs[i])
    curN += 1
    if curN > window:
      cursum -= max(0,xs[i-window])
      curN -= 1

    thresh = t * cursum/curN
    # print "cursum: ",cursum
    # print "thresh: ",thresh

    if peakstart < 0:
      if  xs[i] > thresh:
        if peak_count < len(peak_indices):
          peakstart = i
          peak_count += 1
          peak_indices[peak_count-1] = i
    else:
      if xs[i] > thresh:
        if xs[peak_indices[peak_count-1]] < xs[i]:
          peak_indices[peak_count-1] = i
      else:
        peakstart = -1

def findpeaks(xs,relt=0.95,window=512,maxpeaks=None):
  if maxpeaks == None:
    maxpeaks = len(xs)/10
  peak_indices = -np.ones(maxpeaks,dtype='int_')
  findpeaks__(xs,relt,window,peak_indices)
  indices = np.where(peak_indices >= 0)
  if np.all(peak_indices >= 0):
    warn("Max peaks ("+str(maxpeaks)+") reached. You may want to increase the maximum"+
         " number of peaks.")

  result = np.copy(peak_indices[indices])
  peak_indices[indices] = -1
  return result
