# Deflate profile input generation and compile time

Date: 2026-10-24. Zig 0.16.0, Intel Core i7-10700K, Linux x86-64.
Change: `40bc702b`, based on `2cd7e82c`.

`tools/deflate_dynamic_decode_profile.zig` previously generated 65536-byte
binary and 393472-byte window-match samples during compilation. Their 459008
individual assignments, including wide mixing operations, imposed a large
compile-time evaluation cost. The tool now allocates and generates those
inputs at runtime only when builtin cases are requested. Generation completes
before the codec measurement begins; payload algorithms, lengths, names and
case ordering are preserved.

The cached old executable and source hashes were frozen before modification.
Both executables process the same frozen README/roadmap files. Their nine-row,
77-column CSVs have identical column order, case order and every deterministic
field. Only `payload_ns` is excluded from exact equality. Both outputs pass
the existing profile CSV gate, and the files-only one-row path also matches.

The new executable was independently compiled with an empty local Zig cache,
using the Debug compiler command captured from the build. Global toolchain
cache and two prebuilt link objects were reused. GNU time measured **2.08 s
elapsed** and **333068 KiB peak RSS**, approximately 325 MiB. The earlier full
check recorded roughly **6 minutes and 765 MiB** for the old tool. That older
observation is historical evidence, not a same-run controlled A/B or a
compression/decompression throughput claim.

The [JSON evidence](data/deflate-profile-runtime-x86-20261024.json) records
source/executable hashes, compiler arguments, cache scope, frozen input hashes,
CSV comparisons and the original compile observation. Its artifact directory
contains the logs, CSVs and a script that checks the source before reproducing
the new empty-local-cache compilation.

```sh
zig build run-deflate-dynamic-decode-profile -- --csv /tmp/deflate-profile.csv
zig build run-deflate-dynamic-decode-profile-gate
```
