# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

# contributed by Jarret Revels and Alex Arslan
# based on the Javascript program

function perf_fannkuch(n)
    p = Vector{Int32}(undef, n)
    for i = 1:n
        p[i] = i
    end
    q = copy(p)
    s = copy(p)
    sign = 1; maxflips = chk = 0
    while true
        q0 = p[1]
        if q0 != 1
            for i=2:n
                q[i] = p[i]
            end
            flips = 1
            while true
                qq = q[q0] #??
                if qq == 1
                    chk += sign*flips
                    flips > maxflips && (maxflips = flips)
                    break
                end
                q[q0] = q0
                if q0 >= 4
                    i = 2; j = q0-1
                    while i < j
                        q[i], q[j] = q[j], q[i]
                        i += 1
                        j -= 1
                    end
                end
                q0 = qq
                flips += 1
            end
        end
        #permute
        if sign == 1
            p[1], p[2] = p[2], p[1]
            sign = -1
        else
            p[2], p[3] = p[3], p[2]
            sign = 1
            for i = 3:n
                if s[i] != 1
                    s[i] -= 1
                    break
                end
                i == n && return [chk,maxflips]
                s[i] = i
                rot!(p, i)
            end
        end
    end
end

# Moves first i+1 characters left 1 element
function rot!(v, i)
    t = first(v)
    for j=1:i
        v[j] = v[j+1]
    end
    v[i+1] = t
end

isinteractive() || begin
    n = parse(Int,ARGS[1])
    pf = perf_fannkuch(n)
    println(pf[1])
    println("Pfannkuchen(", n, ") = ", pf[2])
end
