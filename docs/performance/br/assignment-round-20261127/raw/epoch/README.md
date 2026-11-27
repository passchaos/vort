# Round4ctx/u32safe: preparation only

Baseline is Git46d340ac03ab211aa3f745b650e76f0bf530744d. All2,222 tracked
src blobs match the old actual371b18cb frozen build snapshot. The baseline
ELF remains963d97be... with its old build receipt; no new HEAD build is
claimed. Baseline br.zig Git SHA256 is8a06c147... . See
assets/baseline-source-proof.json and assets/actual-old-build.json.

The original main probe is byte-identical to the old sealed build binding.
The small generic public-options probe preserves exactly the original
owning allocating encode/mix/free timer and warm1. q10-default and
q11-default set quality only, preserving the public default command-state
budget. q11-cap8 is a separate explicit-cap caller. Ratio retains null
quality and the public ratio level. Both baseline and candidate will need
this new control wrapper after Root BUILD_SOURCE_READY; baseline may reuse
the old record object and frozen source. The original baseline main ELF
requires no rebuild.

| Phase | Rows | Pairs | Processes | Timed calls |
| --- | ---: | ---: | ---: | ---: |
| Main pilot | 12 | 24 | 48 | 48 |
| Main formal | 12 | 90 | 180 | 180 |
| Public controls | 18 | 108 | 216 | 7,344 |
| Small controls | 12 | 72 | 144 | 14,400 |

Public controls are mozilla/nci/x-ray actual64KiB ×q4/q6/q10-default/
q11-default/q11-cap8/ratio,6 pairs per row. q4/q6 use100 calls per process;
the others use1. Small controls are all12 first4KiB fixtures, q8,
6 pairs and100 calls per process. All30 control point estimates must be≥.98.
All initial primary/control wires require baseline/candidate full memcmp
and pinned library decode, with zero wire-size/ratio regression budget.
That initial matrix is84 warm-only processes if Root releases preflight.

New-epoch formal primary uses only rounds0..5 on all12 rows:72 pairs,
equal row GM≥1.03,20000 shared AB/BA common-round bootstrap CI lower>1,
and each common-six row point≥.98. The three weak rows have six extra
pairs each for separate all12/extra6 row CIs. They never enter primary GM,
primary CI or primary row floor. All-sample secondary is retained and
disclosed. The old epoch's all-sample estimator remains its legitimate
predeclared, independently verified statistic; this new epoch declares
the common-six primary prospectively. No old result/protocol was changed.

Minimal probe CLI, conditional on Root BUILD_SOURCE_READY and future builds:

```sh
taskset -c 2 "$EPOCH/bin/candidate" --input "$INPUT64K" --output "$OUT" --source-revision "$FROZEN_REV" --iterations 1 --window 16
taskset -c 2 "$EPOCH/bin/candidate-controls" --input "$INPUT64K" --output "$OUT" --source-revision "$FROZEN_REV" --iterations 1 --window 16 --control q10-default
taskset -c 2 "$EPOCH/bin/candidate-controls" --input "$INPUT64K" --output "$OUT" --source-revision "$FROZEN_REV" --iterations 1 --window 16 --control q11-default
taskset -c 2 "$EPOCH/bin/candidate-controls" --input "$INPUT64K" --output "$OUT" --source-revision "$FROZEN_REV" --iterations 1 --window 16 --control q11-cap8
taskset -c 2 "$EPOCH/bin/candidate-controls" --input "$INPUT4K" --output "$OUT" --source-revision "$FROZEN_REV" --iterations 100 --window 16 --control q8
```

EPOCH is this directory. q4/q6 use --iterations100; ratio uses1. Untimed
preflight uses --iterations0 and --wire-output, with the same options and
one warmup. Baseline main uses the preserved old bin/candidate ELF;
baseline controls use the new generic wrapper linked to the frozen old
source/object. Each output must be fresh. Root controls all future build,
preflight and separate pilot/formal/control/direct releases; every example
release is false. No sampler auto-starts and no retry-until-pass is allowed.

The current recent46d, historical0a and reference1.2.0 ELF anchors were
hash-checked against their actual old receipts. New candidate direct
comparisons must use fresh pairs and own records, the same original
target/argv/owning lifecycle, and independent initial-wire decode. Reference
wire ratio remains separate; no nominal quality-frontier equivalence or
cross-epoch ratio multiplication is permitted. Old timed records were not
copied or used.

Only this tmp directory was written. Prototype alpha source remains owned
by Root/workers and pending BUILD_SOURCE_READY. No build, library load,
codec, timing or bootstrap was executed during this preparation.
