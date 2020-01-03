# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

# based on Oleg Mazurov's Java Implementation and Jeremy Zerfas' C implementation
# transliterated and modified by Hamza Yusuf Çakır

import Base: @propagate_inbounds

const NUM_BLOCKS = 24

struct Fannkuch
    n::Int64
    blocksz::Int64
    # Overall performance is better with Int32 than with Int8
    maxflips::Vector{Int32}
    chksums::Vector{Int32}
end

function Fannkuch(n, nthreads)
    nfact = factorial(n)
    blocksz = nfact ÷ (nfact < NUM_BLOCKS ? 1 : NUM_BLOCKS)

    Fannkuch(n, blocksz, zeros(Int32, nthreads), zeros(Int32, nthreads))
end

struct Perm
    p::Vector{Int32}
    pp::Vector{Int32}
    count::Vector{Int32}
end

Perm(n) = Perm(collect(Int32, 0:n-1), collect(Int32, 0:n-1), zeros(Int32, n))

@propagate_inbounds function first_permutation(perm, idx)
    for i = length(perm.p):-1:2
        ifact = factorial(i - 1)
        d = idx ÷ ifact
        perm.count[i] = d
        idx = idx % ifact

        rotate!(perm.p, perm.pp, i, d)
    end
end

# Rotate the first i elements of v by n elements to the left using tmp
# as a temporary buffer
@propagate_inbounds function rotate!(v, tmp, i, n)
    copyto!(tmp, v)
    for j=1:i
        k = j + n <= i ? j + n : j + n - i
        v[j] = tmp[k]
    end
end

@propagate_inbounds function next_permutation(perm)
    p = perm.p
    count = perm.count

    p[1], p[2] = p[2], p[1]

    i = 2
    while count[i] >= i - 1
        count[i] = 0

        tmp = p[1]
        for j = 1:i
            p[j] = p[j+1]
        end
        i += 1
        p[i] = tmp
    end
    count[i] += 1
end

@propagate_inbounds function count_flips(perm)
    p = perm.p
    pp = perm.pp
    flips = 1

    first_value = first(p) + 1
    if p[first_value] != 0
        # pp will be working copy. Don't have to copy first value as
        # it's stored in first_value var
        unsafe_copyto!(pp, 2, p, 2, length(p) - 1)

        # If the next flip would result in 0 being in first position,
        # iteration can stop without doing the flip
        while (new_first_value = pp[first_value]) != 0
            flips += 1
            # If only 2 or 3 elements flipped, a swap is all that's needed
            pp[first_value] = first_value - 1
            # If first_value is greater than 3, more flips are needed
            if first_value > 3
                l = 2; r = first_value - 1
                # In total, first_value ÷ 2 swaps must occur, but 1 is
                # already finished. Use the 1:12 as a range here instead
                # to hint the compiler towards unrolling. This means that
                # this program is not correct for n > 27.
                for _=1:12
                    pp[l], pp[r] = pp[r], pp[l]
                    (r < l + 3) && break
                    l += 1
                    r -= 1
                end
            end
            first_value = new_first_value + 1
        end
    end

    flips
end

@propagate_inbounds function run_task(f, perm, idxmin, idxmax)
    maxflips = 0
    chksum = 0

    i = idxmin
    while true
        if perm.p[1] != 0
            flips = count_flips(perm)
            (flips > maxflips) && (maxflips = flips)
            chksum += iseven(i) ? flips : -flips
        end
        i != idxmax || break
        i += 1
        next_permutation(perm)
    end

    id = Threads.threadid()
    (maxflips > f.maxflips[id]) && (f.maxflips[id] = maxflips)
    f.chksums[id] += chksum
    nothing
end

function runf(f)
    factn = factorial(f.n)

    Threads.@threads for idxmin = 0:f.blocksz:factn-1
        perm = Perm(f.n)
        @inbounds first_permutation(perm, idxmin)
        idxmax = idxmin + f.blocksz - 1
        @inbounds run_task(f, perm, idxmin, idxmax)
    end
end

function fannkuchredux(n)
    f = Fannkuch(n, Threads.nthreads())

    runf(f)

    # reduce results
    chk = sum(f.chksums)
    res = maximum(f.maxflips)

    println(chk, "\nPfannkuchen(", n, ") = ", res)
end

isinteractive() || fannkuchredux(parse(Int, ARGS[1]))
