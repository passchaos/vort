# Brotli full-range metadata functional baseline

Date: 2026-10-25/26. Baseline: `24993ef2`; codec source:
`e49fce241781ec4849672ffae410bbad89c701ab`; subsequent test-only revision:
`b502fc50d81be96dc622ab4ba3998a53403c618c`. The full metadata range and alias
lifecycle fix and their functional validation are complete. Narrow, reference,
family and build results retain their respective source scopes below. No speed
or memory-lead claim is assigned. Final build completion was recorded at
2026-10-25 16:29:36 UTC (2026-10-26 00:29:36 Asia/Shanghai).

The increment replaces the prior 64 KiB metadata encoder restriction with the
complete RFC 7932 single-block body range, 0...16,777,216 bytes inclusive. The
[public contract](../formats/brotli-metadata.md) describes `MSKIPBYTES` 0/1/2/3,
minimal length widths, empty-option omission versus explicit empty events,
over-limit rejection and ownership. It adds the public
`br.max_metadata_meta_block_len` and matching root
`BrotliMaxMetadataMetaBlockLen` constants without automatic event splitting.

## Shared header geometry and state

One small header plan supplies option validation, wire writing and exact
stored-stream bit bounds. It includes the starting bit offset, six header bits,
zero/8/16/24 length bits and byte alignment before the body. Nonempty bodies
encode length minus one; multi-byte widths have a nonzero high byte. Metadata
does not add plaintext, history, compression matches or plaintext position.

The scope covers stored/planned, q0...q11, static/HQ, one-shot/chunks/reusable and
incremental surfaces. Oversized setter requests reject before state publication
or body reads. Empty option values retain their existing omission behavior,
while `writeMetadata("")` emits an explicit zero-body metadata meta-block.

The incremental event borrows caller body bytes, then encodes the full body into
pending output using the current allocator authority. The event may therefore
retain body-sized storage; this is not a bounded-small-buffer streaming design
for a 16 MiB body. OOM and pending-output checkpoints retain the established
retry semantics rather than introducing sticky errors or whole-call rollback.

## Reusable alias lifecycle

An actual Debug failure exposed a metadata-only static-dictionary alias bug.
Zig 0.16 `ArrayList.clearRetainingCapacity` can overwrite old output bytes with
`undefined`; deferred copying into pending output did not preserve borrowed
metadata. The repaired path validates first and captures aliased metadata,
source chunks and descriptor arrays across the old allocation capacity before
clear/reset. Snapshot failure preserves the prior output/state. Temporary
metadata option pointers are cleared before releasing the snapshot.

This is a new bug fix, not evidence that the previous ordering was safe.
Pre-fix ReleaseFast passes retain their source epochs and do not replace the
failed Debug case. Independent alias tests cover metadata-only and combined
source/descriptor cases, three snapshot allocation refusal points, and warmed
non-alias reuse without new allocations. Once snapshot preparation succeeds,
later codec failures retain their existing contract rather than whole-operation
rollback. Static-dictionary Large Window 25 preflight is also corrected; the
earlier window-gate evidence remains separate.

## Completed verification and reference scope

Native Debug, native ReleaseFast and x86 ReleaseFast each pass 130/130
executions: 30 filtered metadata tests and 100 public-root tests. This is not
130 separately named metadata cases. Checks cover empty events; 256/257 and
65,536/65,537 widths; exact 16 MiB and maximum-plus-one; bit offsets; payload/
history preservation; caller-output bounds; setter rejection; alias lifetime
and OOM retry. The evidence directory is
[`data/br-metadata-full-range-20261025/`](data/br-metadata-full-range-20261025/).

Each final native/x86 campaign contains 194 target encodes, 18 upstream
reference metadata streams plus their target decoding, 84 pre-allocation
rejections, 10 malformed-stream rejections and one recorded known system
1.0.9 byte-one metadata encoder defect, across 307 commands. The maximum is
physically encoded in two target routes. The tested API routes cover empty and
65,537-byte metadata at representative qualities 0/1/4/8/10/11; this does not
mean the reference campaign individually executes every quality number.
These counts describe executions and fixtures,
not unique codec features. Complete target wire, metadata-header and progress
records agree across architectures after excluding target identity and paths.

The codec source manifest hashes 1,895 files at commit `e49fce241781ec4849672ffae410bbad89c701ab`,
with SHA-256 `c101fde1fd958114c19cc1619694ae0e37763f0e0b1be911306a24f0015c16fd`.
It is archived as `codec-source-manifest.json`. A later full-source manifest at
test revision `b502fc50` has SHA-256
`d849e88b4e4418e10240f075fdc00614d2bcbfcf32e8ddf06d7e6ff4dc50226e`;
`test-source-delta.json` records the sole change to the old wide-bit resource
fixture. That fixture previously treated length 65,537 as format-invalid; it now
uses maximum-plus-one in a length-only sentinel to test rejection priority.
ReleaseFast/x86 narrow geometry checks each pass 20/20. The initial complete
family failure was this obsolete assertion, not a codec format failure. External
runtime reports remain attached to `e49fce24`, without relabeling them as new
codec runs after a test-only commit.

Reference `dladdr` ownership records bind the actually loaded local libbrotli
1.2.0 encoder, decoder and common library, not just requested filenames. The
system 1.0.9 defect experiment runs in the same process and may resolve common
symbols to the newer library; it is not an isolated, dependency-closed 1.0.9
reference benchmark. No timing is measured by this campaign.

## Legacy wire identity

The old `24993ef2` and new codec streams match byte-for-byte in 384/384
comparisons, 192 per target, with zero counterexamples. The base matrix contains
108 comparisons per target: 84 empty-option API/format routes and 24 positive
length boundaries in the stored one-shot/q11 incremental-prefix subset. A
supplement adds 84 positive length-65,536 comparisons per target across seven
codec/quality combinations, six API routes and two format selections. Qualities
are 0/1/4/8/10/11; this is not every q0...q11 permutation or all possible inputs.
All 768 old/new streams pass independent full-content and exact-consumption
reference checks.

The legacy probe uses a compile-only bridge replacing two maximum-constant
references. Inverse/source-hash checks verify that the old implementation is
unchanged; the bridge is not a full-range feature backport. The archived
`legacy-wire-comparison.json` has SHA-256
`ac733d19be2ca5fed8349d94201776310b4a1d5e1d1adb203af807d9d26d4b6a`.

The final complete native ReleaseFast Brotli family passes five build steps and
1430 tests, with one skipped out of 1431. The skip is the host-overflow gate in
`src/tests/br_general_large_window_resources.zig`, which executes only when
`usize` is 32 bits. It is not included in this increment's x86 metadata/root
130-test filter. A separate x86 ReleaseFast execution of
`Brotli general large window encoded bounds detect host integer overflow`
passes 20/20 executions including imports, covering the skipped named gate
without claiming 20 independent overflow tests. The final build check passes
180/180 on test revision `b502fc50`, with the codec still at `e49fce24`. Earlier
successful build reports and failed full-family assertions retain their own
epochs; they are not relabeled as this final run.
Existing
Brotli performance baselines remain dated evidence and are not remeasured by
this compatibility slice. Long-window history, encoder quality and broad
ratio/speed/memory leadership remain open.

The next functional candidates are non-HQ Large Window history beyond the
current retained bound, explicit core Zstd magicless APIs and bounded XZ worker
encoding. Each needs its own compatibility and ownership evidence before
performance tuning or a broader best-library claim.
