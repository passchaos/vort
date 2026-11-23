# Nonrecent prepared-context candidate: complete-operation screen

Status: correct isolated prototype; **not adopted** because the measured
improvement and row controls do not meet the acceptance bar. Main encoder
source is unchanged.

This follows the [primary q10 profile](../brotli-recent-evidence-full-20261123/q10-next-structural-boundary.md).
It extends shared command/distance preparation, exact counting and winning
emission to ordinary nonrecent literal-context candidate groups. The prototype
stores the accepted same-last recoding plan, corrected symbols/extra bits and
actual recent mode; it retains group order, strict ties, proposal-zero cutoff,
nonrecent early return, metadata/large-window/split fallbacks and transactional
publication. Independent distance-context writers remain excluded.

## Functional evidence

Debug and ReleaseSafe each pass 33 selected tests with 104 direct
cold/warm/count/emission wire/stat comparisons, ordinary/exact mixed commands,
static dictionary references, same-last on/off and suffix/16/full contexts.
The real Dickens 8 KiB q10/q11 pair preserves full wires while exercising 14
nonrecent groups. Real emit OOM, failed-codebook atomic capture, key mismatch,
reset/retry, quota boundaries and stats rollback pass; existing controller
tests pass 28/28.

Actual x86 ELF32 and Wasm32 WASI ReleaseSafe executions also pass all 33 tests.
The WASI test configuration explicitly reserves 16 MiB automatic stack for the
existing complete-writer/tree scratch; this is a test reservation and **not**
an encoding stack-peak measurement. The generic execution receipt records exit
zero and no trap, with exact artifact/source/object/log hashes.

The optimized public benchmark preserves all 48 complete Silesia q10/q11 wires
at 8/64 KiB and the two explicit 64/32 KiB search-ceiling wires, with independent
libbrotli 1.2.0/Vort round trips. An expanded public probe covers 156 API entries,
including the actual profiled Dickens input, caller-buffer output, allocating,
singleton/split-chunk append, RAW compound prefixes, moving allocator growth,
profile and exact-cap/cap-minus-one calls. It records zero wire/error/guard
differences. Successful requested-heap peaks and independent backing peaks
do not increase; in this matrix all recorded memory observations are unchanged.
Into's independent backing remains unavailable and is recorded as null.

`prototype-proof-results.json`, `prototype-source-sha256.json` and
`validation.json` bind the frozen candidate. `source-and-portability-proof.tar.xz`
keeps the exact source overlay, patch, final logs, test fixtures and actual
32-bit artifacts/receipts. `full-operation-samples.tar.xz` keeps public API and
complete-wire JSON plus every paired CSV/JSON invocation and exact input.

## Source-correct performance matrix

The initial 32-row pilot reused the recent-cache experiment's 8 KiB target /
64 KiB control labels. That grouping is unsuitable for this new source gate,
which admits prepared groups for **input at least 8 KiB**. The initial samples
and labels are retained; `nonrecent-declared-protocol.json` freezes the corrected
full target/control matrix before the expansion decision.

The final fixed corpus has twelve Silesia files, q10/q11, 8/64 KiB prefixes
(48 target rows), and 4 KiB prefixes (24 unaffected-control rows). Existing
paired samples are retained and the missing eight 64 KiB files and all 4 KiB
controls are measured separately. `sample_batch` identifies actual process
batches rather than treating separated captures as one simultaneous run.

Each row uses three alternating baseline/candidate process pairs, three
allocating API iterations and five Vort/reference rounds per process. CPU 2,
physical core 2 / SMT sibling 10, Intel i7-10700K, Zig 0.16.0 ReleaseFast,
native x86-64 GNU `skylake+pku+sgx`, one codec thread, observed
`intel_pstate/powersave`. Generic mode, window 16, command-state limit 8 KiB,
quality and explicit local libbrotli 1.2.0 libraries match. Allocation/free is
inside primary timing; per-round warmup and auxiliary modes are outside it.
These are local interleaved screens, not a competitor ranking or RSS gate.

| Scope | Rows | Geometric mean | 95% paired-block interval |
| --- | ---: | ---: | ---: |
| All affected target operations | 48 | 1.008252x | [1.005536, 1.010915] |
| Unaffected 4 KiB controls | 24 | 1.001021x | [0.999727, 1.002114] |
| Combined matrix | 72 | 1.005836x | not used for target claim |

The fixed-corpus bootstrap resamples process-pair blocks independently for each
actual batch/size/quality; 10,000 draws use seed 20261123. The target interval
excludes parity but its geometric mean is below 1.03x. Three rows fail 0.98x:
64 KiB q11 `reymont` 0.970918x, 64 KiB q11 `samba` 0.978718x and 4 KiB q10
`webster` 0.972724x. The candidate is rejected and no encoder source is merged.

`nonrecent-combined-summary.json` records all 72 row ratios and gate outcomes.
The original pilot and additional sample batches remain in the raw archive.
`paired_screen.py`, `combine_nonrecent.py` and `paired_ci.py` reproduce the
scope and aggregation. The prototype's own README contains the direct proof
commands; the standalone public probe source and exact Dickens fixture are
also retained.

The common plan is a validated foundation for later work, not an accepted
performance change. Literal-context proposal search remains the dominant
optimized q10 cost in the captured profile and was not eliminated by this
prototype. Further changes need new exact output/resource proof and a complete
matched operation screen; partial wins or positive sub-threshold intervals do
not establish the industry-best objective.
