# Brotli joint-context histogram initialization

The joint literal planner now initializes histogram bins when they are first
used and copies the first nonempty contribution into each aggregate tree.
The selected combination preserves complete plans and output bytes while
reducing ordinary q10/q11 real-file encode time by about 1.6% in its follow-up.
This is a small internal improvement. A separate current-source Brotli 1.2.0
comparison below refreshes the absolute gap; the earlier
[matched reference epoch](brotli-joint-grouped.md) retains its original results.

## Initialization contracts

The four context-mode trials and the final selected-mode collection reset only
histogram totals. On the first literal, a histogram receives its full original
initialization before the unchanged checked `add` operation. Mode scoring and
subsequent populated-index construction skip total-zero contexts. Their private
empty representation can therefore retain old or poisoned bins without reading
those bins. Every successful nonempty histogram has exact counts and total.

Aggregate trees also reset totals first. The first positive context overwrites
the whole tree; later contexts merge into initialized bins. Remaining empty
requested trees receive full initialization before return, so all consumers
receive valid complete trees. Unrequested tail storage remains untouched.
For a disjoint literal population at most u32 maximum, every partial bin sum is
bounded by that population. Above it, aggregation retains the original full
clear and checked merge. No allocation or public option is added.

Collection retains the original checked-add overflow point: first use starts
from the same full initialization, and a positive exact total cannot become
zero within the sum of 256 u32 bins. The larger-than-4-GiB collection boundary
is supported by this invariant and checked-add primitive tests; an actual
literal traversal of that size was not performed.

## Ordinary measurements

The baseline is `fdcc266ede4d36b460fd0d9db3e385146638ac9c` plus the frozen
preceding Brotli/LZ77 changes. Isolated Zig 0.16.0 ReleaseFast executables use
one codec thread pinned to logical CPU 2 of an Intel Core i7-10700K.
Both sides call the same allocating public planned-stream API with its generic
mode and default window16. Profiling and memory controls are disabled.
The timer includes the encode call; startup encode/decode, output comparison,
hashing and freeing are outside it. Compilers and separate codec-validation
campaigns do not overlap ordinary timing.

There are 44 configurations: q10/q11 across six Silesia files at 32/64 KiB,
plus q2/q4/q8/q10/q11 literal-distribution and random controls. These are frozen
prefixes, not a full-file or all-level performance matrix.

| Initial three-sweep screen | Aggregate only | Collection only | Combined |
| --- | ---: | ---: | ---: |
| 24 real-file cases | `0.994112` | `0.987283` | `0.983048` |
| Five literal-distribution cases | `0.979115` | `0.958086` | `0.955081` |
| Fifteen random cases | `1.020176` | `1.006541` | `1.006565` |

Values are geometric means of candidate/baseline median process time ratios;
lower is faster. The screen has 528 serial processes, one timed encode per
process, with forward/reverse side order alternating between sweeps.

A second baseline/combined campaign uses six alternating AB/BA sweeps, again
528 serial processes. Each process performs three timed encodes, or 32 for
random inputs. Selection conditions recorded before this campaign completed
require a real-file geomean at most 0.99, random geomean at most 1.02 and worst
real-file ratio at most 1.02. The combination meets all three conditions.

| Follow-up scope | Combined / baseline time | Paired wins |
| --- | ---: | ---: |
| 24 real-file cases | `0.984406` | `126/144` |
| Five literal-distribution cases | `0.977994` | See raw rows |
| Fifteen random cases | `1.008688` | See raw rows |
| Worst real-file case, q11 NCI 32 KiB | `1.003345` | See raw rows |

The real-file gain is 1.56%; random controls regress 0.87% overall. Individual
control regressions reach `1.025443` (q4 random 64 KiB). Both NCI 32 KiB modes
retain small regressions. All rows and side/order samples remain in the package.
These are engineering point estimates without a statistical-significance or
all-input speed claim. No compressed-size gain is attributed to initialization.

## Current reference gap

After every compiler and codec-validation workflow completed, a separate
96-process campaign compared the selected ordinary executable directly with
Brotli 1.2.0, commit `558fc647cdaf391228d614ca85f711e02e4e583b`. Both sides use
generic mode and window16. Six real 64 KiB prefixes have four alternating
Vort/reference sweeps, one timed encode after startup encode/decode per process.
Output allocation is inside both encode timers; equality and freeing are outside.
The reused reference executable has the exact previous measured identity.
Every reference process checks encoder/decoder API versions, exact plaintext,
output guards and the actual loaded encoder/decoder/common paths and hashes.

| Six-file 64 KiB scope | Vort / reference time | Vort / reference compressed size |
| --- | ---: | ---: |
| q10 | `4.659184` | `1.097600` |
| q11 | `2.327070` | `1.121350` |

These are geometric means of per-case median ratios. Vort still takes about
4.66x/2.33x the reference time and produces about 9.76%/12.14% larger output.
All Vort wires retain their original hashes; no ratio gain is assigned.
Native/reference binaries, complete stdout, loaded-library identities, raw
timestamps and saved reference wires bind this new epoch. Earlier absolute
ratios and internal speedups are not multiplied into cumulative gains.
The campaign does not establish full-file/all-level/platform or memory parity.

## Validation and reproducibility

Independent full-clear/checked-merge oracles verify all histogram bins, totals,
empty output trees, inactive tail storage, immutable inputs and reassigned
caller-owned outputs across every tree count 1..256 and population boundaries.
The actual complete planner oracle compares every owned Plan field/slice,
null/error outcome, poisoned allocation event and scratch/failure prefix against
the original collector. It covers 72 complete choices, 48 exact/below-scratch
cases and 20 allocation-failure prefixes per variant/mode.

The package records native Debug/ReleaseFast and executed 32-bit/WASI oracles,
live joint and literal-entropy regressions, public complete-wire/requested-heap
comparisons and build smoke checks in their terminal result files. Named tests
and completed commands are recorded separately from compilation. Live tests
include zero-total poisoned contexts, which must be ignored while returned
trees are fully initialized.

The expanded aggregate oracle executes 512 additional private-empty poison
cases on native Debug/ReleaseFast, x86 Debug and actual wasm32-wasi ReleaseFast.
Each of these four runs passes three named tests. Actual collection x86/WASI
runs also pass three named tests each. Native 64-bit aggregate runs additionally
execute 768 checked large-population cases; that usize branch is unreachable
on the tested 32-bit targets. The earlier full-Histogram oracle and its native
logs retain their original identities separately.

Live joint tests pass 41/41 and literal-entropy tests 29/29 in both Debug and
ReleaseFast. The public memory test compares q10/q11 for twelve 32/64 KiB inputs,
including complete wires, peak requested bytes, cleanup and the exact measured
heap cap. All comparisons agree. Histogram initialization is not assigned a
requested-heap or RSS reduction.
The whole-encoder memory and native/Wasm build smoke completes 215/215 build
steps with 69/69 tests passed. CLI help, changed-file formatting and diff checks
also complete with exit zero. These are functional/build gates, separate from
the ordinary performance measurements.

All 44 configurations retain identical full wire lengths and SHA-256 values
across both campaigns. The read-only audit binds those signatures to preceding
frozen wires with external decoder evidence; it does not rerun that decoder.
Source overlays, complete raw measurements, commands, native identity hashes,
executed Wasm modules and terminal logs are retained under
[`data/brotli-hist-init-20261031/`](data/brotli-hist-init-20261031/).
Run `python3 audit.py --no-live` there to recompute the frozen reports.
Frozen and live-identity audits both pass: 1,152 serial measured processes,
44 configurations and 22 recorded completed check intervals. Validation and
compiler intervals remain separate from the ordinary timer campaigns.

The broader ratio/speed/memory gap remains open. Next measure full-file and
streaming workloads and improve command pricing/context preparation. Existing
unrelated Bzip2 edits prevent a safe focused commit in this shared worktree;
this increment remains uncommitted under the repository's workflow rule.
