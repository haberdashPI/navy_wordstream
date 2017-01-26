library(tidyr)
library(ggplot2)
library(dplyr)
source('trial_to_times.R')

file_pat = 'pilot_[0-9]+.*0.3.0_2017.*.csv'
data = Reduce(rbind,Map(read.csv,list.files('data',file_pat,full.names=T)))

by_time = data %>%
  filter(code %in% c('stimulus','stream_1','stream_2')) %>%
  group_by(sid,trial) %>%
  do(trial_to_times(.,max_seconds=48))

by_context = by_time %>%
	filter(response > 0) %>%
	group_by(sid,time,stimulus,context) %>%
	summarise(response = mean(response-1),N = length(response))

for(num in unique(by_time$sid)){
  legend = guide_legend(title='Context Stimulus')
  ggplot(subset(by_context,sid == num),
         aes(x=time,y=response,color=context,group=context)) +
    geom_line() + facet_wrap(~stimulus) +
    geom_hline(yintercept=0.5,linetype=2) +
    theme_classic() + ylab('% streaming') + xlab('time (s)')
  ggsave(paste('plots/ind_',num,'_',Sys.Date(),'.pdf',sep=''))
}

means = by_context %>%
  group_by(time,stimulus,context) %>%
  summarise(response = mean(response))

ggplot(means,
       aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')
ggsave(paste('plots/means_',Sys.Date(),'.pdf',sep=''))

by_context1 = by_time %>%
	filter(response > 0,trial < 32) %>%
	group_by(sid,time,stimulus,context) %>%
	summarise(response = mean(response-1),N = length(response))
means1 = by_context1 %>%
  filter(sid %in% c(1,3)) %>%
  group_by(time,stimulus,context) %>%
  summarise(response = mean(response))
ggplot(means1,
       aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')
ggsave(paste('plots/means_1st_half_',Sys.Date(),'.pdf',sep=''))

by_context2 = by_time %>%
	filter(response > 0,trial >= 32) %>%
	group_by(sid,time,stimulus,context) %>%
	summarise(response = mean(response-1),N = length(response))
means2 = by_context2 %>%
  filter(sid %in% c(1,3)) %>%
  group_by(time,stimulus,context) %>%
  summarise(response = mean(response))
ggplot(means2,
       aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')
ggsave(paste('plots/means_2nd_half_',Sys.Date(),'.pdf',sep=''))

#ggsave(paste('data/speech_streaming_joel_',Sys.Date(),'.pdf',sep=''))
