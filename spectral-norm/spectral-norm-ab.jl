using Printf

getA(i, j) = 1.0 / ((((i+j) * (i+j+1)) / 2) + i + 1)
getAt(i, j) = getA(j, i)

function A_times_u!(dest, u, A)
    n = length(u)
    @inbounds Threads.@threads for i in 1:n
        sum1 = 0.0
        j = 1
        while j < n
            sum1 += sum((u[j], u[j+1]) .* (A(i-1, j-1), A(i-1, j)))
#            sum1 = muladd(u[j], A(i-1, j-1), sum1)
            j += 2
        end#while
        dest[i] = sum1
    end#for
end#function

function specnorm(n)
    u = ones(Float64, n)
    v = zeros(Float64, n)
    tmp = Vector{Float64}(undef, n)

    for i in 1:10
        A_times_u!(tmp, u, getA)
        A_times_u!(v, tmp, getAt)
        A_times_u!(tmp, v, getA)
        A_times_u!(u, tmp, getAt)
    end#for

    uv = vv = 0.0
    @inbounds for i in 1:n
        uv = muladd(u[i], v[i], uv)
        vv = muladd(v[i], v[i], vv)
    end#for
    √(uv / vv)
end#function

isinteractive() || @printf("%.9f\n", specnorm(parse(Int, ARGS[1])))
