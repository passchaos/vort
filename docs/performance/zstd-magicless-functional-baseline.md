# Zstd magicless core functional baseline

Date: 2026-10-26. Baseline: `89fae5d6`; feature revision:
`eb6cb40d35d4ba73fcab2ee3e245aaf8be7c22a5`. Core, consumer, family and final
native/x86 reference, standard-wire parity and build checks are complete.
Final check completion was recorded at 2026-10-25 18:16:30 UTC
(2026-10-26 02:16:30 Asia/Shanghai). No performance improvement is assigned.

The [public contract](../formats/zstd-magicless.md) adds explicit standard versus
magicless data-frame format selection to encoding, decoding, inspection and
incremental state. Standard remains the default. Magicless removes only four
header bytes per data frame and preserves content-size, checksum, dictionary
ID, payload and block semantics. Consecutive magicless data frames are valid;
skippable special handling is available only in standard mode.

## API and resource scope

New `FrameDecodeOptions` makes format, dictionary/dictionary-set selection and
expected/max output explicit. Alloc, Append, size and allocator-first Into
routes share that selection. Into stages decoded bytes for atomic publication
but does not copy compressed input or create a synthetic magic prefix.
Reusable and incremental decoders carry the same format through reset/resume
and both compressed-input policies. WithFormat inspection uses physical input
offsets rather than virtual offsets from a prepended buffer.

Incremental magicless `writeSkippable` rejects before allocator/state changes.
Seekable, ZIP, TAR and CPIO reject a magicless Zstd option because their existing
format contracts require standard frames. ZFS retains its own eight-byte length/
level header and directly calls magicless core encoding/decoding, removing only
the adapter's compressed staging copy; output and decoded scratch allocations
remain governed by their APIs.

## Completed validation

Evidence is recorded under
[`data/zstd-magicless-20261026/`](data/zstd-magicless-20261026/), with native/x86
public probes and the local libzstd 1.6.0 checkout. The oracle explicitly
sets `ZSTD_c_format`/`ZSTD_d_format`, uses the advanced frame-header query for
magicless FCS and preserves the actual loaded reference identity.

The initial consumer aggregate passes 111 tests, including allocation-prohibition
checks for the ZFS path's removed compressed staging. Its core aggregate first
reported 17/18 because a QA-generated 128 KiB raw block was malformed before
reaching the decoder. `@min` inferred u18; shifting that length by three in u18
encoded zero. The corrected fixture widens to u24 before shifting and retains
an independent multi-block raw golden. This was a fixture error, not a producer
failure. A second QA expectation was corrected to preserve the existing
one-shot `NeedDictionary` result for a mismatched ID; incremental
`provideDictionary(wrong)` still reports `DictionaryMismatch`.

Final native Debug, native ReleaseFast and x86 ReleaseFast each pass 130/130
executions: 19 core/layout tests plus 111 public-consumer/root tests, not 130
independent magicless codec fixtures. The layout checks observe the changed
fixed decoder state on each target, not runtime stack or RSS. The complete
native ReleaseFast Zstd family passes 1104/1104 and five build steps; focused
ZIP tests pass 44/44 and CLI help 7/7.

Final native/x86 reports each pass 609/609 cases and 609 commands:
142 standard/magicless encode pairs (284 target encodes), 45 libzstd frames over
270 target decode routes, five default-standard checks, 36 malformed checks,
six prevalidated concatenation checks and eight quota/dictionary checks. They
use the same frozen probe source. Output bytes, headers and progress agree across
architectures; target/CPU names, decoder working-peak and dictionary paths are
excluded, while dictionary basename/full hashes retain identity. This is not an
equal-memory or all-platform claim. Earlier probe optional-cast correction and
QA manifests remain separate; they are not relabeled as these final executions.

The final source manifest has 1,912 files at the feature revision, with SHA-256
`927fb9e04fb7e6bad386b64107cb2ebe5cadf32f4d32fe8073f6c6a9f3ea582f`.
Core and both final probe source identities match that manifest. Final build
checks pass 185/185 with the feature source stable. The completed build is a
separate verification result, not inferred from the other aggregates.

## Default-standard legacy parity

The final old/new harness uses only old public APIs, without a format bridge or
feature backport. It matches 96/96 complete wires, 48 per native/x86 target,
with 192 independent full-plaintext/exact-consumption reference decodes. The
old default allocation, reusable and caller-output decode APIs also verify
each produced wire.

Per target, the bounded matrix contains 30 cases from five corpora, three
native selections and two flag configurations; ten cases from tiny/repeated
inputs and levels -1/0/1/3/19; and eight raw/full-dictionary cases across four
output APIs. This is not all levels, inputs or codec features. Old `89fae5d6`
and new `eb6cb40d` source pins, unchanged helper and report/seal identities remain
archived independently of the 609-case explicit-format campaign.

The bounded campaign covers empty/known/unknown FCS, checksum and dictionary ID
variants, concatenated magicless data, wrong mode, skippable/container rejection,
physical header offsets, truncation/corruption, Into/Append aliases and OOM,
reusable/incremental dictionary resume and first-frame trailing-input accounting.
ZFS checks verify the preserved wire header and payload identity while
demonstrating removal of compressed copying separately from output allocation.

Earlier standard/ZFS performance reports retain their original source/executable
epochs. No throughput/RSS or cross-library memory win is inferred from these checks;
this framing capability does not establish full libzstd algorithm, ratio, memory
or speed equivalence.

The next functional slice is bounded XZ parallel encoding, with explicit worker
and in-flight memory ownership. Its compatibility and resource contracts must
be verified independently before throughput optimization; industry-best
functionality/performance remains an open objective.
