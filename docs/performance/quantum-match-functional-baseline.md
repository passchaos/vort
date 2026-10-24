# Quantum matching functional baseline

Date: 2026-10-23. Zig 0.16.0, Linux x86-64, ReleaseFast public-API probe.
Reference: unmodified libmspack 0.11alpha at
`55d501976171397ccd5d5a7a1ca7da065b1d9a06`. This records wire correctness,
determinism, resource/error behavior and compressed sizes. The reference is a
decoder; it does not establish compressor ratio, throughput or HQ parity.

```sh
zig build test-quantum test-cab -Doptimize=ReleaseFast
zig build run-quantum-match-diff -Doptimize=ReleaseFast -- \
  --mspack-dir /path/to/libmspack --report /tmp/quantum-matches.json
```

The 596-case corpus covers every 10...21-bit window: 444 raw-stream cases,
120 ordinary CABs, eight split CAB sets with 2 KiB part limits, and 24 resource
and caller-output checks. Before comparison, every public-API output is
decoded natively and deterministic encoding is repeated. Raw frames are wrapped
independently into CAB records so libmspack decodes the same payload; ordinary
and split archives also decode through libmspack. The driver parses CFDATA
boundaries independently, validates frame sentinel placement and checks part
size limits. The corpus is generated, not a balanced real-file benchmark.

Greedy cases collectively select 5,608 fixed-three-byte matches, 3,792
fixed-four-byte matches and 74,155 variable matches, with 492,819 extra bits.
It includes all selector families, nonzero extra fields, window wrap below the
32 KiB frame size, complete/partial frames, near/far history, and an actual
offset of 262,131 at window 18. Greedy split sets retain 20 parts/19 split
fragments per case; literal sets retain 30 parts/29 fragments.

Selected window-18 standalone observations are:

| Generated family | Input bytes | Literal strategy | Greedy bytes |
| --- | ---: | ---: | ---: |
| random | 66019 | 66757 | 66757 |
| repeated text | 66019 | 34807 | 270 |
| JSON | 68739 | 38821 | 2470 |
| repeated source text | 66000 | 38258 | 302 |
| fixed-three/four-byte records | 2560 | 2530 | 2093 |
| variable lengths | 1624 | 1687 | 925 |
| overlapping repetition | 67772 | 10588 | 99 |

These compare two Vort strategies, not competing compressors. Candidate
selection compares complete bytes within each frame from the same current
model state. Selected greedy frames change future adaptive models, so there is
no universal whole-stream size-monotonicity promise against a fresh literal
stream. The literal strategy retains the old reference frame bytes.

Public frame APIs have complete-prefix and caller-retained-history variants.
The latter reproduces the same wire when given the complete retained suffix,
while bounding its temporary context to `historyLimit() + 32768`. Tests verify
model/progress equivalence and allocation-failure retry. With default hash log
15 the two-position table requests 256 KiB; observed logical peaks on the
selected cases above range from about 267 KiB to 726 KiB. This includes returned
output and candidate/replay buffers, excludes caller input/history and allocator
bookkeeping, and is not a comparison with libmspack memory use.

The allocating and caller-output tests cover exact output and working budgets,
`WorkingMemoryLimitExceeded`, `OutputLimitExceeded`, invalid parameters,
undersized output, and append protection. Item-level regression exercises all
257 legal match lengths and 1,884 position-slot endpoints, shared-cursor extra
fields, full-frame trailers, truncation, malformed plans, integer overflow and
OOM retry after adapted frames.

Exact input/output/probe/reference hashes and tested source digests are retained
in [the JSON](data/quantum-matching-x86-20261023.json). Deeper parsing, calibrated
compression levels, persistent hash reuse, fully progressive decode and broader
real-corpus ratio/throughput/memory comparison remain open.
