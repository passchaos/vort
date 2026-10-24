# Brotli joint literal block/context clustering

Date: 2026-10-14. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU affinity 2, one codec thread.

## Functional result

The literal entropy planner now combines temporal adaptive block types with
RFC literal context modeling:

- each block type independently selects LSB6, MSB6, UTF8, or Signed mode;
- actual insert literals build every selected `(block_type, context)`
  histogram using absolute plaintext history;
- populated histograms are clustered globally, allowing different block types
  to share trees;
- deterministic ordered/interleaved seeds, assignment/rebuild rounds,
  empty-tree compaction, and stable ties produce at most 256 trees;
- candidate scoring uses actual literal tree prefix/payload cost plus exact
  dynamic context-map wire cost;
- the identity-tree adaptive candidate remains present and only a strict
  complete-wire win is retained.

The allocator-owned plan covers 256 block types, four per-type modes, a full
16,384-entry map, and all 256 tree IDs. The generalized context-map planner
accepts 1--16,384 entries and 2--256 trees, explores plain/MTF with zero-run
prefixes 0--6, and guarantees `bit_cost == emitted bits`.

## External wire evidence

The off-grid production fixture retains boundaries 901/2305/5179/7001 and
`A-B-A-C-A` reuse inside one insert run. Its identity adaptive wire is 5,201
bytes; joint global clustering emits 943 bytes for the same 8,192-byte payload,
an 81.87% reduction. The production selector is byte-identical to a forced
joint plan, and temporal types share global trees.

A maximum fixture exercises 256 block types, 256 literal trees, tree ID 255,
four per-type mode values, and all 16,384 map entries. Dynamic MTF/RLE coding
emits 1,046 bytes versus the identity-map fixture's 16,948 bytes.

Vort, Node, runtime libbrotli 1.0.9, and progressive decoding accept the joint
fixtures. The required differential reports `planned_literal_split_cases=13`.
Coverage includes plan validation/cloning, full-width maps/trees,
deterministic global clustering, cross-type sharing, exact map/tree scoring,
malformed combinations, and allocator-failure cleanup across the clustering,
map, plan, and writer layers.

## Adoption and performance

Joint planning is part of the ratio-only `adaptive_literal_split` opt-in. Nine
built-ins and six explicit 128 KiB source/Markdown paths retained their default
sizes. The source rows measured default/joint throughput of:

| Input | Default/joint throughput |
| --- | ---: |
| `src/br.zig` | 0.2218x |
| `src/zstd.zig` | 0.2269x |
| `src/deflate.zig` | 0.2595x |
| `README.md` | 0.2279x |
| `docs/roadmap.md` | 0.2887x |
| `docs/zstd-gap.md` | 0.3432x |

This cost does not justify automatic routing on the current corpus. The full
feature remains available for heterogeneous caller payloads and supplies the
structural base for hierarchical merge queues, cheaper heterogeneity screens,
mode/tree coordinate descent, and selective automatic routing.

An 11-pair default-path control against `e83e5166` retained identical
6,563-byte source32k wire/checksum, won 7/11 pairs, and measured a neutral
`0.999455x` paired geometric ratio. Independent medians were
188.301/188.087 ms; this is no-regression evidence, not a speed claim.
