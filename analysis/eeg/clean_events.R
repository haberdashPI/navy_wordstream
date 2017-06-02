require(tidyr)
require(dplyr)
require(ggplot2)
source('../local_settings.R')

event_data_dir = file.path(data_dir,"events")
data = Reduce(rbind,Map(read.csv,
                        list.files(event_data_dir,
                                   pattern='.*_events.csv',full.name=T)))

## TODO: for just the first two people, figure out how to infer
## what stimuli were played

 stim_starts = data %>%
  filter(event == 'stimulus' & lead(event) == 'trial_start' &
         lead(time) - time +  < 0.2 )

latencies = data %>%
  mutate(latency = lead(time) - time) %>%
  filter(event =='stimulus' & lead(event) == 'trial_start')


buttons = filter(data,event %in% c("button1","button2"))
blocks = data %>%
  filter(!(event == "block_start" & lag(event) == "off" &
           lag(event,2) == "block_start")) %>%
  filter(event == 'block_start')

trials = rbind(stim_starts,buttons,blocks) %>%
  group_by(sid) %>%
  arrange(time) %>%
  mutate(trial = cumsum(event == 'stimulus'),
         block = cumsum(event == 'block_start'))

stream12 = trials %>%
  group_by(sid,block,trial) %>%
  filter(event %in% c('stimulus','button1','button2'),block < 9) %>%
  mutate(event = as.character(event)) %>%
  summarize(
    time = ifelse(all(event != 'stimulus'),first(time),
                  first(time[event == 'stimulus'])),
    response = last(event[event != 'stimulus'])) %>%
  mutate(isswitch = is.na(lag(response)) | response != lag(response),
         response = factor(response))

switches = trials %>%
  group_by(sid,block,trial) %>%
  filter(event %in% c('stimulus','button1','button2'),block > 9) %>%
  mutate(event = as.character(event)) %>%
  summarize(
    time = ifelse(all(event != 'stimulus'),first(time),
                  first(time[event == 'stimulus'])),
    response = last(event[event != 'stimulus'])) %>%
  mutate(response = factor(response))

ggplot(stream12,aes(y=sid,x=trial,color=response)) + geom_point()
ggplot(switches,aes(y=sid,x=trial,color=response)) + geom_point()

besa_events = stream12 %>%
  mutate(Tmu = as.integer(round(time*10**6)),
         TriNo = 100 + 10*ifelse(is.na(response),0,1+(response=='button2')) +
           1*ifelse(is.na(isswitch),0,isswitch),
         Code = 1) %>% data.frame()

eeglab_events = stream12 %>%
  mutate(Latency = time,
         Type = 100 + 10*ifelse(is.na(response),0,1+(response=='button2')) +
           1*ifelse(is.na(isswitch),0,isswitch)) %>% data.frame()

for(mysid in unique(besa_events$sid)){
  print(mysid)
  sdata = subset(besa_events,sid == mysid) %>% data.frame() %>%
    select(Tmu,Code,TriNo)
  write.table(sdata,
              paste(event_data_dir,"/",mysid,'_clean_events.evt',sep=''),
              row.names=F,sep='\t',quote=F)

  sdata = subset(eeglab_events,sid == mysid) %>% data.frame() %>%
    select(Latency,Type)
  write.table(sdata,
               paste(event_data_dir,"/",mysid,'_clean_events.txt',sep=''),
               row.names=F,sep='\t',quote=F)
}
