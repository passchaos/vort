# Deflate refined history chunks, 2026-11-05

The BT modeled refinement was limited to 65,536-byte inputs. For larger inputs
the encoder now plans 32 KiB chunks over `previous_history + chunk`, using up
to 32 KiB of history so the combined BT input stays within the 64 KiB matcher
limit. The dynamic model is built from the seed tokens after trimming the
history prefix, the modeled BT solve is trimmed again, and the selected tokens
are emitted as the chunk's DEFLATE block. A second and third model learned from the
previous modeled result are also solved and kept when their cost is lower.
A fourth modeled pass is accepted only when its actual dynamic coding cost is
lower than the third result; the model cost alone was not a reliable
predictor and regressed samba. Complete-wire
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
| dickens | 372,774 | 370,978 | 1.0048 |
| mozilla | 658,055 | 656,989 | 1.0016 |
| mr | 325,818 | 322,364 | 1.0107 |
| nci | 93,711 | 92,971 | 1.0080 |
| ooffice | 567,452 | 566,256 | 1.0021 |
| osdb | 380,263 | 378,009 | 1.0060 |
| reymont | 266,681 | 265,496 | 1.0045 |
| samba | 318,608 | 315,240 | 1.0107 |
| sao | 763,792 | 764,752 | 0.9987 |
| webster | 290,984 | 289,510 | 1.0051 |
| XML | 140,965 | 140,027 | 1.0067 |
| x-ray | 678,777 | 677,435 | 1.0020 |

Vort is now within 0.13–1.07% of libdeflate 12 on these 1 MiB prefixes and is
smaller on sao. The largest remaining rows are mr (1.0107), samba (1.0107)
and nci (1.0080).

Full-file checks:

| Input | Bytes | Vort | libdeflate 12 | Ratio | Vort time | Reference time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| sao | 7,251,944 | 5,247,502 | 5,250,751 | 0.9994 | 4.15 s* | 0.41 s |
| x-ray | 8,474,240 | 5,743,403 | 5,743,947 | 0.9999 | 3.67 s* | 0.30 s |

The ratio is now at or near libdeflate 12, and both full sao and full x-ray are
smaller than the reference. The starred ReleaseFast timings are from the
three-pass build; the accepted fourth pass adds one more BT solve and has not
been re-timed. Earlier Debug-CLI timings overstated the gap and are not used
for the performance conclusion. Latency is still the next target after the
remaining ratio rows.

The earlier model-cost fourth iteration was rejected because it raised samba
by 35 bytes even while lowering nci and mr. Replacing that acceptance test
with the actual dynamic coding cost makes the fourth pass profitable on every
measured row: nci -47, mr -349, samba -20, x-ray -229, XML -75, webster -62,
reymont -56, dickens -32, mozilla -22, osdb -19, ooffice -7, sao -2. The
fourth pass is retained. Early-exit convergence checks were also measured and
left the wires unchanged with only about 0.3% timing change, so they were not
kept.
