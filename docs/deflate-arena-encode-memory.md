# Reusable Deflate arena requested-heap contract

`RawFixedSyncFlushEncoder.encodeAppend` and `encodeChunksAppend` accept
`CompressionOptions.max_total_working_memory` and `memory_profile`. The cap covers
one complete independent fixed sync-flush operation, including the reusable arena
and the caller's append output. The constructor, method signatures and public
`allocator`/`arena` ownership fields remain available.

`allocator` is the output allocator; `arena.child_allocator` is the scratch
backing allocator. They may have different contexts and different physical
storage. The encoder sends each request to its original allocator and restores
the arena's child allocator before returning, including on errors. It does not
replace the output allocator with the arena allocator. The default untracked
null-policy path preserves the existing direct encoder and arena reset behavior.

One shared stable requested-heap ledger counts:

- the ledger control allocation when the operation creates its own ledger;
- every currently retained arena node's complete backing request;
- caller output's existing allocation capacity;
- new arena nodes, output growth, and simultaneously live old/new buffers during
  explicit allocation/copy/free growth and arena reset consolidation.

Zig 0.16 `ArenaAllocator.queryCapacity()` excludes node headers. Accounting reads
both public used/free node lists and includes each complete `Node.size`, including
header and padding. The node header is 24 bytes on x86_64 and 12 bytes on wasm32.
The arena's logical allocations do not become separate heap charges. Caller
plaintext chunks, pool storage already owned by a backing allocator, automatic
stack storage, allocator bookkeeping and backing remap internals are excluded
under the existing requested-heap profile definition.

The ledger borrows existing arena/output capacity before reset. A cap below that
capacity plus a new ledger's control bytes fails admission before resetting
cursors or modifying output. Failed standalone admission observes existing
capacity in profile peak, then closes live accounting at zero. Existing capacity
can exceed a newly lowered cap; no new request was admitted in that case.

Success and failure return retained arena/output allocations to their original
physical owners. A standalone profile's `live_requested_bytes == 0` means those
allocations left this operation's charged scope; the arena and output can still
physically retain their capacity. The profile accumulates peak until `reset()`.

If either allocator already uses a shared ledger, the encoder inherits one
ledger, preferring the output ledger when present. Matching explicit policy is
accepted; conflicting non-null cap or profile values return `InvalidBlockPlan`.
Existing allocations already in that ledger are not charged twice. Another
caller-tracked allocator keeps its own restrictions and profile, while its
encoder payload participates in the primary operation ledger. Its pre-existing
allocator control state is outside the primary encoder scope. A secondary quota
refusal remains a quota refusal; it is not bypassed by the primary allocator.

A codec-local physical adapter reserves quota before real allocation or admitted
in-place growth. An allocated external reservation transfers its live charge to
that adapter's aggregate, consuming exactly the reservation's extra reference.
The operation owns the remaining scope reference; frees and final ownership
handoff release the aggregate charge before the scope closes. No allocation
metadata or adapter pointer survives in retained arena nodes.

`resize` and `remap` are optional allocator probes. The arena can speculate on a
larger resize than its eventual new-node fallback because its allocation cursor
already includes an overshoot. When such a probe cannot fit the quota, the
adapter returns unsupported without calling the physical backing allocator or
setting sticky refusal. The actual allocation fallback still reserves its full
request and sets refusal if it cannot fit. A real allocation refusal cannot be
ignored to produce a successful stream.

A cap can therefore select an allocation fallback with lower requested peak
than an unlimited in-place-resize path while preserving every wire byte. An
unlimited profile's peak is a sufficient cap, not necessarily the smallest cap
for every backing allocator. Tests fix exact D/D-1 boundaries for paths with a
stable allocation shape and warmed occupied capacity. Supporting-resize tests
also measure a feasible lower fallback peak independently rather than treating
unlimited D-1 as necessarily infeasible.

Quota failures return `WorkingMemoryLimitExceeded`; physical allocator failures
return `OutOfMemory`. A tracked reset/preheat failure is propagated, and sticky
refusal is checked before successful append publication. Append failure restores
the original logical prefix. Spare bytes and arena consolidation/cursors may
have changed after the operation started; the arena remains reusable and keeps
valid physical ownership. Default untracked reset continues its historical
preheat-failure fallback.

The public facade is in `src/deflate/encode/sync_flush_encoder.zig`. The backing
scope, allocator adapter and node accounting are cohesive modules under
`src/deflate/encode/arena_budget`. True incremental stream encoders still reject
these one-shot controls and require a separate lifecycle resource contract.

Targeted native validation:

```sh
zig build -j2 test -Droot-test-filter='Deflate arena' --summary all
```

32-bit validation uses the same contract functions:

```sh
zig test src/deflate.zig -target wasm32-wasi -OReleaseSafe -fsingle-threaded \
  --test-filter 'Deflate arena' --test-no-exec --stack 8388608 \
  -femit-bin=/tmp/vort-deflate-arena-budget-20261110.wasm
node tools/deflate/clone/wasm_gate.js \
  --output /tmp/vort-deflate-arena-budget-20261110-wasi.json \
  /tmp/vort-deflate-arena-budget-20261110.wasm
```

Independent physical observers cover fresh/warm wire identity, complete node
headers, different FBA pointer domains, null-policy reuse, quota rollback, real
OOM and allocation-failure cleanup, same/different inherited ledgers, and
supported/unsupported growth. Non-adjacent random repeated chunks verify real
cross-slice history matching rather than independent per-slice compression.

The native supporting-resize fixture observed 517593 requested bytes without a
cap and 387689 bytes with the feasible fallback cap, with identical wire. Native
results, exact source hashes, validation commands and the executed WASI receipt
are retained in `docs/performance/data/deflate-arena-budget-20261110/`. These are
resource-contract checks and do not claim codec throughput improvement.
