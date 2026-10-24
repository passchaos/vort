# Brotli total encoding memory functionality

Date: 2026-10-24. Codec revision: `2bd19ee8`; CLI revision: `ccbfd60b`.
The frozen codec includes `src/br.zig` SHA-256
`494c994eb7793395cde6f04e23930c15b11e18009897eaf8e8d909b19a3df869`.

The [total-memory contract](../formats/brotli-total-encode-memory.md) defines
operation-wide requested-heap accounting for every planned level, qualities
0...11, and explicit HQ. This milestone closes the earlier HQ-only workspace
quota boundary for encoder-owned heap. Broader compression performance and
industry-best goals remain active.

## Final functional evidence

| Gate | Result | Evidence |
| --- | ---: | --- |
| Total-memory Debug / ReleaseFast | 53/53 each: 41 named + 12 anonymous | [Debug](data/brotli-total-memory-20261024/debug.json), [ReleaseFast](data/brotli-total-memory-20261024/release-fast.json) |
| x86-linux-musl ReleaseFast | 53/53: 41 named + 12 anonymous | [x86](data/brotli-total-memory-20261024/x86.json) |
| Full Brotli ReleaseFast | 1156/1156 | [Family gate](data/brotli-total-memory-20261024/family.json) |
| Reference validation | 15 rows; 104 probes: 73 successes, 31 expected limit refusals | [Report](data/brotli-total-memory-20261024/reference.json), [summary](data/brotli-total-memory-20261024/reference-summary.json) |
| Reference interoperability | 27 bidirectional successes; three system RAW skips | [Artifact binding](data/brotli-total-memory-20261024/reference-binding.json) |
| CLI | 44 round-trips; 14 profile-wire, 14 exact-cap, 14 below-cap; 44 preserved rejections; two same-path | [CLI](data/brotli-total-memory-20261024/cli.json), [gate](data/brotli-total-memory-20261024/cli-gate.json); 9/9 steps and eight parser tests |
| Wasm public consumer | 7/7 steps; 4097 bytes; exact/below caps; two HQ round-trips | [Wasm](data/brotli-total-memory-20261024/wasm.json); Node v26.10.0, q0/q11 total checks, `imports=[]` |
| Complete build check | 147/147 | [Check](data/brotli-total-memory-20261024/build-check.json) |

The dedicated gate contains QA21, primitive12 and generic8 named tests. Its
actual ELF name lists confirm those 41 named tests and 12 anonymous roots in
all three modes. The five scoped-static-index tests occur separately in the
complete Brotli ELF. [Coverage](data/brotli-total-memory-20261024/coverage-summary.json),
[Debug names](data/brotli-total-memory-20261024/coverage-debug.json),
[ReleaseFast names](data/brotli-total-memory-20261024/coverage-release-fast.json),
[x86 names](data/brotli-total-memory-20261024/coverage-x86.json) and
[scoped family coverage](data/brotli-total-memory-20261024/coverage-family-scoped.json)
preserve the independent enumeration and compilation/run input binding.

The codec gate source digest is `0c0628aa12a9820a93ba07d884c4f4bdb51500ee06d87a4abd8eaeafe22674e1`;
before/after source windows have no changes. The CLI window contains 1679
unchanged files; its actual compilation manifest binds 1884 records and 1882
unique inputs without mismatches. The reference window contains 1693 unchanged
files. Earlier stage results are distinct provenance and are not substituted
for these formal source/binary bindings. The successful build commands omitted
`--verbose`, so exact child `zig test` argv was not logged; actual ELF and
cache/run input digest binding supplies the recorded binary provenance.

## Budget and ownership behavior

`max_total_working_memory: ?usize` and `memory_profile` are top-level controls
on `PlannedEncodeOptions` and `PlannedStreamChunksOptions`. Null limit plus null
profile on a fresh encoder keeps the original allocation path; profile-only
tracking is unlimited. A previously tracked encoder retains stable allocator
control until its owned storage is released.
The prior `997fe5e5` baseline and 26 representative null/profile complete wires
retain byte identity. HQ workspace controls remain independently available.

One stable heap control backs movable leases. Its ledger includes plaintext and
pending output, history, dictionary indices, models, parser workspaces, matcher
forks, command plans, alias snapshots, serialization artifacts and complete-frame
candidates. Complete q10 output stays charged while q11 and eligible legacy
candidates are built. Nested phases share one ledger instead of restarting caps.
Tracked legacy dictionary planning owns its indices rather than using an
uncounted singleton.

Existing reusable and incremental capacity is adopted before tracking starts.
The census uses allocated capacity, includes HQ allocations and owned control,
and excludes inline arrays. A cap below current live owned storage refuses
before reset or replacement of options. A borrowed outer control is not counted
again in an individual retained-storage getter.

Allocating one-shot output stays charged until successful transfer to the
caller's allocator; cleanup leaves reported owned live bytes at zero. Reusable
encoders can retain nonzero live heap after a call because cached buffers remain
encoder-owned. Their call-scoped profiles detach before storage expires while
the allocator control stays valid. Different result allocators reserve quota in
the same ledger before physical allocation; success records actual live bytes,
and failed allocation removes the reservation without inventing a heap peak.

The caller's existing output allocation is excluded. An append replacement is
charged until successful publication hands it off. Input, chunk descriptors,
RAW attachments, serialized views and metadata aliases are protected before
mutation. Publication into encoder-owned output uses an independent temporary
encoder under the same lease, preserving old buffers throughout failure and
keeping their live storage charged. Allocator identity mismatches receive
controlled rejection. Final/metadata retries preserve actual accepted input and
delivered output progress without duplicate publication.

## Measurement and compatibility scope

The limit measures requested encoder-owned heap. It excludes borrowed input and
dictionary bytes, caller pre-existing output, fixed state and stack arrays,
allocator bookkeeping, page rounding, internal transients of a successful backing
remap, and RSS. A separate moving allocation before freeing the old buffer counts
both requests. Reserved quota affects admission; only successful physical
allocation raises the heap profile.

`EncodeMemoryProfile` reports availability, peak, latest live requested bytes and
optional limit. Independent peaks from overlapping lifetimes cannot be summed
to establish a combined peak; the implementation uses their shared ledger.
Total and HQ workspace limits may both return `WorkingMemoryLimitExceeded`, so
the error name alone does not identify the refusing domain. Backing failure
remains `OutOfMemory`; size overflow remains `IntegerOverflow`. Total denial
cannot silently skip a candidate or produce stored success.

Reference helpers bind Brotli 1.2.0 and system 1.0.9. The three known skips are
`one_shot-raw`, `chunks-raw` and `incremental-raw` against system 1.0.9, which lacks
the prepared-encoder/attach-decoder shared-dictionary API. Modern 1.2.0 exposes
that RAW API. Neither public helper establishes serialized interoperability.
Existing reference-library build flags/runtime source revisions were not
independently reconstructed. Validation durations, compiler MaxRSS and these
allocation witnesses establish no competitor throughput or memory ranking.

Large Window HQ encoding, globally optimal model/segmentation choices, broader
competitor ratio and encode/decode-throughput matrices, and RSS evidence remain
work. The existing native 4096-position/finite-beam quality boundary remains
separate from this completed total-heap accounting slice.

## Recorded commands

`zig` is the recorded `/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig`, version 0.16.0.

```sh
zig build -fno-incremental test-br-total-memory -Doptimize=Debug --summary all
zig build -fno-incremental test-br-total-memory -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-total-memory -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br -Doptimize=ReleaseFast --summary all
zig build -fno-incremental run-br-total-memory-diff -Doptimize=ReleaseFast -- --reference /tmp/vort-br-hq-reference-modern.so --system-reference /tmp/vort-br-hq-reference-system.so --output-dir /tmp/vort-br-total-final-20261024-n_7jpt2j/reference
zig build -fno-incremental test-br-total-memory-cli -Doptimize=Debug --summary all
zig build test-br-public-wasm -Doptimize=ReleaseFast --summary all
```

The reference directory was prepared with the frozen baseline and versioned
helpers. The build-check JSON preserves its exact command. Permanent reports
are grouped under `data/brotli-total-memory-20261024/`; the temporary formal
working directory supplies raw provenance rather than a final release location.
