# Shared Deflate chunk borrow evidence, 2026-11-11

This package preserves functional correction `b6709ae9f210781ff3b1d90998d57e005fb8b32b`
against base `4e3c42ce4fd6999fba50732ae9dcb5dd3145275c`. The old coalescer
overwrote unread payload or dictionary bytes and returned successful wrong
output. The correction admits the complete copy/borrow schedule before writes,
supports safe current-chunk memmove and identity layouts, preserves single
source borrowing, and stages aliased append reads through the caller allocator.
See [the contract](../../formats/deflate-chunk-borrows.md).

## Preserved artifacts

- `campaign.tar.gz`: exact final packet, 1,368 JSONL rows, fixture/schema/build/
  source/commit manifests, normal ReleaseFast executable and Zig/Python replay
  sources. The 21-row pilot remains explicitly separate and nonfinal.
- `gates.tar.gz`: exact before-source/probe/corruption logs, focused/full/root
  test logs, wasm32 module and its actual execution receipt.
- `source-overlay.tar.gz`: twelve exact changed/new Zig files from the fix.
- `bindings.json`: every archive and member byte count and SHA-256.
- `verify.py`, `validation-receipt.json`, `SHA256SUMS`: independent read-only
  verification and package integrity evidence.

Tar members are sorted GNU format with zero uid/gid/mtime, empty owner names
and explicit modes. Gzip timestamps are zero. Raw bytes are retained inside
archives, including any original line endings. Large corpus/wire payloads are
omitted; their exact hashes and producers are retained in `fixtures.json`.

## Coverage and limits

All 216 independently inflated wires passed: 72 frozen Silesia raw streams,
72 Python-zlib streams and 72 gzip streams, using Python zlib 1.2.11 and
producer levels 6/9 on twelve files at 64 KiB, 1 MiB and full sizes. Six
common schedules each cover 216 wires; one-byte fragmentation covers the
72 small fixtures. Raw/zlib/gzip each have 456 successful rows.

Every row checks complete output and byte count, guards, original-wire
immutability, and relevant joined content/move padding. Raw APIs expose exact
input consumption; wrapped APIs expose output count only. The normal probe is
Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`, one sequential child pinned to CPU 15.
The probe allocates caller buffers; this is not a process heap trace.
**No timing, throughput, ratio or industry-leadership conclusion is made.**

Source hashes for all 1,858 `src/**/*.zig` files are identical during build and
campaign and match the committed Git blobs. Initial HEAD plus dirty overlay
and the subsequently equivalent committed source are both recorded honestly.
Probe SHA-256 is
`8ec4ac7f1936ec34eb3e9bf2d64a3805b915aab7ca72c9c3bb2aa8f0689c6ffd`.

The native full gate passed 698 tests, public-root gate 94, and focused Debug,
ReleaseSafe, x86_64 and actual wasm32-WASI contracts passed 11 tests. Tests cover
Raw's 14 facades, zlib/gzip wrapper/probe/inspection/reset paths, old decoded
bindings, PNG outer state/rows, append allocation failures and metadata lifetime.
Scratch-free direct, contiguous dictionary-set and incremental surfaces have
their own contracts; this package does not claim to cover them all.

## Verification and replay

```sh
sha256sum -c SHA256SUMS
python3 verify.py --live-root /path/to/vort
```

Verification rechecks archived bytes, source registry, every final fixture/
schedule row, guards/count claims and actual recorded WASI receipt. It does
not rerun Vort or substitute tests for a throughput measurement.

Extract `campaign.tar.gz` into a scratch directory and follow its original
`README.md` and `commands.txt`. The retained `campaign.py` commands are
`prepare`, `build`, and `final --source-final`; they create a new functional
epoch. Restore the base checkout and apply `source-overlay.tar.gz`, or check
out the fix commit, before building. Restore the original corpus paths or
adapt the retained runner explicitly and retain a new manifest. The earlier
modern-decode package records the frozen raw producer and input hashes.
