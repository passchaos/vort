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
- The compatibility decoder now covers single-stream and four-stream
  Huffman-literals sections, can reuse that tree for treeless repeat-literals
  blocks, and decodes FSE-compressed sequence tables for the currently supported
  sequence execution path. The broader gap remains open until Vort has
  a native frame entropy mode, dictionary training integrated with the native
  format, long-distance matching in the encoder/decoder pipeline, corpus
  throughput/ratio dashboards, and repeatable same-machine comparisons against
  zstd CLI/library modes.
- `zig build run-zstd-native-probe` now complements the black-box CLI smoke with
  a bounded generated-corpus differential probe over multiple zstd levels and
  data shapes, keeping previously discovered Huffman/FSE/repeat-offset bug
  classes visible without requiring a full external corpus checkout. It also
  validates Vort's dependency-free native encoder on the same generated/file
  byte payloads through `encode-zstd-native-bytes-hex` in `auto`, `raw_or_rle`,
  and `literal_only` modes, including both 4-divisible and non-4-divisible
  four-stream Huffman literal payloads, long-period and long-prefix
  repeated-pattern writer cases, a small-depth hash-chain duplicate-candidate writer case,
  raw-block-cost-aware sequence selection, plus a file-backed multi-block
  treeless Huffman writer case, then checks
  both system zstd decode and Vort native decode, with `size-zstd-native-hex`
  preflight checked before each native decode. The native decoder accepts
  zero-valued Dictionary_ID fields without requiring a dictionary while still
  returning `NeedDictionary` for non-zero IDs unless callers provide a matching
  `NativeDictionary`; dictionary-aware alloc/append/into/scratch/size APIs now
  validate the ID and can use the preset bytes as match history for the native
  sequence subset. The native writer can emit Dictionary_ID fields for downstream
  container metadata and has a dictionary-aware multi-match path for first blocks, so frames
  whose first block contains preset history can be smaller than raw storage
  while remaining decodable through explicit dictionary APIs. Callers can inspect
  Dictionary_ID metadata before decode. The native writer also exposes a
  block-size option, and the public native stream/block iterators expose
  zero-allocation frame, block, and skippable-frame inspection so future
  latency/ratio sweeps can share the same library API rather than relying on
  CLI-specific chunking. `run-zstd-native-dictionary-probe` exercises the public
  dictionary APIs directly, while the generated-corpus probe accepts repeated `--path`
  arguments or bounded recursive `--dir` discovery with an optional `--limit`
  for focused file payloads when investigating real corpus failures.

Recommended next comparison steps:

1. Add library-level decode throughput rows for zstd and Vort native/zlib/raw
   modes rather than CLI smoke timings.
2. Add library-level range-latency rows for the public seekability tiers
   (`seek_fast` 8 KiB, `balanced` 32 KiB, and `ratio` 64 KiB), because even the
   ReleaseFast tier sweep still measures through the CLI bench surface.
3. Expand the standard-corpus comparison beyond the first three bounded rows and
   expand the ReleaseFast artifact beyond the local Silesia-small bounded set once stable.
4. Split compatibility-format goals (raw/zlib/gzip deflate behavior) from native
   Vort goals; fixed deflate can be near zstd on small text while still being the
   wrong benchmark for the long-term native-format target.
