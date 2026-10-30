# PNG ultrafast zero-run tail fusion on AArch64

The PNG-trained ultrafast writer now emits a nonterminal zero run's length
symbol, length extra bits, and the zero distance symbol in one reservoir
update. The previous form called `writeBits` once for the length symbol and a
second time for the extra bits plus distance. The fused value is the same
LSB-first bit sequence, requires no new state or allocation, and is used by
both canonical wide and selected compact pair encoders.

The AArch64 `writeZeroRun` instance shrinks from `0x4d4` to `0x480` bytes.
The surrounding wide `zlibPayload` stays `0x208c`, the compact encoder stays
`0x13b8`, and all three retain their prior cache-line phase. This matters:
rejected multi-token batching variants grew the run writer to `0x588` and
caused unrelated-row regressions even when sectioned or selected. A separate
small-input direct-composition trial was also rejected at `0.99991x` aggregate
because it did not improve the 128-icon target.

## Native fixed-Up A/B

Independent ReleaseFast binaries run on CPU 12 for 21 alternating rounds,
calibrated toward 500 ms per peer and row. Every encoded length, encoded
checksum, and source pixel checksum is identical. Ratios above one mean a
faster fused candidate.

| Result | Before/candidate |
| --- | ---: |
| 15-row geometric mean | `1.014500x` |
| 15-row aggregate | `1.010116x` |
| Minimum / wins | `1.001720x` / `15/15` |
| indexed / ordinary Exoplanet | `1.010345x` / `1.006994x` |
| 128 / 32 / 16 icon | `1.049199x` / `1.034051x` / `1.014543x` |
| lorem oxipng / screenshot | `1.024509x` / `1.025736x` |

The uniform positive result is stronger than the preceding compact-table
increment: it improves both selected compact payloads and unchanged wide
payloads without a workload classifier.

## image-png reference

The five-round external gate pins image-png `05ccdb9c` and fdeflate 0.3.7.
Compared with the immediately preceding compact-pair delivery:

| Scope | Before | Fused |
| --- | ---: | ---: |
| overall geometric | `1.046704x` | `1.065875x` |
| overall aggregate | `1.062827x` | `1.083984x` |
| adaptive geometric | `1.131493x` | `1.152953x` |
| Up geometric | `0.968269x` | `0.985374x` |

The remaining weakest Up rows also move in the intended direction: indexed
Exoplanet `0.849777x -> 0.875766x`, ordinary Exoplanet
`0.867419x -> 0.883233x`, 128 icon `0.863472x -> 0.881672x`, lorem screenshot
`0.902168x -> 0.934988x`, and Kodak17 `0.952992x -> 0.965977x`.
Fixed-Up is now within about 1.5% geometrically, but uniform Rust parity is not
yet established.

## Validation

The native wide and compact ReleaseSafe suites pass 94 and 98 tests. Existing
fdeflate goldens include a 300-zero run that exercises the fused nonterminal
tail, while scalar/batched, boundary, compact/wide, and allocation-failure
oracles remain exact. The compact root compiles for x86_64 and big-endian
PowerPC64. imx targeted compressed-PNG tests and the 30-case comparison smoke
pass.

The external gate validates 15 byte-exact raw inputs, 30 pixel checksums, 60
bidirectional full-pixel cross-decodes, 15 exact Up filtered payloads, 15/15
native Up size non-regressions, and zero swaps. Median peak RSS is
`246,480,896` bytes versus image-png's `233,603,072`, a `1.055127x` ratio below
the `1.15x` cap.

Raw native/Rust profiles, rejected candidates, binaries, orchestration scripts,
and complete samples remain under
`/nav_env/Temp/imx-png-fixed-up-stage-20261030.NFrH5w`.
