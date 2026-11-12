# Current-source modern decode refresh

This completed refresh compares **current committed Vort source** against the
pinned modern reference libraries. All matched cold aggregate throughput ratios
remain below parity: Deflate **0.6886700186021341x**, Zstd **0.76584445537077x**,
Brotli **0.8192795429891954x**. These are fixed-corpus development-host results,
not an industry leadership or dedicated-host acceptance claim.

Source revision is `21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d`, captured registry
**2072 files**, digest
`fcfefbcabf545b7e321426f227e03c7a752a862a6f891e56be91c72b8882e711`.
Exact comparator SHA-256 is
`a69c106fec63a70490be2dd57a76e233ddbaaaadcb37439d2d6abab52897a91f`.
The source checkout was
`/home/passchaos/project-z/vort-wide-copy-baseline-20261112.21e4a1d0`.
Only its frozen baseline comparator/source is included; isolated codec trial
sources and outcomes are outside this ranking.

## Aggregate ratios and API lifecycles

Ratios use **Vort elapsed time / reference elapsed time**; throughput ratio is
its reciprocal on identical plain bytes. A reference throughput of 1.0 means
Vort achieves the following fraction, rather than a percentage-point speed gain.
CI columns are time-ratio intervals, estimated from all raw measured pairs.

| Codec/lifecycle | Throughput ratio | Time ratio | Time-ratio 95% CI | Comparison scope |
| --- | ---: | ---: | --- | --- |
| deflate/cold | 0.688670019x | 1.452074249x | [1.450315761, 1.453861631] | Matched cold raw decode vs alloc/decompress_ex/free. |
| deflate/prepared | 0.688738450x | 1.451929975x | [1.450119074, 1.453808321] | Reference-only retained decompressor; Vort remains decodeRawDeflate. |
| zstd/cold | 0.765844455x | 1.305748175x | [1.303766542, 1.307696522] | Matched decodeFrameInto vs ZSTD_decompress. |
| zstd/prepared | 0.776992457x | 1.287013782x | [1.285392643, 1.288706885] | Matched NativeFrameDecoder.decodeIntoSlice vs retained ZSTD DCtx. |
| brotli/cold | 0.819279543x | 1.220584608x | [1.219236759, 1.221993795] | Matched brDecodeStreamInto vs one-shot BrotliDecoderDecompress. |

Deflate's prepared rows are labeled **reference-only-prepared**, with no
reusable Vort decoder lifecycle claimed. They are kept separate from matched
prepared Zstd. No Brotli prepared/reset comparison is included. Preparation
priming is recorded outside measured pairs, and the exact per-row API names
and lifecycle-match fields are retained.

The reference versions are **libdeflate 1.26**, **Zstd 1.6.0** and **Brotli 1.2.0**.
Exact source revisions are respectively
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`,
`01b7154f1172432f8abe9b3bb9909e14a1176b7d`, and
`558fc647cdaf391228d614ca85f711e02e4e583b`.
Their shared-library bytes, licenses, ABI/version-query origins and mappings
are hash-bound through the existing reference archive. Builds record GCC 11.4.0,
release `-O3 -DNDEBUG -march=skylake` for Deflate/Zstd and Brotli release
`-O3 -march=skylake`. Vort is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
`skylake+pku+sgx`.

## Complete matrix, raw samples and weakest rows

All **360 rows** complete: 216 matched cold rows, 72 matched prepared Zstd rows,
and 72 reference-only prepared Deflate rows. There are **2160 measured
Vort/reference pairs** and **720 warmup pairs**. Every child runs six measured
pairs and two warmups, alternating implementation-first order. Each pair is a
batch of 100 decodes per side at 64 KiB, 20 at 1 MiB, or 1 at full-file size.
These are pair/batch counts, not 2160 individual decodes.

The frozen corpus has 12 Silesia inputs at 64 KiB/1 MiB/full size: 36 plain slices
and 216 original encoded wires, two levels per codec (Deflate 6/9, Zstd 3/19,
Brotli 6/11). Those prior wires are **not regenerated**. Each row records exact
plain/compressed sizes, hashes and generator metadata. Full output, guards,
unchanged input and every iteration's output count are validated. Exact input
consumption is checked for Deflate; selected Zstd/Brotli APIs do not expose it.

| Aggregate group | Weakest paired-mean row | Throughput ratio |
| --- | --- | ---: |
| deflate/cold | `deflate/mr/65536/9` | 0.603499417x |
| deflate/prepared | `deflate/mr/65536/9` | 0.605126367x |
| zstd/cold | `zstd/mozilla/1048576/3` | 0.599133567x |
| zstd/prepared | `zstd/mozilla/1048576/3` | 0.594089773x |
| brotli/cold | `brotli/mozilla/full/11` | 0.484579157x |

Per-row CSV time ratios use the ratio of measured medians. Group and weakest
row statistics use **means of paired log ratios**. Those are distinct summaries
and are independently recomputed from their appropriate raw inputs.

`aggregate-summary.json` is a main-authored all-raw-row derivative. Its five
72-row groups each use 2000 order-stratified bootstrap resamples and seed
`0x20261112`. `aggregate-row-order.json` preserves the **actual unsorted source
row-directory glob order**, then codec/lifecycle filtering preserves that order.
Sorting the files lexically gives the same center but can change finite-
bootstrap CI endpoints; the verifier uses the recorded original order.

The original matrix `summary.json` separately contains 15 size/lifecycle groups,
24 rows each. Its seeds are **0x20261111 plus sorted group index**, retained
exactly as recorded. The verifier recomputes both the 15 original size summaries
and five aggregate summaries, including raw centers/CI/weakest values. It
collects no new samples and does not relabel bootstrap derivatives as reruns.

## Host, memory scope and initial affinity failure

The host is Intel Core i7-10700K, CPU 15, one codec/benchmark thread, Linux
GNU environment. The recorded governor is **powersave**, driver **intel_pstate**,
with turbo enabled. This is a development host without fixed-host performance
acceptance. All 360 child-boundary compiler observations are empty; load1 spans
[0.1767578125,1.29638671875]. Process ticks/last-seen CPU values do not locate
actual timed-batch overlap or establish an uncontended host.

Per-row RSS is the **whole isolated child**, including loaded libraries,
input/output buffers, validation and contexts, and covers both implementations.
It is not codec-only heap or a Vort/reference memory attribution. Raw `/usr/bin/time`
RSS files and before/after process observations remain bound to each row.

An initial **CPU 0-only launcher** failed available-affinity validation with
`Benchmark CPU is outside available affinity`. The44-byte original
`startup-affinity.log` is preserved. No rows were sampled before correction.
The successful launch initially allowed CPUs {0,15}; `source_state` then pins
runner work to CPU 0 and every codec child independently uses `taskset -c 15`.
This is setup provenance, not a decoder failure.

Source and generic benchmark-tool epochs changed relative to 2026-11-11.
This refresh is not a matched before/after optimization experiment, so numerical
changes from older snapshots are **not attributed to codec gains**. Current
copy experiments or read-only implementation studies do not enter these ratios.

## Durable artifacts and source/fixture reuse

| Artifact | Contents |
| --- | --- |
| `raw-refresh.tar.gz` | All original top-level manifest/reference/summary/aggregate/order/CSV/log/affinity/host/producer files and refresh.py. |
| `raw-rows.tar.gz` | All 1800 original per-child JSON, raw stdout/stderr, text stderr and RSS files. |
| `probe.tar.gz`, `probe-build.tar.gz` | Exact baseline comparator and its successful 7/7 build log, without trial artifacts. |
| `runner-imports.tar.gz` | Immutable 21e4 matrix/evidence/pmu_evidence/fixtures dependency closure. |
| `fixture-fields.json` | Original 216 wire/36 plain path/hash/size/generator fields; large bytes remain external. |
| Readable aggregate/order/summary/producer JSON files | Exact original copies, with original finite-bootstrap ordering. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal packing, independent validation, member/origin/container identity, receipt and complete checksums. |

The 2072 captured sources are reconstructed from SHA-bound accepted source
archives and exact overlays, then checked against immutable 21e4 Git blobs.
The existing modern reference archive supplies exact library bytes. The old
accepted fixture manifest and original fixture-only runner seed are opened and
compared by key; their old timings are not reused. All 216 wires/36 plain files
are external and optionally hash-checked by `--originals`; no large corpus is
duplicated in Git.

Archives use sorted GNU tar, regular 0644/probe 0755, uid/gid/mtime zero,
empty owners, gzip level 9 with empty filename/mtime zero. Original raw bytes,
whitespace and EOF remain intact. Packing and every check use **CPU 0**.

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks all source/probe/library/fixture closures,
360 raw rows and corresponding RSS/commands/host records, six measured/two
warmup pairs each, exact lifecycle and consumption scopes, original aggregate
row order, every size/aggregate bootstrap and producer hash binding. It invokes
no compiler, test, codec, oracle, perf or benchmark. `pack.py --finalize` writes only
from final producer-bound inputs and refuses archive overwrite; new source or
measurement work requires its own epoch.
