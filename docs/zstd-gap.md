# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output on sample project files. This is a smoke comparison, not a
performance claim: it uses documentation/source-like inputs, zstd level 1 via
the local CLI, and the Vort debug-built CLI's raw fixed-Huffman encoder. The
build step now retains `zig-out/vort-zstd-compare.csv` and
`zig-out/vort-zstd-compare.md` so the size smoke can be linked from dashboard
indexes instead of only appearing on stdout. The retained CSV/Markdown include
per-input rows plus a `TOTAL` aggregate row for the overall size ratio and
median-of-3 process-level decode throughput. `zig build
run-zstd-compare-gate` validates the retained artifacts plus writes
`zig-out/vort-zstd-compare-gate.json`.

Example local Debug smoke after adding the median-of-3 decode rows
(2026-07-21; process-level timings are intentionally treated as noisy smoke
evidence):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,zstd_decode_ms,vort_raw_fixed_decode_ms
/home/passchaos/project-z/vort/README.md,25830,6161,6256,1.118,9.227
/home/passchaos/project-z/vort/docs/roadmap.md,130331,37866,39091,1.411,8.564
TOTAL: zstd decode 58.88 MiB/s, Vort raw fixed decode 8.37 MiB/s, Vort/zstd 0.142x
```

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
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
