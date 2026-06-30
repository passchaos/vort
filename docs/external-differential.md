# External differential validation

Vort currently has black-box differential smoke coverage against Python `zlib`
and the system `gzip` CLI.

```sh
zig build run-python-zlib-diff
zig build run-gzip-cli-diff
zig build -Doptimize=ReleaseFast ci-smoke
```

The `ci-smoke` aggregate includes the Python zlib, gzip CLI, optional
zlib-ng/zlib-rs family harness, external-tool probe, fuzz smoke entrypoints, and
bounded benchmark reports.

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
