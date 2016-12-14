# Installation

1. [Download](https://github.com/haberdashPI/navy_wordstream/archive/master.zip)
   and unzip this project.
2. Install the 64-bit version of [julia](http://julialang.org/downloads/)
3. Run setup.jl

This last step is accomplished by entering the following commands in a terminal.

```console
$ cd "[download-location]"
$ julia setup.jl
```

Replace `[download-location]` with the directory where you unziped this project.

# Running

To run the experiment just call julia from the terminal as follows:

```console
$ cd "[download-location]"
$ julia run_wordstream.jl [sid]
```

Replace `[sid]` with a subject id number. Results will be saved in a `data` subdirectory.

## Restarting the experiment

If the experiment gets interrupted, the program will report an offset
number. You can use this number as a second argument to run_wordstream.jl, and
the experiment will start at the beginning of the trial it was interrupted
on.

In the below example, the experiment was terminated for participant 1234 at
offset 20, and the experiment is then resumed with the second command.

```console
$ julia run_wordstream.jl 1234
INFO: Experiment terminated at offset 20.
$ julia run_wordstream.jl 1234 20
```

