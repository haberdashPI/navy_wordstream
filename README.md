# About

This is a work-in-progress experiment looking at
[auditory streaming](http://www.nature.com/nrn/journal/v14/n10/fig_tab/nrn3565_F3.html)
in word and non-word utterances, and the role recent acoustical context may (or
may not) play for these stimuli. The work builds on the findings in:

Billig, A. J., Davis, M. H., Deeks, J. M., Monstrey, J., & Carlyon,
R. P. (2013). Lexical Influences on Auditory Streaming. Current Biology, 23(16),
1585–1589. https://doi.org/10.1016/j.cub.2013.06.042

# Analysis

All analysese are located under anlaysis: it's pretty disorganized right now.

# Running the experiment

You need to install julia, and then run the setup.jl script.

One way to do this is as follows:

1. [Download](https://github.com/haberdashPI/navy_wordstream/archive/master.zip)
   and unzip this project.
2. Follow the directions to
   [install Juno](https://github.com/JunoLab/uber-juno/blob/master/setup.md)
3. Open the setup.jl file for this project in Juno.
4. Run setup.jl in Juno (e.g. Julia > Run File).

If you installed Juno (see above) just run `run_wordstream.jl` in Juno.  Make
sure you have the console open (Julia > Open Console), as you will be prompted
to enter a number of experimental parameters. Also note that important warnings
and information about the experiment will be written to the console.

Alternatively, if you have julia setup in your `PATH`, you can run the
experiment from a terminal by typing `julia run_wordstream.jl`. On mac (or unix)
this can be shortened to `./run_wordstream.jl`. You can get help about how to
use the console verison by typing `julia run_wordstream.jl -h`.

## Restarting the experiment

If the experiment gets interrupted, the program will report an offset
number. This number is also saved on each line of the data recorded during
the experiment. You can use this number to call `run_wordstream.jl` starting from
somewhere in the middle of the experiment.

