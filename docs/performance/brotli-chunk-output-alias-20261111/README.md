# Brotli compressed scratch and caller output

At baseline `5425a37b0c36ce8b4193b8ea8d09dd638403d1ab`, chunked append joins
compressed bytes into caller scratch before requested-heap admission. If that
scratch borrows the output allocation, cap zero returns
`WorkingMemoryLimitExceeded` after overwriting the original output prefix.
`before.log.gz` preserves the observed ReleaseFast red test: the first 24 bytes of
the allocation changed from `a5` to an independently frozen Brotli fixture.

The fix validates the actual joined scratch span against the complete append
allocation, or the caller output slice for into/eager decoder forms. It returns
`InvalidBlockPlan` before copying or requesting heap. Overflow and insufficient
scratch keep their prior precedence. Adjacent spans and overlap limited to
unused scratch remain accepted, and ordinary joins add no allocation or copy.

`src/br/decode/tests/chunk_alias.zig` covers six full/prefix append modes,
legacy/default/profile/cap policies, logical/spare/empty output, inherited
ledger preservation, independent retries, physical OOM versus quota errors,
valid/malformed into input and eager constructors/resets. The same contracts
execute on native x86_64, Linux x86 and wasm32-wasi.

```sh
zig build -j2 test-br-decode-memory -Doptimize=ReleaseFast --summary all
zig build -j2 test-br-decode-memory -Dtarget=x86-linux-musl \
  -Doptimize=ReleaseFast --summary all
zig build -j2 test-br-decode-memory-wasm -Doptimize=ReleaseFast --summary all
zig build -j2 test-br -Doptimize=ReleaseFast --summary all
```

`summary.json` records source hashes and terminal validation; this is a
functional ownership correction with no throughput leadership claim. The
[public memory contract](../../formats/brotli-decode-memory.md) describes the
new deterministic alias refusal and retry behavior.
