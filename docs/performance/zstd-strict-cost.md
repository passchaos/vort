# Zstd strict-cost filtering before DP insertion

The HQ parser now skips a match-edge insertion when its checked cost is
strictly greater than the final cost in the destination DP row. DP initializes
equal vacant sentinels and retains nondecreasing costs after every insertion.
Consequently, such an edge cannot improve an earlier duplicate or replace the
last node. Equal costs still enter the complete original key and tie comparison.

The dedicated `SortedContext` makes this invariant explicit. Direct contexts
with arbitrary rows keep the generic implementation. Both ordinary and cold
reuse DP use the specialization; literal transitions keep their existing path.
Admission, profile updates, symbol validation and checked node construction
precede filtering. Cross-horizon complete-search edges still update their spill
continuation. No edge price, search order, allocation, quota or wire policy changes.

## Ordinary encoding evidence

Independent executables use clean `fdcc266e` and the isolated candidate overlay,
Zig 0.16.0 LLVM ReleaseFast/Skylake, Intel i7-10700K, one encoder thread on
CPU 2. Eight process sweeps alternate AB/BA, with two alternating Vort/libzstd
rounds per process: sixteen ordinary samples per side and configuration.
Input setup, hashing, decode and diagnostic encoding stay outside the ordinary
timer. Timed calls include allocating encode and caller frame release, with
both profiles disabled.

Inputs are exact Silesia Dickens/Mozilla/MR 4/16 KiB prefixes, a trained
standard-dictionary fixture, and 4 KiB periodic/repetitive/random controls.
Requested HQ depth/nice/minimum are 64/64/3, checksums and content sizes are
enabled, and the requested windows are 15/17. The reference is the local
libzstd 1.6.0 checkout. Its requested public controls match; unspecified hash
and chain parameters retain reference level-3 defaults.

| Scope | Candidate / baseline time | Paired wins |
| --- | ---: | ---: |
| 4 KiB real-file btultra2 geomean | `0.860430` | `20/24` |
| 16 KiB real-file btultra2 geomean | `0.777708` | `24/24` |
| 4 KiB real-file btopt geomean | `0.867484` | `23/24` |
| Trained dictionary btultra2 | `0.796049` | `8/8` |
| 4 KiB synthetic btultra2 geomean | `0.966379` | `14/24` |
| 4 KiB synthetic btopt geomean | `0.854478` | `22/24` |

The strongest real-file rows are Mozilla 4 KiB at `0.689800` and MR 16 KiB
at `0.679790`. Every row preserves input, complete wire signatures, requested
settings, all diagnostic counters and requested working-memory peak.

The periodic btultra2 row regresses to `1.015668`, losing seven of eight
pairs. Its random row is near parity at `1.000237`; repetitive btultra2 improves
to `0.888359`. These observations retain a small periodic-data cost and do not
establish a gain for every input or platform.

The reference gap remains large: real-file btultra2 time is still `58.37x` /
`65.74x` libzstd at 4/16 KiB, with geometric wire-size ratios `0.985492` /
`0.995786`. The trained row remains `67.50x` slower and `1.012701x` larger.
This increment reduces state-update overhead; it does not establish industry
leadership or close the broader HQ search-design gap.

## Placement and exactness

A separate strict-cost guard inside row-tag insertion was screened first.
Although it improved larger inputs, its insertion specialization grew from
704/707 to 943/946 bytes and MR 4 KiB regressed to `1.050725`. It is archived
separately and was removed from the selected implementation. Placing the guard
in edge extension retains the original 704/707-byte insertion kernels and
avoids the call for a rejected edge.

The two focused contracts compare with the frozen edge implementation across
compact/whole layouts, widths 1/8/16, sampled/complete lengths, tagged/unindexed
paths, vacant/full cost-ordered rows, equal costs, repeated candidates, finite
quota prefixes, invalid LL symbols, accumulated-cost overflow, and spill
continuations. They pass in native Debug/ReleaseFast, actual 32-bit x86 Debug
and executed wasm32-wasi. Existing frozen DP contracts additionally exercise
empty/tiny/random/repetitive inputs, dictionaries/history, horizon boundaries,
quota prefixes and exact requested-memory admission.

The complete Zstd suites pass 1204/1204 tests in both Debug and ReleaseFast.
The independent libzstd campaign passes 41 public search groups and eight
frozen historical wire rows; the public HQ Wasm consumer also passes its
whole/complete search, quota, retry and resource contracts.
The complete build `check` / `check-wasm` and CLI help smoke exit zero.

Exact inputs, all raw exploratory/formal clocks, source overlay, binary and
reference identities, generated code, commands, validation terminals and an
independent reducer are retained in
[`data/zstd-strict-cost-20261030/`](data/zstd-strict-cost-20261030/).

Next work should reduce the remaining number of HQ states/transitions and
investigate the periodic-data overhead with broader ordinary-call evidence.
For Brotli q10/q11, the independent audit identifies bounded reuse of actual
match evidence as a stronger next candidate than retaining predecessor chains
that both passes rescan. Deflate dynamic-plan quality and streaming costs also
remain part of the active three-codec goal.
