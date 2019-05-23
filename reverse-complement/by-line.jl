const INIT_SIZE = 4096
const CHANNEL_SIZE = 5000
const LINE_SIZE = 60

const complementbytes = zeros(UInt8, 256)
for (i, j) in zip(
    "AaCcGgTtUuMmRrWwSsYyKkVvHhDdBbNn",
    "TTGGCCAAAAKKYYWWSSRRMMBBDDHHVVNN"
)
    complementbytes[i % UInt8] = j % UInt8
end#for

function revcomp!(x::AbstractVector{UInt8}, bytemap::Vector{UInt8})
    len = length(x)
    iter_range = range(1, len ÷ 2; step=1)
    Threads.@threads for i in iter_range
        let l = i, r = len - i + 1
            @inbounds x[l], x[r] = bytemap[x[r]], bytemap[x[l]]
        end#let
    end#for
    if isodd(len)
        @inbounds x[len ÷ 2 + 1] = bytemap[x[len ÷ 2 + 1]]
    end#if
end#function

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
            resize!(v.v, nextpow(2, nextpow(2, L)))
        end#if
        @inbounds copyto!(v.v, v.l + 1, xs, first(ixs), l)
        v.l = total_l
    end#let
    v
end#function

# end PushVectors.jl
#-------------------------------------------------------------------------------

const WorkChannel = Channel{
    SubArray{UInt8, 1, Vector{UInt8}, Tuple{UnitRange{Int64}}, true}
}
const PrintChannel = Channel{Tuple{
    Channel{SubArray{UInt8, 1, Vector{UInt8}, Tuple{UnitRange{Int64}},true}},
    # Data, Beginning index, End index, Chunk beginning indexes
    Vector{UInt8}, Int64, Int64, Vector{Int64}
}}

function printer(c::PrintChannel, io::IO=stdout)
    while true
        wc, data, start_ind, end_ind, chunks = take!(c)
        isnan(start_ind) && break
        @inbounds write(io, @view(data[start_ind:first(chunks)-1]))
        write(io, '\n')

        # TODO: check that wc is empty and ?closed? first
        linepos = 0
        for i in lastindex(chunks):-1:firstindex(chunks)
            @inbounds startb = chunks[i]
            @inbounds endb = i == lastindex(chunks) ? end_ind : chunks[i+1]
            # TODO: handle linepos != 0
            bi = startb
            while bi < endb - LINE_SIZE
                @inbounds write(io, data[bi:bi+LINESIZE-1])
                write(io, '\n')
                bi += LINE_SIZE
            end#while
            # TODO: write bytes between bi and endb
        end#for
    end#while
end#function

function main()
    data = PushVector(Vector{UInt8}(undef, INIT_SIZE), 0)

    workchannel = WorkChannel(CHANNEL_SIZE)
    printchannel = PrintChannel(CHANNEL_SIZE)
    while !eof(stdin)
        line = codeunits(readline(stdin))
        if first(line) === 0x3e
            nothing
        else
            nothing
        end#if
    end#while
end#function
