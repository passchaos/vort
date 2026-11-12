# Reference Deflate family implementation study, 2026-11-12

This is a source study, not a performance comparison. Neither reference was
built, tested or benchmarked during this audit. These revisions are not claimed
to be the fastest current implementations. The measured three-codec ranking
remains the [committed-source refresh](modern-decode-refresh-20261112.md).

| Reference | Verified revision | Version and worktree |
| --- | --- | --- |
| zlib-ng | `6d9f3dc072369dc719a5fbe71d4e086a96a680bd` | Exact tag `2.3.2`; clean |
| zlib-rs | `2e487e34e1d2a79c24545b4f843437611d77be2c` | Exact tag `v0.6.1`; clean |

No checkout was initially present under `~/Work`. Sources were fetched to
`/tmp/vort-reference-zlib-ng-study-20261112` and
`/tmp/vort-reference-zlib-rs-study-20261112`. Git status, unstaged diff and
staged diff were clean. Source links below bind findings to those commits.

## Direct final tables

zlib-ng's [table builder](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inftrees.c#L98)
counts lengths, validates codespace, sorts active symbols into temporary work
storage and emits final entries containing operation, remaining code bits and
literal/base/subtable offset. It does not retain a general canonical decoder
and then translate each entry into a semantic table. zlib-rs's
[safe builder](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/inftrees.rs#L42)
follows the same architecture, combining nonzero histogram/minimum/maximum
width in its first pass and emitting final entries into caller-owned slices.

Both production callers request literal/distance roots of 10/9 and use returned
actual widths. zlib-ng's [capacities](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inftrees.h#L41)
apply to those roots, not Vort's 11/8. Reference secondary entries store
remaining code bits; Vort currently stores full width and packs literal pairs.
Changing the representation requires preparation, fast execution and exact
tails to agree. The useful next Vort mechanism is a checked lengths-to-final
semantic plan, eliminating intermediate general-table materialization and
translation rather than merely another histogram/active-list scan.

## Incomplete trees and validation order

The [ng codespace checks](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inftrees.c#L104)
and [rs checks](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/inftrees.rs#L61)
turn empty alphabets into invalid decode entries. Nonempty incomplete
literal/distance sets are accepted only with maximum width one; incomplete
precodes are rejected. This makes remaining invalid-slot handling simpler.

Vort accepts additional incomplete distance alphabets and singleton widths.
Every allocated missing suffix slot must be defined; canonical-zero,
empty-distance, error/progress and checked-tail contracts remain authoritative.
Reference rejection predicates and their single remaining-slot fill cannot
replace those contracts. Both reference callers check missing EOB and build
literal tables before distance tables. Vort must preserve its own validation
and fallback order: an unsupported semantic shape is not an invalid header.

## Actual fast-loop bounds

zlib-ng's [actual declarations](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inflate_p.h#L137)
are 15 input bytes and 260 output bytes; some `inffast_tpl.h` comments still
discuss 8/258. zlib-rs [declares 15/260 too](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate.rs#L554).
Neither constant is a proved bound for Vort's packed-literal iteration.

zlib-ng separates the fast-loop boundary from the true output end. Its
[copy selection](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inffast_tpl.h#L244)
permits capacity-bounded overcopy and computes `extra_safe` when output aliases
the retained window allocation, protecting history needed by subsequent
matches. [CHUNKCOPY_SAFE](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/chunkset_tpl.h#L263)
clips to actual capacity, uses byte copy when a chunk cannot fit and otherwise
uses chunk machinery. Safe here does not mean exact-length.

Vort needs separate proofs for initialized source bytes, destination capacity
and committed output. Its semantic window pause preserves the next token's
input position. Reference slack and partial-match publication cannot simply
be copied into that contract.

## Initialized output and aliasing adapters

The Rust [Writer](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/writer.rs#L8)
owns `MaybeUninit<u8>` plus a filled length. Its
[ordinary chunk copy](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/writer.rs#L321)
requires sufficient additional capacity, otherwise copies exactly. Chunk
operations transport `MaybeUninit` lanes; only the filled prefix is exposed
as initialized output. This does not prove that ordinary Zig byte/vector loads
may read future uninitialized output lanes.

The [inflateBack window adapter](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/writer.rs#L188)
uses memmove semantics without padding when window/output alias; its match
adapter also copies exactly. Padded disjoint owned storage and unpadded or
aliased caller storage need separate executable Vort contracts.

The Rust [bitreader](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate/bitreader.rs#L76)
counts staged whole bytes in subsequent fast-iteration admission and rewinds
unused bytes at exit. Vort allows preloaded reservoir bytes from another
input slice, so its call-local delta accounting cannot be replaced by that
rewind without a narrower entry contract.

## Reusable state and CPU routing

zlib-ng [ResetKeep/Reset](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/inflate.c#L61)
and [zlib-rs resets](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate.rs#L2335)
retain allocated storage but distinguish keeping window state from clearing
valid history. Storage reuse does not authorize a previous dynamic Huffman
plan for unrelated input.

zlib-ng publishes a global function table atomically and
[requires BMI2 for AVX2 selection](https://github.com/zlib-ng/zlib-ng/blob/6d9f3dc072369dc719a5fbe71d4e086a96a680bd/functable.c#L169).
Vort can select kernels at context initialization without hidden mutable
global ownership. zlib-rs [caches CPU detection](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/cpu_features.rs#L29)
and routes its fast helper to a target-feature function. AVX2 passes a constant
feature parameter to Writer for 32-byte chunks; generic Writer still performs
runtime selection. This is not universally dispatch once at context init.

Its [fast helper](https://github.com/trifectatechfoundation/zlib-rs/blob/2e487e34e1d2a79c24545b4f843437611d77be2c/zlib-rs/src/inflate.rs#L1923)
temporarily moves reader/writer into locals and restores them before return,
avoiding state-field aliasing. Vort already uses local reservoir/cursor values
and noalias entry arguments. The useful invariant is clear ownership, not an
assumed win from another loop split or compiler flag.

Next separate checked semantic preparation from fallback materialization,
define padded/disjoint versus exact/aliased execution tiers, and keep storage
and kernel reuse distinct from dynamic-plan reuse. The
[main reference study](reference-decoder-study-20261112.md) specifies concrete
Deflate tail and Zstd X1 lifecycle boundaries. Every candidate still requires
fresh whole-operation, resource and malformed-input evidence.
