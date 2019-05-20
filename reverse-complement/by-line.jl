import Distributed: @everywhere, addprocs, RemoteChannel

#const procs = addprocs(parse(Int64, ARGS[1]))

@everywhere import SharedArrays: SharedVector

const RESIZE_INCREMENT = 4096
const RESIZE_SLOP = 61

@everywhere const complement = Pair{Char,Char}[
    'A' => 'T', 'a' => 'T',
    'C' => 'G', 'c' => 'G',
    'G' => 'C', 'g' => 'C',
    'T' => 'A', 't' => 'A',
    'U' => 'A', 'u' => 'A',
    'M' => 'K', 'm' => 'K',
    'R' => 'Y', 'r' => 'Y',
    'W' => 'W', 'w' => 'W',
    'S' => 'S', 's' => 'S',
    'Y' => 'R', 'y' => 'R',
    'K' => 'M', 'k' => 'M',
    'V' => 'B', 'v' => 'B',
    'H' => 'D', 'h' => 'D',
    'D' => 'H', 'd' => 'H',
    'B' => 'V', 'b' => 'V',
    'N' => 'N', 'n' => 'N',
]
@everywhere const complementbytes = zeros(UInt8, 256)
@everywhere for (k, v) in complement
    complementbytes[k % UInt8] = v % UInt8
end#for

function revline!(x::AbstractVector{UInt8}, bytemap::AbstractVector{UInt8})
    @inbounds if x[1] === 0x3e
        return
    end#if
    left, right = 1, length(x)
    @inbounds while left < right
        x[left], x[right] = bytemap[x[right]], bytemap[x[left]]
        left += 1
        right -= 1
    end#while
    if left === right
        @inbounds x[left] = bytemap[x[left]]
    end#if
    nothing
end#function

function buffered_append!(c1, c2, last_resize::Int64)
    let current_length = length(c1)
        if current_length > RESIZE_INCREMENT + last_resize - RESIZE_SLOP
            resize!(c1, current_length + RESIZE_INCREMENT)
            resize!(c1, current_length)
            last_resize = current_length
        end#if
    end#let
    append!(c1, c2)
    last_resize
end#function

function main()
    bufs = [SharedVector{UInt8}(undef, RESIZE_INCREMENT)]
    resize!(buf, 0)
    last_resize = 0
    while !eof(stdin)
        line = codeunits(readline(stdin))
        if first(line) === 0x3e
            push!(bufs, SharedVector{UInt8}(undef, RESIZE_INCREMENT))
            resize!(last(bufs), 0)
        end#if
        last_resize = buffered_append!(last(bufs), line, last_resize)
    end#while
end#function
