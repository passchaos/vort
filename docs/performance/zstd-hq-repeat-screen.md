# Zstd HQ repeat-key and short-tail screens

Two isolated prototypes were screened against
`26d9eb062da7dedded4aa1e3b639d76a53192d4f`, which already contains the ML tail
stop and candidate-held insertion shift. Neither experimental change entered
production. The evidence describes these code shapes and input distributions;
it does not reject the general algorithms or claim a general throughput gain.
The ten-format product goal remains active.

The [package](data/zstd-hq-repeat-screen-20261028/index.json) shares one compressed
snapshot of 1506 `src` and build files. Docs, the large temporary full-tree archive,
compiler caches and ELF binaries are excluded. Exact binary identities,
ordinary compile/run commands, raw results, actual input bytes, source diffs,
contract sources and available disassembly are retained. These timing screens
did not collect perf periods; none are synthesized in the archive.

Both screens freshly compiled ordinary baseline/candidate runners with Zig
0.16.0 LLVM ReleaseFast `skylake`, without forced frame pointers. Two CPU 2
AB/BA rounds cover Dickens, Mozilla and MR 4 KiB prefixes with explicit
btopt/btultra2, window log 15, block ceiling 32768 and checksums enabled.
Input preparation, caller release of the returned frame, decoding, hashing and
the subsequent diagnostic encode are outside the ordinary-call timer. The
epochs remain separate.

| 4 KiB input | Strategy | XOR source/baseline | Short 8-byte tail/baseline |
| --- | --- | ---: | ---: |
| Dickens | btopt | 0.974693 | 0.967959 |
| Dickens | btultra2 | 0.942836 | **1.016867** |
| Mozilla | btopt | 0.957478 | 0.997388 |
| Mozilla | btultra2 | 0.958554 | **1.027156** |
| MR | btopt | 0.964077 | 1.008020 |
| MR | btultra2 | **1.000548** | **1.017506** |

Each entry is exactly `median(candidate_ns) / median(baseline_ns)`, not the
median of paired ratios. Full wires and complete profiles agree across both
variants and both rounds in each screen: 24 ordinary encodes and 48 original
native decodes per screen, 48/96 in total. These are two-round exploratory
results on small real prefixes, without a significance or platform-wide claim.

The [XOR diff](data/zstd-hq-repeat-screen-20261028/xor.diff.xz) replaces the three
short-circuit `usize` equalities in `state.insert` with OR of three XOR values
equal to zero. The finite-cost and literal guards still precede the expression;
duplicate search, `less`, shift, budgets and allocator behavior are unchanged.
LLVM folded the expression back into conditional comparisons and reordered
repeat words from 0→1→2 to 2→1→0. No branchless XOR reduction or SIMD comparison
remained. The insertion functions change from 535/551 to 536/552 bytes.

Five XOR configurations improve in both rounds. MR btultra2 is **0.979260 /
1.021834**, near parity and mixed, so this screen was not adopted under its
mixed-result criterion. The unmodified frozen key and shift oracles passed
native Debug, native ReleaseFast and actual x86 Linux Debug. The local harness
reports 3/3: two existing registrations plus a wrapper invoking both oracles.
The key contract contains 12,288 randomized insertion operations per invocation,
and shift contracts cover arbitrary rows, sentinels and row-element aliases.

The [short-tail diff](data/zstd-hq-repeat-screen-20261028/short-tail.diff.xz) adds an
8-byte little-endian XOR/`ctz` loop after the unchanged 32-byte vector loop in
`resources.matchLength`. It is bounded by the current contiguous virtual span;
the scalar remainder still follows it. For a mismatch it charges
`mismatch + 1` to `byte_comparisons`; equal words charge 8. This deliberately
preserves the old **logical scalar-tail count**, not physical bytes read by the
wider comparison. Full profile equality therefore does not assert equal physical
memory work.

Short-tail btopt is favorable on Dickens and otherwise near parity or mixed.
All three btultra2 configurations regress in both rounds, so this code shape is
a negative screen and remains out of production. Its frozen reference is the
complete unchanged baseline `resources.zig`. The retained alignment, mismatch,
segmentation, bounds, null-profile and saturation contract has **2,539,064
source-derived `check` calls**; this count is derived from its loops, not a
recorded runtime counter. The parent reports Debug and ReleaseFast 3/3 exits.
Original full compiler/test terminal logs and actual test commands were not
retained locally; `parent-terminal-observations.json` records the supplied chunk
identifiers and exits explicitly, without inventing missing logs. Ordinary
compiler commands and binary hashes are present. The short temporary source
also omitted build files, which were not used by its direct module compilation;
the shared build snapshot is bound to Git instead.

The independent [audit](data/zstd-hq-repeat-screen-20261028/audit.py) checks all
four archive/member hashes, baseline Git blob identities, the sole change in
each candidate, frozen references, complete wire/profile pairs and exact rational
timing ratios. Its optional reference pass successfully decoded all 48 ordinary
wires with local libzstd 1.6.0, recorded the library SHA-256, and compared each
decoded byte with the frozen input. This is an untimed correctness check.

A third, separate [Vector3 epoch](data/zstd-hq-repeat-screen-20261028/vector-index.json)
constructs exact `@Vector(3, usize)` values from the repeat arrays and reduces
lane equality with `.And`, after the same finite-cost/literal guards. LLVM
retains AVX2 `vpcmpeqq` and an odd-width boolean reduction. The memory loads
read exactly 16 plus 8 bytes; no padding or fourth repeat is accessed. The two
insertion specializations grow from 535/551 to 706/722 bytes.

| Vector3 4 KiB input | btopt ratio | btultra2 ratio |
| --- | ---: | ---: |
| Dickens | 1.023954 | 1.040143 |
| Mozilla | **1.253670** | **1.353162** |
| MR | 1.050270 | 1.080376 |

All six Vector3 configurations regress in both AB/BA rounds, so this prototype
was not adopted. These results do not replace the five favorable XOR rows or
merge their timing epochs. Vector3's native Debug, ReleaseFast and actual x86
Debug frozen key/shift contracts each pass 3/3; all 24 ordinary encodes and 48
original native decodes preserve complete wire/profile equality. The separate
`vector-audit.py` verifies the source-only vector expression, member hashes,
ratios, contracts, actual SIMD disassembly and all 24 wires with libzstd 1.6.0.
It also checks that the six original index/manifest/archive identities remain
unchanged. Its archive, manifest and reference report use independent `vector-*`
names; compiled runners and caches remain excluded.

```sh
python3 docs/performance/data/zstd-hq-repeat-screen-20261028/audit.py
python3 docs/performance/data/zstd-hq-repeat-screen-20261028/audit.py \
  --libzstd /home/passchaos/Work/zstd/lib/libzstd.so.1.6.0
python3 docs/performance/data/zstd-hq-repeat-screen-20261028/vector-audit.py
```

Raw paired times, complete profiles, background observations and identities are
preserved separately for each experiment. No additional timing round, combined
prototype or production change was introduced while archiving these results.
