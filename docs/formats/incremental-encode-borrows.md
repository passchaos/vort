# Incremental encoder buffer borrows

Deflate, Brotli and Zstd incremental encoders admit caller buffers before
publishing a header, draining pending output, changing history, or binding
working-memory accounting. Conflicting storage returns `InvalidBlockPlan`
without consuming input, writing output, or changing the encoder. Retry with
independent buffers on the same encoder.

This contract applies to raw Deflate stored/fixed/best encoders, zlib and gzip
fixed/best wrappers, Brotli stored/planned/static-dictionary encoders, and Zstd
single-frame serial and persistent parallel encoders. It covers `step` and
`stepWithDirective` where the latter is provided.

Deflate64's stored encoder shares the raw stored core and follows the same
rules. Its inline bit state is protected with the object; `clone` independently
copies the retained plaintext and pending output capacities.

The entire offered input remains a read borrow until the call returns, including
bytes that output backpressure leaves unconsumed. The countable output window
must be disjoint from that input and from the encoder object, its owned
allocations, and immutable dictionaries or metadata retained for later reuse.
Owned allocations include spare capacity, even after reset clears their logical
length. Caller input must also stay outside the object and owned allocations:
buffer growth or block planning can invalidate a pointer before it is read.

Input may overlap immutable dictionary or metadata bytes when all mutable
storage is independent. Adjacent half-open spans and empty spans do not overlap.
A completed encoder accepts empty input without writing to the supplied output;
such a call can use an otherwise conflicting output span. Nonempty input after
completion is rejected; use reset or a supported frame/member continuation to
start again.

The check adds no input snapshot or allocation. These APIs require independent
buffers for active calls; callers that need to reuse backing memory can supply
disjoint input and output regions or move their input before stepping.

## Why admission covers a whole call

An incremental encoder may drain earlier output before reading new input. Gzip
and Zstd can also publish their frame headers first; Brotli can publish a window
and metadata prefix. Checking only the bytes consumed in one inner operation
would let that earlier output overwrite a future input suffix. Merely checking
logical retained lengths would leave capacity tails exposed to growth, reset,
match indexing and later output writes.

## Validation

Focused public regression modules exercise header-before-input and pending
drain collisions, object and retained-capacity conflicts, dictionary and
metadata protection, refusal without side effects, and disjoint retries. The
same codec tests are available through:

```sh
zig build -j2 test-incremental-encode-borrows
zig build -j2 test-incremental-encode-borrows-x86
zig build -j2 test-incremental-encode-borrows-wasm
zig build -j2 check-incremental-encode-borrows
```

The WASI gate runs the Zig test runner under Node with an 8 MiB stack and writes
`zig-out/incremental-encode-borrows-wasm.json`. Parallel Zstd runs its synchronous
fallback there. `check-wasm` compiles these regression artifacts as part of the
library portability check; the explicit test gate executes them.

See the [functional evidence](../performance/incremental-encode-borrows-20261120.md)
for the source revision, observed failures, final validation and scope.
