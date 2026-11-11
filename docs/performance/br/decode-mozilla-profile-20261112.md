# Mozilla Brotli decode pilot and rejected screens, 2026-11-12

The clean `5fb4c6957342ba51af6902172af02a5369e020cb` source still takes
**2.0511×** libbrotli 1.2.0's time on the frozen full Mozilla q11 wire. Two
isolated candidates produced about 5% gains on that row, below the 20% target
for repairing this known cliff. Neither codec candidate is adopted. The
reusable header diagnostic and the [raw evidence package](decode-mozilla-profile-20261112/README.md)
are the completed increments from this pilot.

## Current-source whole public calls

All three rows reuse the complete modern matrix's frozen producer wires,
plain bytes, library binaries and metadata without recompression. Each row
retains two warmup pairs and six measured AB/BA pairs. This is a three-row
pilot; its manifest preserves the full 216-fixture schema and its summary
correctly reports `complete=false`. It does not replace the
[complete `ea193be2` comparison](../modern-decode-refresh-20261111.md).

| Mozilla condition | Paired Vort/reference time | Vort median batch | Reference median batch |
| --- | ---: | ---: | ---: |
| Full file, q11 | 2.05106993× | 264.822 ms | 128.868 ms |
| First 1 MiB, q11 | 0.88623583× | 71.197 ms | 74.304 ms |
| Full file, q6 | 1.62718989× | 176.166 ms | 107.899 ms |

The full-file batches contain one decode; 1 MiB batches contain twenty.
Ratios use every paired sample rather than the quotient of displayed medians.
Two late 1 MiB reference batches took about 99/107 ms instead of the usual
74 ms. The median quotient is 0.95819×, and the recorded paired confidence
interval is broad. Retain those samples and treat this control as uncertain;
the pilot does not establish a sustained 1 MiB performance lead. The 1.82688×
summary group combines both full-file qualities and is not the q6 row ratio.

The public API, caller-buffer lifecycle, output clearing outside timing,
64-byte alignment/guards, one codec thread and logical CPU 15 match the full
matrix protocol. Zig is 0.16.0 ReleaseFast, target `x86_64-linux-gnu`, CPU
`skylake+pku+sgx`; the host is Intel i7-10700K with turbo enabled and
`intel_pstate/powersave`. All screen boundary captures are compiler-free.
These are development-host observations.

## Header shape and actual payload attribution

The [header diagnostic](../../../tools/br/decode_mozilla/README.md) uses the
existing aggregate multi-block profiler and validates a public decode before
the diagnostic passes. Across one full q11 stream it observes nine compressed
meta-blocks, **799 command trees**, **534 distance trees** and **1,573 literal
trees**. Full q6 has ten blocks, **896 command trees**, **1,576 distance trees**
and **1,649 literal trees**. Every command/distance tree in these diagnostics
is nine-bit-tail eligible, while the existing auxiliary preparer caps inline
command/distance trees at 32/64 per meta-block. The totals alone are not a
per-block route or decoded-byte weighting report.

Perf directly observes the full q11 generic wide payload specialization.
The recording uses `cycles:u`, 499 Hz and 16 KiB DWARF stacks. Offline parsing
retains 1,917 samples and weighted period 18,438,825,507, matching the original
report. **No sample reaches `br.decodeStreamInto`**, even though its symbol
exists in the measured binary. The wide meta-block wrapper reserves 537,976
stack bytes, beyond the captured stack span, so its parent chain is missing.
Whole-process samples also include output clearing, validation and both
competitors. They cannot be called public-decoder-root measurements.

A narrower observed generic-payload-root scope contains 985 samples with
weighted period 9,564,092,283. Within that scope:

| Physical symbol | Self period | Inclusive period |
| --- | ---: | ---: |
| Generic wide payload | 38.4052% | 100% |
| `commandPrefixForDecode` | 7.4337% | 8.7418% |
| `distancePrefixForDecode` | 15.9969% | 18.3273% |
| `readCommandSymbolAny` | 8.7102% | 19.6910% |
| `readMinimalDistance` | 13.6034% | 36.5060% |

Inclusive rows overlap and must not be summed. These are physical-symbol
shares under one observed payload root, with inlined work attributed to its
containing symbol; they do not describe the whole public operation. The
archive retains the independent offline attribution audit and raw stacks.

## Interleaved baseline/candidate screens

Each screen uses four interleaved baseline/candidate process pairs per row,
alternating process order. Every child retains two internal AB/BA measured
pairs plus two warmup pairs against libbrotli. The reported candidate speedup
is the geometric mean of baseline/candidate Vort batch-median ratios across
the four process pairs. Complete stdout/stderr bytes, library/fixture/source
hashes and host observations remain in the archive.

| Candidate | Full q11 speedup | 1 MiB q11 control | Full q6 speedup |
| --- | ---: | ---: | ---: |
| Cache resolved command pointer and inline distance pointers | 1.05286529× | 0.99765438× | 1.05302855× |
| Stable nine-bit lookup planes for all command/distance trees | 1.04752709× | 0.99929304× | 1.02984467× |

The pointer variant refreshes the command pointer after each block switch and
only caches four distance pointers when the entire distance-tree count is at
most 64. Packed distance expansion otherwise overwrites one shared active
slot and must retain per-symbol resolution. The original screen source is
preserved, including the existing cached helper's absent defensive current-type
check; the later test variant restores that check and is a separate epoch.

The lookup-plane variant prepares every eligible tree once per meta-block,
using the shared Huffman constructor for packed trees and stable pointers on
block switches. Eligibility checks widths before building planes; trees above
nine bits fall back to the generic path. Setup is isolated in a noinline
function. Two 256-tree arrays require **524,288 bytes** of lookup storage,
plus setup temporaries and call frames. This is a static storage bound rather
than a measured whole-operation peak. The candidate is kept off the mainline.

Neither screen proves the 20% weak-row improvement, the complete 72-row
non-regression matrix, fixed-host acceptance or memory leadership. Four
process pairs also do not establish the control floor with confidence.
The larger planes do not show a compelling return for their extra storage.

## Validation and next slice

The allocator-free packed-tree constructor passed five focused tests in both
Debug and ReleaseSafe: complete/incomplete/sparse trees, widths 1–9,
singletons, every symbol-bit truncation at offsets 0–7, physical padding,
all 512 prefixes, cursor/error equivalence with the prepared reference, and
malformed shape/width/count/symbol/oversubscription cases. That helper proof
does not by itself validate the complete payload candidate. Payload transition
validation is recorded separately with its exact source epoch. The focused
Debug and ReleaseSafe builds each passed 5/5 steps and 22/22 tests. The latter
retains exact stdout/stderr bytes, return code and unchanged source hashes;
the Debug receipt is explicitly a tool-return record without separate raw
streams or a retroactively asserted source digest. The dedicated oracle covers
command counts 32/33/256 and distance counts 64/65/256, packed previous-type
switches through index 255, all four distance contexts in two switching blocks,
nonzero postfix/regular extra bits, implicit distances while a switch is
pending, static dictionaries and packed literal 10/11/15-bit fallback. Each
short payload enumerates every input bit and output byte boundary, comparing
errors, bit position, written count, the complete output/suffix, distance ring
and all three block states against the prior generic executor; complete cases
also check independently known output. The post-timing reference/adapter
variant does not change or retroactively validate the measured-source digest.

The shipped diagnostic passes its three option/work-limit tests, the
ReleaseFast build and installed help smoke. Five pre-read output-alias smokes
reject direct input/plain, hardlink, symlink and executable aliases with exit
2 while preserving all protected bytes. Production codec source is unchanged
by this increment.

Before another candidate, collect per-meta-block payload routes weighted by
decoded bytes and command/copy distributions using counter instrumentation
outside competitor timing. The remaining command/distance cost warrants a
combined decoder-kernel design; evaluate the existing fused command metadata
and staged distance reads against the measured generic path while preserving
implicit-distance, switch/truncation progress, dictionary and memory bounds.
Header clocks alone cannot predict a whole-operation win. Retain the complete
modern matrix as the competitor comparison and the full Mozilla q11 row as
the cliff gate.
