# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output, a single-frame native best stream, a blocked native stream
without the embedded index, and a native embedded-index stream on sample project
files. `zig build
run-zstd-compare-standard-gate` runs the same comparison over
standard corpus discovery, bounded to the first three 128 KiB cases by default.
`zig build run-zstd-compare-standard-releasefast-gate` retains the same
comparison through a ReleaseFast Vort CLI over the first twelve bounded standard
rows (the full local Silesia-small bounded set when available) for
performance-oriented smoke evidence; it is intentionally opt-in because
compiling the extra ReleaseFast CLI is much more expensive than the Debug CI
smoke. This is a smoke comparison, not
a performance claim: it uses zstd level 1 via the local CLI and debug-built Vort
CLI paths unless the ReleaseFast step is selected. The build steps retain
`zig-out/vort-zstd-compare.csv` / `.md` and
`zig-out/vort-zstd-compare-standard.csv` / `.md`, plus opt-in
`zig-out/vort-zstd-compare-standard-releasefast.csv` / `.md`, so the size smoke
can be linked from dashboard indexes instead of only appearing on stdout.
`zig build run-zstd-compare-block-sweep-gate` additionally retains
`zig-out/vort-zstd-compare-block-sweep.csv` / `.md` / `*-gate.json` for a
standard-suite 4/8/16/32/64 KiB native block-length sweep;
`zig build run-zstd-compare-block-sweep-releasefast-gate` is the opt-in
ReleaseFast variant for the same tier table. The retained
CSV/Markdown include per-input rows plus a `TOTAL` aggregate row for
raw fixed, native best, native stream, and native embedded size ratios; the
stream/native-best overhead from block fragmentation; the embedded/native-stream
overhead from the index frame itself; native block length; and median-of-3
decode throughput. The zstd decode rows still include process/stdout plumbing,
while Vort raw/native best/native embedded rows now use CLI-internal decode
loops divided by the repeat count after a one-shot output check. The three gate
steps validate the retained artifacts and write matching `*-gate.json`
summaries.

Example local Debug default-sample size smoke after splitting native stream and
embedded-index overhead (2026-07-22; decode columns are retained in CSV/Markdown
but are still intentionally treated as smoke evidence):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_best_bytes,vort_native_stream_bytes,vort_native_embedded_bytes
/home/passchaos/project-z/vort/README.md,25924,6176,6271,5757,6338,6514
/home/passchaos/project-z/vort/docs/roadmap.md,130331,37866,39091,39260,44175,44831
TOTAL: raw/zstd 1.030x, native-best/zstd 1.022x, native-stream/zstd 1.147x, native-embedded/zstd 1.166x, stream/best 1.1221x (+5496 bytes, +12.21%), embedded/stream 1.0165x (+832 bytes, +1.65%), embedded/best 1.1406x (+6328 bytes, +14.06%)
```

Example local Debug standard-suite smoke (`--standard-suite --limit 3`, bounded
128 KiB rows from the discovered Silesia tar):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_best_bytes,vort_native_stream_bytes,vort_native_embedded_bytes
silesia-small.tar:silesia-small/ooffice-128k,131072,76985,74575,70298,74348,75004
silesia-small.tar:silesia-small/nci-128k,131072,11129,15154,13877,19219,19875
silesia-small.tar:silesia-small/mozilla-128k,131072,21823,25437,23988,29014,29670
TOTAL: raw/zstd 1.048x, native-best/zstd 0.984x, native-stream/zstd 1.115x, native-embedded/zstd 1.133x, stream/best 1.1333x (+14418 bytes, +13.33%), embedded/stream 1.0161x (+1968 bytes, +1.61%), embedded/best 1.1515x (+16386 bytes, +15.15%)
```

Example local Debug block-length sweep on the same standard-suite rows:

```text
tier,block_len,total_native_stream_bytes,native_stream/zstd,stream/native_best,stream_overhead_bytes,embedded_index_bytes,range_decode_mib_s
custom,4096,130653,1.1884,1.2079,22490,3888,15.37
seek_fast,8192,122581,1.1150,1.1333,14418,1968,8.37
custom,16384,117473,1.0685,1.0861,9310,1008,4.59
balanced,32768,113457,1.0320,1.0489,5294,528,2.67
ratio,65536,110784,1.0077,1.0242,2621,288,0.92
```

Example local ReleaseFast block-length sweep on the same standard-suite rows
(timing is still through the CLI bench surface, but avoids Debug codegen):

```text
tier,block_len,total_native_stream_bytes,native_stream/zstd,range_decode_mib_s
custom,4096,130653,1.1884,63.50
seek_fast,8192,122581,1.1150,38.36
custom,16384,117473,1.0685,19.64
balanced,32768,113457,1.0320,10.36
ratio,65536,110784,1.0077,5.26
```

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
- The native best, blocked stream, and embedded rows prove the comparison
  artifacts now separate native payload efficiency, block-fragmentation cost, and
  the embedded-index frame bytes. On the Debug default samples, most indexed
  overhead is currently stream fragmentation (`+5496` bytes) rather than the
  embedded index frame (`+832` bytes); the same pattern appears in the bounded
  three-row standard smoke (`+14418` stream bytes versus `+1968` index bytes).
  The block-length sweep shows that raising the smoke block length from 8 KiB to
  64 KiB cuts the same three-row stream overhead from `+14418` to `+2621` bytes
  and embedded-index bytes from `+1968` to `+288`, bringing native stream size to
  `1.0077x` zstd. The same sweep now records centered 4 KiB range-decode smoke
  throughput, which drops from `15.37` MiB/s at 4 KiB blocks to `0.92` MiB/s at
  64 KiB blocks in Debug and from `63.50` MiB/s to `5.26` MiB/s in the
  ReleaseFast CLI sweep because each small range must decode a larger containing
  frame.
  The current embedded-index frame is still a validation/seek surface rather than
  a final zstd-class native entropy format.
- The current smoke says Vort fixed-deflate is close on these two text files
  (`~1.5%` larger on `README.md`, `~3.2%` larger on `docs/roadmap.md`), but it
  now times Vort decode inside one CLI process; zstd decode still includes
  process/stdout overhead and the result remains a smoke signal. It still does
  **not** measure library-level decompression speed, memory use, full binary
  corpora, or zstd's higher compression levels.
- Native seekable encoding now has a deterministic parallel API for plain,
  explicit-dictionary, and dictionary-set streams. Frames are independently
  encoded through a bounded caller-selected work queue and serialized in the
  same order as the existing serial encoder; worker-spawn failure reduces
  concurrency instead of changing output. On an Apple M1 Pro ReleaseFast run over
  an 8 MiB generated payload split into 32 256 KiB frames, the retained
  `run-zstd-seekable-parallel-bench-gate` artifact measured 83.49, 164.88,
  320.18, and 537.49 MiB/s for 1/2/4/8 requested workers, or 1.96x/3.81x/6.42x
  at 2/4/8 workers. All rows produced the same 2,229,301-byte stream and pass a
  range-decode check. This is strong same-machine evidence for frame-level
  scaling, but it is one generated corpus and does not replace comparison with
  libzstd's streaming/multithreaded encoder on standard corpora.
- The compatibility decoder now covers single-stream and four-stream
  Huffman-literals sections, can reuse that tree for treeless repeat-literals
  blocks, and decodes FSE-compressed sequence tables for the currently supported
  sequence execution path. The broader gap remains open until Vort has
  long-distance matching in the encoder/decoder pipeline, broader compression
  strategy coverage, corpus
  throughput/ratio dashboards, and repeatable same-machine comparisons against
  zstd CLI/library modes.
- The native encoder now exposes an explicit `fast_compressed` selection for
  callers that need compressed output with less arbitration latency than the
  numeric level-1 policy. It is available through one-shot/reusable/caller-
  buffer, incremental, raw-content dictionary, dictionary-set, and CLI
  surfaces (`fast_compressed` or `fast-compressed`). Each block tries RLE, a
  decisive prefix-tail match, and the double-fast sequence parser; it commits a
  valid match candidate without running the repeat-beam/full arbitration, and
  only tries Huffman-only output when no match candidate is available before
  falling back to raw. This is an opt-in policy: `.auto` and numeric levels
  0/1/3 keep their established behavior and byte selection. Incremental output
  is byte-identical to one-shot output at the same block size, including tiny
  caller-output splits.

  A same-process ReleaseFast run on Apple M1 against runtime libzstd 1.5.7
  (`--native-selection fast_compressed --level 1 --iterations 1000 --rounds
  7`, checksum disabled on both sides) measured:

  | case | Vort bytes | libzstd bytes | Vort MiB/s | libzstd MiB/s | speed ratio |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | text | 80 | 80 | 4979.04 | 6866.33 | 0.7251x |
  | JSON | 694 | 838 | 385.27 | 1877.73 | 0.2052x |
  | binary | 8607 | 8609 | 217.37 | 1490.92 | 0.1458x |
  | tradeoff | 2038 | 1967 | 105.30 | 2291.87 | 0.0459x |
  | multiblock | 34228 | 25606 | 110.26 | 2119.27 | 0.0520x |

  The mode fills a useful Vort-internal Pareto gap (roughly 1.1x/3.5x/1.4x/
  1.0x/2.5x faster than the existing level-1 path on those five rows), but it
  is still only 0.046x--0.725x of libzstd's encode throughput and loses ratio on
  the tradeoff and multiblock rows. It therefore does **not** establish
  libzstd performance parity. `zig build
  run-zstd-fast-compressed-bench-gate -j1` retains and validates a shorter
  five-row artifact at
  `zig-out/vort-zstd-fast-compressed-bench.csv`; pass
  `-- --libzstd PATH` when loader discovery is insufficient.

  For blocks with more than 512 sequences, `fast_compressed` now builds FSE
  transitions directly from the compression table instead of building a decode
  table and recovering its inverse transitions through per-symbol chains. The
  hot kernel is isolated in `src/zstd/sequence/large/transition.zig`;
  default level encoding retains the existing general planner and full
  RLE/predefined/compressed/repeat arbitration. Direct/inverse oracles compare
  table bytes, initial state, and every transition field at 513, 1,024, and
  2,047 sequences, while whole-block and incremental/one-shot tests preserve
  exact wire output. Five alternating independent-binary fast matrices raise
  multiblock median throughput from 125.29 to 232.75 MiB/s (`1.8577x`) with all
  five row medians at or above `1.0000x` and a `1.1551x` geometric mean. A
  separate default 20-row matrix reaches `1.0183x` geometric mean; longer
  controls retain binary level 1 at `0.9915x` and improve JSON level 3 by
  `1.0100x`.

  Large LL/ML planning now materializes each canonical code stream once and
  shares it across RLE, predefined, compressed, and repeat candidates. The
  predefined planner intersects precomputed per-code state masks instead of
  rescanning every state for each sequence. A scalar oracle compares selected
  states at 513, 1,024, and 2,047 codes for LL/OF/ML. Eleven alternating
  1,000-encode controls against the previous commit improve explicit fast
  multiblock by `1.0792x` median with 11/11 wins; default text levels 3/9 and
  JSON level 9 remain at `1.0091x`/`1.0052x`/`1.0015x`. A nine-pair
  five-row fast matrix preserves every hash, frame size, and checksum, with
  multiblock at `1.0794x` and a `1.0225x` row-median geometric mean.

  The fast-only large-sequence cost pass is now isolated in
  `src/zstd/sequence/large/plan.zig`. It reuses the existing
  canonical code arrays to total value and transition bits, then selects the
  LL/OF/ML table tuple by index; the default planner remains a separate comptime
  instance with no runtime policy branch. A 4,096-case randomized cost/selection
  oracle plus a four-way 128 KiB frame comparison (direct/inverse transitions
  and cached/scalar cost) and the normal OOM probes retain identical output.
  Eleven alternating
  1,500-encode pairs improve fast multiblock by another `1.0756x` median with
  11/11 wins. The formerly sensitive default tradeoff levels 1/3 recover to
  `1.0068x`/`1.0054x` medians over the same 11-pair control.

  The double-fast parser now reserves a bounded 64-token cold-start capacity
  only for inputs above 64 KiB, reducing early token-list growth on wide blocks
  without adding input-proportional memory or changing ordinary-block behavior.
  An initial-allocation failure test preserves cleared caller state and balanced
  ownership. Fifteen alternating 1,500-encode comparisons against the frozen
  `732039c2` executable preserve every hash, size, and checksum; the 132,096-byte
  fast multiblock row improves by `1.0057x` median with 13/15 wins, and the five
  row-median geometric mean is `1.0022x`. Default multiblock levels 1/3 remain at
  `1.0021x`/`1.0006x` median over 21 longer pairs. Broader all-input reservation,
  a 128-token wide reserve, a folded sentinel/range guard, and upstream-style
  dummy-candidate loads did not meet the cross-corpus or repeatability bar and
  are not retained.

  A frozen independent-binary control also compared the unchanged default
  selection across 15 paired runs of the complete 20-row matrix, 50 iterations,
  and three interleaved rounds per row. Every input SHA-256, Vort/reference size, and checksum
  matched; the row-median geometric speed ratio was 1.0081x. Its weakest short
  median was JSON level 1 at 0.9900x, while a 31-pair long control recovered to
  1.0117x median / 1.0106x geometric mean with 31/31 wins. This supports the
  claim that adding the opt-in route did not silently replace the default
  level policy.
- Large sequence-free four-stream Huffman sections now follow upstream zstd's
  independent-stream scheduling: all four streams advance together and decode
  five symbols per 64-bit reservoir load, with the existing checked decoder
  handling every stream tail. On the locked 64 KiB high-entropy ASCII frame,
  twelve alternating fixed-CPU runs improve Vort's median from about 188.03
  MiB/s to 781.84 MiB/s (`4.16x`, 12/12 wins); a same-process run reaches about
  0.66x of libzstd 1.5.5, up from roughly 0.16x. This is a focused decode improvement,
  not a general Zstd parity claim.
- The level-9+ encoder now recognizes a low-alphabet one-block primary frame at
  or below 1/32 of source size as decisive and skips the remaining adaptive
  split search. The locked 32 KiB JSON row keeps its exact 640-byte wire while
  improving from about 2.45 MiB/s to 12.5--13.1 MiB/s (`5.2x`); generated
  exhaustive-arbitration tests pin the boundary. This closes a scheduling cliff,
  not the broader encoder throughput gap to libzstd.
- Level 3 applies the same threshold as a documented speed/ratio tradeoff. A
  1,024-case generated audit found 11 split winners totaling 92 saved bytes
  (worst case 29 bytes); the other 1,013 cases were unchanged. The locked JSON
  frame remains 640 bytes while throughput improves by roughly 3.8x.
- The level-3 speed policy also stops after its primary frame on wide-alphabet
  single-block input. A 1,152-case audit found 22 split winners totaling 175
  bytes, with a 22-byte worst case; the other 1,130 cases were unchanged. The
  locked binary frame remains 8,607 bytes while throughput improves by about
  `4.0x` (12/12 fixed-CPU pairs). Levels 4+ retain exhaustive split arbitration.
- Level 9+ keeps ratio semantics stricter: wide-alphabet primary frames return
  early only at 3:1 compression or better. A 1,008-case structured/noise audit
  produced 280 qualifying cases and zero split winners, after an unrestricted
  audit had exposed 71 counterexamples. The locked binary level-9 frame remains
  8,607 bytes and improves by about `3.3x` (12/12 fixed-CPU pairs).
- Wide level-1--3 and level-9+ blocks can now stop candidate-family arbitration when double-fast
  and repeat-beam independently emit the same block at 3:1 compression or
  better. Of 280 qualifying generated cases, 184 reached consensus and all 184
  matched exhaustive arbitration byte-for-byte; omitting the consensus check
  had 16 regressions. The locked binary level-9 row gains another `2.74x` with
  identical wire output.
  Comparing the two token streams and their accounting before emitting the
  repeat-beam wire removes redundant entropy construction: token and wire
  consensus covered the same 184 audit cases with zero disagreement, and the
  locked row gains another `1.24x` over the committed double-wire check.
- Level 3 now uses the same consensus proof from its 64-state budget. Of 168
  generated wide blocks meeting the 3:1 threshold, 89 parser agreements all
  matched complete level-3 arbitration. The locked binary row remains 8,607
  bytes while improving by about `2.14x` (12/12 fixed-CPU pairs).
- The specialized two-state repeat-beam matcher now rejects compact-index hash
  collisions with a full four-byte prefix comparison and resumes extension
  after that proven prefix; recent-offset probes use the same exact skip. A
  scalar compact-index oracle checks every position across eight generated
  inputs. On the locked 32 KiB binary level-3 row, the focused repeat-beam
  median falls from 633.07 to 611.50 microseconds per block. Five alternating
  independent-binary runs preserve the 8,607-byte frame and checksum while
  raising median throughput from 40.69 to 42.54 MiB/s (`1.0452x`, 5/5 wins);
  the 20-row encode gate then passes on three consecutive runs without changing
  its strict level-3/level-1 latency threshold.
- The consensus trigger also covers level 1's 16-state and level 2's 32-state
  budgets. Both 1,008-case audits found 89 agreements and 89/89 matches with
  their complete arbitration. The locked binary level-1 row gains `1.71x`
  (12/12 fixed-CPU pairs) without changing its 8,607-byte wire.
  The selected double-fast wire now writes directly into the reusable caller
  scratch. This removes one allocation and 13,028 requested bytes on the locked
  32 KiB block; every allocation-failure path restores the caller's prior
  output. Timing was only a noisy `1.04x` average (5/12 wins), so this is kept
  as a deterministic allocation improvement rather than a throughput claim.
  Consensus disagreement also reuses the completed repeat-beam plan during full
  arbitration. The fixed fallback case stays at 1,393 bytes while improving by
  `1.25x`/`1.21x`/`1.13x` at levels 1/3/9, each across 12/12 fixed-CPU wins,
  and removes four allocations plus 897,583 requested bytes.
- Level 1 treats a double-fast block at or below `4/15` of source size as final.
  A 784-case audit found 51 smaller, 76 equal, and nine larger results versus
  complete 16-state arbitration; the aggregate was 11 bytes smaller, while the
  worst individual cost was 32 bytes. The locked binary row keeps its 8,607-byte
  frame and improves by about `2.20x` (12/12 fixed-CPU pairs).
- Level 3 uses a narrower `1/16` direct-double-fast cutoff for exceptionally
  compressible wide blocks. A 784-case audit found eight qualifying cases: three
  smaller by eight bytes total, four equal, and one larger by one byte versus
  complete 64-state arbitration. The fixed 2,038-versus-2,037-byte frame boundary
  improves level-3 throughput by about `7.06x` (12/12 fixed-CPU pairs); level 2
  and level 9+ retain strict double-fast/repeat-beam consensus.
- Multi-block levels 1--3 overlap primary encoding on the caller thread with the
  larger adaptive split worker while preserving the exact candidate set and
  shortest-frame result. An 80-case 129/192 KiB audit found the larger split won
  every generated case, and the fixed 129 KiB frame remains byte-identical to
  serial arbitration at all three levels. Fixed-CPU A/B medians improve level 1
  by about `1.038x` and level 3 by `1.090x`; a dedicated same-process gate also
  covers level 2 and enforces a conservative `1.01x` floor per level.
- `zig build run-zstd-native-probe` now complements the black-box CLI smoke with
  a bounded generated-corpus differential probe over multiple zstd levels and
  data shapes, keeping previously discovered Huffman/FSE/repeat-offset bug
  classes visible without requiring a full external corpus checkout, including
  zero-literal rep1/rep2 selector paths, positive-literal rep0/rep1/rep2 plus Repeat_Mode positive-literal rep0/rep1/rep2 replay, invalid
  `rep0 - 1` rejection, valid cross-block `rep0 - 1` after a
  direct-offset update including the minimum non-zero `rep0 - 1 == 1`
  boundary, and Repeat_Mode replay of that `rep0 - 1` selector
  after the repeated-offset ring mutates, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, repeated mixed-table modes across blocks, non-dictionary LL/ML/OF=FSE Repeat_Mode replay, invalid-magic/skippable-adjacent header diagnostics, and no-content-size window/block-size rejection, plus pure library-level libzstd-generated frame differentials. It also
  validates Vort's dependency-free native encoder on the same generated/file
  byte payloads through `encode-zstd-native-bytes-hex` in `auto`, `raw_or_rle`,
  and `literal_only` modes, including both 4-divisible and non-4-divisible
  four-stream Huffman literal payloads, the max direct Huffman symbol set
  (`0...128`) plus FSE-Huffman high-byte literal blocks, long-period and long-prefix
  repeated-pattern writer cases, a small-depth hash-chain duplicate-candidate writer case,
  no-dictionary mixed duplicate/repeated match selection plus dictionary/native
  match-vs-Huffman size arbitration, smallest native match-plan arbitration,
  RLE/predefined sequence cost scoring for single and mixed match candidates,
  mixed RLE/predefined plus limited compressed-FSE sequence-table mode emission
  (LL/OF/ML, public frame-probe coverage for compressed offset-table repeat selector emission,
  public frame-probe coverage for writer-side all-LL/OF/ML compressed-FSE table-plan selection,
  Repeat_Mode replay, and malformed table/state/end-marker paths,
  repeated-table reuse, and short/corrupt LL/OF/ML FSE state streams covered by public dictionary probe
  inspection/decode, with writer-side ML construction still covered by focused
  unit round-trips, public frame-probe coverage for mixed OF+ML compressed-FSE tables
  including reserved-bit/truncated/short-bitstream malformed paths, and frame-probe malformed paths for repeated-table truncation),
  branch-scored mixed duplicate/repeated and dictionary/duplicate/repeated
  match lookahead and emission,
  RLE-literals sections for same-byte sequence literals,
  Huffman-compressed literals inside sequence blocks when the literal payload is compressible,
  including high-byte FSE-Huffman sequence literals, raw-block-cost-aware sequence selection, plus public frame-probe
  coverage for file-backed multi-block treeless Huffman literal reuse, then checks
  both system zstd decode and Vort native decode, with `size-zstd-native-hex`
  preflight checked before each native decode. The native decoder accepts
  zero-valued Dictionary_ID fields without requiring a dictionary while still
  allowing callers to explicitly provide an ID-less raw-content dictionary via
  `NativeDictionary.initRawContent`; non-zero IDs still require a matching
  `NativeDictionary`. Dictionary-aware alloc/append/into/scratch/size APIs can
  use either raw-content or full-dictionary preset bytes as match history for the
  native sequence subset. Seekable scan/index range decoders expose equivalent
  explicit-dictionary into/alloc variants for ID-less random access.
  Dictionary-set decode APIs can resolve per-frame Dictionary_ID
  values in concatenated native streams without caller-side frame splitting,
  chunk-joined decode helpers accept split compressed input with caller-owned
  join scratch, incremental decoder facades expose the shared StepResult
  contract for split-input/caller-output library use and can now drain
  concatenated native streams while skipping skippable metadata frames,
  including dictionary-set streams whose frames carry different Dictionary_ID
  values. Those facades also expose caller-configured compressed-frame and
  decoded-frame buffer limits. Zstd data frames larger than the compressed-input
  limit now switch to a block-streaming path: raw bytes are released while
  copied, RLE blocks retain only their symbol, and compressed blocks retain at
  most one block while carrying dictionary/history, Huffman/FSE tables, and
  repeat offsets forward. Exact-size allocation variants and incremental `expected_output_len`
  plus `finish()` provide strict SizeMismatch semantics when callers know the
  expected output length. LZ4 native incremental decoding now moves oversized
  frames to a block-streaming path: raw linked or independent blocks drain
  directly, while independent and linked compressed blocks retain one encoded
  block and one decoded-block scratch. Optional compressed-block checksums are
  read and verified after releasing the encoded payload and before exposing the
  decoded scratch to caller output, so a compressed-payload-size buffer cap is
  sufficient. Complete frames still use the prevalidated direct-output path
  when possible. Frames without an embedded content size can also use
  direct output when callers provide either `expected_output_len` or
  `max_decoded_buffer_len` as the preflight cap. Frames whose Dictionary_ID
  resolves through the explicit dictionary or dictionary-set incremental
  constructors can stream dictionary-backed compressed blocks directly. Linked
  compressed drains keep a bounded 64 KiB history window, so caller output
  chunks that split frame history can continue without retaining the whole
  frame. Compressed-block output remains block-atomic internally and drains its
  block-sized scratch under caller backpressure. LZ4 skippable metadata is also
  independent of data-frame size: only its eight-byte header is retained, and the payload is
  discarded or captured incrementally under the same bounded-input API.
  Zstd native incremental decoding now
  has matching direct-output slices for raw/RLE blocks and compressed native
  blocks, including multi-block frames whose later compressed blocks reuse
  sequence tables/repeated offsets from earlier compressed blocks and frames
  whose Dictionary_ID resolves through the explicit dictionary or dictionary-set
  incremental constructors; content checksum validation runs on the direct path.
  Frames without an embedded content size can use the same direct path when
  callers provide `expected_output_len` or `max_decoded_buffer_len` as a safe
  preflight cap. The direct path keeps a bounded history window, so multi-block
  sequence matches can continue across caller output chunks. When caller output
  is too small for the next compressed block, the prevalidated direct path first
  returns existing progress as `need_output`, then switches that block to the
  same resumable sequence cursor without decoded scratch; root tests and dictionary
  probes now cover dictionary, dictionary-set, no-content-size, and multi-block
  small-output switches, while the native library bench can add focused `--path` payloads with `--limit` and the gates now keep Debug and ReleaseFast CSV rows for
  LZ4/Zstd lib/native lib-decode rows plus LZ4/Zstd lib-generated compatibility-frame/no-size/checksum/no-size+checksum/independent/full-independent and trained-dictionary library encode/decode plus cheap smoke
  coverage for no-content-size multi-compressed frames, checksum mismatch,
  truncated-checksum limit precedence, and dictionary-set skippable direct output
  plus scratch-free switching without adding CSV rows. Dictionary probes also pin
  `Dictionary_ID` error precedence for hostile Zstd frames: missing or
  mismatched dictionaries are reported as `NeedDictionary` before checksum,
  content-size, malformed raw/RLE block, or malformed compressed
  sequence-table errors; once the matching dictionary is supplied, the same
  fixtures expose the underlying `ChecksumMismatch`, `SizeMismatch`, or
  `CorruptFrame`, including incremental diagnostics for checksum, size,
  raw/RLE malformed-block, and compressed sequence-table paths. Dictionary-set
  variants now exercise the same precedence through top-level, chunked/reusable,
  and incremental APIs when skippable concatenated streams contain a later frame
  whose Dictionary_ID is absent from the set. The
  native writer can emit Dictionary_ID fields for downstream
  container metadata, omit the field for explicit raw-content dictionaries, and
  has a dictionary-aware multi-match path that can also run after the first block, so frames
  whose blocks contain preset history can be smaller than raw storage
  while remaining decodable through explicit dictionary APIs. Public helpers can
  now derive stable non-zero Dictionary_ID values from dictionary content, train
  allocator-owned deterministic native dictionaries, encode through a dictionary
  set by Dictionary_ID, validate dictionary-set catalogs for zero or duplicate
  IDs, build dictionary sets from validated metadata+bytes catalogs with either
  caller-provided scratch or allocator-owned catalog arrays, and compute
  dictionary- or dictionary-set-aware frame bounds for caller-owned output
  buffers. Seekable writers expose the same bound/into symmetry for plain,
  explicit-dictionary, and dictionary-set streams while preserving the existing
  alloc/append output byte-for-byte. Callers can inspect
  Dictionary_ID metadata before decode, and trained owned dictionaries expose a
  shared `DictionaryMetadata` summary plus fixed-size versioned metadata
  records and counted catalog records (including prefix decode for containers
  that append dictionary bytes) that can validate dictionary bytes before
  constructing borrowed codec dictionaries for caller-managed catalogs. The native writer also exposes a
  block-size option plus a bounded mixed-match search budget for library callers
  that need to trade branch-scored ratio work against encode latency, and the public native stream/block iterators expose
  zero-allocation frame, block, and skippable-frame inspection so future
  latency/ratio sweeps can share the same library API rather than relying on
  CLI-specific chunking. `run-lz4-native-dictionary-probe` and
  `run-zstd-native-dictionary-probe` exercise the public dictionary APIs,
  top-level and reusable chunked append/exact-size append decode helpers,
  public sequence-mode inspection for LL/OF/ML=FSE and repeated-table blocks, and
  direct-output small-buffer switching paths directly, while the generated-corpus probe
  accepts repeated `--path` arguments or bounded recursive `--dir` discovery
  with an optional `--limit`
  for focused file payloads when investigating real corpus failures.

High-byte literal writer note:

- The direct Huffman writer remains capped at
  `zstdNativeMaxDirectHuffmanSymbol == 128`, because Zstandard direct Huffman
  headers encode `symbol_count - 1` in one byte and cannot describe full
  `0...255` weight tables. High-byte literal-only and sequence-literal blocks now use
  FSE-compressed Huffman weights when that candidate beats raw storage.
- The high-byte path is validated through both decoders: system `zstd` and
  Vort's native Huffman literal cursor. The unit fixture now checks the parsed
  FSE Huffman tree shape for a deterministic high-byte payload, and
  `zstd_native_frame_probe` requires the same public library payload to encode
  as a compressed block rather than the old raw fallback.
- Remaining high-byte work is quality-of-implementation rather than basic
  capability: broaden real-corpus coverage for high-byte/sequence blocks, tune
  the new frequency-aware Huffman planner against real payloads, and compare the
  generated FSE weight streams against more zstd levels/corpora.

Recommended next comparison steps:

- The reference benchmark, pure-Vort decode profiler, and encode benchmark
  accept an explicit `--libzstd PATH`, so macOS/Homebrew runs no longer depend
  on dynamic-loader search paths. A 20,000-iteration survey against libzstd
  1.5.7 shows the
  raw-literal single-predefined rows already ahead by 2.88x--15.48x; the next
  decode target is therefore the 5,161-sequence raw-literal all-FSE row, which
  remains near 0.40x reference throughput, followed by other multi-sequence
  entropy-heavy rows. Treat these loaded-host numbers as prioritization
  evidence and rerun A/B measurements on an idle machine before claiming small
  changes.
  The raw-literal all-FSE target now has a dedicated large-sequence decoder.
  Final independent-binary A/B runs improve its warmed median by 1.3558x
  (15/15 wins; a separate 21-pair target run is 1.3567x with 21/21 wins) and
  its one-shot median by 1.4272x. The complete five-row control floor is
  0.9965x warmed and 0.9977x one-shot. A fixed libzstd 1.5.7 frame plus
  OutputTooSmall, mutation parity, and recovery checks pin the selected path;
  the full 9,900-frame/64-mode corpus remains green. The target is now roughly
  0.60x libzstd throughput rather than 0.40x, so further work is still needed.
  Exact kernels for the row's dominant `(length=8, offset=7)` overlapping
  copies and 23-byte non-overlapping copies now run inside an isolated text
  section. Relative to the preceding dedicated-loop commit, the final warmed
  five-row matrix improves the target by 2.0473x with a 0.9973x control floor;
  one-shot improves by 1.8825x with a 0.9987x floor. Eleven direct runs against
  libzstd 1.5.7 put this fixed row at 1.2631x median Vort/reference throughput
  with 11/11 wins. Broader FSE/Huffman and mixed-mode rows remain below the
  reference and are the next decode targets.
  The four-block `binary_mixed` path now isolates both FSE/FSE/RLE and
  FSE/RLE/RLE raw-literal loops, applies an exact 48-byte non-overlapping match
  copy to both, and removes unused table dispatch from the latter. Its dominant
  16-byte literal run is also copied exactly. Relative to `3cd5ae91`, final
  independent-binary matrices improve this row by 2.2600x warmed and 2.1749x
  one-shot, with control median floors of 0.9939x and 0.9967x. Eleven direct
  warmed comparisons against libzstd 1.5.7 measure 1.1696x median with 11/11
  wins; three long one-shot full matrices measure 1.0154x--1.0272x. This is a
  second fixed decode shape above the current reference, not broad Zstd parity.
  The zero-sequence four-stream `ascii64k` path now keeps four persistent
  64-bit reverse reservoirs and decodes five symbols per stream before a
  refill, matching upstream's register/pointer model without reading across
  stream boundaries. Dispatch occurs only after the block decoder has proved
  there are no sequences; sequence-interleaved Huffman paths retain their
  previous layout. Relative to a fresh `29734b27` ReleaseFast binary, final
  15-pair matrices improve `ascii64k` by 1.5707x warmed and 1.5732x one-shot,
  both 15/15 wins. Non-target medians remain at or above 0.9945x, and a
  separate 100,000-decode `numbered_json` control is 1.0023x. A 50,000-
  iteration same-process comparison against Homebrew libzstd 1.5.7 reaches
  982.52 MiB/s versus 1042.21 MiB/s (`0.9427x`), up from about `0.598x`.
  Reservoir oracles cover widths 1...11, all byte alignments, repeated reloads,
  checked tail reconstruction, and untouched caller-output suffix bytes.
  The one-block `numbered_json` path now recognizes its exact small-frame
  shape before entering the generic decoder: no dictionary/checksum, declared
  content at most 4 KiB, 2...256 sequences, Huffman literals, and
  LL=predefined/OF=compressed-FSE/ML=predefined (`0x20`). The isolated decoder
  constructs only the dynamic offset table and reads LL/ML from the static
  predefined tables. Relative to the independent `0f12fca6` binary, final
  15-pair one-shot matrices improve the target by 1.5524x--1.5594x with
  15/15 wins and a 0.9943x control floor; reusable rows, which intentionally
  stay on the cached generic path, retain a 0.9963x floor. A 100,000-iteration
  libzstd 1.5.7 comparison measures 449.80 versus 662.35 MiB/s (`0.6791x`),
  up from about `0.439x`. A fixed 183-byte libzstd frame compares generic and
  specialized output, terminal state, OutputTooSmall behavior, caller suffixes,
  and every single-bit mutation across the offset table and sequence stream.
  Large all-FSE/Huffman blocks with at least 1,024 sequences and no more than
  4 KiB of four-stream literals now decode those literals once into bounded
  stack scratch before executing sequences. This replaces thousands of
  interleaved one-symbol Huffman reads with the established four-stream bulk
  decoder while retaining exact output bounds and the generic fallback.
  Relative to independent `548623fe` binaries, final 21-pair target runs improve
  the locked 512 KiB `large_json` row by 1.0963x one-shot and 1.1235x reusable,
  both with 21/21 wins. Final five-row matrices measure 1.1039x/1.1353x on the
  target and retain 0.9965x/0.9972x control floors. Long `numbered_json`
  controls retain 0.9935x one-shot and 0.9971x reusable medians. A
  5,000-iteration libzstd 1.5.7 comparison measures 4429.53 versus 6639.97
  MiB/s (`0.6671x`). A fixed 2,874-byte
  single-block reference frame pins byte-exact fast/generic equivalence, a
  64-byte untouched caller suffix, OutputTooSmall, and 64 mutations each in
  the Huffman payload and sequence bitstream.
  The split-literal loop now handles its dominant one-byte literal run with one
  exact load/store instead of a dynamic-size `memmove`; the fixed fixture
  requires more than 1,000 such hits. Relative to independent `867a46aa`
  binaries, 21-pair one-shot runs improve `large_json` by another 1.0977x with
  21/21 wins. The 15-pair five-row one-shot/reusable matrices improve the
  target by 1.0919x/1.1039x; their non-target median floors are 0.9898x and
  1.0010x, and a 31-pair, 5,000-decode `binary_mixed` confirmation recovers to
  0.9950x. A final 5,000-iteration libzstd 1.5.7 run measures 4900.73 versus
  6640.37 MiB/s (`0.7380x`), so the reference floor rises from 0.55x to 0.65x.
  Multi-sequence candidate arbitration now computes the exact RLE, predefined,
  and mixed-table payload lengths first, preserves the existing RLE-first tie
  order, and emits only the selected wire instead of serializing and copying all
  three alternatives. A test-only legacy selector matches the new path byte for
  byte across the text/JSON/binary benchmark token streams, generated valid
  sequence streams, and examples selecting every winner family; allocation
  failure also leaves caller output unchanged. Against independent `f95aadac`
  and candidate binaries, 31 interleaved JSON level-1 pairs improve by 1.0455x
  median / 1.0458x geometric mean with 31/31 wins and the same 643-byte frame.
  A separate 15-pair 20-row level matrix preserves every input hash, frame size,
  reference size, and checksum while improving by 1.0182x across row medians;
  its weakest row median is 0.9982x, and binary level 1 improves by 1.0608x.
  The noisy multi-block level-3 control was repeated for 31 longer pairs and
  measures 0.9969x median / 0.9974x geometric mean, within the 1% retention
  threshold. The 100-row candidate-stage gate now also models unavailable
  stages explicitly: a zero-duration sample is accepted only when no block was
  available, while every available stage must still report positive time.
  The selected multi-sequence writer now appends transactionally into caller
  output after reserving the exact encoded size, eliminating the final temporary
  block allocation and copy. The predefined-winner allocation oracle drops from
  6 calls / 882 requested bytes to 4 / 580 while preserving exact output and
  rollback under every injected allocation failure. Against independent
  `77f141e7` and direct-output binaries, a 21-pair 20-row matrix preserves every
  input hash, frame/reference size, and checksum; row-median geometric throughput
  is 1.0033x with a 0.9987x floor. The longer target/control checks measure
  0.9994x for JSON level 1, 1.0019x for text level 1, and 1.0077x for binary
  level 1, so the retained claim is lower allocation/copy traffic rather than a
  broad latency win.
  Reverse sequence-bitstream emission now walks the existing read-order fields
  backwards directly instead of copying as many as 3,072 `BitField` records
  into a second roughly 48 KiB stack array. A scalar reference oracle covers
  empty through maximum-length field lists, mixed zero-to-15-bit widths,
  invalid zero/oversized widths, and one-over-limit input. Against independent
  `49cc7607` and candidate binaries, 31 interleaved JSON level-1 pairs improve
  by 1.0401x median / 1.0405x geometric mean with 31/31 wins and the same
  643-byte frame. A separate 21-pair 20-row matrix preserves every input hash,
  frame/reference size, and checksum, improves by 1.0149x across row medians,
  and keeps a 0.9965x weakest median; binary level 1 and multi-block level 3
  improve by 1.0299x and 1.0260x.
  A follow-up direct sequence-plan writer for the 450--512-sequence borrowed
  path was rejected. It removed the remaining read-order `BitField` array and
  emitted transitions, extras, and initial states directly in reverse order; a
  byte-exact oracle covered 450/512 sequences with predefined, compressed,
  mixed Repeat_Mode, malformed-length, and allocation-failure cases. Against
  the frozen reverse-field binary, 31-pair JSON/binary level-1 runs measured
  only 0.9989x/0.9929x, and the 21-pair 20-row matrix reached 0.9997x across
  row medians with a 0.9874x text level-1 floor. All input hashes, frame and
  reference sizes, and checksums matched, but the implementation was removed
  because eliminating the stack array did not improve end-to-end throughput.
  A capped-match continuation experiment was rejected for the same evidence
  standard. Reusing the 257-byte prefix proved by the preceding 258-byte
  single-state match improved the synthetic repetitive-text stage by 2.8275x
  with 31/31 wins, but real README/source prefixes gained only 1.004x--1.019x
  and had no additional capped reuse. The complete JSON level-1 encoder
  regressed to 0.9913x (a narrower formulation reached 0.9883x), despite exact
  token, frame, input-hash, and checksum parity, so no production change is
  retained.
  Level-1 blocks with a precomputed absolute-decisive beam now serialize that
  inevitable candidate first, then run the unchanged greedy parser and use the
  existing conservative literal-Huffman plus LL/ML/OF extra-bit lower bound.
  Only a bound strictly larger than the beam skips greedy entropy emission; an
  equal bound still emits greedy and preserves its historical tie priority. A
  32-shape old/new selector oracle covers both pruned and fallback paths
  byte-exactly; exhaustive allocation-failure
  injection preserves the caller prefix, and the locked 32 KiB JSON case drops
  from 60 to 44 allocations and by 8,741 cumulatively requested bytes. Against
  independent `46198919`/`ca8c7785` ReleaseFast binaries, 31 interleaved
  100-encode JSON level-1 pairs improve by 1.1586x median / 1.1614x geometric
  mean with 31/31 wins and the same 643-byte frame. A 21-pair 20-row matrix
  preserves every input hash, frame/reference size, and checksum, reaches
  1.0100x across row medians, and keeps a 0.9895x short-sample floor. Longer
  controls recover JSON level 3 to 0.9912x and tradeoff level 9 to 1.0042x.
  A cheaper precheck for that greedy lower bound was evaluated and removed. It
  used the integer Shannon floor `sum(freq * floor(log2(total / freq)))`, which
  an independent 2--256-symbol oracle proved never exceeded the selected
  11-bit Huffman payload cost, and it was already strong enough to reject the
  locked JSON candidate. Nevertheless, 31 independent level-1 pairs improved
  by only 1.0054x, below the retention threshold, so the exact Huffman lower
  bound remains the only production proof.
  The same precomputed level-1 beam now also delays the roughly 384 KiB paired
  duplicate index. A direct bounded scan first mirrors the existing indexed
  `CannotBeat` proof: it rejects high-byte input, derives the shortest match
  that could still beat both the beam and the historical 1/256 early-return
  threshold, and compares only that prefix for paired eight-byte hashes. The
  index is built unchanged whenever the proof is inconclusive. Passing
  `max(beam_len, block_len / 256) + 1` preserves both equal-length tie order and
  the old early single return. A 32-shape indexed/direct oracle covers six
  limits per shape; the complete selector oracle covers proof hits, ordinary
  and high-byte fallbacks, byte-exact old/new wire, and allocation-failure
  rollback. Against independent `ca8c7785`/`7100fb34` ReleaseFast binaries, 31
  interleaved 100-encode JSON level-1 pairs improve by 1.1001x median / 1.0999x
  geometric mean with 31/31 wins and the same 643-byte frame. A 15-pair 20-row
  matrix preserves every input hash, frame/reference size, and checksum,
  reaches 1.0043x across row medians, and has a noisy 0.9877x short-row floor.
  Longer controls recover tradeoff level 3 to 1.0019x and text level 9 to
  1.0049x. An earlier exact-Huffman direct proof was rejected before this
  version: although correct, it reduced the target to 0.9329x with 0/15 wins
  because full match extension and tree construction cost more than the index
  it replaced.
  Absolute-beam selection now also skips the later repeated-pattern entropy
  candidate when a conservative literal lower bound cannot beat the selected
  beam. The preceding direct single-match proof retains the whole-block maximum
  byte frequency in reusable scratch. After greedy is independently proved
  worse, repeated-pattern discovery computes the minimum regenerated-literal
  count across its single- and multi-sequence forms. If that count exceeds the
  maximum frequency, at least two symbols remain, so one bit per literal plus
  the three-byte block header is a safe lower bound. Equality is pruned because
  repeated-pattern candidates historically run after the current winner. The
  proof never participates in the stronger mixed-family 24x cancellation
  decision. Generated exact-candidate checks cover 32 shapes and six limits;
  the complete selector oracle covers hits, conservative fallback, old/new wire
  equality, and allocation-failure rollback. The locked JSON path drops from 44
  allocations / 1,519,048 requested bytes to 26 / 1,283,956. Against independent
  `7100fb34`/`c2b18207` ReleaseFast binaries, 31 interleaved 100-encode JSON
  level-1 pairs improve by 1.1951x median / 1.2005x geometric mean with 31/31
  wins and the same 643-byte frame. A 15-pair 20-row matrix preserves every
  input hash, frame/reference size, and checksum, reaches 1.0134x across row
  medians, and keeps a 0.9920x floor. Longer JSON level-3 and tradeoff level-1
  controls measure 0.9933x and 0.9938x. Two narrower repeated-pattern changes
  were rejected: reusing the first segment of a failed multi-pattern scan
  improved that isolated stage by 1.0426x but reduced complete JSON level 1 to
  0.9863x, while replacing scalar extension with 32/8-byte comparisons reduced
  the isolated stage to 0.9877x because most probes fail just after the existing
  three-byte anchor. Two earlier placements of the retained proof were also
  rejected after stable 0.9787x/0.9797x tradeoff-level-1 and 0.9730x JSON-level-3
  regressions; the final one-shot scratch marker keeps non-eligible selector
  control flow unchanged.
  A 10-second, 1 ms macOS sample of the retained `c2b18207` JSON level-1
  binary collected 7,978 stacks. Inclusive attribution puts 3,675 samples
  (about 46%) in `single_beam.planReuse`, about 1,816 (23%) in the beam
  entropy path, 834 (10%) in the direct single-candidate proof, about 837
  (10%) in greedy parsing/emission, and only 110 (1.4%) in the retained
  repeated-pattern proof. This makes single-beam planning and its entropy
  scoring the next evidence-backed optimization targets; repeated discovery is
  no longer a leading whole-encoder cost.
  Two attempts to make the direct proof cheaper were measured and removed.
  Collecting a `ByteSummary` inside single-beam DP avoided the later frequency
  pass but reduced complete JSON level 1 to 0.9895x with only 3/31 wins. An
  alphabet-preservation proof replaced the 256-bin frequency scan with a
  vectorized non-RLE/low-symbol predicate and improved JSON level 1 by 1.0794x
  with 31/31 wins, but its long tradeoff level-1 control fell to 0.9833x with
  0/31 wins. Neither implementation is retained.
  The single-state beam now handles an exact adjacent indexed-match recurrence
  before entering its generic 16-link chain loop. When the newest hash entry is
  the prior match source shifted by one and that prior match ended below the
  258-byte cap, the existing proof already fixes the current length to `L-1`;
  the fast path returns the same match while preserving chain accounting and
  all deterministic tie rules. The 64-shape shifted/reference oracle records a
  real first-entry hit and keeps every token and `PlanStats` field exact. Against
  independent `c2b18207`/`b71f0ad0` ReleaseFast binaries, 31 interleaved
  500-encode JSON level-1 pairs improve by 1.0113x median / 1.0112x geometric
  mean with 31/31 wins and the same 643-byte frame. A 15-pair 20-row matrix
  preserves every input hash, frame/reference size, and checksum and reaches
  1.0036x across row medians. Its noisy 0.9863x/0.9861x text level-1/9 rows
  recover to 0.9960x/0.9917x in separate 31-pair, 5,000-encode controls.
  Multi-sequence winner selection now reuses the exact all-predefined payload
  cost already computed while constructing the mixed RLE/predefined/FSE table
  alternatives. Previously the winner path ran three independent predefined
  DPs, then the mixed-table planner immediately rebuilt the same LL/OF/ML
  plans. The mixed planner now returns the all-predefined cost without changing
  its candidate set; winner comparison remains RLE first, predefined second,
  mixed tables third, and a predefined winner still uses the established
  emitter. The exact-length oracle compares the reused result with the old
  scorer, while generated winner-only/reference checks retain every output
  byte. Against independent `b71f0ad0`/`7405d1b6` binaries, 15 interleaved
  500-encode JSON level-1 pairs improve by 1.0584x median / 1.0581x geometric
  mean with 15/15 wins and the same 643-byte frame. A 15-pair 20-row matrix
  preserves every input hash, frame/reference size, and checksum, reaches
  1.0220x across row medians, and keeps a 0.9957x floor. The weakest multi-block
  level-1 row recovers to 1.0011x over 31 longer pairs. A matching 10-second,
  1 ms post-change sample reduces `planPredefinedSequenceValues` self samples
  from 371 to 203, confirming that the measured gain tracks the removed DP work.
  The direct single-dominance proof now builds its exact 256-symbol frequency
  summary through four interleaved `u16` lanes. Every lane sees at most 16,384
  bytes under the existing 65,535-byte block limit; a final 256-symbol fold
  therefore reconstructs the original counts and maximum exactly while breaking
  the dependency chain for repeated hot bytes. Existing direct/indexed, selector
  wire, repeated-prune, and OOM oracles keep proof decisions and output exact.
  Against independent `7405d1b6`/`f8d4d069` binaries, 15 interleaved 500-encode
  JSON level-1 pairs improve by 1.0320x median / 1.0307x geometric mean with
  15/15 wins and the same 643-byte frame. A 15-pair 20-row matrix preserves
  every input hash, frame/reference size, and checksum, reaches 1.0030x across
  row medians, and keeps a 0.9953x floor. The weakest tradeoff level-3 row
  recovers to 1.0100x over 31 longer pairs. Three nearby experiments were
  removed: a known-valid direct-offset scorer improved JSON only 1.0023x;
  reconstructing small FSE decode entries from the inverse compression table
  improved JSON 1.0149x but reduced the complete matrix to 0.9992x with a
  0.9732x text floor; and a 32-bucket frequency precheck reduced JSON to
  0.9922x because its extra pass cost more than the avoided wide histogram.
  A follow-up 1 kHz `samply` profile retained per-PC leaf addresses for the
  stripped ReleaseFast binary and localized most remaining `single_beam.planReuse`
  samples to literal target insertion plus indexed/rep0 short-match state
  arbitration; allocator growth, backtracking, and the separate match extender
  are secondary. Two semantics-preserving layout experiments were removed. A
  likely-empty literal insertion branch used the measured 30,619/32,797 empty
  JSON targets but reduced complete JSON level 1 to 0.9900x with 0/15 wins.
  Deferring each literal candidate to the next position preserved all 17
  single-state token/profile/tie/OOM tests, but extending the live state and
  adding the merge reduced JSON level 1 to 0.9754x. Production keeps the
  compiler-selected shared insertion layout; the next viable beam change needs
  to reduce successful indexed/rep0 state work rather than only rearrange it.
  Expanding the retained exact dominance histogram from four to eight lanes was
  also rejected at 0.9986x JSON level 1 with 6/15 wins. Four lanes remain the
  measured balance between independent hot-byte updates and the final 256-symbol
  fold.
  A fresh 10-second sample after the striped proof measures 3,973 of roughly
  7,900 stacks in `single_beam.planReuse`, 619 in the direct proof, 514 in
  offset resolution, 284 in greedy parsing, and 263 in the separate match
  extender. The finite-run `samply` PC map confirms literal target arbitration,
  hash-head updates, and indexed/rep0 short-match insertion as the beam's core.
  Moving the shifted-match lower-bound check into the finder preserved all 17
  single-state token/profile/tie/OOM tests but reduced JSON level 1 to 0.9938x.
  It was removed; carrying extra state across that finder boundary costs more
  than the skipped insertion work.
  Sequence bitstream emission now traverses the existing read-order fields in
  reverse directly instead of copying as many as 3,072 `BitField` records into
  a second roughly 48 KiB stack array first. A scalar reference oracle covers
  empty through maximum-length field lists, mixed zero-to-15-bit widths, invalid
  zero-width values, oversized widths, and one-over-limit input. Against frozen
  `49cc7607` and candidate binaries, 31 interleaved JSON level-1 pairs improve
  by 1.0401x median / 1.0405x geometric mean with 31/31 wins and the same
  643-byte frame. A separate 21-pair 20-row matrix preserves all input hashes,
  frame/reference sizes, and checksums, improves by 1.0149x across row medians,
  and keeps a 0.9965x weakest median; binary level 1 and multi-block level 3
  improve by 1.0299x and 1.0260x.

- Native hash-parser blocks are no longer discarded at the historical 512-sequence
  implementation limit. Blocks above that small-stack threshold use bounded
  allocator-backed metadata, FSE/predefined-state, and reverse-bitstream scratch up
  to the format-derived 128 KiB/minimum-match ceiling of 43,690 sequences; the
  existing `<=512` path and wire output remain unchanged. On the first 128 KiB
  of local Silesia `ooffice`, `nci`, `mozilla`, `dickens`, and `xml`, all 20
  double-fast/greedy/lazy/optimal candidates now emit instead of returning
  unavailable. The preceding predefined-only slice produced selected one-block
  frames of 75,660/12,946/26,689/62,228/11,450 bytes and decoded byte-exactly
  through both Vort and the system zstd CLI. A
  generated 513-sequence boundary, the three-byte 32,512-sequence count tier,
  planner equivalence, and exhaustive allocation-failure rollback are pinned by
  unit tests. Wide non-terminal blocks now commit their selected FSE tables and
  repcode ring transactionally; following wide blocks use a scratch-backed
  reachability DP to price Repeat_Mode exactly against fresh
  RLE/predefined/compressed-FSE tables. The 513-sequence two-block regression
  selects LL=Repeat, OF=RLE, and ML=Repeat in block two, covering both compressed
  and RLE table reuse after the offset ring changes.
  `run-zstd-large-sequence-probe` also pins deterministic 128 KiB single-block
  and 256 KiB two-wide-block public-library frames through both Vort and runtime
  libzstd; the latter is 69,882 bytes with 2,044 sequences in each block and
  selects ML=Repeat in block two. The native stage gate retains a matching
  primary/double-fast row. Fixed-CPU interleaved level-1 measurements versus the previous
  commit show a deliberate ratio/latency tradeoff: sizes fall by roughly
  9%--86%, while the slower `ooffice`/`dickens` cases run at about 0.77x/0.83x
  baseline and the other three improve because their previously ineffective
  primary candidates avoid expensive fallback work. Large-path compressed-FSE
  planning now uses scratch-backed RLE/predefined/compressed-FSE alternatives
  without inflating fixed stack plans. On the deterministic probe, selecting
  LL=FSE, OF=FSE, and ML=RLE reduces the double-fast block from 39,598 to
  33,754 bytes (14.8%) and the selected frame from 39,303 to 35,046 bytes
  (10.8%). Multi-block frames now evaluate previous LL/OF/ML
  tables as exact Repeat_Mode candidates, carry the repcode ring across accepted
  blocks, preserve both across zero-sequence blocks, and seed them from standard
  dictionaries. The locked 129 KiB benchmark shrinks from
  28,328/28,328/27,758 bytes at levels 1/2/3 to 27,863/27,863/27,517; level 9
  shrinks from 27,455 to 27,363. The level-1/3 decisive-wide path now feeds the
  current frame tables and repcodes directly into its agreed hash parse instead
  of encoding with initial state and then decoding/re-emitting the candidate. A
  513-sequence allocation oracle records 16 fewer allocations and 237,173 fewer
  cumulatively requested bytes with byte-identical output. The runtime probe also
  covers this production path with a 15,517-byte two-block frame whose disjoint
  byte alphabets exclude cross-block history matches; each 33 KiB block contains
  526 sequences and the second selects LL/ML=Repeat plus OF=RLE. Strict ratio
  levels and non-decisive fallback candidates retain complete legacy arbitration;
  avoiding their decode/re-encode preparation cost and running a fresh multi-file
  corpus pass remain follow-up work. Wide Repeat_Mode reachability scratch is
  also sized from the largest actual previous LL/OF/ML table instead of the
  format-wide 512-state ceiling. The common 128-state case uses two rather than
  eight `u64` words per sequence, reducing that buffer by 75%; tests cover
  64/128/256/512-state boundaries without changing the selected state path.
  One-shot frame assembly now keeps one `LargeSequenceScratch` across candidate
  emission and frame-state rewriting, while `NativeFrameEncoder` retains it
  across calls. On the two-33-KiB wide fixture this removes 13 allocations and
  76,482 cumulatively requested bytes inside one frame; a warmed reusable
  encoder removes a further 18 allocations on its next byte-identical call.
  Injected OOM followed by successful reuse and final allocation balance cover
  the new ownership path; the generic incremental encoder keeps its allocation-free
  state layout and continues to use block-local scratch.

- The runtime `run-zstd-compat-probe` matrix now includes compression level 22,
  four real source-file rows when the local zstd checkout is available, 15
  advanced parameter frames (content-size/checksum flags, window logs 10/21,
  long-distance matching, and all nine standard strategies), four unknown-size
  streaming/flush frames, four upstream golden-decompression frames, and three
  upstream golden error frames rejected through both size preflight and decode.
  The optional upstream files are read from `~/Work`-relative paths and do not
  make clean checkouts depend on those repositories. The current local run
  covers 246 cases with zero unsupported frames against libzstd 1.5.5; this is
  stronger compatibility evidence, but not proof of arbitrary-frame parity.
  Follow-up explicit-sequence cases use the exported libzstd sequence API to
  emit 32,511, 32,512, and the practical 128 KiB-block maximum of 43,690
  three-byte matches, plus deterministic varied literal/match/offset streams at
  127/128/129/1,024/8,192 sequences. This raises the local matrix to 255 cases,
  pins all one-/two-/three-byte sequence-count encodings
  (`sequence_count_tiers=0x7`), and expands the observed LL/OF/ML mode tuples to
  25 without relying on match-finder heuristics.
  Dictionary-aware block inspection now has single-dictionary and dictionary-set
  entry points. They seed Huffman/FSE/repcodes from standard full dictionaries
  before replaying preceding blocks, so a first-block Repeat_Mode frame can be
  inspected rather than being misclassified as corrupt. A fixed 256-byte
  libzstd-trained dictionary plus 702-byte frame pins a 57-sequence all-Repeat
  block, correct/wrong/missing dictionary behavior, and decoded CRC. The runtime
  matrix additionally trains 256/1,024/4,096-byte dictionaries and decodes level
  1/9/19 single- and multi-block payloads through size, allocating, caller-owned,
  single-dictionary, and dictionary-set paths, bringing the local matrix to 273
  cases. The compatibility probe accepts `--libzstd PATH`, bypassing dynamic
  loader search order for reproducible cross-version checks. The same 273-case
  matrix passes with zero unsupported frames against both the system libzstd
  1.5.5 and an explicitly built `~/Work/zstd` libzstd 1.6.0 at commit
  `5233c58e`.
  The same probe optionally consumes paired directories emitted by upstream
  zstd's `tests/decodecorpus`. Seeds 17 and 919 covered 200 and 1,000
  dictionary-free random frames; seeds 2,027, 4,242, 31,337, and 65,521 covered
  200, 1,000, 1,000, and 2,000 random dictionary-backed frames with 64 KiB,
  1 MiB, 64 KiB, and 256 KiB dictionaries. Three focused campaigns add 2,000
  forced RLE frames with content size, 2,000 raw frames with blocks capped at
  eight bytes, and 500 compressed frames with blocks capped at 16 bytes, for
  9,900 total byte-exact frames. Their corpus-only cumulative observed
  sequence-mode mask is `0xffffffffffffffff`,
  covering all 64 LL/OF/ML mode tuples; seed 17's first frame also exposed and
  now pins legal zero-length RLE blocks, including their required one-byte
  payload. `run-zstd-decodecorpus-gate` reproduces all nine campaigns directly
  from upstream `tests/decodecorpus`, carries the observed mode mask between
  runs, requires the final 64/64 mask, and deletes each temporary corpus before
  moving to the next one. Its self-contained smoke step validates argument
  orchestration, summary parsing, failure propagation, and cleanup without
  requiring the optional upstream checkout. The compatibility probe reports
  separate `decodecorpus_*` coverage fields so fixed built-in cases cannot
  inflate the upstream corpus's mode mask. It also records the explicitly loaded
  reference-library path and `ZSTD_versionString`, and rejects a version change
  between campaigns. Every generated frame is now also
  decoded incrementally with a 128 KiB-plus-header compressed-input limit. All
  9,900 pass; 2,699 frames from the broad/dictionary campaigns exercise block
  streaming after including direct-path small-output switches.
  The 5,700 dictionary-free frames additionally pass twice through one reusable
  NativeFrameDecoder per campaign, with different output poison bytes before
  each decode. This checks table replacement between frames as well as warm
  decoding within a frame. The probe reports reusable case and exact-table-hit
  counts separately; the gate requires every eligible frame and nonzero hits
  for compressed campaigns. Dictionary APIs currently bypass this cache and
  must report zero reusable coverage. The public diagnostic
  reusableSequenceTableHitCount counts description matches over the decoder's
  lifetime, including matches before a later decode error; it does not certify
  successful frames. Focused tests compare warmed decoding against the stateless
  path for every nonempty truncated prefix and every single-bit mutation of a
  sequence bitstream, then require a successful complete-frame decode.
  Sequence-free raw/RLE/Huffman literal sections inside compressed blocks now
  retain a persistent literal/Huffman cursor and write directly into tiny caller
  buffers without `decoded_scratch`; the broad suite exercises 197 such blocks
  after including complete-frame direct-path switches.
  On the bounded block-stream path, sequence-bearing compressed blocks now also
  retain their reverse-bitstream/FSE cursor, repeated offsets, Huffman cursor,
  and pending literal/match lengths across `step()` calls. Matches read from the
  bounded rolling history plus the current caller slice, so even one-byte output
  slices need no decoded-block scratch. The broad/dictionary campaigns exercise 76,578
  of these blocks across all 64 LL/OF/ML mode tuples, dictionaries up to 1 MiB,
  and blocks with up to 43,690
  sequences; its streamed decoded-scratch length and capacity peaks are both
  zero.
  Complete frames that were prevalidated for direct output now switch in place
  to the same cursor when caller output cannot hold the next compressed block.
  The switch preserves earlier block history, sequence tables, checksum state,
  and the already-known frame boundary, removing the old full-frame decoded
  scratch fallback without slowing the large-output direct path.
  Skippable-frame payloads now follow a separate incremental state after their
  eight-byte header. They are discarded or copied into caller-owned capture
  storage directly from input, so metadata size no longer counts against
  `max_compressed_buffer_len`; completion statistics and events remain atomic,
  truncated payloads still report `TruncatedFrame` in the public `frame` phase,
  and a limit below eight bytes still reports `OutputLimitExceeded`. A 4 KiB
  metadata fixture under a 16-byte cap also verifies bounded scratch, partial
  capture, and continuation into the following data frame.

1. The new opt-in `run-zstd-reference-bench-gate` now provides same-process
   caller-owned decode rows against runtime libzstd. Optimize the locked raw-
   literal/single-predefined-sequence shape before broadening levels/corpora.
2. Add library-level range-latency rows for the public seekability tiers
   (`seek_fast` 8 KiB, `balanced` 32 KiB, and `ratio` 64 KiB), because even the
   ReleaseFast tier sweep still measures through the CLI bench surface.
3. Expand the standard-corpus comparison beyond the first three bounded rows and
   expand the ReleaseFast artifact beyond the local Silesia-small bounded set once stable.
4. Split compatibility-format goals (raw/zlib/gzip deflate behavior) from native
   Vort goals; fixed deflate can be near zstd on small text while still being the
   wrong benchmark for the long-term native-format target.
