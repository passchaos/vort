# Deflate refined history chunks, 2026-11-05

The BT modeled refinement was limited to 65,536-byte inputs. For larger inputs
the encoder now plans 32 KiB chunks over `previous_history + chunk`, using up
to 32 KiB of history so the combined BT input stays within the 64 KiB matcher
limit. The dynamic model is built from the seed tokens after trimming the
history prefix, the modeled BT solve is trimmed again, and the selected tokens
are emitted as the chunk's DEFLATE block. A second and third model learned from the
previous modeled result are also solved and kept when their cost is lower.
A fourth and fifth modeled pass are accepted only when their actual dynamic
coding cost is lower than the incumbent; the model cost alone was not a
reliable predictor and regressed samba. Complete-wire
arbitration keeps the original one-shot plan when it is smaller.

The same candidate is wrapped into zlib and gzip; raw, zlib and gzip outputs
were independently decoded with Python's `zlib`, `gzip` and raw-deflate
decoders.

## 1 MiB Silesia prefixes

| Input | Before | After | Change |
| --- | ---: | ---: | ---: |
| nci | 99,589 | 94,389 | -5,200 (-5.22%) |
| sao | 770,151 | 764,150 | -6,001 (-0.78%) |
| x-ray | 698,511 | 680,965 | -17,546 (-2.51%) |

Raw nci is 94,383 bytes and gzip nci is 94,401 bytes. The complete Deflate
test suite passes 622/622.

## 1 MiB matrix versus libdeflate 1.26 level 12

The reference sizes come from the system `libdeflate.so` level-12 zlib
compressor on the same 1 MiB prefixes.

| Input | Vort | libdeflate 12 | Ratio |
| --- | ---: | ---: | ---: |
| dickens | 372,689 | 370,978 | 1.0046 |
| mozilla | 658,045 | 656,989 | 1.0016 |
| mr | 325,627 | 322,364 | 1.0101 |
| nci | 93,675 | 92,971 | 1.0076 |
| ooffice | 567,452 | 566,256 | 1.0021 |
| osdb | 380,258 | 378,009 | 1.0060 |
| reymont | 266,657 | 265,496 | 1.0044 |
| samba | 318,596 | 315,240 | 1.0106 |
| sao | 763,777 | 764,752 | 0.9987 |
| webster | 290,906 | 289,510 | 1.0048 |
| XML | 140,894 | 140,027 | 1.0062 |
| x-ray | 678,647 | 677,435 | 1.0018 |

Vort is now within 0.13–1.06% of libdeflate 12 on these 1 MiB prefixes and is
smaller on sao. The largest remaining rows are samba (1.0106), mr (1.0101)
and nci (1.0076).

Full-file checks:

| Input | Bytes | Vort | libdeflate 12 | Ratio | Vort time | Reference time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| sao | 7,251,944 | 5,247,306 | 5,250,751 | 0.9993 | 4.87 s | 0.41 s |
| x-ray | 8,474,240 | 5,742,132 | 5,743,947 | 0.9997 | 4.42 s | 0.30 s |

The ratio is now at or near libdeflate 12, and both full sao and full x-ray are
smaller than the reference. The starred ReleaseFast timings are from the
three-pass build; the accepted fourth and fifth passes add two more BT solves
and have not been re-timed. Earlier Debug-CLI timings overstated the gap and are not used
for the performance conclusion. Latency is still the next target after the
remaining ratio rows.

The earlier model-cost fourth iteration was rejected because it raised samba
by 35 bytes even while lowering nci and mr. Replacing that acceptance test
with the actual dynamic coding cost makes the fourth pass profitable on every
measured row: nci -47, mr -349, samba -20, x-ray -229, XML -75, webster -62,
reymont -56, dickens -32, mozilla -22, osdb -19, ooffice -7, sao -2. The
fourth pass is retained. A fifth pass, accepted by the same actual-wire test,
adds further reductions: nci -36, mr -191, samba -12, x-ray -130, XML -71,
dickens -85, webster -78, reymont -24, sao -15, mozilla -10, osdb -5 and
ooffice 0. A sixth pass was measured and rejected: it saves only nci 7, mr 96, XML 20,
dickens 7, webster 7, reymont 2 and mozilla 1 bytes, with samba, sao, ooffice
and osdb unchanged. The extra BT solve is not justified by those gains; the
fifth pass remains the retained configuration. An early exit when the fourth
pass improves by at most one bit lost 9–17 bytes per tested row with no
measurable time win, so it was also not kept. Early-exit convergence checks
were also measured and left the wires unchanged with only about 0.3% timing
change, so they were not kept.

## Suffix-only planning, 2026-11-06

The chunk planner ran every BT solve over the full 64 KiB combined view even
though only the chunk suffix is emitted. A match can span at most 258 bytes, so
planning can start 258 bytes before the chunk boundary: earlier history
positions cannot influence the suffix plan, and no token starting before that
point can cross the boundary. The solve now takes a `start` position, and the
chunk planner starts all six solves at `history_len - 258`.

The complete wire is byte-identical. `encodeZlibBestAlloc` with `.best` options
produced the same SHA-256 on 1 MiB nci
(`e19f0aaeb5f834b2901d987d0bd56c08e4eaa6878e0c4aceb73ca3a6544c130a`) and
samba (`105b91617b02e285fff5bf670fdd109acb33223dee48c1366c852d55900a0835`)
with and without the change, and the 587-test deflate filter passes.

ReleaseFast `.best` 1 MiB encode times:

| Input | Before | After |
| --- | ---: | ---: |
| nci | 1.99 s | 1.64 s |
| sao | 0.71 s | 0.60 s |
| x-ray | 0.58 s | 0.49 s |
| mr | 1.77 s | 1.62 s |
| samba | 1.12 s | 0.93 s |
| dickens | 1.20 s | 0.99 s |

The saving is 8-18% per input because the DP work is roughly halved; the
one-time BT evidence build is unchanged.
