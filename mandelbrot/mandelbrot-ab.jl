const RMAX = 2
const ITER = 50
const XRANGE = -1.5 => 0.5
const YRANGE = -1.0 => 1.0

const N = parse(Int64, ARGS[1])

z₊₁(c, z) = z^2 + c
#z₊₁(ca, cb, za, zb) = za^2 - zb^2 + ca

function ismandelbrot(c, iter, rmax)
    z = c
    rmax² = rmax^2
    for i in 1:iter
        abs2(z) > rmax² && return false
        z = z₊₁(c, z)
    end#if
    true
end#function

Base.@propagate_inbounds function construct_byte(bools::AbstractVector{Bool})
    byte = 0x00
    bools[1] && (byte |= 0b10000000)
    bools[2] && (byte |= 0b01000000)
    bools[3] && (byte |= 0b00100000)
    bools[4] && (byte |= 0b00010000)
    bools[5] && (byte |= 0b00001000)
    bools[6] && (byte |= 0b00000100)
    bools[7] && (byte |= 0b00000010)
    bools[8] && (byte |= 0b00000001)
    byte
end#function

Base.@propagate_inbounds function mandelbrot_byte(nums::AbstractVector{Complex{Float64}})
    bools = similar(nums, Bool)
    @simd for i in 1:length(nums)
        bools[i] = ismandelbrot(nums[i], 50, RMAX)
    end#for
    construct_byte(bools)
end#function

function write_pbm(io::IO, n::Integer, v::AbstractArray{UInt8})
    write(io, "P4\n")
    s = string(n)
    write(io, s, " ", s, "\n")
    write(io, v)
end#function

function main(io::IO, xrange, yrange, n::Integer)
    a = range(first(xrange), last(xrange); length=n)
    b = range(first(yrange), last(yrange); length=n)
    c = Matrix{Complex{Float64}}(undef, n, n)
    for (j, y) in enumerate(b), (i, x) in enumerate(a)
        c[i,j] = x + y*im
    end#for
    
    byte_n = iszero(n % 8) ? n ÷ 8 : n ÷ 8 + 1
    # Can't use Julia BitMatrix because order is backwards within bytes
    out = zeros(UInt8, (byte_n, n))
    for j in 1:n
        for i in 1:byte_n
            endx = i * 8
            out[i,j] = mandelbrot_byte(@view(c[endx-7:endx]))
        end#for
    end#for
    write_pbm(io, n, out)
end#function

main(stdout, XRANGE, YRANGE, N)
