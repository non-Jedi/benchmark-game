const MPZ = Base.GMP.MPZ
const mpz_t = MPZ.mpz_t
addmul!(x::BigInt, a::BigInt, b::UInt64) =
    ccall((:__gmpz_addmul_ui, :libgmp), Cvoid, (mpz_t, mpz_t, UInt64), x, a, b)
submul!(x::BigInt, a::BigInt, b::UInt64) =
    ccall((:__gmpz_submul_ui, :libgmp), Cvoid, (mpz_t, mpz_t, UInt64), x, a, b)
get_ui(x::BigInt) = ccall((:__gmpz_get_ui, :libgmp), Culong, (mpz_t,), x)

function gen_digits!(v)
    numer = big(1)
    denom = big(1)
    accum = big(0)
    tmp = big(1)
    i = 1
    k = one(UInt64)
    while i ≤ length(v)
        next_term!(k, numer, denom, accum)
        k += 1
        if numer ≤ accum
            d = extract_digit(UInt64(3), numer, denom, accum, tmp)
            if d == extract_digit(UInt64(4), numer, denom, accum, tmp)
                @inbounds v[i] = d + 48
                eliminate_digit!(d, numer, denom, accum)
                i += 1
            end#if
        end#if
    end#while
    v
end#function

function next_term!(k, numer, denom, accum)
    k2 = 2k + 1

    addmul!(accum, numer, UInt64(2))
    MPZ.mul_ui!(accum, accum, k2)
    MPZ.mul_ui!(denom, denom, k2)
    MPZ.mul_ui!(numer, numer, k)
end#function

function extract_digit(n, numer, denom, accum, tmp)::UInt64
    MPZ.mul_ui!(tmp, numer, n)
    MPZ.add!(tmp, tmp, accum)
    MPZ.tdiv_q!(tmp, tmp, denom)
    get_ui(tmp)
end#function

function eliminate_digit!(d, numer, denom, accum)
    submul!(accum, denom, d)
    MPZ.mul_ui!(accum, accum, 10)
    MPZ.mul_ui!(numer, numer, 10)
end#function

function main(io, n)
    # Make sure we don't create an empty vector
    n = max(1, n)
    v = Vector{UInt64}(undef, n)
    gen_digits!(v)
    v8 = convert(Vector{UInt8}, v)
    i = 10
    while i <= n
        @inbounds write(io, v8[i - 9:i], "\t:$i\n")
        i += 10
    end#while
    if n % 10 !== 0
        filler = fill(' ' % UInt8, 10 - n % 10)
        @inbounds write(io, v8[i - 9:end], filler, "\t$i\n")
    end#if
    nothing
end#function

main(stdout, parse(Int, ARGS[1]))
