# Historical parity and observed regressions, 2026-11-26

Some encoding changes have made Vort slower. Historical decode parity on a
limited workload does not establish three-codec encode/decode parity. Keep
source regressions, competitor rankings and candidate gains distinct.

Latest source status, November 27: the shared literal-model implementation
`907b0557` and its sealed evidence in `92204434` have been pushed to main.
Its separate complete public q8 campaign improves throughput 1.03200695x
against its frozen recent baseline, with paired 95% CI
[1.02860148x, 1.03542371x]. It preserves that baseline's wires and full current
candidate policy. There is no direct `92204434 / 0a673757` timing epoch, and
the historical 3.20317086x regression below remains unrepaired. Do not combine
these separate-epoch ratios to report an estimated current result.

Future performance reports must identify the historical source anchor, the
recent source baseline and the competitor comparison separately. A gain over
the recent source is only an increment; recovering earlier public latency and
approaching the competitor's speed/size frontier require their own matched
whole-operation evidence. Keep all current candidates, search budgets and
quality policies when removing repeated work.

## A demonstrated encoding regression

The [q8 source A/B](br/q8-source-regression-20261125/README.md) compares
`0a673757` with `c2c8f250` through the same allocating public probe at
q8/generic/explicit window16. All twelve 64 KiB Silesia rows slow down:
geometric mean encoding time is **3.8338x**, while complete wire size is
**4.34% smaller**. This is direct source A/B evidence of an expensive product
tradeoff. Default entropy feedback adds work, but its individual contribution
has not been isolated.

The original collector was active on another CPU during this source A/B. Its
3.8338x magnitude is a descriptive development-host observation; the new
historical/current-main comparison must run after heavy work stops.

The [V7 histogram proposal screen](br/histogram-proposals-20261126/README.md)
improves throughput **17.93%** against `c2c8f250` with identical initial wires.
That gain does not establish recovery against `0a673757`. Directly pair the
older source with current committed main; do not multiply results from
separate sampling epochs into a current ranking.

The new [historical/current-main direct comparison](br/q8-main-history-20261126/README.md)
now pairs `0a673757` with `8ccd54a5` after heavy workers stop. Its complete
90 pairs / 180 measured calls independently verify **3.20317086x elapsed**,
95% round-block CI **[3.18422544x, 3.22222901x]**, and wire ratio
**0.95658086x**. All twelve primary rows and all ninety individual pairs are
slower on current main. This is a direct observed regression under the
declared q8/window16 allocating policy; it does not attribute the cost to one
intervening commit or establish a competitor ranking.

The Root release and 34.96-second run window are retained separately from
the original reducer's inherited nonquiet template text. Host snapshots and
stopped-worker receipts do not prove continuously zero interference. The
latest tool-only commit `bd934972` changes the Python profile gate and tests;
the sampled codec source remains exactly `8ccd54a5`.

## What the historical near-parity result covered

The [November 16 Brotli result](data/wire-brotli-1.2.0-current-20261116/README.md)
reports a **1.017x median** across twelve full Silesia files against a tuned
libbrotli 1.2.0 build. It covers decode, not encode. Its CSV does not separately
retain producer quality or wire SHA. The saved command and historical tool
source recover requested libbrotli **q0/generic/lgwin22** defaults; actual wire
window was not independently retained. The historical tool alternates batches
but chooses the shortest batch independently for each participant, rather than
using every paired sample. The report's "without paired interleaving" wording
therefore does not fully describe its historical implementation.

The modern matrix uses q6/q11, all twelve corpora at 64 KiB/1 MiB/full size,
all six paired samples, CPU affinity and explicit API lifecycle definitions.
Those 72-row geometric means cannot be compared directly with the historical
q0 full-file median. The earlier three-file Deflate comparison also uses
libdeflate **1.10** and retained reference state, while the modern cold matrix
uses **1.26** and includes reference state creation/destruction. Its changing
competitor ratio is not a measurement of Vort's source regression.

## Comparable modern decode observations

The [November 12](modern-decode-refresh-20261112.md) and
[November 25](modern-decode-refresh-20261125/README.md) archives share frozen
plaintext/wire bytes, producer settings, public APIs and reference builds.
Each cold aggregate includes all 72 fixed rows.

| Codec and reference | November 12 Vort/reference | November 25 Vort/reference |
| --- | ---: | ---: |
| Deflate / libdeflate 1.26 | 68.87% | 68.75% |
| Zstd / libzstd 1.6.0 | 76.58% | 79.02% |
| Brotli / libbrotli 1.2.0 | 81.93% | 83.15% |

These cross-date observations do not show an aggregate widening across all
three decoders, and do not attribute small shifts to code. Competitor speed
also changes between epochs. The latest complete decoder matrix binds
`06d8086d`, not current `8ccd54a5` main. A direct source A/B is still needed
to quantify current main against older revisions. No industry leadership is
claimed.

The [216-condition encoding observation](modern-encode-refresh-20261125/README.md)
binds `4a9796b0`, allocating preset calls and concurrent host activity. It is
neither a replay of the historical decoder workload nor a matched-quality
frontier. Full Brotli q11 reaches 91.87% of reference throughput while its
wire is geometrically 10.77% larger; this does not establish equal-quality
parity.

## Rejected prepared fixed DEFLATE candidates

The [V1 package](deflate/prepared-fixed-20261126/README.md) retains its original
rejected result. V2 and V3 use separate source/ELF/raw epochs and the same
45-row, six-pair public append policy. None has been adopted into main.

| Candidate | 24 prepared target throughput GM | Failed rows below 0.98x |
| --- | ---: | --- |
| V1, ordinary writer bridge | 1.08337749x | 2 small + 12 ordinary controls |
| V2, reserved emitter | 1.18100779x | 3 small + 2 ordinary controls |
| V3, direct byte bit emission | 1.25664605x | 3 ordinary controls |

V3 completes all 540 records, with target paired 95% CI
[1.25392764x, 1.25970659x]. All nine small controls pass; ordinary Mozilla,
mr and reymont 64 KiB remain at 0.97768345x, 0.96563897x and 0.97062014x.
The row floor rejects it despite its target gain. Native/WASI30, 66 newly
generated byte-identical wires and all four decoder oracles pass. Independent
data-only statistics and all source2216/ELF/probe/input/chronology checks pass.
The first launch's permission refusal occurred before any codec ran and
produced zero timing samples; its original logs remain separate. A reporting
group-name error and its original verifier are also retained. Neither issue
changed or replaced successful timing samples.

The [V2/V3 package](deflate/prepared-fixed-variants-20261126/README.md) now
preserves their complete source/raw/validation evidence and independently
replays both rejections from an arbitrary copied location.
The V1 working implementation is saved in local Git stash
`c04cbff2ecefbb5e33fb3ea5ca1eea8bcc0b2134`; production source is restored to
committed main. Before adoption, any new source must repair ordinary controls
and pass fresh complete-source gates.
The direct historical/current-main q8 comparison is complete. Prioritize
removing repeated match/entropy planning and losing candidate output. Local
target gains must retain small/cold latency, ordinary API, wire and resource
controls.

## Two rejected Brotli emission pilots

The [local counted-distance pilot](br/counted-distance-local-20261126/README.md)
and [global final-entropy-bound pilot](br/final-entropy-bound-20261126/README.md)
each compare a separately frozen prototype with clean `cf442dee` through the
same public q8/generic/explicit-window16 allocating call. Each retains all
24 AB/BA pairs / 48 calls and byte-identical initial wires. Independent
data-only verification reproduces throughput GMs **1.01382176x** and
**1.01564227x**, respectively. Both pass every pilot row's 0.98 floor but
miss the predeclared 1.03 target. Neither has a formal CI or an approved/run
full campaign; neither is adopted.

The global prototype passes its recorded native/WASI functionality and resource
prerequisites, but those do not override the failed performance screen. It is
saved in local Git stash `5e431ffff10d57fc576c97f49d1fbb5ea330cf58`, with the
ignored source bytecode preserved separately in the frozen evidence. Production
source is restored to committed main. These gains cannot be multiplied with
historical or local pilot ratios to claim recovery.

The current-source stage diagnostic attributes 30.23% of total measured stage
time to context proposals and 22.85% to optimal parsing. Mozilla's context
proposal share is 49.82%; NCI's optimal parser share is 73.74%. It observes
1,029 physical outputs, of which 993 lose, across 36 trace calls. These are
diagnostic routing facts, not a prediction of recoverable throughput or a
single-commit attribution. A previous
[nonrecent prepared-context prototype](data/brotli-nonrecent-context-full-20261123/README.md)
already failed its whole-operation target and row floors. The next source epoch
must address a larger measured planning boundary rather than repeat that
extension or the two sub-threshold emission pilots.

The [source-history follow-up](br/q8-structural-followup-20261126.md) identifies
default entropy feedback, the inclusive 64 KiB extra-feedback gate and complete
distance-parameter split candidate groups as concrete expansions of q8 work.
It records the next literal-model reuse boundary and preserves the distinction
between this source audit and measured per-commit regression attribution.
