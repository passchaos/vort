# Incremental Brotli literal-run block check: rejected

## Hypothesis

The incremental decoder checked the literal block boundary inside
`Codec.readLiteral` for every literal. The one-shot payload batches this: it
switches once and decodes a run bounded by the block's remaining length. Moving
the incremental loop to the same run shape should remove one check per literal.

## Experiment

`IncrementalLiteralCodec` gained `literalBlockReady`, `literalBlockSpan` and
`readLiteralChecked`, and the `.literals` phase decoded runs bounded by the
block's remaining length. The unguarded form removed the per-literal boundary
check entirely.

## Result

The unguarded form is about 1% faster on two 48-row incremental screens:

| Run | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9901 | 0.9883 | 0.9876 | 0.9883 |
| 2 | 0.9917 | 0.9848 | 0.9885 | 0.9923 |

However, it breaks truncation recovery. A block switch can itself truncate
mid-read; the unguarded run had no checkpoint covering it, so the reader
advanced and the next step mis-decoded. The `br minimal compressed stream
switches thirty-third literal block type` test feeds one input byte per step
and fails.

Three correct variants were then measured, and all are slower than the
committed per-literal loop:

| Variant | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| Guarded due-switch checkpoint in the loop | 1.0358 | 1.0391 | 1.0367 | 1.0348 |
| Same, switch call out of line | 1.0277 | 1.0276 | 1.0225 | 1.0257 |
| Phase-entry switch, run break and re-entry | 1.0129 | 1.0093 | 1.0083 | 1.0079 |

The guarded forms place a non-inlinable `restoreKeepingInput` call inside the
literal loop (or force a call through `&reader`), which perturbs the loop's
register allocation; the phase-entry form pays a phase re-entry per block
switch. Each costs more than the per-literal boundary check saves.

## Conclusion

The per-literal boundary check stays. Batching it is only profitable if the
switch recovery can be handled without a call in the literal loop, which the
current state machine cannot express.

Raw comparison files and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`stream-litrun-comparison.json`,
`stream-litrun2-comparison.json`, `stream-litrun3-comparison.json`,
`stream-litrun5-comparison.json`, `stream-litrun6-comparison.json`).
