# Zstd single-sequence Huffman literal decode, 2026-11-16

## Trigger

After the wide-executor state localization, `x-ray` remained the worst level-1
row at 0.3364. An LBR call graph on the level-1 frame resolves the hot chain:

```
decodeLiteralOnlyCompressedBlockIntoBuffer
  -> decodeSinglePredefinedSequence
    -> copyHuffmanLiteralsFromSection
      -> HuffmanLiteralCursor.readSymbol
```

`decodeSinglePredefinedSequence` handled a block with one predefined sequence
by calling `copyLiteralsFromSection` twice: once for the sequence literal run
and again **from the start of the Huffman stream** for the trailing literals.
Every literal was decoded twice, and both passes used the checked per-symbol
`readSymbol` path. On x-ray that path owned about 43% of decode instructions.

## Change

`src/zstd.zig`, `decodeSinglePredefinedSequence`:

- For four-stream compressed/treeless sections with at least
  `split_x2_huffman_literal_min` (12 KiB) literals, decode the whole literal
  section **once** with the four-stream reservoir loop directly into the
  output. Then slide the trailing literal range right by the match length with
  `std.mem.copyBackwards`, emit the match into the gap, and commit the new
  cursor. This avoids both the double decode and a separate literal staging
  buffer.
- For other shapes (single-stream, small, raw/RLE), keep a stateful
  `HuffmanLiteralDecodeState` so each literal is still decoded exactly once;
  this was the first, smaller fix and remains the fallback.

The match offset is resolved against `base + literal_len`, so the match may
read the literals just written, and the tail move happens before the match
copy, so the moved range cannot disturb the source.

## Intermediate and rejected experiments

- **Stateful cursor only** (no whole-section reservoir): x-ray 0.3364 ->
  0.3889 (+15.6%), twelve-file geometric mean +1.39%. Correct but below the
  cliff-repair bar; superseded by the reservoir path and kept only as the
  fallback.
- **Lowering the literal-only fast-path threshold from 16 KiB to 4 KiB**:
  x-ray 0.3364 -> 0.3282, a regression. Rejected; the 16 KiB threshold stays.

## Results

Baseline: the committed wide-executor state-localization package. `speedup` is
`after / before`; `cumulative` is `after / original 1.6.0 baseline`.

| file | before | after | speedup | cumulative |
| --- | ---: | ---: | ---: | ---: |
| dickens | 0.8064 | 0.8076 | 1.0015 | 1.1013 |
| mozilla | 0.7983 | 0.8001 | 1.0023 | 1.0383 |
| mr | 0.6144 | 0.6210 | 1.0107 | 1.0305 |
| nci | 0.7876 | 0.7871 | 0.9994 | 0.9996 |
| ooffice | 0.7933 | 0.7969 | 1.0045 | 1.0308 |
| osdb | 0.8030 | 0.8066 | 1.0045 | 1.0620 |
| reymont | 0.7990 | 0.8081 | 1.0114 | 1.1334 |
| samba | 0.7908 | 0.7930 | 1.0028 | 1.0459 |
| sao | 0.8187 | 0.8127 | 0.9927 | 1.0221 |
| webster | 0.8331 | 0.8347 | 1.0019 | 1.0907 |
| xml | 0.7774 | 0.7759 | 0.9981 | 1.0201 |
| x-ray | 0.3364 | **0.7811** | **2.3219** | **2.3930** |

Nine of twelve rows improve, the lowest control row is 0.9927 (above the 0.98
floor), and the twelve-file geometric mean improves **1.0754** in this
increment. Cumulatively, the two 2026-11-16 zstd decode increments improve the
twelve-file geometric ratio from 0.6957 to 0.7835 (**1.1261**), with `x-ray`
moving from 0.3264 to 0.7811 (2.39x).

## Validation

- `zig build test-zstd -Dzstd-test-filter=predefined`: 49/49 pass.
- `zig build test-zstd -Dzstd-test-filter="stream counters"`: 42/42 pass.
- `zig build test-zstd -Dzstd-test-filter=literal`: 162/162 pass.
- The reference bench verifies byte equality for all twelve files on every
  measured decode.
- Focused decode-memory, source-reverse, compressed-workspace and `check-wasm`
  results are recorded in the status ledger for this increment.

## Scope limits

Single host, one-shot decode, 20 iterations, no CPU pinning. The paired
libzstd ratio controls host drift; absolute throughput moved between runs. The
`x-ray` gain is specific to the single-sequence predefined-block shape and does
not by itself establish parity on other near-incompressible corpora.
