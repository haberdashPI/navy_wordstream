using WeberDAQmx

stop_record = 0xfd
start_record = 0xfc
manual_start_record = 0x29

stimtrak(port) = daq_extension(
  port,
  eeg_sample_rate = 512,
  codes = Dict(
    "trial_start" => start_record,
    "break_start" => stop_record,
    "paused" => stop_record,
    "unpaused" => start_record,
    "terminated" => stop_record,
    "UNUSED" => manual_start_record,
    "stream_1" => 1,
    "stream_2" => 2,
    "stream_1_up" => 3,
    "stream_2_up" => 4,
    "stimulus" => 16,
    "experiment_start" => 17,
    "block_start" => 18,
    "response_timeout" => 64
  )
)
