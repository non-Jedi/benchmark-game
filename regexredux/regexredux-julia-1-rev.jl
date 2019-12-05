# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# contributed by Daniel Jones
# fixed by David Campbell
# modified by Jarret Revels, Alex Arslan, Yichao Yu
# made (slightly) multi-threaded by Adam Beckmeyer

const variants = (
      "agggtaaa|tttaccct",
      "[cgt]gggtaaa|tttaccc[acg]",
      "a[act]ggtaaa|tttacc[agt]t",
      "ag[act]gtaaa|tttac[agt]ct",
      "agg[act]taaa|ttta[agt]cct",
      "aggg[acg]aaa|ttt[cgt]ccct",
      "agggt[cgt]aa|tt[acg]accct",
      "agggta[cgt]a|t[acg]taccct",
      "agggtaa[cgt]|[acg]ttaccct"
)

const subs = (
    (r"tHa[Nt]", "<4>"),
    (r"aND|caN|Ha[DS]|WaS", "<3>"),
    (r"a[NSt]|BY", "<2>"),
    (r"<[^>]*>", "|"),
    (r"\|[^|][^|]*\|", "-")
)

function perf_regex_dna(io)
    seq = read(stdin, String)
    l1 = length(seq)

    seq = replace(seq, r">.*\n|\n" => "")
    l2 = length(seq)

    variant_counts = zeros(Int64, length(variants))
    @inbounds Threads.@threads for i in 1:length(variants)
        variant_counts[i] = length(collect(eachmatch(Regex(variants[i]), seq)))
    end
    for (v, k) in zip(variants, variant_counts)
        write(io, v, ' ', string(k), '\n')
    end#for

    for (u, v) in subs
        seq = replace(seq, u => v)
    end

    write(io, '\n', string(l1), '\n', string(l2), '\n', string(length(seq)), '\n')
end

perf_regex_dna(stdout)
