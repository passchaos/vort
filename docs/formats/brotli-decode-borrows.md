# Brotli chunk borrows and append sizing

All chunked decode, size, summary, probe and eager-decoder entry points prepare
compressed input with the same allocation-free checked join. The caller owns
compressed scratch, chunk descriptors, source bytes and all other borrowed
storage. The preparation module is `src/br/decode/chunk_join.zig`.

Before copying, preparation checks descriptor-span multiplication, total chunk
length and scratch capacity. The actual joined span must be separate from the
chunk descriptor table and the protected storage required by the operation:
the complete append allocation and list descriptor, caller output/history,
summary diagnostics, eager decoder object, RAW dictionary descriptors/bytes,
and the serialized dictionary view and backing bytes, including active detached
word, transform, prefix/suffix and parameter tables. Nested table counts are
bounded before traversal. Unused scratch outside
the joined span may overlap these regions, and adjacent boundaries are valid.
Scalar dictionary validation retains its existing public error mapping.

A supplied memory-profile object must be independent of source bytes,
descriptors, active compressed scratch, dictionaries and caller output/history
or decoder/diagnostic objects. Decode facades check that binding before any
profile observation can write those bytes. An invalid binding returns
`InvalidBlockPlan` without changing the profile or invoking the ordinary join
diagnostic updates. A profile in unused scratch tail remains valid. Unreadable
descriptor extents and length-sum overflow also fail before observation when
the profile binding cannot safely be checked. Other valid preflight refusals
retain the fresh zero-heap observation.

A source chunk can overlap its own destination. The join skips exact self
copies and uses directional copying for other overlaps. An earlier copy must
not overwrite a source that a later chunk still needs. Preparation checks
this before making any writes, using the address interval between the first
and last earlier non-self copy. That constant-space, linear-time interval is
conservative: it can reject a later borrow into a gap between earlier copies
even if bytes in that gap would remain unchanged. Stable contiguous identity
joins and safe monotonic shifts remain supported. Cyclic destructive joins
return `InvalidBlockPlan`; use independent scratch to retry.

Preflight errors are descriptor-span or total-length `IntegerOverflow`, then
insufficient scratch `OutputTooSmall`, then protected-storage alias rejection,
scalar dictionary validation and remaining source-alias rejection. No join
failure copies bytes or requests heap. Summary and eager decoder wrappers
retain their existing diagnostic updates on rejection. Successful preparation
continues through the original format, output-limit and allocator checks.

Append publication uses `src/br/decode/output_size.zig` to check the final list
length. Exact append rejects `out.items.len + expected_output_len` overflow
with `IntegerOverflow` before ledger admission, decoded staging or output
growth. Legacy, options, full, prefix and chunked variants share this rule.
Scalar dictionary, window and first-meta-block errors keep precedence; the
ordinary representable-size path adds no repeated header parsing. A valid
exact request whose sum is representable still uses ordinary quota/OOM rules.
For non-exact calls, known decoded sizes are checked before admission when
available; prefix staging is checked before publication after its size is known.

Preflight refusal preserves caller output pointer, capacity and bytes. A fresh
standalone profile reports zero heap when the operation was never admitted;
inherited ledger state and profile remain unchanged. An impossible length does
not become a quota refusal merely because the cap is zero. A representable
request can still fail with `WorkingMemoryLimitExceeded` or `OutOfMemory`.

Focused verification uses the same public contracts on native, Linux x86 and
WASI:

```sh
zig build -j2 test-br-decode-memory -Doptimize=ReleaseSafe --summary all
zig build -j2 test-br-decode-memory -Dtarget=x86-linux-musl \
  -Doptimize=ReleaseSafe --summary all
zig build -j2 test-br-decode-memory-wasm -Doptimize=ReleaseSafe --summary all
```

This is a functional ownership and error-reporting increment. It adds no heap
snapshot and makes no codec throughput or industry-leadership claim.
