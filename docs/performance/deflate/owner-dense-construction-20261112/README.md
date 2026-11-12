# Dense canonical construction control: rejected screen

The fused dense-construction control is **not adopted**. Twelve-row cold
speed GM is **1.0161967969538732x**, with fixed-row bootstrap 95% CI
**[1.0115169431874778, 1.0208318191838939]**. This is below the 1.03 aggregate
bar. The weakest row is NCI 1 MiB/L9 at **0.9967958215397039x**; target Reymont
64 KiB/L6 reaches **1.0096590452278693x**, below the 1.20 cliff-repair target.
No dense helper, owner or library core code is adopted from this packet.

Base revision is `cf47832821e0dce4261ab9d1cc6d56505bd121a3`. The helper is a
separate `huffman/dense_decode_init.zig` module; original `huffman.zig`/init,
semantic decoder and scalar entry source remain byte-identical to baseline.
The helper derives active symbols, histogram and maximum width together during
canonical construction into final owner storage. Frozen v1 and v2 sources,
compile/error observations and binaries remain separate epochs.

## v1 compile failure and corrected v2 boundary

| Epoch | Existing completed observation |
| --- | --- |
| V1 dedicated dense test | Compilation fails twice at capacity=0: original HuffmanTable init oracle and new helper each index an empty active-symbol array. |
| V1 ordinary capacities | Owner ReleaseSafe 96/96, full Deflate ReleaseSafe 738/738 and comparator build succeed. The original v1 binary is retained; no v1 timing is used. |
| V2 dedicated dense tests | Native and x86 ReleaseSafe each 90/90 after explicit zero reset and direct static empty oracle correction. |
| V2 owner/full/build | Owner 96/96, full Deflate 738/738, comparator build and 72-wire smoke pass. |

V2 adds a compile-time capacity=0 branch calling `resetEmpty`; empty metadata
reset is shared with the zero-active-symbol path. Tests use a direct
`HuffmanTable(capacity){}` default-table oracle at zero capacity and skip
unsupported old init/decode calls there. Original Huffman init remains unchanged
and is the differential oracle for nonzero capacities. Only the dense helper
and its dedicated test file change between the two ten-file source snapshots.
This is constructor/metadata coverage, **not a runtime allocation probe**.

V2 dedicated 90-log suites contain **88 named tests and two anonymous imports**,
with **six new dense-helper declarations**. Owner 96 contains 94 named plus two
imports, with eight constructor declarations. Full Deflate 738 contains 725 named
plus 13 imports and no new standalone helper/owner test modules. Inner fixture
loops are not 90 new behaviors. Guard/input/metadata checks are retained; no
usable-table state is promised after an initialization error.

## New v2 probes and ordinary/PMU results

| Probe | Frozen SHA-256 |
| --- | --- |
| baseline | `4a8ae400ddb5736e7a5f46190041e6271fdb2bc9d58ffb1d54ad841b0f786a85` |
| control | `f165198bc381a5af85b87aeab03b699fec37002382e851228a3d1f8f337fa567` |

V1 comparator SHA-256 is
`12d1acd34c92606bf47e1547a7d7a5c7202ec9f26b8186d05e667c1a327ac84f`.
It is not relabeled as the measured v2 `f165198b…` probe. Source capture
registries contain **2072 baseline files** and **2078 v2 control files**,
reconstructed from the immutable base plus exact frozen v2 overlay. The v1
snapshot is independently retained by its own source hashes and validation.

There are **160 child events**: **96 ordinary wall events** across twelve
rows and **64 PMU events** across four selected rows/two groups. Four AB/BA
process pairs per row/group each use two measured Vort/reference pairs and two
warmups: **320 measured pairs and 320 warmup pairs**. Ordinary speed ratios are
baseline Vort duration / control Vort duration, independently rebuilt from
raw measured process medians. Bootstrap holds the twelve rows fixed, balances
process-order strata, uses 2000 resamples and seed `0x20261112`.

| Ordinary cold row | V2 speed GM |
| --- | ---: |
| `deflate_reymont_65536_6_cold` | 1.009659045x |
| `deflate_reymont_65536_9_cold` | 1.017593582x |
| `deflate_nci_65536_6_cold` | 1.034427245x |
| `deflate_nci_65536_9_cold` | 1.031540465x |
| `deflate_xml_65536_6_cold` | 1.016484164x |
| `deflate_xml_65536_9_cold` | 1.044684134x |
| `deflate_reymont_1048576_6_cold` | 0.997869865x |
| `deflate_reymont_1048576_9_cold` | 1.032028101x |
| `deflate_nci_1048576_6_cold` | 1.008043589x |
| `deflate_nci_1048576_9_cold` | 0.996795822x |
| `deflate_xml_1048576_6_cold` | 0.997608896x |
| `deflate_xml_1048576_9_cold` | 1.009024383x |

All selected row GMs pass the 0.98 control floor. The aggregate and target
still fail adoption gates; this is development-host evidence, not fixed-host
acceptance or an industry ranking/full corpus performance matrix. Individual
process-pair ratios remain in the raw evidence. Scalar normalization does not
make the measured operation preparation-only or remove caller/helper effects.

PMU groups preserve Vort-only cycles/instructions/branches or branch-misses
for the batch loop, count/mix and userspace control boundary. Reference, timers
and full validation remain outside counters. PMU wall time includes control
overhead and is diagnostic. Ratios use **control counter cost / baseline cost**,
opposite to ordinary speed-ratio orientation. Nine-word raw reads, three IDs,
full unscaled running and cumulative enabled/running header advance are checked;
counts reset per batch but cumulative header times do not.

The target is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU `skylake+pku+sgx`, CPU 15
on Intel Core i7-10700K, one codec thread. libdeflate 1.26 uses matched cold
alloc/decompress_ex/free lifecycle, revision
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, GCC 11.4.0,
`-O3 -DNDEBUG -march=skylake`, shared-library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
Original build mode, CPU/host policy, compressed sizes, hashes and process
observations are retained. Compiler boundary observations are empty. No
runtime allocation or codec-memory result is inferred from static source/tests.

## Original static artifacts and scoped normalized equality

The two `agent-static-originals` files preserve **exact original agent raw
tool bytes**, source paths and hashes. They are not new main captures.
`codegen-audit.json` and `producer-validation.json` are separately attributed
main-authored derivatives.

Both full scalar symbols are **3659 bytes**, reserve **296 stack bytes** and
contain **897 static instruction lines** including padding: 90 conditional
jumps, 43 jmp and 131 negative-rbp references each. There are **43 different
raw bytes**, all within **eight call rel32** or **seventeen RIP disp32** fields;
masked nonrelocation difference is **zero**. The verifier matches raw
instructions against ELF bytes and independently resolves the four actual
jump-table entries to the same scalar-relative targets:
**+0x931, +0x8c0, +0x950, +0xccc**. Direct relative branch targets also match.

This proves the declared normalization/self-target scope. Masked external
calls/data references and helper bodies were not completely compared, and
static operand counts are not dynamic spill costs. Caller text/stack is
**33038/77480** for baseline and **38572/82152** for dense v2; the prior committed
owner-control caller was **39054/82168**. Caller registers/state and addresses
differ, and the caller covers all routes. No complete helper/binary/timing
identity or whole-operation cause is claimed.

## Wire smoke and durable artifacts

All **72 original Deflate wires** pass one-call/two-round/zero-warmup smoke
with full output, exact consumption, immutable input and guards. Its source
registry and probe match the frozen v2 control. Smoke clocks are excluded from
performance evidence. Commands/results are retained; absent standalone runner
or test argv is not invented.

| Artifact | Contents |
| --- | --- |
| `source-v1.tar.gz`, `source-v2.tar.gz` | Separate original and corrected ten-file source snapshots. |
| `probes-tests.tar.gz` | Exact baseline, original v1 and final v2 comparator/test binaries, including nonzero-capacity v1 successes. |
| `agent-static-originals.tar.gz` | Two exact original raw scalar tool artifacts. |
| `raw-evidence.tar.gz` | Every top-level original log/manifest/protocol/event/statistics/validation/audit file and run.py. |
| `rows.tar.gz`, `smoke.tar.gz` | All 640 per-process pilot files and 219 per-wire smoke files. |
| `runner-imports.tar.gz` | Immutable cf478 matrix/evidence/pmu_evidence/fixtures helper closure. |
| Readable freeze/v1-validation/origin/audit/producer/statistics JSON files | Exact original receipt copies. |
| `fixture-replay-bindings.json` | SHA-bound existing ordinary descriptors; large input bytes stay external. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal packing, independent verification, origins/container/member hashes, completed receipt and full checksums. |

Baseline library/helpers, prior owner-control audit and reference bytes are
opened from exact SHA-bound committed archives. The 108 ordinary plain/wire
files are reused by original descriptor/optional hash checks; no large corpus
is duplicated. Uncommitted v1/v2 overlays are verified by snapshot/capture
identity, while immutable baseline source is checked through Git blobs.
The prior owner-prepare packet stays frozen; no later trial source or result
is mixed into this packet.

Archives use sorted GNU tar, regular 0644/binaries 0755, uid/gid/mtime zero,
empty owners, gzip level 9 with empty filename/mtime zero. Original whitespace,
EOF and bytes remain intact. Packing and verification use **CPU 0**.

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks v1/v2 source/error/binary scope, retained
original huffman/init/scalar bytes, actual test/import/declaration counts,
raw ordinary/PMU ratios and bootstrap, original agent provenance, scalar
normalization and real jump tables, caller text/stack limits and all 72-wire
smoke bindings. It invokes no compiler, test, codec, oracle, perf or benchmark.
`pack.py --finalize` requires terminal frozen inputs and refuses overwrite;
new measurements or source changes require a separate epoch.
