# Run-to-run stability of the decode throughput ratios, 2026-11-16

## Why this exists

The companion single-run baseline
([README.md](README.md), `summary.csv`) gives one Vort/reference throughput
ratio per codec/file. A single snapshot cannot show whether the directional
conclusions sit inside measurement noise. This package repeats the benches as
independent processes and quantifies the variance, using the fast Silesia
`xml` file so five rounds stay quick.

## Method

For each codec the existing reference bench was invoked five separate times at
a fixed 30 iterations (`run-deflate/zstd/br-reference-bench --input .../xml
--iterations 30`). Each invocation already pairs Vort and the reference back to
back in one process, so the within-process environment is matched; separate
processes add independent scheduling/cache variation. No CPU pinning. The
ratio is `vort_mib_s / reference_mib_s` (>1 = Vort faster).

`stability-runs.csv` holds the five ratios per codec; `stability-summary.csv`
aggregates them.

## Results

| codec | min | median | max | span | CV | all rounds |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Deflate (libdeflate 1.10) | 1.0104 | 1.0151 | 1.0173 | 0.0069 | 0.29% | all > 1.0 |
| zstd (libzstd 1.4.8) | 0.7790 | 0.7837 | 0.7927 | 0.0137 | 0.70% | all < 1.0 |
| Brotli (libbrotli 1.0.9) | 0.9242 | 0.9272 | 0.9336 | 0.0094 | 0.40% | all < 1.0 |

## Interpretation

- Coefficient of variation is under 0.7% for every codec, an order of
  magnitude smaller than the measured gaps. The directional conclusions are
  robust to run-to-run noise, not artifacts of one timed batch.
- **zstd:** every round lands in 0.779-0.793, i.e. Vort is reliably 21-22%
  behind on `xml`; no round approaches parity.
- **Brotli:** every round is 0.924-0.934, a reliable ~7% deficit.
- **Deflate:** every round is just above 1.0 (1.010-1.017), a small but
  consistent Vort edge on this file (recall the single-run baseline showed the
  Deflate result flips sign on other files, so this is `xml`-specific).

## Scope limits (unchanged)

- `xml` only; five rounds; no CPU pinning or paired-interleave protocol. This
  characterizes noise, it is still not the section-8 adoption gate.
- The old-library caveat applies in full: against current upstream
  libzstd/libbrotli the gaps may be larger. Low variance here means the
  measurement is repeatable, not that the reference is competitive.
- Measurement only; no production code changed.
