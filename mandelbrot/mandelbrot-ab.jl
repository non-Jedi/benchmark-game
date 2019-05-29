const RMAX = 2f0
const RMAX² = RMAX * RMAX
const ITER = 50
const CHECKFREQ = 5
const XRANGE = -1.5f0 => 0.5f0
const YRANGE = -1f0 => 1f0

const N = parse(Int64, ARGS[1])

Base.@pure function nextz(zr, zi, cr, ci)
    zrsq = Base.mul_float(zr, zr)
    zisq = Base.mul_float(zi, zi)
    (
        Base.add_float(zrsq, Base.add_float(cr, Base.neg_float(zisq))),
        Base.muladd_float(2f0, Base.mul_float(zr, zi), ci),
        zrsq, zisq,
    )
end#function
function nextz(zr::Tuple, zi, cr::Tuple, ci)
    accum = nextz.(zr, zi, cr, ci)
    zr = ntuple(i -> accum[i][1], 8)
    zi = ntuple(i -> accum[i][2], 8)
    zrsq = ntuple(i -> accum[i][3], 8)
    zisq = ntuple(i -> accum[i][4], 8)
    (zr, zi, zrsq, zisq)
end#function

function mandelbrot_byte(cr::NTuple{8,Float32}, ci::Float32)
    zr, zi, zrsq, zisq = nextz(cr, ci, cr, ci)

    tmp = ntuple(_ -> 0f0, 8)
    i = 0
    while i < ITER
        @inbounds for _ in 1:CHECKFREQ
            zr, zi, zrsq, zisq = nextz(zr, zi, cr, ci)
            i += 1
        end#for
        tmp = zrsq .+ zisq
        all(e -> isnan(e) || e > RMAX², tmp) && return 0x00
    end#while

    byte = 0xff
    tmp[1] <= 4.0 || (byte &= 0b01111111)
    tmp[2] <= 4.0 || (byte &= 0b10111111)
    tmp[3] <= 4.0 || (byte &= 0b11011111)
    tmp[4] <= 4.0 || (byte &= 0b11101111)
    tmp[5] <= 4.0 || (byte &= 0b11110111)
    tmp[6] <= 4.0 || (byte &= 0b11111011)
    tmp[7] <= 4.0 || (byte &= 0b11111101)
    tmp[8] <= 4.0 || (byte &= 0b11111110)
    byte
end#function

function write_pbm(io::IO, n::Integer, v::AbstractArray{UInt8})
    write(io, "P4\n")
    s = string(n)
    write(io, s, " ", s, "\n")
    write(io, v)
end#function

function main(io::IO, xrange, yrange, n::Integer)
    # example image isn't inclusive on upper bound
    stepx = (last(xrange) - first(xrange)) / n
    stepy = (last(yrange) - first(yrange)) / n
    a = collect(range(first(xrange); length=n, step=stepx))
    b = collect(range(first(yrange); length=n, step=stepy))
    
    byte_n = iszero(n % 8) ? n ÷ 8 : n ÷ 8 + 1
    # Can't use Julia BitMatrix because order is backwards within bytes
    out = zeros(UInt8, (byte_n, n))
    Threads.@threads for j in 1:n
#    for j in 1:n
        @inbounds @simd for i in 1:byte_n
            endxprev = i * 8 - 8
            out[i,j] = mandelbrot_byte(ntuple(i -> a[endxprev+i], 8), b[j])
        end#for
    end#for
    write_pbm(io, n, out)
    out
end#function

main(stdout, XRANGE, YRANGE, N)
