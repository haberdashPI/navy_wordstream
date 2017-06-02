library(tidyr)
library(ggplot2)
library(dplyr)
source('trial_to_times.R')

file_pat = 'pilot_.+.*0.3.2_2017.*.csv'
data = Reduce(rbind,Map(read.csv,list.files('data',file_pat,full.names=T)))

by_time = data %>%
  filter(code %in% c('stimulus','stream_1','stream_2')) %>%
  group_by(sid,trial,presentation) %>%
  do(trial_to_times(.,max_seconds=50))

by_context = by_time %>%
	filter(response > 0) %>%
	group_by(sid,time,stimulus,context,presentation) %>%
	summarise(response = mean(response-1),N = length(response))

for(num in unique(by_time$sid)){
  legend = guide_legend(title='Context Stimulus')
  ggplot(subset(by_context,sid == num),
         aes(x=time,y=response,color=context,group=context)) +
    geom_line() + facet_wrap(presentation~stimulus) +
    geom_hline(yintercept=0.5,linetype=2) +
    theme_classic() + ylab('% streaming') + xlab('time (s)')
  ggsave(paste('plots/ind_',num,'_',Sys.Date(),'.pdf',sep=''))
}

means = by_context %>%
  group_by(time,stimulus,context,presentation) %>%
  summarise(response = mean(response))

ggplot(means,aes(x=time,y=response,color=context,group=context)) +
	geom_line() + facet_wrap(presentation~stimulus) +
  geom_hline(yintercept=0.5,linetype=2) +
	theme_classic() + ylab('% streaming') + xlab('time (s)')
ggsave(paste('plots/means_',Sys.Date(),'.pdf',sep=''))

by_switch = data %>%
  filter(trial >= 1,
         code %in% c('trial_start','stimulus','stream_1','stream_2')) %>%
  group_by(sid,trial,presentation) %>%
  filter(length(stimulus[code=='stimulus']) > 0) %>%
  mutate(stimulus=first(stimulus[code=='stimulus']),
         spacing=first(spacing[code=='stimulus'])) %>%
  filter(code != 'stimulus') %>%
  group_by(sid,presentation) %>%
  filter(code != lag(code) | trial != lag(trial)) %>%
  mutate(length = time - lag(time))

ggplot(subset(by_switch,spacing != 'negative'),
       aes(x=stimulus,y=as.numeric(code == 'stream_2'))) +
  stat_summary() +
  facet_wrap(sid~presentation) + theme_classic()
ggsave(paste("con_vs_int",Sys.Date(),".pdf",sep=''))

file_pat = 'pilot_.+.*0.3.1_2017.*.csv'
old_cont = Reduce(rbind,Map(read.csv,list.files('data',file_pat,full.names=T)))
old_cont$presentation = 'cont'

by_switch = old_cont %>%
  filter(trial >= 1,
         code %in% c('trial_start','stimulus','stream_1','stream_2')) %>%
  group_by(sid,trial) %>%
  filter(length(stimulus[code=='stimulus']) > 0) %>%
  mutate(stimulus=first(stimulus[code=='stimulus']),
         spacing=first(spacing[code=='stimulus'])) %>%
  filter(code != 'stimulus') %>%
  group_by(sid) %>%
  filter(code != lag(code) | trial != lag(trial)) %>%
  mutate(length = time - lag(time))

ggplot(by_switch,aes(x=stimulus,y=as.numeric(code == 'stream_2'))) +
  stat_summary() + ylab('% streaming') + scale_y_continuous()
  facet_wrap(sid~presentation) + theme_classic()
