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

The remaining cost in that prototype was generated-code layout: retaining separately compiled
9- and 10-bit wide executors duplicates roughly 14 KiB of payload code and
moves the established 10-bit instances. Reversing source-level instantiation
order did not change LLVM's emitted order. A conditional link section cannot
refer to a generic comptime parameter in Zig 0.16, and copying the complete
executor solely to force a section required separate evidence.

## Retained isolated middle tier

The final implementation limits 9-bit roots to the existing 65--128-tree
middle tier and places its explicit setup and payload executors in the separate
`.vort_br_wide_lookup9` ELF section. Streams with 129--256 trees retain the
original 10-bit full tier. This removes runtime policy metadata, preserves the
header layout, and keeps roughly 8.6 KiB of 9-bit code out of ordinary `.text`.
The 9-bit lookup remains half the size of the 10-bit table.

Against frozen `2b2950f3...`, 15 source-q9 pairs improve by 1.0231x median /
1.0222x geometric mean with 15/15 wins and a 1.0093x minimum. The candidate
reaches 0.6814x median local libbrotli throughput. Seven-pair controls are
neutral-positive:

| control | median | geometric mean | wins |
| --- | ---: | ---: | ---: |
| source q5 (130 trees, 10-bit) | 1.0033x | 1.0043x | 5/7 |
| roadmap q5 (143 trees, 10-bit) | 1.0050x | 1.0038x | 5/7 |
| roadmap q9 (143 trees, 10-bit) | 1.0014x | 1.0011x | 4/7 |
| `clustered_q8` | 0.9997x | 0.9985x | 7/15 |

The clustered geometric result contains two approximately 0.989 scheduling
samples; its median and win count are neutral, and the route is not selected.
Every timed invocation verified complete Vort and libbrotli output. The focused
9/10-bit fast-hit, single-symbol, long-code fallback, table-size, and cursor
oracle passes, together with all 541 direct tests, the 13-row reference gate,
the upstream and real-corpus differentials, and the full repository check.

Exact hashes and pair summaries are in
[brotli-wide-root-x86-20261001.json](data/brotli-wide-root-x86-20261001.json).

## Literal-state cache follow-up

A non-timing pass over the retained source-q9 route counted 20,486 decoded
literals but only 204 nine-bit root misses (1.0%). It also found 10,965 short
insert runs and only ten literal block switches. The next cost was therefore
not Huffman fallback coverage: every command reloaded the active context-map
base, context mode, and block countdown even though that state almost never
changed.

The isolated 9-bit executor now keeps the active map pointer, mode, and block
remaining count locally across commands. It synchronizes the countdown before
a validated block switch and commits it through the same error-safe defer path
as the output cursor. The 10-bit and low-tree executors are unchanged.

Against frozen `0ae320e3...`, 15 source-q9 pairs improve by another 1.0127x
median / 1.0116x geometric mean with 15/15 wins and a 1.00035x minimum.
libbrotli-normalized geometric improvement is 1.0137x. Final candidate
throughput reaches 0.6910x median / 0.6918x geometric local libbrotli, so a
large literal-loop gap remains despite the two retained steps.

All 541 direct tests, the reference gate, upstream differential, real-corpus
matrix, and full repository check pass again.

## Reader-refill follow-up

The same non-timing pass shows that root coverage is no longer the immediate
problem: 20,486 literals produce only 204 root misses (1.0%). The executor
processes 10,965 insert runs and only ten literal block switches. Context and
tree use are broad rather than dominated by one lookup, so the next bounded
probe targeted the bit reader.

A 9-bit-only peek variant loaded seven bytes whenever fewer than nine bits were
staged and the current reservoir held at most eight. Command, distance, 10-bit,
and all other reader paths retained the established 7/6/4-byte policy. The two
9-bit payload instances shrank by 177 and 441 bytes, but 15 source-q9 pairs
regressed to 0.9763x median / 0.9770x geometric mean with 0/15 wins. This
reproduces the historical 10-bit seven-byte-refill result: fewer refills do not
repay the altered dependency and branch structure. The candidate was removed.

A current-block table of 64 direct context-to-lookup pointers was also
rejected. It removed the tree-index load and scaled root address on fast hits,
while the canonical tree index was read only on the 1% miss path. Building and
retaining the 512-byte pointer table expanded the two executors by 606/311
bytes and measured 0.9698x median / 0.9662x geometric mean with 0/15 wins.
The retained byte context map plus indexed lookup has the better cache and
register footprint.

## Single-literal run follow-up

The command audit counted 50,530 commands: 39,571 insert no literals and
10,959 have a non-zero insert. Of those non-zero runs, 7,166 (65.4%) insert
exactly one literal; lengths two and three occur only 1,634 and 825 times.

Duplicating the complete literal transition for `insert_len == 1` was rejected.
It expanded the two 9-bit payload instances by roughly 1.6 KiB and measured
0.9922x median / 0.9914x geometric mean with 1/15 wins. The retained variant
keeps one literal body and only chooses `run_len = 1` before the existing loop,
avoiding the remaining/min calculation without code duplication.

Against frozen `9e10eead...`, 15 source-q9 pairs improve by 1.0071x median /
1.0083x geometric mean with 15/15 wins and a 1.00265x minimum. Final candidate
throughput reaches 0.6971x median / 0.6974x geometric local libbrotli. All 541
tests, reference/upstream/real-corpus gates, and the full repository check pass.

Extending the shortcut to block-local runs of two and three literals was
rejected. Although those lengths occur 1,634 and 825 times, the additional
remaining-count and block-boundary condition measured 0.9949x median / 0.9944x
geometric mean with 2/15 wins. Production remains restricted to the exact
single-literal invariant.

## Wide zero-insert command roots

The retained source streams have ten command block types. Of 50,530 commands,
39,571 (78.3%) insert no literals, but the wide executor still decoded a 9-bit
command symbol and then loaded compact metadata separately. The middle-tier
wrapper now prepares the existing 32-bit, 10-bit command roots for up to the
complete 32-tree inline command tier whenever the established auxiliary
distance lookups are available.

Zero-insert root hits carry copy base, copy extra-bit width, and implicit-
distance state directly. Non-zero inserts, long Huffman codes, block switches,
malformed input checks, and the canonical fallback keep their existing paths.
The active command root/tree pointers are refreshed only at a command block
switch. Streams that cannot use the external roots retain the prior executor
instance.

Against frozen `62d1663a...`, 15 source-q9 pairs improve by 1.0202x median /
1.0200x geometric mean with 15/15 wins and a 1.00064x minimum. Seven source-q5
pairs improve by 1.0223x median / 1.0234x geometric, also 7/7. Final candidate
throughput reaches 0.7099x/0.7090x median local libbrotli at q9/q5.

All 541 direct tests, reference/upstream/real-corpus gates, and the full
repository check pass.

## Rejected literal root-slot offsets

A smaller follow-up to the rejected 512-byte context-to-pointer table expanded
the active 64-byte context map into 64 `u16` root-slot offsets. The 128-byte
table encoded `tree_index << 9`, so a fast hit could combine the stored offset
with the reader's nine-bit prefix and index the continuous lookup plane
directly. Canonical tree indices were recovered only on the 1% miss path.

The generated hot loop removed the scaled root-address chain and the isolated
section grew by only 80 bytes, from 15,952 to 16,032 bytes. The extra map load,
block-switch rebuild, and register pressure still erased the instruction win:
15 source-q9 pairs measured 0.9991x median / 0.9995x geometric raw throughput
with 7/15 wins. Local-libbrotli-normalized results were 0.9999x median / 0.9966x
geometric, also 7/15. The candidate was removed.

## Wide external distance roots

The retained command-root wrapper now also prepares the existing external
nine-bit distance roots for the complete 64-tree inline distance tier. The
command-root payload caches the active four-entry distance context-map slice
and its dominant context-three tree, refreshing them only on a non-implicit
distance block switch. Implicit last-distance commands, long-code fallback,
remaining-count accounting, ring updates, and malformed-input checks retain
their canonical behavior. Other wide executor instances keep the prior
in-header tail lookup.

This adds a bounded 64 KiB root plane and grows the isolated section from
15,952 to 17,493 bytes. The measured source frames use 37 distance trees at q9
and 38 at q5. Against frozen `ead94ef5...`, 15 source-q9 pairs improve by
1.0315x median / 1.0317x geometric raw throughput with 15/15 wins and a
1.0256x minimum. Libbrotli-normalized median/geometric improvement is
1.0290x/1.0311x. Seven q5 pairs improve by 1.0274x / 1.0276x, also 7/7 with a
1.0237x minimum. Final candidate throughput reaches 0.7351x/0.7246x median
local libbrotli at q9/q5.

The progressive differential initially exposed a harness assumption rather
than a decoder mismatch: system libbrotli 1.0.9 may advertise WBITS=16 after a
q10 request for lgwin=10. The harness used the requested value and allocated
only 1,008 history bytes, then correctly rejected a 7,680-byte match from the
actual WBITS=16 frame. Progressive history is now sized from the frame's RFC
window code. The candidate then passes all 541 direct tests, the 13-row local
libbrotli 1.2.0 reference gate, 7,056 generated and progressive upstream
cases, 1,401 fragmentation cases, 64 high-tree truncations, seven Large Window
cases, and the four-file 16/16 real-corpus matrix.

## Rejected context-three distance pointer

A non-timing pass over the retained source-q9 frame counted 50,574 commands,
39,619 zero-insert commands, and 50,573 distance transitions. Only 2,460
transitions use the implicit last distance. Of 48,113 explicit distance
symbols, 47,701 (99.14%) use RFC distance context three, 47,893 (99.54%) hit
the external nine-bit root, and 39,210 (81.49%) are regular symbols at least
16. All 37 prepared distance trees are used; reducing root coverage would not
fit this stream.

Despite that dominance, caching a direct pointer to the context-three distance
root was decisively slower. The pointer and its block-switch refresh grew the
command-root payload and isolated section by 103 bytes. Five source-q9 pairs
measured 0.9343x median / 0.9347x geometric raw throughput with 0/5 wins;
local-libbrotli-normalized median/geometric throughput was 0.9382x/0.9384x.
The candidate was removed. The retained cached byte tree index plus scaled
root address has materially better register allocation and code layout.

## Next direction

The 65--128 tier is faster, but source q9 still reaches only about 0.74x
libbrotli. Root width, refill size, pointer tables, and root-slot offset maps
are now bounded out; the context-three audit also rules out retaining another
hot pointer. The next useful work is a genuinely smaller regular-distance
transition or executor representation that reduces live state, not another
active-block cache. The 129--256 tier should stay at ten bits unless a
separately isolated policy improves its slowest row.
