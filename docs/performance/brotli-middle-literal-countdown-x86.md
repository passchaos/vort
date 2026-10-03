# x86-64 Brotli middle-tier literal countdown short-circuit

Date: 2026-10-03. Baseline: `bd289c98`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Scope and invariant

The 65--128 literal-tree executor keeps a local countdown for the current
literal block. Its per-literal loop previously loaded the header's
`block_type_count` before testing that countdown. A preceding audit of the
same source-family q9 path found 20,486 literals and only ten literal block
switches; the current frozen q9 frame contains 20,459 literal bytes.
The retained change tests `literal_block_remaining == 0` first, so the common
case short-circuits without reading the header field.

The two predicates and switch body are unchanged. When the countdown reaches
zero, the executor still reads `block_type_count`, switches only when more
than one type exists, and refreshes the same local block state. No bitstream
read, output write, error condition, allocation, public API, or format
behavior changes. The full 129--256 tier and generic paths are untouched.

The selected middle-tier function grows from `0x109e` to `0x112e` bytes and
the complete `.vort_br_wide_lookup9` section from `0x4269` to `0x438a` bytes.
The increase is accepted because it removes a repeated dependent header load
from the selected hot loop. The Large Window, paired full-tier, and wide10
auxiliary sections retain their addresses and sizes and are byte-identical to
baseline; their respective SHA-256 values are `2c4e6713...a88048fa`,
`4abc6e76...5e9395`, and `e4b18ce2...7ec3a92`.

## Performance

The frozen 1,726,567-byte source input has SHA-256
`b75cf6294797c217c0e4a17054a65c5e2d6a355529eccd65c7fd94c24f26fff0`.
Its q9/q5 frames are 141,001/147,580 bytes, contain 20,459/23,048 literal
bytes, and select the 104/117-tree middle tier. Each decoder-only process uses
500 iterations. Each reference process
uses 100 iterations and times Vort and libbrotli in the same process. Both
protocols alternate baseline/candidate launch order, and every binary was
built once to a fixed path before the measurements began.

| Input | Decoder-only median / geometric | Wins | Reference raw / normalized geometric | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: |
| source q9 | 1.0061x / 1.0067x | 14/15 | 1.0040x / 1.0004x | 0.7305x |
| source q5 | 1.0035x / 1.0034x | 13/15 | 1.0135x / 1.0061x | 0.7274x |

The same-process q9 campaign is noisier than the longer decoder-only run and
normalizes to near neutral rather than confirming its full gain. The q5
campaign remains positive after normalization. Both absolute ratios remain
far below libbrotli, so this is a bounded middle-tier improvement rather than
a Brotli decode parity or leadership claim.

Clean five-pair, 500-iteration full-tier controls measure roadmap q9 at
1.0033x median / 1.0026x geometric and roadmap q5 at 1.0003x / 1.0006x. A
separate long clustered-q8 control, whose 52 literal trees do not select this
executor, measures 1.0043x median / 1.0029x geometric with 10/15 wins. Each
sample decodes the frame 1,000 times, and the full batch monitor observed no
external Zig workload. The specialized Large Window/full-tier/auxiliary
sections are byte-identical between the frozen binaries.

## Rejected adjacent candidates

- A likely hint on the recent-distance ring update measured about 0.9956x on
  source q9 and 0.9983x on roadmap q9. Replacing its four scalar assignments
  with one aggregate assignment measured 0.9989x/0.9981x; generated code
  already used a 16-byte vector move. Both were removed.
- Likely hints for the three-context literal case and the static-dictionary
  branch were neutral on source but regressed roadmap q9 to about
  0.9936x/0.9917x. They were removed.
- Unlikely hints on command-block and literal-block switches either left the
  selected code unchanged or produced a smaller gain. Combining an unlikely
  hint with the retained countdown-first order reached only about
  1.0014x/1.0026x on source q9/q5 and generated more code, so the no-hint
  form was retained.

Exact executable hashes, raw timing pairs, controls, and validation results
are in
[brotli-middle-literal-countdown-x86-20261003.json](data/brotli-middle-literal-countdown-x86-20261003.json).

## Validation

- All 549 direct ReleaseFast Brotli tests and the full project test suite pass.
- The 13-row reference gate and three-row path smoke pass against local
  libbrotli.
- The upstream differential passes 7,056 generated one-shot, 7,056
  progressive, 1,401 fragmentation, 64 high-tree truncation, and seven Large
  Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases.
- AArch64 ReleaseFast compilation, `zig build check -j2`, and the CLI help
  smoke test pass.
