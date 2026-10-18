# Brotli quality and mode preset status

Date: 2026-10-15.

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
are mutually exclusive. On the bounded one-shot path, leaving `quality` null
keeps the established fast/balanced/ratio policy. On chunked/incremental paths,
null selects the shared fast policy, now with bounded cross-block history.
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

Bounded stream planning uses a quality-specific automatic block size: q0 uses
16 KiB for lower latency; q1, q6, q7, and q11 use 32 KiB; q2...q5 and q8...q10
use 64 KiB to amortize meta-block headers. Legacy fast uses 32 KiB; balanced
and ratio use 64 KiB. `BrotliPlannedStreamChunksOptions.block_len` may
explicitly select any size from 1 through 64 KiB. The incremental encoder's
outer `block_len` takes precedence when non-zero; otherwise the stream option
or automatic policy is used. q6/q7/q11 therefore keep every automatic block
inside their deepest optimal-search ceiling.

Legacy balanced/ratio plus q2...q5 and q8...q10 inspect both 32 KiB halves of each
automatic 64 KiB lookahead. A deterministic allocation-free Q8 byte-histogram
model materializes a midpoint candidate only when separate literal entropy
beats the combined distribution by more than a conservative 2,048-bit
header/tree allowance. The encoder then compares the exact single-block and
two-block bit counts and keeps the split only when it is strictly smaller.
Homogeneous data therefore keeps the larger block, while a profitable strong
distribution transition gets two independently modeled blocks without losing
cross-block LZ77 history or the recent-distance ring. `adaptive_blocks = false` disables
this policy; `true` forces it for a 64 KiB configured block. A non-zero explicit
`block_len` is fixed by default. Automatic lookahead is disabled above the
standard 16-bit window to keep branch snapshots bounded; forcing it there is
rejected. Conservative encoded bounds assume every adaptive 64 KiB block may
split.

| Quality | Family | Current Vort behavior |
| ---: | --- | --- |
| 0 | fast | Minimum hash-greedy search: chain 1, nice length 16, one candidate; no contexts, splitting, recent distances, or built-in static-dictionary probing. Explicit RAW shared-prefix matching remains available. This is not a fragment encoder. |
| 1 | fast | Hash-greedy chain 2 and nice length 24; still no contexts, splitting, recent distances, or built-in static-dictionary probing. Explicit RAW shared-prefix matching remains available. This is not a fragment encoder. |
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
context policy, split schedule, and built-in static-dictionary thresholds and
probe budgets:

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
vetted subset of the RFC built-in dictionary transforms. The dedicated
`brEncodePlannedStreamStaticDictionaryAlloc` API instead uses the exhaustive
reference matcher and covers all 121 standard transform families; it is kept
separate because exhaustive search is intentionally ratio-oriented. Neither
path is support for caller-supplied/custom static dictionaries. RAW
shared-prefix matching is the separate option described below.

## RAW shared-prefix encode/decode boundary

`BrotliSharedDictionary` is a borrowed descriptor for zero through fifteen
ordered RAW attachments. Non-empty attachments are logically concatenated in
order; an empty attachment contributes no bytes but still consumes one
attachment slot.

`BrotliPlannedEncodeOptions.shared_dictionary` makes RAW matching available to
one-shot and reusable planned encoding at legacy fast/balanced/ratio and
q0...q11, independently of the table's built-in static-dictionary schedule.
The streaming surfaces use
`BrotliPlannedStreamChunksOptions.shared_dictionary` and
`BrotliIncrementalPlannedStreamEncoder.Options.stream.shared_dictionary` for
chunked and incremental encoding respectively. The same stream options now
carry `level`, `quality`, and `mode`; omitting them preserves the established
fast policy while non-null quality applies the selected schedule per bounded
meta-block. Omitting the dictionary preserves compound-free behavior.

With a non-empty RAW descriptor, the one-shot path applies the selected
quality's lazy-search budget, context/split policy, recent-distance policy,
adaptive split overrides, distance-parameter search, and built-in static-
dictionary budget to the compound-aware command plan. It does not yet combine
RAW matches with the separate optimal-parser, fixed-record, or font-distance
alternative candidates used by some higher presets, and non-empty RAW q11 does
not inherit the complete q10 winner. Consequently, the ordinary no-dictionary
q11 <= q10 size guarantee does not currently extend to non-empty RAW
dictionaries. Closing that ratio gap is performance work; it does not change
the accepted quality range or wire interoperability described here.

Compound references use the actual Brotli wire distance and update the recent-
distance ring when explicit; implicit rep0 leaves its order unchanged. Built-in
transformed static-dictionary references never update the ring. The encoder's
fixed 15-bit/four-way matcher index occupies about 1 MiB on 64-bit targets once
a non-empty dictionary is prepared. Reusable and incremental encoders retain
the index, but never copy or own the attachment bytes.

`BrotliDecodeOptions.shared_dictionary` is honored by one-shot
`brDecodeStream*WithOptions` decoding,
chunked decode, decoded-size and summary APIs, caller-history summaries, and
both the caller-history `BrotliIncrementalCopyStreamDecoder` and allocator-owned
`BrotliIncrementalStreamDecoder` progressive paths. Summary results distinguish
shared-dictionary use with `uses_shared_dictionary`,
`shared_dictionary_copy_count`, and `shared_dictionary_bytes`.

The outer attachment slice and every attachment's bytes are borrowed without
copying. They remain alive and unchanged throughout any synchronous call.
Reusable encoders retain the matcher index, not the bytes; index reuse for an
identical descriptor requires the attachment bytes to stay unchanged across
calls. Incremental encoders retain them through finish/drain and reset reuse,
or until `nextStream` installs completed-stream options. Progressive decoders
retain them from initialization through completion and reset reuse; the
allocator-owned decoder can replace them only through `nextFrame` after
completing the current frame.

Latest upstream still marks serialized shared dictionaries as
`BROTLI_EXPERIMENTAL` and `DO NOT USE`, so Vort does not expose that unstable
wire. Caller-supplied/custom static dictionaries are unsupported; RAW
attachment support does not promise future API or wire compatibility for
either unsupported form.

## Large-input and API boundaries

Inputs larger than Brotli's 16 MiB meta-block limit remain one valid stream and
are split into bounded 16/32/64 KiB planning blocks selected as above. Every block applies the selected
legacy level or q0...q11 quality/mode policy, including its parser budget,
recent-distance choice, context/split candidates, bounded optimal candidate,
distance-parameter/font candidate, static-dictionary policy, and exact
compressed-versus-stored bit comparison. LZ77 history and the actual committed
recent-distance ring continue across block boundaries and are bounded by the
advertised window. A stored fallback rolls back candidate distance state while
advancing the logical output position.

The same policy core backs allocating, caller-buffer, reusable, explicit
chunk-list, and incremental planned encoders, including RAW shared-prefix
matching. Incremental `flush` and metadata boundaries preserve the selected
stream policy and bounded history. Explicit chunked/incremental block-size
overrides use the same core and conservative stored-stream bounds.

## Verification and performance claims

The schedule unit tests cover all 36 quality/mode combinations, validate every
row, require enabled features and search depth to grow, explicitly check q11's
shorter deep-optimal ceiling, and require the base policy to be equal across
modes. The planned Node differential emits one generic, text, and font fixture
at each of q0...q11 and requires Node's Brotli decoder to reproduce the input,
for 36 quality/mode interoperability cases. This is wire-compatibility evidence
only; it is not byte-parity or ratio/performance evidence against libbrotli.

The dedicated RAW shared-dictionary gate passed in Debug and ReleaseFast
against local libbrotli 1.2.0 with this matrix:

| Direction and Vort surface | Attachments | Qualities | Cases |
| --- | --- | --- | ---: |
| libbrotli encode -> Vort decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort one-shot encode -> libbrotli decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort reusable encode -> libbrotli decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort chunked encode -> libbrotli decode | 0/1/2/15 | fast coverage row | 4 |
| Vort incremental encode -> libbrotli decode | 0/1/2/15 | fast coverage row | 4 |
| Stateful window/ring/rollback/static regressions | mixed | fast/ratio | 4 |

The stateful regressions cover WBITS=10 saturation and cross-block recent
reuse, stored rollback followed by compound copy, incremental metadata and
output backpressure, and static addressing after a saturated compound region.
The same run retains four upstream decode fixtures and three descriptor-error
cases. System libbrotli 1.0.9 lacks the optional shared-dictionary symbols, so
the tool explicitly reports the complete runtime matrix as skipped there.
Debug and ReleaseFast `zig build test-br` pass all 775 tests, including q0...q11,
legacy level, retained-index, empty-dictionary wire, static-address shift,
incremental rollback, cross-API quality wire equality, and 16 MiB+ q0/q2
coverage. The upstream differential passes in both build modes with 7,056
one-shot and 7,056 progressive generated cases, 1,401 fragmentation runs, 64
high-tree truncations, seven Large Window cases, and one Vort-generated 16 MiB+
q2/font stream decoded independently by libbrotli 1.0.9
(`planned_large_quality_cases=1`). Five additional Vort-generated streams pin
q0/q2/q6/q11 automatic sizing plus an explicit 24 KiB override through
libbrotli (`planned_quality_block_size_cases=5`).
Two more streams require automatic q2 midpoint splitting and its explicit
disable path to decode through libbrotli
(`planned_stream_segmentation_cases=2`).

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
- contextual dictionary encoding;
- global multi-boundary segmentation and exact compressed-cost optimization
  beyond the current bounded midpoint entropy lookahead;
- calibration and regression gates for compression ratio, throughput, peak
  memory, and output-size monotonicity across representative corpora and
  platforms.

Until those items land, describe this surface as “Vort-native q0...q11
generic/text/font presets” rather than “libbrotli-compatible quality presets.”
