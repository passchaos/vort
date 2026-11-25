# Codec boundary check, 2026-11-24

This is a functional screen, not a performance result or a full conformance
claim. It covers raw Deflate, zlib, gzip, standard Zstd and Brotli on the
source after correcting incremental zlib tail completion.

A valid nine-byte zlib member decodes `A`; the following `78 00` is not a
member header. Libz 1.2.11 returned `A` and preserved both trailing bytes.
With concatenation and trailing data enabled, Vort previously returned
`.done` from `step` even when the cumulative exact output pledge was two bytes.
The regression test first failed with `.done` and one byte written, then
passed after the zlib tail branch checked the pledge before completion.
It covers direct gzip/zlib and auto detection, whole and split tails, both a
fulfilled and a short pledge, and exact committed progress.

```sh
zig build -j5 test-zlib-or-gzip-auto test-zlib-or-gzip-auto-x86 \
  test-zlib-or-gzip-auto-wasm test-deflate-incremental-relaxed \
  check-gzip-header-events run-zlib-or-gzip-auto-diff \
  run-codec-differential-fuzz --summary all -- --max-size=256
```

The bounded generated-wire screen used seed `8534165662193842810` and system
libz 1.2.11, libzstd 1.4.8 and libbrotli 1.0.9:

| Check | Count | Result |
| --- | ---: | --- |
| Valid generated wires | 2,584 | All round-trip, exact-size and external reference checks passed |
| Truncation comparisons | 62,432 | 61,888 both reject, 544 accept with equal output, no one-sided verdicts |
| Mutation comparisons | 97,894 | 20,817 both accept with equal output, 74,403 both reject, 2,674 one-sided |

Of the mutation observations, 2,660 were reference-only accepts and 14 were
Vort-only accepts in the Brotli bucket. They were not adjudicated in this
screen. No compared pair that both accepted disagreed on plaintext.

- Generated wire digest: `a0aa0970e844f2039eff114f41b9773612410da8b622b9a72e21d081cedfffe4`
- Mutation sequence digest: `c7298bf5b0693261144eeabf3f35b2f08629355051a8fd252de0de9ce2afdc4f`

## Brotli capacity follow-up

Repeat the same seed, patterns, wire generation and mutations with the
ordinary 4,097-byte reference destination and a 65,537-byte Brotli-only
destination. Use system libbrotli 1.0.9 and repeat with local libbrotli 1.2.0
(`558fc64`, its decoder and common libraries loaded together):

```sh
zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- --max-size=256
zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --max-size=256 --brotli-reference-floor=65536
# Repeat both commands with LD_LIBRARY_PATH=$HOME/Work/brotli/build-vort.
```

Both versions produce the same result:

| Brotli reference destination | Both accept | Reference only | Vort only | Output mismatch |
| ---: | ---: | ---: | ---: | ---: |
| 4,097 | 4,912 | 747 | 14 | 0 |
| 65,537 | 4,926 | 747 | 0 | 0 |

All 14 observations become equal-output accepts with a larger buffer. The
wire and mutation digests, valid and truncation results, and every other
codec's classification stay unchanged. This explains the 14 Vort-only
observations in this screen as capacity effects, not a confirmed Brotli
wire-acceptance bug. The 747 reference-only observations were checked in the
follow-up below.

## Brotli complete-input follow-up

With the same 65,537-byte reference destination, compare the ordinary
libbrotli one-shot route to its streaming route with complete-input
consumption required:

```sh
zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --max-size=256 --brotli-reference-floor=65536 --brotli-reference-exact-input
# Repeat with LD_LIBRARY_PATH=$HOME/Work/brotli/build-vort.
```

Both libbrotli 1.0.9 and 1.2.0 returned streaming success with input remaining
on 747 comparisons. Requiring full input moved those 747 observations from
reference-only acceptance to both-reject. Both-accept remained 4,926, no
accepted outputs differed, and both Brotli one-sided counts became zero.
The generated-wire and mutation digests, valid and truncation results, and
other codecs' counts were unchanged. This resolves the remaining Brotli
observations in this bounded screen as a trailing-input policy difference,
not a decoder issue. Other codecs' one-sided observations were not separately
adjudicated in that follow-up.

## Deflate complete-input follow-up

Keeping the same Brotli settings, require `avail_in == 0` after `Z_STREAM_END`
for the raw Deflate, zlib and single-member gzip libz reference calls. The
multi-member gzip reference already requires full consumption.

```sh
zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --max-size=256 --brotli-reference-floor=65536 --brotli-reference-exact-input \
  --zlib-reference-exact-input
```

With libz 1.2.11 this moved 1,879 observations from reference-only accept to
both-reject: 927 raw Deflate, 408 zlib and 544 gzip. Libz reached
`Z_STREAM_END` with an unconsumed tail in all 1,879. Valid and truncated
results, both-accept outputs, both digests and the Brotli and Zstd counts
were unchanged.

The 34 reference-only Zstd observations were still unclassified at that
checkpoint. The libzstd 1.4.8 dictionary-capable one-shot API accepted a
valid concatenation with a skippable frame and rejected an unrecognized extra
byte in an independent check. The streaming oracle already requires full
input and a zero final hint. A [historical oversized RLE sample](codec-differential-reporting-20261120.md#representative-adjudication)
violated the format's block limit, but its explicit-window generator variant
was not part of this small run.

## Zstd per-observation follow-up

On `896a0212`, the isolated [diagnostic patch](data/zstd-reference-audit-20261124/diagnostics.patch)
rechecks only the generated reference-only Zstd outcomes. It retains error
names, layout status and digests, not compressed samples. Apply it in an
isolated checkout (`git apply --unidiff-zero /path/to/diagnostics.patch`) and
run the Deflate complete-input command above without changing the seed or
max size. Repeat with `LD_LIBRARY_PATH=$HOME/Work/zstd/lib` to select the
local libzstd 1.6.0 build instead of system libzstd 1.4.8.

The [34 observations](data/zstd-reference-audit-20261124/observations.csv)
refer to 23 distinct wire digests. Vort returns `CorruptFrame` in all of them
while outer frame/block inspection succeeds. For 33 observations, the only
changed byte is the symbol compression modes byte, and only its low two bits
changed from zero to nonzero. The audit locates that byte in the valid parent
using the literals-section lengths and sequence-count widths independently of
entropy decoding. RFC 8878's Symbol Compression Modes field requires these
reserved bits to be zero; Vort's rejection matches that constraint. The last observation changes
one data bit in the final sequence byte without moving the end marker; its
sequence modes still inspect successfully. It is a version-specific acceptance
difference here, not a separately proven format violation or a confirmed Vort
bug.

| libzstd | Valid checks passed | Both accept | Both reject | Reference only | Vort only | Output mismatch |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1.4.8 | 544 | 4,455 | 16,183 | 34 | 0 | 0 |
| 1.6.0 | 544 | 4,455 | 16,217 | 0 | 0 | 0 |

Both runs retain the original wire and mutation digests and the same 12,206
Zstd truncation comparisons with no one-sided verdict. The loaded libzstd
libraries had SHA-256 `5df4f4df42d76270bb6981fabc7c1fdccd8ad28a23d84d67f73203fb3f537667`
(system) and `c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`
(local). No production decoder change follows from this bounded audit.
