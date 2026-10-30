# DEFLATE adaptive split bit-state scoring

The dictionary-free one-shot adaptive chooser now scores its unsplit and K2
split plans from the live `BitWriter.bit_index`. It reproduces the production
writer's byte-rounded block-type selection, then advances the exact bit state
across both prospective blocks. This replaces the former approximation:

```text
rounded_bytes(first from offset 0)
+ rounded_bytes(second from offset 0)
+ one conservative byte
```

## Shared production selector

`selectBestBlockBitCost()` is now the single authority used by both the
production writer and adaptive scorer. For the current bit offset it computes
the closed-byte footprint of stored, fixed, and dynamic blocks and preserves
the existing tie order:

```text
stored > fixed > dynamic
```

This is intentionally Vort's existing byte-rounded policy, not a mechanical
copy of libdeflate's raw-bit comparison. After selecting the same BTYPE that
production will emit, the result records exact added bits and the next bit
offset. Stored blocks include header padding, LEN/NLEN, multiple 65,535-byte
chunks, and always end byte-aligned.

The scorer receives only the live `u3` bit offset. It cannot mutate the writer,
allocates no memory itself, and uses checked arithmetic for accumulated state.
Fixed/dynamic costs already include BFINAL/BTYPE, payload, extra bits, and EOB;
BFINAL's value therefore does not require a scoring branch.

The scope remains deliberately narrow. Dictionary-backed and incremental
adaptive choosers retain their existing grid proxy because they also need
history-aware parsing and live matcher state before they can be called exact.
The final complete adaptive-versus-one-shot wire arbitration remains unchanged.

## Writer oracle

The focused oracle covers every incoming bit offset `0...7`, both BFINAL
values, and stored/fixed/dynamic winners. It checks all nine two-block BTYPE
combinations against actual consecutive production writes, including:

- selected BTYPE;
- complete bytes appended;
- pending bit offset;
- exact accumulated bits;
- stored lengths `0`, `1`, `65,534`, `65,535`, `65,536`, `131,069`,
  `131,070`, and `131,071`;
- byte-rounded stored/fixed/dynamic ties.

## Ordinary A/B

The baseline is clean `d4a80299`. Independent ReleaseFast executables ran on
logical CPU 2 of an Intel Core i7-10700K, with alternating process order and
one ordinary untimed warmup per process.

| Scope | Sweeps | Candidate / baseline geomean | Worst case | Baseline bytes | Candidate bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 12 Silesia 192 KiB prefixes | 5 | `0.990408` | `1.008138` | `910,041` | `910,041` |
| Dickens/Mozilla/Samba 512 KiB | 3 | `1.008822` | `1.015186` | `801,621` | `801,621` |

All fifteen ordinary cases preserve complete size. A separate 64-case mixed
random/text/JSON/periodic multi-block screen also preserves every size
(`9,353,648` bytes on both sides). A fresh raw/zlib/gzip probe produced 36
wires that are byte-identical to the prior K2 baseline and independently decode
with system zlib.

This increment is retained as a correctness and architecture improvement, not
as a new ratio claim: the current corpora do not change boundary selection.
It removes a known modeling error and establishes a production-shared state
transition for the next history-aware/incremental scorer without exceeding the
pre-registered `1.02x` geomean and `1.05x` row limits.

Raw timings, exact wires, source overlay, identities, commands, and audit are
retained in
[`data/deflate-adaptive-bit-state-20261030/`](data/deflate-adaptive-bit-state-20261030/).
