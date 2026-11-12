# Owner preparation with the original scalar executor, 2026-11-12

The owner preparation control is not adopted. Twelve matched public cold rows
reach a speed geometric mean of **1.004636x**, with fixed-row process-order
bootstrap 95% CI **1.002049–1.007177x**. The weakest and target reymont64K L6
row is **0.989457x**. All controls exceed 0.98x, but the aggregate is below the
3% adoption bar and no cliff repair or industry-ranking gain is established.

Unlike the earlier owner-only variant, this control retains the mainline
`decoder.zig` and `linear_entry.zig` source bytes. Only the buffered, 11-bit,
no-dictionary, non-overlapping input/output preparation path constructs
canonical LL/DIST tables and semantic mapping in the address-stable owner.
Semantic preparation failure reuses the compact tables for checked fallback.
Ordinary, RLE258 and deep-distance execution keep their original entries.

| Cold public raw decode row | Speed, baseline / control time |
| --- | ---: |
| reymont64K L6 | 0.989457x |
| reymont64K L9 | 1.005736x |
| nci64K L6 | 1.013176x |
| nci64K L9 | 1.036111x |
| XML64K L6 | 1.003439x |
| XML64K L9 | 1.017487x |
| reymont1M L6 | 0.993991x |
| reymont1M L9 | 1.001733x |
| nci1M L6 | 0.993254x |
| nci1M L9 | 0.993777x |
| XML1M L6 | 1.003031x |
| XML1M L9 | 1.005348x |

The new baseline/control executables are frozen at `cf478328`. All 160 child
events are retained: 96 ordinary wall events, four balanced process pairs per
row, and 64 Vort-only PMU events on four representative rows in two groups.
Each child retains two measured and two warmup Vort/reference batches, using
500 calls at 64 KiB and 100 at 1 MiB. PMU wall durations include control
overhead and remain diagnostic, separate from the ordinary comparison.

The branch-misses group gives candidate/baseline instruction ratios
0.999738x / 0.990248x / 0.999490x / 0.999409x on reymont64K L6, nci64K L9,
XML64K L6 and nci1M L9 respectively. Their user-cycle ratios are
0.999543x / 0.967578x / 0.993378x / 1.001649x. These are whole Vort batch
counters, including count/mix bookkeeping and userspace control boundaries;
they cannot assign a cost solely to table preparation.

Independent full-symbol inspection proves scalar non-relocation codegen
consistency in this epoch:

| Ordinary aligned scalar entry | Baseline | Control |
| --- | ---: | ---: |
| Symbol bytes | 3,659 | 3,659 |
| Local stack reservation | 296 | 296 |
| Register pushes | 6 | 6 |
| Static instruction lines, including padding | 897 | 897 |
| Conditional jumps / jmp | 90 / 43 | 90 / 43 |
| Negative-rbp operand references | 131 | 131 |

The complete 3659-byte symbols differ in 46 bytes, all within eight call rel32
or seventeen RIP disp32 fields. Masking those fields leaves zero differences.
All direct function-relative branch targets match. The real four-entry tail
jump tables also target the same relative offsets `+0x931`, `+0x8c0`,
`+0x950` and `+0xccc`. The original audit tool artifacts are preserved as exact
bytes; they are not relabeled as newly recaptured main output.

The caller still changes: all-route text is 33038→39054 bytes and local stack
reservation 77480→82168 bytes, with different parameter/register arrangements.
Absolute scalar/table addresses change, and helper bodies are not individually
compared. Scalar non-relocation equality therefore does not establish entire
binary equality or preparation-only timing. Static stack references do not
measure dynamic spills.

Correctness passes owner constructor ReleaseSafe **96/96 aggregate/import
tests**, comprising eight new owner declarations and existing dependencies,
and complete Deflate ReleaseSafe **738/738**. All **72 frozen ordinary wires**
pass complete output, consumption, immutable input and guards. Empty, single
and valid incomplete distance trees retain support; malformed suffix holes
remain defined and rejected. Both ReleaseFast comparators build successfully,
with formatting and patch-whitespace checks passing.

The host is Intel i7-10700K, logical CPU15, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, one thread. The pinned libdeflate 1.26
cold allocate/decode/free reference and original Python zlib 1.2.11 raw L6/L9
wires are reused by exact hash. Compiler observations are empty at measured
process boundaries. This is a development-host target/control screen,
not a dedicated-host or complete modern-reference acceptance result.

The [evidence packet](owner-prepare-control-20261112/README.md) preserves source,
executables, tests, original static audit artifacts and every measured batch.
The source work that remains in canonical preparation is an N-length scan
to collect active symbols, followed by an A-symbol sparse scan to validate
the generated list and count widths, then another A-symbol emission scan.
The original dense constructor fuses active-list collection with counting.
The next independent candidate uses a checked dense in-place constructor to
avoid this repeated preparation while retaining the original scalar code
and all borrow/error/incomplete-tree contracts.
