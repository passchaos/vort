# Deflate stream resource diagnostic: rejected

The complete fixed 54-row, two-round diagnostic failed its predeclared 0.98
point floor. The equal-row geometric mean of baseline elapsed ns divided by
candidate elapsed ns is **0.9317892012110397**; **27 of 54 rows** are below 0.98.
`CI=null`. This result cannot enable adoption or a formal release.

| Row | Row GM | Round 0 ratio, AB | Round 1 ratio, BA |
|---|---:|---:|---:|
| `gzip-fixed-out1-structured` | 0.5679957096354561 | 0.559815888123167 | 0.5762950516568847 |
| `zlib-fixed-out1-structured` | 0.56836710628815 | 0.5677520106934192 | 0.5689828682699363 |

The first row's actual baseline/candidate ns were 1,080,153 / 1,929,479 in
round 0 and 1,079,698 / 1,873,516 in round 1. All 108 pairs and 216 children
are retained, including every positive, weak, and noisy row. Every child
actually exited 0. The scalar replay matches every published row point and
raw ratio. The output-quantum grouping is descriptive: out1 GM
0.8398396767086921, out17 GM 0.969626986992003, out4096 GM
0.9934635470049255. It does not replace the original all-row gate.

The next implementation work should inspect the complete structured + out1
lifecycle costs. These two-round diagnostic points provide a rejected screen;
they do not provide confidence intervals or a causal breakdown of costs.

## Fixed comparison scope

This compares Vort baseline Git `d5d9d8aab3d91d34003e25d3e2c6a3fda6b51388`
against the original frozen candidate identified by complete source-manifest
SHA `beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f`.
The candidate source in this package comes from the old epoch's frozen
`sources/candidate` copy. Current production entered a separate default-repair
round after this diagnostic; this package does not substitute its code or
certify that newer source.

The 54 rows are raw/zlib/gzip × fixed/best × output quantum 1/17/4096 ×
structured 4096-byte / opaque 4096-byte / empty payload. Input follows the
original cyclic 1/17/4096 schedule, holds each offered chunk end until fully
consumed, and drains empty input between chunks. All public encoders use
`E.init(allocator)` defaults without parameter, strategy, level, block,
lookahead, budget, window, header, or dictionary overrides.

Each child performs one complete untimed warm operation and then 100 timed
complete owning stream operations. Every timed operation freshly initializes
and deinitializes the encoder, including feed, finish, drain, caller output
collection allocations/copies, owned wire length mix and free. The process's
`std.process.Init.gpa` allocator has been warmed; the encoder is freshly
created for every operation. The 216 children represent 21,600 timed complete
operations plus 216 untimed warm operations. The earlier 108 untimed preflight
records are preserved separately.

| Provenance | Recorded value |
|---|---|
| CPU | Intel Core i7-10700K @ 3.80 GHz |
| Codec affinity / threads | CPU 2 / one thread |
| Zig / build mode | 0.16.0 / ReleaseFast |
| All module targets | `x86_64-linux-gnu`, `skylake+pku+sgx` |
| Baseline complete source manifest | `1636c421524e522632fe051876ee42d1a19223c59d1f030102aff0252e4d51ef` |
| Baseline ELF | `782f2936775811f6fa9305563141dbc76fcf360672d458d072b59f1593f64b1a` |
| Candidate ELF | `6e2df9831a83db4ae068e567fae4e5c3b820d6212523b9bdc11f4a933cefb61f` |

There are no competitor performance samples in this comparison. Python zlib
1.2.11 supplied the original retained external-decode pass records for the
108 preflight wires. This export binds those booleans to the exact original
wire and input identities; it performs no new decode and claims no new EOF,
unused-data, tail, decoded-SHA, memory, or RSS measurements. Timed attempts do
not contain per-child source-before/source-after snapshots. Source provenance
is established by the original build receipts, complete frozen source
registries, original preflight snapshots, ELF/probe identities, and raw
revision/command records; continuous source monitoring is not claimed.

## Preserved first failure and metadata-only repair

The original v1 sampler exited 1 before creating any run manifest or starting
a codec/timer: it read nonexistent `preflight.json.row_definitions` and raised
`KeyError`. Its sampler, release, terminal JSON and output log are retained
unchanged. That failure is not a performance observation.

The subsequent `sampler-v2.py` consumes the existing 108 actual warm records
from `preflight-results.json`. The original PF was not given invented
`row_definitions`. Only the row metadata guard, its identity bindings and
output path changed. The original timed body and reducer are byte-identical
after `diagnostic-v2/` → `diagnostic/` path normalization; normalized SHA is
`ed32bfa11407c66b4525c17e15abeba0f6881803122f1e6675b2e548f50aff68`.
The row/variant/ELF data-only tampering checks, their actual exit 0 receipt,
and 12 original-file before/after hashes are retained.

Root uniquely ran v2 with actual exit 0, session 25587, tool chunk 897097.
The original terminal records UTC 2026-11-27 16:00:16.875697 through
16:01:03.669322. The original producer's diagnostic output
`full_gate_passed=false` means this diagnostic is not complete acceptance.
The old `SOURCE_READY` independently records the old Beb source's functional
whole-library gate: actual exit 0, 419/419 steps, 6108/6110 tests with two
skips. It is historical evidence for that snapshot, not a current pass for
the later default repair.

The immutable protocol's preparation fields `candidate_source=PENDING...`
and `all_releases_false=true` remain unchanged. Actual candidate identity and
authorization come from the retained execution bindings, `SOURCE_READY`, and
Root's `release-diagnostic-v2.json`. The retained readiness seal predates the
v2 outputs; the new archive inventory separately hashes all 864 diagnostic
artifacts.

## Portable package and data-only verification

- `epoch-data.tar`: uncompressed data archive, 5,860 ordinary members. It
  contains all 216 raw JSON/wire/stdout/stderr sets, all 108 original warm
  sets, both native ELFs, probe/provenance/build receipts, three inputs,
  complete baseline 2,250-file and candidate 2,267-file source copies,
  metadata repair, original v1 failure, v2 release/terminal, and all five
  external original whole-library receipt/log/source artifacts.
- `evidence-manifest.json`: exact original-absolute-path → archive-member
  mapping, sizes, hashes, artifact roles, tool provenance, and original data
  verification result. Raw files and their absolute path strings are not
  rewritten. `epoch/` and `whole-gate/` are the two explicit namespaces.
- `verify-evidence.py` and `package_io.py`: read only the archive, require
  exact safe member inventory and SHA, compare full wires byte for byte,
  validate every raw ns/mix/step/argv/input/ELF/source identity, and independently
  replay all 54 row points and their equal-row GM without importing a producer.
  The archive store is adapted from the existing portable export adapter;
  paired point replay follows the existing evidence verifier.
- `check-portable.py`: runs the same verification while denying original
  host `/tmp` file reads. Actual exit 0 proves the copied package can be
  checked without the original temporary paths.
- `row-points.csv`, `rejection-summary.json`, `verify-output.json`: full row
  points and refusal result. No filtered subset or bootstrap is used.
- `export-terminal.json`, `verify-terminal.json`, `portable-terminal.json`:
  actual data-only process exits and stdout/stderr identities.
- `SHA256SUMS`: final top-level package file inventory and hashes.

From this directory:

```sh
sha256sum -c SHA256SUMS
python3 -B verify-evidence.py --package .
python3 -B check-portable.py
```

Export, copied-data verification, and host-path-denial verification all exited
0. No captured executable, codec, build, new sample, RSS observer, or bootstrap
was executed to create or verify this package. Only this new documentation
directory was written; the original epoch was preserved and no commit made.
