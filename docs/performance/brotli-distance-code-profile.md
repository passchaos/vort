# Brotli distance-code profile

Date: 2026-10-04. Baseline: `a050f4f7`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast. Reference encoder/decoder: local
libbrotli 1.2.0-dev (`558fc647`).

## Scope

`BrotliStreamSummary` now reports the actual distance coding path for every
copy that is applied by a compressed meta-block:

- `implicit_distance_copy_count`: the command consumes no distance symbol and
  reuses the newest ring entry;
- `short_distance_copy_count`: an explicitly decoded symbol in 0--15;
- `direct_distance_copy_count`: an explicitly decoded symbol in the configured
  NDIRECT range;
- `regular_distance_copy_count`: a postfix-coded regular distance.

These copy counters deliberately differ from the existing
`implicit_distance_command_count`: a final command can advertise implicit
distance semantics but reach the meta-block end after its insert, so no
distance is decoded and no copy is applied. The four new counters must sum to
`lz77_copy_count + static_dictionary_copy_count`; this invariant is checked by
both the library tests and the CSV/upstream gates.

The summary also exposes `max_distance_postfix_bits` and
`max_direct_distance_codes`. Classification is implemented in summary-only
distance readers, leaving the production decoder's return types, hot
functions, and state layout unchanged.

## Measured distribution

Each row uses an already frozen libbrotli frame and one summary pass. Percentages
are relative to actual applied copies, including static-dictionary copies.

| Input | Applied copies | Implicit | Explicit short | Direct | Regular | NPOSTFIX / NDIRECT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 109,099 | 990 (0.91%) | 3,225 (2.96%) | 0 | 104,884 (96.14%) | 0 / 0 |
| roadmap q5 | 118,277 | 1,135 (0.96%) | 2,226 (1.88%) | 0 | 114,916 (97.16%) | 0 / 0 |
| source q9 | 50,573 | 2,460 (4.86%) | 8,903 (17.60%) | 0 | 39,210 (77.53%) | 0 / 0 |
| source q5 | 54,074 | 3,529 (6.53%) | 8,541 (15.80%) | 0 | 42,004 (77.68%) | 0 / 0 |

This rules out direct-distance specialization for the current priority frames.
The next decoder experiment should instead specialize the existing prepared
regular-distance calculation for the block-wide `NPOSTFIX=0, NDIRECT=0`
shape, while preserving the generic path for all other Brotli streams.

A first source-level follow-up added a zero-postfix early return inside the
shared prepared-distance helper. LLVM compiled the ordinary `.text`, Large
Window, paired full-tier, 10-bit auxiliary, and 9-bit middle sections
byte-for-byte identically to baseline. Seven clean pairs on each of the four
profiled frames ranged from 0.9954x to 1.0018x geometrically, demonstrating the
remaining measurement noise rather than a code effect. The spelling was
removed without a performance claim. A useful zero-postfix optimization must
therefore specialize at block/executor scope strongly enough to eliminate the
dynamic shift in generated code.

Exact hashes, counters, and validation results are recorded in
[brotli-distance-code-profile-20261004.json](data/brotli-distance-code-profile-20261004.json).

## Validation

- Five focused ReleaseFast tests cover aggregation, distance-class boundaries,
  prepared table positivity, and truncated prepared-distance reads.
- Root-level Brotli summary tests pass, including stored and compressed frames.
- The 13-row reference benchmark gate and three-row path smoke pass with the
  extended CSV schema.
- The upstream differential passes 7,056 generated one-shot, 7,056 progressive,
  1,401 fragmentation, 64 high-tree truncation, and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases.
- The complete project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
