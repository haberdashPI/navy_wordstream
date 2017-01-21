library(tidyr)
library(ggplot2)
library(dplyr)
source('trial_to_times.R')

file_pat = 'pilot_[0-9]+.*0.2.2_2017.*.csv'
data = Reduce(rbind,Map(read.csv,list.files('data',file_pat,full.names=T)))

by_time = data %>%
  filter(code %in% c('stimulus','stream_1','stream_2')) %>%
  group_by(sid,trial) %>%
  do(trial_to_times(.,max_seconds=80))

by_context = by_time %>%
	filter(response > 0) %>%
	group_by(sid,time,stimulus,context) %>%
	summarise(response = mean(response-1),N = length(response))

legend = guide_legend(title='Context Stimulus')
ggplot(subset(by_context,sid == 3),
       aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')

by_context = by_time %>%
	filter(response > 0,sid %in% c(1,3)) %>%
	group_by(time,stimulus,context) %>%
	summarise(response = mean(response-1),N = length(response))

ggplot(by_context,
       aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')


#ggsave(paste('data/speech_streaming_joel_',Sys.Date(),'.pdf',sep=''))
