# Complex fixed block-length trees

The fixed literal, command and distance block-length writers previously called
`simpleCode` for every non-singleton alphabet. That function only supports at
most four symbols. A legal five- or six-region split with distinct length
symbols therefore failed with `InvalidBlockPlan`, even though its header could
describe the required complex prefix tree.

The fixed split module now prepares a canonical 26-symbol encoder once when
the alphabet has more than four symbols. One- through four-symbol output uses
the original simple encoding. Frozen code from `0dd219d9` independently checks
the old bits, validation rules and length geometry. Literal retains its
stricter reuse-policy validation; distance and command retain their original
rules. This is a functional repair, not an encoder performance claim.

`src/br/format/block_length.zig` owns the shared RFC 7932 length geometry and
encoder resolver. The decoder still accepts the full final-code range; the
encoder retains its 16 MiB per-region cap. The adaptive block encoder uses the
same resolver. The fixed code writer accepts physical and counting writers,
providing a checked boundary for subsequent shared entropy planning.

## Regression scope

- Five and six distinct length symbols in all three split dimensions.
- Frozen simple wire bits at eight bit offsets; independently decoded
  Huffman symbols and extras; exact counting versus physical bit geometry.
- Two through six regions, cyclic type reuse, malformed boundaries and
  policies, invalid indices, and per-region length limits.
- Six complete standard streams with region lengths `[1,5,9,17,49,113]`.
  The Vort stream summary verifies five/six block types, and the decoder checks
  the complete output. The frozen fixtures are additionally decoded byte for
  byte by libbrotli 1.2.0.

The focused code suite executes 10 Zig tests, including imported tests; six
named behaviors concern this repair. Debug, ReleaseSafe, ReleaseFast and
32-bit x86-linux-musl passed. The complete-stream aggregate and imports execute
25 tests and passed native ReleaseSafe and wasm32-wasi ReleaseSafe. Full native
Brotli ReleaseSafe validation passed 1707 tests with one 32-bit-only resource
test skipped on the 64-bit host. The build and executor exited successfully.
`validation.json` and the compressed logs retain these separate scopes.

## Reproduction

```sh
zig build -j1 -Doptimize=ReleaseSafe --summary all \
  test-br-fixed-length-codes test-br-fixed-length-wires
zig build -j1 -Dtarget=x86-linux-musl -Doptimize=ReleaseSafe \
  --summary all test-br-fixed-length-codes
zig build -j1 -Doptimize=ReleaseSafe --summary all test-br
python3 docs/performance/br/fixed-length-complex-20261125/verify_reference.py \
  --library /absolute/path/to/libbrotlidec.so.1.2.0
```

To regenerate the wire fixtures, set `VORT_FIXED_LENGTH_EXPORT` to an existing
directory before running `test-br-fixed-length-wires`. The test exports the
input and complete wire after its own summary and byte-equality checks.

```sh
zig build -j1 --prefix /tmp/vort-fixed-length-wasi \
  -Dtarget=wasm32-wasi -Doptimize=ReleaseSafe --summary all \
  build-br-fixed-length-wires
node docs/performance/br/fixed-length-complex-20261125/wasi-run.js \
  /tmp/vort-fixed-length-wasi/bin/vort-br-fixed-length-wires-tests.wasm
```

The saved WASI receipt identifies the actual tested module and exit status.
No benchmark throughput or memory improvement is inferred from these
correctness tests. Concurrent validation activity was logged for the ongoing
fixed-source encoder matrix; those full-file timings remain observational.
