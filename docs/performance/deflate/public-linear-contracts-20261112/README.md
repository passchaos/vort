# Public generic linear Deflate contracts

This is a functional coverage packet based on
`8adfb3bae74409bae146fed2ed9b6594a1d3cdb8` plus three frozen test files.
Commit `52cb0f56` later saved byte-identical copies of these test changes.
The Deflate/root changes only connect tests; production decoding was neither
accelerated nor repaired for a newly discovered wire bug in this increment.

The new aggregate exercises **27 actual public contract scenarios**, plus
**two direct root facade calls**. Completed validation has eight successful
runs: Deflate Debug/ReleaseSafe/x86/WASI at 8/8; root Debug/ReleaseSafe/WASI at
90/90; full Deflate ReleaseSafe at 734/734. The filtered Deflate count contains
one behavioral aggregate and seven import tests. The filtered root count
contains two behavioral aggregates and 88 import tests. Those totals are not
90 independent new public-linear cases.

Frozen fixtures establish the public generic semantic entry with the same
buffered parser and selector predicates used by the facade. The original
OSDB dynamic header has **LL maximum 14, complete LL/dist trees, distance
maximum 9 with 22 nonzero entries, HLIT 279, HDIST 30, and 762 header bits**.
The separate malformed fixture has a **complete LL10 tree with 11 leaves**
and an incomplete two-entry distance tree. Its missing primary distance code
is rejected after Vort accepts the header. This is not replaced by another
decoder's earlier header rejection.

These witnesses correct an earlier coverage interpretation: the old test at
14082 only selected compact9 despite its descriptive name. The new tests
explicitly assert `literal_max_bits > 9`, the actual lookup selector and
generic semantic initialization, exclusion of dictionary/overlap/RLE258
paths, and hot versus bounded-tail predicates. Native uses the existing
`linear_entry.aligned` path; WASM uses its portable counterpart.

The later independent Python oracle records eight **bare LL14 wires**:
valid 84-byte and 211-byte zero outputs, two invalid-history distances, and
four truncated long-wire tails. All passed under zlib 1.2.11. `oracle.log`
belongs to that new post-freeze revalidation; it is not a recovered copy of
earlier tool stdout. Caller-bounded output and LL10 missing-primary behavior
remain Zig contracts, because zlib's one-shot API has a different surface.

## Exact artifacts

| File | Contents |
| --- | --- |
| `source-overlay.tar.gz` | Three exact frozen files: `src/deflate.zig`, `src/root.zig`, and `src/deflate/semantic/public_linear_contracts.zig`. |
| `raw-validation.tar.gz` | All original logs, source hashes, validation, WASI runner, and the new oracle source/log/validation. |
| `test-executables.tar.gz` | All eight exact recorded native and WASI test executables. |
| `small-fixtures.tar.gz` | Exact original Git OSDB fixture; eight bare wires reconstructed and matched to oracle hashes; the LL10 malformed wire reconstructed from the frozen independent bit writer. |
| `validation.json`, `oracle-validation.json` | Exact readable copies of the original receipts. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Original member origins/hashes, independent offline verification, receipt, and complete checksum inventory. |

GNU tar members are sorted regular files with uid/gid/mtime zero, empty owner
names, and modes 0644/0755. Gzip uses level 9, empty filename and timestamp
zero. Original source, logs, JSON, and EOF bytes remain unchanged. The derived
small wires are explicitly identified as reconstruction, not pre-existing
captured files.

Baseline bytes are reused by SHA from
`br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz`.
The original OSDB fixture is bound to its Git object at the base revision and
SHA-256 `cb731c66afe83c470f5ef4f6e24807c3590e8b145adac9d2511474fff1e7b91f`.
The frozen validation SHA is
`60467185e9e59d32b876ab864fd442628fcba3477fcb20eb7b56f27180ff8622`.

## Offline verification and replay

Packaging and validation were pinned to **CPU 0** while unrelated performance
work used CPU 15. From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks exact archive bytes, all eight log and
executable identities, source hashes and test-only hooks, aggregate/import
counts, OSDB Git identity, independently parsed LL14/LL10 header shapes,
recorded oracle case hashes and stdout, and the equivalent test commit. It
does not execute Zig, WASI, zlib, or a benchmark during archive verification.

For later replay, use a separate checkout at the base plus the source overlay,
or at the equivalent test commit. The focused filter is
`public generic semantic linear contracts`; use Debug/ReleaseSafe and the
recorded x86/WASI target with Zig 0.16.0. Extract the exact WASI artifacts and
use archived `run-wasi.js` for execution. Re-run `oracle.py` in that checkout
only as a new verification run, preserving its own stdout and timestamps.
Source/input ownership, exact errors and public counts are the purpose of
this packet; it makes no throughput or industry-ranking claim.
