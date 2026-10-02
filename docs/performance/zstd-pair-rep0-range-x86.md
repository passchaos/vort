# x86-64 Zstd paired-rep0 range validation

The 2026-10-02 change removes one redundant check from the compact
split-Huffman sequence-pair path used by the synthetic `large_json` row. Both
sequences in this path have one literal and OF code zero, so they select the
same positive-literal rep0 value without rotating the repeated-offset ring.

For the bounded-output specialization, the first literal makes the valid
history interval `1...available_history`, where
`available_history = written - frame_output_start + 1` and is always nonzero.
The unsigned predicate

```zig
match_offset -% 1 >= available_history
```

therefore rejects both rep0 zero and offsets beyond available history in one
comparison. The non-wildcopy oracle keeps the existing explicit nonzero check
and per-sequence history checks, and all literal/output preflights and exact
copy bounds remain unchanged. The wire format, public API, allocator behavior,
and persistent decoder state do not change.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. The baseline is commit `ed503bf6`; the reference is the local
Zstd checkout at `01b7154f1172432f8abe9b3bb9909e14a1176b7d`
(libzstd 1.6.0-dev). Odd pairs run baseline then candidate, and even pairs
reverse the order. The complete-frame benchmark uses 3,000 decodes per
process; the prepared-stage benchmark uses seven rounds of 1,000 decodes.

| Measurement | Median | Geometric mean | Minimum | Wins |
| --- | ---: | ---: | ---: | ---: |
| Complete `large_json` frame | 1.0120x | 1.0131x | 1.0063x | 15/15 |
| Complete frame, libzstd-normalized | 1.0143x | 1.0155x | 0.9994x | 14/15 |
| Four-block prepared stage | 1.0178x | 1.0176x | 1.0011x | 15/15 |

The final candidate reaches 0.8139x median / 0.8155x geometric local libzstd
throughput, so this is a useful executor improvement rather than a Zstd decode
leadership result. Baseline and candidate ELF `.text` sizes are both 637,193
bytes; the measured gain does not come from a whole-binary text-size change.

A seven-pair, 13-row one-shot matrix keeps `large_json` positive at 1.0120x
median / 1.0124x geometric and passes the reference gate for every run. Short
rows remain scheduler-sensitive; the row-median geometric mean is 0.9979x raw
and 1.0035x after simultaneous libzstd normalization. Longer 3,000-iteration,
15-pair controls resolve the relevant rows as follows:

| Control | Median | Geometric mean | Wins | Normalized geometric mean |
| --- | ---: | ---: | ---: | ---: |
| `binary_mixed` | 1.0032x | 1.0032x | 13/15 | 1.0010x |
| `huffman80k` | 0.9995x | 1.0000x | 7/15 | 0.9991x |
| `large_text` | 1.0065x | 1.0041x | 11/15 | 1.0027x |

An adjacent attempt to preload the current LL and OF FSE entries across the
pair body reduced the target executor from 8,822 to 8,632 bytes but extended
their live ranges. Seven complete-frame pairs measured only 0.9848x median /
0.9866x geometric throughput with 1/7 wins, so that change was removed.

Exact commands, executable hashes, observations, matrix rows, and validation
counts are retained in
[zstd-pair-rep0-range-x86-20261002.json](data/zstd-pair-rep0-range-x86-20261002.json).

## Validation

- The split-Huffman specialized-versus-generic oracle passes in ReleaseSafe
  and ReleaseFast. It covers short output, 64 sequence-bit mutations, 64
  literal-bit mutations, output suffix guards, and production route hits.
- All 679 direct ReleaseFast Zstd tests pass.
- The 276-case libzstd compatibility matrix reports zero unsupported cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, all 64 sequence
  mode combinations, incremental and reusable decoding, and 2,699 block-stream
  cases.
- Generic x86-64 and AArch64 Linux ReleaseFast compilation, the full project
  test suite, `zig build check -j1`, and the CLI help smoke test pass.
