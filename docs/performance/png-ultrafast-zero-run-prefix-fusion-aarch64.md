# PNG ultrafast zero-run prefix fusion on AArch64

The PNG-trained ultrafast writer now emits the first literal zero together
with the first following run token. Runs of 6 through 258 bytes combine the
literal, length symbol, extra bits, and zero-distance bit in one reservoir
update. Longer runs combine the literal with the first 258-byte token, while
one- through five-byte runs emit their zero-valued codes in one update. The
canonical wide and selected compact-pair encoders use the same LSB-first
construction.

This follows the earlier zero-run tail fusion. The AArch64 wide
`writeZeroRun` instance grows from `0x480` to `0x5e4` bytes, while the
surrounding `zlibPayload` stays `0x208c` and the compact encoder stays
`0x13b8`. The larger run writer is retained because the matched corpus result
is uniformly positive rather than depending on a few small images.

## Native fixed-Up A/B

Independent ReleaseFast binaries ran on CPU 12 for 21 alternating rounds,
calibrated toward 500 ms per peer and row. Every encoded length, encoded
checksum, and source pixel checksum is identical. Ratios above one mean the
prefix-fused candidate is faster.

| Result | Tail fusion / prefix fusion |
| --- | ---: |
| 15-row geometric mean | `1.043072x` |
| 15-row aggregate | `1.021220x` |
| Minimum / wins | `1.004246x` / `15/15` |
| indexed / ordinary Exoplanet | `1.011948x` / `1.008807x` |
| Kodak02 / Kodak17 | `1.021150x` / `1.018809x` |
| 128 / 32 / 16 icon | `1.184654x` / `1.111903x` / `1.137124x` |
| lorem oxipng / screenshot | `1.012404x` / `1.028940x` |

## image-png reference

The external comparison pins image-png `05ccdb9c` and fdeflate 0.3.7. Five
alternating rounds produce:

| Scope | Vort / image-png |
| --- | ---: |
| overall geometric | `1.080768x` |
| overall aggregate | `1.083268x` |
| adaptive geometric | `1.164011x` |
| fixed-Up geometric | `1.003478x` |
| encoded-size geometric | `0.998108x` |

This is the first fixed-Up corpus result above Rust geometrically. It is not a
uniform per-image lead: fixed-Up wins 7 of 15 rows, with indexed and ordinary
Exoplanet at `0.869611x` and `0.870745x`. Adaptive wins 14 of 15 rows and the
combined comparison wins 21 of 30. The evidence therefore establishes a
corpus-level lead, not universal Rust dominance.

## Validation and resources

The wide and compact ReleaseSafe suites pass 95 and 99 tests. A new scalar
bit-sequence oracle exhaustively checks run lengths 1 through 1,035, covering
short literals, every length-code tail, the 258 boundary, and multiple full
tokens. Existing fdeflate goldens, compact/wide equality, and allocation-
failure enumeration remain exact. The compact root compiles for x86_64 and
big-endian PowerPC64; the imx 30-case smoke passes with 60 cross-decodes.

The external gate validates 15 byte-exact raw inputs, 30 pixel checksums, 60
bidirectional full-pixel cross-decodes, 15 exact Up filtered payloads, and
15/15 native Up size non-regressions. Median peak RSS is `246,480,896` bytes
versus Rust's `233,603,072`, a `1.055127x` ratio, with zero swaps. A separate
1024 MiB address-space-capped run succeeds at `55,156,736` bytes peak RSS and
zero swaps.

Raw proofs, binaries, scripts, and complete samples remain under
`/nav_env/Temp/imx-png-fixed-up-stage-20261030.NFrH5w`.
