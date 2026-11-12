# PMU batch counters and bounded branch-miss profiles

This is **diagnostic evidence**, with no codec prototype adoption, throughput
acceptance or industry ranking update. It records a newly instrumented three-
probe cohort, separate disabled-counter controls and four physical branch-miss
captures. The measurements constrain the observed instruction/cycle/miss
behavior; they do not establish a root cause for the owner-only regression.

Base revision is `485ca30f2c61dd57673dd04e996a69171081e194`. Compiler/measurement
source is the frozen **common10** epoch. A later **final-tool10** snapshot changes
only `matrix.py` and `evidence_test.py` to mark PMU summaries/CSV as diagnostic.
It was saved in `07523cb9fb82825f47b5d799b5240297d50352c7`. The original probes
were not rebuilt for that Python metadata correction; old common-source bytes
remain unchanged and are not replaced by final tool source.

## Exact cohort and completed validation

| Cohort | Newly instrumented comparator SHA-256 |
| --- | --- |
| baseline | `75cde056539cf5ac164a3bcdd41efa5a2cd327e0a7aa97e615160bbec90287e4` |
| owner-word | `bfc95dd40cc7b31da52d6941427da1d16e2eaeb0420fbae789bc8c43644ce115` |
| owner-only | `e646296c2a646103b80876e3cb8e6712867ddd87a2a06b3115eff390f446cbb2` |

The captured source registries contain baseline **2072**, owner-word **2074**
and owner-only **2074** files. Library source/prototype overlays are reused by
exact frozen bytes; every cohort uses the same instrumented common10 and its
own new probe. Previous wall-time or code-layout identities are not transferred
to these measurements. Registry contents are verified, with no complete
compiler-input claim.

Original tool gates pass **13 Zig tests** (eight sampling and five pure PMU)
and eight initial Python tests. After the metadata correction, **nine Python
tests** pass. Unit tests exercise synthetic raw group-read contracts; separate
hardware/codec smoke exercises real Linux PMU reads. Original logs, probe
build receipts and compiler RSS are preserved. Compiler RSS is not codec heap.

The pilot has **144 child events**: **48 disabled-counter wall controls** and
**96 PMU events**, four process sweeps for each of four cases and three variants.
Each child has two measured Vort/reference pairs and two warmup pairs: **288
measured pairs and 288 warmup pairs**. PMU-only data comprises **192 measured
and 192 warmup counter reads**. There are also six other-codec PMU smoke events
and two initial Deflate hardware checks. Those smoke clocks are not performance
samples.

## Counter domain, raw validity and ratio orientation

The PMU domain is the calling thread's **Vort decode loop, count/mix bookkeeping
and userspace enable/disable boundary**. Clock reads, reference decoding and
full validation remain outside counters. Kernel and hypervisor are excluded;
no inheritance or silent scaling is used. PMU wall duration includes control
overhead and is not a throughput-acceptance metric. Disabled-counter controls
remain separate and are also interpreted within this diagnostic pilot.

Each group reads exactly nine u64 words: `nr=3`, raw cumulative enabled/running
time, then three value/ID pairs. Semantic order is cycles, instructions and
branches or branch-misses. The verifier checks the exact three unique IDs,
raw/semantic bindings, positive cycles/instructions/time, complete running
(equal enabled/running), and strictly advancing cumulative header time over
the same FD. RESET clears counts, not those cumulative time fields. Branch
misses may be zero. No per-batch time is fabricated from cumulative headers.

`paired-summary.json` is a **main-authored independent derivative** bound to
original `events.json`. It retains four paired candidate/baseline ratios for
each metric and a 2000-resample balanced process-order bootstrap with seed
`0x20261112`. The independent archive verifier recomputes raw medians, ratios,
geometric means and intervals with floating tolerance 1e-12. Ratio orientation
is **candidate cost / baseline cost**; values above one mean more duration or
counter work, not higher speed.

| Case, branch-miss group | Owner-word cycles / instructions / misses | Owner-only cycles / instructions / misses |
| --- | --- | --- |
| `deflate_reymont_65536_6_cold` | 0.996255 / 1.048541 / 0.938394 | 0.979707 / 1.000568 / 0.935225 |
| `deflate_nci_65536_9_cold` | 0.976469 / 1.020424 / 0.795555 | 1.101504 / 0.991871 / 1.738043 |
| `deflate_xml_65536_6_cold` | 1.006036 / 1.023743 / 0.951978 | 1.092142 / 1.000266 / 1.494908 |
| `deflate_nci_1048576_9_cold` | 1.006048 / 1.010369 / 0.993448 | 1.008290 / 0.999925 / 0.999887 |

For owner-only NCI 64 KiB/L9, instructions are approximately unchanged,
cycles increase about **10%**, and misses about **74%**. XML 64 KiB/L6 shows
approximately unchanged instructions, about **9%** more cycles and **49%** more
misses. Whole-operation counters cannot isolate preparation, refill, copies
or frontend stalls, and these observations do not identify a cause.

The target is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU `skylake+pku+sgx`,
CPU 15 on Intel Core i7-10700K, one codec/benchmark thread. Deflate uses
libdeflate 1.26 with matched cold allocation/decode/free lifecycle; other-codec
smoke uses pinned Zstd 1.6.0 cold/prepared and Brotli 1.2.0 cold APIs. Exact
library bytes, versions, inputs, compressed sizes, loaded mappings, original
host/powersave policy and process observations are retained. All batches check
returned count, full output, guards and immutable input. Exact consumption is
verified **for Deflate**; the selected Zstd/Brotli APIs do not expose it.

## Physical profiles and exact-IP scope

The four saved `perf.data` records are NCI/XML 64 KiB versus baseline/owner-only.
Each case/variant has **one recording**, with 500 iterations, two warmup and
two measured pairs, hence **2000 known Vort calls**. Perf sampled
`branch-misses:upp`, period 1000, requested precise_ip 2, on CPU 15 with a frame-
pointer call graph. Its whole process also contains reference/harness activity;
only declared native Vort sample-IP domains are used. The call graph is not a
complete-unwind or complete-public-decoder denominator.

| Recording | All saved samples | Bounded samples | cmp/jbe weighted sample-period per Vort call |
| --- | ---: | ---: | ---: |
| NCI baseline | 1825 | 1078 | 58.5 |
| NCI owner-only | 2294 | 1589 | 388 |
| XML baseline | 2543 | 1489 | 104 |
| XML owner-only | 2850 | 1823 | 472 |

All **9512** saved sample records have `misc=0x4002`: exact-IP and user mode.
No LOST/LOST_SAMPLES records are present in those saved data/dumps. The verifier
parses binary perf headers/records directly, matches every sample IP to the
raw dump and sample text, and independently rebuilds bounded domain weights.
It never invokes perf. These are period/call sampled-IP estimates, not exact
per-branch miss counts or mixed-process percentages.

The caller domain is `raw_caller_all_routes`: parsing, preparation, dispatch
and every selected route, not preparation-only. `compare.decodeOnce__anon_5293`
in `baseline-decode-once.objdump.txt` is a **Zstd specialization**, explicitly
excluded from Deflate preparation evidence.

## Static scalar and exact inner-loop limits

New main CPU 0 nm/objdump captures preserve the original static bytes; they
are not claimed as an earlier audit agent's raw tool output. The ordinary
scalar `.aligned` symbol is **3659 bytes / stack296** for baseline versus
**3649 bytes / stack312** for owner-only, with real register/control-flow
changes beyond relocation. The latter has 902 static instruction lines versus
897, including cold/tail/padding. Static counts are not dynamic spill or
retired-instruction costs.

Only the **26-byte sixteen-byte copy-loop body** is byte-identical:
SHA-256 `dc84e82411b2f8ade64306811733d766d83514546f5b3c359786b07e53b7a743`.
This does not make the full scalar functions equivalent. Large sampled miss
weight is observed at that loop's cmp/jbe IPs; the one-record estimate and
identical local bytes do not establish why the surrounding operation regresses.
`copy-loop-analysis.json` preserves this narrow identity and its explicit
`cause_proven=false`/`exact_counters=false` scope. No prototype is adopted.

## Durable artifacts and offline checks

| Artifact | Contents |
| --- | --- |
| `common-source.tar.gz` | Exact original ten compiled/measurement helper/build files, including pre-correction Python bytes. |
| `final-tool-source.tar.gz` | Exact later ten tool files, kept as a separate epoch. |
| `probes.tar.gz` | Three exact new instrumented ELF comparators. |
| `raw-diagnostics.tar.gz` | Every original top-level log/manifest/protocol/event/summary/smoke/static/producer file and run.py. |
| `rows.tar.gz` | All 576 original per-process report/event/exit/stdout/stderr files. |
| `branch-sampling.tar.gz` | All 35 original perf data, sample texts, raw dumps, attrs, commands, bounded/exact-IP receipts and recording metadata. |
| `runner-imports.tar.gz` | Original matrix/evidence/pmu_evidence and immutable fixtures helper closure. |
| Readable source/probe/final-tool/producer/paired/copy-loop JSON files | Exact original receipt copies. |
| `saved-tool-commit.json`, `fixture-fields.json` | Separate final-tool Git identity and scoped original fixture field registry. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal archive construction, independent verification, member/container/origin identity, successful receipt and complete checksums. |

Source/library/prototype bytes are reconstructed from SHA-bound existing
committed packets and exact overlays. No ordinary corpus bytes are duplicated.
Only the **four diagnostic Deflate cases/eight files plus the other-codec smoke
fixture fields** are checked; the scoped registry has six tasks/ten unique
external files. `--originals` verifies only those external inputs and saved
packet originals, not the full ordinary corpus.

Archives are sorted GNU tar, regular0644/probes0755, uid/gid/mtime zero,
empty owners, gzip level9 with empty filename/mtime zero. Original bytes,
whitespace and EOF stay unchanged. Every archive check runs on **CPU 0**,
separately from recorded CPU 15 measurements.

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks raw identity, all source/probe/library
bindings, complete unscaled PMU reads, paired/physical scopes and statistics,
scoped codec/hardware smoke, exact-IP binary/dump records, the narrow copy-loop
identity and the separate final-tool Git blobs. It runs no compiler, test,
codec, oracle, perf or benchmark. `pack.py --finalize` writes archives only
from terminal original inputs and refuses overwrite; reproduction requires a
fresh output directory and the referenced exact input packets.
