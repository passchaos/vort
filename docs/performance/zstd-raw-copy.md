# Apple M1 Zstd raw-block copy policy

For the independently selected x86-64 ERMSB full-block path, see
[x86-64 Zstd full raw-block copy policy](zstd-raw-copy-x86.md).

The 2026-09-29 change improves the native raw-frame decoder on Apple M1 Pro,
using Zig 0.16.0 ReleaseFast and Homebrew libzstd 1.5.7. It does not establish
industry-leading decoding: the final 21-run `raw256k` comparison is only
1.0659x libzstd by median, below the strict 1.20x floor used for this campaign.

## Implementation and scope

`src/zstd/frame/raw_copy.zig` separates copy kernels and their oracle from
frame parsing. On an `apple_m1` target with NEON, raw blocks of at least 64 KiB
use paired `LDNP`/`STNP` instructions when the encoded frame occupies at least
256 KiB. Small frames and short blocks retain the existing cached vector
kernel. Other CPU models retain their existing copy implementation.

The new loop copies complete 128-byte groups, declares all register and NZCV
clobbers, and copies the remaining bytes exactly. It requires no input or output
padding. The raw-frame parser still validates the entire eligible frame before
writing output; unsupported frames retain the same fallback behavior.

The frame-size condition matters. Applying non-temporal copies to every raw
block of at least 4 KiB regressed 4 KiB frames to 0.9478x and 16 KiB frames to
0.9330x by median. The final policy avoids this small-frame cost. It uses the
encoded frame length so large RLE output alone does not select streaming copies.

## Evidence

All complete-frame measurements use frozen executables, one codec thread,
identical input hashes, and alternating baseline/candidate order. Both outputs
are checked before timing, so these are warmed caller-buffer measurements.
The reference
harness keeps its existing five interleaved Vort/libzstd samples and reports the
fastest sample per codec. No agent builds ran alongside these timed campaigns.
Defender, WindowServer, Ghostty, browser, and system activity remained present;
the host was not idle.

The baseline was built from `30ebf67d` with raw-copy blob `a965268b`. The existing,
unrelated `src/br.zig` edit was present in both build inputs and was not changed.
The frozen reference binaries have SHA-256:

- Baseline: `c0e4742dc2f4863c39c3554d7ce79c9d1ed5719a2bdecca88cbdccaa8bacc0f5`.
- Final candidate: `4f628875a40160abca8ae2b964e1acc109a5bb574d2ebf3d5fda1c58bb4d2a29`.

The primary case uses 20,000 decodes per sample. Twenty-one alternating pairs
improve `raw256k` by **1.0309x median**, with **21/21 wins** and a 1.0121x
minimum. The 1.0971x geometric mean is inflated by several baseline stalls,
including a 1.4982x pair; it should not be presented as the expected speedup.
Candidate/libzstd ratios range from 1.0546x to 1.1059x, with a 1.0659x median.
None reaches 1.20x.

A separate 21-pair experiment keeps the copy helper's addresses, register
allocation, loop, and tail identical and changes only the eight temporal versus
non-temporal memory opcodes. Disassembly confirms that identity. Non-temporal
access improves throughput by 1.0274x median / 1.0352x geometric, with 20/21
wins. This comparison supports a memory-instruction benefit independently of
function layout or the new routing policy.

Fifteen additional pairs per input check size sensitivity:

| Input | Iterations/sample | Candidate/baseline median | Pairs won |
| --- | ---: | ---: | ---: |
| 4 KiB raw frame | 10,000 | 0.9944x | 4/15 |
| 16 KiB raw frame | 10,000 | 1.0057x | 8/15 |
| 128 KiB raw frame | 5,000 | 1.0074x | 11/15 |
| 1 MiB raw frame | 1,000 | 1.0008x | 8/15 |

These controls remain within 0.8% by median. The evidence supports the measured
256 KiB improvement, not a speedup at every size. Their payloads are generated
with `random.Random(size).randbytes(size)` and compressed by the same libzstd
level-1 call. This campaign did not use Downloads/private corpus because its
then-current entry condition required every synthetic row to reach 1.20x. The
user subsequently accepted the bandwidth-bound raw gap and authorized real-file
benchmarking without that precondition.

The retained [JSON observations](data/zstd-raw-copy-m1-20260929.json) contain
102 complete pairs, input hashes, binary hashes,
iteration counts, and the raw nanosecond observations. Reproduction uses:

```sh
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -j1 -- \
  --case raw256k --iterations 20000 \
  --libzstd /opt/homebrew/opt/zstd/lib/libzstd.dylib --csv /tmp/raw.csv
```

Freeze baseline and candidate executables before alternating their invocations.
For the size controls, replace `--case` with `--input FILE --name CASE` and use
the iteration counts above. Host-specific experiment scripts and rejected
variants remain in `/tmp/vort-raw-tune-20260929`.

## Rejected follow-ups

- A 64-byte alignment directive on the original Zig loop: 1.0089x median,
  12/21 wins; insufficient evidence for retaining padding.
- An indexed chunk counter: 0.9952x median, 6/15 wins.
- Advancing pointers with a separate tail length: 1.0180x median, 8/15 wins.
- That pointer loop aligned to 32 bytes: 1.0035x median, 9/15 wins.
- Larger unrolls, source realignment, multi-register `LD1`/`ST1`, and software
  pipelining did not survive the preliminary copy-kernel screen.

## Validation and remaining work

The copy oracle covers 70,656 combinations: all 128 tail lengths, independent
16-way input/output alignment, vector and non-temporal threshold boundaries,
zero/tiny blocks, and full 128 KiB blocks. Each comparison checks the decoded
bytes and both output guards. Native ReleaseSafe validation and non-emitting
cross-compilation for x86-64 Linux and AArch64 Linux without NEON pass.
All 670 direct ReleaseFast Zstd tests, the 276-case libzstd compatibility
probe, and all nine upstream decodecorpus campaigns (9,900 frames, 64 sequence
modes, with real reusable table hits) pass. `zig build check -j1`, the 13-row
reference gate, and the five-row decode-profile gate also pass. The final gate
uses the same executable hash as the timed candidate: its `raw256k` snapshot is
1.0545x libzstd, while the other twelve rows exceed 1.20x in that snapshot.

This campaign used only one-shot comparisons. The subsequent
[reusable comparison](zstd-reusable-decode.md) corrects the reference API to
`ZSTD_decompressDCtx` and explicitly labels both APIs; reusable results from
the older harness are not equivalent to that series. The hard 1.20x raw-row
entry condition is retired; broader real-file evidence is now the next gate.
