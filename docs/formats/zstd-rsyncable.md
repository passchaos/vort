# Zstd rsyncable parallel Jobs

`ZstdParallelOptions.rsyncable` makes the one-shot parallel frame encoder cut
Jobs at content-defined synchronization points. The wire format remains
standard Zstandard; only the internal Job boundaries change. A small edit in
the input therefore rewrites only the Job that contains it, and later Job
boundaries stay aligned with the unchanged suffix.

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
- `ZstdParallelProfile.job_count` reports the actual submitted Job count after
  the operation; the geometry count remains an upper bound during admission.
- The default is `false`, so existing frames and benchmark rows are unchanged.

## Scope

Only the explicit one-shot parallel frame APIs expose the option through
`ZstdParallelOptions`. The persistent incremental parallel encoder and the
seekable-frame encoder keep their fixed or independent-frame boundaries.
Rsyncable output is a normal Zstandard frame and decodes with any conforming
decoder; it is not a new container or dictionary mode.

## Validation

Tests cover the upstream minimum Job size, hit-mask construction, deterministic
and minimum-block-bounded boundaries, the edit-at-a-boundary shift property,
end-to-end decode through Vort and the Zig standard-library decoder, repeated
encode determinism, serial/multi-worker byte equality, and the reported actual
Job count. The existing parallel frame and queue contracts continue to pass.
No performance or RSS claim follows from this functional control.
