# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output on sample project files. This is a smoke comparison, not a
performance claim: it uses documentation/source-like inputs, zstd level 1 via
the local CLI, and the Vort debug-built CLI's raw fixed-Huffman encoder. The
build step now retains `zig-out/vort-zstd-compare.csv` and
`zig-out/vort-zstd-compare.md` so the size smoke can be linked from dashboard
indexes instead of only appearing on stdout.

Latest local smoke (2026-07-21):

```text
path,input_bytes,zstd_bytes,vort_raw_fixed_bytes
/home/passchaos/project-z/vort/README.md,25825,6162,6253
/home/passchaos/project-z/vort/docs/roadmap.md,130331,37866,39091
```

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
- The current smoke says Vort fixed-deflate is close on these two text files
  (`~1.5%` larger on `README.md`, `~3.2%` larger on `docs/roadmap.md`), but it
  does **not** measure decompression speed, memory use, binary corpora, or zstd's
  higher compression levels.
- The gap remains open until Vort has a native frame entropy mode, dictionary
  training integrated with the native format, long-distance matching in the
  encoder/decoder pipeline, corpus throughput/ratio dashboards, and repeatable
  same-machine comparisons against zstd CLI/library modes.

Recommended next comparison steps:

1. Extend `run-zstd-compare` metadata with the Vort commit, Zig version, CPU
   model, and target optimization mode.
2. Add decode throughput rows for zstd and Vort native/zlib/raw modes rather
   than size-only output.
3. Run the comparison over the standard corpus discovery used by
   `run-standard-multi-corpus-dashboard`, not only README/roadmap text files.
4. Split compatibility-format goals (raw/zlib/gzip deflate behavior) from native
   Vort goals; fixed deflate can be near zstd on small text while still being the
   wrong benchmark for the long-term native-format target.
