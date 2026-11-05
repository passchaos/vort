# Deflate refined history chunks, 2026-11-05

The BT modeled refinement was limited to 65,536-byte inputs. For larger inputs
the encoder now plans 32 KiB chunks over `previous_history + chunk`, using up
to 32 KiB of history so the combined BT input stays within the 64 KiB matcher
limit. The dynamic model is built from the seed tokens after trimming the
history prefix, the modeled BT solve is trimmed again, and the selected tokens
are emitted as the chunk's DEFLATE block. Complete-wire arbitration keeps the
original one-shot plan when it is smaller.

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
| dickens | 373,468 | 370,978 | 1.0067 |
| mozilla | 658,237 | 656,989 | 1.0019 |
| mr | 330,056 | 322,364 | 1.0239 |
| nci | 94,389 | 92,971 | 1.0153 |
| ooffice | 567,752 | 566,256 | 1.0026 |
| osdb | 380,918 | 378,009 | 1.0077 |
| reymont | 268,218 | 265,496 | 1.0103 |
| samba | 318,964 | 315,240 | 1.0118 |
| sao | 764,150 | 764,752 | 0.9992 |
| webster | 291,846 | 289,510 | 1.0081 |
| XML | 141,491 | 140,027 | 1.0105 |
| x-ray | 680,965 | 677,435 | 1.0052 |

Vort is now within 0.2–2.4% of libdeflate 12 on these 1 MiB prefixes and is
smaller on sao. The largest remaining rows are mr (1.0239) and nci (1.0153).

Full-file checks:

| Input | Bytes | Vort | libdeflate 12 | Ratio | Vort time | Reference time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| sao | 7,251,944 | 5,250,700 | 5,250,751 | 0.99999 | 33.91 s | 0.41 s |
| x-ray | 8,474,240 | 5,793,349 | 5,743,947 | 1.0086 | 30.13 s | 0.30 s |

The ratio is now at or near libdeflate 12, but the encode time is roughly
80–100 times larger on these full files. That latency is the next performance
target after the remaining ratio rows.
