# Current wire-format decode baseline vs installed system libraries, 2026-11-16

## Purpose

The industry-gap audit's first open item is a current, provenance-tagged
measurement of Vort's one-shot decoders against installed reference
libraries. This package captures that snapshot for the three target wire
formats (raw Deflate, zstd, Brotli) on three representative Silesia files
(`xml` source, `nci` and `mozilla`, the two historically weak rows).

Reproduce (per codec/file):

```sh
zig build run-deflate-reference-bench -- --input <file> --name <n> --iterations 30 --rounds 1 --csv <out>
zig build run-zstd-reference-bench    -- --input <file> --name <n> --iterations 30 --csv <out>
zig build run-br-reference-bench      -- --input <file> --name <n> --iterations 30 --csv <out>
```

`summary.csv` normalizes the per-run CSVs (the raw benches use opposite ratio
column conventions) into one direction: `vort_over_reference_throughput =
vort_mib_s / reference_mib_s`, so `>1.0` means Vort is faster.

## Provenance (from each CSV row)

- Host: Intel Core i7-10700K (Skylake), x86_64-linux-gnu, affinity 0-15,
  single-thread decode (`codec_thread_policy=single`).
- Build: Zig 0.16.0, ReleaseFast; each row carries the executable SHA-256 and
  input SHA-256.
- 30 iterations, one round, no CPU pinning; wall-clock medians as emitted by
  the bench. This is a diagnostic snapshot, **not** a paired-A/B adoption gate.
- Reference libraries as installed on this host:
  - Deflate: **libdeflate 1.10** (2022, relatively current);
  - zstd: **libzstd 1.4.8** (2020, old);
  - Brotli: **libbrotli 1.0.9** (2016, old).

## Results (Vort throughput / reference throughput, >1 = Vort faster)

| codec | ref version | xml | nci | mozilla |
| --- | --- | ---: | ---: | ---: |
| Deflate | libdeflate 1.10 | 1.017 | **1.150** | 0.936 |
| zstd    | libzstd 1.4.8  | 0.783 | 0.840 | 0.821 |
| Brotli  | libbrotli 1.0.9 | 0.926 | 0.930 | 0.927 |

Compressed size as a percentage of raw input is in `summary.csv`
(`encoded_pct`); it is each codec's own wire size and is not directly
cross-comparable across formats.

## Interpretation

- **zstd is the clearest gap: 16-22% slower, consistent across all three
  files** (0.78-0.84x). This matches the earlier serial-entropy analysis: the
  ~46% sequence-executor hotspot is a single-cursor FSE recurrence that cannot
  be parallelized within the wire format. It is also the documented weak row on
  nci/mozilla.
- **Brotli is a steady ~7% behind** (~0.93x) with little file-to-file spread,
  consistent with the dispersed, instruction-bound one-shot payload path.
- **Deflate is near parity and file-dependent**: slightly ahead on `xml`
  (1.02x) and clearly ahead on `nci` (1.15x), behind on `mozilla` (0.94x).
  No single direction dominates.

## Critical scope limits — do not over-claim

- **The zstd and Brotli references are old.** Against current libzstd and
  libbrotli the Vort gap is plausibly *larger*, not smaller, than the numbers
  here. These are lower bounds on the competitive distance, not evidence of
  parity. A real "industry best" claim needs measurements against current
  upstream releases on pinned hosts with paired interleaving.
- Single host, one round, no CPU pinning or paired interleave: suitable for
  ranking and identifying weak rows, not for the 3%/95%-CI/0.98x-control
  adoption gate in `docs/formats/native-entropy-design.md` section 8.
- Decode one-shot only: no encode throughput, RSS/peak-memory, streaming, or
  cold/warm split.
- No production code changed; this is measurement only.

## What this directs

The data re-confirms zstd sequence decode as the highest-value decode target,
and that its ceiling is the FSE serial wall already documented in
`docs/performance/zstd-serial-entropy-wall-20261116.md`. Within the wire format
no local micro-lever was found in the prior exhaustive pass, so closing it is a
structural (representation/executor) effort rather than another local tweak.
