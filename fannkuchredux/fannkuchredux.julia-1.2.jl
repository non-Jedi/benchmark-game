# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

# contributed by Jarret Revels and Alex Arslan
# based on the Javascript program

function fannkuch(n)
    p = collect(Int8, 1:n)
    q = copy(p)
    s = copy(p)
    sign = 1; maxflips = chk = 0
    while true
        if p[1] != 1
            flips = 0
            copyto!(q, p)
            while q[1] != 1
                reverse!(q, 1, q[1])
                flips += 1
            end
            chk += sign*flips
            flips > maxflips && (maxflips = flips)
        end

        #permute
        if sign == 1
            p[1], p[2] = p[2], p[1]
            sign = -1
        else
            p[2], p[3] = p[3], p[2]
            sign = 1
            i = 3
            while i ≤ n && s[i] == 1
                i == n && return (chk,maxflips)
                s[i] = i
                i += 1
                insert!(p, i, popfirst!(p))
            end
            i ≤ n && (s[i] -= 1)
        end
    end
end

isinteractive() || begin
    n = parse(Int,ARGS[1])
    chk, flips = fannkuch(n)
    println("$chk\nPfannkuchen($n) = $flips")
end
