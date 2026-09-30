# x86-64 Zstd full raw-block copy policy

The 2026-09-30 change closes the measured `raw256k` decoder gap on an Intel
Comet Lake host. When the build target explicitly includes ERMSB, a complete
128 KiB raw block now uses `rep movsb` instead of Zig compiler-rt's generic
runtime-sized `memcpy`. Smaller blocks, x86-64 targets without ERMSB, and all
existing AArch64 paths retain their previous implementation.

The policy is deliberately limited to the one size measured here. Zstandard
raw blocks cannot exceed 128 KiB, so the equality check selects only complete
blocks and does not make an unsupported claim about ERMSB startup costs for
shorter copies. Frame parsing still performs its complete validation pass
before any output mutation, and the copy does not read or write padding.

## Evidence

The comparison uses frozen ReleaseFast executables pinned to CPU 2. Each
executable alternates five Vort/libzstd samples internally and reports the
fastest sample for each codec; the 15 outer pairs alternate baseline/candidate
process order. Every sample decodes the same 262,159-byte frame 10,000 times,
checks the 262,144-byte output, and uses one codec thread.

The baseline is commit `21683c9c`. The reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev), built as a
Release shared library. On an Intel Core i7-10700K with Zig 0.16.0, the final
candidate improves Vort raw decode by **1.3469x median / 1.3455x geometric
mean**, wins **15/15** pairs, and has a 1.2947x minimum gain. After normalizing
each binary by its simultaneous libzstd measurement, the median/geometric gains
remain 1.3590x/1.3443x.

The final Vort path reaches **1.0355x median / 1.0357x geometric mean versus
libzstd 1.6.0-dev**. Every pair is ahead, from 1.0224x to 1.0447x. This is a
bounded full-raw-block result, not a claim that compressed Zstd workloads or
all x86 implementations lead libzstd.

The frozen executable hashes, reference-library hash, exact nanosecond
observations, input hash, build details, and reproduction command are retained
in [zstd-raw-copy-x86-20260930.json](data/zstd-raw-copy-x86-20260930.json).

## Validation and remaining work

The existing raw-copy oracle covers every 0--127-byte vector tail, independent
16-way source and destination alignment, threshold boundaries, zero/tiny
inputs, and the complete 128 KiB block while checking output guards. It passes
in ReleaseFast and ReleaseSafe. Generic x86-64 and generic AArch64 ReleaseFast
compile-only checks ensure the ERMSB path disappears on targets that do not
advertise it. The complete direct Zstd suite passes all 676 tests, the
276-case compatibility matrix has zero unsupported cases, and the complete
9,900-frame upstream decodecorpus passes with all 64 sequence-mode combinations.
The 13-row one-shot reference gate also passes against libzstd 1.6.0-dev. The
reusable matrix itself completed, but its gate retained an Apple-M1-specific
1.20x floor for `numbered_json`; the x86 row measured 0.8343x and is not
reported as a gate pass. Its raw row measured 0.9712x in that single noisy
full-matrix run.

The next decoder priority remains compressed data: on this host the current
synthetic `numbered_json`, `large_json`, and `binary_mixed` rows reach only
about 0.71x, 0.77x, and 0.72x of the older system libzstd before this change.
Those paths spend their time in Huffman/FSE sequence execution and match copy,
not raw-block copying, so this optimization intentionally does not route them.
