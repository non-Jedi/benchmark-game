#                                         ABCDEFGHIJKLMNOPQRSTUVWXYZ      abcdefghijklmnopqrstuvwxyz
const complement_hasharr = Vector{UInt8}("TVGH  CD  M KN   YSAABW R       TVGH  CD  M KN   YSAABW R")
complement(charbyte::UInt8)  = @inbounds complement_hasharr[charbyte - 0x40]

function reversemap!(f,v::AbstractVector{UInt8}, s=first(LinearIndices(v)), n=last(LinearIndices(v)))
    r = n
    i = s
    @inbounds while true
        while v[i] < 0x41
           i+=1
        end
        while v[r] < 0x41
           r-=1
        end
        if i >= r
           break
        end
        v[i], v[r] = f(v[r]), f(v[i])
        i += 1
        r -= 1
    end
    if i==r
      v[r] = f(v[r])
    end
    return v
end

reversecomplement!(block) = reversemap!(complement,block)

function main(;instream = stdin, outstream = stdout)
   readuntil(instream,UInt8('>'))
   while !eof(instream)
      header = readuntil(instream,UInt8('\n'))
      body = readuntil(instream,UInt8('>'))
      write(outstream,UInt8('>'),header,UInt8('\n'))
      write(outstream,reversecomplement!(body))
   end
end

main()
