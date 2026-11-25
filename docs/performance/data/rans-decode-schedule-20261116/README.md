# rANS decode-schedule ILP diagnostic, 2026-11-16

## Question

Interleaved rANS creates N independent state/renorm chains so a *vectorized*
decoder could advance them together. Zig 0.16 has no portable dynamic-index
gather (see `docs/formats/native-entropy-design.md` section 5), so a real SIMD
rANS decoder is not expressible yet. This probe asks the narrower question that
IS answerable with scalar code: does simply visiting the lanes in lockstep
rounds (adjacent independent chains) let a superscalar core overlap them and
beat draining one lane fully before the next?

## What is compared

`tools/rans/decode_schedule_probe.zig` (`run-rans-decode-schedule-probe`), on
one deterministic ~1,048,576-symbol block (24-symbol skewed alphabet, L=4096):

- **nested** — fully drain lane 0, then lane 1, ... (one dependent chain kept
  hot at a time);
- **lockstep** — each round advances every active lane by one scalar step.

Both call the identical scalar `Decoder.next` the same number of times into
identically-addressed per-lane contiguous scratch; only lane-visit order
differs. Outputs are cross-checked for equality and against the canonical
symbols before timing. Timing alternates which schedule runs first, uses two
warm-up plus nine timed iterations, and reports the median.

## Result (single host, ReleaseFast)

| lanes | nested ns/symbol (milli) | lockstep ns/symbol (milli) | lockstep / nested (milli-x) |
| ---: | ---: | ---: | ---: |
| 1 | 4.799 | 6.052 | 0.792 |
| 2 | 4.679 | 4.873 | 0.960 |
| 4 | 4.544 | 5.279 | 0.860 |
| 8 | 4.637 | 5.699 | 0.813 |

Lockstep is consistently **slower** (about 4-21%) than nested, and nested
throughput is essentially flat as N grows (4.5-4.8 ns/symbol).

## Interpretation

- Scalar lockstep scheduling does **not** extract measurable ILP on this host.
  The round loop's per-round branching and the wider live register set cost
  more than any superscalar overlap returns. The N=1 case, where the two
  schedules are logically identical, still shows the lockstep outer-loop
  scaffolding alone (~21%), which is a structural confound that also weighs on
  the N>1 numbers.
- More lanes do not by themselves speed up a scalar decoder; the dependency
  chains were already being overlapped out of order inside each drained lane.
- The parallelism value of interleaving is therefore **future-latent**, not
  presently realized: it pays off only when a true vectorized path exists
  (toolchain gather support or an explicit dispatch-gated native backend), and
  even then must clear the section-8 paired A/B.

## Scope and limits (this is not an adoption gate)

- Single host, single binary, no CPU pinning and no paired interleave protocol;
  wall-clock numbers are a representative snapshot, not reproducible CI
  evidence, and are not deterministic run to run.
- The loop-structure difference is intrinsic to the two schedules, so the
  comparison isolates lane-visit order but not with zero overhead.
- No gather is available, so this cannot measure SIMD potential directly; it
  only shows the scalar schedule alone is insufficient.
- Do not cite these numbers as a throughput claim or industry comparison. The
  durable conclusion is negative and architectural: do not assume interleaving
  gives free scalar speed, and do not prioritize lockstep on the scalar path.

Reproduce:

```sh
zig build -Doptimize=ReleaseFast run-rans-decode-schedule-probe
```
