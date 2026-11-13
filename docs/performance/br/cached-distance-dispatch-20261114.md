# Brotli cached distance dispatch screen, 2026-11-14

Status: rejected before full-matrix adoption. No production source changed;
the prototype lived on a temporary branch and was removed after the screen.

## Hypothesis

The mozilla full q11 profile attributes 10.19% self weight to
`distancePrefixForDecode` and another 8.01% to `readMinimalDistance`. For
single-block distance alphabets the four context trees never switch, so
pinning them once at payload entry should remove the per-match context-map
load, tree-index bounds check and prefix-code indirection.

## Prototype

In `processWideExternalLiteralLookupCompressedPayloadCore`, when
`auxiliary_tail_lookups` is true and `header.distance_block.block_type_count
== 1`, build a four-entry `cached_distance_trees` array from the context map
before the command loop. The match path then resolves the context directly
into that cached `PrefixCode`, decodes with the same fixed-9 tail lookup and
reuses the existing short/long distance helpers. Multi-block frames and the
non-auxiliary generic path keep their original block-aware readers.

The complete `zig test src/br.zig` suite passes.

## Twenty-four-row paired screen

Twelve fixtures at 64 KiB and 1 MiB, qualities 6 and 11, 40 iterations with
four rounds and two warmup pairs on CPU 15 against libbrotli 1.2.0.

- geometric mean baseline/candidate: 1.000844 (parity)
- three rows below the 0.98x floor in the first sweep
  (ooffice 64K q6 0.97167, ooffice 64K q11 0.97059, reymont 64K q11 0.97840)

A rerun of those controls shows the losses are unstable: ooffice q6 returns
1.00064/1.00499, while ooffice q11 and reymont q11 oscillate around parity
(0.967..1.002). The candidate neither delivers a reliable gain nor stays
above the control floor; code-layout perturbation from the new cache block
offsets any removed indirection.

## Why it fails

The hot profile's `distancePrefixForDecode` cost includes the
`readMinimalDistance` caller frame and reader state work, not only the tree
lookup. Caching the tree pointer removes one load but leaves the context
computation, tail decode, prepared-distance staging and ring update intact,
so the surviving instructions dominate and reorder around the new stack
resident cache. Like the Deflate primary-only flag, this adds a
discriminator/cache rather than removing carried state.

A viable follow-up must reduce the whole distance resolution sequence
(context + tree + staged read + ring bookkeeping), for example by fusing
the four-context selection into the prepared lookup itself, rather than
hoisting only the tree pointer. No A/B artifacts are committed; baseline
probe SHA is
`66bc992521fba3c03c7444fa59f2bcedeed1e5da5ece6f20a4f1f04919447e6b`.
