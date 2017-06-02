# these codes are used to start and stop recording in ActiveView
stop_record = 0xfd
start_record = 0xfc
manual_start_record = 0x29

# NOTE: we use powers of two for the codes so that we can identify codes that
# occur at the same time: e.g. 2^0 + 2^5 would indicate that the stream_1 button
# was pressed at the same time that a normal nw2w stimulus began to play.
stimtrak_codes = Dict(
  "trial_start" => start_record,
  "break_start" => stop_record,
  "paused" => stop_record,
  "unpaused" => start_record,
  "terminated" => stop_record,
  "UNUSED" => manual_start_record,
  "stream_1" => 2^0,
  "stream_2" => 2^1,
  "stream_1_up" => 2^0 + 2^2,
  "stream_2_up" => 2^1 + 2^2,
  "stimulus_normal_w2nw" => 2^4,
  "stimulus_normal_nw2w" => 2^5,
  "stimulus_negative_w2nw" => 2^4 + 2^6,
  "stimulus_negative_nw2w" => 2^5 + 2^6,
  "experiment_start" => 2^7,
  "block_start" =>  2^7
)
