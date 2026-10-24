# Zstd HQ strategy functionality

Date: 2026-10-24. Source and tools revision: `c526c1f0`.

The explicit strategy API now includes lazy2, btlazy2, btopt, btultra and
btultra2 alongside the original auto/fast/double-fast/greedy/lazy/optimal
policies. The [HQ contract](../formats/zstd-hq-strategies.md) describes options,
costs and ownership. This milestone adds real engines and their public/streaming
propagation; it does not establish libzstd algorithm, output, ratio or throughput
equivalence.

## Final evidence

| Gate | Result | Evidence scope |
| --- | ---: | --- |
| Debug / ReleaseFast HQ contracts | 78/78 each | 68 named tests and ten import roots; API, model, matching and transaction coverage |
| Full Zstd and consumers, ReleaseFast | 1300/1300 | Zstd 907, prior controls 44, control consumers 83, CHD 96 and OpenZFS 170 |
| CLI | 898 round-trips, 728 legacy-wire comparisons, 85 profile comparisons, 168 rejected-output checks | Debug binary bound to 1003 actual compilation inputs and 1463 stable before/after source hashes |
| Versioned references | 52 functional groups plus 56 old wires | Local libzstd 1.6.0 and system 1.4.8; true full-dictionary DDicts, wide history, concatenation, streaming and seekable entries |
| Build and portability | 142/142 build steps; ARM64 and PowerPC64 compile exits zero | Complete build surface includes wasm; focused HQ tests instantiate cross-target paths |

[Contracts and test names](data/zstd-hq-contracts-x86-20261024.json),
[CLI provenance](data/zstd-hq-cli-x86-20261024.json) and
[reference results](data/zstd-hq-functional-x86-20261024.json) preserve commands,
source/compiler/binary hashes and original reports. The Debug source window
covers 1089 files without changes. The CLI report discloses a later correction
to the independent reference driver; compiled CLI/codec inputs remain unchanged.

## Implemented behavior

The HQ tree indexes every byte of the retained dictionary/history prefix,
uses checked cyclic generations, and returns a complete increasing-length
frontier. An independent finite short-hash chain supports three-byte candidates.
Unlike the legacy optimal index, the HQ index does not sample away a prefix
after 65536 anchors. SIMD mismatch detection preserves byte order across
little- and big-endian targets.

Lazy2 and BT-lazy2 compare one- and two-position delays with literal-sensitive
repeat offsets and sequence prices. Btopt uses a 4096-position, eight-state
search and integer bit costs; ultra uses sixteen states, fractional Q8 costs
and more length alternatives. Btopt rounds native Q8 symbol costs upward and
penalizes exact offset codes of at least twenty. The original `.optimal` keeps
its fixed-price behavior and existing block bound.

Cold btultra2 parses once to collect actual selected-sequence/literal statistics,
refines prices, and parses again from the original source and repeated offsets.
Both complete candidates are evaluated with the same refined model, and the
lower-cost candidate wins. Dictionary, retained-history and initialized-model
paths use one ultra parse. The first parse never becomes input history or
published frame state.

Standard dictionary Huffman weights and FSE table-state frequencies supply
initial prices. Successfully emitted sequences supply actual Huffman/FSE state
and four distributions for later blocks. Every record retains its selected
wire offset value, so emission cannot replace a priced direct offset with a
repeat selector merely because both resolve to the same distance.

## Independent checks and corrected boundaries

The matcher and parser gates include scalar frontiers, min-match 3...7, wide
dictionary positions, more than 256 frontier entries, exact/below memory,
growth/fork failures and moved owners. Independent canonical parameter data
covers all 92 level-table cells and size/dictionary/negative-level boundaries.

Two parser regressions are fixed with independent small witnesses. An
increasing-length chain no longer stops retaining candidates after 32 entries;
the 40-byte witness retains all 38 lengths and finds distance 855. Terminal
matches cross a 4096 boundary only when the complete sequence plus remaining
literals improves under the same model; the frozen ML47/48 witness selects a
4098-byte match plus one literal at cost 3072.

Physical-wire tests verify exact offset value seven when a repeat distance
four is also available, and compare committed literal prices with every active
symbol in the actually emitted sequence Huffman tree. Failed first-block
dictionary initialization restores the complete codec state, including table
availability, repeated offsets and HQ models. Partial header allocation failures
retain no emitted magic before retry.

Caller-alias and final-checksum transactions retain input through header growth
and commit the final block with its checksum. Snapshot counters retain actual
accepted/delivered progress; retries resume without a duplicate final block.
Work counters describe attempts, while emitted counters describe published
wire. Exact work budgets cover the matcher/parser and live owned plans;
serialization scratch and caller-owned buffers are separate from process RSS.

## Reference and compatibility scope

Legacy complete wires are frozen independently from pre-HQ source. New frames
are decoded by both the local libzstd 1.6.0 and system 1.4.8. Complete dictionary
frames use genuine reference DDicts and preserve their original headers; plain
frames also have an independent Zig standard-library decoder path.

The far-dictionary row explicitly omits content size: its window descriptor
advertises 128 KiB and the selected distance is 98288. With known 512-byte
content, the single-segment frame window is 512 bytes and correctly excludes
that distant prefix. The same input/dictionary witness verifies this setting
distinction rather than relaxing distance checks.

The public canonical query follows versioned Zstd 1.6.0 parameter tables and
size refinement. Its canonical level-zero default-three convention is separate
from Vort's legacy level-zero raw/RLE encoder. Hash/chain logs are reference
metadata in the query result; `hqOptions()` transfers the supported search
controls and does not claim an identical reference index layout.

Further work remains on broad current-reference ratio, encode/decode throughput,
working memory and RSS, as well as complete optimal-model parity. Bounded beams
and native priors remain engineering choices to measure. This functional
increment does not complete the long-term industry-best objective.

```sh
zig build test-zstd-hq -j2 --summary all
zig build test-zstd-hq -Doptimize=ReleaseFast -j2 --summary all
zig build test-zstd test-zstd-encode-controls test-zstd-control-consumers test-chd test-zfs-compression -Doptimize=ReleaseFast -j4 --summary all
zig build test-zstd-hq-cli -j2 --summary all
zig build run-zstd-hq-diff -Doptimize=ReleaseFast -- --reference /tmp/vort-zstd-hq-reference.so --output-dir /tmp/vort-zstd-hq-prepared
zig build check -j4 --summary all
```

Reference output directories must contain the frozen baseline assets, or
initial preparation must supply its legacy probe and source. Durations and
process peaks in validation logs are not competitor performance measurements.
