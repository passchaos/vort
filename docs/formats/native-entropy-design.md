# Native Vort entropy stage design (interleaved rANS)

Status: **proposal, no wire bytes frozen.** This is the design-first artifact
required by [native-format.md](../native-format.md) ("Before implementation,
write golden vectors and version the format so experimental encoders do not
accidentally become permanent compatibility promises"). Nothing here is a
compatibility commitment; the byte layout is illustrative until a versioned
experimental encoder lands with golden vectors.

## 1. Problem this stage exists to solve

The wire-compatible codecs are throughput-bound by an entropy recurrence that
Vort cannot change without breaking compatibility. The mechanism is proven in
[zstd-serial-entropy-wall-20261116](../performance/zstd-serial-entropy-wall-20261116.md):
in FSE/tANS the next table index is
`state_{n+1} = entry.next_state + read(entry.state_bits)`, a load-use chain
through one shared reverse-bit cursor, so iterations cannot be gathered or
pipelined. The same serial "advance by the current symbol's width" dependency
blocks SIMD Huffman gather in Brotli/Deflate.

The native `vort` frame is explicitly exempt from those historical tradeoffs
([native-format.md](../native-format.md) goals), and its entropy back-end is
still open: v0 ships only store / deflate / RLE / dictionary-patch / LDM
(`src/store.zig` flags 0-5), and "future ANS/FSE-style entropy" is a stated but
unbuilt goal. This design fills that gap with an entropy stage whose decode
critical path is parallel **by construction**, targeting the measured ~46%
sequence-executor hotspot rather than adding another general compressor.

## 2. Chosen approach: interleaved rANS for sequence symbols

### 2.1 Why rANS and why interleaving

Range Asymmetric Numeral Systems (rANS) encodes each symbol `s` with
frequency `f_s` and cumulative `b_s` over a fixed normalization constant `L`.

Decode step for one state `x`:

```
slot = x mod L
s    = symbol whose [b_s, b_s + f_s) interval contains slot   // table lookup
x    = f_s * (x / L) + slot - b_s
while x < L: x = x * R + read_renorm_byte()                   // refill
```

A single rANS state is still serial. The throughput change comes from
**interleaving N independent states** `x_0 .. x_{N-1}` and assigning symbols
round-robin (or per symbol class). Each `x_i` is a self-contained recurrence
with its own renormalization byte stream:

- state `i`'s next value depends only on `x_i`, its frequency table, and
  stream `i` — never on `x_j`;
- the N per-step recurrences are therefore independent and the superscalar
  core can issue them concurrently, and a fixed-N formulation maps directly to
  SIMD lanes later;
- this is the standard high-throughput rANS construction (interleaved/rg-rANS
  style), and it removes the single shared cursor that makes FSE serial.

The contrast with the documented wall is structural: FSE has one state and one
reverse bit cursor per table; interleaved rANS has N states and N independently
indexed renorm streams, so decode ILP is a property of the format rather than
something an executor must manufacture.

### 2.2 Scope of the first milestone

Attack the proven hotspot with the smallest reviewable surface:

- **Sequence symbols (the LL/ML/OF equivalent)** are coded with N-way
  interleaved rANS. This is the ~46% executor cost.
- **Literals stay Huffman** in stage 1. Huffman literal decode already has a
  working X1/X2 path and is not the dominant serial cost; replacing it is a
  later, separately-gated decision.
- **The LZ77/match front-end is reused.** Ratio is governed mostly by match
  finding, which Vort already invests in; swapping only the entropy back-end
  isolates the throughput change and keeps the ratio budget defensible.
- Store / RLE / deflate / dictionary / LDM modes are untouched and remain
  valid; the new mode is additive.

### 2.3 Fixed parameters chosen up front for determinism

These are constants, not runtime-adaptive knobs, so identical inputs always
produce identical bytes (the repository determinism contract):

- `N = 4` interleaved states per coded symbol class. Four fills a modern
  superscalar window without bloating per-block headers; `N=8` is a measured
  later variant, not a config field.
- Frequency precision `L = 1 << 12` for the first implementation. This bounds
  the cumulative-freq lookup table to 4,096 entries and keeps renorm in byte
  granularity (`R = 256`). Wider `L` (1<<16) is a ratio/speed tradeoff to test
  with the paired A/B, not a default.
- Symbol-to-lane assignment is fixed round-robin by symbol ordinal; no
  content-dependent lane selection.

## 3. Alternatives considered

- **Keep tANS/FSE and repack the table.** Rejected on the evidence in the
  serial-wall note: the entry is already one 8-byte word, the tables are
  L1-resident, and repacking cannot break the recurrence. No expected gain.
- **SIMD gather over one FSE block.** Rejected: the shared cursor and the
  state recurrence leave no independent iterations to gather.
- **Pure stateless / bounded-length prefix coding for all symbols.** Retained
  as a fallback for specific hot classes, not the primary design. It removes
  the dependent load but gives up some ratio versus ANS; it should be adopted
  only where a measured class shows the ILP gain outweighs the size cost.
- **Bigger Huffman tables / wider lookups.** Already screened below the 3% bar
  in the wire codecs and does not change serial depth.
- **Parallel frames only.** Already done (`incremental_parallel`). Frame-level
  parallelism does not help single-block latency, which is the weak-row
  problem; interleaving adds sub-block ILP.

## 4. Format and block sketch (non-normative)

The native frame header is the existing 32-byte `VORT` layout in
`src/store.zig` (`magic, version, flags, reserved, uncompressed_size,
stored_size, checksum, reserved`). The new entropy mode must not silently
extend v0:

- Introduce it behind a **new experimental `version` (v1)** and a new `flags`
  value (the next free tag after `flags_dictionary_deflate = 5`). v0 parsers
  keep returning `UnsupportedVersion`/`CorruptFrame` for unknown tags, so old
  decoders fail closed rather than misreading the payload.
- A v1 entropy block is independently decodable, preserving the native
  splittability and independent-corruption-localization goals:

```text
entropy_block :=
    block_header
    huffman_literal_section            // stage 1: unchanged literal coding
    rans_section
    match_command_section              // LZ77 lengths/distances, rANS-coded
block_header :=
    regenerated_size : u64             // drives bounded-output / bomb rejection
    literal_encoded_len : u32
    rans_stream_count (= N) : u8
    per_lane_renorm_len[N] : u32       // independent, seekable renorm streams
    freq_table                        // bounded, normalized to L
    freq_table_crc : u32
```

- Each rANS lane owns a contiguous renorm byte span with a length in the
  header, so lanes are independently indexable and a corrupt/truncated lane is
  localized to that block.
- The frequency table is normalized to exactly `L`; the encoder rejects
  distributions that cannot normalize within the bounded alphabet, and the
  decoder validates the sum before constructing lookup state.

## 5. Hard-constraint mapping

These are non-negotiable and map onto existing machinery rather than new
policy:

- **Bounded memory / decompression bombs.** `regenerated_size` is declared up
  front and flows through the existing `frame_decoded_max` /
  `OutputLimitExceeded` / `SizeMismatch` checks used by the other native modes.
  rANS decode state is O(alphabet + N), independent of input length; no
  input-proportional scratch.
- **Determinism.** Fixed `N`, `L`, lane assignment, and normalization; no
  threads or adaptive choices in the byte-producing path. Parallel *decoding*
  produces the same bytes as scalar decode.
- **Explicit sizes and checksums.** Reuse the native frame CRC-32 contract and
  add the per-block frequency-table CRC so a corrupted table is caught before
  decode.
- **Portable/WASM parity.** A scalar reference encoder and decoder land first
  and are the correctness oracle. Any SIMD acceleration is a later,
  dispatch-gated twin that must emit identical bytes; the WASM build uses the
  scalar path. `zig build check-wasm` and the WASI decode gates must stay green.
- **Resumability.** The block decoder exposes the same phase/suspend contract
  as `compressed_block/execute.zig` so incremental and one-shot paths share
  semantics; interleaving is internal state, not a new streaming model.

## 6. Implementation plan (scalar oracle first, no early perf claim)

1. **Standalone `src/rans/` module** (new, keeps `src/store.zig` from growing
   past its current size): `table.zig` (frequency normalization + cumulative
   lookup), `encoder.zig`, `decoder.zig`, each with scalar reference logic and
   unit tests. Pure codec, no frame I/O.
2. **Differential oracle tests** for the codec alone: round-trip across empty,
   single-symbol, full-alphabet, skewed, and maximum-alphabet distributions;
   hand-computed rANS state vectors as golden anchors; renorm boundary cases.
3. **N-way interleaved encode/decode** with independent renorm spans and
   property tests that scalar interleaved decode equals a trivial sequential
   reference for every lane count and alignment.
4. **Native v1 frame wiring** behind the experimental version/flag: block
   header parse with fail-closed unknown-tag handling, bounded-output
   admission, checksum and table-CRC validation, one-shot then incremental.
5. **Corpus round trips and fuzzing** (section 7), then and only then
   performance work and the SIMD twin.

Each step is a small commit with tests; no step claims a throughput number
until the adoption gates in section 8 run.

## 7. Golden vectors, fuzzing, and differential strategy

- **Golden vectors.** Check in small, hand-derived frames (fixed N=4, L=4096)
  with exact expected bytes and decoded output, generated first from the scalar
  reference and then frozen. The experimental encoder is rejected if it ever
  drifts from a frozen vector.
- **Structure-aware fuzzing.** Extend the existing
  `tools/codec_differential_fuzz.zig` generator family to emit v1 rANS blocks
  and run the same truncation/byte-mutation matrix. There is no external
  reference for the native format, so the invariant is Vort-scalar vs
  Vort-optimized (and later SIMD) decoders must agree on every input, and any
  mutation must either be rejected or decode to identical bytes; no successful
  decode may diverge across the decoder variants.
- **Bounded-resource fuzzing.** Mutate `regenerated_size`, per-lane lengths,
  and the frequency table to assert `OutputLimitExceeded`, `CorruptFrame`, and
  table-CRC failures fire before large allocation, mirroring the native memory
  test suite.
- **WASM execution.** The scalar decoder must pass an actual WASI behavioral
  run, not only compile, matching the current `test-*-wasm` discipline.

## 8. Adoption gates

A native rANS mode only becomes a selectable default after all of the following,
on the standard text/JSON/source/binary/log/small/repetitive/already-compressed
corpora with full provenance (competitor version, CPU, build mode, thread
policy, size, throughput, memory scope):

- Round-trip and golden-vector correctness across the full boundary matrix,
  plus zero cross-decoder disagreements in the differential fuzz campaign.
- Portable parity: `zig build check-wasm` and the WASI decode gates green;
  SIMD path byte-identical to the scalar oracle.
- Paired two-baseline A/B for decode throughput: at least 3% geometric-mean
  improvement with a 95% confidence interval excluding parity, and no control
  row below 0.98x.
- Ratio budget: native rANS size versus the current native best mode within a
  predeclared tolerance; any ratio loss must be justified by the decode gain and
  reported per corpus class, never hidden in an aggregate.
- Memory: no input-proportional decoder allocation; peak scratch bounded and
  preflighted through the existing native allocation report tooling.

## 9. Open questions to settle by measurement, not assumption

- `N = 4` versus `8`: header overhead and ILP saturation on both x86-64 and
  AArch64.
- Precision `L = 4096` versus `65536`: ratio gain against table-build and cache
  cost.
- Whether literals also move to rANS or keep Huffman once the sequence path is
  proven; decided with a separate A/B, not bundled in.
- Byte-granular versus wider renormalization base and its effect on the
  per-lane span lengths and truncation behavior.
- Whether a stateless prefix fallback wins for specific high-frequency symbol
  classes after real distributions are observed.

These are intentionally left open so the first implementation stays a clean,
testable scalar oracle; each is resolved with the same paired-evidence bar
rather than folded into the initial design.
