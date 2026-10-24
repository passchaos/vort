# Zstd HQ position, length and price controls

`ZstdHqOptions` adds three independent search controls:

| Field | Default | Requested behavior |
| --- | --- | --- |
| `parse_mode` | `.bounded` | `.whole_block` keeps one DP table across every position and endpoint in the current format block. |
| `match_lengths` | `.sampled` | `.complete` prices every legal length of each admitted match and exact offset choice. |
| `max_price_evaluations` | `null` | A `u64` admission limit for sequence-edge prices in each actual DP plan. |

The optimal HQ strategies `btopt`, `btultra` and `btultra2` accept these controls.
`lazy2` and `btlazy2` continue to accept their ordinary HQ settings; expanded
search or an explicit price limit is rejected for them because those engines do
not perform the corresponding DP search. Unsupported requests fail explicitly.

## Positions and complete lengths

A format block is bounded by the configured block size and window, with a
maximum of 128 KiB. Whole-block search uses a traceback coordinate wide enough
for the final position at 131072. The bounded default retains its 4096-position
tables and existing layout.

The matcher admits a finite frontier of distances under the caller's depth and
nice-length settings. Complete length search enumerates each admitted distance,
its legal repeat selectors and direct offset, and every legal match prefix.
It does not enumerate every historical distance or every repeat-cache state.
The beam remains finite, so neither mode promises a globally optimal parse.

Bounded complete search also prices endpoints past the current 4096-position
table. It keeps a finite continuation candidate, evaluated with the remaining
literal cost, and resumes matching after the selected copy. Whole-block search
places all legal endpoints in the single DP table and does not take that
cross-window shortcut. Enumeration and retention are separate capabilities.

## Price admission and actual profiles

The price budget is local to one actual DP plan and spans all of its windows.
It admits an evaluation before reading the sequence price or recording that
transition. It includes candidate-edge and continuation/extension search
prices. Literal costs, match finding, final plan validation and refinement
remeasurement are outside this budget. It is therefore not a CPU-time limit.

A zero limit can succeed when no sequence edge needs evaluation, including
empty, raw/RLE and literal-only work. The first required edge beyond the limit
returns `SearchLimitExceeded`. Requested work is not silently skipped or
replaced with a stored fallback. Cold `btultra2` passes and safeguards each
perform real plans under the same independent limit; their cumulative work can
exceed one plan's limit.

The optional encoder-control profile separates policy, work and publication:

- Effective fields report the requested parse mode, length policy and limit.
- Pass counters distinguish bounded/whole and sampled/complete searches.
- `max_parse_positions` records positions actually processed in a plan, not
  allocated capacity. A failed early request cannot report the whole block as
  searched merely because a large table was planned.
- `max_match_length_considered` records lengths actually admitted for pricing.
- `max_plan_price_evaluations` records the largest single-plan count;
  `price_evaluations` accumulates across calls, refinements and safeguards.
- `price_limit_refusals` and search work survive failed attempts. Published
  block/frame selection counters roll back when output is not committed.

Profile presence does not determine admission, search coverage or output bytes.
The plan enforces its limit even when the caller does not request a profile.

## Wire safeguards and ownership

Expanded search can discard a path in a finite beam, so more enumeration alone
does not guarantee better output. Successful expanded requests compare against
the corresponding bounded/sampled settings, keeping the same depth, nice
length, minimum match, memory limits, dictionary and price allowance. The
requested search runs first; an admission or allocation failure is returned
before a baseline can replace it. Ties preserve the baseline.

For complete one-shot, reusable and independently framed seekable encoding,
the safeguard compares two actual complete frames from independent fresh
states. Incremental encoding compares the current complete block from the same
incoming coding state. Different selected repeats or entropy tables can affect
later blocks, so an incremental block safeguard does not establish that the
entire frame is smaller than an independently encoded baseline frame.

Both alternatives use the same format writer and decoder authority. Only the
chosen output commits its coding state and emitted counters. Scratch, candidate
frames, simultaneous output storage and alias snapshots remain subject to the
existing requested-heap policy. A caller-buffer or seekable publication failure
must preserve previously visible output and caller-owned state.

Default bounded/sampled settings and a price-limit-only request use the
existing single search path, with no extra baseline allocation. Seekable
requests with a price limit still stage publication and entry metadata so that
a later-frame failure cannot expose partial caller output. Default wire bytes
are checked against a separately archived pre-change implementation.

## Verification and remaining limits

Independent small cost recurrences test position/length traps and exact repeat
selectors. Public API gates separately test actual emitted frames, dictionary
and streaming transitions, safeguards, budget boundaries, allocation failure
and reference-library interoperability. Custom test-model plan costs do not
imply the same improvement under an ordinary public encoder's entropy model.

Functional work counters and durations do not establish competitor throughput
or compression-ratio leadership. Broader entropy planning, finite-beam losses,
dictionary-training cost and current cross-library/platform benchmarks remain
part of the incomplete industry-best objective.
