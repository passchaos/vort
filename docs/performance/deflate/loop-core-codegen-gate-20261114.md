# Deflate loop core codegen gate result, 2026-11-14

Status: prototype rejected at the first codegen gate and reverted; no
production source changed on main. This records why a non-inlined wrapper
alone cannot meet the design from `noninlined-loop-core-design-20261114.md`.

## Prototype

Added a `noinline ordinaryCore` in `linear_entry.zig` wrapping the existing
`decodeDynamicBlockIntoLinearMode(false,false,false,false,false,...)` and
pointed the ordinary `aligned`/`portable` entries at it. No token logic was
changed, so the experiment isolates the effect of removing inlining across
the orchestration boundary.

## Measured codegen versus gate

| Metric | Design target | Measured |
| --- | ---: | ---: |
| Core text | < 2,048 B | 3,659 B (0xe4b) |
| Core stack frame | < 128 B | 296 B (`sub $0x128`) |
| Memory operands | reduced | 273 (unchanged) |
| Outer `aligned` entry | — | 37 B thin tail-call wrapper |

The core is byte-identical in size to the prior inlined body. Forcing the
call boundary only shrank the outer entry; the frame and instruction count
are intrinsic to the state machine itself (four-entry literal speculation,
exceptional/secondary Huffman handling, distance tiers and the copy-kernel
branches), not to inlining.

## Why the design's second-stage rewrite is now contraindicated

The design assumed a smaller physical core was reachable by moving
block/tail handling out. The gate experiment shows the ordinary steady
state already excludes those paths at runtime through branches, but the
compiler must still emit them because they share the same entry-typed
control flow. Reaching the 2 KB / 128 B targets would require actually
deleting code paths from the core — duplicating the exceptional, secondary
and tail logic into separate functions. That is precisely the code-size
multiplication the design's kill criteria forbid ("windowed/PNG paths
require duplicating the core, recreating the current code-size
multiplication"), and it matches the mechanism behind every rejected
Brotli layout screen: splitting without removing work perturbs layout but
does not reduce the hot state machine.

## Decision

The non-inlined loop core project is stopped before any A/B:

1. The cheap structural variant (noinline wrapper) fails both codegen
   gates with zero frame or text improvement.
2. The only way to hit the gates is a full state-machine rewrite with
   duplicated cold paths, which the design itself classifies as a kill
   condition and which carries high regression risk across the deflate,
   deflate64 and PNG windowed APIs.
3. No measured hotspot supports that cost: the loop is front-end saturated
   with diffuse branch misses, but a smaller core is not demonstrably
   reachable without sacrificing the specializations that already handle
   the common token shapes.

## Position of the decode performance workstream

After this result the local/structural decode optimization surface is
exhausted across all three codecs:

- Brotli: seven rejected variants; diagnostics complete.
- Zstd: retention/content caches zero-hit; copy-width trials rejected.
- Deflate: setup ~3-4%, reader 0.24%, loop front-end saturated; the only
  structural rewrite fails its own codegen gate at the first cheap check.

Further decode throughput claims would require either a from-scratch loop
architecture outside the current semantic-decoder contract (a separate,
resourced project with its own correctness case) or new profiling evidence
revealing a hotspot not visible in the current cycle/instruction/branch/PMU
data. Continuing incremental edits on the existing functions has produced
eight consecutive negative or parity screens and is not a productive use
of effort.
