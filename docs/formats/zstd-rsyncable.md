# Zstd rsyncable parallel Jobs

`ZstdParallelOptions.rsyncable` and
`ZstdIncrementalParallelOptions.rsyncable` cut Jobs at content-defined
synchronization points in the one-shot and persistent incremental parallel
frame encoders. The wire format remains standard Zstandard; only the internal
Job boundaries change. A small edit in the input therefore rewrites only the
Job that contains it, and later Job boundaries stay aligned with the unchanged
suffix.

## Semantics

- The rolling hash uses upstream Zstandard's 32-byte window, prime and
  character offset. A synchronization point is a hash whose low `bits` are all
  set, where `bits = floor(log2(job_size / 1 KiB)) + 10`. The average interval
  is therefore `job_size`.
- A synchronization point is only considered after
  `rsync_min_block_size` (128 KiB) bytes, so it cannot create a Job smaller
  than one maximum-size Zstd block. `job_size` must be at least 512 KiB.
- Boundaries are a pure function of the input bytes and `job_size`. The same
  input produces the same Jobs in serial fallback and multi-worker execution,
  and the resulting frame bytes are identical.
- The incremental encoder scans each offered chunk with the same rolling hash.
  Splitting the same stream into different chunk sizes does not change the
  boundaries or the emitted frame. A hit at the current position seals the
  filling Job without accepting new input; a hit inside a chunk accepts only
  the prefix up to that point.
- `ZstdParallelProfile.job_count` reports the actual submitted Job count after
  the one-shot operation; the geometry count remains an upper bound during
  admission. The incremental admission path charges the minimum-block upper
  bound when rsyncable is enabled.
- The default is `false`, so existing frames and benchmark rows are unchanged.

## Scope

The explicit one-shot parallel frame APIs and the persistent incremental
parallel frame encoder expose the option. The seekable-frame encoder keeps its
independent-frame boundaries. Rsyncable output is a normal Zstandard frame and
decodes with any conforming decoder; it is not a new container or dictionary
mode.

## Validation

Tests cover the upstream minimum Job size, hit-mask construction, deterministic
and minimum-block-bounded boundaries, the edit-at-a-boundary shift property,
chunk-scanner agreement with whole-input boundaries for several chunk sizes,
incremental chunking invariance, serial/multi-worker byte equality, end-to-end
decode through Vort and the Zig standard-library decoder, repeated encode
determinism, and the reported actual Job count. The existing parallel frame,
queue and incremental contracts continue to pass on native, Linux x86 and
actual WASI. No performance or RSS claim follows from this functional control.
