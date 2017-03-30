trial_to_times = function(trial,max_seconds,
                          times=seq(0,max_seconds,length.out=100)){

  if(any(trial$phase %in% c('practice','example'))) return(data.frame())

	stim = subset(trial,code == 'stimulus')
	start_time = min(trial$time,na.rm=TRUE)
	responses = subset(trial,code %in% c('stream_1','stream_2'))

	old_code = 0
	old_index = 1
  if(nrow(responses) > 0){
    trial_duration = max(trial$time,na.rm=T) - min(trial$time,na.rm=T)
  }

  if(nrow(responses) > 0 && trial_duration < max_seconds){
    response_times = rep(0,length(times))
    for(r in 1:nrow(responses)){
      index = max(1,round((responses[r,]$time - start_time) /
                          max_seconds * length(times)))

      response_times[old_index:index] = old_code
      if(responses[r,]$code == 'stream_1'){
        old_code = 1
      }else{
        old_code = 2
      }
      old_index = index
    }

    response_times[old_index:length(response_times)] =
      as.numeric(as.character(old_code))

    data.frame(time = times,response=response_times,context=stim$spacing[1],
               stimulus = stim$stimulus[1],trial=stim$trial[1])
  }else data.frame()
}
