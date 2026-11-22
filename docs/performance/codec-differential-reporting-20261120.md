# Classified codec differential evidence, 2026-11-20

The old differential summary combined real external-reference checks with
Vort-only dictionary/magicless contracts, and combined acceptance differences
with changes in variants lacking a reference. The tooling now reports each
category explicitly and can save bounded, replayable representatives. The
generator, RNG, original decoder verdicts and failure gates retain their
existing behavior.

Reporting and artifact ownership live in `tools/codec_differential/reporting.zig`.
The existing tool adds these optional arguments:

```sh
zig build -j2 -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --deep --seed=0x20261120 --divergence-dir=zig-out/new-differences
zig build -j2 -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --replay-dir=zig-out/new-differences
```

The capture directory must be new. Conflicting capture/replay modes fail before
creating it. Default execution writes no artifacts. Bounds are 32 samples,
two representatives per codec/direction (empty and nonempty source), 1 MiB of
blobs per sample, and 8 MiB total with 512 KiB reserved for the manifest.
Accepting outputs remain complete; the collector skips a sample rather than
truncating a blob. Metadata includes source/dictionary/wire/output hashes,
traversal ordinals, format flags, actual reference destination size and the
available inflate consumption diagnostics.

## Current classification

The complete seed `0x20261120` campaign preserves all old totals: 14,684 valid
wires, 408,571 cuts and 498,324 mutations. It contains 13,828 actual external
valid-wire checks, all source-identical, and 856 Vort-only contracts. External
mutation results are:

| Observation | Count |
| --- | ---: |
| Both accept | 115,614 |
| Both reject | 340,018 |
| Reference only accepts | 10,526 |
| Vort only accepts | 844 |
| Both accept but outputs differ | 0 |

The other 31,322 mutations lack the original system reference: 29,389 reject,
1,195 preserve content, 702 change same-length content and 36 change length.
Thus the old 12,108 divergence total contains 11,370 external acceptance
observations and 738 Vort-only content/length changes.

Isolated default/capture runs preserve all original counters and ordered
wire/mutation digests. The mainline default deep run also passes 7/7 build
steps with identical classifications and digests. Mainline replay verifies all
15 captured observations; conflicting-mode refusal creates no directory.
The completed producer saved 15 samples and 62 blobs, totaling 78,439 bytes
including its manifest. These counts describe observations rather than bug
counts.

## Representative adjudication

Six captured raw/zlib/gzip reference-only cases reach `Z_STREAM_END` with one
byte remaining. Vort's strict one-shot APIs reject trailing input; their
partial APIs expose the completed prefix. Independent raw replays verify
`TrailingData`, exact consumed offsets and matching prefix output.

Brotli reference-only representatives similarly leave trailing input under
both libbrotli 1.0.9 and 1.2.0 streaming replay. Its Vort-only representatives
need more than the old 4,097-byte destination: 32,775 bytes in the diagnostic
subset and 4,103 in the complete deep sample. With enough destination space,
both references reproduce the Vort output. The public limited Vort API rejects
the same over-cap diagnostic sample with `OutputLimitExceeded`. Modern RAW
dictionary attachment also reproduces both original and changed sample
outputs. The normal 1.2.0 build omits `BROTLI_EXPERIMENTAL` and rejects the
serialized attachment; that observation supplies no serialized-reference
verdict.

The Zstd huge-window representative exceeds both reference implementations'
accepted window limit. The small-window RLE representative regenerates 2,050
bytes under a 1,024-byte window. Upstream format documentation requires both
encoded and regenerated block sizes to fit `min(Window_Size, 128 KiB)`;
Vort correctly refuses this frame even though the two tested one-shot
references accept it.

Two remaining Deflate representatives expose a real admission gap. Current
Vort accepts malformed dynamic distance trees in raw and gzip streams, while
zlib 1.2.11, zlib-ng's runtime 1.3.2-compatible API and the loaded libdeflate
artifact reject them. Original wires decode completely in all references.
One mutation creates a width-seven distance singleton; the other creates an
incomplete `{1, 3}` tree. A separate codec-specific dynamic-tree fix is being
validated across direct and incremental decoding.

[Raw evidence](data/codec-differential-reporting-20261120/) preserves the
producer implementation, unchanged-generator/gate checks, full classifications
and replayable samples. Representative adjudication does not exhaust all
11,370 acceptance observations. No codec performance or leadership claim
follows from this tooling increment.
