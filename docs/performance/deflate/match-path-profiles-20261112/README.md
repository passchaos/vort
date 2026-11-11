# Deflate NCI and Reymont match-path profiles

These are **whole-process diagnostic samples** of the public cold Deflate
operation against pinned libdeflate 1.26. NCI 64 KiB/L9 spends a larger local
sampled fraction in wide-copy setup/kernel/fallback than Reymont 64 KiB/L6.
That guides match-path experiments; it does not attribute dynamic retired
instructions or measured throughput to an isolated region.

The new NCI capture uses frozen revision
`492a0a74535992cd4a7e3ad3182777414c8c0fac`. Reymont retains its original
`8adfb3bae74409bae146fed2ed9b6594a1d3cdb8` packet unchanged, with a new
separately archived offline physical annotation. Both probes are byte-identical,
SHA-256 `2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14`;
source epochs, fixtures and raw capture receipts remain distinct.

## Recorded operation and sampling scope

| Profile | Plain/wire bytes | Iterations per side per pair | Capture samples | Root samples | Whole-process physical root | Physical reference |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Reymont 64 KiB/L6 | 65,536 / 18,792 | 30,000 | 2681 | 1554 | 58.02% | 36.53% |
| NCI 64 KiB/L9 | 65,536 / 4,836 | 60,000 | 1244 | 578 | 46.93% | 36.18% |

Each capture has two warmup pairs and two measured pairs with alternating
Vort/reference order. Vort calls `decodeRawDeflate`; libdeflate allocates,
decodes through `libdeflate_deflate_decompress_ex`, then frees its decompressor.
Every iteration validates returned count; each batch validates full output,
input/output guards, unchanged input and exact consumption on both sides.
NCI raw stdout records the 64-byte guards and aligned buffers. The existing
NCI comparator build log reports 7/7 success.

Perf records `cycles:u` at 199 Hz with `dwarf,65528`, on CPU 15 of an Intel
Core i7-10700K, one codec/benchmark thread. Vort is Zig 0.16.0 ReleaseFast,
x86_64 Linux GNU, `skylake+pku+sgx`. The reference is libdeflate 1.26 at
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, GCC 11.4.0,
`-O3 -DNDEBUG -march=skylake`, shared-library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
The original development-host powersave/intel_pstate environment and boundary
process observations are retained. Boundary tick records do not establish
timed overlap or a dedicated-host acceptance condition.

NCI perf.data retains 81,546,392 bytes; perf stderr reports 77.754 MB and
1244 samples. NCI whole-process sampled period is 30,057,120,959; Reymont is
65,407,305,645. Both physical reports show zero lost samples. The capture
includes warmups, both implementations, harness and validation. No complete
Vort-only/public-root denominator or codec heap measurement is available.
Profile clocks are excluded from candidate A/B acceptance samples.

## Derived local-period region comparison

`regions.json` is the **main-authored summary of read-only audit messages**,
not an original partitioning-script/nm stdout artifact. Its annotation hashes
bind the exact retained physical reports for the symbol address range
`[18084160, 18087797)`, `deflate.semantic.linear_entry.aligned`.

| Local sampled region | Reymont | NCI |
| --- | ---: | ---: |
| Literal | 28.58% | 23.84% |
| Match fields | 23.70% | 15.99% |
| Consume/preload/refill | 19.26% | 17.80% |
| Short copy | 12.79% | 7.25% |
| Wide setup/kernel/fallback | 4.31% | 20.79% |
| Entry dispatch | 6.62% | 6.26% |
| Copy dispatch/RLE | 2.13% | 3.79% |
| Loop limits | 2.30% | 3.47% |
| Prologue/cold tail/error | 0.25% | 0.86% |
| Original rounded sum | 99.94% | 100.05% |

The denominator is each root's **local sampled period**, with cycle sampling
and skid. Rounded sums are preserved, not renormalized. The separately
reported stack mov load/store/cmp values are Reymont 6.37/0.97/3.73% and
NCI 6.93/0.36/2.60%; they overlap these regions and cannot be added to them.

The coordinating audit separately reported pure wide-kernel local fractions
of **2.32% Reymont versus 16.79% NCI**. That task-provided observation is not
one of the nine region columns or a newly reconstructed raw partition. No
original script for that narrower attribution is claimed. A checked completed
match descriptor might reduce copied parameters across consume/preload/refill;
actual materialization, scalar fallback and whole-operation A/B still need
their own evidence. This packet does not accept that prototype.

## Original registry and separate replay addendum

The unchanged NCI manifest and capture-validation register **2048 files**,
digest `ca749da163882c8d358b32e95602110b71b4987fafbebc96330dbbb7aaacf529`.
`matrix.source_state` omitted 15 build modules that the earlier Reymont
manual `complete_registry` included. NCI also includes the subsequently added
public-linear test file. Thus 2062 old records become 2048 capture records;
the original list is not a complete compiler-input claim.

`build-source-addendum.json` and its archive are a **later main-authored
reconstruction** from immutable Git 492a0a74 blobs. Those 15 module hashes
match the earlier recorded baseline. Appending them yields a **2063-file
replay inventory**, digest
`32546e939bea56b5b2122482e0383a2bce3769e4f6146bcf0684d31128692075`.
The raw 2048 manifest/capture-validation bytes remain unchanged. The verifier
checks both identities and their provenance separately.

## Artifacts and existing packet reuse

| File | Contents |
| --- | --- |
| `nci-raw-profile.tar.gz` | All 14 retained NCI raw files: perf data, capture runner/manifest/command/execution/receipt/log, stdout/stderr, build log, physical symbols and annotate reports with empty report stderr. |
| `reymont-offline-annotate.tar.gz` | Newly saved physical annotate text and empty stderr, separately bound to the unchanged old capture. |
| `nci-fixture-bytes.tar.gz` | Exact original NCI plain/wire, 70,372 retained bytes. |
| `nci-runner-dependencies.tar.gz` | Frozen evidence/fixtures/matrix modules and exact original Sao seed manifest. |
| `build-source-addendum.tar.gz` | 15 immutable Git build files plus the separately attributed reconstruction JSON. |
| `capture-validation.json`, `build-source-addendum.json`, `regions.json` | Exact readable copies of original capture, later reconstruction and message-derived summary. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Container/member identity, origins, offline verification, receipt and checksum inventory. |

The original `deflate/reymont-profile-20261112` packet is reused without
modification. Baseline source/probe archives come from
`br/decode-mozilla-distributions-20261112`, the three public-linear source
changes from `deflate/public-linear-contracts-20261112`, and the reference
library from `modern-decode-current-20261111/reference-libraries.tar.gz`.
Every reused container and every file of the old Reymont packet is hash-bound.
The independent verifier reconstructs the frozen source; live modified
production files are never used. No duplicate large baseline binary, full
source or original Reymont perf.data is stored here.

Archives use sorted GNU tar, uid/gid/mtime zero, empty owners and gzip level 9
with empty filename/mtime zero. Raw bytes, whitespace and EOF are preserved.
Packaging and verification run on **CPU 0**, separately from captures on CPU 15.

## Offline verification and later reproduction

From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks original/raw source, addendum,
probe/reference/fixture bindings, capture commands/exits/target/thread policy,
recorded paired counts and medians, perf file/sample/report totals, annotate
identities, unchanged previous packet and original derived percentages. It
compiles no code, performs no decompression and collects no new samples.
Optional checks compare retained originals and both frozen Git revisions.

To reproduce later, restore exact fixtures/probe/reference in a separate
checkout and use a derived copy of the archived capture runner and its
imports. Its original absolute paths identify the captured checkout; changing
paths or source creates a new capture epoch with its own raw outputs, command,
source registry, environment observations and validation receipt.
