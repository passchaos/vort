# Brotli counts adaptive-distance context losers before emission

Quality-eight standard-window encoding now avoids materializing every rejected
literal-context wire after an adaptive distance split has been selected. The
first context remains a complete physical wire. Alternate contexts and the
plain-literal alternative run the same frequency, tree, header and payload
planning through the exact counting writer. Strict byte-length arbitration is
unchanged; only a strictly smaller counted candidate replaces the incumbent,
and a counted winner is then emitted once.

The retained path is intentionally narrow:

- standard window and recent-distance commands;
- one adaptive-distance plan with two through eight types;
- complete final stream, no metadata;
- no literal, command, legacy-distance or combined adaptive split;
- no HQ exact commands, model capture, final-state capture or Large Window.

Every other valid configuration retains the previous complete writer. The
counter serializes the real window/meta-block/header, literal context map,
adaptive block-type and block-length trees, initial block length, identity
distance context map, and all literal/command/distance trees. Payload accounting
includes command Huffman bits, insert/copy extras, per-type distance Huffman
bits, distance extras and every adaptive switch. Padding is rounded only at the
same final byte boundary used by the physical writer.

The first prototype exposed why the extra fields matter: adaptive candidates
do not use the unsplit command/distance cache, so command and distance extras
must be collected independently in count mode. The production oracle now
constructs a context-shaped 64 KiB stream, compares every candidate's counted
size with its complete physical wire, forces a counted alternate to win, and
requires old materialized versus new selected wires and complete stats to
match. Its profile contains exactly one evaluate-to-wire link for that winner.
The same fixture injects the first, last and every intermediate allocation
failure through the complete path and checks caller stats rollback and leak
freedom.

## Current-parent profile evidence

The baseline was compiled from a clean archive of `ef409b59`; the candidate
contains only this adaptive-distance change. On Mozilla, Dickens and MR 64 KiB,
the old profile physically emitted six adaptive-distance/context candidates
per call. The candidate emits the two incumbent adaptive-distance wires and
records the other four as exact evaluations. All eighteen candidate lengths
match their old physical-wire lengths in order:

| Input | Candidate lengths in bytes |
| --- | --- |
| Mozilla | 14327, 14358, 14358, 16269, 16406, 16405 |
| Dickens | 25720, 25863, 25863, 24726, 25045, 24731 |
| MR | 16050, 16405, 16137, 15482, 15882, 15667 |

The ordinary and profiled returned wires retain their complete SHA-256
identities. The profile gate passes with complete timing/event coverage.

An executed wasm32-wasi public q8 consumer adds a deterministic 64 KiB fixture
with 11,032 planned commands. The candidate observes three adaptive-distance
evaluations and two physical wires; ordinary/profile output agrees and Node's
native Brotli decoder reconstructs the exact input. The pre-existing frozen
public fixture also stays byte-identical to its old Wasm baseline.

## Ordinary A/B results

Both separately compiled ReleaseFast executables were pinned to logical CPU 2
on an Intel Core i7-10700K. Each process runs five alternating Vort/libbrotli
rounds with three timed encodes per round. Three process sweeps alternate
baseline/candidate order. The final corpus contains twelve Silesia files at
4, 16 and 64 KiB, or 36 cases and fifteen raw Vort samples per version/case.

| Scope | Candidate/baseline geometric time ratio |
| --- | ---: |
| All 36 cases | 0.986445 |
| 4 KiB, path disabled | 1.003436 |
| 16 KiB, path disabled | 1.000351 |
| 64 KiB | 0.956262 |

The three case-paired sweep ratios are `0.986671`, `0.985082` and `0.987474`.
All input hashes, resolved settings, Vort sizes and complete Vort wire hashes
match the current-parent baseline. The benchmark independently decodes Vort
output with Brotli 1.2.0 and reference output with Vort. Against that reference,
the final 36-case geometric size ratio is `0.995561` while the encoding-time
ratio remains `36.16`; this increment materially improves q8 speed but does not
establish industry-best throughput.

The first 36-case discovery run used a stale pre-DEFLATE-cost baseline and is
explicitly excluded: NCI/XML wire changes came from the intervening shared LZ77
cost fix. Later process-wide runs are also excluded because object identity,
compiler/test overlap, a withdrawn module-layout experiment, or powersave
frequency transitions biased whole version batches. The final epoch warms the
CPU first and alternates baseline/candidate per case, so frequency drift is
locally paired. All excluded raw data remains archived.

Complete raw rounds, profiles, inputs, executable/reference identities and a
machine-checkable audit are retained in
[`data/brotli-adaptive-distance-counted-20261029/`](data/brotli-adaptive-distance-counted-20261029/).

The next structural step is to retain command/distance/split preparation once
per candidate group. This implementation already removes loser byte buffers and
payload emission, but each counted candidate still rebuilds adaptive distance
histograms, trees and split-code state; sharing those allocator-owned objects
requires an explicit move/deinit ownership contract.
