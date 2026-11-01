# Brotli header parse skip

The 1-byte q11 profile attributed about 48% of cycles to
`readPrefixCodeRuntimeLimited` and 13% to `memset`: every one-byte step re-parsed
the retained compressed header. The header loop also parsed the same prefix once
at the top of the next step before appending the new byte, so each byte paid two
parses of the previous prefix.

## Change

The incremental decoder records `header_parse_len`, the retained byte count at
the last `TruncatedFrame`. The compressed-header loop only parses when the
retained length differs from that value. A failed parse stores the new length;
`beginCompressedHeader` resets it to zero. The first parse of each meta-block
still runs immediately, and the parser still rewinds whole over-read bytes on
success.

This does not change progress, truncation or trailing-data behavior: the
decoder still consumes the offered input into its retained prefix and reports
`need_input` exactly as before. It only removes a provably identical re-parse.

## Measurement

### 1-byte and 4096-byte spot check

Mozilla 64 KiB q11, eight iterations, baseline / pre-skip / post-skip:

| Input chunk | Baseline | Pre-skip | Post-skip |
| --- | ---: | ---: | ---: |
| 1 byte | 25.52 ms | 27.33 ms | 14.10 ms |
| 4096 bytes | 1.015 ms | 0.536 ms | 0.520 ms |

### 720-process epoch

Two alternating sweeps over all 72 frames give these final/baseline geometric
means:

| Quality / scope / input chunk | Final / baseline |
| --- | ---: |
| q6 / 64 KiB / 1 | 0.5774 |
| q6 / 64 KiB / 7 | 0.5443 |
| q6 / 64 KiB / 4096 | 0.5007 |
| q6 / 1 MiB / 4096 | 0.4399 |
| q6 / full / 4096 | 0.5208 |
| q11 / 64 KiB / 1 | 0.5678 |
| q11 / 64 KiB / 7 | 0.5372 |
| q11 / 64 KiB / 4096 | 0.4769 |
| q11 / 1 MiB / 4096 | 0.4028 |
| q11 / full / 4096 | 0.4621 |

The two sweeps agree within about half a percent for every group. The worst row
in each scope is NCI 64 KiB q6 for 1-byte (`0.620`), MR 64 KiB q6 for 7-byte
(`0.615`) and 4096-byte (`0.603`), Dickens 1 MiB q11 (`0.616`) and Dickens full
q11 (`0.660`). No scope has a row above parity.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. Focused incremental and stream-contract runs pass in the
default build.

## Next work

The resumable header parser would reduce the remaining tiny-chunk header cost
from repeated full-prefix parses to retained semantic progress, but the
redundant-parse removal already captures about half of the earlier gap. It
should be re-measured against this decoder before adoption. The copy path,
long-code fallback, one-shot reference epochs and Deflate/Zstd decoder work
remain separate.
