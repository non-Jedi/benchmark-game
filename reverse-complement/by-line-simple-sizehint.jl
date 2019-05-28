const SIZEHINT = 8192
const LINESIZE = 60

const complementbytes = zeros(UInt8, 256)
for (i, j) in zip(
    "AaCcGgTtUuMmRrWwSsYyKkVvHhDdBbNn",
    "TTGGCCAAAAKKYYWWSSRRMMBBDDHHVVNN"
)
    @inbounds complementbytes[i % UInt8] = j % UInt8
end#for

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
    size_max= SIZEHINT
    data = Vector{UInt8}(undef, SIZEHINT)
    empty!(data)
    while !eof(inio)
        line = codeunits(readline(inio))
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
    end#while
    @inbounds revcomp!(data, bytemap)
    @inbounds write_chunk(outio, data)
end#function

main(stdin, stdout, complementbytes)
