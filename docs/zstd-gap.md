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
can be linked from dashboard indexes instead of only appearing on stdout. The
retained CSV/Markdown include per-input rows plus a `TOTAL` aggregate row for
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
  The current embedded-index frame is still a validation/seek surface rather than
  a final zstd-class native entropy format.
- The current smoke says Vort fixed-deflate is close on these two text files
  (`~1.5%` larger on `README.md`, `~3.2%` larger on `docs/roadmap.md`), but it
  now times Vort decode inside one CLI process; zstd decode still includes
  process/stdout overhead and the result remains a smoke signal. It still does
  **not** measure library-level decompression speed, memory use, full binary
  corpora, or zstd's higher compression levels.
- The gap remains open until Vort has a native frame entropy mode, dictionary
  training integrated with the native format, long-distance matching in the
  encoder/decoder pipeline, corpus throughput/ratio dashboards, and repeatable
  same-machine comparisons against zstd CLI/library modes.

Recommended next comparison steps:

1. Add library-level decode throughput rows for zstd and Vort native/zlib/raw
   modes rather than CLI smoke timings.
2. Expand the standard-corpus comparison beyond the first three bounded rows and
   expand the ReleaseFast artifact beyond the local Silesia-small bounded set once stable.
3. Split compatibility-format goals (raw/zlib/gzip deflate behavior) from native
   Vort goals; fixed deflate can be near zstd on small text while still being the
   wrong benchmark for the long-term native-format target.
