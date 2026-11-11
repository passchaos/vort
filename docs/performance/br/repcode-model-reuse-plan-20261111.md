# Bounded repcode-model reuse plan, 2026-11-11

Status: planned; no production change or benchmark result.

The functionality-first Deflate raw-output alias correction takes priority.
This Brotli slice remains parked until that defect and its required gates are
complete. The audit inspected revision
`6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1`; implementation and measurements
must bind a fresh source revision.

## Duplicate preparation and exact trigger

The public native quality route is
`encodePlannedStreamWithOptionsAlloc` →
`encodePlannedStreamQualityWithOptionsAllocRecorded` →
`encodeQualityOptimalCandidateAllocRecorded` →
`selectQualityCommandStateCandidate` → `selectWideCommandStateCandidate`.

The optimal-feedback function builds
`entropy_feedback.buildWithRepcodeBonus(allocator, input,
modeled_commands.commands, search_window)` for the bonus modeled DP candidate
at `src/br.zig:5980`. After that scope closes, the wide command-state path
allocates a heap `Model` and invokes the same builder with identical arguments
at `src/br.zig:6032`.

Both constructions execute together only when the native optimal route is
admitted, entropy feedback is enabled, seed/modeled parses contain matches,
and the resolved command-state ceiling admits an **exact 64 KiB input**.
The first bonus block requires at least 64 KiB; the later command-state
ceiling permits at most 64 KiB. Default q10/q11 ceilings extend to 64 KiB for
eligible text/binary inputs above 8 KiB; explicit 64 KiB admits this size,
while explicit 0/8/32 KiB does not.

q11 obtains the complete q10 winner first and skips its own deeper optimal
parse at inputs up to 64 KiB (`src/br.zig:5687`). Reuse saves one preparation
through the inherited q10 operation, not two per q11 call. q8 has feedback
but no command-state parser and is a negative control. Dedicated HQ and
attached shared-dictionary routes are separate.

## Immutable model and bounded ownership

Reuse the complete `entropy_feedback.Model`. `modeled_commands` is const and
remains alive until function exit; later `commands2`/`bonus_commands2` never
replace it. Candidate arbitration changes only the retained wire. Input,
source commands and search window are identical at both build sites.

The model owns one distance allocation; other cost arrays are inline. Both
consumers borrow immutable tables (`[]const u16` or `*const Model`). The normal
search window is capped by `lz77.default_window_len` at 32 KiB, so its distance
array contains 32,769 u16 entries, **65,538 requested bytes**. The builder
also scans commands/literals, builds histograms and a temporary repcode hash
map, and fills all distance prices. Reuse removes its second execution and
the later heap Model descriptor allocation.

Use an optional automatic owner in the enclosing feedback scope. Construct
at the existing first-build point, publish ownership only on success, borrow
its const view for bonus DP and the later wide parser, then deinitialize once.
Preserve every current model2/DP/command cleanup scope. Keep the existing
build-once route at 32 KiB through 64 KiB minus one. Do not allocate a heap
owner before bonus DP: that adds descriptor bytes to its live working set.
No public option, global/content cache, escaping owner or model substitution
is needed.

## Wire, resource and failure contracts

- Preserve all parser options, cost tables, candidate order, compact/full-wire
  gates and strict-smaller tie rules. Keep bonus DP and all arbitration.
- Use the same default starting-distance ring. Do not substitute the plain
  seed model or rebuild from commands2/bonus_commands2. Independently compare
  every semantic Model field and distance entry; ignore padding/addresses.
- Extended distance lifetime has no intervening allocating operation before
  the old replacement build. Prove requested peak does not increase using a
  forced-moving allocator with unchanged DP cleanup scopes; fewer requests
  alone are insufficient. Check compiled stack separately, including WASI.
- Genuine remaining allocation failure stays `OutOfMemory`; quota refusal
  stays `WorkingMemoryLimitExceeded`. Never catch either and change policy.
  Failed initialization publishes no owner; cleanup must avoid dangling
  borrows/double-free and leave zero encoder-owned live bytes.
- Removed requests cease to be fault sites. Recompute fault-injection indices
  from the new successful run; old indices may now succeed. Measure new peak
  D, require D to succeed and D−1 to refuse with cleanup. Do not promise an
  old refusal threshold after reducing peak.
- The current quality recorder has no feedback-model build-count stage.
  Existing command-model counters belong to entropy writers; preserve them.
  Focused builder/reuse counters may establish execution, never throughput.

## Required validation and whole-operation gate

Compare complete baseline/candidate wires at q10/q11 on exact 64 KiB text,
structured and binary inputs, including Dickens/XML/NCI/x-ray. Cover default
and explicit 64 KiB ceilings, explicit 0/8/32 KiB controls, 65,535/65,537-byte
boundaries, q8 at 64 KiB, q10/q11 at 16/32 KiB and selected actual 1 MiB
inputs. Include empty/tiny/random/no-match/repetitive cases and counters
showing actual build/reuse. Preserve q11's complete-q10 size contract.

Validate forced-moving allocation, null/profile/exact-cap/D−1 paths, every
remaining reached OOM site, retries and zero live-byte cleanup. Run relevant
Debug/ReleaseSafe, actual x86/WASI contracts, focused Brotli families and
required library checks. Cover admitted mode/window/metadata settings.

The primary performance target is all twelve Silesia exact-64-KiB prefixes
at q10/q11. Measure interleaved baseline/candidate **public complete encode
operations**, matched options, one codec thread, fixed affinity, warmup and
retained raw process samples. Record latency, wire bytes and requested peak.
Keep q8, smaller/adjacent sizes, disabled ceilings and selected 1 MiB controls
visible separately. Require at least 3% target geometric-mean throughput
improvement with a confidence interval excluding parity, no control below
0.98x and exact wire identity. Preparation may be small relative to HQ DP;
no gain magnitude is predicted.

Refresh the matched reference matrix with exact Vort/competitor revisions,
loaded binary hashes, compiler flags, target/features, CPU/affinity, corpus
hashes, quality/mode/window, API lifecycle, thread policy, raw samples, wire
bytes and memory scope. Historical q8 ratios, isolated model timing and
removed-request counts do not establish a current-source encoding win or
industry leadership. If the operation gate fails, preserve the negative or
mixed evidence and keep production unchanged.
