const SIZEHINT = 8192
const LINESIZE = 60
const READSIZE = 16 * 1024

const complementbytes = zeros(UInt8, 256)
for (i, j) in zip(
    "AaCcGgTtUuMmRrWwSsYyKkVvHhDdBbNn",
    "TTGGCCAAAAKKYYWWSSRRMMBBDDHHVVNN"
)
    @inbounds complementbytes[i % UInt8] = j % UInt8
end#for

mutable struct BufferedInput{T<:IO}
    io::T
    buffer::Vector{UInt8}
    position::Int
end#struct

function BufferedInput(io::IO)
    buffer = Vector{UInt8}(undef, READSIZE)
    n = min(readbytes!(io, buffer), READSIZE)
    # Resizing in case available input < READSIZE
    @inbounds resize!(buffer, n)
    # Make sure to handle case of empty IO
    BufferedInput(io, buffer, isempty(buffer) ? 0 : 1)
end#function

function refill!(io::BufferedInput)
    n = readbytes!(io.io, io.buffer)
    resize!(io.buffer, n)
    io.position = iszero(n) ? 0 : 1
end#function

function next_occurrence(c::T, v::AbstractVector{T}, start::Int) where T
    next = length(v) + 1
    @inbounds for i in start:length(v)
        if v[i] === c
            next = i
            break
        end#if
    end#for
    next
end#function

function readline!(io::BufferedInput, line::Vector{UInt8})
    io.position != 0 || return
    next_newline = next_occurrence('\n' % UInt8, io.buffer, io.position)
    if next_newline == length(io.buffer)
        len = next_newline - io.position
        resize!(line, len)
        @inbounds copyto!(line, 1, io.buffer, io.position, len)
        refill!(io)
    elseif next_newline > length(io.buffer)
        len = length(io.buffer) - io.position + 1
        resize!(line, len)
        @inbounds copyto!(line, 1, io.buffer, io.position, len)
        refill!(io)
        if !isempty(io.buffer)
            next_newline = next_occurrence('\n' % UInt8, io.buffer, io.position)
            len = next_newline - io.position
            sp = length(line)
            resize!(line, sp + len)
            @inbounds copyto!(line, sp+1, io.buffer, io.position, len)
            io.position = next_newline + 1
        end#if
    else
        len = next_newline - io.position
        resize!(line, len)
        @inbounds copyto!(line, 1, io.buffer, io.position, len)
        io.position = next_newline + 1
    end#if
    nothing
end#function

function revcomp!(x::AbstractVector{UInt8}, bytemap::Vector{UInt8})
    len = length(x)
    iter_range = range(1, len ÷ 2; step=1)
    @inbounds @simd for i in iter_range
        let l = i, r = len - i + 1
            x[l], x[r] = bytemap[x[r]], bytemap[x[l]]
        end#let
    end#for
    if isodd(len)
        @inbounds x[len ÷ 2 + 1] = bytemap[x[len ÷ 2 + 1]]
    end#if
end#function

write_line(io::IO, v::AbstractVector{UInt8}) = (write(io, v); write(io, '\n'))

function write_chunk(io::IO, v::AbstractVector{UInt8})
    if !isempty(v)
        chunk = Vector{UInt8}(undef, nextpow(2, length(v)))
        empty!(chunk)
        pos = firstindex(v)
        while pos < length(v) - LINESIZE
            p1 = length(chunk) + 1
            resize!(chunk, length(chunk) + LINESIZE + 1)
            @inbounds copyto!(chunk, p1, v, pos, LINESIZE)
            @inbounds chunk[end] = '\n' % UInt8
            pos += LINESIZE
        end#while
        p1 = length(chunk) + 1
        resize!(chunk, length(chunk) + length(v) - pos + 2)
        @inbounds copyto!(chunk, p1, v, pos, length(v) - pos + 1)
        chunk[end] = '\n' % UInt8
        write(io, chunk)
    end#if
    nothing
end#function

function main(inio::IO, outio::IO, bytemap::Vector{UInt8})
    size_max = SIZEHINT
    input = BufferedInput(inio)
    data = Vector{UInt8}(undef, SIZEHINT)
    empty!(data)
    line = Vector{UInt8}(undef, LINESIZE)
    empty!(line)
    readline!(input, line)
    while !isempty(line)
        if first(line) == 0x3e # '>'
            revcomp!(data, bytemap)
            write_chunk(outio, data)
            write_line(outio, line)
            empty!(data)
        else
            l = length(data) + length(line)
            if l > size_max
                size_max = nextpow(2, nextpow(2, l))
                sizehint!(data, size_max)
            end#if
            append!(data, line)
        end#if
        empty!(line)
        readline!(input, line)
    end#while
    revcomp!(data, bytemap)
    write_chunk(outio, data)
end#function

main(stdin, stdout, complementbytes)
