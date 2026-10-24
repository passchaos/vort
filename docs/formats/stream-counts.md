# Cumulative Brotli and Zstd stream counts

`core.StreamCount`, also exported as `vort.StreamCount`, represents a cumulative
stream quantity. It is `u64` on targets whose `usize` is narrower than 64 bits,
and remains `usize` on 64-bit targets. Existing native public types therefore
retain their identity. A single caller buffer and `core.Progress` continue to
use `usize`.

This distinction applies to accepted input, delivered output, frame/stream
counts, pledges, cumulative metadata quantities and diagnostic byte offsets.
It does not increase a physical allocation, format block size or match distance
limit. `core.stream_count` provides checked addition, explicit optional-local
conversion, checked physical narrowing, bounded history lengths and ring
indices. Narrowing a cumulative pledge to fit an allocation is not a substitute
for streaming it.

## Brotli

General/caller-history/owned decoding and the stored, literal and RLE subsets
use wide cumulative counts. Output pledges and per-stream/operation caps use
the same type. The supported wire subsets remain unchanged: a single final RLE
meta-block is still bounded by Brotli's meta-block size; it cannot serve as a
multi-GiB single-block test. General decoding can process multiple blocks with
bounded history and caller output.

The generic stored/planned/static-dictionary encoder core already used a wide
outer counter. The remaining ordinary, fragment and static serializer output
positions now use the same cumulative type. Backward-distance geometry first
bounds the position by the actual format window, then uses a local index.

`stream_bits` in progressive copy/literal parsing is a cyclic coded-bit
position used for alignment and checkpoints. Directly consumed stored and
metadata payload bytes were never included in it. It retains its local type
and advances with wrapping arithmetic; wrapping preserves modulo-eight
alignment. Diagnostic absolute byte positions use `StreamCount`. This avoids
both a premature 32-bit coded-bit limit and an artificial byte limit obtained
by multiplying a whole-stream byte counter by eight.

Captured metadata bytes and captured descriptor indices remain local: they
cannot exceed the caller's slices. Observed metadata totals and block counts
remain exact even after capture storage is exhausted.

## Zstd

Incremental exact-size initializers, continued frames, snapshots, logical
limits and byte offsets use `StreamCount`. Both `block_stream` and
`prevalidated_frame` retain wide decoded lengths. A small complete RLE frame
may describe more than 4 GiB of output without requiring a decoded-output
allocation of that size. Prevalidation counts its blocks in the wide domain.
Its retained compressed frame is still a physical slice with a local capacity.

`max_decoded_buffer_len` is a per-frame logical safety cap and uses the wide
type. Working-memory limits and actual buffer capacities remain `usize`.
Snapshots expose full decoded lengths and remaining counts. The common
diagnostic `payload_remaining` field remains local; a wide remaining quantity
is bounded to `usize` there, with the complete value available in the snapshot.

Rolling history start/end positions and index entries use `StreamCount`.
Matchers check the wide coordinate difference and the visible history span
before converting it into a physical index. Local matcher coordinates and
format distance limits are unchanged. Retained index allocations are charged
using the actual entry size; widening entries on 32-bit targets is included in
the existing requested-heap budget.

`checksum.XxHash64Stream`, exported as `vort.XxHash64Stream`, preserves the
standard-library XXH64 type and implementation on 64-bit targets. Its 32-bit
implementation keeps a full `u64` length and canonical stripe/tail processing,
without heap allocation. The standard-library implementation's `usize`
processed-byte count cannot safely represent a checksum-bearing 4 GiB stream
on a 32-bit target. The new implementation avoids that truncation and the
incorrect small-input finalization branch.

## Progress, overflow and file adapters

All quantities delivered in one `StepResult.progress` remain local. An input
counter overflow is rejected before draining a pending header or modifying
caller output. Output advances and completion counts are checked before their
corresponding write or state commit. Partial progress that was accepted earlier
in a failed call remains observable. Reset and continuation preserve their
existing operation, cap and ownership semantics.

The Brotli/Zstd `stream-file` CLI commands read and write bounded 32 KiB chunks
through the public encoder core and atomically publish completed output. Only
these commands accept `--max-input-len` and `--max-output-len` as wide source
and encoded-output caps. Their file-size pledge is wide; non-streaming commands
retain their physical input limits. An unsuccessful limit, allocation or I/O
operation preserves an existing destination, including same-path input/output.

The common diagnostic record now accepts wide byte quantities. Other codec
providers explicitly convert their existing optional local values into that
record; this type adaptation does not itself extend those codecs' internal
stream counters.

## Verification scope

Small state tests separately cover checked `u64` boundaries, legitimate
repeated-prefix checkpoints, old independent wire bytes, metadata capture,
history rings, dictionary continuation, quotas, allocation failure and actual
failed-call progress. Those checkpoints model a valid prefix; they do not claim
to have physically processed it. Real large-stream gates separately consume
and produce the logical multi-GiB data through reusable bounded buffers, with
independent content/checksum validation.

Contiguous one-shot arrays remain bounded by the address space. Brotli's shared
whole-input bit reader has a separate 32-bit bit-addressability limitation;
the cumulative incremental fixes do not establish that every contiguous API
can accept every physically representable input size. Current platform/API
boundaries and industry-wide quality/throughput/memory comparisons remain
separate work.
