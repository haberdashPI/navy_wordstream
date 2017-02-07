#!/usr/bin/env julia

# NOTE: record mispressed keys

using Weber
include("calibrate.jl")
setup_sound(buffer_size=buffer_size)

version = v"0.3.2"
sid,trial_skip,presentation =
  @read_args("Runs a wordstream experiment, version $version.",
             presentation = [:cont,:int])

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
n_trials = 24
n_repeat_example = 20

if presentation == :int
  response_spacing = 200ms
  stimuli_per_presentation = 3
  presentations_per_phase = 9
elseif presentation == :cont
  stimuli_per_presentation = 36
  presentations_per_phase = 1
end

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

function withgap(a,b,gap)
  sound(mix(attenuate(a,atten_dB+dB_s),[silence(duration(a)+gap); attenuate(b,atten_dB)]))
end

stimuli = Dict(
  (:normal,   :w2nw) => withgap(s_stone,dohne,normal_s_gap),
  (:negative, :w2nw) => withgap(s_stone,dohne,negative_s_gap),
  (:normal,   :nw2w) => withgap(s_stone,dome,normal_s_gap),
  (:negative, :nw2w) => withgap(s_stone,dome,negative_s_gap),
  # (:normal,   :w2w) => withgap(s_stone,drum,normal_s_gap),
  # (:negative, :w2w) => withgap(s_stone,drum,negative_s_gap),
  # (:normal,   :nw2nw) => withgap(s_stone,drun,normal_s_gap),
  # (:negative, :nw2nw) => withgap(s_stone,drun,negative_s_gap)
)

stimulus_description = Dict(
  :w2nw => """
In what follows you will be presented the sound "stone".

When you hear "stone" press "Q". When you hear "dohne" press "P".
""",
  :nw2w => """
In what follows you will be presented the sound "stome".

When you hear "stome" press "Q". When you hear "dome" press "P".
""",
  :w2w => """
In what follows you will be presented the sound "strum".

When you hear "strum" press "Q". When you hear "drum" press "P".
""",
  :nw2nw => """
In what follows you will be presented the sound "strun".

When you hear "strun" press "Q". When you hear "drun" press "P".
"""
)

# block all words in first, and then second half
order = [keys(stimuli) |> collect |> shuffle,
         keys(stimuli) |> collect |> shuffle]

stream_1_key = key"q"
stream_2_key = key"p"
isresponse(e) = iskeydown(e,stream_1_key) || iskeydown(e,stream_2_key)

# presents a single syllable
function syllable(spacing,stimulus;info...)
  sound = stimuli[spacing,stimulus]

  [moment() do
    play(sound)
    record("stimulus",stimulus=stimulus,spacing=spacing;info...)
  end,moment(SOA)]
end

# in a practice phase, the listener is given a prompt if they're too slow
function practice_phase(spacing,stimulus,limit;info...)
  asyllable = syllable(spacing,stimulus;info...)
  resp = response(stream_1_key => "stream_1",stream_2_key => "stream_2";info...)

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  waitlen = SOA*stimuli_per_presentation+limit
  min_wait = SOA*stimuli_per_presentation+response_spacing
  await = timeout(isresponse,waitlen,atleast=min_wait) do
    record("response_timeout";info...)
    display(go_faster)
  end

  x = [moment(practice_spacing),resp,show_cross(),
       moment(repeated(asyllable,stimuli_per_presentation)),
       await]
  repeat(x,outer=presentations_per_phase)
end

# in the real trials the presentations are continuous and do not wait for
# responses
function real_phase(spacing,stimulus;info...)
  blank = moment(display,colorant"gray")
  resp = response(stream_1_key => "stream_1",stream_2_key => "stream_2";info...)
  asyllable = syllable(spacing,stimulus;info...)

  x = [resp,show_cross(),repeated(asyllable,stimuli_per_presentation),
       moment(response_spacing)]
  repeat(x,outer=presentations_per_phase)
end

exp = Experiment(condition = "pilot",sid = sid,version = version,
                 moment_resolution = moment_resolution,
                 skip=trial_skip,columns = [:stimulus,:spacing,:phase])

setup(exp) do
  addbreak(moment(record,"start"))

  blank = moment(display,colorant"gray")

  addbreak(
    instruct("""

      During this experiment you will listen to the same word
      or a non-word repeated over and over. Over time the sound of this word or
      non-word may (or may not) appear to change."""),
    instruct("""

      For example the word "stone" may begin to sound like an "s" that is
      separate from a second, "dohne" sound. See if you can hear the sound
      "stone" change to the sound "dohne" in the following example."""))

  addpractice(blank,show_cross(),
              repeated(syllable(:normal,:w2nw,phase="example"),
                       n_repeat_example))

  addbreak(
    instruct("""

      In this experiment we'll be asking you to listen for whether it appears
      that the begining "s" of a sound is a part of the following sound or
      separate from it."""),
    instruct("""

      So, for example, if the word presented is "stone" we
      want to know if you hear "stone" or "dohne". There may be
      other changes to the sound that you hear; please ignore them."""))

  addbreak(instruct("""

    As the sound plays we want you to indicate what you heard. Let's practice a
    bit. Hold down "Q" when you hear "stone". Hold down "P" when year hear
    "dohne".
  """))

  addpractice(real_phase(:normal,:w2nw,phase="practice",spacing=:normal))

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
        addbreak(instruct("You can take break (break $n_break of $n_breaks).\n"*
                          stimulus_description[word],clean_whitespace=false))
      else
        addbreak(instruct(stimulus_description[word],clean_whitespace=false))
      end

      for i in 1:n_repeats
        context_phase = real_phase(context,word,phase="context",spacing=context)
        test_phase = real_phase(:normal,word,phase="test",spacing=context)

        addtrial(context_phase,test_phase)
      end
    end
  end
end

play(attenuate(ramp(tone(1000,1)),atten_dB),wait=true)
run(exp)
