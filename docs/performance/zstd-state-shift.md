# Zstd HQ state insertion shifts

HQ beam insertion now holds the candidate while moving preceding nodes one slot
to the right, then writes the candidate at its final position. The old path wrote
the candidate first and repeatedly exchanged two complete nodes. Duplicate-key
search, sentinel handling, rejection, `less` ordering, price admissions and
profile accounting retain their existing behavior. No table or allocation is
added. The ten-format product goal remains active.

This is equivalent even for unsorted rows: at every old bubble comparison,
`row[replace]` contains the same candidate, and the predecessor is the same old
node. Both loops stop at the same position and produce the same shifted segment.
The [measured diff](data/zstd-state-shift-20261028/source.diff.xz) changes only the
sorting tail of `state.insert`.

The [evidence package](data/zstd-state-shift-20261028/) shares baseline
`dbbb64cdfe70fbb4705d8e9256c49a7580748767`, which already contains the sampled ML
tail stop. Its compressed snapshot contains 1505 `src` and build files; docs,
compiler caches and compiled runners are excluded. Binary byte counts, SHA-256
and ELF targets remain in `binary-identities.json`. The original two artifact
manifests were checked before packaging: all 35 sampling and 119 prototype
entries matched their recorded size and hash.

Ordinary-only CPU sampling used Zig 0.16.0 LLVM ReleaseFast `skylake`, frame
pointers and CPU 2. Mozilla 4 KiB/btultra2 ran eight calls (4868 samples);
Dickens 4 KiB/btopt ran 256 (3425 samples), at 1999 Hz `cpu-clock:u`. All samples
came from CPU 2, with no lost samples or diagnostic calls. The loop checks
repeated complete wires and performs a native decode after encoding.

| Global sample share | Mozilla btultra2 | Dickens btopt |
| --- | ---: | ---: |
| `state.insert` total | 67.09% | 43.88% |
| Duplicate scan and loop | 54.87% | 18.07% |
| Same-key/final replacement `less` | 3.00% | 3.71% |
| Sorting `less` | 0.51% | 2.45% |
| Sorting swaps and loop | 3.49% | **14.51%** |

These shares are recomputed from raw instruction-pointer periods over the entire
recording, not symbol-local annotate percentages. The compact 56-byte node swap
compiled to a loop exchanging fourteen `u32` lanes. The shift prototype uses
vector loads/stores to copy each predecessor once and writes the candidate only
at the end; its two insertion specializations shrink from 577/577 to 535/551
bytes. FP sampling identifies a target; it is not a stage-by-stage accounting of
the separate non-FP ordinary timing results below.

Both timing variants were freshly built with the same non-FP ReleaseFast
`skylake` flags and runner. Two AB/BA rounds cover three real Silesia 4 KiB
prefixes and explicit btopt/btultra2 strategies, with window log 15, block ceiling
32768 and checksums enabled. Each ordinary allocating encoder call is timed;
input setup, caller release of the returned frame, decoding, hashing and the
separate diagnostic encode are outside that timer. Internal workspace cleanup
occurs inside the allocating API. Full wires and complete profiles agree for all
24 ordinary calls; 48 original native decodes passed.

| 4 KiB input | Strategy | Paired ratios, rounds 0/1 | Ratio of medians |
| --- | --- | ---: | ---: |
| Dickens | btopt | 0.828982 / 0.865556 | **0.847066** |
| Dickens | btultra2 | 0.766079 / 0.769440 | **0.767761** |
| Mozilla | btopt | 0.980521 / 0.982529 | 0.981524 |
| Mozilla | btultra2 | **0.948338 / 1.007208** | 0.977409 |
| MR | btopt | 0.901598 / 0.893331 | **0.897477** |
| MR | btultra2 | 0.842899 / 0.829151 | **0.836014** |

The final column is exactly `median(candidate_ns) / median(baseline_ns)`, not
the median of paired ratios. Dickens and MR improve in both rounds. Mozilla
btultra2 is mixed, so its aggregate does not establish a stable gain. Two rounds
on three small prefixes remain exploratory; these numbers do not establish
general HQ throughput, significance, platform parity or reference-encoder speed.
Raw rounds, background activity and complete settings are preserved.

The prototype's unchanged frozen `state_tests` compare every row field with the
b04 `std.mem.eql` insertion oracle. Native Debug, native ReleaseFast and actual
x86 Linux Debug each passed 12,288 randomized insertion operations plus high
repeat bits, ties, full/vacant rows and sentinel fixtures. Observed sizes are
Node/WholeNode **56/64 bytes on x86_64**, **40/44 on x86**. The parent reports
integrated arbitrary-row/alias tests passing 4/4 on native Debug, ReleaseFast,
x86 and Wasm, plus 369 focused tests. Those integration results are separate from
the measured prototype; authoritative final commands, source and logs belong in
`current-validation.json`, whose initial status explicitly records that boundary.

The independent [audit](data/zstd-state-shift-20261028/audit.py) checks all four
archive/member hashes, matches the baseline to Git blob identities, applies and
checks the sole candidate diff, verifies wire/profile pairs and recomputes exact
rational timing ratios and sampling denominators. It also decodes all **24
prototype wires with local libzstd 1.6.0**, compares every byte with the frozen
input and records the decoder library SHA-256 in `reference-decode.json`.
This is a correctness oracle, not a timed competitor comparison.

```sh
python3 docs/performance/data/zstd-state-shift-20261028/audit.py
```

Software samples can skid, and an instruction's share is not a branch outcome or
recoverable speedup. The selected encoder calls dominate the recordings, but
small setup and verification work is also sampled. Reproduction extracts the
shared source and frozen inputs, applies `source.diff`, and uses the archived
compile/run commands with local path substitutions. Continue with broader
ordinary matched-parameter measurements and final platform/resource checks; the
withdrawn first-key, worst-node and prepared-pricing prototypes are not bundled
with this change.

The retained implementation is saved in `e29650ca`. Native Debug,
ReleaseFast, actual x86 Debug and executed wasm32-wasi each pass 4/4 standalone
checks, including the old 12,288-step oracle and new arbitrary-row/aliased
candidate contracts. Existing HQ/search/parallel-incremental tests pass
369/369; versioned bidirectional references pass 52 HQ and 41 search groups.
The current source completes the broader build check with exit code zero.
`current-validation.json`, the final source overlay and `current-audit.py`
record these integrated results separately from the measured prototype.
