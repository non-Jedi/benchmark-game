# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# Contributed by Adam Beckmeyer

# This version is not as fast as nbody-ab-tuples.jl

module NBodyAB

import Printf: @printf
import Base: @propagate_inbounds

const DAYS_PER_YEAR = 365.24
const SOLAR_MASS = 4 * π * π

# Use a tuple rather than struct to hint compiler towards simd code
# 4 floats in tuple instead of 3 generates better SIMD instructions
const V3d = NTuple{4,Float64}
V3d(x=0.0, y=0.0, z=0.0) = (Float64(x), Float64(y), Float64(z), 0.0)

# don't bother adding the empty 4th element
Base.sum(v::V3d) = @inbounds +(v[1], v[2], v[3])

@propagate_inbounds function init_sun(m, v)
    p = V3d()
    for i in 1:length(m)
        p = muladd.(v[i], m[i], p)
    end#for
    p .* (-inv(SOLAR_MASS))
end#function

@propagate_inbounds function update_velocity(m1::Float64, m2::Float64,
                                             p1::V3d, p2::V3d, v1::V3d, v2::V3d,
                                             Δt::Float64)
    Δpos = p1 .- p2
    d² = sum(Δpos.^2)

    # Fastest implementations use an intrinsic to do a
    # single-precision sqrt approximation followed by two iterations
    # of the Newton-Raphson method. But the sqrt isn't currently this
    # implementations bottleneck, so I've left it unoptimized.

    # The fastest Rust/C implementations store this value instead of
    # immediately modifying the body objects. Possible performance
    # gains there due to cache-locality? I've been unable to replicate
    # this in Julia by calculating mag as an NTuple{10,Float64}.
    vmag = Δpos .* (Δt / (d² * √d²))

    muladd.(-m2, vmag, v1), muladd.(m1, vmag, v2)
end#function

@propagate_inbounds update_pos(m, pos, v, Δt) = muladd.(v, Δt, pos)

@propagate_inbounds function next!(m, pos, v, Δt)
    # Using special iteration tools like eachindex or Iterators.drop
    # is actually measurably slower than for loop around a UnitRange
    for i in 1:length(m)
    @simd for j in i+1:length(m)
        # Script spends roughly 90% of it's time in this loop. Of that
        # 90%, 36% is spent on float multiplication, 34% is spent on
        # the call to muladd, 12% is spent on vector manipulation and
        # iteration overhead, 11% is spent on division, 2% is spent on
        # sqrt, 2% is spent on summing. The remaining 3% is
        # unaccounted for. Overall, multiplication (including muladd)
        # dominates this benchmark.
        v[i], v[j] = update_velocity(m[i], m[j], pos[i], pos[j], v[i], v[j], Δt)
    end end#for

    # this could be broadcast or mapped, but for-loop is faster
    @simd for i in 1:length(m)
        pos[i] = update_pos(m[i], pos[i], v[i], Δt)
    end#for
end#function

@propagate_inbounds function energy(m, pos, v)
    e = 0.0
    for i in 1:length(m)
        e += 0.5 * m[i] * sum(v[i].^2)
        for j in i+1:length(m)
            Δpos = pos[i] .- pos[j]
            d = √sum(Δpos.^2)
            e = muladd(m[i] * m[j], -inv(d), e)
        end#for
    end#for
    e
end#function

function main(io, n, Δt)
    m = [9.54791938424326609e-04, # jupyter
         2.85885980666130812e-04, # saturn
         4.36624404335156298e-05, # uranus
         5.15138902046611451e-05, # neptune
         1.0] .* SOLAR_MASS       # sun
    pos = [V3d(4.84143144246472090e+00, -1.16032004402742839e+00, # jupyter
               -1.03622044471123109e-01),
           V3d(8.34336671824457987e+00, 4.12479856412430479e+00,  # saturn
               -4.03523417114321381e-01),
           V3d(1.28943695621391310e+01, -1.51111514016986312e+01, # uranus
               -2.23307578892655734e-01),
           V3d(1.53796971148509165e+01, -2.59193146099879641e+01, # neptune
               1.79258772950371181e-01),
           V3d()]                                                 # sun
    v = [V3d(1.66007664274403694e-03, 7.69901118419740425e-03,  # jupyter
             -6.90460016972063023e-05) .* DAYS_PER_YEAR,
         V3d(-2.76742510726862411e-03, 4.99852801234917238e-03, # saturn
             2.30417297573763929e-05) .* DAYS_PER_YEAR,
         V3d(2.96460137564761618e-03, 2.37847173959480950e-03,  # uranus
             -2.96589568540237556e-05) .* DAYS_PER_YEAR,
         V3d(2.68067772490389322e-03, 1.62824170038242295e-03,  # neptune
             -9.51592254519715870e-05) .* DAYS_PER_YEAR]
    push!(v, init_sun(m[1:end-1], v)) # init sun

    @printf(io, "%.9f\n", @inbounds(energy(m, pos, v)))
    @inbounds for i in 1:n
        next!(m, pos, v, Δt)
    end#for
    @printf(io, "%.9f\n", @inbounds(energy(m, pos, v)))
end#function

end#module

isinteractive() || NBodyAB.main(stdout, parse(Int, ARGS[1]), 0.01)
