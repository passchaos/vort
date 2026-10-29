# Brotli shares adaptive-distance preparation across literal candidates

Quality-eight standard-window encoding now prepares the command and adaptive
distance side of one candidate group exactly once. Every literal-context
candidate reuses the same command symbols, explicit distance encodings,
command tree, per-distance-type trees, block-switch code, identity context map,
and shared payload bit cost. All candidates, including the primary, are counted
exactly; the strict byte winner is then emitted once.

The retained path remains deliberately narrow:

- standard windows with the narrow 79-symbol distance writer;
- recent-distance commands without HQ exact encodings;
- one adaptive-distance plan with two through eight types;
- at most 64 Ki commands and 32 Ki explicit distance symbols;
- complete final streams without metadata or any other split family.

Unsupported shapes keep the established physical-writer path. The prepared
state is allocator-owned and single-owner. Its key covers command and split
identity plus every option that changes command or distance encoding. Literal
context, history, and tree policy remain in the separate per-candidate literal
key. This separation keeps actual-type storage bounded and avoids the 256-type
fixed stack objects that previously caused Wasm pressure.

The shared count remains exact at the final byte boundary. It includes command
Huffman and length-extra bits, every per-type distance symbol and extra field,
all adaptive block switches, and the complete prepared header. Tests compare
every new shared count with both the legacy physical wire and the previous
monolithic counter. They also force primary and alternate winners, verify exact
trace topology and stats, prove one common scan/tree build per group, exhaust
all allocation failures, and reject key or writer-capacity mismatches.

## Profile evidence

ReleaseFast profiles on Mozilla, Dickens, and MR 64 KiB retain the exact input
and returned-wire hashes. The current-parent baseline records four counted
literal alternatives and two physical adaptive-distance wires. The candidate
records six exact evaluations, one for every primary/alternate candidate, and
still emits only two physical adaptive-distance wires across the surrounding
outer alternatives. Both emitted winners link back to their evaluation.

| Input | Baseline evaluate / wire ns | Candidate evaluate / wire ns |
| --- | ---: | ---: |
| Mozilla | 2,623,321 / 9,267,051 | 1,574,583 / 7,645,472 |
| Dickens | 3,538,515 / 15,195,143 | 1,534,485 / 13,005,165 |
| MR | 2,466,366 / 12,129,617 | 1,053,146 / 10,832,216 |

Shared preparation occurs above the individual evaluation scopes, so these
stage values are mechanism evidence rather than ordinary throughput results.
The profile gate passes for both executables. An executed wasm32-wasi public
consumer also retains its exact ordinary/profile wire, observes five adaptive
evaluations and two physical wires, and passes Node's native Brotli decoder.

## Ordinary A/B results

The baseline is a clean archive of `47ff561d`; the candidate is the final
shared-preparation source. Separately compiled ReleaseFast executables share
the same record-optimal object. Measurements are pinned to logical CPU 2 on an
Intel Core i7-10700K. Each case has five alternating Vort/libbrotli rounds with
three timed encodes per round, and three case-paired process sweeps alternate
baseline/candidate order. The corpus is twelve Silesia files at 4, 16, and
64 KiB, producing 36 cases and fifteen raw samples per version/case.

| Scope | Candidate / baseline geometric time ratio |
| --- | ---: |
| All 36 cases | 0.983721 |
| 4 KiB, path disabled | 0.999527 |
| 16 KiB, path disabled | 1.000146 |
| 64 KiB | 0.952264 |

The three sweep ratios are `0.981921`, `0.983279`, and `0.983530`. All input
hashes, resolved settings, output sizes, and complete Vort wire hashes match.
Against Brotli 1.2.0, Vort's geometric size ratio is `0.995561`, while its
encoding-time ratio remains `35.69`; this is a material q8 improvement, not an
industry-wide throughput lead.

Raw rounds, profiles, exact inputs, executable/reference identities, commands,
and a machine-checkable audit are retained in
[`data/brotli-adaptive-distance-shared-20261029/`](data/brotli-adaptive-distance-shared-20261029/).

The next structural opportunity is to reduce repeated literal work across the
remaining context candidates, then address the much larger command planning and
context-clustering gap to libbrotli.
