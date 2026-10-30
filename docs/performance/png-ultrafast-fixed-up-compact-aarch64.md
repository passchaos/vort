# PNG ultrafast fixed-Up compact pairs on AArch64

The fixed-Up PNG caller now has an explicit compact literal-pair encoder while
the canonical 64-bit-pair encoder remains source-identical. The alternate
implementation lives in `src/png_ultrafast_compact.zig`; it stores each pair's
up-to-24 code bits and five-bit combined length in one aligned `u32` instead of
one `u64`. Both implementations emit identical zlib bytes.

A bounded 64-word probe is enabled only for filtered payloads of at least
1.25 MiB. It selects the compact implementation when at least half of the
sampled words are zero or when a 256-bit pair bloom has at least 140 occupied
bits. On the locked corpus this selects two Exoplanet rows, Lohengrin, both
lorem rows, and paletted-zune. Smaller inputs return before sampling. The imx
caller also checks the size boundary before calling the probe.

## Stage evidence

Fresh CPU-12 `perf` profiles of the prior one-shot path attribute the dominant
cost to the Vort encoder. Percentages are exclusive symbol samples; the two
deflate columns are separate because the run writer remains outlined.

| Fixed-Up case | zlib body | zero-run writer | Adler | filter | CRC | copy |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| indexed Exoplanet | 48.44% | 16.29% | 14.73% | 17.39% | 1.08% | 1.00% |
| 128 icon | 51.12% | 32.91% | 7.37% | 3.39% | 3.53% | 0.42% |
| lorem screenshot | 52.45% | 24.22% | 11.47% | 7.51% | 2.60% | 1.47% |
| Lohengrin | 70.71% | 14.03% | 2.99% | 5.12% | 3.77% | 2.48% |

This rules out framing and another standalone Adler rewrite as the primary
fixed-Up direction. The compact pair working set targets the measured deflate
body without changing its trained syntax.

## Native A/B

Independent ReleaseFast binaries run on CPU 12 for 21 alternating rounds,
with each peer calibrated toward 500 ms per row. Every one of the fifteen
encoded byte lengths, encoded checksums, and source pixel checksums is exact.
Ratios above one mean the candidate is faster.

| Result | Before/candidate |
| --- | ---: |
| 15-row geometric mean | 1.015754x |
| 15-row aggregate | 1.043704x |
| Exoplanet indexed / ordinary | 1.027636x / 1.029563x |
| Lohengrin | 1.133324x |
| lorem oxipng / screenshot | 1.020573x / 1.007912x |
| paletted-zune | 1.015921x |

The 21-round minimum was `0.997797x` on `kodim02`, which does not select the
compact table. A dedicated 61-round, 700-ms-pair rerun measured `1.002133x`;
the matching same-binary control measured `0.999625x`. The apparent minimum
was therefore rejected as scheduling noise rather than treated as a product
regression.

## image-png reference and validation

The five-round external gate pins image-png `05ccdb9c` and fdeflate 0.3.7.
Overall native/image-png geometric and aggregate throughput become
`1.046704x` and `1.062827x`; fixed-Up rises from the previous locked
`0.954998x` to `0.968269x`. Adaptive remains `1.131493x`. Lohengrin and
Transparency Up now lead Rust at `1.028523x` and `1.061768x`, but fixed-Up as
a whole is still below parity.

The external gate passes 15 byte-exact raw inputs, 30 pixel checksums, 60
bidirectional full-pixel cross-decodes, 15 exact Up filtered payloads, 15/15
native Up size non-regressions, zero swaps, and a `1.052764x` median RSS ratio
(`246,480,896` versus `234,127,360` bytes). The compact module passes 98
ReleaseSafe tests, including exhaustive pair equality, canonical byte equality,
bounded probe cases, fdeflate goldens, and every allocation-failure point. It
also compiles for x86_64 and big-endian PowerPC64. The canonical
`png_ultrafast.zig` file is unchanged and the imx `zlibPayload` hot function
retains its `0x208c` size.

Raw profiles, binaries, scripts and complete samples are under
`/nav_env/Temp/imx-png-fixed-up-stage-20261030.NFrH5w`. The compact increment
materially narrows fixed-Up, but does not establish complete Rust parity or
cross-platform PNG encode leadership.
