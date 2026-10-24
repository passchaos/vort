# Brotli stored memory evidence

`index.json` lists original text files, byte counts and SHA-256 plus deterministic
tar.gz bundle hashes. Each stage retains its own source and artifact identity.
The original 63-test stage preceded the actual-write-region scratch fix; the
formal 65-test stage and final runtime gates use the corrected implementation.

QA, prepared old wire, formal aggregate, allocator authority, producer checks,
versioned reference, CLI, Wasm, complete family, global and post-rebase checks
are recorded separately. Original fixture/tool failures remain in their stage
reports. Non-input Wasm changes are not labelled as compiled-code changes.

Call-scoped reusable profiles retain their last real measurement and are
subsequently detached; a later deinit must not write to them. Independent final
allocator cleanup and current memory snapshots provide lifetime evidence.
Zero-heap Into and spare Append paths are checked separately from allocating
CLI paths. Resource counts and durations are functional evidence, not a claim
of cross-library memory, compression ratio or throughput leadership.

Full source ZIPs, ELF/Wasm, binary wire files and cache directories are not
repeated in Git. Their hashes and local paths remain in archived reports.
See the [functional baseline](../../brotli-stored-memory-functional-baseline.md)
for exact scope, validation and the incomplete industry-best objective.
