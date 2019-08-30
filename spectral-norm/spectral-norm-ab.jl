using Printf

A(i, j) = inv((((i+j)*(i+j+1)) >> 1) + i + 1)
At(i, j) = A(j, i)

function A_times_u!(dest, u, f)
    n = length(u)
    @inbounds Threads.@threads for i in 0:n-1
        sum1 = 0.0
        @simd for j in 1:n
            sum1 += u[j] * f(i, j-1)
        end#for
        dest[i+1] = sum1
    end#for
end#function

function specnorm(n)
    u = ones(Float64, n)
    v = zeros(Float64, n)
    tmp = Vector{Float64}(undef, n)

    for _ in 1:10
        A_times_u!(tmp, u, A)
        A_times_u!(v, tmp, At)
        A_times_u!(tmp, v, A)
        A_times_u!(u, tmp, At)
    end#for

    uv = vv = 0.0
    @inbounds for i in 1:n
        uv = muladd(u[i], v[i], uv)
        vv = muladd(v[i], v[i], vv)
    end#for
    √(uv / vv)
end#function

isinteractive() || @printf("%.9f\n", specnorm(parse(Int, ARGS[1])))
