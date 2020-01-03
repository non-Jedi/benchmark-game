# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

# based on Oleg Mazurov's Java Implementation and Jeremy Zerfas' C implementation
# transliterated and modified by Hamza Yusuf Çakır

import Base: @propagate_inbounds

const NUM_BLOCKS = 24

struct Fannkuch
    n::Int64
    blocksz::Int64
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

    first = p[1] + 1

    if p[first] != 0

        unsafe_copyto!(pp, 2, p, 2, length(p) - 1)

        while true
            flips += 1
            new_first = pp[first] + 1
            pp[first] = first - 1

            if first > 3
                lo = 2; hi = first - 1
                # see the note in Jeremy Zerfas' C implementation for
                # this loop
                for k = 0:13
                    pp[lo], pp[hi] = pp[hi], pp[lo]
                    (hi < lo + 3) && break
                    lo += 1
                    hi -= 1
                end
            end

            first = new_first
            pp[first] == 0 && break
        end
    end

    return flips
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
