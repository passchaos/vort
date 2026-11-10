The focused codec gates are `zig build test-br-decode-memory` and
`zig build test-br-decode-memory-wasm`. The WASI gate executes the real Zig test
runner and installs its provenance JSON as `zig-out/br-decode-memory-wasm.json`.

Run the bounded bidirectional reference gate with:

```sh
zig build -j2 run-br-decode-memory-reference --summary all
```

It compiles consumers of the public package decoder facade for the selected
native target and x86-linux-musl, verifies ELF32 and actual 32-bit execution,
and writes `zig-out/br-decode-memory-reference/report.json`. The default
references are system libbrotli and Python Brotli. A local shared-library
build can be pinned with
`-Dbr-decode-reference-libbrotli-dir=/path/to/brotli/build`; the directory must
contain `libbrotlienc.so` and `libbrotlidec.so` with resolvable dependencies.

The matrix uses quality 0/5/11 and generic/text/font for empty, tiny, random,
repetitive, source-code context, and single-byte-run payloads. Every frame
exercises owned/full/prefix, exact owned, chunked, append with growing or spare
capacity, into, and decoded-size APIs. An independent allocator forces moving
growth and verifies the observed requested-byte peak. For each API the
profiled peak D succeeds at budget D, with and without profiling; D-1 refuses
when D is nonzero. Into and size paths succeed with zero requested heap.
Profiling includes budget control storage, so its D can exceed the default
unprofiled peak. These bytes exclude caller-owned into/scratch buffers and
automatic storage, and describe requested heap rather than RSS.

Reference prefix consumption must equal the first frame's exact length for
both an invalid suffix and a concatenated second stream. Full decoders must
return `TrailingData` under default options and a sufficient measured budget.
This checks tail-error identity after lawful admission; legal-frame D/D-1
checks independently verify quota refusal. Refused append operations preserve
the entry pointer, capacity, and contents. Output and scratch guards and final
allocator live bytes are checked for every API invocation.

The reverse direction checks native/x86 identity of Vort stored wire and
single-byte-run RLE wire, then decodes those wires with libbrotli and Python
Brotli. RLE is emitted only for supported runs of at least five bytes. All
plain/frame/suffix fixtures, successful receipts, hashes, loaded reference
library paths and versions, and a partial failure report are retained in the
output directory. This is bounded compatibility and memory-contract evidence;
it does not measure throughput or claim performance parity.
