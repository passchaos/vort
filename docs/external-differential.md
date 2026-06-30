# External differential validation

Vort currently has black-box differential smoke coverage against Python `zlib`
and the system `gzip` CLI.

```sh
zig build run-python-zlib-diff
zig build run-gzip-cli-diff
```

The optional zlib-family harness detects locally built zlib-ng/zlib-rs minigzip
binaries and reports explicit skip status when they are not available:

```sh
zig build run-zlib-family-diff
```

Expected current output on an unbuilt checkout is similar to:

```text
zlib family differential harness:
- zlib-ng-minigzip: skipped (binary not built)
- zlib-rs-minigzip: skipped (binary not built)
zlib family differential summary: used=0 skipped=2
```

To turn this into real coverage, build compatible `minigzip`-style binaries in
one of the paths listed in `tools/zlib_family_diff.py`, then rerun the build
step. Skip output must not be counted as zlib-ng/zlib-rs compatibility evidence.
