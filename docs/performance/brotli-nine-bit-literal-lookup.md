# Brotli nine-bit literal lookup

The prepared lookup used eight bits for every prefix tree. A one-shot profile of
Mozilla 64 KiB q6 still attributed 13.8% to
`HuffmanTable(256).decodeValueLongAfterLookup`, the canonical fallback for codes
longer than the lookup width.

## Change

Literal trees (`alphabet_size <= 257`) now build a nine-bit prepared lookup
(512 entries); command, distance, block-type and context trees keep the
eight-bit table. The build, peek and long-code fallback all use the per-tree
lookup width. The literal trees gain about 33 KiB of header memory in total
(65 trees × 512 extra bytes); the decoder remains below its 1.5 MB size
contract.

## Measurement

### Incremental 48-row paired screen

Against the eight-bit build:

| Producer quality / scope | Nine-bit / eight-bit |
| --- | ---: |
| q6 / 64 KiB | 0.8978 |
| q6 / 1 MiB | 0.9167 |
| q11 / 64 KiB | 0.9534 |
| q11 / 1 MiB | 0.9711 |

### 720-process epoch

Two alternating sweeps over all 72 frames give these final/baseline geometric
means:

| Quality / scope / input chunk | Final / baseline |
| --- | ---: |
| q6 / 64 KiB / 1 | 0.5979 |
| q6 / 64 KiB / 7 | 0.5344 |
| q6 / 64 KiB / 4096 | 0.4512 |
| q6 / 1 MiB / 4096 | 0.4057 |
| q6 / full / 4096 | 0.4924 |
| q11 / 64 KiB / 1 | 0.5986 |
| q11 / 64 KiB / 7 | 0.5531 |
| q11 / 64 KiB / 4096 | 0.4608 |
| q11 / 1 MiB / 4096 | 0.3929 |
| q11 / full / 4096 | 0.4609 |

The two sweeps agree within about half a percent. Compared with the eight-bit
epoch, the 4096-chunk groups improve from `0.5007/0.4399/0.5208` to
`0.4512/0.4057/0.4924` for q6 and from `0.4769/0.4028/0.4621` to
`0.4608/0.3929/0.4609` for q11. The 1-byte groups regress from
`0.5774/0.5678` to `0.5979/0.5986` and the 7-byte q11 group from `0.5372` to
`0.5531`, because the larger lookup build costs more for tiny multi-step
headers. The trade is retained because the 4096/1 MiB/full gains are larger and
the tiny-chunk groups remain far below parity.

### One-shot API

A paired 48-row screen gives `0.9908/1.0048/0.9878/0.9975` for q6/q11 at
64 KiB/1 MiB, so the one-shot API is neutral within about one percent.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. Focused prepared-lookup tests pass.

## Next work

The 1-byte and 7-byte groups would benefit from avoiding the full lookup build
on tiny frames, for example by building only on the first literal-heavy block.
Deflate's semantic loop remains the largest three-codec gap, followed by the
Zstd sequence decode.
