# Brotli HQ command parsing

The implementation and its functional/reference evidence are recorded in the
[HQ baseline](../performance/brotli-hq-functional-baseline.md).

The optional `hq` controls on `br.PlannedEncodeOptions` and
`br.PlannedStreamChunksOptions` select the standard-window HQ command parser
for quality 10 or 11. `BrotliHqOptions` and `BrotliHqProfile` are also exported
from the package root. A null `hq` preserves the established quality policy
and wire. These are native Vort controls; matching a reference quality number
does not establish equal output, compression ratio, throughput or memory use.

## Controls

| Field | Default | Accepted values |
| --- | --- | --- |
| `search_depth` | 64 | 1...65536 |
| `nice_len` | 128 | 2...16777216 |
| `beam_width` | 0, automatic | 0 or 1...32; automatic is 8 for q10, 16 for q11 |
| `iterations` | 0, automatic | 0 or 1...8; automatic is one for q10, two for q11 |
| `block_len` | 262144 | 1...16777216 |
| `max_working_memory` | `maxInt(usize)` | Caller-selected allocation budget |
| `distance_parameters` | Mode-selected | `npostfix` 0...3, `ndirect_high` 0...15 |
| `profile` | null | Borrowed caller-owned profile |

`nice_len` is a search convergence threshold, not a maximum copy length.
The container's existing `window_bits` remains authoritative, with standard
windows 10...24 and a normal-history bound of `2^window_bits - 16`. This opt-in
does not change the container's default window. Callers comparing public APIs
or reference presets should specify the same window explicitly.

Generic and text modes default to distance shape `(0, 0)`. Font mode defaults
to `(1, 6)`, which means twelve direct distances, because the wire's four-bit
`ndirect_high` field is shifted by `npostfix`. The standard alphabet has at most
520 symbols; prices are indexed by symbols and do not allocate one entry for
every possible history distance. The subsequent
[Large Window extension](brotli-large-window-hq.md) selects a separate explicit
format, with a 62-bit wire alphabet and a safe active capacity through 544.

## Exact command and distance choices

Each HQ command preserves its selected symbol from the complete 704-command
alphabet, its semantic distance code, its encoded distance symbol and extra
bits, and the fixed distance parameters. The writer validates this combination
and emits it without choosing another equivalent representation. Null exact
encoding fields preserve the legacy writer's choice.

The 128 implicit-last-distance commands require insert code below eight and
copy code below sixteen. Other length pairs may still explicitly emit semantic
distance code zero. Every code-zero reference leaves the four-entry distance
cache unchanged. Static dictionary commands never push that cache; compound
dictionary commands may push it. Equal physical distances from different
short selectors remain distinct choices because their prices and resulting
cache can differ.

Static dictionary commands encode the original word length but advance by the
transformed output length. At absolute output position `p`, with compound
dictionary size `c` and normal-history maximum `h = min(p, window - 16)`, their
physical distance is `h + c + address + 1`. Compound distance is
`h + c - address`. Their logical addresses are retained separately from normal
history distances. Candidate enumeration retains different addresses and raw
copy lengths even when their transformed bytes are equal.

## Streaming and publication

HQ `block_len` is the default meta-block input target. A nonzero outer
`PlannedStreamChunksOptions.block_len` overrides that target, through the same
16 MiB limit. The incremental encoder's outer `Options.block_len` takes
precedence over both. The effective target is passed to HQ parsing and its
profile. The existing adaptive 64 KiB block policy is disabled for HQ;
explicit `adaptive_blocks = true` is rejected. Null HQ keeps the old block
limits and adaptive policy.

The generic incremental encoder gathers one bounded meta-block across caller
input fragments before HQ parsing. Internal parser search windows do not
commit the stream: pending literals and command state continue until the real
meta-block boundary. History, recent distances and the previous two context
bytes belong to the stream and continue across committed meta-blocks. A stored
fallback preserves the entering distance cache while making its plaintext
available as later history.

Output publication reserves storage before changing a shared partial byte.
Allocation failure leaves pending plaintext, mutable output and codec state
available for retry. A complete final block and final marker form one
transaction, including cases where caller output has already drained part of
the earlier stream.

On 32-bit targets, current-stream and cumulative byte counters and
`max_input_len` use `u64`, so address-space width does not impose a 4 GiB stream
limit. Individual call progress and buffer sizes remain `usize`. Input and
output counters are checked before copying or accepting bytes; overflow keeps
the completed progress visible without publishing another byte.

One-shot q11 retains the complete corresponding q10 wire as a candidate.
Incremental q11 compares q10 candidates from the same entering meta-block
state. That local comparison does not claim a whole-stream size ordering for
independent streams with different block boundaries or earlier selected states.
Reference-style automatic merging and global segmentation across multiple
input blocks remain separate work.

The 4096-position search horizon and finite beam also do not guarantee a
globally minimum model cost. An independent 4098-byte regression model has a
32792-bit legal parse, while the current horizon choice costs 32793 bits; both
beat its 32797-bit literal-only path. The extension decision correctly rejects
the more expensive long copy and preserves complete command, selector and
terminal costs. The one-bit gap is a retained quality limitation, not an
encoded-byte or throughput measurement.

## Profiles and evidence

Work counters describe actual attempted tree, dictionary, transition, price and
parse work, including rejected candidates. Published-output counters describe
only the winning wire and roll back with failed publication. Peak working
memory merges by maximum; work counters use saturating addition. A q11 run may
perform more than two parses when its complete q10 safeguard also does work.
Enabling the profile must preserve the output bytes.

Requested working allocation, caller-owned buffers, fixed state, serialization
scratch and process RSS are different measurements. Reproducible competitor
claims require the actual codec revision, CPU, build mode, corpus and command,
and must report compression ratio, encode/decode throughput and memory
separately. Functional gates and their durations do not establish performance
leadership.

`max_working_memory` and `peak_working_memory` cover the HQ-managed requested
heap: the stable budget handle, dictionary indices, models, matchers and live
forks, parser workspaces, plans, candidate artifacts, and explicitly charged
alias snapshots. Generic incremental plaintext/pending buffers, retained
plaintext history, complete-frame output and a retained complete q10 comparison
wire use the supplied backing allocator outside this cap. Streaming I/O storage
is bounded by the configured block and window sizes; allocating convenience
APIs also retain their complete result. The independent
[`max_total_working_memory` option](brotli-total-encode-memory.md) covers those
outer allocations together with HQ workspaces. Lower-memory whole-frame
comparison remains separate work. The HQ workspace profile must not be
reported as total encoder allocation or process RSS.
