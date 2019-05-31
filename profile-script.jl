using Profile

Profile.init(n=10^8, delay=0.001)

@profile include(joinpath(pwd(), ARGS[2]))

open(joinpath(pwd(), ARGS[2] * "-profile.txt"); write=true) do f
    Profile.print(IOContext(f, :displaysize => (24, 600)))
end#open
