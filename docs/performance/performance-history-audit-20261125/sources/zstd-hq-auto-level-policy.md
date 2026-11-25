# Zstd opt-in HQ level policy

Date: 2026-11-10. This is a functional increment with local size evidence;
the overall Deflate/Zstd/Brotli leadership goal remains open.

## Problem and behavior

The legacy auto level policy does not select Vort's implemented HQ parsers.
Callers previously needed an explicit parser strategy
to obtain the higher quality behavior.

`FrameOptions.hq_auto` enables a documented Vort level policy:

| Requested level | Automatically selected strategy |
| --- | --- |
| Below 9, including zero and negative levels | Existing level policy |
| 9-15 | `btopt` |
| 16-18 | `btultra` |
| 19-22 | `btultra2` |

HQ effort defaults come from `resolvedHqDefaults(strategy, level)`. Explicit
`strategy`, `hq`, `fast_acceleration` and `fast_long_matches` take precedence.
Invalid combinations remain errors: `hq` without an explicit HQ strategy is
still invalid, and explicit fast acceleration with an HQ strategy is rejected.
The flag defaults to false; frozen default wires remain covered by the existing
all-level and HQ compatibility contracts.

This policy is independent of `resolveCanonicalCompressionParameters`, whose
versioned libzstd table also depends on source/dictionary size and has different
strategy and effort schedules. `hq_auto` makes no canonical preset claim.

One-shot, append, into, reusable level encoders, dictionary and dictionary-set
entry points use the same level resolver. Incremental, ordinary parallel and
seekable APIs take `NativeFrameOptions`; resolve once and pass the result:

```zig
const native = try zstd.resolveFrameOptionsForLevel(19, .{
    .hq_auto = true,
    .window_log = 17,
    .max_total_working_memory = 64 * 1024 * 1024,
});
// Pass native to the existing NativeIncrementalFrameEncoder or native
// one-shot/parallel/seekable entry point.
```

Whole-operation heap limits remain effective. Limit failures propagate as
`WorkingMemoryLimitExceeded`; failed into/append publication preserves caller
output. HQ settings and explicit search caps are retained by the resolver.
After resolving, callers can narrow `native.hq.?.max_working_memory` or the
existing search/price caps before constructing a native context.

The benchmark exposes `--hq-auto`, records actual HQ profile counters outside
timed work, and selects its execution path from the resolved strategy. Enabling
the flag below level 9 therefore retains the public level policy instead of
bypassing adaptive candidate selection. Explicit fast controls also retain
their original paths and exact wires.

## Recorded snapshot evidence

The matrix below uses the 95-state auto policy at the recorded source snapshot.
That default shortcut has since been rejected because it changes a frozen CHD
hunk wire; the production resolver again uses legacy budgets 96/128/96.
The HQ strategies and their level-derived effort remain unchanged. These
relative legacy/HQ numbers are snapshot evidence, not current-default rankings.

The [evidence package](data/zstd-hq-auto-level-policy-20261110/results/summary.json)
contains 48 bidirectional reference rows: twelve Silesia 64 KiB prefixes,
levels 9/19, legacy/HQ policies, one iteration and three alternating
Vort/reference rounds per row. The reference is the local libzstd 1.6.0 build.
Every Vort wire is decoded by libzstd, and every reference wire by Vort, before
measurement. Schema/CSV/raw-round validation also passes for every row.

The source snapshot is base `084cb361bc0f80e57a6f4722d5642540bbef13b2` plus the
archived `source-overlay.patch.xz` and file hashes in `source.json`. The ReleaseFast
benchmark SHA-256 is
`8cc045a12de79c2aba59fca53bf4755a798a73438accd09771091442b4a07f9d`.
Reports record the reference hash/version, input and wire hashes, API/settings,
CPU (Intel Core i7-10700K), target/features (`x86_64-linux-gnu`,
`skylake+pku+sgx`), Zig 0.16.0, affinity, thread policy and complete commands.

The operation is allocating one-shot encoding: Vort's public level policy or
resolved native HQ path versus `ZSTD_compress`. These are level-preset
comparisons, not identical parser/index parameter comparisons. The benchmark
reports one benchmark thread and `internal-auto` codec policy; it runs on the
development host without isolated affinity or a dedicated-host acceptance gate.
No requested-heap/RSS/stack measurement or performance leadership is claimed.

### Level 9

| Source | Legacy bytes | HQ bytes | HQ change | libzstd 1.6.0 bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 25,898 | 25,463 | -1.68% | 25,800 |
| mozilla | 17,118 | 13,839 | -19.16% | 14,861 |
| mr | 16,806 | 16,401 | -2.41% | 16,739 |
| nci | 4,728 | 4,082 | -13.66% | 4,286 |
| ooffice | 32,276 | 30,812 | -4.54% | 32,050 |
| osdb | 26,901 | 26,508 | -1.46% | 26,566 |
| reymont | 18,720 | 17,685 | -5.53% | 18,475 |
| samba | 22,048 | 21,591 | -2.07% | 21,917 |
| sao | 49,140 | 48,582 | -1.14% | 49,286 |
| webster | 22,669 | 22,221 | -1.98% | 22,646 |
| x-ray | 50,370 | 47,405 | -5.89% | 50,184 |
| xml | 5,078 | 4,611 | -9.20% | 4,786 |

HQ is smaller than legacy on all twelve rows; the geometric size ratio is
`0.941108` (5.89% reduction). All twelve outputs are also smaller than the
reference level-9 outputs in this bounded prefix matrix.

### Level 19

| Source | Legacy bytes | HQ bytes | HQ change | libzstd 1.6.0 bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 25,898 | 25,199 | -2.70% | 24,902 |
| mozilla | 17,118 | 13,431 | -21.54% | 13,347 |
| mr | 16,806 | 16,002 | -4.78% | 15,696 |
| nci | 4,728 | 3,891 | -17.70% | 3,884 |
| ooffice | 32,276 | 30,391 | -5.84% | 30,095 |
| osdb | 26,901 | 26,522 | -1.41% | 26,376 |
| reymont | 18,720 | 17,541 | -6.30% | 17,263 |
| samba | 22,048 | 21,435 | -2.78% | 21,205 |
| sao | 49,140 | 48,087 | -2.14% | 48,074 |
| webster | 22,669 | 22,101 | -2.51% | 21,905 |
| x-ray | 50,370 | 44,746 | -11.17% | 44,094 |
| xml | 5,078 | 4,471 | -11.95% | 4,473 |

HQ is smaller than legacy on all twelve rows; the geometric size ratio is
`0.922030` (7.80% reduction). Reference level 19 remains smaller on eleven
rows; XML is 4,471 versus 4,473 bytes. Local median time improves on eight
level-9 rows and three level-19 rows, and worsens elsewhere. Raw times remain
in the package as trend evidence. Choosing a deeper parser does not promise
a per-input size or throughput improvement.

## Reproduction and validation

Build the benchmark through `zig build run-zstd-encode-bench -- --help`, then
pass its emitted executable and the corpus/reference paths to:

```sh
python3 docs/performance/data/zstd-hq-auto-level-policy-20261110/run.py \
  --executable /path/to/vort-zstd-encode-bench \
  --corpus /path/to/silesia/files \
  --library /path/to/libzstd.so \
  --output /tmp/new-hq-level-policy-results
```

The output includes compressed frozen input prefixes, original corpus hashes,
source overlay, raw reports, CSVs, logs, commands, summary and `SHA256SUMS`.
`--summarize-only` verifies archived input hashes and recovers the summary
without re-running completed measurements.

Seven new `Zstd HQ level policy` public contracts cover all mapped levels,
explicit-control precedence, seven input families, exact explicit-HQ wires,
reusable/append/into/incremental behavior, cross-block history, raw/full
dictionaries, seekable serial/parallel equality, ordinary parallel fallback,
invalid levels and transactional heap refusal/retry. They pass in native
Debug, x86-linux ReleaseSafe and actual wasm32-wasi ReleaseSafe execution
(32/32 test-runner entries on each target).

`zig build test-zstd-hq-auto-bench` checks fourteen positive CLI cases and ten
rejected invocations, including preserving existing CSV/JSON and not creating
new output on invalid requests. It passes with local libzstd 1.6.0 and the
system libzstd. This gate checks behavior and evidence schemas, not speed.

The full repository gate is recorded in the final handoff after a terminal
result is captured. Full-file, dictionary, streaming, memory and AArch64
performance matrices remain future work.
