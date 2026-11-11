# Incremental dictionary-borrow proof, 2026-11-11

This package preserves correctness and borrow-lifetime evidence for the public
raw Deflate/Deflate64 seed APIs and zlib/automatic dictionary provision.
The [public contract](../../formats/deflate-dictionary-borrows.md) describes
accepted sources, rejected writer collisions and resumable state rules.
This package makes no throughput or performance leadership claim.

The before probes were compiled from an immutable Git archive of
`9a41b4e43e6258f8e10d602b3d7d5312cd683d1f`, through public `src/root.zig`,
using Zig 0.16.0. Both `initWithDictionary` and `seedDictionary` abort with
`@memcpy arguments alias` for source `H[5..15]` and destination `H[0..10]`.
The corrected public probes copy bytes 5 through 14 exactly and retain
`history_len=10`, `history_pos=10`; both operations exit 0.

A second before probe stops a valid length-ten, distance-ten fixed match with
zero output, then supplies the nonoverlapping dictionary `12345`. The old API
accepts it and sets history length/position to 5. Debug aborts at the history
availability assertion in `copyMatchSpanAt`. ReleaseFast emits five stale
`0xa5` slots followed by `12345`, then the probe reports
`PendingHistoryCorrupted` and exits 1. The corrected Debug probe returns
`InvalidStreamState` from the short seed, compares complete receiver/history
snapshots, and resumes the original pending match to output `ABCDEFGHIJ`.
Its first output drain reports `need_output`; the focused tests also drain EOB
and finish successfully.

The RFC 1951 fixtures are independently constructed, with Python zlib runtime
1.2.11 oracle checks. `43b000` is a final fixed block containing only a
length-ten, distance-ten match and EOB; its complete output comes from the
dictionary tail. `430000` repeats the last dictionary byte ten times.
The partial-header control uses five nine-bit literals in a nonfinal fixed
block. Its first block is 55 bits long, so seven input bytes leave exactly one
bit of the next header buffered. Both oracle scripts and their exact output
logs are included. Production encoders are not used to construct these wires.

The final worker-focused Debug and ReleaseSafe suites each pass **14 named
contract tests plus 90 import aggregators, 104 total** through public
`src/root.zig`. Coverage includes forward/backward/exact/adjacent history
sources, long dictionaries clipped to 32/64 KiB windows, full zlib DICTID
validation, mismatch preservation and retry, empty sources, receiver metadata
sources consumed before metadata updates, actual destination collisions with
the enclosing raw/zlib/Auto receiver, and released override output reuse/reset.

Positive controls preserve partial block/stored headers, pending literals and
stored payload state. A longer shifted pending seed (`keep=15`, distance 10)
produces its new tail `pqrstuvwxy`. Inactive attached workspaces retain their
poisoned/uninitialized table bytes, and the second history window remains
unchanged when either supplies the copied dictionary. A real active semantic
generation refuses all reseeds atomically and resumes to exact output.
Both compact match-completion paths normalize an exhausted match to `symbols`
before a public return; this natural zero-remaining state permits an empty
seed before its buffered EOB is drained.

Earlier worker runs contain 12 named contracts plus 90 aggregators, 102 total.
The two `attempt1` logs preserve a test-helper compile error from accessing
optional diagnostics progress; the helper was corrected to use snapshot
progress before either successful run. The earlier and final logs are kept
separately and retain their original bytes, whitespace and EOF.
The archived Zig probes likewise retain the exact original compiler inputs,
including their formatting, so the recorded source hashes remain valid.
Implementation and regression-test formatting is checked separately; do not
normalize these immutable probe copies when checking the production sources.

`proof.json` binds copied artifacts, source/probe hashes, expected and observed
failures, focused test results, and external retained artifacts. The before
revision is pinned; the corrected probe source snapshot and final test freeze
are represented by their original per-file SHA-256 manifests. The binaries,
full Git source tar and source directories remain externally under
`/tmp/vort-dictionary-borrows-20261111`; they are listed with hashes and are
not committed in this package. Original command manifests preserve the actual
snapshot paths used for each compilation.

Final acceptance is bound to implementation `7d846abe` in `validation.json`.
The full ReleaseSafe Deflate/Deflate64 suite passes **733 tests**. The focused
codec suite passes **23 tests on native x86 and actual WASI**, including its
14 named dictionary contracts. Public-root worker runs pass 104 tests in
Debug and ReleaseSafe. Decoder clone/reference checks pass **40 native/x86
events**, covering 20 decode cases with libz 1.2.11 validation and independent
branch history, reset and dictionary ownership.

The whole-library Debug `check check-wasm` gate passes **380/380 steps and
86/86 tests**. Aggregate root compilation is filtered to `dictionary borrows`;
the complete codec family was executed independently in ReleaseSafe. Main
gate logs, actual WASI exit receipt and clone report are now included. The
545-file clone input/output packet and binaries remain external under the
same temporary directory with additional hashes in `validation.json`.

Verify the copied archive and rerun the independent oracles with:

```sh
python3 docs/performance/deflate-dictionary-borrows-20261111/verify.py
python3 docs/performance/deflate-dictionary-borrows-20261111/verify.py --external-root /tmp/vort-dictionary-borrows-20261111 --source-root .
python3 docs/performance/deflate-dictionary-borrows-20261111/independent-wire-oracle.py
python3 docs/performance/deflate-dictionary-borrows-20261111/partial-header-oracle.py
python3 docs/performance/deflate-dictionary-borrows-20261111/verify_final.py --source-root .
python3 docs/performance/deflate-dictionary-borrows-20261111/verify_final.py --source-root . --external-root /tmp/vort-dictionary-borrows-20261111
```

Recreate the before source outside the current checkout, since the pinned
revision predates this evidence directory:

```sh
mkdir -p /tmp/vort-dictionary-before-source
git archive 9a41b4e43e6258f8e10d602b3d7d5312cd683d1f | tar -x -C /tmp/vort-dictionary-before-source
zig build-exe -ODebug --dep vort -Mroot=docs/performance/deflate-dictionary-borrows-20261111/before.zig -Mvort=/tmp/vort-dictionary-before-source/src/root.zig -femit-bin=/tmp/vort-dictionary-before
/tmp/vort-dictionary-before init
/tmp/vort-dictionary-before seed
zig build-exe -ODebug --dep vort -Mroot=docs/performance/deflate-dictionary-borrows-20261111/before-pending.zig -Mvort=/tmp/vort-dictionary-before-source/src/root.zig -femit-bin=/tmp/vort-dictionary-pending-before-debug
/tmp/vort-dictionary-pending-before-debug
zig build-exe -OReleaseFast --dep vort -Mroot=docs/performance/deflate-dictionary-borrows-20261111/before-pending.zig -Mvort=/tmp/vort-dictionary-before-source/src/root.zig -femit-bin=/tmp/vort-dictionary-pending-before-fast
/tmp/vort-dictionary-pending-before-fast
```

The three Debug before operations are expected to terminate with SIGABRT;
Python subprocess records `-6` (a shell commonly reports 134). The ReleaseFast
pending probe is expected to exit 1 after displaying stale output. Compile
`after.zig` and `after-pending.zig` against the corrected checkout; they are
expected to exit 0. The exact actual build commands remain in the manifests.
Focused tests on the corrected checkout are:

```sh
zig test src/root.zig -ODebug --test-filter 'dictionary borrows'
zig test src/root.zig -OReleaseSafe --test-filter 'dictionary borrows'
zig test src/deflate.zig -OReleaseSafe
zig test src/deflate.zig -OReleaseSafe -target x86-linux --test-filter 'dictionary borrows'
zig test src/deflate.zig -OReleaseSafe -target wasm32-wasi --test-filter 'dictionary borrows' --test-no-exec --stack 16777216 -femit-bin=/tmp/vort-dictionary-contracts.wasm
node tools/deflate/clone/wasm_gate.js /tmp/vort-dictionary-contracts.wasm
zig build -j2 run-deflate-clone-diff -Doptimize=ReleaseSafe --summary all -- --only decode
zig build -j2 check check-wasm '-Droot-test-filter=dictionary borrows' -Doptimize=Debug --summary all
```
