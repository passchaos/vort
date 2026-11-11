# Fresh decoder evidence, 2026-11-11

The [Chinese overview](../modern-decode-refresh-20261111.md) presents this
completed refresh. The measured source is the validated commit
`ea193be259579ceda476c9278dd726fbfaec7e51`, with source digest
`dd10145c489b1105e50e13ff249d7ecf68a557208a43deb8937b740684814a37`.
The main worktree's unrelated DirectChunk repair was in flight at measurement
start and is excluded. This round records measurements and evidence; it adopts
no codec acceleration.

All **360 rows** completed: 216 matched cold, 72 matched Zstd prepared, and
72 Deflate reference-only prepared. They retain **2,160 measured pairs** and
**720 warmup pairs**. Cold throughput geometric means are **68.7698955554%**
of libdeflate 1.26, **76.5594350577%** of libzstd 1.6.0, and
**80.8553881016%** of libbrotli 1.2.0. The overall estimates use all 72 fresh
fixed rows per codec/lifecycle and all six pairs per row; they are not derived
from an older epoch. The paired-log bootstrap retains AB/BA strata and uses
recorded seeds with 2,000 resamples.

## Exact contents

| Artifact | Preserved content |
| --- | --- |
| `raw-rows.tar.gz` | Exact 360 row JSON files, 360 empty stderr files and 360 RSS sidecars. All raw pair clocks, mixes, paths, APIs, sizes, hashes and validation flags remain intact. |
| `metadata.tar.gz` | Exact 20 original metadata files, including manifest, packet, aggregate/validation/summary, run log, CSV, host observations, source freeze, initial/build provenance, command, adapter and original live verification script. |
| `manifest.json.gz`, `packet.json.gz`, `source-freeze.json.gz` | Exact original payload bytes compressed with a zero gzip timestamp. The source registry binds all 2,029 files. |
| `aggregate-summary.json`, `summary.json`, `validation.json` | Exact original readable overall, per-size/lifecycle and validation records. |
| `matrix.csv.gz` | Exact original CSV, including CRLF line endings. |
| `matrix.csv` | Readable LF-only derivative; every row and field is identical. |
| `probe-stdout-json.tar.gz` | 360 derived pretty JSON views of the complete structured probe stdout values retained in `row['probe']`. |
| `host-observations.jsonl.gz` | Exact 360 before/after row observations, including load, process ticks, compiler presence and power fields. |
| `host-before-measurement.json`, `host-after-measurement.json` | Exact boundary captures. The final capture preceded the main agent resuming functional builds. |
| `source-snapshot.tar.gz` | Exact bytes of all 2,029 frozen source-registry files, verified against the committed Git blobs. There is no codec source overlay. |
| `probe.tar.gz` | Exact measured `bin/vort-decode-compare`, SHA-256 `5efe3eac0e58bc9f44350096002dc26161f80d48bbeda34f1ff2930c1bd15ea0`. |
| `reference-reuse.json` | Explicit links and byte hashes for the original reference-library/build-metadata archives; the same five binaries are reused. |
| `archive-bindings.json` | Container and member hashes, metadata policy, exact/readable payload bindings and stdout scope. |
| `verify.py`, `verify_test.py`, `validation-receipt.json`, `SHA256SUMS` | Independent offline validator, disposable-copy corruption tests, packaging-time receipt and complete package checksum inventory. |
| `independent-stats-review.json` | Separate read-only standard-library audit of all overall/size results, rounded overview figures, weak rows and host counts. |

The committed matrix runner parsed the child stdout into `row['probe']` and
did not retain the original stdout text bytes. All structured values, including
every integer clock and sample, are losslessly retained. The separate stdout
views are clearly labeled derivatives; their whitespace/number formatting is
not claimed to be the original stream. The exact raw row JSON, stderr, RSS and
runner log are preserved. No measurement was rerun to recreate stdout.

Every new tar uses GNU format, lexicographic members, uid/gid/mtime zero and
empty owner names. Regular source/data files use mode 0644; the measured binary
uses 0755. Gzip uses level 9, an empty filename and mtime zero. All reference
archive members, licenses and symlinks retain the original package's bindings.

## References, corpus and API lifecycle

The package reuses the byte-identical binaries and build provenance in
[`modern-decode-current-20261111`](../modern-decode-current-20261111/README.md),
specifically
[`reference-libraries.tar.gz`](../modern-decode-current-20261111/reference-libraries.tar.gz)
and
[`reference-build-metadata.tar.gz`](../modern-decode-current-20261111/reference-build-metadata.tar.gz).
`reference-reuse.json` records both container hashes, every file/symlink binding,
the selected binaries' original paths, and their hashes. Reference binaries are
not duplicated in this directory.

| Reference | Source revision | Selected binary SHA-256 |
| --- | --- | --- |
| libdeflate 1.26 | `92e6a0db9fa848d742f9eb286c92afc60f2c3dda` | `1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28` |
| Zstd 1.6.0 | `01b7154f1172432f8abe9b3bb9909e14a1176b7d` | `ff67de9643e7cc0ce88265af3a6f4503c09ef107c094186980484751914ac9c8` |
| Brotli 1.2.0 encoder | `558fc647cdaf391228d614ca85f711e02e4e583b` | `916611262bd0975d4b75e6a19d957de5747eb182f2c36022a459bd21b6e40b6d` |
| Brotli 1.2.0 decoder | Same Brotli revision | `916a4e22b249bb9b5024ed6d6956431fbcdea31f0cf157474de36c529a961750` |
| Brotli 1.2.0 common | Same Brotli revision | `d049d028ce0ee836b2f90579b1fba73ac2c8cdde4e2014721eb93c107a399dfb` |

libdeflate has no runtime version API; its version is declared from the pinned,
hashed public header. Zstd and both Brotli ABI versions are queried, and every
row proves the selected actual mapped library closure. References retain the
recorded GCC 11.4 Release/Skylake flags. The probe uses Zig 0.16.0 ReleaseFast,
x86_64-linux-gnu and `skylake+pku+sgx` on logical CPU 15.

The twelve Silesia inputs are dickens, mozilla, mr, nci, ooffice, osdb, reymont,
samba, sao, webster, xml and x-ray. Sizes are first 65,536 bytes, first 1,048,576
bytes and full input. Deflate uses producer L6/L9, Zstd L3/L19 and Brotli q6/q11.
All 216 frozen wires and 36 plain inputs were SHA-verified and reused without
recompression. The manifest retains every length, first plain byte, SHA and
producer setting, including Python zlib 1.2.11 raw mode, Zstd compression and
Brotli window 22/generic mode. The payloads remain in the original frozen
directory and are not duplicated here.

| Comparison | Vort API | Reference API |
| --- | --- | --- |
| Deflate cold | `decodeRawDeflate` | alloc + `libdeflate_deflate_decompress_ex` + free every decode |
| Deflate reference-only prepared | Same public `decodeRawDeflate` | retained decompressor |
| Zstd cold | `decodeFrameInto` | `ZSTD_decompress` |
| Zstd matched prepared | retained `NativeFrameDecoder.decodeIntoSlice` | retained `ZSTD_decompressDCtx` |
| Brotli cold | `brDecodeStreamInto` | `BrotliDecoderDecompress`, including one-shot state/internal heap handling |

Brotli has no supported matched prepared-reset API in this probe. Output/input
buffers are allocated outside timing; selected cold APIs' internal creation,
allocation and cleanup are included. Context priming, file I/O, library loading
and post-batch full validation are outside timing. Each side performs 100/20/1
decodes per batch for 64 KiB/1 MiB/full. Counts are checked per call; complete
output, unchanged input/wire, 64-byte guards and exposed consumption counts are
checked after each batch. Deflate exposes exact consumption; selected Zstd and
Brotli APIs do not expose it. RSS is whole-child peak, not codec-only heap.

## Host observations

Intel Core i7-10700K, Linux 6.8.0-79, glibc 2.35, CPU 15;
`intel_pstate`/`powersave`, turbo enabled. No compiler process was present in
any of the 360 row-boundary observations. Load1 ranged from 0.3125 to
1.30810546875. Positive tick changes for shared before/after PIDs appeared in
272 whole-child scopes, mainly traex. These use total process ticks and
last-seen CPU labels; they do not prove overlap with specific timed batches.
The archive keeps all snapshots and the final pre-compile capture.

This is a development-host observational comparison. The fixed-row confidence
intervals cover sampling uncertainty within the recorded host/corpus, not
changes of host, corpus or power policy. No industry-leadership or dedicated
performance-host acceptance claim is made.

## Verify without decoder or benchmark execution

```sh
cd docs/performance/modern-decode-refresh-20261111
sha256sum -c SHA256SUMS
python3 verify.py
python3 verify_test.py
```

The standalone verifier uses only Python's standard library. It checks exact
archive/payload bytes and normalized metadata, the complete 360-row task grid,
all raw counts/mixes/order/medians/validation flags/API/library/CPU bindings,
all stderr/RSS/CSV fields, the 2,029-file source snapshot, and the reused
reference packages. It independently recomputes all fifteen size and five
72-row aggregate bootstrap results and their recorded endpoints, weak rows,
pooled rates and host observations. It reads preserved evidence and never
executes the measured decoder.

To repeat the optional live checks, use the frozen isolated EA193 worktree,
not the dirty main tree:

```sh
python3 verify.py \
  --live-root /home/passchaos/project-z/vort-decode-refresh-20261111.ea193be2 \
  --fixture-root /tmp/vort-current-decode-matrix-20261111/fixtures
```

The packaging receipt records all 2,029 current files and committed Git blobs
matching the source snapshot, plus all 252 unique live plain/wire file hashes.
The original temporary adapter/verification scripts and exact build/matrix
commands are in `metadata.tar.gz` and `command.json`. A future measurement
must use a new epoch; this archive is the finished current comparison.
