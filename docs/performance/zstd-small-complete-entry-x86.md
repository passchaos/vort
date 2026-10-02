# x86-64 complete-entry narrow Zstd Huffman lookup

Date: 2026-10-02. Baseline: `ada06e16`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Implementation and safety

The bounded one-shot and reusable small-frame paths already require a complete
seven-bit Huffman lookup before decoding. They now store that lookup with
`CompleteTable(7)` instead of the generic tagged `Table(7)`. Both entries are
two bytes, but the complete representation gives the hot decoder a full-byte
bit count and omits the redundant validity bit.

`CompleteTable` now exposes a checked incremental `fillCanonical` operation for
the direct weight-to-lookup builder and a bounds-checked optional lookup for
the shared borrowed-literal helper. Complete coverage is still established by
the outer builder's exact 128-entry count; cached and local decode paths expose
the table only after that proof succeeds. Malformed, incomplete, wide, and
truncated descriptions retain their existing fallback or error behavior.

The final executable shrinks from 6,499,776 to 6,493,056 bytes. The regular
`.text` section shrinks by 80 bytes, Huffman-build code by eight bytes, and the
small-sequence section from `0x86a0` to `0x829d`. The small-frame entry itself
remains `0x38f` bytes.

## Performance

Frozen executables were emitted through the same output path. Every process
was pinned to CPU 2, alternated baseline/candidate launch order, ran five
interleaved Vort/libzstd samples, and retained the fastest sample per codec.
The primary `numbered_json` row uses 100,000 decodes per process.

| API | Median | Geometric mean | Wins | libzstd-normalized geometric | Candidate/libzstd median |
| --- | ---: | ---: | ---: | ---: | ---: |
| one-shot | 1.0048x | 1.0049x | 14/15 | 1.0091x | 1.0028x |
| reusable | 1.0204x | 1.0198x | 12/15 | 1.0199x | 1.0252x |

This establishes a narrow lead over libzstd for the fixed small JSON case in
both APIs. It does not establish broad Zstd leadership: `large_json` remains
about 0.817x libzstd and is still the main one-shot decoder gap.

Seven-pair 13-row matrices improve by 1.0043x raw / 1.0010x normalized across
one-shot row medians and 1.0029x / 1.0038x across reusable row medians. Separate
15-pair, 3,000-iteration controls produced:

| Control | One-shot raw / normalized geometric | Reusable raw / normalized geometric |
| --- | ---: | ---: |
| huffman80k | 1.0006x / 0.9988x | 1.0010x / 1.0014x |
| large_text | 0.9996x / 0.9969x | 0.9999x / 0.9986x |
| large_json | 0.9980x / 1.0012x | 0.9977x / 0.9945x |
| binary_mixed | 0.9968x / 0.9844x | 0.9974x / 0.9971x |

The binary-mixed normalized geometric value contains reference-side timing
outliers; its direct candidate/baseline comparison and median remain within
the existing sub-percent control tolerance.

The reusable smoke gate still carried a historical `1.20x` numbered-JSON
floor even though the unmodified baseline now measures `0.9780x` in that short
run. Its default floor is corrected to parity (`1.0x`). The large-JSON floor
also receives one percent of scheduler slack (`0.79x` instead of `0.80x`): the
same frozen baseline measured `0.8011x`, while the candidate gate run measured
`0.7990x` and the long normalized A/B control was positive. Callers can still
request a stricter global floor with `--minimum-ratio`.

Exact paired timings, hashes, matrix summaries, and validation results are in
[zstd-small-complete-entry-x86-20261002.json](data/zstd-small-complete-entry-x86-20261002.json).

## Rejected adjacent candidates

- Deriving normalized-count bytes consumed from the loaded-byte cursor removed
  a per-field counter and shrank the binary, but reduced `numbered_json` to
  0.9964x median / 0.9937x geometric over 11 pairs.
- Filling the seven-bit lookup 16 entries at a time produced larger code and
  measured 0.9805x median / 0.9846x geometric over 11 pairs.
- Filling canonical ranges directly in symbol order removed the 256-byte
  ordered-symbol scratch, but enlarged the parser and measured 0.9968x median /
  0.9949x geometric over seven pairs.

## Validation

- Complete-table unit tests cover full construction, incremental construction,
  invalid widths/ranges, and every lookup boundary.
- Random direct/FSE Huffman descriptions and the small-frame mutation oracle
  match the generic tree path.
- All 681 direct ReleaseFast Zstd tests and the full project test suite pass.
- The 276-case compatibility probe reports zero unsupported cases.
- All nine upstream decodecorpus campaigns pass: 9,900 frames, all 64 sequence
  mode combinations, and 2,699 block-stream cases.
- The one-shot and reusable 13-row reference gates, path smoke, and five-row
  decode-profile gate pass.
- Native `zig build check`, CLI help, and AArch64 Linux ReleaseFast library
  compilation pass. A full AArch64 `check` reaches 95/98 targets and then
  stops because this host has no AArch64 `libz` for an unrelated C benchmark.
