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
    io::IO
    buffer::Vector{UInt8}
    position::Int
end#struct

function BufferedInput(io::IO)
    buffer = Vector{UInt8}(undef, READSIZE)
    n = min(readbytes!(io, buffer), READSIZE)
    # Resizing in case available input < READSIZE
    resize!(buffer, n)
    # Make sure to handle case of empty IO
    BufferedInput{IO}(io, buffer, isempty(buffer) ? 0 : 1)
end#function

function refill!(io::BufferedInput)
    n = readbytes!(io.io, io.buffer)
    resize!(io.buffer, n)
    io.position = iszero(n) ? 0 : 1
end#function

function readline!(io::BufferedInput, line::Vector{UInt8})
    # TODO: what if io.buffer is empty?
    if io.position > length(io.buffer)
        refill!(io)
    end#if
    io.position != 0 || return
    next_newline = length(io.buffer) + 1
    for i in io.position:length(io.buffer)
        if io.buffer[i] == '\n' % UInt8
            next_newline = i
            break
        end#if
    end#for
    if next_newline == length(io.buffer)
        append!(line, @view(io.buffer[io.position:next_newline - 1]))
        refill!(io)
    elseif next_newline > length(io.buffer)
        append!(line, @view(io.buffer[io.position:end]))
        refill!(io)
        readline!(io, line)
    else
        append!(line, @view(io.buffer[io.position:next_newline - 1]))
        io.position = next_newline + 1
    end#if
    nothing
end#function

function revcomp!(x::AbstractVector{UInt8}, bytemap::Vector{UInt8})
    len = length(x)
    iter_range = range(1, len ÷ 2; step=1)
    for i in iter_range
        let l = i, r = len - i + 1
            @inbounds x[l], x[r] = bytemap[x[r]], bytemap[x[l]]
        end#let
    end#for
    if isodd(len)
        @inbounds x[len ÷ 2 + 1] = bytemap[x[len ÷ 2 + 1]]
    end#if
end#function

write_line(io::IO, v::AbstractVector{UInt8}) = (write(io, v); write(io, '\n'))

function write_chunk(io::IO, v::AbstractVector{UInt8})
    if !isempty(v)
        pos = firstindex(v)
        while pos < length(v) - LINESIZE
            @inbounds write_line(io, @view(v[pos:pos+LINESIZE-1]))
            pos += LINESIZE
        end#while
        @inbounds write_line(io, @view(v[pos:end]))
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
            @inbounds revcomp!(data, bytemap)
            @inbounds write_chunk(outio, data)
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
    @inbounds revcomp!(data, bytemap)
    @inbounds write_chunk(outio, data)
end#function

main(stdin, stdout, complementbytes)
