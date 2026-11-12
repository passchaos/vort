# Owner preparation control with retained scalar implementation

This control is **not adopted**. Its twelve-row cold speed geometric mean is
**1.004636342695135x**, with fixed-row bootstrap 95% CI
**[1.0020490196676917, 1.0071769245616522]**. The gain is below the 1.03 aggregate
bar. The target and weakest row, Reymont 64 KiB/L6, reaches only
**0.9894570042045981x**, below the 1.20 declared cliff-repair target. This packet
preserves the completed control independently of any later constructor trial.

Base is `cf47832821e0dce4261ab9d1cc6d56505bd121a3`. The control changes owner
preparation/public dispatch while retaining byte-identical baseline
`decoder.zig` and `linear_entry.zig`. It does not contain a mapped match-word
implementation or generic executor refactor. The six frozen control files and
source hashes govern identity; live source from other work is not substituted.

## New cohort, measured scope and outcome

| Cohort | New comparator SHA-256 |
| --- | --- |
| baseline | `4a8ae400ddb5736e7a5f46190041e6271fdb2bc9d58ffb1d54ad841b0f786a85` |
| control | `91ef93c63a1991f348521c95185d3f8fce29c2850d347c16f8fe707a9305c21a` |

Captured full source registries are **2072 baseline files** and **2075 control
files**. Both contain the same committed benchmark helper source and their
respective library/constructor source. They are a new executable/source epoch;
previous probe timing identities are not reused. The ordinary comparison uses
matched public cold caller-buffer raw decode, CPU 15, one codec thread.

The campaign has **160 child events**: **96 ordinary wall events** over twelve
rows and **64 PMU events** over four rows in two groups. Four AB/BA process
pairs are retained per row/group, each child with two measured Vort/reference
pairs and two warmup pairs: **320 measured pairs and 320 warmup pairs** total.
Original process snapshots record zero compiler observations; tick/last-seen
CPU fields do not locate timed-batch overlap.

| Ordinary cold row | Baseline/control speed GM |
| --- | ---: |
| `deflate_reymont_65536_6_cold` | 0.989457004x |
| `deflate_reymont_65536_9_cold` | 1.005736492x |
| `deflate_nci_65536_6_cold` | 1.013175759x |
| `deflate_nci_65536_9_cold` | 1.036111457x |
| `deflate_xml_65536_6_cold` | 1.003438950x |
| `deflate_xml_65536_9_cold` | 1.017486704x |
| `deflate_reymont_1048576_6_cold` | 0.993990552x |
| `deflate_reymont_1048576_9_cold` | 1.001732919x |
| `deflate_nci_1048576_6_cold` | 0.993254307x |
| `deflate_nci_1048576_9_cold` | 0.993776965x |
| `deflate_xml_1048576_6_cold` | 1.003030933x |
| `deflate_xml_1048576_9_cold` | 1.005348433x |

Ordinary speed ratios are baseline Vort duration / control Vort duration,
computed from each child's raw measured median. The verifier independently
recomputes every ratio and the balanced fixed-row process-order bootstrap,
2000 resamples, seed `0x20261112`. The confidence interval is conditional on
these twelve rows. All row geometric means pass 0.98; individual process-pair
ratios can fall below it. No dedicated-host or complete industry-matrix result
is claimed, and the aggregate gain is insufficient for adoption.

PMU groups separately collect cycles/instructions/branches or branch-misses
for the Vort batch, loop/count/mix bookkeeping and userspace control boundary.
Timers, reference decoding and full validation remain outside counters; PMU
wall durations include control overhead and are not throughput acceptance.
Raw nine-word reads preserve exact event IDs and cumulative enabled/running
headers; reset clears counts only. The archive verifier checks unscaled full
running, advancing cumulative headers and raw/semantic ID bindings. PMU ratios
use **control counter cost / baseline counter cost**, opposite to ordinary
speed-ratio orientation, and are retained as diagnostic context.

The recorded build is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
`skylake+pku+sgx`, Intel Core i7-10700K, CPU 15. Reference libdeflate 1.26 uses
matched alloc/decompress_ex/free lifecycle, pinned revision
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, GCC 11.4.0,
`-O3 -DNDEBUG -march=skylake`, library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
Original environment, compressed/plain sizes, fixture hashes, mapped libraries
and raw before/after observations are retained. No codec heap is measured.

## Scoped scalar normalization and actual self targets

The two files in `agent-static-originals` are **exact original agent tool
artifact bytes**, with original source paths and SHA-256 in
`agent-static-originals.json`. They were copied intact and are not new main
captures. `codegen-audit.json` is a separately identified main-authored derived
summary; `producer-validation.json` is also main-authored.

| Full scalar symbol observation | Baseline | Control |
| --- | ---: | ---: |
| Symbol bytes | 3659 | 3659 |
| Stack reservation | 296 | 296 |
| Pushes | 6 | 6 |
| Static instructions including padding | 897 | 897 |
| Conditional jumps / jmp | 90 / 43 | 90 / 43 |
| Negative-rbp operand references | 131 | 131 |

There are **46 different raw bytes**. Every difference falls within exactly
**eight call rel32** or **seventeen RIP disp32** fields; after masking those
fields, **zero bytes differ**. The verifier parses the original disassembly,
checks bytes against the retained ELF probes and derives normalized hash
`97c3ff8da464ed49c52b20a43b6bf59f3ceeb55431cdf6b374395a211b16e945`.
Direct function-relative branch targets match. Independently resolving the
four actual ELF jump-table entries yields the same scalar-relative targets:
**+0x931, +0x8c0, +0x950, +0xccc**.

This is a scoped normalized scalar instruction/self-target result. Masked
external calls and RIP data references do not prove full helper/data-body
identity. Helpers were not fully compared. Caller text changes **33038→39054**
and static stack reservation **77480→82168**, with different register/state
layout. The caller covers every route. Neither whole-binary/timing equality
nor preparation-only timing attribution follows from scalar normalization.
Static operand counts are not runtime spill counts or instruction costs.

## Completed functional validation

The constructor ReleaseSafe suite passes **96/96**, consisting of **94 named
tests and two anonymous imports**. Exactly **eight new constructor test
declarations** belong to `mapped_owner_tests`; the remaining 88 entries are
existing dependency tests/imports. Inner fixture loops are not 96 new cases.
The owner builds canonical LL/DIST tables in its final address-stable storage,
preserves validation/fallback contracts, and mints only the constructor borrow.
The original scalar decoder/entry source remains unchanged.

Full Deflate ReleaseSafe passes **738/738**, 725 named plus 13 import tests,
without the constructor shim tests. All **72 original Deflate wires** pass
one-call/two-round/zero-warmup smoke with full output, exact consumption,
guards and immutable input. Smoke times are excluded from performance evidence.
The smoke source/probe identity matches the frozen control. Individual command
and raw-output receipts are retained; no absent standalone smoke runner or
unsaved test command is reconstructed as an original artifact.

## Durable contents and offline verification

| Artifact | Contents |
| --- | --- |
| `control-source.tar.gz` | Six exact frozen source files, including retained baseline scalar modules. |
| `agent-static-originals.tar.gz` | Both original agent raw tool files with byte identity. |
| `probes-tests.tar.gz` | New baseline/control comparators, constructor test and full Deflate test binaries. |
| `raw-evidence.tar.gz` | Every original top-level log/manifest/protocol/event/statistics/audit/producer file and run.py. |
| `rows.tar.gz` | All 640 original per-process output/event/exit files. |
| `smoke.tar.gz` | All 219 original per-wire output/events and terminal source/validation receipts. |
| `runner-imports.tar.gz` | Immutable cf478 matrix/evidence/pmu_evidence/fixtures helper closure. |
| Readable freeze/origin/audit/producer/statistics JSON files | Exact copies of original receipts. |
| `fixture-replay-bindings.json` | Exact reused ordinary input descriptors; large corpus bytes remain external. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal archive creation, independent verification, member/origin/container identity, completed receipt and checksums. |

Baseline library/helper source and reference libraries are read from SHA-bound
committed prior archives; the verifier opens them and reconstructs exact bytes.
Ordinary fixtures reuse the prior frozen path/hash/size/generator descriptors.
The 108 plain/wire files are external; `--originals` verifies those already
required inputs without duplicating the large corpus in Git. Uncommitted
control source is verified against its frozen snapshot/capture registry, while
immutable cf478 baseline source is checked through Git blobs. No later trial
source, counters or outcome is mixed into this packet.

Archives use sorted GNU tar, regular0644/probes0755, uid/gid/mtime zero,
empty owners, gzip level9 with empty filename/mtime zero. All original raw
bytes, whitespace and EOF remain unchanged. Packing and checks use **CPU 0**.

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks original source/probe/library/helper
bytes, raw test classifications, original-agent provenance, scoped scalar
normalization and actual jump tables, caller text/stack limits, every raw
ordinary/PMU ratio and fixed-row bootstrap, and all72-wire smoke bindings.
It invokes no compiler, test, codec, oracle, perf or benchmark. `pack.py`
requires explicit `--finalize` and refuses archive overwrite; later measurement
or source changes require a separate epoch.
