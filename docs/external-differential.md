# External differential validation

Vort currently has black-box differential smoke coverage against Python `zlib`
and the system `gzip` CLI.

```sh
zig build run-checksum-zlib-diff
zig build run-python-zlib-diff
zig build run-gzip-cli-diff
zig build run-rust-deflate-diff
zig build -Doptimize=ReleaseFast ci-smoke
```

The checksum zlib-family smoke checks Vort's CLI checksum output against Python
zlib, then verifies Python zlib Adler-32 trailers and system gzip CRC-32
trailers. The `ci-smoke` aggregate includes that checksum harness, the Python
zlib and gzip CLI deflate/gzip harnesses, match-heavy dynamic/split/adaptive
payloads, split-best gzip output checks against system `gzip -dc`, optional
zlib-ng/zlib-rs family coverage, fdeflate/miniz_oxide source-checkout
differential smoke, the external-tool probe, fuzz smoke entrypoints, and bounded
benchmark reports.

The optional zlib-family harness detects locally built zlib-ng/zlib-rs minigzip
binaries and reports explicit skip status when they are not available:

```sh
zig build run-zlib-family-diff
```

If competitor binaries are not built, output is explicit about skipped coverage. After building zlib-ng `minigzip` in `~/Work/zlib-ng/build`, expected output includes zlib-ng coverage:

```text
zlib family differential harness:
- zlib-ng-minigzip: ok (/home/passchaos/Work/zlib-ng/build/minigzip)
- zlib-rs-minigzip: skipped (binary not built)
zlib family differential summary: used=1 skipped=1
```

To turn this into real coverage, build compatible `minigzip`-style binaries or the zlib-rs `compress` example in
one of the paths listed in `tools/zlib_family_diff.py`, then rerun the build
step. Skip output must not be counted as compatibility evidence for that implementation.

The hosted GitHub Actions smoke workflow builds the zlib-rs `compress` example
under `~/Work/zlib-rs` and reruns `run-zlib-family-diff`, so zlib-rs binary
coverage is a required CI signal rather than only an optional local probe.

Additional Rust deflate baselines are expected under `~/Work/fdeflate` and
`~/Work/miniz_oxide` when available. They are tracked by `run-external-probe`
as local source checkouts, including their current git revision when available,
and `run-rust-deflate-diff` builds a temporary Cargo runner with path
dependencies to both checkouts. That smoke verifies Rust-generated zlib frames
decode through Vort and Vort-generated zlib frames decode through both Rust
implementations. Passing that smoke is compatibility evidence for its small
payload set; it is not yet throughput or ratio evidence, so dedicated benchmark
harnesses are still required before making performance claims. The
`run-rust-deflate-bench` step is the first such decode-throughput smoke: run it
with `-Doptimize=ReleaseFast` so the Vort row is comparable to the release-mode
temporary Cargo runner built against both Rust checkouts. It prints CSV rows
comparing Vort, fdeflate, and miniz_oxide zlib decode throughput on generated
tiny, repetitive, text, and binary payloads plus real project README/roadmap
files. Each engine performs one warmup decode before timing to reduce cold-start
noise. Use
`run-rust-deflate-bench-csv` to persist the same rows to
`zig-out/vort-rust-deflate-decode-bench.csv`. The Vort decode rows include the
zlib allocator-returning API (`vort`), the zlib caller-owned output-buffer API
(`vort-into`), and matching gzip wrapper rows (`vort-gzip`,
`vort-gzip-into`) so regressions can distinguish inflate/checksum work,
wrapper format overhead, and per-iteration allocation overhead.

`run-rust-deflate-encode-bench` provides the matching encode-side smoke. It
prints CSV rows for zlib output size, ratio, and encode throughput for Vort,
fdeflate, and miniz_oxide on the same generated payloads. Vort is reported at
fastest, fast, default, best, dynamic-default, fixed-fast, split-default, and
adaptive-default modes so speed/ratio tradeoffs, dynamic-only cost,
best-selection overhead, and wrapper split/adaptive overhead are visible next to
the Rust baselines. The best row uses fewer iterations because it currently
exercises the slower optimal parser; each row records its actual iteration
count. It also includes real project README/roadmap files. Run it with
`-Doptimize=ReleaseFast` before interpreting the Vort rows. Use
`run-rust-deflate-encode-bench-csv` to persist the same rows to
`zig-out/vort-rust-deflate-encode-bench.csv`.
`run-rust-deflate-benchmark-summary` consumes both CSV files and writes
`zig-out/vort-rust-deflate-benchmark-summary.md`, highlighting per-case Vort
zlib allocator and caller-buffer throughput ratios against the best Rust
baseline. Gzip decode rows and decode allocation overhead are summarized
separately because the Rust baseline harness measures zlib frames. The encode
table also reports the Vort default/dynamic-default throughput ratio to expose
best-selection overhead, plus split-default/adaptive-default speed and size
ratios against Vort default to expose wrapper block-planning overhead and
split-induced size changes.
