# Zstd repeated-offset choice dominance and original budget allowances

HQ parsing now avoids materializing redundant offset encodings when they
produce the same complete successor repeat history. Literal length and match
length are fixed for each compared edge, so only the OF table price, offset
extra bits and long-offset penalty distinguish these choices. The lowest OF
term wins; equal terms retain the first, lowest original offset. Different
successor triples remain independent.

The actual `rep.choices` order places equal successor histories in adjacent
groups. Selecting one representative per group preserves every final DP row
and strict spill tie. The local four-entry choice array is compacted in place
before the original length loop runs, retaining original winner order. No heap
allocation is added. An inline entry wrapper returns immediately for a match
shorter than the configured minimum, before entering heavy materialization.

The ordered DP path opts in only for an immutable validated entropy model and
a block at most 128 KiB. Its real bounded literal prefix is then at most 2^31.
Additional LL/ML, u64 node-cost and admission-counter guards conservatively
retain the original path for invalid or near-overflow inputs. Generic and
default direct contexts keep the original implementation; arbitrary custom
prefixes cannot grant this opt-in. The range threshold is 16 bytes.

## Budget compatibility

The first compaction prototype produced correct final plans but lowered its
reported maximum price allowance. A caller using that measured value as a
finite limit still ran the original enumeration and failed with
`SearchLimitExceeded`. The existing public cap-only regression and an
independent `abcd` repeated 64 times both reproduced this failure. That
prototype was withdrawn; its timings are not the final implementation.

The accepted path reserves the original skipped-choice allowance without
performing their prices or insertions. Exact enumeration counts include the
sampled loop's repeated endpoints and its original minimum behavior. Finite
limits continue to run the complete original enumeration and preserve every
partial state, counter and error prefix. `max_plan_price_evaluations` retains
the original allowance, while `price_evaluations` and `optimal_transitions`
report the work actually performed. This keeps an existing measured cap usable
without weakening the requested limit.

The small `enumeration_count.zig` module derives that allowance from the ML
bucket indices and compares against the frozen explicit loop. Its complete
mode is the original inclusive length count. The previous source-dominance
integration test now explicitly requests an unpruned reference ledger with a
finite maximum; its finite success/failure bounds remain strict. Existing
public resource tests and their requested caps are unchanged.

## Validation and measurements

Independent baseline/current tests verify all successor fields, tags, spill,
model immutability, ordinary/default contexts, finite quota prefixes and
overflow guards. Four target executions cover native Debug/ReleaseFast,
32-bit x86 Debug and actual wasm32-wasi ReleaseFast. The final wrapper uses
the unchanged eight-test oracle and assertions. Exact budget and maximum
allowance must match the baseline; only two actual-work counters may decrease.

The actual Zig counter oracle compares 2,357,922 sampled and 785,974 complete
enumerations. Offset selection includes 1,620,000 full-price comparisons,
325,728 compaction checks and 404,364 complete selected-choice field checks.
Thresholds 14/15/16/17, 2,448 finite prefixes, generic/default controls and 109
guards are retained. A real parser fixture verifies all four parse/length
combinations: measured cap N reproduces the complete original plan and expanded
bytes, while N-1 still fails. Sampled N stays 232,773 as physical prices fall
to 186,771; complete N stays 700,258 as physical prices fall to 518,028.

Ordinary measurements use the preceding choice-price and fixed-window shipping
source as baseline, isolated ReleaseFast executables, an Intel i7-10700K,
one codec thread pinned to CPU 2, and local libzstd 1.6.0. Profiles, input setup,
hashing and verification stay outside the timed encode/free interval. Public
requested HQ depth/nice/minimum are 64/64/3 with checksum and content size;
reference hash/chain defaults remain level-3 defaults. Actual algorithms and
visited work differ. All raw campaigns and source/binary identities are
retained separately; no compiler or codec-validation campaign overlaps final
timing.

Eight alternating AB/BA sweeps cover sixteen 4/16 KiB real, synthetic and
trained-dictionary configurations, with sixteen observations per side/case
and 160 serial processes. Two Vort/reference rounds alternate within each
process. Repetition batches 100 encodes, random batches 20, and other cases
use one call; times are normalized per call.

| Scope | Candidate / preceding baseline time | Paired wins |
| --- | ---: | ---: |
| Three real 4 KiB files, btultra2 | `0.922351` | `24/24` |
| Three real 16 KiB files, btultra2 | `0.929304` | `24/24` |
| Three real 4 KiB files, btopt | `0.926366` | `22/24` |
| Periodic 4 KiB, btultra2 / btopt | `0.736527 / 0.861028` | `8/8 / 8/8` |
| Random 4 KiB, btultra2 / btopt | `0.957879 / 0.948935` | `8/8 / 8/8` |
| Pure repetition 4 KiB, btultra2 / btopt | `0.972131 / 1.016304` | `7/8 / 2/8` |
| Trained dictionary btultra2 | `0.988674` | `7/8` |

All nine real-file median ratios improve. Every complete wire, requested and
resolved setting, non-price diagnostic field, requested heap peak and logical
maximum allowance remains identical. The pure-repetition btopt row is a
retained 1.63% regression with zero price evaluations; the change cannot be
attributed to eliminated prices on that path. These point estimates do not
establish statistical significance or all-input/platform gains.

Periodic btultra2 physical evaluations fall from 34,000,436 to 23,968,313,
while its maximum allowance stays at the original value. The first ungated
prototype's lower physical count alone was insufficient: the final allowance
reservation is essential to preserve measured-cap behavior.

A separate larger-input campaign uses exact six-file Silesia 64 KiB prefixes
and three alternating process sweeps, six observations per side/case. Its
btultra2 time geomean is `0.901950`, with all `18/18` paired wins. All full
wires, settings, heap peaks and allowances agree. The input archive is bound
to the preceding Brotli corpus identities, and shared 4/16 KiB prefixes match
the primary corpus exactly.

| Scope | Vort / libzstd time | Vort / libzstd compressed size |
| --- | ---: | ---: |
| Real 4 KiB btultra2 | `47.751724` | `0.985492` |
| Real 16 KiB btultra2 | `51.911422` | `0.995786` |
| Six real 64 KiB btultra2 | `61.934751` | `0.988703` |
| Real 4 KiB btopt | `31.240967` | `0.981975` |
| Trained dictionary btultra2 | `55.281899` | `1.012701` |

Periodic btultra2/btopt still require `28997.872 / 4510.842` times the reference
time at equal frame sizes. Random controls remain `6.214 / 5.786` times slower.
The real-file absolute gap remains substantial. Earlier epochs' ratios are
not multiplied into cumulative speed claims.

Complete live Zstd Debug and ReleaseFast suites each pass 1219/1219 after the
row-tag fixture explicitly requests the original unpruned reference ledger.
Its original profile assertions and finite prefixes remain strict. Registered
production contracts pass 20/20 in both native modes, including all five named
choice/count regressions; actual x86 Debug and Wasm ReleaseFast execute those
five names with 16/16 total tests. The original public measured-cap regression
also passes without changing its requested limit.

The public HQ Wasm gate passes four operations and 7/7 steps. The independent
reference campaign passes 41 groups and eight original frozen wire rows against
actual libzstd 1.6.0 and system 1.4.8. Source hashes stay unchanged during that
campaign. Final repository `check` / `check-wasm` passes 212/212 steps, CLI help
and formatting/diff checks exit zero. Broad compile checks do not imply full
runtime execution of unrelated codec families.

The frozen audit verifies 286 source identities, all 22 ordinary/larger-input
configurations, actual Wasm modules and 22 terminal gates. Early ungated, gated,
inline, compact and density experiments remain selection evidence. The failed
pre-build dispatch attempt is preserved and excluded from timing claims. The
temporary source-packager directory mistake was repaired with all four prior
artifacts byte-identical to their original hashes; all prior package checksums
were revalidated before the new package was sealed.

The package is in
[`data/zstd-choice-dominance-20261031/`](data/zstd-choice-dominance-20261031/).
Broad industry leadership remains unproven. Next work should reduce remaining
rejected length/state extensions while preserving logical allowances, then
extend real-file, streaming, dictionary and platform speed/ratio/memory evidence.
The full Deflate/Zstd/Brotli objective remains active.
