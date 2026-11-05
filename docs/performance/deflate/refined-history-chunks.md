# Deflate refined history chunks, 2026-11-05

The BT modeled refinement was limited to 65,536-byte inputs. For larger inputs
the encoder now plans 32 KiB chunks over `previous_history + chunk`, using up
to 32 KiB of history so the combined BT input stays within the 64 KiB matcher
limit. The dynamic model is built from the seed tokens after trimming the
history prefix, the modeled BT solve is trimmed again, and the selected tokens
are emitted as the chunk's DEFLATE block. A second model learned from the first
modeled result is also solved and kept when its cost is lower. Complete-wire
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
| dickens | 373,080 | 370,978 | 1.0057 |
| mozilla | 658,122 | 656,989 | 1.0017 |
| mr | 327,414 | 322,364 | 1.0157 |
| nci | 93,858 | 92,971 | 1.0095 |
| ooffice | 567,471 | 566,256 | 1.0021 |
| osdb | 380,319 | 378,009 | 1.0061 |
| reymont | 266,929 | 265,496 | 1.0054 |
| samba | 318,738 | 315,240 | 1.0111 |
| sao | 763,983 | 764,752 | 0.9990 |
| webster | 291,355 | 289,510 | 1.0064 |
| XML | 141,194 | 140,027 | 1.0083 |
| x-ray | 679,216 | 677,435 | 1.0026 |

Vort is now within 0.2–1.6% of libdeflate 12 on these 1 MiB prefixes and is
smaller on sao. The largest remaining rows are mr (1.0157), samba (1.0111)
and nci (1.0095).

Full-file checks:

| Input | Bytes | Vort | libdeflate 12 | Ratio | Vort time | Reference time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| sao | 7,251,944 | 5,249,244 | 5,250,751 | 0.9997 | 35.79 s | 0.41 s |
| x-ray | 8,474,240 | 5,751,886 | 5,743,947 | 1.0014 | 31.91 s | 0.30 s |

The ratio is now at or near libdeflate 12, but the encode time is roughly
80–100 times larger on these full files. That latency is the next performance
target after the remaining ratio rows.
