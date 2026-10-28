# Brotli RLE statistics and repeat counting

The post-RLE complex-prefix score has a sufficient key of eighteen symbol
frequencies. This follow-up to the withdrawn complete-shape memo screens that
smaller key before adding a production cache.

For an unmodified Summary produced successfully by `summarize` or
`summarizeSparse`, the repeat counters equal frequencies 16 and 17, and the
token count equals their sum. Consequently, with fixed HSKIP=0:

```text
bits = 2 + header(L(F)) + sum(F[i] * L(F)[i]) + 2*F[16] + 3*F[17]
```

`L(F)` is the deterministic five-bit code-length Huffman tree. Repeat extras
and token order affect bytes but do not affect this count. A new writer/scorer
contract uses two valid trees with different repeat-16 extras, and one valid
tree after zero gaps of 3 and 10 with different repeat-17 extras. Each pair has
equal frequencies and scores, and different wire bytes. This key is suitable
only for scoring, not for caching encoded prefixes or diagnostic shape fields.

The sparse summary must run before lookup so local invalid metadata still
fails. Complete enumeration of nonzero lengths remains a caller invariant;
the sparse path does not scan dense gaps to detect omissions. Only successful
scores could be published. Profiling would still record actual RLE and shape
work on every call. Hand-built or modified Summary values are outside the
repeat-counter identity proof.

The diagnostic source snapshot is based on 620efa74 and records actual q8
preferred-group cluster misses across twelve Silesia files at each prefix size.
Every search starts with an empty model; modes share its state. All 36 calls
round-trip and match ordinary encoding bytes, and logged requests reconcile
with their actual profile counters. This experiment records no memo throughput
claim because no frequency memo was implemented. Trace builds print each
summary; their timing fields are diagnostic and excluded from throughput claims.

| Prefix bytes | Requests | Unbounded hits | Unbounded rate | LRU64 hits | LRU64 rate |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4,096 | 10,025 | 839 | 8.369% | 532 | 5.307% |
| 16,384 | 11,688 | 793 | 6.785% | 574 | 4.911% |
| 65,536 | 12,585 | 735 | 5.840% | 554 | 4.402% |

Including baseline and suffix calls yields 53,840 requests, 7,272 unbounded
hits (13.507%) and 5,357 LRU64 hits (9.950%). Sharing across all score scopes
has more reuse than cluster-only memoization, but its ordinary-call benefit
has not been measured. The archive preserves that broader trace for follow-up.

An unbounded model gives a reuse upper bound for these recorded requests.
Fully associative LRU is a capacity model, not a bound on other replacement
policies. With 4.4–5.3% LRU64 reuse and mandatory summarization on every request,
the frequency memo remains deferred.

The direct repeat-count experiment replaces the inverse loop with proven
maximum-run thresholds: radix 4 uses 6/22/86/342/1366 and radix 8 uses
10/74/586/4682. Larger runs retain the original recurrence. The candidate
passes both Debug and ReleaseFast comparisons for every run from 3 through
65,536 against that recurrence, an independent forward geometric oracle,
Summary, and actual unchanged wire-helper tokens. Threshold neighbors and
`usize` extremes also pass; oversized synthetic chains use the count/Summary
oracles beyond the wire helper's existing sixteen reverse-extra slots.
Correctly targeted x86-linux and actual wasm32-wasi execution also pass all
three candidate tests. Misconfigured early invocations are recorded separately
and do not count as target or optimization-mode verification.

Three alternating baseline/candidate sweeps cover the same 36 prefixes, each
with five Vort/reference rounds of three calls. All input/wire/settings
identities agree. The aggregate candidate/baseline time ratio is **0.998710**,
with 4/16/64 KiB ratios 0.997146/1.002123/0.996870. Individual sweep ratios are
0.993483/1.005394/1.000640. These observations do not establish a stable benefit,
so the threshold implementation stays in the archived candidate snapshot.
Production repeat counting remains unchanged; only the scoring contract test
is retained.

Ordinary calls use Zig 0.16.0 ReleaseFast native skylake+pku+sgx on Intel
i7-10700K, one thread pinned to CPU2, Silesia 12 files × 4/16/64 KiB, and
q8/generic/actual-lgwin16. Allocation and free are timed. Vort has an untimed
primary warmup; the reference has none explicitly. The requested reference is
the local GCC 11.4.0 Brotli 1.2.0/558fc647 build with
`-O3 -DNDEBUG -march=native`. A separate untimed loader trace confirms the
requested encoder/decoder/common files and their native dependencies; timing
runs do not enable loader tracing. Source, executable, library and dependency
identities are saved with the commands. This recorded candidate is 37.18 times
the reference time with a geometric encoded-size ratio of 0.995560; neither
ratio establishes general compressor leadership.

[Evidence](data/brotli-rle-statistics-20261028/) includes raw frequency traces,
counter reconciliation, capacity replay, ordinary rounds, source overlays,
the unchanged shared record object, exact commands, identities, and validation.
The retained writer/scorer contract passes native Debug/ReleaseFast and actual
wasm32-wasi execution (one substantive test plus nineteen import hooks per
run). The broader context selection checks pass 82/82 in Debug, and CLI help
passes its build/run smoke.
To reproduce, extract a 620efa74 snapshot for each variant, apply the archived
diagnostic/candidate source overlays, build using the recorded module commands,
and rerun the archived scripts with the same corpus and reference library
paths. The overlays are experiment inputs rather than production changes.

The next optimization should target larger measured q8 costs in planning,
candidate evaluation or context assignment. Both prefix memo screens are now
recorded; the ten-format goal remains active.
