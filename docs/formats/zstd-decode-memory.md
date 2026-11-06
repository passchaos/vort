# Zstd whole-operation decode memory

`FrameDecodeOptions` provides `max_total_working_memory: ?usize` and
`memory_profile: ?*DecodeMemoryProfile` for complete one-shot and reusable
decoding operations. The output-length limit remains independent. A result
can fit `max_output_len` while staging, destination growth or retained decoder
storage requires more heap than the working-memory limit allows.

The fields apply to `decodeFrameAllocWithOptions`,
`decodeFrameIntoWithOptions`, `decodeFrameAppendWithOptions` and the equivalent
`NativeFrameDecoder` methods. `initWithOptions` also applies them to the
decoder's convenience, dictionary, exact-size, limited and chunked methods.
The root module exports `ZstdFrameDecodeOptions`, `ZstdDecodeMemoryProfile`
and `ZstdDecodeMemorySnapshot`.

## Accounting and ownership

The limit counts live requested heap bytes, including the stable ledger's
control allocation and, for a reusable decoder, its optional heap owner.
It includes:

- complete decoded staging until publication finishes;
- the append destination's entire capacity, including its original prefix
  and spare capacity, and any old/new allocation overlap during growth;
- retained scratch capacity and an existing heap entropy workspace, including
  storage allocated before tracking was enabled.

Borrowed compressed frames, raw/standard/prepared dictionaries, caller-owned
output slices, automatic stack storage, allocator bookkeeping and internal
backing-remap transients are excluded. This is a requested-heap limit, rather
than a process RSS limit. Allocator growth strategy and target layout affect
the exact peak. Caller output slices are borrowed; an ArrayList's capacity is
temporarily adopted because the append operation manages its growth.

Owned output is removed from decoder accounting when it transfers to the
caller. Append capacity likewise returns to the caller after the operation.
Reusable scratch, workspace and control storage remain charged until their
owner frees them. `NativeFrameDecoder.memorySnapshot()` observes that ledger
without allocating. An untouched default decoder returns an unavailable
snapshot.

Null cap/profile fields preserve the default allocation path and do not
create an additional heap owner. Once reusable tracking is enabled, its ledger
remains alive so later growth and frees use the same accounting. Per-call
profiles are detached on return; their live value describes the last observed
operation boundary. A profile stored in `initWithOptions` must remain alive
while those configured options are used.

Nested operations inherit an already tracked allocator's limit and profile.
They do not seed already charged capacity again, detach the parent's profile,
or release allocations that still belong to that parent ledger. Explicit
incompatible limits/profiles return `InvalidBlockPlan`. Default calls through
the incremental decoder's working allocator preserve its existing peak and
error classification.

## Refusal and publication

Quota refusal returns `WorkingMemoryLimitExceeded`; backing allocator failure
returns `OutOfMemory`. Options and size validation run before allocating the
ledger. Caller output size is also checked before staging. Into, append and
scratch publication happens only after the frame has been decoded and verified.
Quota, allocation, checksum and malformed-frame failures preserve the previous
destination bytes, pointer and capacity.

A reduced reusable limit must admit its already retained storage. Refusal
leaves that storage intact, so the caller can raise the limit and retry.
Control storage successfully activated during a failed operation can remain
retained. If initial control allocation fails, caller append capacity returns
to caller accounting; it does not remain in the profile's live count.

Size-only methods have no heap allocation or policy activation and accept a
zero heap limit. They retain the normal format, dictionary and output-size
validation rules. Allocating methods also account for their control storage;
a zero limit cannot admit such an allocation.

## Validation

The public contracts use independently observed allocation peaks and compare
an exact successful cap `D` with refusal at `D - 1`. They cover raw, RLE and
compressed frames, checksum verification, standard and magicless formats,
raw/native/full/prepared dictionaries, cap-only and profiled calls, configured
convenience methods, input/output aliases, retained workspace and scratch,
shared parent ledgers and each backing allocation failure point.

```sh
zig build -j4 test-zstd-decode-memory
zig build -j4 test-zstd-decode-memory-wasm
zig build -j4 test -Droot-test-filter='root exports Zstd decode memory'
zig build -j4 test-zstd-magicless run-zstd-magicless-diff
zig build -j4 run-zstd-full-dictionary-diff
zig build -j8 check
```

The actual wasm32-wasi Debug consumer, Zig 0.16.0 and Node 26.10.0 regenerate
512-byte raw and RLE inputs with checksums. Its observed requested-heap values
are:

| Operation | Peak | Live at operation boundary | Relevant capacity |
| --- | ---: | ---: | ---: |
| Owned raw/RLE | 552 | 0 after handoff | 512 result bytes |
| Append with original spare capacity | 2,101 | 0 after caller handoff | 1,549 destination bytes |
| Reusable scratch | 1,404 | 892 retained bytes | 832 scratch bytes |

The runner checks relationships between these values, rather than prescribing
one control layout for every target. It also observes zero heap requests for
size-only calls and verifies refusal/retry and destination guards. The JSON
report in `zig-out/zstd-decode-memory-wasm.json` records artifact, consumer,
library and gate hashes. These are functional/resource measurements and do
not establish a general throughput or industry-leadership claim.

Final native validation passes 1,296 Zstd Debug tests, 44 dedicated decode
memory tests, 96 root-export tests and 151 magicless contracts. The libzstd
magicless campaign passes 609 cases; the standard dictionary differential
passes against libzstd 1.4.8. The complete Debug build check passes 214 steps,
including the full wasm32-wasi library and the memory consumer. CLI help,
formatting and whitespace checks also pass.
