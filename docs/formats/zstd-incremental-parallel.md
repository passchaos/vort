# Persistent parallel jobs in one incremental Zstandard frame

Draft, 2026-10-26. The explicit encoder, shared job view and ZIP integration are
being implemented and independently tested. This records the current contract;
runtime/reference/platform pass counts remain pending in the
[functional baseline](../performance/zstd-incremental-parallel-functional-baseline.md).
No future validation or performance result is assigned.

`zstd.NativeIncrementalParallelFrameEncoder` is a separate owning encoder type.
It does not add an ignored worker option to the existing serial encoder.
Its `Options.frame` is `NativeFrameOptions`, defaulting to
`include_content_size = false`, and `Options.parallel` is required. The
persistent parallel options use a wide-Count profile distinct from the one-shot
profile. Root aliases expose the same class and observations during integration.

```zig
var encoder = try vort.zstd.NativeIncrementalParallelFrameEncoder.init(
    allocator,
    .{
        .frame = .{ .include_content_size = false, .content_checksum = true },
        .parallel = .{
            .io = io,
            .worker_count = 2,
            .job_size = 1024 * 1024,
            .max_inflight_jobs = 4,
            .max_inflight_bytes = 4 * 1024 * 1024,
            .max_working_memory = 256 * 1024 * 1024,
        },
    },
);
defer encoder.deinit();
```

Unknown-size initialization omits FCS; exact-size initialization uses matching
content-size settings and a checked pledge. Job size rounds up to the effective
block size. The configured worker/job/byte/heap defaults and worker count 1...64
match the one-shot policy, but ownership and delivery credit are persistent.
Workers use the original native strategies/HQ/search budgets and mixed heap
workspace rather than reducing codec settings for streaming.

## Sealing, owned input and history

The entire Stream Header must reach caller output before input acceptance or
worker startup. An initial zero-output step can stage the header and returns
zero accepted/delivered progress. A full filling job is not encoded immediately:
a valid following input offer seals it nonfinal, `flush()` seals accepted data
nonfinal, and `finish()` seals the final full/partial job final. This defers the
last-Block decision without adding an unnecessary empty final after an unflushed
full job. Invalid surplus/limit offers reject before sealing or output changes.

Reported accepted input is copied into an owned `[prefix | plaintext]` job buffer.
The rolling prefix includes every accepted predecessor, including jobs still
queued/active, not just already published bytes. Workers see immutable prefix
snapshots and never a pointer to the movable public encoder or mutable rolling
history. The caller can overwrite accepted input before its next step, and can
transfer unique encoder ownership to a moved value while workers retain stable
heap addresses. No new same-call input/output overlap guarantee follows from
that next-step reuse contract.

With history window H and effective job size J, the owner retains rolling H-byte
history plus O(H+J) input snapshots per bounded slot. Job byte credit counts only
actual new plaintext; prefix copies, codec/history/index scratch and outputs are
charged to requested heap. Partial, queued, active, complete and delivering jobs
keep credit until their last coordinated output byte reaches the caller.
A small cap below J permits a smaller explicit flush/final job. Exhausting that
partial cap with no submitted job able to release credit returns recoverable
`WorkingMemoryLimitExceeded`; it does not silently split partial jobs.

The coordinator has one ordered front publication unit rather than complete
plaintext or whole-frame output staging. Other bounded jobs can remain queued
or completed. Synchronous worker-one/unsupported-target mode uses the same
geometry and boundaries with `std.Io.failing` allowed and zero OS-worker activity.
Spawn/worker errors stop and join started workers instead of changing modes.

## Global frame state and job transactions

Shared Job View keeps cumulative `Count` frame positions separate from bounded
local prefix indices, explicit finality and the actual window limit. Known FCS
clamps retained/matching history to the emitted header window; unknown frames use
the configured window descriptor, with the legacy 8 MiB policy when unspecified.
Wide coordinates use checked arithmetic and do not imply physical giant-buffer
support or permit narrowing a frame offset to a 32-bit local index.

Each job starts original dictionary entropy/FSE/repcodes independently. Its
decoded physical distances and literals are checked against the owned prefix/
plaintext, including overlap and the history seam. Re-emission uses the actual
persistent global-frame reps/Huffman/FSE state. A whole-job transaction rolls
back output logical length, coding state and emitted statistics on error;
scratch retains real capacities without copying owning pointers.

The existing one-shot adapter keeps its borrowed prefix/global offset/finality
and null window override. Saved one-shot wire preservation is a separate
regression gate, not a consequence of the incremental tests. New job priors are
explicit-mode policy; no libzstd MT algorithm/ratio/speed equivalence is promised.

## Limits, flush, finish and error progress

| Option | Scope |
| --- | --- |
| `max_input_len: Count` | Cumulative accepted data plaintext across frames |
| `max_output_len: Count` | Cumulative delivered wire bytes across data/skippable frames |
| `max_pending_output_len: usize = 16 MiB` | Complete Header, coordinated job, checksum/final or skippable publication unit |
| `max_job_count: Count` | Current-frame admissions, including partial and empty-final jobs |

All four limits may change between calls and legal values survive `reset()`.
`max_job_count` must remain nonzero, matching initialization and next-frame
validation; a runtime zero is rejected with zero progress as `InvalidBlockPlan`.
| `parallel.max_working_memory`, native total cap | Shared requested heap, including control, prefixes/history, codecs, job outputs and front |

`flush()` acknowledges with `need_input` only after all accepted data has been
sealed nonfinal and delivered. Repeated empty flush is idempotent; it keeps
history, frame hash and entropy state. `finish()` rejects further input and
emits the final partial/full job. After an acknowledged flush with no new input,
it adds an empty final job. The content XXH checksum is appended once, and `done`
plus the data-frame count advance only after all terminal bytes are delivered.
Finishing with fewer accepted bytes than the exact pledge produces sticky
`SizeMismatch` until reset.

Surplus input, scalar input/job-admission caps and invalid offers are checked before
sealing/delivery and are recoverable. Raising pending or cumulative output caps
allows precise retry without re-encoding/re-emitting a completed front unit.
The output cap can admit a prefix before returning an error; failed-step progress
accounts for that delivered prefix, and retry drains only the remaining bytes.
Worker codec, spawn or heap failures are sticky and stop/join workers. Read
`failedProgress()` after the most recent failing step to account accepted input
and delivered bytes once; repeated sticky errors report zero new progress.
Bytes already delivered by earlier steps cannot be rolled back.

## Profiles and lifecycle

Persistent profiles use `Count` for accepted/encoded/published/delivered jobs,
Blocks and current-frame accepted input. Published counts describe ordered
internal coordination. Delivered jobs advance only at the job's final output
byte, and delivered Blocks credit all Blocks of that completed job together.
Native control-profile emitted statistics merge only for fully delivered jobs;
a partly delivered job can have output progress without those whole-job counters.

Snapshots separate queued/active/completed/delivering work, partial/owned input,
logical in-flight bytes, retained job/history/front capacities, control storage,
requested live/peak heap and the latest step/error state. Workers update private
work/counters; public touchpoints synchronize caller destinations. Profile storage
stays valid until deinit, with no setter swapping active destinations; callers
may read profiles between steps. Caller I/O,
allocator and borrowed dictionaries remain valid until joined work is finished;
calls on the owner are externally serialized.

`reset()` joins work, clears poison/frame/logical stream state and retains real
capacities without allocation. It uses the captured frame/I/O/parallel settings
and preserves the four runtime caps. At a fully done/drained boundary, next-frame
methods transactionally admit complete new settings, metadata and heap limits.
Failure leaves the old completed state unchanged; success clears frame history/
hash/coding state while retaining cumulative stream totals and data-frame count.
Done can retain live heap; deinit joins/frees and publishes live zero. Caller
buffers, stack mappings and Io/backing private overhead are outside requested
heap, so these counters are not RSS measurements.

Preset/set routes derive a default zero frame Dictionary_ID from the selected
dictionary; a conflicting nonzero ID returns `DictionaryMismatch`. Direct raw
preset ID zero is legal. Metadata-only nonzero-ID routes do not supply history
and are limited to their raw-output contract. Standard skippable frames may be
written only at done/drained boundaries, contribute delivered output bytes and
do not advance data-frame count; magicless mode rejects skippable writing.

ZIP incremental `zstd_parallel_options = null` preserves serial wire, allocation
and existing resolution guards. An explicit option selects the new stable owning
Zstd union and failed-progress bridge, so ZIP input/CRC/encryption/output bytes
are accounted exactly once on codec error. Known/unknown entry, failure and
deinit contracts are pending independent consumer checks. No CLI worker flags
are added by this increment.
