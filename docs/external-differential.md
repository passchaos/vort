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
tiny, repetitive, text, and binary payloads.
