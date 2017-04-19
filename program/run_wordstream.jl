#!/usr/bin/env julia

# NOTE: record mispressed keys

using Weber
using Lazy

include("calibrate.jl")
include("stimtrak.jl")

version = v"0.4.1"
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
  ]
)

const ms = 1/1000

################################################################################
# settings

# terminology
#
# Each *trial* is divided into two phases: a context phase and a test phase
# Each *phase* is dividied up into one more presentations.
# Each *presentation* consists of a series of stimuli, and one or more
# responses to those stimuli.

# when the sid is the same, the randomization should be the same
randomize_by(sid)

SOA = 672.5ms
practice_spacing = 250ms
response_spacing = 200ms
n_trials = 72 # needs to be a multiple of 8 (= n stimuli x n halves)
n_repeat_example = 20
stimuli_per_response = 3
responses_per_phase = 9

normal_s_gap = 41ms
negative_s_gap = -41ms

if n_trials % 8 != 0
  error("n_trials must be a multiple of 8")
end

s_stone = load("sounds/s_stone.wav")
dohne = load("sounds/dohne.wav")
dome = load("sounds/dome.wav")
drun = load("sounds/drun.wav")
drum = load("sounds/drum.wav")

# what is the dB difference between the s and the dohne?
rms(x) = sqrt(mean(x.^2))
dB_s = -20log10(rms(s_stone) / rms(dohne))

function syllables(a,b,gap)
  x = mix(attenuate(a,atten_dB+dB_s),
          [silence(duration(a)+gap); attenuate(b,atten_dB)])

  xs = silence(SOA*stimuli_per_response)
  for i in 1:stimuli_per_response
    at = round(Int,(i-1)*SOA*samplerate(x))+1
    xs[at:(at+size(x,1)-1)] = x
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

If you hear "stone" press "Q". If you hear "dohne" press "P".
""",
  :nw2w => """
In what follows you will be presented the sound "stome".

If you hear "stome" press "Q". If you hear "dome" press "P".
""",
  :w2w => """
In what follows you will be presented the sound "strum".

If you hear "strum" press "Q". If you hear "drum" press "P".
""",
  :nw2nw => """
In what follows you will be presented the sound "strun".

If you hear "strun" press "Q". If you hear "drun" press "P".
"""
)

# block all words in first, and then second half
order = [keys(stimuli) |> collect |> shuffle,
         keys(stimuli) |> collect |> shuffle]

isresponse(e) = iskeydown(e,stream_2) || iskeydown(e,stream_1)

################################################################################
# trial defintions

# in a practice trial, the listener is given a prompt if they're too slow
function practice_trial(spacing,stimulus,limit;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  waitlen = SOA*stimuli_per_response+limit
  min_wait = SOA*stimuli_per_response
  await = timeout(isresponse,waitlen,atleast=min_wait) do
    record("response_timeout";info...)
    display(go_faster)
  end

  x = [resp,show_cross(),
       moment(play,stimuli[spacing,stimulus]),
       moment(record,"stimulus";info...),
       await,moment(practice_spacing)]
  repeat(x,outer=responses_per_phase)
end

# in the real trials the presentations are continuous and do not wait for
# responses
function real_trial(spacing,stimulus;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)
  x = [resp,moment(play,stimuli[spacing,stimulus]),
       moment(record,"stimulus";info...),show_cross(),
       moment(SOA*stimuli_per_response+response_spacing)]
  repeat(x,outer=responses_per_phase)
end

################################################################################
# expeirment setup
setup(exp) do
  addbreak(moment(record,"start"),
           moment(250ms,play,@> tone(1000,1) ramp attenuate(atten_dB)),
           moment(1))

  blank = moment(display,colorant"gray")

  addbreak(
    moment(display,load("images/instruct_01.png")),
    await_response(iskeydown(end_break_key)),
    moment(display,load("images/instruct_02.png")),
    await_response(iskeydown(end_break_key)))

  addpractice(blank,show_cross(),
              repeated([moment(play,stimuli[:normal,:w2nw]),
                        moment(record,"stimulus",phase="example"),
                        moment(3SOA)],
                       round(Int,n_repeat_example/3)),
              moment(SOA))


  addbreak(
    moment(display,load("images/instruct_03.png")),
    await_response(iskeydown(end_break_key)),
    moment(display,load("images/instruct_04.png")),
    await_response(iskeydown(end_break_key)),
    moment(display,load("images/instruct_05.png")),
    await_response(iskeydown(end_break_key)),
    moment(display,load("images/instruct_06.png")),
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
