# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# Contributed by Adam Beckmeyer

import Printf: @printf
using Base.Threads

const LINESIZE = 61
const SIZEHINT = 4 * 4096
const COUNTSFOR = zip(
    (5, 4, 3, 2, 1),
    collect.(codeunits.(("ggt", "ggta", "ggtatt", "ggtattttaatt",
                         "ggtattttaatttatagt")))
)
const PERMS1 = collect.(codeunits.((
    "a", "c", "g", "t"
)))
const PERMS2 = collect.(codeunits.((
    "aa", "ac", "ag", "at",
    "ca", "cc", "cg", "ct",
    "ga", "gc", "gg", "gt",
    "ta", "tc", "tg", "tt",
)))

const BYTE_TO_BITS = Vector{UInt8}(undef, 256)
@inbounds BYTE_TO_BITS['a' % UInt8] = 0x00
@inbounds BYTE_TO_BITS['c' % UInt8] = 0x01
@inbounds BYTE_TO_BITS['g' % UInt8] = 0x02
@inbounds BYTE_TO_BITS['t' % UInt8] = 0x03

# * Override default hash function for UInt32 and UInt64 for performance

# This is the hash function used in C gcc program by Jeremy Zerfas
Base.hash(x::UInt32)::UInt64 = x ⊻ x >> 7
Base.hash(x::UInt64)::UInt64 = x ⊻ x >> 7

# * Functions to do the calculation of number of occurrences

Base.@propagate_inbounds function hashvec(
    v::AbstractVector{UInt8}, ::Type{T}, indstart, indend
) where T
    result = zero(T)
    for ind in indstart:indend
        result = result<<2 | T(BYTE_TO_BITS[v[ind]])
    end#for
    result
end#function

Base.@propagate_inbounds hashvec(v, T) =
    hashvec(v, T, firstindex(v), lastindex(v))

Base.@propagate_inbounds nexthash(b::T, c::UInt8, mask::T) where T =
    mask & b<<2 | BYTE_TO_BITS[c]

function get_mask(n, ::Type{T}) where T<:Unsigned
    out = zero(T)
    for _ in 1:n
        out = out<<2 | 0x03
    end#for
    out
end#function

function count_frame!(frame, seq, dict::AbstractDict{K,V}) where {K,V}
    @specialize
    subseq = hashvec(seq, K, 1, frame)
    dict[subseq] = get(dict, subseq, zero(V)) + one(V)
    mask = get_mask(frame, K)
    
    @inbounds for i in frame + 1:length(seq)
        subseq = nexthash(subseq, seq[i], mask)
        dict[subseq] = get(dict, subseq, zero(V)) + one(V)
    end#for
end#function

# * Get input in the proper format

function get_third_seq(io)
    count = 0
    buffer_size = SIZEHINT
    buffer = Vector{UInt8}(undef, buffer_size)
    empty!(buffer)
    linebuffer = Vector{UInt8}(undef, LINESIZE)
    while !eof(io)
        if count === 3
            resize!(linebuffer, LINESIZE)
            new_length = length(buffer) + LINESIZE
            if new_length > buffer_size
                buffer_size = nextpow(2, nextpow(2, new_length))
                sizehint!(buffer, buffer_size)
            end#if
            nb = readbytes!(io, linebuffer)
            resize!(linebuffer, nb - 1)
            append!(buffer, linebuffer)
        else
            pos = position(io)
            nb = readbytes!(io, linebuffer)
            @inbounds count += first(linebuffer) === '>' % UInt8
            if last(linebuffer) !== '\n' % UInt8
                @inbounds seek(io, pos + findnext(isnewline, linebuffer, 1))
            end#if
        end#if
    end#while
    buffer
end#function

isnewline(c::UInt8)::Bool = c === '\n' % UInt8

# * Calculate and format statistics and output

function write_freq(io, d::Dict{T}, perms) where T
    v = [i => d[T(hashvec(i, UInt8))] for i in perms]
    sort!(v; rev=true)
    total = sum(last, v)
    for (subseq, freq) in v
        write(io, uppercase(String(subseq)), ' ')
        @printf(io, "%2.3f\n", 100freq / total)
    end#for
    write(io, '\n')
end#function

function write_occurrences(io, d::AbstractDict{K}, subseq) where K
    n = get(d, hashvec(subseq, K), 0)
    print(io, n)
    write(io, '\t', uppercase(String(subseq)), '\n')
end#function

# Type piracy so things are printed in right order
function Base.isless(a::Pair{<:Vector,<:Integer}, b::Pair{<:Vector,<:Integer})
    if a.second === b.second
        isless(a.first, b.first)
    else
        isless(a.second, b.second)
    end#if
end#function

# * Tie everything together

function main(ioin, ioout)
    seq = get_third_seq(ioin)
    # All frames can fit into UInt32 except largest
    freqs = (Dict{UInt64,Int32}(), Dict{UInt32,Int32}(), Dict{UInt32,Int32}(),
             Dict{UInt32,Int32}(), Dict{UInt32,Int32}(), Dict{UInt32,Int32}(),
             Dict{UInt32,Int32}())
    # reverse so iterations that take longest start first
    frames = [18, 12, 6, 4, 3, 2, 1]
    @inbounds @threads for i in 1:length(frames)
        count_frame!(frames[i], seq, freqs[i])
    end#for
    # output
    write_freq(ioout, freqs[7], PERMS1)
    write_freq(ioout, freqs[6], PERMS2)
    for (i, subseq) in COUNTSFOR
        @inbounds write_occurrences(ioout, freqs[i], subseq)
    end#for
    freqs
end#function

isinteractive() || main(stdin, stdout)
