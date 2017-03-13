#!/usr/bin/env julia

# NOTE: record mispressed keys

using Weber
using Lazy

include("calibrate.jl")

version = v"0.3.3"
sid,trial_skip = @read_args("Runs a wordstream experiment, version $version.")
#sid,trial_skip = "test",0

const ms = 1/1000

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
n_trials = 48 # n/2 needs to be a multiple of 8 (the number of stimuli)
n_break_after = 10
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
    xs[at:(at+length(x)-1)] = x
  end

  xs
end

stimuli = Dict(
  (:normal,   :w2nw) => syllables(s_stone,dohne,normal_s_gap),
  (:negative, :w2nw) => syllables(s_stone,dohne,negative_s_gap),
  (:normal,   :nw2w) => syllables(s_stone,dome,normal_s_gap),
  (:negative, :nw2w) => syllables(s_stone,dome,negative_s_gap),
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

stream_1 = key"q"
stream_2 = key"p"
isresponse(e) = iskeydown(e,stream_2) || iskeydown(e,stream_1)

# in a practice trial, the listener is given a prompt if they're too slow
function practice_trial(spacing,stimulus,limit;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  waitlen = SOA*stimuli_per_response+limit
  min_wait = SOA*stimuli_per_response+response_spacing
  await = timeout(isresponse,waitlen,atleast=min_wait) do
    record("response_timeout";info...)
    display(go_faster)
  end

  x = [resp,
       moment(practice_spacing,play,stimuli[spacing,stimulus]),
       moment(record,"stimulus";info...),
       show_cross(),await]
  repeat(x,outer=responses_per_phase)
end

# in the real trials the presentations are continuous and do not wait for
# responses
function real_trial(spacing,stimulus,first_trial;info...)
  resp = response(stream_1 => "stream_1",stream_2 => "stream_2";info...)
  trial_soa = first_trial ? SOA*stimuli_per_response+response_spacing : SOA
  x = [moment(trial_soa,play,stimuli[spacing,stimulus]),resp,
       moment(record,"stimulus";info...),show_cross()]
  repeat(x,outer=responses_per_phase)
end

exp = Experiment(
  moment_resolution = moment_resolution,
  skip=trial_skip,
  columns = [
    :condition => "pilot",
    :sid => sid,
    :version => version,
    :stimulus,:spacing,:phase
  ]
)

setup(exp) do
  addbreak(moment(record,"start"),
           moment(250ms,play,@> tone(1000,1) ramp attenuate(atten_dB)),
           moment(1))

  blank = moment(display,colorant"gray")

  addbreak(
    instruct("""

      In each trial of the present experiment you will listen to the same word
      or a non-word repeated over and over. Over time the sound of this word or
      non-word may (or may not) appear to change."""),
    instruct("""

      For example the word "stone" may begin to sound like an "s" that is
      separate from a second, "dohne" sound. See if you can hear the sound
      "stone" change to the sound "dohne" in the following example."""))

  addpractice(blank,show_cross(),
              repeated([moment(SOA,play,stimuli[:normal,:w2nw]),
                        moment(record,"stimulus",phase="example"),
                        moment(2SOA)],
                       round(Int,n_repeat_example/3)),
              moment(SOA))

  addbreak(
    instruct("""

      In this experiment we'll be asking you to listen for whether it appears
      that the begining "s" of a sound is a part of the following sound or
      separate from it."""),
    instruct("""

      So, for example, if the word presented is "stone" we
      want to know if you hear "stone" or "dohne". There may be
      other changes to the sound that you hear; please ignore them."""),
    instruct("""

      After several sounds, we want you to indicate what you heard. Let's
      practice a bit.  Use "Q" to indicate that you heard the "s" as part of the
      sound all of the time and "P" if you heard the "s" as separate at any
      point. Respond as promptly as you can."""))

  addpractice(practice_trial(:normal,:w2nw,10response_spacing,phase="practice"))

  addbreak(instruct("""

    In the real experiment, your time to respond will be limited. Let's
    try another practice round, this time a little bit faster.
  """) )

  addpractice(practice_trial(:normal,:w2nw,2response_spacing,phase="practice"))

  addbreak(instruct("""

    During the real expeirment, try to respond before the next trial begins, but
    even if you don't please still respond."""))

  anykey = moment(display,"Hit any key to start the real experiment...")
  addbreak(anykey,await_response(iskeydown))

  n_blocks = length(keys(stimuli))
  n_repeats = div(n_trials,2length(keys(stimuli)))
  n_breaks = 2*n_blocks - 1
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

      for i in 1:n_repeats
        context_phase = real_trial(context,word,i==1,phase="context",spacing=context)
        test_phase = real_trial(:normal,word,i==1,phase="test",spacing=context)

        addtrial(context_phase,test_phase)
      end
    end
  end
end

run(exp)
