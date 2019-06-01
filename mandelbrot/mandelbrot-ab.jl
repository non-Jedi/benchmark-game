const ITER = 50
const CHECKFREQ = 5
const zerotuple8 = ntuple(_ -> zero(Float32), 8)

function mandelbrot_floats(cr::NTuple{8,T}, ci::T) where {T<:AbstractFloat}
    # Use broadcasting instead of loops because tuples aren't mutable
    zr = zi = zrsq = zisq = absz = zerotuple8
    i = 0
    while i < ITER
        @inbounds for _ in 1:CHECKFREQ
            zi = @. T(2) * zr * zi + ci
            zr = @. zrsq - zisq + cr
            zrsq = zr .* zr
            zisq = zi .* zi
            i += 1
        end#for
        
        absz = zrsq .+ zisq
        all(e -> e > 4f0, absz) && break
    end#while

    absz
end#function

function mandelbrot_byte(zsums::NTuple{8,<:AbstractFloat})
    byte = 0xff
    @inbounds for i in 0x01:0x08
        byte &= ifelse(zsums[i] <= 4f0, byte, ~(0x01<<(0x08-i)))
    end#for
    byte
end#function

function main(io::IO, n::Integer)
    byte_n = n ÷ 8

    # Tuples of values instead of vectors to help SIMD code generation
    a = Vector{NTuple{8,Float32}}(undef, byte_n)
    @inbounds for j in 1:byte_n
        # Mimic calculations from original Julia code to avoid float errors
        a[j] = ntuple(i -> Float32(2*(8*(j - 1) + i - 1) / n - 1.5), 8)
    end#for
    b = collect(Float32(2 * j / n - 1) for j in 0:n-1)
    
    # Can't use Julia BitVector because order is backwards within bytes
    # Not using Matrix since extra precompilation occurs versus Vector
    out = Vector{UInt8}(undef, byte_n*n)
    Threads.@threads for j in 0:n-1
        @inbounds bval = b[j+1]
        @inbounds inner(out, a, bval, j)
    end#for
    write_pbm(io, n, out)
    out
end#function

# inner exists to put a function barrier between @threads and @simd macros
Base.@propagate_inbounds function inner(
    out::AbstractVector{UInt8}, a::AbstractVector{NTuple{8,T}}, bval::T, j::Integer
) where T<: AbstractFloat
    @simd for i in 1:length(a)
        out[j * length(a) + i] = mandelbrot_byte(mandelbrot_floats(a[i], bval))
    end#for
end#function

function write_pbm(io::IO, n::Integer, v::AbstractArray{UInt8})
    write(io, "P4\n")
    s = string(n)
    write(io, s, " ", s, "\n")
    write(io, v)
end#function

main(stdout, parse(Int, ARGS[1]))
