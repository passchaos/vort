# zstd comparison gap

`zig build run-zstd-compare` reports zstd CLI size beside Vort's current raw
fixed-deflate output on sample project files. This is a smoke comparison, not a
performance claim.

Current interpretation:

- zstd is available locally and produces smaller output on documentation files.
- Vort's current fixed-Huffman encoder is a compatibility/bootstrap encoder, not
  the native format that is expected to compete with zstd.
- The gap remains open until Vort has native entropy modes, dictionary training,
  long-distance matching integration, real-corpus throughput/ratio dashboards,
  and same-machine comparisons against zstd.
