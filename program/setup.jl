Pkg.add("Weber",v"0.4.2")
if !isfile("calibrate.jl")
  open("calibrate.jl","w") do s
    println(s,"# call run_calibrate() to select an appropriate attenuation.")
    println(s,"const atten_dB = 30")
    println(s,"")
    println(s,"# call Pkg.test(\"Weber\"). If the timing test fails, increase ")
    println(s,"# moment resolution to avoid warnings.")
    println(s,"const moment_resolution = 0.0015")
  end
end
