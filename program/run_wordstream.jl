#!/usr/bin/env julia

using Weber
# NOTE: offset 9 skips all the practice trials

include("calibrate.jl")
include("stimtrak.jl")

version = v"0.4.2"
sid,trial_skip = @read_args("Runs a wordstream experiment, version $version.")
#sid,trial_skip = "test",0

exp = Experiment(
  moment_resolution = moment_resolution,
  skip=trial_skip,
  data_dir=joinpath("..","data","csv"),
  columns = [
    :condition => "pilot",
    :sid => sid,
    :version => version,
    :stimulus,:spacing,:phase
  ],
  extensions = [@DAQmx(stimtrak_port,codes=stimtrak_codes,eeg_sample_rate=512),
                @Cedrus()]
)

################################################################################
# settings

# terminology
#
# Each *trial* is divided into two phases: a context phase and a test phase
# Each *phase* is dividied up into one more presentations.
# Each *presentation* consists of three stimuli, and one response to those stimuli

# when the sid is the same, the randomization should be the same
randomize_by(sid)

SOA = 672.5ms
practice_spacing = 250ms
n_repeat_example = 20
response_spacing = 200ms
n_trials = 72 # needs to be a multiple of 8 (= n stimuli x n halves)
responses_per_phase = 9
stimuli_per_response = 3

normal_s_gap = 41ms
negative_s_gap = -41ms

if n_trials % 8 != 0
  error("n_trials must be a multiple of 8")
end

s_stone = sound("sounds/s_stone.wav")
dohne = sound("sounds/dohne.wav")
dome = sound("sounds/dome.wav")
drun = sound("sounds/drun.wav")
drum = sound("sounds/drum.wav")

# what is the dB difference between the s and the dohne?
rms(x) = sqrt(mean(x.^2))
dB_s = -20log10(rms(s_stone) / rms(dohne))

# generate a syllable with a given spacing between the "s" and the remainder of the syllable
function syllables(a,b,gap)
  x = mix(attenuate(a,atten_dB+dB_s),
          [silence(duration(a)+gap); attenuate(b,atten_dB)[:]])

  xs = silence(SOA*stimuli_per_response)
  for i in 1:stimuli_per_response
    at = (i-1)*SOA
    xs[at .. (at + duration(x))] = x
  end

  xs
end

stimuli = Dict(
  (:normal,   :w2nw) => syllables(s_stone,dohne,normal_s_gap),
  (:negative, :w2nw) => syllables(s_stone,dohne,negative_s_gap),
  (:normal,   :nw2w) => syllables(s_stone,dome,normal_s_gap),
  (:negative, :nw2w) => syllables(s_stone,dome,negative_s_gap),
  # REMEMBER: when we add these back in, we need to ensure a multiple of 16 above
  # FOR NOW: we've decided not to use these control conditions.
  # (:normal,   :w2w) => syllable(s_stone,drum,normal_s_gap),
  # (:negative, :w2w) => syllable(s_stone,drum,negative_s_gap),
  # (:normal,   :nw2nw) => syllable(s_stone,drun,normal_s_gap),
  # (:negative, :nw2nw) => syllable(s_stone,drun,negative_s_gap)
)

stimulus_description = Dict(
  :w2nw => """
In what follows you will be presented the sound "stone".

If you hear "stone" press "yellow". If you hear "dohne" press "orange".
""",
  :nw2w => """
In what follows you will be presented the sound "stome".

If you hear "stome" press "yellow". If you hear "dome" press "orange".
""",
  :w2w => """
In what follows you will be presented the sound "strum".

If you hear "strum" press "yellow". If you hear "drum" press "orange".
""",
  :nw2nw => """
In what follows you will be presented the sound "strun".

If you hear "strun" press "yellow". If you hear "drun" press "orange".
"""
)

# block all words in first, and then second half
order = [keys(stimuli) |> collect |> shuffle,
         keys(stimuli) |> collect |> shuffle]

isresponse(e) = iskeydown(e,stream_1) || iskeydown(e,stream_2)

################################################################################
# trial defintions

# in a practice trial, the listener is given a prompt if they're too slow
function practice_trial(spacing,stimulus,limit;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)

  waitlen = SOA*stimuli_per_response+limit
  min_wait = SOA*stimuli_per_response+practice_spacing

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  await = timeout(isresponse,waitlen,atleast=min_wait) do
    display(go_faster)
  end

  one_response = [resp,show_cross(),
                  moment(play,stimuli[spacing,stimulus]),
                  moment(record,"stimulus_"string(spacing)"_"string(stimulus);info...),
                  await]
  fill(one_response,responses_per_phase)
end

# in the real trials the presentations are continuous and do not wait for
# responses
function real_trial(spacing,stimulus;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)
  one_response = [resp,moment(play,stimuli[spacing,stimulus]),
                  moment(record,"stimulus_"string(spacing)"_"string(stimulus);
                         info...),
                  show_cross(),
                  moment(SOA*stimuli_per_response+response_spacing)]
  fill(one_response,responses_per_phase)
end

################################################################################
# expeirment setup
setup(exp) do
  addbreak(moment(record,"start"),
           moment(250ms,play,@> tone(1000,1) ramp attenuate(atten_dB)),
           moment(1))

  blank = moment(display,colorant"gray")

  addbreak(
    moment(display,"images/instruct_01.png"),
    await_response(iskeydown(end_break_key)),
    moment(display,"images/instruct_02.png"),
    await_response(iskeydown(end_break_key)))

  addpractice(blank,show_cross(),
              fill([moment(play,stimuli[:normal,:w2nw]),
                    moment(record,"stimulus",phase="example"),
                    moment(3SOA)],
                   round(Int,n_repeat_example/3)),
              moment(SOA))


  addbreak(
    moment(display,"images/instruct_03.png"),
    await_response(iskeydown(end_break_key)),
    moment(display,"images/instruct_04.png"),
    await_response(iskeydown(end_break_key)),
    moment(display,"images/instruct_05.png"),
    await_response(iskeydown(end_break_key)),
    moment(display,"images/instruct_06.png"),
    await_response(iskeydown(end_break_key)))

  addpractice(practice_trial(:normal,:w2nw,10response_spacing,phase="practice"))

  addbreak(moment(display,"Let's try a few more practice trials..."),
           await_response(iskeydown(end_break_key)))

  addpractice(practice_trial(:normal,:w2nw,2response_spacing,phase="practice"))

  anykey = moment(display,"Hit any key to start the real experiment...")
  addbreak(anykey,await_response(iskeydown))

  n_blocks = length(keys(stimuli))
  n_repeats = div(n_trials,2length(keys(stimuli)))
  n_breaks = 2*n_blocks - 1

  marker = moment(record,"experiment_start")
  for half in 1:2
    for block in 1:n_blocks
      context,word = order[half][block]
      n_break = (half-1)*n_blocks + block - 1
      if n_break > 0
        addbreak(
          instruct("You can a take break (break $n_break of $n_breaks).\n\n"*
                   stimulus_description[word],clean_whitespace=false))
      else
        addbreak(instruct(stimulus_description[word],clean_whitespace=false))
      end
      marker = moment(record,"block_start")

      for i in 1:n_repeats
        context_phase = real_trial(context,word,phase="context",
                                   spacing=context,stimulus=word)
        test_phase = real_trial(:normal,word,phase="test",
                                spacing=context,stimulus=word)

        addtrial(marker,context_phase,test_phase)
        marker = moment()
      end
    end
  end
end

run(exp)
