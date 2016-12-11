# NOTES:

# concern that there is a delay in when you hear a stream switch and when you
# indicate that switch , sometimes occuring on the *next* stimulus. Might
# make relationship between EEG and beahvioral data difficult to interpret.

include("util.jl")
using Psychotask
using Lazy: @_, @>

# make sure that play is fully compiled
# play(silence(0.1))
play(tone(1000,1))

sid = (length(ARGS) > 0 ? ARGS[1] : "test_sid")
 
sr = 44100.0
s_sound = loadsound("sounds/s_stone.wav")
dohne_sound = loadsound("sounds/dohne.wav")
dome_sound = loadsound("sounds/dome.wav")
drun_sound = loadsound("sounds/drun.wav")
drum_sound = loadsound("sounds/drum.wav")

function withgap(a,b,gap)
  sound(attenuate(mix(a,[silence(duration(a)+gap); b]),20))
end

const ms = 1/1000

stimuli = Dict(
  (:normal,   :w2nw) => withgap(s_sound,dohne_sound,41ms),
  (:negative, :w2nw) => withgap(s_sound,dohne_sound,-100ms),
  (:normal,   :nw2w) => withgap(s_sound,dome_sound,41ms),
  (:negative, :nw2w) => withgap(s_sound,dome_sound,-100ms),
  (:normal,   :w2w) => withgap(s_sound,drum_sound,41ms),
  (:negative, :w2w) => withgap(s_sound,drum_sound,-100ms),
  (:normal,   :nw2nw) => withgap(s_sound,drun_sound,41ms),
  (:negative, :nw2nw) => withgap(s_sound,drun_sound,-100ms)  
)

cross = render_text("+")
break_text = render_text("You can take a break. Hit"*
                         " any key when you're ready to resume...")

# We might be able to change this to ISI now that there
# is no gap.
SOA = 672.5ms
response_timeout = 750ms
trial_pause = 100ms
n_trials = 80
n_break_after = 10
n_repeat_example = 2
stimuli_per_response = 4
responses_per_phase = 6

context_types = [:normal,:negative]
word_types = [:w2nw,:nw2w,:w2w,:nw2nw]

words,contexts = @> [(w,c) for w in word_types for c in context_types][:] begin
  cycle
  take(n_trials)
  collect
  shuffle
  unzip
end

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
  m = moment() do t
    clear()
    record("instructions",time=t)
    draw(str*"\n\n(Hit spacebar to continue...)")
    display()
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
  show_cross = moment(trial_pause) do t
    clear()
    draw(cross)
    display()
  end
  
  addbreak(
    instruct("""

      In each trial of the present experiment you will listen to the same
      syllable repeated over and over. Over time the sound of this sylable
      may (or may not) appear to change.""")...,
    instruct("""

      For example the word "stone" may begin to sound like an "s" that is
      separate from a second, "dohne" sound. See if you can hear the word
      "stone" change to the sound "dohne" in the following example.""")...)

  addtrial(blank,show_cross,
           repeated(syllable(:normal,:w2nw,"example"),n_repeat_example)...,
           moment(SOA))

  x = stimuli_per_response
  addbreak(
    instruct("""

      In this experiment we'll be asking you to listen for whether it appears
      that the begining "s" of a sound is a part of the following syllable or
      separate from it.""")...,
    instruct("""

      So, for example, if the syllable presented is "stone" we
      want to know if you hear "stone" or "dohne". There may be
      other changes to the sound that you hear; please ignore them.""")...,
    instruct("""

      After every $x sounds, we want you to indicate what you heard most
      often. Let's practice a bit.  Use "Q" to indicate that you heard the "s"
      as part of the sound most of the time, and "P" otherwise.  Respond as
      promptly as you can.""")...)

  stims = repeated(syllable(:normal,:w2nw,"practice"),stimuli_per_response)
  resp = response(e -> iskeydown(e,key"q") || iskeydown(e,key"p"))
  x = [blank,show_cross,stims...,resp]
  # addtrial(take(cycle(x),length(x)*responses_per_phase)...)

  addbreak(instruct("""

    In the real experiment, your time to respond will be limited. Try to respond
    before your time is up.
    """)...)

  anykey = response(e -> iskeydown(e) || endofpause(e))
  anykey_message = moment() do t
    clear()
    draw("Hit any key to start the real experiment...")
    display()
  end

  addbreak(anykey_message,anykey)

  for i in 1:n_trials
    context = syllable(contexts[i],words[i],"context")
    test = syllable(:normal,words[i],"test")
    # TODO: limit time for response?
    # TODO: I can create a higher level primitive
    # that makes this easier to use: e.g. "q" => "stream_1", "p" => "stream_2"
    go_faster = render_text("Faster!")
    isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")
    r = timeout(isresponse,response_timeout) do time
      record("response_timeout",time=time)
      clear()
      draw(go_faster)
      display()
    end

    x = [show_cross,repeated(context,stimuli_per_response)...,r]
    context_phase = take(cycle(x),length(x)*responses_per_phase)
    x = [show_cross,repeated(test,stimuli_per_response)...,r]
    test_phase = take(cycle(x),length(x)*responses_per_phase)

    addtrial(context_phase...,test_phase...) do event
      if iskeydown(event,key"q")
        record("stream_1",time = event.time)
      elseif iskeydown(event,key"p")
        record("stream_2",time = event.time)
      end
      
      if endofpause(event)
        clear()
        draw(cross)
        display()
      end
    end

    # add a break after every n_break_after trials
    if i > 0 && i % n_break_after == 0
      break_text = render_text("You can take a break. Hit"*
                               " any key when you're ready to resume..."*
                               "\n$(div(i,n_break_after)) of "*
                               "$(div(n_trials,n_break_after)) breaks.")
      message = moment() do t
        record("break")
        clear()
        draw(break_text)
        display()
      end

      addbreak(message,anykey)
    end

  end
end

run(exp)

# prediction: acoustic variations would prevent streaming...
