# Count distance-parameter alternatives before emission, 2026-11-03

Brotli q8 distance-parameter search used to materialize both the baseline and
the selected alternative as complete wires, then keep the shorter one. The
new prepared-pair controller prepares both candidates as exact counted
lengths, borrows the already published ordinary command model and literal
model, and emits at most one selected wire. If the selected local winner does
not beat the incoming incumbent, no wire is emitted at all.

The pair preparation owns only its alternative distance model: frequency
support, alphabet, lengths and encoder. It reuses the immutable command
alphabets, lengths, encoders, extra-bit total, literal trees and literal
header/payload count from the same candidate group. The local chooser, strict
tie behavior and the outer incumbent comparison are unchanged. The prepared
alternative is checked against its borrowed owners and option key again before
physical emission.

The first supported scope is standard windows 10–24, 8–64 KiB q8 inputs,
recent distances, default distance parameters, no compound dictionary split,
no metadata and no active split family. Unsupported shapes retain the original
physical search. The production public path applies the prepared pair only at
q8, 8–64 KiB, ordinary window and empty metadata.

## Correctness and work

The full old physical writer is the wire oracle. Tests compare the prepared
base and alternative against independently emitted baseline, alternative and
selected wires, complete stats, distance alphabets/lengths/encoders and the
decoded stream. Fixtures cover 1–5 symbol command alphabets, literal-only
streams, 4/5/256 literal alphabets, 127/128/129 command counts, all 64 legal
parameter shapes, windows 10/24, non-zero output positions, starting distance
rings, previous-byte context, UTF-8 contexts, context candidates, compound
dictionaries and static dictionaries.

The ownership suite rejects stale input slices, changed command arrays,
window/offset/dictionary changes, distance-ring and previous-byte changes,
context and split option changes, metadata, reset owners and wrong distance
keys before any emission allocation. It also covers checked overflow, exact
allocation counts, OOM cleanup and preservation of borrowed models. The
profile suite verifies counted/evaluation/wire/selection events, strict ties,
incumbent acceptance and event truncation. The frozen original-controller test
mode bypasses the prepared pair so its materialized-primary oracle remains
independent. Native Debug/ReleaseSafe/ReleaseFast runs pass the
prepared-distance and public parameter-pair tests. The complete ReleaseFast
Brotli suite passes 1,531 tests with one existing platform skip out of 1,532
and exit zero.

Across twelve 64 KiB Silesia slices, every returned wire is byte-identical to
baseline commit `36fa5838` (same SHA-256 and length), and every probe round
trip and output guard passes. The old path materialized 24 full candidate
wires for these rows; the prepared path materializes 4 (one per winning
alternative) and skips 8 pairs entirely because the local winner loses to the
incumbent. Two candidates are counted for every pair.

## Ordinary q8 probe matrix

Both binaries call the public quality API through
`tools/br/parameter_pair_probe.zig`: q8/generic/actual window16, followed by
native decode and guard checks. Five alternating profile rounds per row are
reduced to per-row medians. Profile timing includes the recorder overhead on
both sides; it identifies candidate-work reduction rather than a standalone
ordinary encode benchmark.

Host: Intel Core i7-10700K, one codec thread. Vort uses Zig 0.16.0 ReleaseFast,
GNU x86-64. Baseline is clean commit `36fa5838`; the final source is the
prepared-pair tree.

| Scope | Geometric paired time ratio | Physical emits old → new | Wire identity |
| --- | ---: | ---: | ---: |
| Twelve Silesia 64 KiB slices | 0.97083 | 24 → 4 | 12/12 |

Per-row paired ratios span 0.951–0.991. The aggregate geometric ratio is
0.97083, about 3.0% less profiled outer encode time, with eight rows skipping
pair emission entirely. [All row results](distance-parameter-pair-20261103.csv)
retain wire hashes, counters and independent medians.

## Reproduction

```sh
zig build build-br-parameter-pair-probe
zig build test-br -Dbr-test-filter="Brotli parameter pair" --summary all
zig build test-br -Dbr-test-filter="prepared distance parameters" --summary all
```

The probe accepts an ordinary or `profile` mode and an input file up to
65,536 bytes. It prints input/wire length, both SHA-256 identities, guard
status and the optional profile JSON.
