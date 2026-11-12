# Fused dense canonical preparation, 2026-11-12

The fused checked dense preparation candidate is not adopted. Twelve public
cold rows reach **1.016197x** speed, fixed-row balanced process-order 95% CI
**1.011517–1.020832x**, below the required 1.03x aggregate bar. The weakest
nci1M L9 row is **0.996796x** and reymont64K L6 is **1.009659x**. The improved
preparation work does not establish a cliff repair or industry-ranking gain.

The previous owner collected active symbols in an N-length scan, then passed
that generated list to sparse initialization for another A-symbol validation/
histogram scan and A-symbol emission. The new helper fuses active collection,
histogram and maximum width in the first scan; canonical availability and
next codes share a width recurrence, and one active-symbol pass emits entries
directly into the final owner storage. It uses no external active list, table
post-validation scan, mutable trust flag, temporary returned table or heap.
The original scalar and `HuffmanTable.init` sources remain unchanged.

| Public raw cold row | Speed, baseline / candidate time |
| --- | ---: |
| reymont64K L6 | 1.009659x |
| reymont64K L9 | 1.017594x |
| nci64K L6 | 1.034427x |
| nci64K L9 | 1.031540x |
| XML64K L6 | 1.016484x |
| XML64K L9 | 1.044684x |
| reymont1M L6 | 0.997870x |
| reymont1M L9 | 1.032028x |
| nci1M L6 | 1.008044x |
| nci1M L9 | 0.996796x |
| XML1M L6 | 0.997609x |
| XML1M L9 | 1.009024x |

All 160 child events are retained: 96 ordinary wall events and 64 Vort-only
PMU events on four representative rows in two three-event groups. Every child
has two measured and two warmup Vort/reference batches; calls per batch are
500 at 64 KiB and 100 at 1 MiB. PMU wall times include control overhead and
remain diagnostic, separate from the ordinary speed comparison.

The branch-misses group shows nci64K L9 instruction/cycle ratios of
**0.986007x / 0.962244x** and XML64K L6 ratios of **0.994566x / 0.981655x**.
These candidate/baseline counters cover the complete Vort batch plus
bookkeeping and userspace control boundaries. They do not isolate table
construction or prove a causal explanation for elapsed-time differences.

The final comparison uses baseline SHA `4a8ae400...` and corrected-v2 candidate
SHA `f165198b...` at base `cf478328`. Independent scalar full-symbol analysis
finds 3659 bytes, stack296 and 897 static instruction lines in both. All 43
different bytes lie in eight call rel32 or seventeen RIP disp32 fields;
masking those fields leaves zero differences. Direct relative branches and
the four real jump-table targets `+0x931/+0x8c0/+0x950/+0xccc` match.

Caller code still changes: 33038→38572 bytes and local stack 77480→82152
bytes relative to baseline. Compared with the preceding source-only owner
control, this is 482 fewer code bytes and 16 fewer stack bytes. Scalar
non-relocation equality does not establish helper or whole-binary equality;
addresses, caller registers and surrounding control remain separate variables.
The original agent tool artifacts are preserved under their actual provenance.

Validation passes corrected-v2 dedicated native/x86 ReleaseSafe **90/90
aggregate/import tests**, each containing six new dense-constructor
declarations; owner ReleaseSafe **96/96**, containing eight owner declarations;
and complete Deflate ReleaseSafe **738/738** without either new shim. Every
ordinary frozen wire passes full-output/consumption/input/guard smoke, **72/72**.
Original dense initialization supplies canonical metadata, entry and wire
oracles for supported positive capacities. Tests cover empty reuse, oversized
and oversubscribed error order, single widths1..15, long complete/incomplete
trees and deterministic legal/skewed randomized alphabets with removed codes.

The first dedicated test build failed because both the existing dense oracle
and new helper attempted to instantiate a zero-sized active-symbol array.
The first source, original compiler diagnostics, successful nonzero owner/full
tests and first comparison build are retained separately. Corrected v2 adds
an explicit zero-capacity empty reset and uses the default empty table as the
zero-capacity metadata oracle; the old dense initializer is not silently
changed. Its unsupported zero-capacity initializer is not claimed tested.
Used-entry wire decoding remains compared against the original positive-
capacity oracle. No runtime allocation probe is claimed from the fixed
workspace/two-argument API alone.

The host is Intel i7-10700K, CPU15, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, one thread. The pinned libdeflate 1.26
cold allocate/decode/free reference and Python zlib 1.2.11 raw L6/L9 wires are
reused by exact hash. No compiler is observed at measured process boundaries.
This development-host screen is not a dedicated-host acceptance or complete
modern-reference ranking refresh.

The [evidence packet](owner-dense-construction-20261112/README.md) preserves
v1/v2 sources, binaries, compile/test logs, original static audit artifacts,
all ordinary/PMU batches and independent statistics. The next round should
target a larger measured preparation/execution cost with reusable contexts
or a larger kernel structure change, retaining these exact safety and scalar
contracts rather than continuing descriptor packing experiments.
