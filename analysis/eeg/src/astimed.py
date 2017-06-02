import numpy as np
from numba import jit, float64, void, int64

@jit(int64(int64[:],int64[:],int64[:]))
def __astimed(xs,ys,ts):
  ys[0] = xs[0]
  ts[0] = 0
  last = xs[0]
  count = 1

  for i in range(len(xs)):
    if xs[i] != last:
      ys[count] = xs[i]
      ts[count] = i
      count += 1
      last = xs[i]

  return count

def astimed(xs,sr):
  ys = np.zeros(xs.shape,'int64')
  ts = np.zeros(xs.shape,'int64')
  count = __astimed(xs,ys,ts)
  return ys[0:count], ts[0:count] / float(sr)
