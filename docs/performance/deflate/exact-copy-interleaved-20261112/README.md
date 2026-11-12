# Exact-copy bucket/interleaved prototypes: all rejected

**All three codec prototypes are rejected; no codec code is adopted.** V1's
12-row gain is about 1.02806x, v2 about 1.00523x with a control below 0.98, and v3's
small-screen 1.03129x does not survive the declared full 72-row expansion. V3
full-cold GM is **1.0051537516535274x**, 95% CI
**[1.0036886340104947,1.0066313157192643]**, with **nine rows below 0.98** and
weakest x-ray 64 KiB/L9 **0.9712646890844143x**. The aggregate and control gates
fail. These are development-host screens, not dedicated-host or industry
acceptance.

All epochs use immutable baseline
`21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d`, exact comparator
`a69c106fec63a70490be2dd57a76e233ddbaaaadcb37439d2d6abab52897a91f`.
The committed current-source refresh supplies only SHA-bound baseline source,
probe, fixture and library identity. Its 360-row reference timings are not mixed
into baseline/candidate optimization ratios.

## Three source/binary epochs and small screens

| Epoch | Copy schedule | Candidate comparator SHA-256 |12-row ordinary GM | Small-screen95% CI | Weakest row GM |
| --- | --- | --- | ---: | --- | ---: |
| V1 | Fixed-width head/tail buckets. | `7101064ccb2f11019bc2800ad64e9f30bd8cf0d9d6262acb3624877ae1947aa6` |1.028060765735492x |[1.0247440430786117,1.031231170343654] |0.9988604053150546x |
| V2 | Interleaved16-byte blocks within buckets. | `d836982fd00fec41f39a3b4afb0a75ffc948b320f091eb85a9612dc1f48c8521` |1.0052257636616815x |[1.0012720951150809,1.0092364394024478] |0.975901888099464x |
| V3 | Interleaved32-byte blocks with16-byte minimum/tail. | `4aff629c7845165041ec0bd74da76dd4036ccbcacdf13defaca6a88f81e7f682` |1.0312899868075671x |[1.0268493376240244,1.03584580623215] |0.9916537081517761x |

Each small screen has **160 events**: 96 ordinary wall events over twelve cold
rows plus 64 PMU events over four rows/two groups. Four AB/BA process pairs per
row/group each child use **two measured and two warmup Vort/reference pairs**,
320 measured and 320 warmup pairs per small epoch. The twelve ordinary rows
are Reymont/NCI/XML, 64 KiB/1 MiB, levels 6/9. PMU batches retain raw nine-word
IDs/full-running/cumulative time bindings and remain diagnostic context; their
control-overhead wall times are not throughput acceptance.

The source changes the non-overlapping copy helper. `src/deflate.zig` and
semantic decoder caller/error/reader source remain baseline bytes. Exact
source snapshots/hashes remain distinct. For compact storage, each changed
kernel is durable, three shared test-support files are stored once, and all
unchanged large source files are reconstructed from SHA-bound baseline/Git
identity. Full candidate registries contain 2075 files, baseline 2072.

V1/V2/V3 each pass the existing kernel3-test aggregate/import root and full
Deflate ReleaseSafe 738/738. Linux exact-span guard-page coverage records 1996
facade/core edge-position cases inside one aggregate: v1 Debug/Safe/x86 and
v2/v3 Safe runs are retained by their actual logs. All three separate 72-wire
smokes pass full output, exact consumption, guards and immutable input; smoke
clocks are excluded from performance data.

Checked contracts are **3..258-byte facade** and **16..258-byte core**, with
non-overlapping source/destination spans. Destination head/tail stores may
overlap each other. An assertion-disabled residual loop is retained in source,
but that is **not proof or a test of private lengths above 258**. No private
outlier contract is claimed. Test aggregates/imports are not 738 new behaviors.

## Final expanded full-cold protocol and rejection

Only v3 received this completed expanded 72-row screen. The raw expanded
protocol has **72 tasks, four sweeps, rounds=2, warmup=2, modes=[null], no PMU
keys**. It has **576 events**, **1152 measured pairs and 1152 warmup pairs**.
Those are the actual per-child parameters; the earlier six-round current-source
reference refresh is a separate operation. Some template description text is
retained in the original protocol, while its actual task/round/mode fields and
raw argv govern the effective expanded scope.

The 72 rows cover all twelve frozen Deflate corpus inputs, 64 KiB/1 MiB/full
sizes and levels 6/9. Each row has four balanced baseline/control process pairs,
with every process duration reduced from **all its two raw measured batches**.
`full-cold/recompute.py` and `independent-statistics.json` are original
main-authored independent reductions. Their fixed row order, AB/BA strata,
seed 0x20261112, 2000 resamples and CI order indices 50/1950 are preserved. The
verifier independently rebuilds every pair/row/size/aggregate statistic.

| Expanded size group | Speed GM |
| --- | ---: |
|64 KiB |1.010916446299873x |
|1 MiB |1.0019740093666376x |
| Full |1.0025955566448024x |

Ordinary speed ratios are baseline Vort median duration / candidate Vort median
duration. The full aggregate is **0.515% faster** at the center, below the 3%
bar; nine control rows also fail 0.98. The CI excludes parity but does not fix
those failures. The v3 small-screen gain is not reported as a full-corpus win,
and v1/v2 have no invented full 72 results.

| Full-cold control below 0.98 | Row GM |
| --- | ---: |
| `deflate_x-ray_65536_9_cold` | 0.971264689x |
| `deflate_x-ray_65536_6_cold` | 0.971721161x |
| `deflate_mr_1048576_6_cold` | 0.972308596x |
| `deflate_ooffice_65536_9_cold` | 0.973419911x |
| `deflate_x-ray_1048576_6_cold` | 0.974248125x |
| `deflate_ooffice_65536_6_cold` | 0.975563487x |
| `deflate_sao_65536_6_cold` | 0.976567014x |
| `deflate_sao_1048576_6_cold` | 0.976711144x |
| `deflate_x-ray_full_9_cold` | 0.977306959x |

The recorded target is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
`skylake+pku+sgx`, CPU 15 on Intel Core i7-10700K, one codec/benchmark thread.
libdeflate 1.26 uses matched cold alloc/decompress_ex/free lifecycle, pinned
revision `92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, GCC 11.4.0,
`-O3 -DNDEBUG -march=skylake`, library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
Original development-host powersave policy, source/build/size/fixture/library
and process observations remain in raw manifests. Empty compiler boundary
observations and process ticks do not establish an uncontended dedicated host.
No broader codec ratio or industry ranking is updated.

## Original codegen evidence and static limits

Four **original audit-agent tool stdout artifacts** are saved: same-round
baseline plus v1/v2/v3 disassembly, with original source paths and byte hashes.
No fresh capture replaces their epoch. `codegen-reported.json` is separately
attributed as an archive-composed record of Hume/coordinator-reported counters;
the verifier parses the actual originals and checks ELF byte identity.

| Static whole scalar symbol | Text bytes | Stack reservation | Instructions including padding | Vector-stack operand references |
| --- | ---: | ---: | ---: | ---: |
| Baseline |3659 |296 |897 |2 |
| V1 |4171 |696 |971 |28 |
| V2 |4017 |312 |963 |2 |
| V3 |3883 |312 |930 |2 |

These complete-symbol counts include cold/tail/error paths and padding.
Vector-stack references are static operands, not dynamic spills or isolated
instruction cost. They do not establish throughput, normalized binary equality
or private >258 correctness. The final whole-operation gate decides adoption.

## Compact durable contents and offline verification

| Artifact | Contents |
| --- | --- |
| Three `v*-kernel-source.tar.gz` files | Exact changed copy kernels, each with its original freeze/snapshot identity. |
| `shared-test-source.tar.gz` | Three byte-identical standalone kernel/page test-support files. |
| Three `v*-raw.tar.gz` files | All original top-level manifests/protocol/statistics/logs/validation/freeze records and run.py. |
| Three `v*-rows.tar.gz` and three `v*-smoke.tar.gz` files | All original per-child report/stdout/stderr/process data and source/order metadata. |
| `full-cold.tar.gz` | All 2314 expanded artifacts, including 2304 per-child files, complete protocol/ordering and original recompute.py/statistics. |
| `performance-probes.tar.gz` | Three necessary candidate performance comparators; shared baseline ELF is read and hash-verified from the committed refresh package. |
| `test-binary-identities.json` | All eleven original test executable SHA/size/source-epoch/log identities; test bytes stay external. Complete original build argv was not saved and is explicitly marked missing. |
| `original-codegen.tar.gz`, `codegen-reported.json` | Four original raw tool files and separately identified reported static table. |
| `runner-imports.tar.gz`, `fixture-replay-bindings.json` | Immutable 21e4 helper closure and exact existing 72-wire descriptors. |
| `full-cold-independent-statistics.json` | Exact readable copy of the original final main derivative. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal packing, independent validation, member/source/origin/container hashes, completed receipt and full inventory. |

The original test binaries account for most of the earlier 44MB archive. This
compact package retains performance probes and original codegen, plus full test
binary hashes, source epochs and logs. Missing original test build argv is
recorded explicitly; no command is fabricated as an original recipe.

Baseline source/probe/library and fixture identity reuse SHA-bound committed
refresh and predecessor archives. Only changed kernels/new shared test files
are stored; unchanged large source is independently reconstructed and checked
against frozen digests/Git blobs. The ordinary corpus remains external by hash,
without duplicating hundreds of MB. Original snapshot files are optionally
compared through `--originals`; no live trial source is substituted.

Archives use sorted GNU tar, regular 0644/binaries 0755, uid/gid/mtime zero,
empty owners, gzip level 9 with empty filename/mtime zero. Raw bytes, whitespace
and EOF stay unchanged. All archival work uses **CPU 0**.

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks all three epochs and exact raw ordering,
source/probe/fixture/library identity, logs/smoke/raw PMU data, original codegen
bytes/counters and the complete 72-row independent reduction/gates. It invokes
no compiler, test, codec, oracle, perf or benchmark. `pack.py --finalize` refuses
archive overwrite. The completed rejection is final for these source epochs;
no new performance sampling is part of packaging.
