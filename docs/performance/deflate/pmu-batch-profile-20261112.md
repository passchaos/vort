# Deflate Vort-batch PMU diagnosis, 2026-11-12

The owner-only regressions are associated with more user cycles and branch
misses, while retired instructions stay close to baseline. Bounded precise
branch-miss IP samples concentrate the added observations in the ordinary
sixteen-byte copy loop. The complete scalar entry has also changed codegen;
this is not a preparation-only control and does not establish a root cause.
Neither owner prototype is adopted.

The benchmark now accepts `--perf-group branches|branch-misses`. Each option
opens a three-event Linux group containing cycles, instructions and the named
third event. The group counts only the calling thread's Vort public-decode
batch, including loop/count/mix bookkeeping and userspace enable/disable
boundary work. Poisoning, clocks, reference decoding, full validation,
provenance and JSON/file I/O are outside the counter interval.

The tool retains all nine raw kernel words, three event IDs and unscaled
semantic values. IDs bind values to events independently of read ordering.
It rejects short/extra reads, incorrect event counts, invalid/duplicate IDs,
zero core/time values and incomplete running time. A third event may be zero.
Enabled/running headers remain cumulative over the FD lifetime; RESET clears
counts only. A failed read retains its actual bytes for stderr diagnostics,
and failure cleanup closes every opened descriptor. Each new batch clears
old diagnostics before attempting activation.

PMU wall times include Vort reset/enable/disable overhead while the reference
has none. Raw reports and the final matrix summary/CSV label these times as
diagnostic, with throughput-gate use disabled. Ordinary runs keep counters
off. General CI tests parsing and metadata; hardware use is optional and
permission/scheduling failures return explicit errors.

## Matched diagnosis cohort

The three new executables share the same ten frozen tool/build files. Library
baseline source is `485ca30f` (the preceding documentation correction changes
no codec code), and owner production overlays reuse their previously frozen
bytes. This is a new instrumented-probe epoch, with its own source, executable
and sample identities; it does not inherit earlier timing or code-layout
evidence.

Four conditions are reymont64K/L6, nci64K/L9, XML64K/L6 and nci1M/L9. Every
condition runs four balanced forward/reverse variant sweeps in three separate
modes: ordinary wall time, branches group and branch-misses group. All 144
child events retain two measured and two warmup Vort/reference batches. The
96 PMU children supply 192 measured counter batches and 192 warmup counter
batches; the 48 ordinary children remain separate controls. Iterations are
500 at 64 KiB and 100 at 1 MiB.

The following ratios are candidate / baseline, geometric means of four
paired child medians in the branch-misses group. Lower is less work/time.
All raw observations, paired ratios and balanced process-order bootstrap
intervals are retained rather than selected minima.

| Owner-only condition | User cycles | Instructions | Branch misses | Ordinary wall time |
| --- | ---: | ---: | ---: | ---: |
| reymont64K L6 | 0.979707x | 1.000568x | 0.935225x | 0.991406x |
| nci64K L9 | 1.101504x | 0.991871x | 1.738043x | 1.098603x |
| XML64K L6 | 1.092142x | 1.000266x | 1.494908x | 1.086027x |
| nci1M L9 | 1.008290x | 0.999925x | 0.999887x | 1.011375x |

Owner + word increases instructions to 1.048541x on reymont64K,
1.020424x on nci64K and 1.023743x on XML64K. Its corresponding cycle ratios
are 0.996255x, 0.976469x and 1.006036x. These measurements separate work and
stalls as hypotheses; they do not establish an accepted speedup or refresh
the complete modern-reference ranking.

The host is Intel i7-10700K, CPU15, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, one codec/benchmark thread. The exact
libdeflate 1.26 library and closure remain pinned; wires are the original
Python zlib 1.2.11 raw L6/L9 fixtures. Before/after child observations contain
no compiler processes. This remains a development-host diagnosis, not a
dedicated-host acceptance result.

## Bounded physical branch observations

Four additional recordings use `branch-misses:upp`, fixed period 1000, one
recording for each nci/XML baseline/owner-only pair. Each process performs
2000 known Vort API calls. All 9512 sample records have the exact-IP flag and
user mode, with no recorded lost-event marker. FP callgraphs are retained
without a complete-unwind claim. Profiled wall times are not performance
evidence.

Only explicitly named native Vort code IP domains are interpreted, and their
period weights are divided by known Vort calls. Foreign-library/startup/I/O
samples are not a public-decoder denominator. The raw caller domain includes
parsing, preparation, dispatch and other routes; it is not preparation-only.
`compare.decodeOnce__anon_5293` is a Zstd instance and is excluded.

| Copy-loop cmp/jbe sampled period weight per Vort call | Baseline | Owner-only |
| --- | ---: | ---: |
| nci64K L9 | 58.5 | 388.0 |
| XML64K L6 | 104.0 | 472.0 |

These are noisy sampled-IP estimators, not exact per-branch counters. The
26-byte inner loop body is identical at baseline `[0x1145a00,0x1145a1a)` and
owner-only `[0x11466a0,0x11466ba)`, SHA-256 `dc84e824...`. Surrounding control
flow, register allocation, instruction addresses and branch history differ.
The concentration is useful for locating the next experiment but cannot prove
which change causes the miss increase.

The whole scalar aligned symbol is 3659 / 3649 bytes, with local stack
reservation 296 / 312 bytes and 897 / 902 static instruction lines including
padding. Literal-to-match branch merging, cursor spill shapes and a restaged
length-buffer spill differ. These are real codegen changes, not relocation
alone; static stack references are not dynamic spill counts. The full raw
caller grows from 33038 to 39054 bytes and contains all routes.

## Validation and source versions

Unified validation passes 13/13 pure Zig tests (eight sampling contracts and
five PMU read/metadata contracts), plus the final 9/9 Python evidence tests.
All three ReleaseFast comparator builds succeed. Both hardware groups pass
complete validation on a frozen Deflate case. Six further smoke events cover
Zstd cold/prepared and Brotli cold in both groups, including complete output,
guards, input immutability and the codec's declared consumption scope.
Every pilot counter read passes exact raw/ID/semantic binding, full running
time and strictly increasing cumulative headers.

The final matrix summary/CSV diagnostic-label correction follows the
original measurement epoch. `common-source` retains the original ten files;
`final-tool-source` records the later Python-only output/test correction.
It does not silently change the archived compiled or measured source.

The [evidence packet](pmu-batch-profile-20261112/README.md) retains the three
executables, source overlays, raw counter observations, profiler data and
exactness checks, derived summaries and offline verification. Next isolate
owner preparation while retaining the original scalar implementation, then
recheck actual codegen before attributing a regression or proposing a
production change.
