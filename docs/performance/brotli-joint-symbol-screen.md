# Brotli joint literal and symbol split combination screen

Reference-algorithm study identified that the default single-block quality
pipeline did not combine its joint literal plan with command/distance splits,
although chunked encoding already did. A staged q10/q11 candidate reused the
best already-encoded symbol split and tried one additional full joint wire per
command group, only at most64KiB with a joint plan and a symbol candidate
strictly smaller than the preferred baseline. No production change was adopted.

The ordinary public API remained
`encodePlannedStreamWithOptionsAlloc(.quality=q,.mode=.generic)`, with no
explicit HQ selection. Its source routing is distinct from the optional
command-state HQ engine; findings for that engine do not explain this matrix.

Zig0.16.0 ReleaseFast on i7-10700K/CPU2 measured three alternating AB/BA process
sweeps over24 real q10/q11 cases (six Silesia32/64KiB prefixes) and nine controls.
There were198 serial processes. Encode-only timings exclude startup
encode/decode, input setup, hashing and output release. Every process checks
determinism. All real/control complete wires remain unchanged; the real-file
time geomean is1.010878 and control time1.007497 versus baseline. There is no
real-file ratio benefit to compensate for the extra cost.

Independent Brotli1.2.0 decoder/common loading and guarded exact output checks
pass72 encodes across36 real/control/tiny cases. A separate caller-owned
instrumented copy then proves branch coverage on36 encodes: tries/completed
events identify the new writer, and group-local wins are distinguished from
the final public winner. It never supplies the performance runner.

Twelve generated64KiB fixtures vary record columns, byte populations,
short-copy/literal balance and near/far offsets. Forty-eight additional
uninstrumented baseline/candidate encodes pass the independent decoder and
retain the instrumented candidate's exact wire. Six public outcomes, all in
the mixed-short family at q10/q11, shrink:

| Seed | Baseline bytes | Candidate bytes |
| --- | ---: | ---: |
| 1 | `31745` | `31552` |
| 19 | `31758` | `31565` |
| 97 | `31759` | `31681` |

Those synthetic gains are about0.61%/0.61%/0.25%. Several real command groups
also improve locally but lose later full-pipeline arbitration, explaining why
the ordinary real output remains unchanged. No default adoption, requested-heap
improvement or reference ranking follows from these fixtures.

The next useful architecture step is a shared prepared entropy plan that
serves actual command/context costs, bit estimates and final encoding, instead
of serializing more isolated alternatives. The broader Brotli ratio/time gap
remains open. Source variants, real timings, guarded decoder results, generated
inputs and actual trigger events are frozen under
[`data/brotli-joint-symbol-screen-20261031/`](data/brotli-joint-symbol-screen-20261031/).
