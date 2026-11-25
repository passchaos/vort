# DEFLATE binary-tree evidence and covered optimal parsing

Date: 2026-10-31. This increment replaces dense hash-chain discovery in the
dictionary-free high-level one-shot refinement path with a DEFLATE-specific
three-byte hash binary tree and shared immutable matching evidence. The generic
`lz77.PreparedOptimal` remains available for arbitrary per-distance costs.
The [frozen evidence package](data/deflate-bt-optimal-20261031/README.md) retains
all candidates, raw observations, reference provenance and validation results.

## Algorithm and model boundaries

Reference: local libdeflate 1.26, clean commit
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, especially `lib/bt_matchfinder.h`
and `lib/deflate_compress.c`. Vort uses a Zig-native design rather than the
reference's four-byte BT and small three-byte fast path. It validates hash
collisions by bytes, retains the longest visited match in each of the 30 RFC
distance-price classes, and maintains the original raw-node/candidate budgets.
Class representatives retain minimum frozen-model cost over the visited edges;
they can change nearest-distance ties at shorter selected lengths. This is
a bounded matcher graph, not a global or original hash-chain optimum.

The selected coverage threshold is 258. A position with a full-length match
suppresses outgoing match evidence at the following covered positions. Every
position still performs the same BT insertion and retains its literal edge;
an omitted interior match cannot extend coverage. Fixed and modeled solves
therefore use the same cost-independent graph. Discovering the triggering
match does not force the DP to choose it. Thresholds 150 and 128 are separately
measured and retain their different quality/work results.

The tree is released before DP storage is allocated. Match evidence uses three
little-endian bytes: eight bits for length minus three and fifteen bits for
distance minus one. Per-position counts use one byte; reverse solves consume
the records with a cursor without a separate position-offset table. Both solves
share the immutable evidence and reuse checked `u32` costs and token steps.
Prices remain `u16`; positive literal costs, at most 65,536 bytes and a valid
match's bounded suffix prove that every real cost remains below the sentinel.

The eligible input range now includes a full 64 KiB block. Only positions
through 65533 can have a three-byte match, so 65535 remains a valid `u16` empty
link sentinel. Distance exactly 32768 is supported. Existing default-strategy,
optimal-parser, dynamic block selection and dictionary-free routing stay in
effect; streaming/dictionaries, split planning and broader full files still
need their own graph and entropy-model work.

## Independent candidates and ordinary evidence

All ordinary campaigns use separate Zig 0.16.0 LLVM ReleaseFast executables,
Intel i7-10700K, CPU 2 and one codec thread. Input setup, metering, determinism
and decoder verification are outside allocating encode/free intervals. Formal
timers do not overlap compilers or separate codec-validation runs. All twelve
Silesia files are frozen at 4 KiB, 16 KiB, 65535 bytes and 65536 bytes.

The first scalar BT cache already reduced aggregate time but increased dense
input memory. A portable word-extension candidate preserved its exact graph
and output. A cache-free forward replay reduced memory but added BT traversal
and outgoing-edge work. Narrow `u32` forward costs and exact price intervals
were independently validated; their outputs remain byte-identical to forward
replay, but their ordinary performance did not justify replacing the cached
reverse solver. All unsuccessful variants and point regressions are retained.

| Level-9 variant / scope | 4 KiB time | 16 KiB time | 65535-byte time | 65536-byte time |
| --- | ---: | ---: | ---: | ---: |
| Word cache, original eligible cap | `0.720798` | `0.611351` | `0.483820` | `0.990946` |
| Cache-free forward replay | `1.112551` | `0.957908` | `0.786027` | `1.240683` |
| Forward replay, `u32` costs | `1.048807` | `0.907094` | `0.759449` | `1.164380` |
| Forward replay, exact price intervals | `1.010746` | `0.930562` | `0.756886` | `1.187172` |
| Covered cache, threshold 258 | `0.636548` | `0.582305` | `0.444869` | `0.700361` |
| Covered cache, threshold 150 | `0.629726` | `0.580733` | `0.439618` | `0.691011` |
| Covered cache, threshold 128 | `0.630134` | `0.581220` | `0.442769` | `0.691221` |

These are geometric means of per-case median new/baseline times from one
nine-variant campaign, with two alternating sweeps and three encodes per
process. The 258-threshold cache size ratios are
`0.999910 / 0.998569 / 0.997163 / 0.985241`; its 150/128 alternatives are slightly
faster but consistently larger. The final packed-record/`u32` layout is a
separate source epoch, measured below.

Pinned libdeflate level 12 takes roughly half the 258-threshold candidate's
time at similar sizes in this screen: candidate/reference time is
`1.925763 / 1.830843 / 1.849844 / 1.871978`, at size
`1.000685 / 1.002773 / 1.012366 / 1.012369`. Reference and Vort levels are
explicit settings with different algorithms, not an equal-strategy contract.
Lower reference levels have different speed/ratio tradeoffs, recorded in the
separate reference epoch. No full-file or industry-lead claim follows.

## Final-source allocating encode/free check

The adopted source runs a separate three-sweep campaign against the preceding
live encoder, its frozen selected snapshot, the original 258-threshold layout
and pinned libdeflate level 12. Each process performs three timed encodes after
warmup. The complete 1008-process campaign ends with exit zero. Live output
matches the selected snapshot, and all 288 wrapper wires independently decode;
60 additional tiny/out-of-range wrapper pairs remain identical to the old
encoder. These results are not multiplied with earlier epochs.

| Input scope, all twelve files | Live / prior time, level 8 / 9 | Live / prior size | Live / libdeflate12 time, level 9 | Live / libdeflate12 size |
| --- | ---: | ---: | ---: | ---: |
| 4 KiB | `0.631379 / 0.630066` | `0.999910` | `1.916330` | `1.000685` |
| 16 KiB | `0.585644 / 0.589154` | `0.998569` | `1.853619` | `1.002773` |
| 65535 bytes | `0.446008 / 0.456402` | `0.997163` | `1.879912` | `1.012366` |
| Complete 64 KiB | `0.704928 / 0.713807` | `0.985241` | `1.914154` | `1.012369` |

The final record/cost layout preserves the 258-threshold output but trades a
small amount of time for lower requested heap. Live/frozen-selected time is
close in each bucket. Individual output and time regressions remain in the raw
rows; aggregate savings do not imply every case improves. The remaining
reference time and size gaps justify further matching, price and entropy work.

## Resource accounting and validation

Requested-byte probes include the returned wire and exclude borrowed input and
allocator overhead. The initial NCI-65535 scalar cache peaks at 4,083,695 bytes,
versus the preceding encoder's 1,894,928 bytes. The 258-threshold cache lowers
that to 3,090,329 bytes. Three-byte evidence and native `u32` DP then lower it to
2,134,342 bytes. This remains a 12.6% point increase versus the preceding
encoder; aggregate memory savings are not a per-case guarantee.

The final packed layout's summed requested peaks, divided by the prior
encoder's sums, are `0.729363 / 0.799264 / 0.844218 / 0.832807` across the four
input buckets. All 48 final-source probes equal the frozen selected public
peaks and free their allocations. The
reference's measured level-12 compressor allocation is 9,011,751 requested
bytes, plus its output capacity; these are requested bytes, not process RSS.

Independent recursive tree/raw-edge oracles validate covered graph maxima,
all legal lengths, far but cheaper distance classes, nonmonotonic length
prices, length 258 and the 32768 distance. Frozen 258-threshold comparisons
validate all position costs, steps, tokens and full wires after layout changes.
Allocation-failure tests cover construction, result allocation, recoverability
and the tree/evidence/DP/model/two-plan ownership overlaps. Native and actual
32-bit/WASI runs cover the maximum positive-`u16` model and complete 64 KiB
input. Permanent codec test registration is required alongside focused roots.

The complete native Deflate suite passes 578/578 tests in Debug and
ReleaseFast, with all 18 named new BT tests executed from permanent codec
registration. Frozen selected native/x86/WASI Debug/ReleaseFast suites each
pass 21/21, and shipping codec dependencies match that validated source.
Refinement tests pass 8/8; actual Deflate and package-root filtered registration
each execute all five named layout/ownership additions. Final-source reference
and CLI gates pass, including Python zlib differential smoke and bidirectional
parameter, partial-flush and recovery operations.

The independent measurement reducer verifies 3792 successful serial ordinary
process records and 288 case rows across the initial level-8/9 screens,
reference, replay, nine-variant and final-live campaigns. Project native/Wasm
checks complete 212/212 build steps. The existing incremental-encode smoke
gate passes all five cases with 9/9 build steps; its performance and reference
settings remain a separate legacy-stream scope. Frozen and live package audits
both pass with final status and no pending gates. Archived byte identities
cover all 12 formal native benchmark executables and six executed Wasm modules;
other native test/probe executables retain source/command/log identities and
are checked from local bytes by the live audit. The audit checks all 71 codec
dependency files and 74 source-overlay files, with no missing live identities.
The active three-codec
objective remains incomplete; next work includes full-file and dictionary/
streaming BT graphs, reduced pricing work and stronger entropy convergence,
alongside Zstd persistent indexes and Brotli final-model command parsing.
