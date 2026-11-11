# Brotli borrowed input and checked append publication

This functional increment starts from `f6a9b713`. It adds checked compressed
chunk preparation and destination sizing, and validates memory-profile bindings
before any observation can modify input, dictionary or output storage. The
[public contract](../../formats/brotli-decode-borrows.md) defines supported safe
overlaps, conservative source rejection and error precedence.

The executed append-size red test returns `OutOfMemory` for a mathematically
overflowing `out.items.len + expected_output_len`. The fix returns
`IntegerOverflow` before ledger/staging/growth and retains scalar-format errors
and caller pointer/capacity/bytes. The native/x86/WASI matrix covers full,
prefix, chunked, legacy, options, cap-zero/profile and inherited-ledger routes,
representable maximum sums, physical OOM, alias inputs and independent retries.

Two identical public borrow repros fail before the join fix and pass after it:
a rotated compressed source loses its second half, and compressed scratch
overwrites eleven bytes of RAW dictionary history before a limit refusal.
`borrow-repro.zig` is the executed harness. Its `br` module is supplied by:

```sh
zig test -OReleaseFast --test-filter 'borrow pre-fix' --dep br \
  -Mroot=docs/performance/brotli-borrow-sizing-20261111/borrow-repro.zig \
  -Mbr=src/br.zig
```

Compressed logs preserve the executed red/green observations. The initial
borrow red uses the pre-integration join together with the independent append
sizing edits; it is not attributed to a clean source benchmark epoch. The
baseline commit, harness and executable hashes retain that scope.

New contracts protect chunk/protected descriptor arrays, later source chunks,
complete output allocations and descriptors, histories, diagnostics/eager
objects, RAW/serialized/detached static dictionary backing, and observers.
Identity joins and safe directional moves allocate no heap; cyclic destructive
joins are rejected before copying. An observer in unused scratch tail remains
valid. The explicit-offset fixture avoids Zig auto-layout field reordering.
Two setup fixes initialize/capture sentinels after allocator poisoning in safety
modes. These fixture corrections do not relax the codec preservation checks.

`test-br-decode` executes the relevant complete decoder/summary corpus and both
new boundary groups without unrelated encoder-quality campaigns. Resource and
actual WASI tests run the same public contracts, and the existing reference
driver checks native and Linux x86 against reference-produced streams:

```sh
zig build -j2 test-br-decode test-br-decode-memory \
  test-br-decode-memory-wasm check-wasm -Doptimize=ReleaseSafe --summary all
zig build -j2 test-br-decode-memory -Dtarget=x86-linux-musl \
  -Doptimize=ReleaseSafe --summary all
zig build -j2 run-br-decode-memory-reference -Doptimize=ReleaseFast --summary all
```

`summary.json` binds frozen source hashes and final gate results. Source overlays,
raw receipts and integrity manifests make the result reproducible. These are
functional correctness/resource checks; they establish no throughput, ratio or
industry-performance leadership result. The long-term three-codec goal remains
active.
