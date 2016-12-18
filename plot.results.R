library(tidyr)
library(ggplot2)
library(plyr)
library(dplyr)

results = Reduce(rbind,Map(read.csv,list.files('data','*.csv',full.names=T)))

max_seconds = 80
times = seq(0,max_seconds,length.out=20)

s = subset(results,code %in% c('stimulus','stream_1','stream_2'))

by_time = ddply(s,c('sid','offset_time'),function(d){
    if(any(d$phase %in% c('practice','example'))) return(data.frame())

	stim = subset(d,code == 'stimulus')
	start_time = min(d$time,na.rm=TRUE)
	responses = subset(d,code %in% c('stream_1','stream_2'))

	old_code = 0
	old_index = 1
    if(nrow(responses) > 0){
        trial_duration = max(d$time,na.rm=T) - min(d$time,na.rm=T)
    }

    if(nrow(responses) > 0 && trial_duration < max_seconds){
        response_times = rep(0,length(times))
        for(r in 1:nrow(responses)){
            index = round((responses[r,]$time - start_time) /
                          max_seconds * length(times))

            response_times[old_index:index] = old_code
            if(responses[r,]$code == 'stream_1') old_code = 1
            else old_code = 2
            old_index = index
        }

        response_times[old_index:length(response_times)] =
            as.numeric(as.character(old_code))

        data.frame(time = times,response=response_times,context=stim$spacing[1],
                   stimulus = stim$stimulus[1],offset=stim$offset[1])
    }else data.frame()
})

by_context = by_time %>%
	filter(response > 0) %>%
	group_by(sid,time,stimulus,context) %>%
	summarise(response = mean(response-1))

legend = guide_legend(title='Context Stimulus')
ggplot(subset(by_context,sid == 'abin'),
	   aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')

#ggsave(paste('data/speech_streaming_joel_',Sys.Date(),'.pdf',sep=''))
