#!/usr/bin/env julia

# NEW NOTES
# pitch changes??
# more chunks of the same sound
# maybe introduce to other VTs
# do we have people respond to the most recent stimulus rather than all 4?
# or does it split at all
# do we run as a block?
# allow restarting of experiment
# make shorter? or make sure 1st half has everything
# maybe block the stimuli?

# NOTES:

# concern that there is a delay in when you hear a stream switch and when you
# indicate that switch , sometimes occuring on the *next* stimulus. Might
# make relationship between EEG and beahvioral data difficult to interpret.

include("util.jl")
using Psychotask
using Lazy: @>

sid,trial_skip = @read_args("Run a wordstream experiment")

const ms = 1/1000
atten_dB = 20

# when the sid is the same, the randomization should be the same
srand(reinterpret(UInt32,collect(sid)))

# We might be able to change this to ISI now that there
# is no gap.
SOA = 672.5ms
response_timeout = 750ms
n_trials = 40
n_break_after = 5
n_repeat_example = 20
stimuli_per_response = 3
responses_per_phase = 16
normal_s_gap = 41ms
negative_gap = -100ms

s_stone = loadsound("sounds/s_stone.wav")
dohne = loadsound("sounds/dohne.wav")
dome = loadsound("sounds/dome.wav")
drun = loadsound("sounds/drun.wav")
drum = loadsound("sounds/drum.wav")

# what is the dB difference between the s and the dohne?
rms(x) = sqrt(mean(x.^2))
dB_s = -20log10(rms(s_stone) / rms(dohne))

function withgap(a,b,gap)
  sound(mix(attenuate(a,atten_dB+dB_s),[silence(duration(a)+gap); attenuate(b,atten_dB)]))
end

stimuli = Dict(
  (:normal,   :w2nw) => withgap(s_stone,dohne,normal_s_gap),
  (:negative, :w2nw) => withgap(s_stone,dohne,negative_gap),
  (:normal,   :nw2w) => withgap(s_stone,dome,normal_s_gap),
  (:negative, :nw2w) => withgap(s_stone,dome,negative_gap),
  (:normal,   :w2w) => withgap(s_stone,drum,normal_s_gap),
  (:negative, :w2w) => withgap(s_stone,drum,negative_gap),
  (:normal,   :nw2nw) => withgap(s_stone,drun,normal_s_gap),
  (:negative, :nw2nw) => withgap(s_stone,drun,negative_gap)
)

response_pause = SOA - duration(stimuli[:normal,:w2nw])

# randomize presentations, but gaurantee that all stimuli
# are presented in equal quantity within the first and second half
# of trials
contexts1,words1 = @> keys(stimuli) begin
  cycle
  take(div(n_trials,2))
  collect
  shuffle
  unzip
end

contexts2,words2 = @> keys(stimuli) begin
  cycle
  take(n_trials - div(n_trials,2))
  collect
  shuffle
  unzip
end

contexts = [contexts1; contexts2]
words = [words1; words2]

function syllable(spacing,stimulus;info...)
  sound = stimuli[spacing,stimulus]

  moment(SOA) do t
    play(sound)
    record("stimulus",time=t,stimulus=stimulus,spacing=spacing;info...)
  end
end

function create_trial(spacing,stimulus;timeout=response_timeout,info...)
  asyllable = syllable(spacing,stimulus;info...)
  go_faster = render("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  await = Psychotask.timeout(isresponse,timeout) do time
    record("response_timeout",time=time;info...)
    display(go_faster)
  end
  
  x = [show_cross(response_pause),repeated(asyllable,stimuli_per_response),await]
  take(cycle(x),length(x)*responses_per_phase)
end

# this could be a standard primitive for Trial.jl
isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

# TODO: allow trials to generate new trials, allowing for a variable number of
# trials. (figure out the interface for this)

# TODO: fix bug so there is no flash

# TODO: change the API for moment to be a macro, so the rendered objects can be
# precomputed, without having to explicitly do so. (This could lead to confusing
# undefined variable errors if the rendered object depends on variables
# within the scope of the function.)

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style.

# TODO: create a 2AFC adaptive abstraction

# TODO: generate errors for any sounds or image generated during
# a moment. Create a 'dynamic' moment and response object that allows
# for this.

function setup()
  start = moment(t -> record("start",time=t))

  clear = render(colorant"gray")
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

  addpractice(blank,show_cross(response_pause),
              repeated(syllable(:normal,:w2nw,phase="example"),n_repeat_example),
              moment(SOA))

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

      After every $x sounds, we want you to indicate what you heard most
      often. Let's practice a bit.  Use "Q" to indicate that you heard the "s"
      as part of the sound most of the time, and "P" otherwise.  Respond as
      promptly as you can.""") )

  practice_trial = create_trial(:normal,:w2nw,phase="practice",
                                timeout=10response_timeout)
  r = response(key"q" => "stream_1",key"p" => "stream_2",phase="practice")
  addpractice(r,practice_trial)

  addbreak(instruct("""
  
    In the real experiment, your time to respond will be limited. Let's
    try another practice round, this time a little bit faster.
  """) )

  practice_trial = create_trial(:normal,:w2nw,phase="practice",
                                timeout=2response_timeout)
  r = response(key"q" => "stream_1",key"p" => "stream_2",phase="practice")  
  addpractice(r,practice_trial)
  
  addbreak(instruct("""

    In the real experiment, your time to respond will be even more limited. 
    Please try to respond before you see the "Faster!" flash, but even if
    it does flash, please still respond.
  """) )

  str = render("Hit any key to start the real experiment...")
  anykey = moment(t -> display(str))
  addbreak(anykey,await_response(iskeydown))
  
  for trial in 1:n_trials
    context_phase =
      create_trial(contexts[trial],words[trial],phase="context")
    record_context =
      response(key"q" => "stream_1",key"p" => "stream_2",phase="context")
    
    test_phase = create_trial(:normal,words[trial],phase="test")
    record_test =
      response(key"q" => "stream_1",key"p" => "stream_2",phase="test")

    addtrial(record_context,context_phase,record_test,test_phase)
  end
end

exp = Experiment(setup,condition = "pilot",sid = sid,version = v"0.1.0",
                 skip=trial_skip,
                 columns = [:time,:stimulus,:spacing,:phase])
play(attenuate(ramp(tone(1000,1)),atten_dB))
run(exp)

# prediction: acoustic variations would prevent streaming...
