> Experimental API contract. This prepared-fixed implementation is archived
> and has not been adopted into main after the V1/V2/V3 performance rejections.

# Prepared fixed DEFLATE encoding

`deflate.PreparedRawFixedEncoder` prepares caller-owned matcher and token
capacity for independent, final raw DEFLATE streams using fixed Huffman codes.
After preparation, encoding any input inside the declared capacity uses no
heap allocation, resize or remap request for its workspace. It runs the same
greedy/hash policies as the ordinary fixed encoder and emits the complete wire
once, directly into caller output.

This first prepared owner supports `strategy = .default`, `parser = .greedy`
or `.hash`, windows from zero through 32768 bytes, and no custom dictionary
provider. The existing allocating/reusable APIs continue to provide the other
parsers, strategies, dictionaries, best/dynamic selection and wrappers. Extending
those capabilities is part of the remaining prepared-encoder work.

## Use

```zig
const deflate = @import("vort").deflate;
const options: deflate.CompressionOptions = .{
    .parser = .hash,
    .lz77_options = .{ .window_len = 16 * 1024 },
};
var encoder = deflate.PreparedRawFixedEncoder.init(allocator);
defer encoder.deinit();
const capacity = 64 * 1024;
const needed = try deflate.PreparedRawFixedEncoder.requirements(capacity, options);
try encoder.prepare(capacity, options);
const output = try allocator.alloc(u8, needed.maximum_wire_bytes);
defer allocator.free(output);
const written = try encoder.encodeInto(input, output, options);
const wire = output[0..written];
```

`input.len` must not exceed the prepared capacity. Each call re-plans the actual
input; changing input contents does not require preparation. Compression
settings must match the prepared normalized settings. Memory cap and profile
are per-call policy and may change without replacing workspace.

`encodeAppend(output_allocator, out, input, options)` appends the same final
fixed stream to a caller `ArrayList`. Reserve enough caller output capacity
before timing if the complete operation must also perform zero heap requests.
Output growth uses the supplied output allocator and participates in the same
whole-operation ledger. A failed append preserves the existing logical prefix.

## Capacity and ownership

`requirements()` reports token/table capacities, standalone minimum prepared
heap, a worst-case fixed-wire byte count, and inline owner bytes. Its heap
estimate includes the stable budget control state; it excludes the inline
owner object, caller fixed output slices, input, and allocator bookkeeping.
Actual quota checks use retained physical allocation capacities, including
both compact and wide layouts when the declaration requires them.

The original hash dispatch remains intact: small scan, compact tiny tables,
full tables and ring layouts are selected for each actual input. A declaration
covering full/ring inputs reserves all reachable predecessor capacities; it
does not substitute a smaller matcher to obtain a zero-allocation result.

Preparation replaces payload transactionally. If growth or quota admission
fails, the prior prepared configuration remains usable. The stable control
state may already exist after a failed first prepare and is released by
`deinit()`. During a replacement, old and new payload allocations are both
live and both count against the preparation cap. Preparing a smaller capacity
with unchanged settings may retain larger physical buffers.

The encoder owns its workspace and must be deinitialized. Moving ownership
does not invalidate the stable ledger allocator; copying an owner and
deinitializing both copies is invalid. The backing allocator and any inherited
ledger policy/profile must remain valid for the required lifetime.

## Budget and publication

The same shared requested-heap ledger counts persistent tokens, tables and
control storage. Fixed caller output slices are excluded from requested heap;
append allocation capacity is borrowed into the ledger for the operation.
No fresh control state is created when a prepared encoder begins another call.
Policy admission checks the existing owner ledger before attempting to borrow
external append capacity. A refusal at that first stage observes the owner
ledger; attempted output admission also includes the external capacity in the
reported peak, including when that admission is refused.

An owned per-call profile is detached at return. Its final live observation
still includes real persistent encoder heap. An inherited ledger retains its
outer profile and sticky refusal policy; the prepared encoder does not reset
that outer state or accept conflicting policy settings.
A mutable profile cannot observe two distinct ledgers at the same time.
Append rejects a profile already attached to a different caller-output ledger;
sharing the same ledger and its profile remains supported.

Input and output data may overlap: complete token planning finishes before
output is reserved or written. Owner/workspace/control storage and mutable
profile/output descriptors must not conflict. Conflicting aliases are rejected
before publication or policy updates. Fixed output admission uses the exact
token bit count before any caller output byte is written.

| Condition | Error |
| --- | --- |
| No prepared capacity or input exceeds declaration | `WorkspaceTooSmall` |
| Unsupported/mismatched settings or conflicting aliases | `InvalidBlockPlan` |
| Caller fixed output slice is too small | `OutputTooSmall` |
| Whole-operation heap cap refuses admission | `WorkingMemoryLimitExceeded` |
| Physical backing allocation fails | `OutOfMemory` |
| Capacity or bit-count arithmetic cannot be represented | `IntegerOverflow` |

## Verification

```sh
zig build -j2 test-deflate-prepared-fixed
zig build -j2 check-deflate-prepared-fixed-wasm
```

The gates compare complete wire with the ordinary allocating encoder and
decode it, switch the backing allocator to reject every new request after
preparation, and cover different contents/sizes, dispatch boundaries, exact
caps, physical OOM, rejected-call recovery, aliases and inherited ledgers.
Native and WASI execution use the same public APIs. This capability does not
establish general Deflate/Zstd/Brotli performance leadership.
