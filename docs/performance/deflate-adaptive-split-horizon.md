# DEFLATE adaptive split compares complete horizons

The adaptive raw/zlib/gzip encoders now compare every prospective boundary over
the same plaintext horizon. Previously the search compared the encoded size of
`input[0..candidate]` for different candidate lengths. A short prefix is almost
always fewer bytes, so the search systematically selected its minimum block
length even when the resulting sequence of blocks lost to the one-shot stream.

For a fixed `horizon = min(input.len, max_block_len)`, the production score is
now:

```text
score(input[0..candidate])
+ score(input[candidate..horizon])
+ one conservative boundary byte
```

The unsplit candidate scores the horizon once. Checked addition rejects
unrepresentable pair costs. Exact ties select the longer block, with the whole
horizon initialized as incumbent, so fragmentation must provide an actual
modeled improvement. At most 64 grid candidates plus one off-grid entropy
heuristic are evaluated, bounding adversarial `search_step=0/1` options. The
incremental block chooser calls the same local search instead of maintaining a
second two-half policy.

The final adaptive encoder still compares the complete emitted stream with its
one-shot baseline, so the optimization cannot regress encoded size. Search
tests independently enumerate the candidate grid, demonstrate that the old
prefix-only objective selects the shortest boundary, check longer-on-tie and
overflow behavior, keep uniform input whole, round-trip every wrapper, and
inject every allocation failure.

Incremental scoring remains a local, history-free and byte-aligned proxy while
the actual incremental matcher retains prior-block history and a live bit
offset. It is therefore not a general proof of incremental wire-size
non-regression. A dedicated fragmented raw/zlib/gzip fixture copies a random
32 KiB block across the boundary, exercises retained history, round-trips every
wrapper, and requires adaptive raw output not to exceed the fixed 32 KiB
boundary policy. A future exact incremental scorer should accept the retained
history and current writer state explicitly.

## Ordinary A/B evidence

The baseline is clean `f560b156`; the candidate contains only the horizon-score
change. Separate ReleaseFast executables run on logical CPU 2 of an Intel
Core i7-10700K under the same powersave governor. Each process performs the
benchmark's ordinary untimed warmup followed by one timed adaptive-default
zlib encode. Five sweeps alternate baseline/candidate order per case over all
twelve Silesia 192 KiB prefixes.

| Quantity | Result |
| --- | ---: |
| Candidate / baseline time geometric ratio | `0.287951` |
| Sweep ratios | `0.289468 / 0.288575 / 0.288678 / 0.285886 / 0.288286` |
| Baseline total bytes | `915,572` |
| Candidate total bytes | `910,041` |
| Cases with a size regression | `0 / 12` |

Every timing row improves. Dickens, Mozilla, and X-ray move from
`360.8 / 3567.5 / 194.3 ms` to `95.4 / 1216.0 / 51.5 ms`. Mozilla saves 24
bytes. Samba exposes the ratio consequence of the old target most clearly:
`110,207 -> 104,700` bytes while time falls from `192.8 -> 55.0 ms`.

A separate three-sweep 512 KiB screen for Dickens, Mozilla, and Samba records a
time ratio of `0.273373`; all sweeps are between `0.271712` and `0.276622`.
Mozilla saves 1,786 bytes and Samba saves 11,789 bytes, with no regression.

The candidate probe emits raw, zlib, and gzip streams for all twelve 192 KiB
inputs. Python's system zlib independently decodes all 36 wires to their exact
input SHA-256. On the same inputs, zlib 1.2.11 produces 912,169 bytes at level 6
and 905,780 at level 9, versus the candidate's 910,041 adaptive-default bytes.
This establishes a large adaptive-search correction and a small aggregate size
lead over zlib level 6, not broad DEFLATE leadership: Vort remains 4,261 bytes
behind zlib level 9, while ordinary parser throughput, cross-block history and
dynamic-Huffman-aware optimal refinement remain separate targets.

Raw rounds, exact inputs, wrapper hashes, executable identities, commands, and
a machine-checkable audit are retained in
[`data/deflate-adaptive-split-horizon-20261029/`](data/deflate-adaptive-split-horizon-20261029/).
