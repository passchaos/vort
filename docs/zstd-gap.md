# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output and a native embedded-index stream on sample project
files. `zig build run-zstd-compare-standard-gate` runs the same comparison over
standard corpus discovery, bounded to the first three 128 KiB cases by default.
`zig build run-zstd-compare-standard-releasefast-gate` retains the same
comparison through a ReleaseFast Vort CLI over the first twelve bounded standard
rows (the full local Silesia-small bounded set when available) for
performance-oriented smoke evidence; it is intentionally opt-in because
compiling the extra ReleaseFast CLI
is much more expensive than the Debug CI smoke. This is a smoke comparison, not
a performance claim: it uses zstd level 1 via the local CLI and debug-built Vort
CLI paths unless the ReleaseFast step is selected. The build steps retain
`zig-out/vort-zstd-compare.csv` / `.md` and
`zig-out/vort-zstd-compare-standard.csv` / `.md`, plus opt-in
`zig-out/vort-zstd-compare-standard-releasefast.csv` / `.md`, so the size smoke
can be linked from dashboard indexes instead of only appearing on stdout. The
retained CSV/Markdown include per-input rows plus a `TOTAL` aggregate row for
raw fixed and native embedded size ratios, native block length, and median-of-3
decode throughput. The zstd decode rows still include process/stdout plumbing,
while Vort raw/native rows now use CLI-internal decode loops divided by the
repeat count after a one-shot output check. The three gate steps validate the retained
artifacts and write matching `*-gate.json` summaries.

Example local Debug default-sample size smoke after adding native embedded rows
(2026-07-21; decode columns are retained in CSV/Markdown but are still
intentionally treated as smoke evidence):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_embedded_bytes
/home/passchaos/project-z/vort/README.md,25871,6167,6263,6484
/home/passchaos/project-z/vort/docs/roadmap.md,130331,37866,39091,44831
TOTAL: raw/zstd 1.030x, native-embedded/zstd 1.165x
```

Example local Debug standard-suite smoke (`--standard-suite --limit 3`, bounded
128 KiB rows from the discovered Silesia tar):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_embedded_bytes
silesia-small.tar:silesia-small/ooffice-128k,131072,76985,74575,75004
silesia-small.tar:silesia-small/nci-128k,131072,11129,15154,19875
silesia-small.tar:silesia-small/mozilla-128k,131072,21823,25437,29670
TOTAL: raw/zstd 1.048x, native-embedded/zstd 1.133x
```

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
- The native embedded rows prove the comparison artifacts now include a native
  Vort stream on both project-file and standard-corpus inputs, but the current
  embedded-index frame is still a validation/seek surface rather than a final
  zstd-class native entropy format.
- The current smoke says Vort fixed-deflate is close on these two text files
  (`~1.5%` larger on `README.md`, `~3.2%` larger on `docs/roadmap.md`), but it
  now times Vort decode inside one CLI process, but zstd decode still includes
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
