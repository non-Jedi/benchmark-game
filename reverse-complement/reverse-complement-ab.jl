const complement = Dict{Char,Char}(
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
)
const complementbytes = zeros(UInt8, 256)
for (k, v) in pairs(complement)
    complementbytes[k % UInt8] = v % UInt8
end#for

function revcomp!(x::AbstractVector{UInt8})
    left = findfirst(b -> b === 0x0a, x)
    right = length(x)
    @inbounds while left < right
        if x[left] === 0x0a # '\n'
            left += 1
        end#if
        if x[right] === 0x0a # '\n'
            right -= 1
        end#if
        # Above could cause left and right to be same index
        left === right && break

        x[left], x[right] = complementbytes[x[right]], complementbytes[x[left]]

        left += 1
        right -= 1
    end#while
    # If an odd number, left and right will be same
    if left === right && x[left] !== 0x0a
        x[left] = complementbytes[x[left]]
    end#if
end#function

function main()
    input = read(stdin) # Creates Vector{UInt8} over which we will operate
    headers = findall(b -> b === 0x3e, input)
    fastas = Vector{SubArray{UInt8,1,Vector{UInt8}}}(undef, length(headers))
    @inbounds for (i, h) in enumerate(headers)
        fastas[i] = if i < length(headers)
            @view(input[h:headers[i+1] - 1])
        else
            @view(input[h:end])
        end#if
    end#for

    Threads.@threads for f in fastas
        revcomp!(f)
    end#for
    
    write(stdout, input)
end#function

main()
