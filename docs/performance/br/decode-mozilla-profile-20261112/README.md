# Mozilla Brotli decode profiling and rejected screens

This package preserves the frozen `5fb4c6957342ba51af6902172af02a5369e020cb`
baseline, three Mozilla header diagnostics, three perf recordings, and two
small candidate screens. The candidates were **not merged**. The original
baseline manifest retains 216 fixtures and cold tasks, while its summary
retains **`complete=false`, 3 completed rows, 216 expected rows**. This is a
targeted development-host investigation, not a full acceptance matrix or
industry ranking.

The selected producer wires are reused byte for byte from the existing modern
decode corpus. The reference is Brotli 1.2.0. Frozen source, executable, input,
wire, reference paths/hashes, balanced raw pairs, host observations, and original
stdout bytes are retained. Reference shared libraries and large corpus/wire
payloads are reused by hash from the existing modern decode package.

## Per-row baseline and screen results

Baseline time ratios are geometric means of all six paired
`vort_ns/reference_ns` observations in each row. Values above one mean Vort
took longer. Each row retains two warmup pairs. The 1 MiB row uses 20 decodes
per side per batch; full rows use one.

| Fixture | Baseline paired time ratio |
| --- | ---: |
| Mozilla full, q11 | 2.051069925628395 |
| Mozilla 1 MiB, q11 | 0.8862358272742067 |
| Mozilla full, q6 | 1.627189892459272 |

The original summary's **1.8268771857215018** combines the two full rows.
It is not the q6/full result. Its fixed-row confidence interval is preserved
as original evidence; it does not describe unmeasured corpus rows.

Each candidate screen has four interleaved process pairs for each of the three
fixtures: **24 child events**. Process ordering alternates baseline/candidate
and candidate/baseline. Each child retains two warmup pairs and two measured
pairs, giving **48 measured and 48 warmup pairs per screen**. Producer screen
statistics use the geometric mean of four ratios of the Vort-side child
median batch durations (`baseline/candidate`). Values above one mean the
candidate was faster in this screen.

| Fixture | Pointer cache screen | Packed planes screen |
| --- | ---: | ---: |
| Mozilla full, q11 | 1.0528652947117587 | 1.047527093862721 |
| Mozilla full, q6 | 1.0530285526757057 | 1.0298446717349699 |
| Mozilla 1 MiB, q11 | 0.9976543818787503 | 0.9992930392439617 |

The original per-screen summaries remain exact. The independent receipt also
reports geometric means from the eight aligned measured raw pairs, labeled
separately because that statistic differs from ratios of child medians.
Neither screen demonstrates the 20% weak-row improvement bar, runs the full
72-row acceptance/control matrix, or supplies dedicated-host acceptance
evidence. The packed layout can add up to **512 KiB of stack storage**; the
small target wins do not justify merging it under the stated gate.

## Perf and header attribution limits

The perf runs use `cycles:u`, frequency 499 Hz, and
`--call-graph dwarf,16384`. They sample the entire isolated child, including
startup, two warmup pairs, six measured pairs, both implementations, output
initialization, and post-batch validation. Durations recorded under perf include
sampling overhead and are diagnostic, not additional competitor evidence.

The [complete root audit](root-attribution-audit.json) preserves integer
period-weighted self/inclusive counts. The q11/full recording has 1,917
samples and total period 18,438,825,507, with zero reported lost samples.
The ELF contains `br.decodeStreamInto`, but **no recorded callchain contains
that exact public root**. Its denominator is zero, so the audit's strict-root
percentages are `null`; this does not mean the decoder did no work.

Observed `br.` descendant union and generic payload-root scopes are conditional
local observations. Their denominators are 10,476,269,254 and 9,564,092,283
respectively. Their inclusive percentages overlap and cannot be added or
treated as whole-call stage times. The generic native payload symbol is
`br.processWideExternalLiteralLookupCompressedPayloadNative__anon_37334`;
there is no separately emitted `genericCore(false,false)` symbol in this build.

The wide wrapper subtracts **537,976 bytes** from the stack, excluding register
pushes, while perf captured only 16,384 user-stack bytes. Unknown frames occur
in 1,899 annotated callchains. Zero lost samples therefore does not establish
complete unwinding. Existing records cannot recover missing public ancestry,
separate warmup from measured API samples, or quantify all Vort decode cycles.
The independent verifier re-reduces the preserved complete annotated script,
checks the authoritative counts, and reads the archived ELF symbol/prologue
bytes. The audit also records that a complete `--no-inline` replay agreed with
those target counts; no sampling or replay was rerun during packaging.

Header reports accumulate every compressed meta-block header over two
iterations: 9 headers per q11/full stream, 10 per q6/full stream, and 1 for
q11/1 MiB. Nested prefix-stage clocks overlap the outer tree clocks and must
not be added to the outer-stage sum. The header APIs perform full discovery
decodes and allocation before isolated header timing. Their public output,
immutability, and guard validation is outside timing. These reports identify
diagnostic reconstruction costs, not the public payload route or whole-codec
heap/time.

The original diagnostic executable and unchanged original tool source are
preserved. Header reports did **not export measurement-time executable or
source SHA-256**, and no separately saved original header build metadata was
found. Source path/creation order support their association; the package does
not retroactively invent an exported identity. The main tool commit
`840b99a5` and final build proof belong to later validation.

## Exact package contents and source identities

| Artifact | Contents |
| --- | --- |
| `baseline-source.tar.gz` | All 2,044 files in the measured source registry; each matches the baseline Git blob. |
| `candidate-sources.tar.gz` | Exact first-screen `cache-pointer-screen-br.zig` and patch; exact second-screen frozen `br.zig`, `packed_aux_lookup.zig`, and `packed_aux_planes.zig`. |
| `probe-binaries.tar.gz` | Baseline, recovered pointer-cache candidate, packed-planes candidate, and original header diagnostic executables. |
| `pairs-raw.tar.gz` | Exact full manifest, partial summary/CSV, all three row JSON/stdout/stderr/RSS files, fixture reuse, and host observations. |
| `cache-screen-raw.tar.gz`, `packed-planes-screen-raw.tar.gz` | Exact manifests, 24 events and complete stdout/stderr bytes, event list, and original three summaries per screen. |
| `perf-recordings.tar.gz` | All three perf.data files and complete producer stdout/stderr/report JSON, perf manifest, q11 stacks/symbols text, and complete root audit. |
| `runners-diagnostics.tar.gz` | Exact four Python runners, logs, selected fixture/reference metadata, three header JSON reports, and stderr files. |
| `validation-supplement.tar.gz` | Later header build/alias checks and payload correctness proof, with separately frozen validation source. |
| `baseline-summary.json`, `baseline-matrix.csv.gz` | Exact original summary and CSV bytes. |
| `baseline-matrix.csv` | CSV with CRLF changed to LF only; raw CSV bytes remain compressed. |
| `selected-fixtures.json`, `root-attribution-audit.json` | Exact readable copies for navigation. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Member-byte hashes/origins, independent offline verifier, final read-only verification receipt, and complete package inventory. |

All archives use GNU tar with sorted regular files, uid/gid/mtime zero, empty
owner names, and modes 0644/0755. Gzip uses level 9, no filename, and timestamp
zero. Original text bytes, including line endings and line-end spaces, remain
unchanged inside archives.

| Measured executable | SHA-256 |
| --- | --- |
| Baseline | `9bb054933076e6faca6277f9763ac7f4ae4977d2713ce649d7d67cb9b9a86e41` |
| Pointer cache | `73bfb778aaf2e5c01cf6b2423ac8fd132a72de7854672452497900b7fe405d1f` |
| Packed planes | `f958e61691c0f08a55938772c05516bef511d986a4fd694d4b8954937b8ebafd` |
| Original header diagnostic | `4e4af02e53b9b4aa1670ccb6c2b3ec1865ad216b5baa37b68b1ece2c33b3066a` |

The first candidate installed binary had been overwritten. Its original
matching executable was recovered from the candidate Zig cache by SHA.
The second candidate's **measured source** is the archived
`packed-planes-source/` snapshot, not the later test worktree. Its runner's
`source_with_imported_helpers` expands the normal registry from 2,044 to 2,046
files to cover both new helpers. The immutable baseline plus the corresponding
frozen overlay reconstructs each measured source registry exactly.

## Separate post-timing verification

The main diagnostic tool build completed 8/8 steps and 3/3 parser tests. Five
protected output identities (wire, plain, hardlink, symlink, executable) all
returned exit 2 while preserving protected bytes. This is a functional
pre-read refusal smoke, with no codec timing claim and a different executable
hash from the original measured diagnostic.

The payload worker captured exactly one ReleaseSafe run: 5/5 steps and 22/22
tests. Original stdout/stderr bytes, return code, argv/cwd, and four copied
source files match before/after SHA snapshots. This later source includes a
generic reference wrapper and local test adapter; it is distinct from the
earlier packed-planes timing source. The Debug proof is a transcription of
an already completed tool response, not separately captured raw stdout/stderr
and not retroactively bound to the Safe snapshots. Neither validation proof
adds WASI, full-matrix, or acceptance evidence.

## Offline verification and reproduction

From this directory in the repository:

```sh
sha256sum -c SHA256SUMS
python3 verify.py
```

The standard-library verifier checks complete schemas, preserved partial
completion, every archived file byte hash, all measured source registries and
probe hashes, fixture/reference bindings, complete JSON equality to original
stdout, balanced raw sampling, original summaries, independent per-row and
screen statistics, perf period attribution and ELF prologue, header aggregate
scope, and the separately scoped validation proofs. It uses the existing
reference-library archive by hash and runs no compiler, codec, measurement,
or perf command.

Repeat the optional original-byte and Git-blob checks while the recorded paths
are available:

```sh
python3 verify.py \
  --repo /home/passchaos/project-z/vort \
  --raw-root /tmp/vort-mozilla-profile-20261111.5fb4c695 \
  --fixture-root /tmp/vort-current-decode-matrix-20261111/fixtures
```

When relocating the package, pass `--reference-archive` pointing to
`docs/performance/modern-decode-current-20261111/reference-libraries.tar.gz`.
The five selected plain/wire files are omitted; hashes and generator settings
remain in the manifests. Regenerate or reuse them according to the
[modern decode package](../../modern-decode-current-20261111/README.md).

For source replay, clone a separate checkout at the baseline revision,
extract `baseline-source.tar.gz` into it, and apply the chosen exact archived
candidate overlay to `src/br.zig` and its helper paths. Extract the archived
measured executables to a separate directory. All original invocation argv
and the four unmodified runners remain in the archives. Their absolute paths
refer to the original isolated worktrees; relocate paths in a derived runner
copy and record a new epoch if executing again. Do not rewrite the frozen
manifests to resume with changed source, probes, host policy, or paths.

The original runners enforce CPU 15, single-threaded codec policy,
ReleaseFast Zig 0.16.0, target `skylake+pku+sgx`, exact producer fixtures,
and balanced sampling. The original host used `intel_pstate`, `powersave`,
and enabled turbo. Host observations are preserved; process ticks do not
identify timed-batch overlap. Any future dedicated-host acceptance campaign
needs its own full corpus/control matrix, uncertainty, and resource evidence.
