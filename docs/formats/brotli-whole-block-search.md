# Brotli complete-block HQ search

The implementation and its quality, memory and compatibility evidence are
recorded in the [functional baseline](../performance/brotli-whole-block-functional-baseline.md).

`HqOptions.parse_mode` selects `bounded` or `whole_block`. Bounded is the default
and preserves the established command search and complete wire. The package
root exports `BrotliHqParseMode`. Both standard and Large Window formats, quality
10 and 11, and all existing public HQ encoding surfaces accept the setting.

## Search scope

Bounded parsing searches up to 4096 positions, carries pending literals and the
recent-distance cache forward, and evaluates cross-horizon copies against a
literal continuation. Whole-block parsing keeps a DP row for every position in
the current meta-block and chooses its terminal state only at the real block
end. It preserves atomic dictionary transforms and exact command/distance
choices. Its predecessor indices cover the complete accepted 16 MiB block.

The search still uses the configured finite beam and match finder. Copy lengths
default to the existing sampled alternatives and code boundaries; the separate
[`copy_lengths = .complete`](brotli-complete-copy-lengths.md) control enumerates
every ordinary/compound candidate prefix. Whole-block scope does not promise an
exhaustive search of every cache state or future entropy model. It removes the
artificial 4096-position decision boundary without claiming globally optimal
compression.

An independent 4098-byte cost model has a 32792-bit legal parse that begins its
final two-byte copy at position 4096. The default bounded search costs 32793 bits
on that witness; whole-block search selects the 32792-bit parse and retains its
exact selector through serialization. These are estimated model costs, not
compressed-byte or throughput measurements.

## Actual wire selection

The encoder serializes bounded and whole candidates from the same source,
model, context bytes, distance cache and matcher checkpoint. It trains later
iterations from actually emitted Huffman tables and selected statistics. A
complete independent bounded refinement sequence remains a wire candidate;
pairwise comparison alone could change the next iteration's model.

One-shot and reusable whole-stream entrypoints also retain the complete
corresponding bounded stream, because earlier block choices can change later
history and models. q11 continues to retain its complete q10 counterpart. The
smallest complete wire wins. Publishing a bounded candidate is valid, but the
requested whole search must actually finish first; budget denial or OOM cannot
silently skip it and return the already completed baseline.

## Memory and work profiles

Dense position-state storage uses checked calculations based on
`(block_len + 1) * beam_width * sizeof(Node)`. The existing HQ workspace and
[total-heap](brotli-total-encode-memory.md) limits cover their respective live
allocations. Larger search scopes may require substantially more memory and
work. A limit that only accommodates the default search can reject whole-block
mode before allocating its dense workspace.

Command storage grows with the selected traceback rather than allocating one
record for every possible input position. It begins with a small capacity and
returns an exact owned sequence. Capacity growth and final copies remain
charged to the same budget, including old and new allocations that coexist.
The workspace query is a fixed lower bound; actual peak memory must be measured.

`bounded_passes` and `whole_block_passes` count actual nonempty parser runs.
`max_parse_positions` records the maximum workspace search span, rather than
summing spans or reporting a configured size that was never allocated. The
existing `passes`, transitions, prices and peak counters retain their meaning.
Bounded safeguards and whole candidates both contribute work; published-output
counters describe only the selected wire. The effective profile reports the
caller's requested mode even when the selected representation came from a
bounded safeguard.

The CLI accepts `--hq-parse-mode=bounded|whole_block`. With whole mode and
`--profile`, its separate `br_parse_profile` line reports the mode counts and
span. New controls use the public library and existing atomic output workflow.
Functional validation includes independent full-cost replay, actual wire
nonregression, predecessor boundaries, dictionary transforms, exact/below
limits, OOM recovery and old default bytes. Performance claims require separate
current-source corpus and competitor measurements.
