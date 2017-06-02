Pkg.add("Weber",v"0.5.1")
if !isfile("calibrate.jl")
  open("calibrate.jl","w") do s
    print(s,"""
    # call run_calibrate() to select an appropriate attenuation.
    const atten_dB = 30

    # call Pkg.test(\"Weber\"). If the timing test fails, increase
    # moment resolution to avoid warnings.
    const moment_resolution = 1.5ms

    const stream_1 = key":cedrus5:"
    const stream_2 = key":cedrus6:"
    const end_break_key = key"`"

    # select an appropriate serial port for stimtrak
    const stimtrak_port = nothing
    """)
  end
end
