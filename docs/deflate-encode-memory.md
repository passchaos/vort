# Deflate encoding requested-heap contract

`CompressionOptions.max_total_working_memory` optionally bounds one complete
encoding operation. `memory_profile` points to `DeflateEncodeMemoryProfile`
(`deflate.EncodeMemoryProfile` in the codec module), the same profile type used
by Zstd. Both fields default to null. Default calls use the original allocator
and codec choices directly; profile-only calls preserve all candidate searches,
complete wire bytes and tie decisions.

The supported boundary includes all existing raw/zlib/gzip allocating and append
functions accepting `CompressionOptions`, the corresponding Alloc/Append/Scratch
methods of `RawDeflateEncoder`, `ZlibEncoder` and `GzipEncoder`, ordinary fixed
sync-flush append (including scatter input), the reusable
`RawFixedSyncFlushEncoder` arena facade, and `dynamicPlanStatsAlloc`.
The arena facade counts actual backing node requests and supports distinct
physical scratch/output allocators; see
[its resource contract](deflate-arena-encode-memory.md).
Chunked sync-flush paths also preserve plaintext and descriptor aliases to the
whole output allocation using scratch copies of affected original contiguous
runs; [the alias contract](deflate-sync-flush-alias.md) specifies memory accounting
and retry ownership.
`ZlibEncodeOptions` supplies the same fields for every `ZlibFrameEncoder`
Alloc/Append/Into/Scratch and stored-chunks operation and the one-shot frame
facades. This includes stored, fixed, dynamic, literal-only dynamic, best,
adaptive and PNG ultrafast modes, default and small windows, preset dictionaries,
refinement, fallback and split candidates.

One ledger counts the requested live capacities of the matcher, token/planning
storage, every simultaneous losing/winning candidate, wrappers and encoded
output. The stable ledger control allocation is itself counted. Internal calls
receive the tracked allocator and cleared policy fields, so they inherit the
same ledger rather than resetting the cap or profile. An explicit policy on an
already tracked allocator must match the inherited non-null policy; incompatible
settings return `InvalidBlockPlan`.

Caller plaintext, dictionaries, fixed caller `into` slices, stack storage and
allocator bookkeeping are excluded. Existing append capacity participates in the
operation even when spare capacity avoids growth. Output growth and simultaneous
temporary encoded bytes count. Returned owned wire bytes are charged until
ownership transfers back to the same physical allocator; their exact allocated
size is the returned slice length. These APIs have no separate return-allocator
parameter.

Warm scratch capacity is borrowed into each operation at its start, before any
allocation or publication. Growth and freeing use the operation allocator, then
physical ownership returns to the original encoder allocator at the end. The
profile measures **this operation's charged ledger scope**. Its
`live_requested_bytes == 0` after a call means that borrowed and returned
allocations have left that scope. The encoder can still physically retain warm
scratch; this value does not claim that the encoder holds zero heap.
`peak_requested_bytes` includes the actual previously retained capacity plus all
concurrent requested allocations. Profiles accumulate peak until `reset()` is
called, so reset between calls for an individual operation's peak.

A lower cap than warm/append capacity plus control bytes rejects admission before
changing bytes or the owner allocator. On that failed admission the profile
records observed existing capacity in its peak, then closes live accounting at
zero. A pre-existing capacity larger than the newly lowered cap can consequently
appear above that cap in the profile; no new allocation was admitted. Ordinary
allocation/append failures restore the prior logical output prefix; a scratch
failure retains the previous borrowed result. Output capacity can remain enlarged
when an earlier growth succeeded before a later failure.

Direct stored `into` without an explicit `block_len`, and stored scatter `into`
including explicit scatter block lengths, use only caller storage. They request
no new heap or ledger control allocation. A fresh encoder with cap zero succeeds
when the destination fits and records a zero requested-heap operation.
A warmed encoder still borrows its retained scratch capacity for admission and
profiling, even though direct emission does not use it. Cap zero succeeds for a
fresh encoder; a cap below retained capacity fails before publishing bytes.
When inherited from an outer ledger it validates policy without resetting the
outer live/peak observation. Allocating stored APIs still charge their owned
output and ledger control bytes.

For `ZlibEncodeOptions`, top-level and nested `compression` fields combine into
one policy: one non-null value is used, matching non-null values are accepted,
and differing non-null caps or profile pointers return `InvalidBlockPlan` before
publication. The policy covers framing even in modes whose raw backend does not
accept compression settings.

A quota refusal returns `WorkingMemoryLimitExceeded`; physical backing allocator
failure returns `OutOfMemory`. These errors are available as `DeflateEncodeError`
(`deflate.EncodeError`); the existing decode/base `DeflateError` is unchanged.
A refused refinement/fallback/split/adaptive
candidate cannot be skipped to produce a successful different wire. Reusable
operations also inspect the ledger's sticky refusal before returning an owned
result or successful append; refused owned results are freed, and append restores
its prior logical prefix. Scratch and caller-buffer paths inspect the same
inherited ledger before physical publication, so a caught optional-candidate
refusal cannot overwrite the previous result or caller bytes. In a tracked
cap or profile-only operation, physical OOM in a refined-history candidate also
propagates as `OutOfMemory`; the untracked default keeps the historical optional
candidate OOM fallback behavior. All owned temporary storage is cleaned up.

Persistent incremental stream encoders (`Options.compression` or
`Options.raw.compression`) require a separate stream resource contract.
Incremental encoders reject non-null cap or profile fields with `InvalidBlockPlan`
during validation and before accepting input or publishing headers/output.
Their existing void reset APIs may install options; the next validation/step
rejects an unsupported policy. `writeIncrementalBestPlannedBlock`, the staged
benchmark instrumentation surface, also explicitly rejects these controls. No
accepting path silently ignores a requested cap or profile.

Gzip Fixed/Best `nextMemberWithOptions` and `nextMemberExactSizeWithOptions`
validate raw block controls and reject unsupported one-shot cap/profile before
installing options, replacing a pledge, or resetting checksum/history state.
Admission preserves the existing priority: complete and drained member first,
then cumulative member-counter overflow, then raw options. A rejected transition
leaves the previous member state intact and permits a valid next-member retry.

Validation is available with:

```sh
zig build -j2 test -Droot-test-filter='Deflate whole-operation requested heap'
zig build -j2 run-deflate-split-history-interop
```

Independent counting-allocator tests cover exact peak D acceptance and D-1
refusal, default/profile-only wire identity, strategies, dictionaries, refinement,
large-input candidates, split/adaptive modes, append and warm ownership,
inherited policy, zero-heap stored into, publication and all backing allocation
failure points for a refined one-shot operation. The existing system libz split
history harness compares default/profile-only/exact-cap wires before decoding
the bounded wires with fragmented libz input/output and preset dictionary requests.

Reusable owner facades now live in `src/deflate/encode/raw_encoder.zig`,
`zlib_encoder.zig` and `gzip_encoder.zig`; the main module only wires their public
types. The remaining large Deflate facade has an explicit follow-up split plan:
move one-shot encode/wrapper entrypoints and their candidate planning into
cohesive encoder modules, then extract the remaining inline tests into dedicated
contract files. Keep each move separately reviewable with unchanged public wire
and ownership behavior.
