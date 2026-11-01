# Brotli packed literal tree cache

A `perf` profile of samba.full q6 attributed 62% of decoder cycles to
`expandPackedLargeLiteralPrefixForDecode`. Frames with many literal block types
alternate between packed literal trees; the single active-tree slot rebuilt a
complete Huffman table on every switch.

## Change

The large-window header keeps a four-slot round-robin cache of expanded packed
literal trees, keyed by tree index. A hit returns the cached tree directly; a
miss expands into the next slot. The indices are cleared after every compressed
header parse and the prepared-lookup flags are cleared with the rest of the
header, so a cached tree can never be reused across meta-blocks. Command and
distance packed trees keep their existing single active slot because they are
expanded far less often.

`PackedPrefixCode.expand` already leaves the prepared lookup undefined and sets
`prepared = false`; the cache therefore copies only the table, never the 512-byte
lookup. The cache adds about 9.4 KiB to the large-window header.

## Measurement

### Full-file spot checks

Single-iteration medians, baseline / pre-cache / post-cache:

| Frame | Baseline | Pre-cache | Post-cache |
| --- | ---: | ---: | ---: |
| samba.full q6 | 880 ms | 927 ms | 438 ms |
| webster.full q6 | 708 ms | 686 ms | 404 ms |
| xml.full q6 | 45.8 ms | 45.3 ms | 23.2 ms |
| samba.full q11 | 367 ms | 282 ms | 121 ms |
| x-ray.full q11 | 422 ms | 369 ms | 174 ms |

### 48-row epoch

A four-sweep paired epoch against the pre-cache build gives
post-cache/pre-cache `1.0208/0.9798/1.0083/0.9327` for q6/q11 at 64 KiB/1 MiB,
all 48 rows `0.9848`, and independent sweeps
`0.9888/0.9873/0.9811/0.9798`. The best row is x-ray 1 MiB q11 at `0.364` and
the worst is NCI 64 KiB q6 at `1.059`. Combined with all earlier increments the
48 rows reach `0.4619` of the frozen baseline.

### 720-process epoch

Two alternating sweeps over all 72 frames give these final/baseline geometric
means:

| Quality / scope / input chunk | Final / baseline |
| --- | ---: |
| q6 / 64 KiB / 1 | 0.9532 |
| q6 / 64 KiB / 7 | 0.7329 |
| q6 / 64 KiB / 4096 | 0.5136 |
| q6 / 1 MiB / 4096 | 0.4345 |
| q6 / full / 4096 | 0.5153 |
| q11 / 64 KiB / 1 | 1.0310 |
| q11 / 64 KiB / 7 | 0.8216 |
| q11 / 64 KiB / 4096 | 0.4862 |
| q11 / 1 MiB / 4096 | 0.3991 |
| q11 / full / 4096 | 0.4534 |

The q6 full group sweeps are `0.5154/0.5151` and q11 full `0.4529/0.4539`.
Every full-file q6 row is now at or below `0.630` and every full-file q11 row at
or below `0.654`; the previous samba/webster/xml q6 regressions are gone. Only
the 1-byte q11 group remains above parity at `1.0310`.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. The header-ownership comparison test now checks the
cache indices and round-robin cursor instead of the removed single active index.

## Next work

The 1-byte q11 case still needs a dedicated check. Extending the cache to
command and distance trees is only worth it if their expansion profiles grow.
The copy path, long-code fallback, one-shot reference epochs and Deflate/Zstd
decoder work remain separate.
