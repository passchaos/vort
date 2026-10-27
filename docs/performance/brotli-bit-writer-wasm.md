# Brotli bit writer Wasm reference coverage

The independent probe compares the Brotli writer with a bit-by-bit reference
on successful writes with sufficient reserved capacity. Its frozen writer
uses general bulk stores that merge the old partial byte before writing;
Huffman retains the original implementation.

| Method | Widths | Cases |
| --- | --- | ---: |
| General | 0–63 | 49,152 |
| Huffman | 1–15 | 11,520 |
| General ninth-byte spill subset | Total field width above 64 bits | 2,016 |

Every initial offset 0–7 is covered, including highest-bit values, empty and
nonempty prefixes, zero and nonzero old partial bytes, exact and spare
capacity, and bounded/growable reserved storage. An empty fixed allocator
rejects unexpected growth. Comparing the entire backing array checks the
prefix, logical output, and all guard bytes beyond logical output, including
unused bytes within the advertised capacity. Length, bit offset and bit
position must also match.

The [frozen evidence package](data/brotli-bit-writer-wasm-20261028/) preserves
the source, probe, JS gate, compressed Debug/ReleaseFast Wasm modules and raw
logs. Native, actual wasm32-wasi Debug and ReleaseFast runs completed with
explicit exit code 0 and the same fingerprint **`0x72a93b45`**. The original
builds used Zig 0.16.0, a 1 MiB stack and affinity `0,1,3-9,11-15`.

This probe covers successful reserved writes. Failure progress and allocator
ledgers are covered by the main scalar-reference tests. Performance evidence
is maintained separately.

`source_epoch.json` and `evidence.json` record source/module SHA-256 values,
commands and completion evidence. Run `python3 replay.py --output EMPTY_DIR`
from the package to execute frozen modules, rebuild both Wasm modes and run
the native probe; `SHA256SUMS` checks the complete package.
