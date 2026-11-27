# Original-command split planning reuse, 2026-11-27

Status: implemented in `11effbb7` after passing the predeclared functional,
primary and control gates. Independent primary/control/history/reference
replay passed. The implementation is pushed to remote main; the portable
evidence package is being sealed for a separate documentation commit.
Baseline source is `742f4663`.
This increment does not establish codec parity or leadership.

The quality encoder repeatedly plans the same original immutable commands
while comparing its initial lazy group, forced-recent parameter baseline and
parameter alternate. This slice transfers completed adaptive literal and
command/distance split results across those groups. It preserves the existing
planner options, candidate order, full-wire arbitration and strict ties.

An owner binds the input and original command slice while both remain live.
Other repacked, short-match, static-dictionary or modeled command arrays miss
this owner. Symbol keys contain every argument of the existing split chooser:
the resolved recent-distance boolean, four split flags, minimum distance
command count and full wire context. The original symbol projection's fixed
distance parameters remain unchanged. Literal planning uses the same input
and insert spans. Joint planning also requires the exact cached parent
literal plan and the existing fixed joint options.

The owner stores final plans, including successful null results, with no new
payload copy or allocation. Publication transfers ownership only on success.
Its 64 KiB admission budget includes stack metadata and all owned plan slices;
overflow, capacity or budget refusal leaves the caller's plan intact and uses
the original path without another search. The owner releases all payload
before the optimal/feedback parser stages. Metadata accounting is separate
from observed requested heap; it is not a heap or stack measurement.

The parameter pair also returns an explicit choice witness: unsearched,
searched with no alternate, or searched with alternate parameters. The later
split-aware family consumes that result rather than repeating the chooser.
Unsupported materialized fallbacks retain unsearched. The forced-recent base
candidate still runs when the pair has no alternate; its wire settings differ
from the initial group and it cannot be removed on that basis.

Public enablement follows the existing q8/generic/explicit-window16 literal
reuse gate, excludes disabled contexts, metadata, shared/HQ/Large Window
routes, and requires input 8–64 KiB with nonempty original commands. Other
qualities keep their original split planning. Joint reuse is covered through
the real lower writer; q8's default schedule does not enable joint contexts.

## Observed functional and resource evidence

- Owner: native Debug and actual WASI ReleaseSafe 10/10 each.
- Choice witness: native and actual WASI 12/12 each, including six direct
  strategy contracts; existing native parameter-pair integration 27/27.
- Joint writer: native and actual WASI 31/31 each. Mozilla, Xray and the
  established 8 KiB off-grid input consume a real nonnull joint result while
  preserving uncached/cold/warm full wire, stats and decode. NCI/XML are not
  labeled joint activation cases.
- Public native suite: 35/35, including four complete gold wires, excluded
  routes and a real 8 KiB null-plan hit (two literal-null and two empty-symbol
  hits). Exact peak, peak-minus-one quota refusal and recovery pass. Mozilla
  completes 681 backing allocation failures and 681 active retries.

These public memory comparisons disable only split reuse in the same source.
Both sides already include the choice witness; they are not a `742f4663`
source comparison. The allocator forces moving growth and includes all codec
allocations and the final owned wire, with caller release verified separately.

| Native public case | Peak disabled/enabled B | Allocations disabled/enabled | Cumulative requested B disabled/enabled |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 5,115,910 / 5,115,910 | 723 / 681 | 30,758,066 / 30,505,144 |
| Xray 64 KiB | 8,168,439 / 8,168,439 | 1,020 / 978 | 56,370,439 / 55,586,279 |

Actual WASI public suite completes 35/35, including gold/control/null, both
resource screens, quota/recovery and 688 backing OOM points with 688 active
retries. All successful wires match their original gold and every failure and
retry releases the allocator's owned bytes. The whole-source
`zig build -j2 test check check-wasm --summary all` gate completes with actual
exit0: 414/414 steps and 6,085/6,087 tests (two skipped). All seven selected
source hashes remain unchanged. The main Debug test run takes 109 minutes;
three live diagnostic samples identify the earlier allocation-failure work
and subsequent q10/q11 command-state ceiling test. They are not throughput
evidence. The original diagnostic `failed command` lines remain preserved;
the authoritative final exit and summary are successful.

| Actual WASI public case | Peak disabled/enabled B | Allocations disabled/enabled | Cumulative requested B disabled/enabled |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 4,430,770 / 4,430,770 | 730 / 688 | 26,286,222 / 26,033,300 |
| Xray 64 KiB | 7,398,019 / 7,398,019 | 1,035 / 993 | 48,887,754 / 48,103,594 |

## Performance acceptance

The fixed two-pair pilot completes 24 pairs / 48 processes: speedup GM
1.036184997491676x, every row point at least 0.98 and initial wire identity
pass. CI remains null and the pilot cannot authorize adoption by itself.

The independently released full90 campaign completes 90 pairs / 180 processes.
Its original producer reports equal-row GM across all samples
1.0312916722332623x, 95% round-block CI
[1.0297344815763332x, 1.0327249356711294x], and every row point at least 0.98.
The protocol declared the all-sample estimator before sampling. Its separate
six-primary-round estimate is 1.0292433572443302x, below 1.03. This difference
and every outlier are preserved.
Independent primary reduction reproduces the complete point values and all
20,000 round-block resamples. The narrow matrix interval reflects observed
shared-round covariance, not omitted samples. The six-round primary value
remains below 1.03 and is preserved as the protocol's predeclared secondary
estimate.

The separate control campaign completes 90 pairs / 180 processes and 15,624
timed encodes. q4, q11 with explicit 8 KiB command-state cap, ratio and all
twelve 4 KiB inputs pass their individual 0.98 point floor. Their complete
initial wires remain equal. The weakest point is small XML 0.9951913216x;
its 95% interval is [0.9831635968x, 1.0057178935x]. Independent control replay
reproduces all rows and every actual timed sample.

Two further independent 90-pair epochs measure the frozen candidate directly:

| Comparison | Candidate elapsed / other elapsed | Paired 95% interval | Candidate / other wire size |
| --- | ---: | ---: | ---: |
| Exact historical `0a673757` | 3.0917714011x | [3.0748826832x, 3.1106789832x] | 0.9565808634x |
| Pinned libbrotli 1.2.0 | 59.7101037639x | [59.3762297490x, 60.0314513566x] | 0.9438865172x |

All twelve rows remain slower than both comparators. These results use q8,
generic, explicit window16 and matched owning warmup/encode/mix/free scopes.
Nominal quality is not a matched speed/size frontier. The reference's actual
version, three library hashes and mapped dependency paths are verified for
each process. Historical regression and reference leadership remain unresolved;
the recent-source increment cannot be multiplied into either direct result.

Matched whole-probe ELF text is 1,817,513 B baseline and 1,830,185 B candidate
(+0.697216%). This is not isolated codec text, requested heap or measured
stack. These samples were collected on the development host after team heavy
work ended; they do not prove continuously zero interference or an industry
ranking.

Independent replay of controls/history/reference verifies 270 pairs / 540
processes and 15,984 timed calls, including every 100-call arithmetic process
mean, row/matrix resampling, source/ELF/probe/input/wire/argv/exit and complete
chronology. No producer import, codec execution, sample filtering or timing
retry occurs during this verification.

The declared public allocating q8 matrix retains all twelve 64 KiB
Silesia prefixes, symmetric warmup and encode/mix/free lifecycle. The fixed
1.03 geometric mean target, paired interval excluding parity and every
applicable row/control at least 0.98 pass. Current source, historical `0a673757`
and pinned libbrotli 1.2.0 comparisons have distinct exact identities and
sampling epochs; do not multiply their ratios or equate equal quality numbers
with a matched speed/size frontier. Existing historical q8 regression remains
unrepaired until a new direct source comparison proves recovery.

Initial source and validation roots are `/tmp/vort-br-split-plan-reuse-gate.93efvyav`,
`/tmp/vort-parameter-choice-validation.jy3hhavn`,
`/tmp/vort-br-split-plan-public-gate-ydifd4lx`, and
`/tmp/vort-br-split-integration-3c_ti_ax`. The new benchmark epoch is
`/tmp/vort-br-original-command-split-reuse-ab.egqd38jr`. These are live working
evidence roots; a completed portable archive is required for final handoff.

After pulling remote main with rebase, focused choice/owner contracts pass
22/22 each and the real joint writer oracle passes31/31; all seven selected
source hashes still equal the successful whole-library gate. These are
post-rebase checks, not a repeated full Debug run or a new benchmark epoch.
