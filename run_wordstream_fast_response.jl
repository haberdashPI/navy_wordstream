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

n_trials = 80
n_break_after = 10
stimuli_per_phase = 25 # phase = context or test, so 50 stimuli per trial

context_types = [:normal,:negative]
word_types = [:w2nw,:nw2w,:w2w,:nw2nw]

words,contexts = @> zip(word_types,context_types) begin
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

function waiting_syllable(wait,spacing,stimulus,phase)
  sound = stimuli[spacing,stimulus]
  last_time = -1ms
  faster = render_text("Try to respond a little faster!")
  wait_trial_spacing = wait - duration(sound)

  response() do event
    if iskeydown(event,key"q") || iskeydown(event,key"p")
      record("stimulus",time=event.time,stimulus=stimulus,
             spacing=spacing,phase=phase)

      if last_time > 0ms && event.time-last_time > wait
        clear()
        draw(faster)
        display()
      else
        clear()
        draw(cross)
        display()
      end
      last_time = event.time

      sleep(wait_trial_spacing)
      play(sound)

      true
    else
      false
    end
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

# TODO: create higher level primitives from these lower level primitives
# e.g. continuous response, adpative 2AFC, and constant stimulus 2AFC tasks.

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style. Altenrative proposal, just use sleep
# and a loop to time events. None of this icky reactive stuff.
# Exceptions and errors would be easier to interpret, and the code
# easier to read. The issue would be handling responses well.

# TODO: generate errors for any sounds or image generated during
# a moment. Allow a 'dynamic' moment and response object that allows
# for this.

# TODO: only show the window when we call "run"

∨(fns...) = x -> any(fn -> fn(x),fns)

exp = Experiment(condition = "pilot",sid = sid,version = v"0.0.4") do
  addbreak(moment(t -> record("start",time=t,stimulus="none",
                              spacing="none",phase="none")))

  blank = moment() do t
    clear()
    display()
  end

  show_cross = moment(1.5) do t
    clear()
    draw(cross)
    display()
  end
  
  addbreak(
    instruct("""

      In each trial of the present experiment you will listen to the same
      syllable repeated over and over. Over time the sound of this sylable
      may appear to change.""")...,
    instruct("""

      For example the word "stone" may begin to sound like an "s" that is
      separate from a second, "dohne" sound. See if you can hear the word
      "stone" change to the sound "dohne" in the following example.""")...)

  addtrial(blank,show_cross,
           repeated(syllable(:normal,:w2nw,"example"),stimuli_per_phase)...,
           moment(SOA))

  addbreak(
    instruct("""

      In this experiment we'll be asking you to listen for whether it appears
      that the begining 's' of a sound is a part of the following syllable or
      separate from it.""")...,
    instruct("""

      So, for example, if the syllable presented is "stone" we
      want to know if you hear "stone" or "dohne". There may be
      other changes to the sound that you hear; please ignore them.""")...,
    instruct("""

      When you hear the "s" as part of the syllable, hit "Q".

      When you hear the "s" as separate from the syllable, hit "P".""")...,
    instruct("""

      We want you to respond to every sound. Let's practice a bit.
      In the following trials, indicate "part of" (Q) or "separate from" (P)
      for every sound. Respond as promptly as you can.""")...)
  addtrial(syllable(:normal,:w2nw,"example"),
           repeated(waiting_syllable(1500ms,:normal,:w2nw,"example"),
                    round(Int,stimuli_per_phase/2))...)

  addbreak(instruct("\n\nLet's try that a little bit faster.")...)
  addtrial(blank,show_cross,
           syllable(:normal,:w2nw,"example"),
           repeated(waiting_syllable(SOA,:normal,:w2nw,"example"),
                    round(Int,stimuli_per_phase/2))...)

  addbreak(instruct("""

    For the real experiment, trials will be presented at a fast, fixed pace.
    Try to keep up and respond to every stimulus.""")...)

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

    play_contexts = repeated(context,stimuli_per_phase)
    play_tests = collect(repeated(test,stimuli_per_phase))

    addtrial(blank,show_cross,play_contexts...,
             blank,show_cross,play_tests...) do event

      if iskeydown(event,key"q")
        record("stream_1",time = event.time)
      elseif iskeydown(event,key"p")
        record("stream_2",time = event.time)

      elseif iskeyup(event,key"q")
        record("stream_1_off",time = event.time)
      elseif iskeyup(event,key"p")
        record("stream_2_off",time = event.time)

      elseif endofpause(event)
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
