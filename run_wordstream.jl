# NEW NOTES# pitch changes
# more chunks of the same sound
# maybe introduce to other VTs
# do we have people respond to the most recent stimulus rather than all 4
# or does it split at all
# do we run as a block
# allow restarting of expeirment
# make shorter? or make sure 1st half has everything

# NOTES:

# concern that there is a delay in when you hear a stream switch and when you
# indicate that switch , sometimes occuring on the *next* stimulus. Might
# make relationship between EEG and beahvioral data difficult to interpret.

include("util.jl")
using Psychotask
using Lazy: @>
const ms = 1/1000
atten_dB = 20
play(attenuate(ramp(tone(1000,1)),atten_dB))

# We might be able to change this to ISI now that there
# is no gap.
SOA = 672.5ms
response_timeout = 750ms
trial_pause = 100ms
n_trials = 40
n_break_after = 5
n_repeat_example = 2
stimuli_per_response = 6
responses_per_phase = 8
normal_s_gap = 41ms
negative_gap = -100ms

s_stone = loadsound("sounds/s_stone.wav")
dohne = loadsound("sounds/dohne.wav")
dome = loadsound("sounds/dome.wav")
drun = loadsound("sounds/drun.wav")
drum = loadsound("sounds/drum.wav")

# what is the dB difference between the s and sthe dohne?
rms(x) = sqrt(mean(x.^2))
dB_s = -20log10(rms(s_stone) / rms(dohne))

function withgap(a,b,gap)
  sound(mix(attenuate(a,atten_dB+dB_s),[silence(duration(a)+gap); attenuate(b,atten_dB)]))
end

# maybe block

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

sid = (length(ARGS) > 0 ? ARGS[1] : "test_sid")

function syllable(spacing,stimulus,phase)
  sound = stimuli[spacing,stimulus]

  moment(SOA) do t
    play(sound)
    record("stimulus",time=t,stimulus=stimulus,
           spacing=spacing,phase=phase)
  end
end

# TODO: maybe make this a standard construct in Psychotask.
function instruct(str)
  text = render(str*" (Hit spacebar to continue...)")
  m = moment() do t
    record("instructions",time=t)
    display(text)
  end
  [m,response(iskeydown(key":space:"))]
end

# TODO: move the windowing and event handling from SFML to SDL.  (while doing
# this, make sure the window doesn't initialize until run is called).

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style.

# TODO: allow trials to generate new trials, allowing for a variable number of
# trials. (figure out the interface for this)

# TODO: create higher level primitives from these lower level primitives
# e.g. continuous response, adpative 2AFC, and constant stimulus 2AFC tasks.

# TODO: generate errors for any sounds or image generated during
# a moment. Allow a 'dynamic' moment and response object that allows
# for this.

# TODO: only show the window when we call "run"

# TODO: rather than requiring users to record a pointless
# event, have the header specified in initialization.

exp = Experiment(condition = "pilot",sid = sid,version = v"0.0.5") do
  addbreak(moment(t -> record("start",time=t,stimulus="none",
                              spacing="none",phase="none")))

  blank = moment() do t
    clear()
    display()
  end

  # TODO: show cross could also be a simpler primitive e.g. cross(pause =
  # trial_pause)
  # TODO: trials should be able to flatten out nested lists, to simplify syntax
  cross = render("+")
  show_cross = moment(trial_pause,t -> display(cross))

  addbreak(
    instruct("""

      In each trial of the present experiment you will listen to the same word
      or a non-word repeated over and over. Over time the sound of this word or
      non-word may (or may not) appear to change."""),
    instruct("""

      For example the word "stone" may begin to sound like an "s" that is
      separate from a second, "dohne" sound. See if you can hear the sound
      "stone" change to the sound "dohne" in the following example."""))

  addtrial(blank,show_cross,
           repeated(syllable(:normal,:w2nw,"example"),n_repeat_example),
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

  # TODO: record responses
  isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")
  stims = repeated(syllable(:normal,:w2nw,"practice"),stimuli_per_response)
  resp = response(isresponse)
  x = [blank,show_cross,stims...,resp]
  addtrial(take(cycle(x),length(x)*responses_per_phase) )

  addbreak(instruct("""
  
    In the real experiment, your time to respond will be limited. Let's
    try another practice round, this time a little bit faster.
  """) )

  go_faster = render("Faster!")
  resp = timeout(isresponse,2response_timeout) do time
    record("response_timeout",time=time)
    display(go_faster)
  end
  x = [blank,show_cross,stims...,resp]
  addtrial(take(cycle(x),length(x)*responses_per_phase) )  
  
  addbreak(instruct("""

    In the real experiment, your time to respond will be even more limited. 
    Please try to respond before you see the "Faster!" flash, but even if
    it does flash, please still respond.
  """) )

  anykey = response(e -> iskeydown(e) || endofpause(e))
  anykeystr = render("Hit any key to start the real experiment...")
  anykey_message = moment() do t
    display(anykeystr)
  end

  addbreak(anykey_message,anykey)

  for i in 1:n_trials
    context = syllable(contexts[i],words[i],"context")
    test = syllable(:normal,words[i],"test")
    # TODO: limit time for response?
    # TODO: I can create a higher level primitive
    # that makes this easier to use: e.g. "q" => "stream_1", "p" => "stream_2"
    go_faster = render("Faster!")
    r = timeout(isresponse,response_timeout) do time
      record("response_timeout",time=time)
      display(go_faster)
    end

    x = [show_cross,repeated(context,stimuli_per_response)...,r]
    context_phase = take(cycle(x),length(x)*responses_per_phase)
    x = [show_cross,repeated(test,stimuli_per_response)...,r]
    test_phase = take(cycle(x),length(x)*responses_per_phase)

    addtrial(context_phase,test_phase) do event
      if iskeydown(event,key"q")
        record("stream_1",time = time(event))
      elseif iskeydown(event,key"p")
        record("stream_2",time = time(event))
      end
      
      if endofpause(event)
        display(cross)
      end
    end

    anykeybut = response(e -> (iskeydown(e) || endofpause(e)) &&
                         !(iskeydown(e,key"p") || iskeydown(e,key"q")))
    # add a break after every n_break_after trials
    if i > 0 && i % n_break_after == 0
      break_text = render("You can take a break. Hit"*
                               " any key when you're ready to resume..."*
                               "\n$(div(i,n_break_after)) of "*
                               "$(div(n_trials,n_break_after)) breaks.")
      message = moment() do t
        record("break")
        display(break_text)
      end

      addbreak(message,anykeybut)
    end

  end
end

run(exp)

# prediction: acoustic variations would prevent streaming...
