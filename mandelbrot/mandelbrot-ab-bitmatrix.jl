const ITERATIONS = 50
#const N = parse(Int, ARGS[1])
const MINX = -1.5
const MAXX = 0.5
const MINY = -1.0
const MAXY = 1.0

function in_mandelbrot(a::Float64, b::Float64)::Bool
    c = z = Complex(a, b)
    for i in 1:ITERATIONS
        if abs2(z) > 4
            return false
        end#if
        z = z^2 + c
    end#for
    true
end#function

function main()
    padding = let r = N % 8
        r === 0 ? 0 : 8 - r
    end#let
    set = falses(N+padding, N)
    a = range(MINX, MAXX; length=N)
    b = range(MINY, MAXY; length=N)
    for (j, bv) in enumerate(b)
        for (i, av) in enumerate(a)
            set[i,j] = in_mandelbrot(av, bv)
        end#for
    end#for
    write(stdout, "P4\n$N $N\n")
    write(stdout, set)
end#function

#main()
