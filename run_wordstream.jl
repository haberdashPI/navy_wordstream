#!/usr/bin/env julia

# NOTES
#===============================================================================

What is up with 0002 and 0004? why aren't the negative sounds working?

0004 - did not understand the task, interpreted split as based on the number of
syllables

0002 - anna is not sure, thinks maybe negative were different words (but
guessing it was a confusiong aobut which were new and which were "old" words)

show a message for word transitions
shorter session? running 90 minutes right now, is rough for participants

go through several examples. How would we handle the negative examples?

maybe have some limit for how long we continue without any response?

===============================================================================#

# NOTES - from 0.2.2
# pitch changes??
# more chunks of the same sound
# maybe introduce to other VTs
# do we have people respond to the most recent stimulus rather than all 4?
# or does it split at all
# do we run as a block?
# allow restarting of experiment
# make shorter? or make sure 1st half has everything
# maybe block the stimuli?

# NOTES - from older
# concern that there is a delay in when you hear a stream switch and when you
# indicate that switch , sometimes occuring on the *next* stimulus. Might
# make relationship between EEG and beahvioral data difficult to interpret.

# NOTE: record mispressed keys

include("util.jl")
using Weber
using Lazy: @>
include("calibrate.jl")
setup_sound(buffer_size=buffer_size)

version = v"0.3.0"
sid,trial_skip = @read_args("Runs a wordstream experiment, version $version.")

const ms = 1/1000

# when the sid is the same, the randomization should be the same
randomize_by(sid)

# We might be able to change this to ISI now that there
# is no gap.
SOA = 672.5ms
practice_spacing = 150ms
response_spacing = 200ms
n_trials = 80 # n/2 needs to be a multiple of 8 (the number of stimuli)
n_break_after = 10
n_repeat_example = 20
stimuli_per_response = 3
responses_per_phase = 9
normal_s_gap = 41ms
negative_s_gap = -41ms

if n_trials % 16 != 0
  error("n_trials/2 must be a multiple of 8")
end

s_stone = load("sounds/s_stone.wav")
dohne = load("sounds/dohne.wav")
dome = load("sounds/dome.wav")
drun = load("sounds/drun.wav")
drum = load("sounds/drum.wav")

billig_s_stone = load("sounds/billig_s_stone.wav")
billig_dohne = load("sounds/billig_dohne.wav")
billig_dome = load("sounds/billig_dome.wav")
billig_s_stone = billig_s_stone[1:end-round(Int,44100*29ms)]

billig_normal_s_gap = 29ms
billig_negative_s_gap = -29ms

# what is the dB difference between the s and the dohne?
rms(x) = sqrt(mean(x.^2))
dB_s = -20log10(rms(s_stone) / rms(dohne))

function withgap(a,b,gap)
  sound(mix(attenuate(a,atten_dB+dB_s),[silence(duration(a)+gap); attenuate(b,atten_dB)]))
end

stimuli = Dict(
  (:normal,   :w2nw) => withgap(s_stone,dohne,normal_s_gap),
  (:negative, :w2nw) => withgap(s_stone,dohne,negative_s_gap),
  (:normal,   :nw2w) => withgap(s_stone,dome,normal_s_gap),
  (:negative, :nw2w) => withgap(s_stone,dome,negative_s_gap),
  (:normal,   :w2nw2) => withgap(billig_s_stone,billig_dohne,billig_normal_s_gap),
  (:negative, :w2nw2) => withgap(billig_s_stone,billig_dohne,billig_negative_s_gap),
  (:normal,   :nw2w2) => withgap(billig_s_stone,billig_dome,billig_normal_s_gap),
  (:negative, :nw2w2) => withgap(billig_s_stone,billig_dome,billig_negative_s_gap)
  # (:normal,   :w2w) => withgap(s_stone,drum,normal_s_gap),
  # (:negative, :w2w) => withgap(s_stone,drum,negative_s_gap),
  # (:normal,   :nw2nw) => withgap(s_stone,drun,normal_s_gap),
  # (:negative, :nw2nw) => withgap(s_stone,drun,negative_s_gap)
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
stimulus_description[:w2nw2] = stimulus_description[:w2nw]
stimulus_description[:nw2w2] = stimulus_description[:nw2w]

# block all words in first, and then second half
order = [keys(stimuli) |> collect |> shuffle,
         keys(stimuli) |> collect |> shuffle]

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

# presents a single syllable
function syllable(spacing,stimulus;info...)
  sound = stimuli[spacing,stimulus]

  [moment() do t
    play(sound)
    record("stimulus",stimulus=stimulus,spacing=spacing;info...)
  end,moment(SOA)]
end

# in a practice trial, the listener is given a prompt if they're too slow
function practice_trial(spacing,stimulus,limit;info...)
  asyllable = syllable(spacing,stimulus;info...)
  resp = response(key"q" => "stream_1",key"p" => "stream_2";info...)

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  waitlen = SOA*stimuli_per_response+limit
  min_wait = SOA*stimuli_per_response+response_spacing
  await = timeout(isresponse,waitlen,atleast=min_wait) do time
    record("response_timeout";info...)
    display(go_faster)
  end

  x = [moment(practice_spacing),resp,show_cross(),
       moment(repeated(asyllable,stimuli_per_response)),
       await]
  repeat(x,outer=responses_per_phase)
end

# in the real trials the presentations are continuous and do not wait for
# responses
function real_trial(spacing,stimulus;info...)
  clear = visual(colorant"gray")
  blank = moment(t -> display(clear))
  resp = response(key"q" => "stream_1",key"p" => "stream_2";info...)
  asyllable = syllable(spacing,stimulus;info...)

  x = [resp,show_cross(),
       moment(repeated(asyllable,stimuli_per_response)),
       moment(SOA*stimuli_per_response+response_spacing)]
  repeat(x,outer=responses_per_phase)
end

exp = Experiment(condition = "pilot",sid = sid,version = version,
                 moment_resolution = moment_resolution,
                 skip=trial_skip,columns = [:stimulus,:spacing,:phase])

setup(exp) do
  start = moment(t -> record("start"))

  clear = visual(colorant"gray")
  blank = moment(t -> display(clear))

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
              repeated(syllable(:normal,:w2nw,phase="example"),
                       n_repeat_example))

  x = stimuli_per_response
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

    In the real experiment, your time to respond will be even more limited. Try
    to respond before the next trial begins, but even if you don't please still
    respond.""") )

  str = visual("Hit any key to start the real experiment...")
  anykey = moment(t -> display(str))
  addbreak(anykey,await_response(iskeydown))

  n_blocks = length(keys(stimuli))
  n_repeats = div(n_trials,2length(keys(stimuli)))
  n_breaks = 2*n_blocks - 1
  for half in 1:2
    for block in 1:n_blocks
      context,word = order[half][block]
      n_break = (half-1)*n_blocks + block - 1
      if n_break > 0
        addbreak(instruct("You can take break (break $n_break of $n_breaks).\n"*
                          stimulus_description[word],clean_whitespace=false))
      else
        addbreak(instruct(stimulus_description[word],clean_whitespace=false))
      end

      for i in 1:n_repeats
        context_phase = real_trial(context,word,phase="context",spacing=context)
        test_phase = real_trial(:normal,word,phase="test",spacing=context)

        addtrial(context_phase,test_phase)
      end
    end
  end
end

play(attenuate(ramp(tone(1000,1)),atten_dB),wait=true)
run(exp)
