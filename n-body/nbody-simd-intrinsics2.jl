# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

# contributed by Jarret Revels and Alex Arslan
# based on the Java version

module NBody

using Printf

const F32 = Float32
const F64 = Float64

const VE = VecElement
const __m128 = NTuple{4,VE{F32}}

rsqrt(a::__m128) =
    ccall("llvm.x86.sse.rsqrt.ps", llvmcall, __m128, (__m128,), a)

Base.@propagate_inbounds pack(v::Vector{F64}, i::Int) =
    (VE(F32(v[i])), VE(F32(v[i+1])), VE(F32(v[i+2])), VE(F32(v[i+3])))

Base.@propagate_inbounds function unpack!(v::Vector{<:AbstractFloat}, nt::__m128,
                                          i::Int)
    for ind = 1:4
        v[ind+i-1] = nt[ind].value
    end#for
end#function

# Constants
const solar_mass = 4 * pi * pi
const days_per_year = 365.24

# A heavenly body in the system
mutable struct Body
    x::F64
    y::F64
    z::F64
    vx::F64
    vy::F64
    vz::F64
    mass::F64
end

const V64 = Vector{F64}
const V32 = Vector{Float32}

struct Buffers
    Δx::V64
    Δy::V64
    Δz::V64
    dsq::V64
    rd::V64
end#struct

const buffer_fields = fieldnames(Buffers)

Buffers(n::Integer) = Buffers((V64(undef, n) for _ in buffer_fields)...)

# Update Buffers field contents from vector of bodies
function reset!(buf::Buffers, bodies::Vector{Body})
    l = length(bodies)
    k = 1
    @inbounds for i=1:l
        for j=i+1:l
            buf.Δx[k] = bodies[i].x - bodies[j].x
            buf.Δy[k] = bodies[i].y - bodies[j].y
            buf.Δz[k] = bodies[i].z - bodies[j].z
            k += 1
        end#for
    end#for
end#function

function offset_momentum(b::Body, px, py, pz)
    b.vx = -px / solar_mass
    b.vy = -py / solar_mass
    b.vz = -pz / solar_mass
end

function init_sun(bodies)
    local px::F64 = 0.0
    local py::F64 = 0.0
    local pz::F64 = 0.0
    for b in bodies
        px += b.vx * b.mass
        py += b.vy * b.mass
        pz += b.vz * b.mass
    end
    offset_momentum(bodies[1], px, py, pz)
end

function advance!(bodies, dt, bufs)
    l = length(bodies)
    numpairs = l * (l - 1) ÷ 2
    numvecs = round(Int, numpairs / 4, RoundUp)

    reset!(bufs, bodies)

    @inbounds begin
        @. bufs.dsq = bufs.Δx^2 + bufs.Δy^2 + bufs.Δz^2

        resize!(bufs.dsq, 4numvecs)
        resize!(bufs.rd, 4numvecs)
        i = 1
        while i < 4numvecs
            v = pack(bufs.dsq, i)
            v = rsqrt(v)
            unpack!(bufs.rd, v, i)
            i += 4
        end#while
        resize!(bufs.dsq, numpairs)
        resize!(bufs.rd, numpairs)

        # 2 iterations of Newton-Raphson method
        for i=1:2
            @. bufs.rd = 1.5*bufs.rd - 0.5*bufs.dsq*bufs.rd*(bufs.rd*bufs.rd)
        end#for

        mag = bufs.rd
        @. mag = dt * bufs.rd / bufs.dsq

        bufs.Δx .= bufs.Δx .* mag
        bufs.Δy .= bufs.Δy .* mag
        bufs.Δz .= bufs.Δz .* mag

        k = 1
        for i = 1:l
            for j = i+1:l
                bodies[i].vx -= bufs.Δx[k] * bodies[j].mass
                bodies[i].vy -= bufs.Δy[k] * bodies[j].mass
                bodies[i].vz -= bufs.Δz[k] * bodies[j].mass

                bodies[j].vx += bufs.Δx[k] * bodies[i].mass
                bodies[j].vy += bufs.Δy[k] * bodies[i].mass
                bodies[j].vz += bufs.Δz[k] * bodies[i].mass

                k += 1
            end#for
        end#for
    end#@inbounds

    for b in bodies
        b.x += dt * b.vx
        b.y += dt * b.vy
        b.z += dt * b.vz
    end
end

function energy(bodies)
    local e::F64 = 0.0
    for i = 1:length(bodies)
        e += 0.5 * bodies[i].mass *
             (bodies[i].vx^2 + bodies[i].vy^2 + bodies[i].vz^2)
        for j = i+1:length(bodies)
            dx = bodies[i].x - bodies[j].x
            dy = bodies[i].y - bodies[j].y
            dz = bodies[i].z - bodies[j].z
            distance = sqrt(dx^2 + dy^2 + dz^2)
            e -= (bodies[i].mass * bodies[j].mass) / distance
        end
    end
    e
end


function perf_nbody(N::Int=1000)
    jupiter = Body( 4.84143144246472090e+00,                  # x
                   -1.16032004402742839e+00,                  # y
                   -1.03622044471123109e-01,                  # z
                   1.66007664274403694e-03 * days_per_year,   # vx
                   7.69901118419740425e-03 * days_per_year,   # vy
                   -6.90460016972063023e-05 * days_per_year,  # vz
                   9.54791938424326609e-04 * solar_mass)      # mass

    saturn = Body( 8.34336671824457987e+00,
                  4.12479856412430479e+00,
                  -4.03523417114321381e-01,
                  -2.76742510726862411e-03 * days_per_year,
                  4.99852801234917238e-03 * days_per_year,
                  2.30417297573763929e-05 * days_per_year,
                  2.85885980666130812e-04 * solar_mass)

    uranus = Body( 1.28943695621391310e+01,
                  -1.51111514016986312e+01,
                  -2.23307578892655734e-01,
                  2.96460137564761618e-03 * days_per_year,
                  2.37847173959480950e-03 * days_per_year,
                  -2.96589568540237556e-05 * days_per_year,
                  4.36624404335156298e-05 * solar_mass)

    neptune = Body( 1.53796971148509165e+01,
                   -2.59193146099879641e+01,
                   1.79258772950371181e-01,
                   2.68067772490389322e-03 * days_per_year,
                   1.62824170038242295e-03 * days_per_year,
                   -9.51592254519715870e-05 * days_per_year,
                   5.15138902046611451e-05 * solar_mass)

    sun = Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, solar_mass)

    bodies = [sun, jupiter, saturn, uranus, neptune]
    init_sun(bodies)

    bufs = Buffers(10)

    @printf("%.9f\n", energy(bodies))
    for i = 1:N
        advance!(bodies, 0.01, bufs)
    end
    @printf("%.9f\n", energy(bodies))
end

end # module

isinteractive() || NBody.perf_nbody(parse(Int, ARGS[1]))
