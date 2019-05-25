using Profile

const SIZEHINT = 8192
const LINESIZE = 60

const complementbytes = zeros(UInt8, 256)
for (i, j) in zip(
    "AaCcGgTtUuMmRrWwSsYyKkVvHhDdBbNn",
    "TTGGCCAAAAKKYYWWSSRRMMBBDDHHVVNN"
)
    @inbounds complementbytes[i % UInt8] = j % UInt8
end#for

#-------------------------------------------------------------------------------
# Taken from PushVectors.jl: https://github.com/tpapp/PushVectors.jl
#
# The PushVectors.jl package is licensed under the MIT "Expat" License:
# 
# > Copyright (c) 2018: Tamas K. Papp.
# >
# > Permission is hereby granted, free of charge, to any person obtaining a copy
# > of this software and associated documentation files (the "Software"), to deal
# > in the Software without restriction, including without limitation the rights
# > to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# > copies of the Software, and to permit persons to whom the Software is
# > furnished to do so, subject to the following conditions:
# >
# > The above copyright notice and this permission notice shall be included in all
# > copies or substantial portions of the Software.
# >
# > THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# > IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# > FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# > AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# > LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# > OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# > SOFTWARE.

mutable struct PushVector{T, V<:AbstractVector{T}} <: AbstractVector{T}
    v::V
    l::Int64
end#struct

@inline Base.length(v::PushVector) = v.l
@inline Base.size(v::PushVector) = (v.l, )

function Base.sizehint!(v::PushVector, n)
    if length(v.v) < n || n ≥ v.l
        resize!(v.v, n)
    end#if
    nothing
end#function

@inline function Base.getindex(v::PushVector, i)
    @boundscheck checkbounds(v, i)
    @inbounds v.v[i]
end#function

@inline function Base.setindex!(v::PushVector, x, i)
    @boundscheck checkbounds(v, i)
    @inbounds v.v[i] = x
end#function

Base.empty!(v::PushVector) = (v.l = 0; v)

function Base.append!(v::PushVector, xs)
    ixs = eachindex(xs)
    let l = length(ixs)
        total_l = l + v.l
        if length(v.v) < total_l
            resize!(v.v, nextpow(2, nextpow(2, total_l)))
        end#if
        @inbounds copyto!(v.v, v.l + 1, xs, first(ixs), l)
        v.l = total_l
    end#let
    v
end#function

# end PushVectors.jl
#-------------------------------------------------------------------------------

@inline Base.resize!(v::PushVector, l) = setfield!(v, :l, l)
Base.write(io::IO, v::PushVector) = @inbounds write(io, @view(v.v[1:v.l]))

function revcomp!(x::AbstractVector{UInt8}, bytemap::Vector{UInt8})
    len = length(x)
    iter_range = range(1, len ÷ 2; step=1)
#    Threads.@threads for i in iter_range
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
    data = PushVector(Vector{UInt8}(undef, SIZEHINT), 0)
    while !eof(inio)
        line = codeunits(readline(inio))
        if first(line) == 0x3e # '>'
            revcomp!(data, bytemap)
            write_chunk(outio, data)
            write_line(outio, line)
            resize!(data, 0)
        else
            append!(data, line)
        end#if
    end#while
    revcomp!(data, bytemap)
    write_chunk(outio, data)
end#function

Profile.init(n=10^7, delay=0.003)

@profile main(stdin, stdout, complementbytes)

open("by-line-simple.jl-profile.txt"; write=true) do f
    Profile.print(IOContext(f, :displaysize => (24, 600)))
end#open

