# Zstd serial-entropy wall and the native-format frontier, 2026-11-16

## Why this note exists

The 2026-11-16 local-lever pass closed every micro-edit and labeled the ~46%
sequence-executor hotspot "a research-scale pipeline/representation redesign"
([FSE explore](data/zstd-fse-explore-20261116/README.md),
[status ledger final disposition](decode-optimization-status.md)). This note
records *why* such a redesign cannot shorten the critical path inside the
zstd wire format, with current-source references, so a future session does
not re-attempt table-repacking or executor fusion as if it were an open local
lever. It then identifies the only place a wall-breaking decode design is
actually legal: the not-yet-built native `vort` entropy stage.

No production code changes. All references below are committed `7a894d25`.

## The irreducible per-sequence recurrence

The generic FSE sequence reader is `src/zstd/sequence/raw_mixed.zig`,
`read()` (lines 47-72). One sequence performs, in order:

1. Three dependent table loads indexed by the *current* states:
   `of = state.spec.offset_fse.entries[state.of_state]` plus the predefined
   LL/ML lookups (`raw_mixed.zig:52-54`).
2. The entry supplies the field widths: `additional_bits` and `state_bits`
   are data-dependent values read out of that loaded entry
   (`raw_mixed.zig:55-56`).
3. Extra bits are read at those run-time widths, then the next states are
   computed as
   `state.ll_state = ll.next_state + readField(..., ll.state_bits)` and the
   analogous ML/OF forms (`raw_mixed.zig:67-69`).

The next iteration's table index (`*_state`) therefore cannot exist until the
current entry is loaded *and* its `state_bits`-wide field is pulled from the
bitstream. This is a load-use recurrence:

```
state_n -> entry = table[state_n] -> width = entry.state_bits
        -> bits = read(width)        -> state_{n+1} = entry.next_state + bits
```

Every link depends on the previous one. This is the FSE/ANS algorithm itself,
not a Vort code-quality artifact: the state transition is, by the zstd
specification, an arithmetic recurrence carried through a single reverse-read
bitstream. libzstd executes the same chain.

## Why representation or packing changes cannot shorten the chain

Three candidate levers are already at their physical limit in current source,
which is why no table-layout edit has positive expected value:

- **The entry is already one machine word.** The mapped FSE entry is a packed
  8-byte struct (`base` u32 / `next_state` u16 / two u8 fields), asserted at
  compile time in `fse_table.zig:26-30`, and the build emits it with vectorized
  word stores (`writePackedMappedPhase`, `fse_table.zig:36-47`). A consumer
  touching one field touches the whole cache line regardless; splitting or
  re-packing cannot remove the dependent load, only add loads.
- **The tables are already L1-resident.** A table is 256 entries x 8 B = 2 KiB;
  the LL/ML/OF triple is ~6 KiB, comfortably inside a 32-48 KiB L1. The
  recurrence is latency-bound on a *hit*, so neither table shrinking nor
  section placement (already pinned via `text_section`, `fse_table.zig:4-9`)
  can reduce the load-to-use delay that gates the next state.
- **The bit reads are already fused to a single load.** A whole sequence's
  payload+transition bits are fetched in one 8-byte unaligned read and then
  extracted purely by shifts (`field_group.Group.initProven`/`read`,
  `field_group.zig:26-43`). `readBranchless` is literally an alias of `read`
  (`field_group.zig:45-47`), confirming there is no second branch or load to
  remove. The alternative `ShiftingGroup` was measured neutral and is not on
  the hot path.

In other words, the per-iteration work is minimal; the cost is the *serial
depth* across iterations, which no within-iteration representation change
touches.

## Why ILP / SIMD cannot harvest across sequences

A vectorized decoder needs independent iterations. FSE blocks provide none:

- All three tables draw transitions from one shared bitstream cursor
  (`state.reader`, one `remaining_bits` counter) through the shared `group`
  (`raw_mixed.zig:57-69`). The LL, ML and OF transitions are therefore not
  three independent streams; they consume a common, sequentially-advanced bit
  position, so even the three conceptual tables cannot be decoded in parallel.
- Sequence `n+1`'s indices are a function of sequence `n`'s loaded entry and
  bits (the recurrence above), so there is no known address to gather ahead of
  time. A SIMD gather would still stall on the same scalar predecessor.
- The only spec-concurrency boundary is the block/frame (independent frames
  have independent state), which the existing `incremental_parallel` executor
  already exploits. There is no legal sub-block parallelism to add.

This is the same reason the earlier SIMD-Huffman-gather screen failed for
Brotli: variable-length prefix/ANS codes carry a serial "advance by the
current symbol's width" dependency.

## Why the resumable phase machine cannot be flattened for throughput

`src/zstd/source/compressed_block/execute.zig` is an explicit `switch (phase)`
state machine (`drive`, lines 10-36) rather than one fused loop. That is a
correctness requirement, not overhead: the incremental path must suspend on
`NEED_MORE_INPUT`/`NEED_MORE_OUTPUT` and resume at 26 partial-buffer points
without re-emitting bytes. Collapsing it into a goto-style fused loop (the
idea considered for Brotli) would destroy resumability. The one-shot path, by
contrast, is already a single fused loop and has no phase dispatch to remove.
This matches the Brotli disposition in the ledger.

## Where a wall-breaker is actually legal: the native format

The constraints above are inherited from the zstd *wire format*. Vort cannot
change the FSE recurrence and remain byte-compatible. The native `vort`
format is explicitly exempt from those historical tradeoffs
(`docs/native-format.md:1-6`), and its entropy stage is still open:

- Native v0 today compresses only via store / deflate / RLE /
  dictionary-patch / LDM (`native-format.md:8-10`).
- "Future ANS/FSE-style entropy" is listed as a goal, not an implementation
  (`native-format.md:97-99`).

A native entropy stage is therefore the one place decode-throughput
leadership can be pursued without the serial-ANS handcuff. Design directions
that break the recurrence (each must be measured, not assumed):

- **Interleaved independent entropy streams** within one block (rANS-style
  interleaving or per-class streams) so the state-recurrence chains are
  independent and can be pipelined or vectorized instead of sharing one
  reverse-read cursor.
- **Bounded-length / stateless prefix coding** for hot symbol classes that
  removes the dependent `table[state]` load entirely, trading some ratio for
  decode ILP on the latency-bound path.
- **Block-splittable by construction**, consistent with the native format's
  splittability and independent-corruption-localization goals
  (`native-format.md:83-94`), so parallel decode is a format property rather
  than an executor add-on.

## Gates for any future native entropy work

This is a feature/research milestone, not a micro-commit, and must not start
as an accidental frozen layout. Per `native-format.md` and the repository
adoption rules:

- Freeze golden vectors and version the frame before implementation; keep the
  byte layout explicitly experimental (`native-format.md:114-116`).
- Preserve explicit sizes, bounded memory, deterministic decode, and fuzzable
  parser states (`native-format.md:78-81`, v1 validation list at 130-137).
- Keep portable/WASM parity: `zig build check-wasm` and
  `test-deflate-wide-decode-wasm` must stay green alongside the native path.
- Clear the paired two-baseline A/B: >=3% geometric mean, 95% CI excluding
  parity, no control row below 0.98x, no wire/ratio regression beyond budget.
- Benchmark whole operations on the standard corpus against current-source
  libzstd/libbrotli/libdeflate with full provenance, not microbenchmarks.

## Explicit non-goals (do not retry without new evidence)

- Re-packing or widening the 8-byte FSE entry, or moving its section: the
  dependent load is L1-hit and already one word; only added loads result.
- Branchless / single-word field reads: already present (`readBranchless` is
  an alias; one 8-byte group load per sequence).
- SIMD gather or multi-table parallel decode of one FSE block: the shared
  bitstream cursor and the state recurrence leave no independent iterations.
- Flattening the incremental `execute.zig` phase machine: it is mandated by
  partial-buffer resume semantics.

Net: within wire-compatible zstd (and the analogous Huffman serial path in
Brotli/Deflate), decode throughput is bounded by the format's entropy
recurrence and the remaining measured gap is dispersed, intrinsic work. The
next genuine decode-performance lever is a deliberately decode-parallel
entropy stage in the native `vort` format, scoped as its own milestone.

## Postscript: the level-1 wide executor was instruction-bound (2026-11-16)

This note's profile and conclusions came from level-19 64 KiB prefixes and the
medium executor. The full-Silesia reference sweep decodes level-1 frames, where
the dominant path is the wide executor. Instruction sampling there showed Vort
executing about 159 instructions per sequence versus about 117 for libzstd
1.6.0 on the same wire: an instruction-throughput gap, not a stall on the FSE
recurrence. Localizing the output cursor and the three FSE states (matching the
compact and medium executors) improved the twelve-file level-1 ratio by 4.72%
geometrically with 12/12 wins
([evidence](../data/zstd-wide-state-localization-20261116/README.md)). The
non-goals below remain valid for table repacking, SIMD gather and phase
flattening, but "no local lever remains" applies to the level-19 medium path,
not to per-sequence state traffic in the wide path.
