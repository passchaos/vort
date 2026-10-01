# Brotli nine-bit roots with ten-bit sibling entries

Date: 2026-10-02. Baseline: `cc49b739`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Representation

The full 129--256-literal-tree tier formerly used a 1,024-entry, 16-bit table
for each literal tree. Most entries decode fewer than ten bits, so the high
index bit duplicates the same short symbol across both halves of each table.

The new representation stores those symbols in a 512-entry, nine-bit root.
Ten-bit leaves use a small separate table containing the two possible symbol
bytes for that nine-bit prefix. The root entry carries the pair index and two
presence flags. A byte value of zero is therefore distinct from an absent
child. Canonical ten-bit codes begin at an even code and are contiguous, so
at most 256 symbols require at most 128 sibling entries per tree.

Short root entries retain `((symbol + 1) << 4) | bit_count`. A ten-bit parent
uses bit 15 as a tag, bits 4--10 for its pair index, and bits 11/12 for the
zero/one child presence flags. All symbols are checked against the literal
alphabet before constructing roots, preventing marker collisions.

The decoder obtains the tenth bit before testing the selected presence flag.
An absent child returns to the original fallback before the staged-bit check,
preserving the old ten-bit table's error and cursor behavior. Eleven- through
fifteen-bit codes retain the existing canonical fallback. This distinction
matters because the packed-tree fallback can consume an incomplete prefix
before reporting truncation, whereas a ten-bit root hit reports it without
advancing the logical cursor.

## Storage and routing

The existing stream-size, meta-block-size, tree-count, and auxiliary-table
eligibility checks remain in force. Eligible full-tier blocks enter the new
setup directly, avoiding a simultaneously live old literal table. Other blocks
retain the existing decoders.

| Fixed table storage | Previous | Paired representation |
| --- | ---: | ---: |
| Literal root plane | 512 KiB | 256 KiB |
| Ten-bit sibling plane | 0 | 64 KiB |
| Command roots | 128 KiB | 128 KiB |
| Distance roots | 64 KiB | 64 KiB |
| Total | 704 KiB | 512 KiB |

Literal storage falls by 37.5%, and the three table families together save
192 KiB. No heap allocation is added. In the measured x86 binary, the new
setup reserves 541,472 stack bytes, versus 535,864 and 212,096 bytes in the two
nested old setup functions. These reserves include local temporary storage
but exclude common caller/payload frames, register saves, and alignment.

An intermediate layout placed the new table constructors in ordinary text.
Its clustered q8 control fell to 0.9915x median over 15 pairs. Moving the
constructors into the same isolated section as paired literal decoding restores
that control to 1.0002x median / 1.0005x geometric, with 8/15 wins. The retained
layout uses the isolated section for both preparation and execution.

## Final throughput

The final isolated executable is compared with the frozen baseline in reversed
process order. Each full comparison alternates Vort/libbrotli over five warmed
rounds and retains each implementation's best time.

| Input | Pairs won | Median | Geometric mean | Minimum pair | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 13/15 | 1.0214x | 1.0191x | 0.9915x | 0.7381x |
| roadmap q5 | 7/7 | 1.0287x | 1.0299x | 1.0241x | 0.7499x |

The reference-normalized geometric improvement is 1.0247x. All samples,
including the two negative q9 pairs, remain in the evidence; this is a median
throughput gain alongside the deterministic table-storage reduction.

Final decoder-only controls measure source q9 at 0.9973x median / 0.9968x
geometric (0/7 wins), source q5 at 0.9965x / 0.9953x (1/7), and clustered q8
at 1.0002x / 1.0005x (8/15). The source controls retain small 0.27%/0.35%
median regressions in this linked executable and remain tracked. They are not
reported as improvements. The retained tradeoff reduces the full tier's
fixed table storage by 192 KiB and improves its q9/q5 complete-frame medians
by 2.14%/2.87% while preserving the existing reference-gate floors.

## Earlier command experiments

A non-timing audit of the frozen 1,251,399-byte roadmap q9 frame counted
109,100 commands, 88,384 zero inserts, and 88,246 commands satisfying a
24-byte input-window and distance-state precondition. It also found 94,967
short non-overlapping copies, only 20 overlaps, and 836 dictionary copies.
The quality-5 frame has 118,278 commands and 93,036 such eligible zero inserts.

Despite that coverage, an inlined single-command reader with a proven 73-bit
budget measured only 0.9945x median over seven pairs, with 1/7 wins. A separate
runner sharing a 96-byte input proof over up to eight zero-insert commands
measured 0.9818x median, with 0/7 wins. Both passed their bit-budget/alignment
and padded decoder-state oracles, but their code/register/call overhead did
not repay the removed checks. Both implementations were removed.

The initial two-level literal representation used two 16-bit child entries,
requiring 384 KiB of literal storage and measuring 1.0307x median in a seven-
pair screen. Moving child presence into the root permits two byte-sized
symbols instead, reducing storage to 320 KiB while preserving truncation
semantics. Its screen measured 1.0242x median with 7/7 wins. Final measurements
use the completed byte-pair implementation and its checked literal initializer.

## Validation

The root oracle compares against the old ten-bit lookup with both canonical
fallback styles at every truncated symbol prefix. It covers complete siblings,
missing siblings, all 128 pair slots, fifteen-bit depth, literal 255, empty
input for a single-symbol tree, and rejection of symbols outside the byte
alphabet. Decoder-level tests additionally cover long-only subtrees, a refill
with nine staged bits before a long fallback, every truncated payload prefix,
all twelve copy/context/block-switch fixtures, and public tier boundaries.

All 547 direct Brotli tests pass. The local upstream differential passes
7,056 generated and 7,056 progressive cases, 1,401 fragmentation schedules,
64 high-tree truncations, and seven Large Window cases. The four-file real-
corpus matrix passes 16 one-shot and 16 progressive cases. AArch64 paired tests
are cross-compiled and linked, not executed on the x86 host.
The final 13-row local-reference gate passes its unchanged throughput floors;
the benchmark path smoke passes three valid rows and five invalid argument
combinations. Changed Zig files pass formatting checks; the full repository
check and CLI help smoke also pass.

The overall decoding-leadership goal remains open. Storage reductions and the
recorded throughput observations do not establish superiority across all
corpora, qualities, streaming APIs, or architectures.

All sample times, commands, hashes, reference builds, the non-timing audit,
and source patches for the rejected command readers are in
[brotli-paired-literal-x86-20261002.json](data/brotli-paired-literal-x86-20261002.json).
