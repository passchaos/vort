# Brotli wide literal-root experiments on x86-64

Date: 2026-10-01

## Current gap

The packed 65--256 literal-tree tier remains Vort's largest measured Brotli
decode gap on this x86-64 host. Current repository source and roadmap inputs
were encoded by local libbrotli 1.2.0-dev and decoded through frozen
`1f93a4bb`:

| input | quality | literal trees | Vort/libbrotli |
| --- | ---: | ---: | ---: |
| `src/br.zig` | 5 | 130 | 0.6613x |
| `src/br.zig` | 9 | 104 | 0.6652x |
| `docs/roadmap.md` | 5 | 143 | 0.6399x |
| `docs/roadmap.md` | 9 | 143 | 0.6175x |

These are the then-current public repository files locked by the hashes below,
not the historical private corpus. The absolute gap confirms that the wide
path deserves priority over another small `clustered_q8` branch adjustment.

## Global nine-bit root

The first candidate changed only the wide tier from a 10-bit to a 9-bit packed
literal root. Low-tree external lookups retained their existing 10-bit table.
This halves each prepared root from 2 KiB to 1 KiB and reduced both wide setup
wrappers by roughly 560 bytes. Seven fixed-CPU-2 pairs produced:

| input | quality | median | geometric mean | wins |
| --- | ---: | ---: | ---: | ---: |
| source | 5 | 1.0316x | 1.0317x | 7/7 |
| source | 9 | 1.0245x | 1.0248x | 7/7 |
| roadmap | 5 | 0.9893x | 0.9870x | 0/7 |
| roadmap | 9 | 0.9899x | 0.9881x | 0/7 |

The table reduction is valuable for the source trees but the added 10-bit-code
fallbacks hurt the already slower roadmap rows. A global 9-bit policy was
therefore rejected.

## Format-derived adaptive policy

Tree inspection found exactly 157 ten-bit symbols in both source frames versus
211/237 in roadmap q5/q9. Source averages at most two ten-bit symbols per tree;
roadmap does not. An adaptive prototype selected 9-bit roots only when
`ten_bit_symbols <= 2 * literal_tree_count`, otherwise retaining 10 bits.

Scanning every tree after parsing preserved source gains but moved the two
10-bit controls to 0.9912x/0.9967x geometric. Accumulating the count during
header parsing and using `HuffmanTable.count_by_bits[10]` reduced the routing
decision to O(1), but roadmap q5 still measured 0.9919x median / 0.9940x
geometric with only 1/7 wins. Roadmap q9 was neutral by geometric mean only
because of a 1.0311x host outlier; its median remained 0.9982x.

The remaining cost is generated-code layout: retaining separately compiled
9- and 10-bit wide executors duplicates roughly 14 KiB of payload code and
moves the established 10-bit instances. Reversing source-level instantiation
order did not change LLVM's emitted order. A conditional link section cannot
refer to a generic comptime parameter in Zig 0.16, and copying the complete
executor solely to force a section would add maintenance risk without evidence
that the final layout wins.

All candidates verified complete output on every timed invocation and the
focused packed fast-hit, single-symbol, long-code fallback, and cursor test
passed. No production code was retained. Exact hashes and pair summaries are
in
[brotli-wide-root-x86-20261001.json](data/brotli-wide-root-x86-20261001.json).

## Next direction

A future 9-bit policy must avoid emitting a second payload executor in the
ordinary text section. Credible options are a deliberately isolated generated
executor with byte-identical 10-bit layout, or a shared root representation
whose width choice does not add a per-literal branch. Merely changing the root
width or rescanning tree metadata is now ruled out.
