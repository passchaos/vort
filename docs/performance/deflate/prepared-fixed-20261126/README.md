# Prepared fixed DEFLATE: rejected performance screen

Status: implementation and all functional gates pass; the complete formal
performance screen rejects this candidate. No production adoption is approved.
All 540 process records and their original samples remain preserved.

## Performance verdict

| Comparison | Rows | Throughput geometric mean | Lowest row | Rows below 0.98 |
| --- | --- | --- | --- | --- |
| Prepared targets | 24 | 1.08337749x, paired 95% CI [1.08009221, 1.08655783] | mr.128KiB 1.00376417x | 0 |
| Prepared small controls | 9 | 1.07187588x | mozilla.256B 0.96789274x | 2 |
| Old/current ordinary controls | 12 | 0.95179991x | nci.64KiB 0.93355023x | 12 |

The other failed small row is nci.256B at 0.97539661x. Ordinary-control
secondary weak rows include ooffice 0.94124346x, mr 0.94564816x and dickens
0.94693959x. The target mean/CI and exact-wire gates pass, but the row floor
fails. The acceptance decision is **rejected**, retaining the original gate.
These are matched probe comparisons on this development host, within the
declared API/parameter scope; the ordinary-control cause still needs code/ELF
analysis before assigning it to a production algorithm or harness layout.

## Capability and source scope

`deflate.PreparedRawFixedEncoder` retains typed matcher tables, token capacity
and a stable requested-heap ledger. It plans each actual input with the same
ordinary greedy/hash routing, sizes the complete fixed stream and writes it
once into caller output. It does not allocate, resize or remap its workspace
after preparation for inputs within the declared capacity. Caller append
growth remains an explicit, charged output allocation.

The initial API covers default strategy, greedy/hash parsing, windows through
32768 bytes and no custom dictionary provider. Lazy/optimal parsing, dynamic
and best selection, dictionaries, streaming state and zlib/gzip wrappers remain
subsequent migration work. See the [archived API contract](api-prototype.md).

Baseline is clean commit `8ccd54a59da850da724cc4d6ca79a727c659889e`.
The candidate's frozen manifest contains 2,214 source files; its manifest-file
SHA256 is `0ff9d603cbac2a2125a28bd541ca3c8d62255baf04fe388c4ca800e1aaa2f60d`.
The frozen source, original inputs, complete wires, build receipts and failed
or interrupted validation epochs will be preserved with the final package.

## Completed functional evidence

Latest focused native Debug tests pass 29 prepared-owner, 7 matcher and 11
budget tests. Actual WASI ReleaseSafe execution passes the same three groups.
The final full command also passes the current native ReleaseSafe 29/7/11
groups. These include
complete ordinary-wire comparison, independent requested-heap observers,
reject-all backing allocators after preparation, exact-cap and cap-minus-one
admission, physical OOM, retry, aliases, inherited sticky policies and shared
profile rejection across distinct ledgers. Final profile live retains actual
persistent workspace and control memory.

Untimed public preflight covers 33 inputs and three variants: old ordinary,
current ordinary and current prepared. All 99 complete wires are byte-equal
within their input row. Every wire passes Python zlib raw inflate, independent
C libz raw inflate, and old/current public `decodeRawAuto` in separate processes
(198 public decoder processes). Both Python and C zlib compile/runtime versions
are 1.2.11. These checks establish wire and decode correctness, not throughput.

The first whole-library build was deliberately terminated with exit 143 after
correctness fixes. It is separate from the current final build and is not a
pass. The current final command exits 0 with **428/428 steps succeeded and
6121/6123 tests passed (two skipped)**:

```sh
zig build -j2 test check check-wasm test-deflate-prepared-fixed \
  check-deflate-prepared-fixed-wasm -Doptimize=ReleaseSafe --summary all
```

The final receipt binds session 46721, the actual command and full logs. All
2,214 current source files were rehashed after that terminal result and still
match the frozen source. Explicit per-target build modes remain visible in the
full log; the command-wide optimize option does not override those modes.

## Frozen performance policy

Both sides use the real public caller-append lifecycle and plain
`std.process.Init.gpa`. The baseline calls
`RawDeflateEncoder.encodeFixedWithOptionsAppend`; the candidate calls
`PreparedRawFixedEncoder.encodeAppend`. A current ordinary comparison controls
for changes to the existing public path.

Preparation, precise output preallocation and one warm encode are outside the
timer. Each timed iteration includes `clearRetainingCapacity`, the whole public
append and a length mix. Input loading, hashes and decoder checks are outside
the timer. Timed wire SHA256 observes the final iteration's complete output;
the 99 preflight wires are checked separately byte for byte.

| Item | Policy |
| --- | --- |
| Build | ReleaseFast, x86_64-linux-gnu, skylake+pku+sgx on both modules |
| Host | Intel Core i7-10700K; CPU 2 governor powersave, SMT siblings 2/10 |
| Execution | CPU 2 affinity, one codec thread; quiet sampling after all builds stop |
| Parsing | hash, window 16384, min match 4, chain 32, nice 16, max match 128, candidates 2 |
| Targets | 12 original Silesia prefixes at 64/128 KiB: 24 rows |
| Small controls | nci/mozilla/ooffice at 256 B, 24 KiB and 32 KiB: 9 rows |
| Ordinary controls | 12 Silesia 64 KiB rows, old/current ordinary API |
| Sampling | 6 outer pairs, AB/BA alternating; ceil(32 MiB/input size), minimum 256 iterations |
| Statistics | geometric mean of paired elapsed ratios; 20,000 paired bootstrap draws, seed 261126 |
| Acceptance | target geometric mean >=1.03, 95% CI excludes parity, every one of 45 rows >=0.98, exact wire |

All raw samples and outliers remain in the evidence. No retry-until-pass,
minimum/best-of selection, lower quality setting or relaxed row floor is used.
The timer does not measure requested heap or RSS; allocation contracts are
verified independently. This is a warmed workspace migration comparison,
and cannot establish cold-operation parity or industry leadership.
`host.json` preserves the actual OS/kernel/compiler, policy and quiet-process
snapshot. Pre-sampling load averages were 0.40/1.55/2.15; no other
zig/vort/perf/addr2line/python3/node processes were present in that snapshot.

## Pending release evidence

[release-state.json](release-state.json) records the authoritative release
fields. Both full and sampling terminal receipts exist (exit 0). All 540 raw
records are complete; sampling lasted 243.245 seconds and has stopped.
Archive packing, independent replay, relocated-copy verification and the final
publication inventory have completed. The separately rejected
[V2/V3 screens](../prepared-fixed-variants-20261126/README.md) retain their own
source and timing epochs.
[pack.py](pack.py) preserves the base plus exact source overlay;
[verify.py](verify.py) checks archived provenance and contracts, while
[statistics_replay.py](statistics_replay.py) replays statistics from archived
bytes without running a codec or loading a foreign library.
[independent_statistics.py](independent_statistics.py) independently recomputes
the paired ratios, all confidence bounds and the acceptance gates without
evaluating the producer program. Their actual terminal results are recorded
separately from the sampling producer's verdict.

V2 restores ordinary writer inlining but fails three small and two ordinary
controls. V3 uses direct zero/one/two-byte field writes, passes all nine small
controls and reaches target GM1.25664605x, but fails three ordinary controls.
Their complete540-record source/ELF epochs are preserved separately; neither
replaces this original rejection. Static analysis identifies three inline
Work objects as the main source of the enlarged shared caller frame, without
establishing causality for the ordinary-control regressions.

The original V1 production prototype and public API documentation are saved
in local Git stash `c04cbff2ecefbb5e33fb3ea5ca1eea8bcc0b2134` and the frozen
source archive. The workspace production files now match committed main;
no prepared-fixed variant has been adopted. Any revised source or harness
starts a separately identified epoch and retains the original floors.
