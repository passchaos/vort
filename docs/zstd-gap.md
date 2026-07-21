# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output and a native embedded-index stream on sample project
files. This is a smoke comparison, not a performance claim: it uses
documentation/source-like inputs, zstd level 1 via the local CLI, and debug-built
Vort CLI paths. The build step now retains `zig-out/vort-zstd-compare.csv` and
`zig-out/vort-zstd-compare.md` so the size smoke can be linked from dashboard
indexes instead of only appearing on stdout. The retained CSV/Markdown include
per-input rows plus a `TOTAL` aggregate row for raw fixed and native embedded
size ratios, native block length, and median-of-3 process-level decode
throughput. `zig build run-zstd-compare-gate` validates the retained artifacts
plus writes `zig-out/vort-zstd-compare-gate.json`.

Example local Debug size smoke after adding native embedded rows (2026-07-21;
process-level decode columns are retained in CSV/Markdown but are intentionally
treated as noisy smoke evidence):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_embedded_bytes
/home/passchaos/project-z/vort/README.md,25830,6161,6256,6444
/home/passchaos/project-z/vort/docs/roadmap.md,130331,37866,39091,44831
TOTAL: raw/zstd 1.030x, native-embedded/zstd 1.165x
```

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
- The native embedded row proves the comparison artifact now includes a native
  Vort stream, but the current embedded-index frame is still a validation/seek
  surface rather than a final zstd-class native entropy format.
- The current smoke says Vort fixed-deflate is close on these two text files
  (`~1.5%` larger on `README.md`, `~3.2%` larger on `docs/roadmap.md`), but it
  only measures decompression as a process-level smoke that includes CLI startup
  and temporary-file/stdout overhead. It still does **not** measure library-level
  decompression speed, memory use, binary corpora, or zstd's higher compression
  levels.
- The gap remains open until Vort has a native frame entropy mode, dictionary
  training integrated with the native format, long-distance matching in the
  encoder/decoder pipeline, corpus throughput/ratio dashboards, and repeatable
  same-machine comparisons against zstd CLI/library modes.

Recommended next comparison steps:

1. Add library-level decode throughput rows for zstd and Vort native/zlib/raw
   modes rather than only process-level CLI smoke timings.
2. Run the comparison over the standard corpus discovery used by
   `run-standard-multi-corpus-dashboard`, not only README/roadmap text files.
3. Split compatibility-format goals (raw/zlib/gzip deflate behavior) from native
   Vort goals; fixed deflate can be near zstd on small text while still being the
   wrong benchmark for the long-term native-format target.
