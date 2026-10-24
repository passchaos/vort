# Brotli HQ complete copy lengths and search work limits

`HqOptions.copy_lengths` selects `sampled` or `complete`; `sampled` remains
the default. The package root exports `BrotliHqCopyLengthPolicy`. Both policies
accept q10/q11, standard/Large Window and either
[`parse_mode`](brotli-whole-block-search.md). The two controls are independent:
complete lengths do not automatically select whole-block position search.

## Length coverage

For each ordinary or RAW compound-dictionary match candidate and legal distance
selector, complete mode enumerates every raw copy length from two through that
candidate's maximum, inclusive. It keeps exact command symbols, extra bits and
recent-distance cache transitions. Static dictionary tuples remain atomic:
their raw copy length and transformed output length are not interchangeable,
and a transform's output cannot be truncated into additional copy candidates.

The maximum remains limited by the match finder, source and caller settings.
Complete length enumeration does not enumerate all match distances, all beam
states or all future entropy models. Combining it with whole-block positions
therefore still does not promise globally optimal compression.

Independent small models demonstrate legal interior lengths 50 and 69 at q10
and 83 at q11 that the sampled policy omits. Their complete paths cost 18, 18
and 19 model bits; independent command replay and actual wire parsing verify
the selected commands. These are quality witnesses, not corpus compression
ratio or throughput measurements.

## Per-plan evaluation limits

`HqOptions.max_price_evaluations: ?u64` defaults to `null`. A finite value caps
the exact copy-command encoding choices admitted for pricing in each actual
parser plan. The counter spans all 4096-position horizons of a bounded plan;
it does not restart at a horizon boundary or use the caller's accumulated
profile as its starting value.

Admission happens after legal encoding metadata is found and before symbol
prices are read. Implicit and explicit forms of semantic distance zero count
separately, as does each legal recent-distance alias. An evaluated edge counts
even if beam insertion discards it. Literals, entropy construction, matching,
I/O, terminal insert-only pricing and auxiliary continuation/extension pricing
are outside this counter. It is a copy-command pricing limit, not a total CPU,
elapsed-time, matcher-work or whole-operation limit.

Zero is legal. A plan without copy choices can succeed; the first copy choice
returns `SearchLimitExceeded` before its price is computed. Workspace
allocation can happen before that choice, so zero does not promise zero
allocation. The HQ workspace and
[`max_total_working_memory`](brotli-total-encode-memory.md) limits independently
control their documented requested-heap scopes.

Each refinement, sampled safeguard, bounded safeguard and q10 comparison has
its own plan allowance. Their accumulated `price_evaluations` can exceed the
configured per-plan limit. Exhaustion must propagate as `SearchLimitExceeded`;
an already valid safeguard cannot excuse skipping a requested complete pass.

## Actual wire and transaction contracts

The native block codec preserves an independent sampled refinement trajectory
with the same parse mode and entering model/history/cache, executes complete
search, and selects the smaller serialized candidate. It keeps the whole-block
position guard separate to avoid re-entering the length guard recursively.
One-shot, chunked and reusable complete-frame APIs also retain the corresponding
sampled complete stream. q11 retains its corresponding q10 complete frame.
All candidates use the caller's allocator and the original total heap budget.

Incremental encoding uses the same block codec and its entering-checkpoint
guard. Its per-block comparisons do not establish a complete-stream size
ordering against a separately run sampled incremental stream whose earlier
choices may change later history and models.

On failure, published/emitted counters and caller-visible state follow the
existing transaction contracts; actual attempted work remains visible.
Caller-buffer output is preserved, incremental buffered input and snapshots
survive repeated search denial, and reset/retry remains deterministic.

Profile fields describe actual work:

- `sampled_length_passes` and `complete_length_passes` count nonempty plans in
  their selected policy, without incrementing the existing total passes twice.
- `max_copy_length_considered` is the largest admitted raw command copy length.
- `max_plan_price_evaluations` is the largest admitted count of any individual
  plan, including failed plans; it is neither a sum nor the configured limit.
- `price_evaluations` keeps the cumulative count across all actual plans.

The effective profile retains the requested policy even when the selected wire
comes from a sampled safeguard. Counters saturate and maxima merge by maximum.
Disabling profiles must preserve the wire and resolved settings.

## CLI and verification

The CLI accepts `--hq-copy-lengths=sampled|complete` and
`--hq-max-price-evaluations=NUM`, including separated values. They use the same
public HQ options and require a valid HQ quality. Complete mode with `--profile`
adds a separate `br_length_profile` line while preserving existing profile
records and atomic file output behavior.

```sh
zig build test-br-complete-lengths -Doptimize=Debug --summary all
zig build test-br-complete-lengths -Doptimize=ReleaseFast --summary all
zig build test-br-complete-lengths -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build test-br-complete-lengths-cli -Doptimize=Debug --summary all
zig build test-br-public-wasm -Doptimize=ReleaseFast --summary all
```

`run-br-complete-lengths-diff` accepts the four versioned standard/Large Window
reference helpers and an output directory containing the independently frozen
sampled baseline. The small campaign exercises both qualities, formats, parse
modes and public ownership models, RAW dictionaries, empty input, exact/below/
zero pricing limits and profile-independent wire. Functional evidence is
recorded in the [baseline](../performance/brotli-complete-copy-lengths-functional-baseline.md).
