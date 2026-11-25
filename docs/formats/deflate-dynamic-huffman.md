# Dynamic Deflate Huffman validity

Deflate wire parsers apply codec-specific tree validity before selecting a
literal/distance decoder or emitting data from the new dynamic block. The
generic Huffman builder retains its existing behavior for other codecs and
low-level correctness oracles.

The shared admission rules are:

- Code-length trees are nonempty, complete and no wider than seven bits.
- Literal/length and distance trees are no wider than fifteen bits and cannot
  be oversubscribed. Incomplete trees are allowed only for a single one-bit
  code.
- Literal/length trees must contain end-of-block symbol 256. Existing
  missing-EOB error classification is preserved.
- An empty distance tree is valid until a length token actually requires a
  distance. That later symbol failure retains its existing error category.

Ordinary raw/zlib/gzip parsing, allocating/direct/chunked/append APIs, header
inspection and PNG consumers share the one-shot policy. Resumable compact
tables and the independent Deflate64 header parser use the same admission
module. Deflate64 retains its established extended distance alphabet.

New one-shot invalid-tree refusals return `InvalidHuffmanCode`. Incremental
parsers retain `InvalidDynamicBlockHeader`, their accepted-input accounting,
diagnostics and sticky error behavior. Caller output/history remain protected
before the invalid block executes; earlier blocks may have committed output
under the existing progress contract.

Run the public regression matrix with:

```sh
zig build -j2 check-deflate-dynamic-admission
zig build -j2 test-deflate-dynamic-admission
zig build -j2 test-deflate-dynamic-admission-x86
zig build -j2 test-deflate-dynamic-admission-wasm
```

The combined gate executes native, x86 and actual WASI tests.
`check-wasm` also compiles the WASI regression. See the
[functional evidence](../performance/deflate-dynamic-admission-20261120.md)
for real failures, valid singleton/empty controls and fixture provenance.
