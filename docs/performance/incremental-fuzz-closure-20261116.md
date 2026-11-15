# Incremental fuzz closure and Brotli performance entry point, 2026-11-16

Status: functional fuzz work is complete and merged on the
`test/zstd-trailing-data` branch; this note records the evidence-based handoff
into the performance phase. No production decoder source is changed here.

## Functional closure now in place

All three primary codecs (Zstd, Brotli, Deflate) share the same bounded
incremental fuzz shape, each behind a deterministic `drive(allocator, seed)`:

- wire + caller-schedule mutation across valid/truncate/flip/suffix regimes,
  both input policies where applicable, exact/short pledges, finite resource
  caps, and independent input/output slice schedules;
- per-step progress accounting against the snapshot, output canary
  preservation, sticky documented errors that clear on `reset`, schedule
  independence on frame-bounded regimes, and one-shot differential agreement;
- a 48-seed fixed matrix plus a 256-seed broad deterministic sweep per codec;
- valid multi-member concatenation round-trips and preset-dictionary
  round-trips;
- a shared coverage-guided entry
  (`run-incremental-libfuzzer-smoke`) routing arbitrary bytes through all
  three drivers.

The broad sweeps hardened three real driver-assumption gaps (suffix
concatenation depth in Zstd, meta-block termination in Brotli, and damaged
stream output expansion in Deflate) without touching production decoders.

## Performance entry point: Brotli payload stage

The functional-to-performance pivot targets Brotli first because it carries
the largest measured gap. Current ledger figures (libbrotli 1.0.9,
reference/Vort):

- overall 48-row geometric mean `0.7843` (Vort about 1.28x slower);
- 64 KiB q6 `0.7206`, 1 MiB q6 `0.8331`, 64 KiB q11 `0.7509`,
  1 MiB q11 `0.8392`; a few 1 MiB rows already beat libbrotli.

A fresh `run-br-decode-stage-profile --iterations 200` run on a 1 MiB q8
clustered frame attributes decode time as:

| stage | share |
| --- | ---: |
| payload | 0.8104 |
| header | 0.1434 |
| lookup setup | 0.0458 |
| unattributed | 0.0004 |

This confirms the ledger's standing structural option: Brotli payload
state-machine fusion (goto-style removal of the per-command phase/branch
dispatch). The payload function is flat at roughly 1-5% per instruction, so
micro-tweaks cannot move it; only a restructure can.

## Required discipline for the next step

Any Brotli payload change must follow the established adoption bar rather
than land on intuition:

1. build a paired baseline/candidate probe and pin it to a dedicated CPU;
2. run alternating multi-sweep A/B over the 48-row corpus and report the
   geometric mean with a 95% confidence interval;
3. adopt only if the geomean improves by at least 3%, no control row
   regresses beyond the 0.98x floor, and every Brotli gate plus the
   differential wire validation still passes;
4. archive the raw timings, validation JSON, and the probe under a new
   dated `docs/performance/data/` package and append a ledger entry.

Rejected prior experiments (for example the ungated distance-tree cache and
the branch-scoped literal locals) show that plausible restructures regress
specific rows, so gating and per-row controls are mandatory.
