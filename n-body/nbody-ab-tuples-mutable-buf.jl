# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# Contributed by Adam Beckmeyer

# This is about 25% slower than nbody-ab-tuples-mutable.jl and
# nbody-ab-tuples.jl. I'm still looking into why.

import Printf: @printf

const DAYS_PER_YEAR = 365.24
const SOLAR_MASS = 4 * π * π

# Use a tuple rather than struct to hint compiler towards simd code
# 4 floats in tuple instead of 3 generates better SIMD instructions
const V3d = NTuple{4,Float64}
V3d(x=0.0, y=0.0, z=0.0) = (Float64(x), Float64(y), Float64(z), 0.0)

# Rust implementation #7 uses pos and v of length 3 with 1 filler
# Float64 field for a total struct width of 64 bytes instead of 72
# bytes as shown currently. This might be possible for Julia in the
# future using https://github.com/eschnett/SIMD.jl. Not sure if it
# would actually be advantageous though.
mutable struct Body
    pos::V3d
    v::V3d
    m::Float64
end#struct

# don't bother adding the empty 4th element
squarednorm(v::V3d) = @inbounds +(v[1] * v[1], v[2] * v[2], v[3] * v[3])

function init_sun(bodies)
    p = V3d()
    for b in bodies
        p = muladd.(b.v, b.m, p)
    end#for
    Body(V3d(), p .* (-inv(SOLAR_MASS)), SOLAR_MASS)
end#function

## Calculate "mag" and use it to update velocities on bodies b1 and b2
#Base.@propagate_inbounds function update_velocity!(b1, b2, Δt)
#    Δpos = b1.pos .- b2.pos
#    d² = sum(Δpos .* Δpos)
#    # Fastest implementations use an intrinsic to do a
#    # single-precision sqrt approximation followed by two iterations
#    # of the Newton-Raphson method. But the sqrt isn't currently this
#    # implementations bottleneck, so I've left it unoptimized.
#    d = √d²
#    # The fastest Rust/C implementations store this value instead of
#    # immediately modifying the body objects. Possible performance
#    # gains there due to cache-locality?
#    mag = Δt / (d² * d)
#    # Separating this into its own line and variable declaration
#    # rather than calculating it inline below generates faster code
#    # for some reason
#    mag1 = -b2.m * mag
#    mag2 = b1.m * mag
#    # Profiling shows that this muladd instruction is where the
#    # program spends the majority of its time. Exactly why is not
#    # clear to me.
#    b1.v = muladd.(mag1, Δpos, b1.v)
#    b2.v = muladd.(mag2, Δpos, b2.v)
#end#function

Base.@propagate_inbounds update_pos!(b, Δt) =
    b.pos = muladd.(Δt, b.v, b.pos)

positional_offset(bodies, ij::Tuple{Int,Int}) =
    @inbounds bodies[ij[1]].pos .- bodies[ij[2]].pos

function next!(bodies, Δt, bodies_iter, mi, mj)
    @inbounds begin
        Δpos = ntuple(i -> positional_offset(bodies, bodies_iter[i]), Val{10}())
        d² = squarednorm.(Δpos)
        mag = @. Δt / (d² * √d²)
        magi = @. -mj * mag
        magj = @. mi * mag
    end#@inbounds

    # Using special iteration tools like eachindex or Iterators.drop
    # is actually measurably slower than for loop around a UnitRange
    k = 1
    @inbounds for i in 1:length(bodies), j in i+1:length(bodies)
        bodies[i].v = muladd.(magi[k], Δpos[k], bodies[i].v)
        bodies[j].v = muladd.(magj[k], Δpos[k], bodies[j].v)
        k += 1
    end#for

    # Similarily, this could be broadcast or mapped, but doing so is
    # slower than a for loop
    @inbounds for i in 1:length(bodies)
        update_pos!(bodies[i], Δt)
    end#for
end#function

function energy(bodies)
    e = 0.0
    @inbounds for i in 1:length(bodies)
        bi = bodies[i]
        e += 0.5 * bi.m * sum(bi.v .* bi.v)
        for j in i+1:length(bodies)
            bj = bodies[j]
            Δpos = bi.pos .- bj.pos
            d = √sum(Δpos .* Δpos)
            e = muladd(bi.m * bj.m, -inv(d), e)
        end#for
    end#for
    e
end#function

function main(io, n, Δt)
    jupyter = Body(V3d(4.84143144246472090e+00,
                       -1.16032004402742839e+00,
                       -1.03622044471123109e-01),
                   V3d(1.66007664274403694e-03 * DAYS_PER_YEAR,
                       7.69901118419740425e-03 * DAYS_PER_YEAR,
                       -6.90460016972063023e-05 * DAYS_PER_YEAR),
                   9.54791938424326609e-04 * SOLAR_MASS)
    saturn = Body(V3d(8.34336671824457987e+00,
                      4.12479856412430479e+00,
                      -4.03523417114321381e-01),
                  V3d(-2.76742510726862411e-03 * DAYS_PER_YEAR,
                      4.99852801234917238e-03 * DAYS_PER_YEAR,
                      2.30417297573763929e-05 * DAYS_PER_YEAR),
                  2.85885980666130812e-04 * SOLAR_MASS)
    uranus = Body(V3d(1.28943695621391310e+01,
                      -1.51111514016986312e+01,
                      -2.23307578892655734e-01),
                  V3d(2.96460137564761618e-03 * DAYS_PER_YEAR,
                      2.37847173959480950e-03 * DAYS_PER_YEAR,
                      -2.96589568540237556e-05 * DAYS_PER_YEAR),
                  4.36624404335156298e-05 * SOLAR_MASS)
    neptune = Body(V3d(1.53796971148509165e+01,
                       -2.59193146099879641e+01,
                       1.79258772950371181e-01),
                   V3d(2.68067772490389322e-03 * DAYS_PER_YEAR,
                       1.62824170038242295e-03 * DAYS_PER_YEAR,
                       -9.51592254519715870e-05 * DAYS_PER_YEAR),
                   5.15138902046611451e-05 * SOLAR_MASS)
    # sun's initial velocity calculated based on position of other bodies
    sun = init_sun((jupyter, saturn, uranus, neptune))
    bodies = (sun, jupyter, saturn, uranus, neptune)

    mi, mj = let mi = Vector{Float64}(undef, 10),
        mj = Vector{Float64}(undef, 10)
        k = 1
        @inbounds for i in 1:length(bodies), j in i+1:length(bodies)
            mi[k] = bodies[i].m
            mj[k] = bodies[j].m
            k += 1
        end#for
        (mi...,), (mj...,)
    end#let
    bodies_iter = let buf = Vector{NTuple{2,Int}}()
        @inbounds for i in 1:length(bodies), j in i+1:length(bodies)
            push!(buf, (i, j))
        end#for
        (buf...,)
    end#let

    @printf(io, "%.9f\n", energy(bodies))
    for i in 1:n
        next!(bodies, Δt, bodies_iter, mi, mj)
    end#for
    @printf(io, "%.9f\n", energy(bodies))
end#function

isinteractive() || main(stdout, parse(Int, ARGS[1]), 0.01)
