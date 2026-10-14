# Brotli quality and mode preset status

Date: 2026-10-14.

## Scope

The planned encoder accepts an optional Vort-native Brotli quality and mode:

```zig
const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
    allocator,
    input,
    .{ .quality = 8, .mode = .text },
);
defer allocator.free(encoded);
```

`quality` is `0...11`; `mode` is `.generic`, `.text`, or `.font`, with
`.generic` as the default. Setting `quality` selects one of 36 deterministic
schedules; `level` must remain at its default `.fast` because the two selectors
are mutually exclusive. Leaving `quality` null keeps the established
fast/balanced/ratio API and output policy unchanged.
The mode is an encoder hint, not a field in the Brotli stream and not automatic
content detection. Generic and text currently have the same policy; font adds
one optional distance-shape candidate from q4, so modes may legitimately choose
the same winning wire.

These presets emit RFC 7932-compatible streams through Vort's existing planned
encoder. They do **not** implement libbrotli's quality presets internally and
do not claim algorithm, byte-for-byte output, compressed-size, memory, or
throughput parity with libbrotli. A larger quality number generally deepens the
configured search and never retracts an enabled feature; q11 deliberately
trades a shorter deep-optimal input ceiling for more candidates while retaining
the complete q10 winner. Except for the explicit q11-over-q10 size guarantee,
the presets do not yet promise output-size monotonicity or the same speed/ratio
point as the corresponding libbrotli number.

## Implemented schedule

q0/q1 use bounded hash-greedy LZ77 planning; q2...q11 use bounded lazy LZ77
planning. All qualities share the existing Brotli Huffman and command writers,
exact complete-wire candidate comparison, and stored fallback. The default
advertised window is 16 bits. q0...q5 accept 10...16-bit windows; q6...q11
accept RFC windows 10...24. The quality path's ordinary LZ matcher is capped at
`lz77.max_window_len`, currently 65,535 bytes, even when a wider window is
advertised.

| Quality | Family | Current Vort behavior |
| ---: | --- | --- |
| 0 | fast | Minimum hash-greedy search: chain 1, nice length 16, one candidate; no contexts, splitting, recent distances, or dictionary probing. This is not a fragment encoder. |
| 1 | fast | Hash-greedy chain 2 and nice length 24; still no contexts, splitting, recent distances, or dictionary probing. This is not a fragment encoder. |
| 2 | balanced | Lazy chain 4 and nice length 32; every mode may try the built-in transformed static dictionary through 256 bytes. No specialized q2 entropy writer is present. |
| 3 | balanced | Lazy chain 8, nice length 48, recent-distance selection, and the same short-input dictionary candidate in every mode. No specialized q3 entropy writer is present. |
| 4 | balanced | Lazy chain 16 and nice length 64; enables existing literal/command/distance split candidates and distance-parameter search. Font additionally compares its first mode-specific distance-shape candidate. |
| 5 | balanced | Lazy chain 32 and nice length 96; every mode enables the fixed two-tree UTF-8 literal-context candidate. |
| 6 | ratio | Lazy chain 64 and nice length 128; adds a bounded 64-chain/16-candidate optimal search for 4--32 KiB inputs. The advertised window range expands to 10...24 bits. |
| 7 | ratio | Lazy chain 96 and nice length 160; adds clustered contexts, adaptive distance splitting, and extended static-dictionary probing through 4 KiB in every mode. |
| 8 | ratio | Lazy chain 128 and nice length 192; expands the optimal-input ceiling to 64 KiB with a 128-chain/64-candidate budget and enables adaptive literal splitting. |
| 9 | ratio | Lazy chain 256 and nice length 258; uses a 192-chain/128-candidate optimal search through 64 KiB and enables adaptive command splitting in addition to the q8 candidates. |
| 10 | ratio | Lazy chain 384 plus a 256-chain/128-candidate optimal search through 64 KiB and the bounded fixed-record candidate; joint literal block/context clustering is eligible. No Zopfli/HQ cost-refinement engine or placeholder HQ claim is attached to this preset. |
| 11 | ratio | Lazy chain 512, plus a deeper 512-chain/256-candidate optimal search limited to 32 KiB. It recursively retains the complete q10 winner before considering q11 candidates, guaranteeing q11 size is no larger than q10 for identical options. This remains bounded Vort optimal search, not libbrotli-style HQ Zopfli. |

The bounded optimal candidate is considered only for inputs from 4 KiB through
32 KiB at q6/q7, through 64 KiB at q8...q10, and through 32 KiB for q11's
deeper search. q11 separately evaluates the complete q10 path, so the q10
64 KiB candidate and all of q10's context, split, dictionary, font, and stored
decisions remain eligible. The q10/q11 fixed-record candidate is limited to
4--64 KiB, advertised windows of at least 16 bits, and the recognized
newline-terminated record shape. These are extra Vort candidates, not the
general libbrotli HQ parser.

## Mode effects

Generic, text, and font use exactly the same parser budgets, UTF-8 literal
context policy, split schedule, and dictionary thresholds and probe budgets:

- the built-in transformed static dictionary starts at q2;
- the fixed UTF-8 literal-context candidate starts at q5;
- extended static-dictionary probing through 4 KiB and context clustering start
  at q7.

Generic and text therefore currently select from the same candidates. Font
adds exactly one mode-specific choice from q4 onward: a complete wire using
`NPOSTFIX=1, NDIRECT=12` with same-last-distance optimization disabled. The
ordinary shared-policy wire remains a candidate, and the font wire is retained
only when its complete encoded byte length is smaller.

Static-dictionary candidates are considered through 256 bytes. When extended
search is enabled, the bounded indexed search applies through 4 KiB. This is a
vetted subset of the RFC built-in dictionary transforms; it is not support for
caller-supplied or shared dictionaries.

## Large-input and API boundaries

The quality-aware planner applies to a single input no larger than Brotli's
16 MiB meta-block limit. Larger inputs remain one valid Brotli stream, but are
routed through the established bounded 32 KiB chunk planner. That fallback
preserves the requested window and metadata while using its existing fast
per-block policy; it does not apply the requested quality/mode schedule or plan
matches and entropy decisions across blocks.

The current quality/mode surface is a one-shot planned-encoder policy available
through allocating, caller-buffer, and reusable-encoder one-shot frontends. It
does not add quality-aware behavior to the incremental planned encoder or the
explicit chunk-list options. Callers that need streaming today should continue
to use those APIs with their documented existing policy.

## Verification and performance claims

The schedule unit tests cover all 36 quality/mode combinations, validate every
row, require enabled features and search depth to grow, explicitly check q11's
shorter deep-optimal ceiling, and require the base policy to be equal across
modes. The planned Node differential emits one generic, text, and font fixture
at each of q0...q11 and requires Node's Brotli decoder to reproduce the input,
for 36 quality/mode interoperability cases. This is wire-compatibility evidence
only; it is not byte-parity or ratio/performance evidence against libbrotli.

The planned encode benchmark accepts independent Vort selectors:

```sh
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --planned-quality 8 --planned-mode text --iterations 100
```

Its existing `--quality` option continues to select the libbrotli reference
quality. Recording both values prevents a Vort schedule from being mistaken for
a libbrotli implementation. No general q0...q11 by mode ratio, throughput, or
memory parity claim is made until a pinned multi-corpus benchmark publishes
those dimensions.

### Local q8 smoke evidence

One pinned single-thread ReleaseFast smoke on 2026-10-14 used Zig 0.16.0,
reported libbrotli version `1000009`, and an Intel Core i7-10700K
(`skylake+pku+sgx`, affinity `0-15`). The benchmark takes the best of five
interleaved rounds; the JSON row used 20 iterations and `source32k` used five:

| Case | Input | Vort q8 | libbrotli q8 | Size / reference | Vort MiB/s | Reference MiB/s | Speed / reference |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `json` | 2,640 | 57 | 59 | 0.9661 | 13.09 | 266.88 | 0.0491 |
| `source32k` | 32,768 | 6,686 | 6,658 | 1.0042 | 1.71 | 49.31 | 0.0347 |

Commands:

```sh
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --case json --iterations 20 --quality 8 \
  --planned-quality 8 --planned-mode generic
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --case source32k --iterations 5 --quality 8 \
  --planned-quality 8 --planned-mode generic
```

The input SHA-256 values were
`0d6239d44e1f465d045e5179cc2a5bf0997a95bdd8ad70a11eb2f3d3f4796941`
and `d890ef81cce951440e62e0c288ca5b43b1f8134cf4a2463f477fed21cea6f38b`,
respectively. This deliberately narrow smoke shows the immediate performance
gap: q8 size is already close on these two fixtures, but repeatedly materializing
and comparing the current split/context/distance candidates is roughly 20x to
30x slower. It is evidence for profiling and candidate-pruning work, not a
multi-corpus performance claim.

## Missing libbrotli-class work

The following are explicit gaps, not implied by the presence of the preset
names:

- dedicated q0/q1 fragment compressors and their streaming fragment model;
- the specialized q2/q3 entropy writers and their matching block decisions;
- real q10/q11 Zopfli/HQ cost refinement, including iterative model feedback;
- shared dictionaries, contextual dictionaries, and compound dictionaries;
- quality-aware large-stream planning, including cross-meta-block matches,
  quality-specific block sizing, and entropy/context decisions;
- calibration and regression gates for compression ratio, throughput, peak
  memory, and output-size monotonicity across representative corpora and
  platforms.

Until those items land, describe this surface as “Vort-native q0...q11
generic/text/font presets” rather than “libbrotli-compatible quality presets.”
