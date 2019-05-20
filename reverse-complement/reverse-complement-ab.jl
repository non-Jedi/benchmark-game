const complement = Pair{Char,Char}[
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
const complementbytes = zeros(UInt8, 256)
for (k, v) in complement
    complementbytes[k % UInt8] = v % UInt8
end#for

function revcomp!(x::AbstractVector{UInt8}, bytemap::Vector{UInt8})
    # Song and dance to ensure left cannot be nothing for type-stability
    left = let eol = findfirst(b -> b === 0x0a, x)
        eol === nothing ? 1 : eol + 1
    end#let
    @inbounds right = x[length(x)] === 0x0a ? length(x) - 1 : length(x)
    @inbounds while left < right
        lcur, lnext = x[left], x[left+1]
        rnext, rcur = x[right-1], x[right]
        x[left], x[right] = bytemap[rcur], bytemap[lcur]
        left = lnext === 0x0a ? left + 2 : left + 1
        right = rnext === 0x0a ? right - 2 : right - 1
    end#while
    # If an odd number, left and right will be same
    if left === right
        @inbounds x[left] = bytemap[x[left]]
    end#if
    nothing
end#function

function main(bytemap::Vector{UInt8})
    input::Vector{UInt8} = read(stdin)

    headers = findall(b -> b === 0x3e, input)
    fastas = Vector{SubArray{UInt8, 1, Vector{UInt8}, Tuple{UnitRange{Int64}},
                             true}}(undef, length(headers))
    @inbounds for (i, h) in enumerate(headers)
        fastas[i] = if i < length(headers)
            @view(input[h:headers[i+1] - 1])
        else
            @view(input[h:end])
        end#if
    end#for

    Threads.@threads for f in fastas
        revcomp!(f, bytemap)
    end#for
    
    write(stdout, input)
    nothing
end#function

main(complementbytes)
