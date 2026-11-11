# Deflate reader screens, 2026-11-12

This package preserves two rejected whole-operation cold experiments: length
prefix/total/code/extra preparation and an isolated shared semantic refill count
update. Both use exactly twelve selected rows: reymont/nci/xml, 64 KiB/1 MiB,
levels 6/9. Each screen retains 96 successful child reports: four outer B/C process
pairs per row, alternating B,C / C,B / B,C / C,B.

| Screen | Twelve-row speed geomean | reymont64K L6 target | Weak controls |
|---|---:|---:|---|
| Prefix fields | 1.0099839656880558x | 1.0486816351474246x | nci64K L9 0.9388454925030074x; L6 0.976816351013917x |
| Refill count | 0.9611664352386534x | 1.0183349950846656x | nci64K L9 0.910305832088486x; xml64K L6 0.8392420174654576x; L9 0.8791255099688111x |

The validator independently computes each process median from the two timed
Vort batches, divides baseline median by candidate median, then takes four-ratio
row geomeans and the equal-row twelve-row geomean. Warmups and reference durations
are excluded from these B/C ratios. Under equal workload, above 1 means candidate
throughput exceeds baseline. Both candidates missed the target's 20% repair bar
and had controls below 0.98; neither was adopted.

The full 216-fixture manifests are inherited protocol metadata. Actual selection
is twelve cold rows, explicitly overriding iterations to 500 at 64K and 100 at 1 MiB;
rounds 2 and warmup 2 apply per child. This is not a complete 72-row Deflate acceptance
matrix. No dedicated-host confidence interval, industry leadership or codec heap
result is asserted. Profile clocks do not enter the statistics.
The inherited generic iterations map remains `65536:100,1048576:20,full:1`;
the selected-row runner and every argv/probe explicitly override it to 500/100.

Public APIs are Vort `decodeRawDeflate` and
`libdeflate_alloc_decompressor + libdeflate_deflate_decompress_ex + free`, with
per-call cold state. The pinned reference is libdeflate 1.26, header-declared ABI
`LIBDEFLATE_SUCCESS=0/decompress_ex`. Every report records full output, 64-byte
guards, unchanged input and exact compressed consumption for both consumers.
Recorded conditions are ReleaseFast, Zig 0.16.0, x86_64-linux-gnu,
`skylake+pku+sgx`, i7-10700K, CPU 15 and single codec/benchmark thread. Before/after
snapshots observed no compilers, but cannot establish exclusive timed-batch isolation.

`screens-raw.tar.gz` retains both sets of events, manifests, stdout/stderr and row
summaries. `prefix-source-probe.tar.gz` freezes six source files and its exact
candidate executable; `refill-source-probe.tar.gz` freezes four source files and
its separate executable. Both binaries have mode 0755. No live prefix worktree is
used: it was subsequently replaced by the refill candidate.

`runners-validation.tar.gz` preserves both runners/logs, build logs, full Safe 734
logs, freeze records, original independent-statistics JSON and main-authored
derived codegen JSON. The exact pilot/matrix/evidence/fixtures import sources and
input manifests are retained as dependencies, without executing them. Original
audit nm/objdump stdout was not separately saved; the codegen JSON is a derived
summary. Whole-symbol static counts include cold/tail/error/padding and must not
be treated as dynamic frequency, spills, cycles or performance attribution.

`first-block-shapes.json` is also a main-authored derived summary of read-only
messages, not a saved original parser script/stdout. Its twelve fixture keys are
bound to the manifests and frozen wire hashes. All six 64K first blocks are final,
literal-complete with widths above 9, distance widths below 12 and non-RLE, selecting
`generic11/aligned`. The first 1 MiB nci distance widths 13 select `nonOverlap`; the
other first blocks select generic11. Later 1 MiB blocks were not parsed and no
whole-stream route or hot/tail frequency is inferred from these records.

`payload-counts.json` preserves the final main-authored reconstruction of the
read-only full 64K-to-EOB audit messages. No original parser/stdout is claimed,
and no output bytes were materialized. For each of the six 64K wires, literal plus
match bytes equal 65536, match-length/LL-extra/OF-extra bucket sums equal match
count, LL-symbol buckets equal literal plus match count, and ceil(EOB-bit/8)
equals the frozen wire length. Input SHA values match the manifests. Distance1
and distance2–4 are subsets, not additional overlap classes. These logical token
counts are neither timings nor semantic packed-lookup hit counts. Matches of
length<=16 account for about 90–91% in reymont, 33–36% in nci and 21–26% in xml;
secondary symbol widths are rare. No 1 MiB payload distribution is asserted.

Baseline revision is `8adfb3bae74409bae146fed2ed9b6594a1d3cdb8`. Its 2062 registered
source bytes and `2527c721...` executable equal the earlier shared-dispatch package;
revision advancement changed docs only. `reuse.json` binds those exact source and
probe archives by SHA. The new overlays reconstruct candidate registries 2064
(prefix) and 2063(refill). Reference library bytes are reused from the pinned modern
reference archive by SHA, with no duplicated full source or SO package.

All original report/source/log bytes and EOFs are preserved. Sorted GNU tar/gzip9
use uid/gid/mtime 0, empty owners and gzip filename, timestamp0, and modes 0644/0755.
`archive-bindings.json` binds every member, and `SHA256SUMS` binds standalone files.

Run only the offline audit from the repository root:

```sh
taskset -c 0 python3 -B \
  docs/performance/deflate/reader-screens-20261112/verify.py \
  --original-bytes --git-repo . --fixture-bytes
```

The validator uses the Python standard library only. It does not invoke compilers,
codecs, tests or benchmark runners. `validation-receipt.json` preserves the completed
192-event/24-row archival verification.
