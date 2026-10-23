# Zstd signed levels and strategy functional baseline

Date: 2026-10-24. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.
Source and tools revision: `4f6d5b97`. This records functional behavior,
interoperability, parameter effects and validation. It does not establish
libzstd quality/throughput parity or broad industry-best performance.

## Implemented controls

Compression levels now accept `-131072...22`. Default and level 0...22 automatic
encoding retain their old dispatch and wire selection. Negative magnitude
selects real fast acceleration. Explicit single-hash fast, double-fast,
greedy, lazy and bounded optimal matchers use the permitted dictionary suffix
and completed frame history; records retain wide distances. Optimal uses a
fixed symbol-cost model and four states over blocks capped at 32 KiB, with
normal larger input split by the same helper used by frame bounds and streaming.

The public resolver is shared by allocating/caller-buffer/append/reusable,
dictionary/dictionary-set, incremental and seekable encoding. Conflicting
selection, acceleration and unsupported legacy repeat-beam combinations fail
before output; explicit raw/RLE and literal-only subset APIs reject matcher
controls. Empty input remains valid with explicit windows and content sizes.

Caller-owned profiles count actual search work separately from committed
wire blocks and dictionary/history references. Rejected candidates retain
performed work but cannot report emitted references. Complete-call failures
restore emission counters. Saturating private seekable worker profiles merge
in frame order and agree with serial output/statistics. Legacy automatic paths
have explicit instrumentation-availability indicators.

CHD compression hints are signed; explicit Zstd accepts core negative levels,
while other backends retain their own validated domains. OpenZFS supports all
21 representable FAST levels without changing the unsigned metadata layout:
`-1...-10 -> 103...112`, `-20...-100` in tens `-> 113...121`, `-500 -> 122`,
and `-1000 -> 123`. Fixed-tag upstream sources and hashes are in the
[consumer evidence](data/zstd-fast-consumers-x86-20261024.json).

The [API contract](../formats/zstd-encode-controls.md) describes control
validation, profile lifetime, parser limits and CLI flags.

## Validation

| Gate | Result |
| --- | ---: |
| Complete Zstd family, ReleaseFast | 798/798 |
| Control/matcher/resource aggregate, Debug and ReleaseFast | 34/34 each |
| CHD/ZFS control consumer aggregate, ReleaseFast | 71/71 |
| Complete CHD family, ReleaseFast | 84/84 |
| ZFS compression family, ReleaseFast | 159/159 |
| Final build check, including wasm32-wasi | 137/137 steps |
| Final Debug CLI | 117 checks |
| Final small benchmark surface | 6 rows and 24 invalid CSV checks |

The combined ReleaseFast test command passes 1146 executions. Independent
kernel oracles compare virtual-source matching, overlap, repeated offsets,
sampling, search budgets, tiny exhaustive optimal costs, wide distances and
allocation failures. Public regressions cover output/bound contracts, OOM
cleanup and caller preservation, failed emission rollback, empty streams,
header/check/window settings, dictionary recovery surfaces and serial/parallel
profiles.

The [independent ReleaseFast report](data/zstd-encode-controls-x86-20261024.json)
passes **431 cases**. Its 217 frozen legacy outputs match revision `2cd7e82c`
byte-for-byte. System libzstd 1.4.8 independently decodes all Vort outputs,
including seekable component frames; 15 reverse cases also pass.
Twenty history-reference and sixty direct/set dictionary cases across five
strategies and four public API forms emit real references. Five tiny
dictionary candidates fall back to raw: parser match counts remain one while
emitted references and max distance are zero. Raw dictionary-set references
use a validated matching-ID entropy-header wrapper with repcodes 1/4/8 and
the same raw history; the Vort wire is not rewritten.

Parameter effects are measured as deterministic work/output evidence:

| Locked observation | Result |
| --- | --- |
| Fast acceleration 1 to 16 | Positions tested 4032 to 960 |
| Double-fast workload | 4032 long-hash probes |
| Level -1 versus -13, fixed input | 61 versus 358 encoded bytes |

These observations show that parameters are consumed. They are not a general
speed/ratio ranking or equivalence with identically named libzstd controls.

The [CLI report](data/zstd-controls-cli-x86-20261024.json) verifies 20 historical
wire/stdout cases, 48 new control combinations, 44 output-file preservation
errors and five empty/binary boundary cases. The
[benchmark-surface report](data/zstd-controls-bench-x86-20261024.json) preserves
the original CSV column schema and prevents invalid parameters from changing
an existing CSV or creating a new one. Each valid row used one iteration and
one round; these are API smoke observations.

Consumer interoperability passes all 21 OpenZFS FAST levels in both directions
and seven CHD compressed-hunk checks against system Zstd 1.4.8. Default CHD
and ZFS outputs retain their historical hashes. The reports bind 75 core/tool,
13 CLI and ten benchmark source hashes, plus probe/object/reference artifacts;
integration records verify these against the source/tools revision.

```sh
zig build test-zstd test-zstd-encode-controls -Doptimize=ReleaseFast
zig build test-zstd-encode-controls
zig build test-zstd-control-consumers test-chd test-zfs-compression -Doptimize=ReleaseFast
zig build run-zstd-controls-diff -Doptimize=ReleaseFast -- --report /tmp/zstd-controls.json
zig build check --summary all
```

The separate [profile-tool compile improvement](deflate-profile-runtime-inputs.md)
removes 459008 compile-time sample assignments while preserving all CSV
deterministic fields. It improves development tooling rather than codec
throughput. Remaining function priorities include complete FastCover training
and richer encoder presets/HQ strategy models, followed by current-source
real-corpus speed/ratio/memory comparisons across platforms.
