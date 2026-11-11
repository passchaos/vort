# Incremental step-borrow proof, 2026-11-11

This is correctness evidence. It contains no throughput or leadership claim.
The latest complete decoder comparison remains
[the frozen modern refresh](../modern-decode-refresh-20261111.md).

At `17058d8150af5b5ae3178def85b2e227f55df686`, the public `src/root.zig` probe
decoded two valid Stored blocks as `abcabc`, consuming all 16 input bytes and
reporting successful six-byte output instead of `abcdef`. The first output
covered the second unread payload; each individual copy had disjoint ranges.
`before.zig`, its exact log and metadata preserve the independent failure.
Seven raw/wrapper/dictionary wires also have Python zlib oracle evidence.

The repaired `after.zig` probe verifies `InvalidBlockPlan`, byte-for-byte
unchanged input/history/decoder storage and an independent successful retry:
`done`, input 16, output 6, `abcdef`. The public
[borrow contract](../../formats/deflate-incremental-step-borrows.md) describes
live storage and the preserved safe layouts.

The focused suite has 24 tests, including raw/zlib/gzip/Stored/automatic
dispatch/Deflate64, pending literal/match drains, configured dictionaries and
set storage, empty slices, physical output-limit clipping, lowering logical
options during an admitted continuation, and inactive second-window reuse.
Independent RFC dynamic fixtures exercise optional semantic fallback before
workspace initialization and active-generation refusal, with full storage
snapshots and exact output retries. Native ReleaseSafe, Debug, native 32-bit
x86 and an actually executed WASI artifact are retained separately. The full
Deflate suite passes 718 tests; the filtered public-root build and its object
tests pass 112.

`validation.json` binds the 14 relevant frozen source files, commands, probe
and test binary hashes, final gate exits and every copied evidence file.
The original source tar and executable binaries remain under
`/tmp/vort-incremental-step-borrows-20261111`, with their hashes explicitly
listed as external artifacts. They are not claimed to be in this archive.
The before source is also reproducible from the named Git revision. The
implementation revision is checked against the frozen source hashes.
Captured logs retain their exact whitespace and EOF bytes; the local Git
attribute excludes those raw logs from whitespace normalization/checking.

The initial ReleaseSafe attempt was stopped after the unfiltered aggregate
test compiler and a main-program optimization compile were deliberately
interrupted. The latter had run for more than twenty minutes. Source-reverse
node stderr warnings were displayed with a `failed command` label, which did
not establish a nonzero exit. Direct receipts and the final build summary
record WASI success with exit 0; that earlier interpretation was corrected.

The final Debug build passes **394/394 steps and 110/110 tests**, retaining
every requested check, CLI, benchmark, fuzz and differential entrypoint target,
with aggregate root coverage filtered to `step borrows`. Optimized codec/
runtime coverage remains the independently executed ReleaseSafe suites. Both
build logs and the final WASI receipt are retained; no compiler failure is
inferred from the interrupted optimization's duration.

Run the probes against their corresponding checkout with:

```sh
zig build-exe -ODebug --dep vort -Mroot=docs/performance/deflate-incremental-step-borrows-20261111/before.zig -Mvort=src/root.zig -femit-bin=/tmp/vort-incremental-before
zig build-exe -ODebug --dep vort -Mroot=docs/performance/deflate-incremental-step-borrows-20261111/after.zig -Mvort=src/root.zig -femit-bin=/tmp/vort-incremental-after
zig test src/deflate.zig -OReleaseSafe --test-filter 'step borrows'
zig test src/deflate.zig -ODebug --test-filter 'step borrows'
zig test src/deflate.zig -OReleaseSafe -target x86-linux --test-filter 'step borrows'
zig test src/deflate.zig -OReleaseSafe -target wasm32-wasi --test-filter 'step borrows' --test-no-exec --stack 16777216 -femit-bin=/tmp/vort-incremental-contracts.wasm
node tools/deflate/clone/wasm_gate.js /tmp/vort-incremental-contracts.wasm
zig test src/deflate.zig -OReleaseSafe
zig build -j2 test '-Droot-test-filter=step borrows' -Doptimize=ReleaseSafe --summary all
zig build -j2 test-deflate-wide-decode test-deflate-wide-decode-wasm test-deflate-incremental-relaxed test-deflate-incremental-relaxed-wasm run-deflate-incremental-relaxed-interop run-deflate-split-history-interop check check-wasm '-Droot-test-filter=step borrows' -Doptimize=Debug --summary all
```

Use a copy of `before.zig` outside the old checkout when recreating the original
failure, since that revision predates this archive. Before is expected to exit
1 with `OutputMismatch`; after and the final checks are expected to exit 0.
