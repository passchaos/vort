# Puffin empty distance and checked metadata bounds (2026-11-21)

Puffin converts Deflate bits into metadata and tokens and reconstructs those
bits. The converter has its own structural contract. The ordinary Deflate
dynamic-tree admission repair is documented separately in
[deflate-dynamic-admission-20261120.md](deflate-dynamic-admission-20261120.md).

## Reproduced failures

The differential campaign's original sample 14 is a 124-byte raw Deflate
stream with 991 meaningful bits, complete CODES/LENS, an unused `DISTS=[0]`,
and 128 bytes of decoded content. Both public Puffin directions rejected it
with `InvalidPuffinStream`. A separate Python canonical-code parser produces
an independently expected 218-byte Puffin stream; the repaired converter
matches that stream and reconstructs all original meaningful bits.

The public puffer also panicked when raw HLIT/HDIST values 31/31 and repeats
138+138+44 wrote 320 entries into the 316-entry dynamic-length array. Its
reverse converter already rejected these field counts. The isolated before
probe records SIGABRT; the repaired probe returns `InvalidPuffinStream`.

Two adjacent hostile-input arithmetic paths are covered by the same repair:
output bit-length rounding previously added seven without an overflow check,
and a Puffin distance token added one to a `u16` before checking its range.

## Structural contract

Distance-only Huffman initialization admits an empty error-marker table.
Actual distance encoding or decoding still refuses that table. Empty CODES
and LENS remain invalid. Shared count validation enforces the supported
286/30/19 field limits in both directions; subtraction-based span checks
bound direct lengths and repeats before indexing the shared 316-entry array.

Canonical incomplete CODES/LENS/DISTS, a width-seven singleton EOB, and
representable match-first tokens retain their bit-preserving behavior. Puffin
does not execute history copies. These controls keep its structural contract
explicit while ordinary inflate continues to enforce its own validity rules.

Output rounding overflow reports `IntegerOverflow`. Encoded distances at or
above `0x8000` report `InvalidPuffinStream` before addition; truncated distance
tokens retain their existing `InvalidPuffinStream` result. Exact-bit size,
output-cap, caller-canary, allocation-failure cleanup and retry checks are
included in dedicated test modules.

## Frozen isolated validation

The producer's final native, x86-linux-musl and wasm32-wasi tests all pass,
14/14 per target, on the same frozen Debug source. WASI executes the Zig test
runner through Node and records the compiled artifact SHA. Mainline source
remained unchanged during these tests. An additional isolated test of the
public `src/android_ota.zig` module passes 38/38, including existing AOSP
fixed/stored patch application and non-byte-aligned extent mapping.

The [immutable evidence package](data/puffin-dynamic-bounds-20261121/)
preserves before/after public probes, exact fixture bytes, independently
generated expected Puffin bytes, source/patch manifests, split regressions and portability
receipts. The producer patch SHA-256 is
`1ac63a4552aef3ad23bce2c8b4cf537e8881a2e90768d63d7afcd3a566d8812c`.

Pinned AOSP source at
`56246e65146cbf7b736343c95a3e8ed970b9d106` confirms count limits and the
metadata/token contract. This reference scope is a source audit; no local
AOSP executable was available for this increment. No throughput sampling or
performance claim is attached to these functional results.

## Stored padding representation

A separate audit constructed complete 88-bit and 96-bit Deflate streams
accepted by zlib 1.2.11. Their final stored blocks need seven or six alignment
bits. Padding 0/31 preserves the raw bits, while values 32/64 overwrite TYPE
in Puffin's FINAL1/TYPE2/SKIP5 header. An existing SHA-identified CLI accepted
the source but could not Huff it at the original bit length. Huff at 56 bits
instead produced a fixed final block with the same plaintext and different
raw bits. This observation binds the archived CLI, not a newly built binary.

Mainline now rejects values above 31 as `InvalidPuffinStream` and preserves
representable padding even for six/seven-bit alignment. Fully supporting
larger values would require a metadata representation extension. Pinned AOSP
puffer/huffer sources use the same header layout; this source comparison
does not establish an AOSP binary verdict. The independent samples, zlib
outputs and command/CLI provenance are in `padding-audit/` in the evidence
package. Current compiled tests cover both alignment widths.

## Early serialized output quota

On 65,535-byte stored and fixed-literal blocks with output cap 16, the old
puffer reached `OutOfMemory` on a 1 KiB fixed heap. On a growing heap it
allocated 320,654 cumulative requested bytes in 17 allocations before its
late `OutputLimitExceeded`. The isolated resource delta now returns
`OutputLimitExceeded` on both heaps, requests 389 cumulative bytes in three
allocations on the growing heap, and frees every allocation in both cases.

The builder checks current output, pending literal data plus its one/three
byte run header, and upcoming metadata/copy/end tokens before append or
flush. Tests cover exact/one-below caps, the 127/128 literal-header and
129/130 copy-token boundaries, large inputs with small caps, allocation
failure cleanup/retry and error precedence. A known output beyond quota
stops before later malformed/trailing data; already parsed format errors
retain their results. This is a logical output quota, not an allocator
capacity or physical-memory guarantee.

The resource-only producer passes 15/15 native, x86 and actual WASI tests,
with its immutable archive under `output-budget-producer/`. Its patch SHA is
`c5ec56791e623e85400621972356918a7bffce41872b8e5aa8139858099967af`.

## Current mainline validation

The pre-Puffin full-library snapshot reached terminal exit zero: 408/408
build steps, 5,827 passed/two skipped, with all recorded source hashes still
matching. The [receipt](data/deflate-dynamic-admission-20261120/full-final-gate-receipt.json)
preserves that separate source epoch.

After all Puffin changes were integrated, the current Debug gate passes
20/20 build steps and 246/246 native runner tests: 78 native/x86 Puffin
tests plus 168 Android OTA regressions. Actual WASI passes 39/39; the complete
current library test suite compiles. ReleaseFast passes 11/11 steps, 78/78
native/x86 tests and 39/39 actual WASI tests. Both WASI receipts are copied
from the corresponding Node run's captured stdout and bound to its compiled
artifact SHA. The full library was not executed again after this increment.

`mainline-source-provenance.json` and the mainline log/receipt pairs bind the
combined source, including the preserved unrelated LZ77 experiment. The
record-skip performance patch remains unadopted. These results close this
functional slice; the broader codec performance/functionality goal remains
active.
