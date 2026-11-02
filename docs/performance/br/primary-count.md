# Count the primary context candidate, 2026-11-03

Preferred q8 context groups now prepare the primary candidate with an exact
count when the current search produces a different context proposal. All
candidates retain their original byte-length comparison and strict tie rules;
the selected preparation emits once. Groups with no distinct proposal retain
the original physical-primary controller and reuse the already calculated
proposals. The explicit plain baseline remains materialized, and equality
still selects it.

The controller and the cold command/distance publication use a cohesive
module/code section. The materialized-primary controller remains the
independent policy reference. Primary and alternative literal states are
separate; only a strictly better alternative replaces the selected state.
No preparation heap allocation is added. Unsupported windows, metadata,
splits and live HQ output states retain the existing routes.

The final q8 stage recorder preserves every candidate configuration and exact
byte length over three rounds each of MR/Mozilla/Dickens 64 KiB. Physical wire
attempts fall from 14 to 12 for MR and 12 to 10 for Mozilla/Dickens; evaluations
rise from 10 to 12. Returned wires and native round trips remain identical.
These counts identify the avoided output work; stage clocks are diagnostic.

## Cold preparation and the literal gate

The counting path accepts an initialized matching command/distance key before
its `ready` flag is published. It validates insert bounds and stream geometry,
collects frequencies, builds canonical command/distance encoders, then
publishes the complete common data. The literal state becomes ready only
after the actual header serializer and weighted payload/extras produce a
complete checked byte count. Reached errors propagate; invalid canonical
preparation publishes no partial common state. Common data remains valid if
a later literal preparation fails, because it is independent of that literal
candidate.

For fewer than 128 inserted literals, the existing context policy cannot
produce a proposal. Analysis now checks this minimum before allocating and
clearing approximately 256 KiB of mode histograms. A bounded prefix scan stops
at the threshold, so accepted searches avoid a second complete command scan
and the eligibility calculation cannot overflow. Threshold, candidate order
and output remain unchanged.

## Ordinary q8 comparison

Baseline source is `0a85bcad`. Independent binaries call the public quality
API through `tools/br/planned_encode_bench.zig`: q8/generic/actual window16,
matching the reference quality, mode and window. Twelve Silesia sources at
4/16/64 KiB plus random 16/64 KiB and repetitive 64 KiB controls give 39 rows.
Three alternating outer sweeps verify 234 processes and retain all five
timing rounds at three encodes per round. Ratios use per-row median paired
times; every complete input, Vort wire and reference wire identity agrees.

Host: Intel Core i7-10700K, logical CPU2, one codec thread. Vort uses Zig
0.16.0 ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0 is
clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`, using the pinned loader closure in
[interval-cost evidence](interval-cost.md).

| Real-input scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 1.00174 | 4/12 |
| 16 KiB | 0.99241 | 8/12 |
| 64 KiB | 0.96948 | 12/12 |
| All 36 real inputs | 0.98778 | 24/36 |

Real-input geometric latency improves about 1.22%, with about 3.05% at 64 KiB.
Small-input rows remain near neutral as a group, including individual
regressions. [All row results](primary-count-20261103.csv) retain independent
medians and paired ratios, which need not equal their quotient.

Eleven longer alternating pairs at seven encodes per round give:

| Input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 0.97634 | 0.97885 | 10/11 |
| MR 64 KiB | 0.97528 | 0.97192 | 11/11 |
| Dickens 64 KiB | 0.95876 | 0.96466 | 10/11 |
| Reymont 4 KiB | 0.99678 | 0.99272 | 8/11 |
| Random 64 KiB | 0.99907 | 0.99894 | 8/11 |
| Repetitive 64 KiB | 1.01784 | 1.01866 | 0/11 |

The three targets improve 2.4–4.1% in this longer median comparison. The
repetitive control retains a 1.8% latency regression, although its profile
does not enter the prepared context group. The implementation does not claim
a speed win on every input; the control remains a limit of the current
ordinary comparison. An isolated x86 parser-entry alignment experiment did
not remove it and is not adopted.

The reference epoch remains 31.02 times native Brotli encoding latency
geometrically at compressed size 0.99556 times reference. Earlier increment
gains are not multiplied into that ratio.

## Independent validation

The original and prepared-primary controllers agree on 52 successful and
16 fault configurations, or 136 paired paths. The tests compare complete
active result fields, output bytes, stats, alternates and the proposal-zero
cutoff. They check primary-only groups, distinct proposals that do not win,
strict ties, plain equality, deduplication, state copies, the 80% guard,
zero-allocation preparation and exact physical-allocation ownership. Native
Debug/ReleaseSafe/ReleaseFast runs pass.

Real cold tests compare 18 fixtures and eight warm literal variants with an
independent full writer. They cover simple/complex alphabets, tiny streams,
more than 128 commands, exact commands, poisoned inactive frequencies, keys,
insert bounds, arithmetic and invalid canonical data. Twelve public q8 cases
retain all earlier negative fixtures; the 16/32 KiB guard cases each execute
two successful cold counts with equal complete wires, summaries and decoded
content. The counting route has zero actual allocation sites; output emission
failure sweeps reach three OOM cases and preserve cleanup/prior readiness.
The production `context primary` filter passes all 30 tests including imports.

The short-analysis oracle checks lengths 0…129 with contiguous and fragmented
spans, untouched inputs, exact 127/128/129 allocation behavior and invalid
large spans. Debug/ReleaseSafe/ReleaseFast runs pass. Final ReleaseSafe Brotli
tests pass 1,513 cases with one skip, and the public prepared-command Wasm gate
preserves frozen full output and passes Zig/Node decoding. The default
`check check-wasm` command completes 212/212 steps with exit zero.

## Reproduction and bindings

`zig-out/br-primary-count-20261103` retains every source variant, raw timing
round, `matrix-final.py`, `long-final.py`, discarded experiments, canonical
controller proofs, real preparation tests and final verification logs. All
eleven executable sections in the production benchmark match the measured
contained candidate. Runtime/code-layout experiments are separate from their
successful correctness checks and do not become performance evidence for a
different variant.

```sh
python3 zig-out/br-primary-count-20261103/matrix-final.py
python3 zig-out/br-primary-count-20261103/long-final.py
zig build -j2 test-br -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
```

| Binding | SHA-256 |
| --- | --- |
| Baseline benchmark | `bb3bdaa0ee0f0390e5349d089c0cdd53477d2de7bd93e3192637b06a01292c6a` |
| Final benchmark | `5f078f9022e9706225e246e6f207f4e9644c54ffa8703a07a23dcc6a4a586a6f` |
| Final matrix | `91ee64f226ed28e270136fa90bbf4d2860805f81baa02a4f9fa98295e2580b47` |

Adaptive literal split candidates still serialize their complete streams;
exact preparation/counting for that family is the next larger output target.
Context tree scoring and high-quality parser/model work also remain. The
Deflate/Zstd/Brotli industry-best goal stays active.
