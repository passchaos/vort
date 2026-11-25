# Complete q8 context histogram diagnostic, 2026-11-26

The twelve fixed 64 KiB inputs produce **103 context analyses**, including
**29 exact repeated histograms**. All 29 repeat the complete suffix,
up-to-16 and full proposals. **Twelve repeated records have different command
field digests from their earliest matching histogram**, one per input. The
remaining seventeen have the same command digest; that does not establish
exact command-list equality. No snapshot or context event is truncated.

This is an untimed diagnostic. It establishes a larger possible sharing
boundary than one immutable command slice, not a throughput improvement or a
competitor ranking. No production implementation or preset changes here.

## Frozen source and operation

The source copy starts at `7bb7ee116c93be1850133be8727bbce9856519ad`.
The archived source identity contains 2,197 files: 2,191 match their base Git
blobs, four existing hook/profile/tool files change, and two diagnostic files
are added. Full identities match before and after the final capture. The
production Brotli source at that revision also matches the `c2c8f250` baseline
used by the controlled historical q8 regression report.

The probe calls public q8/generic/explicit-window16 allocating encoding. Its
ordinary and instrumented calls compare complete output bytes against the
ordinary oracle; each input also round-trips through Vort decoding. All twelve
initial wire hashes and lengths match the previously cross-library-verified
c2 wires. There is no new external decoder execution in this diagnostic.

The frozen binary uses Zig 0.16.0 ReleaseFast, `x86_64-linux-gnu`,
`skylake+pku+sgx`, CPU3 and one codec thread on an Intel Core i7-10700K.
Provenance, exact argv, successful exits, ELF gzip and the codec record object
are retained. The ELF SHA256 is
`a96ecc8a207f0f53fa8eaeb008c5f9eb0695e66a7929e541bf3f6711e7a7348b`.
All fixtures retain their original 65,536 bytes without normalization,
repetition or padding. This is one diagnostic round per row.

## What is compared

Each complete `Analysis` snapshot stores exactly 263,176 canonical bytes:
literal count as u64 little endian, all 256 total counts as u32 little endian,
then all `[4][64][256]` context counts in mode/context/symbol order as u32
little endian. SHA256 includes the diagnostic domain and version. Digest
equality is only a prefilter; every candidate match compares all bytes.

The evidence freezes the complete chooser, pruning, mode order `[0,1,2,3]`,
cluster inclusion, maximum 64 trees, savings gate and suffix-map cost policy
with the source and target epoch. Each proposal compares null presence, mode,
tree count, all 64 context-map entries and savings bits. Null Analysis remains
distinct from a present zero histogram in the focused fixtures.

Command fingerprints cover all declared command fields, including nested
optional HQ encoding. Integers and enums use u64 little endian; booleans and
optional presence use one byte; structs recurse in declaration order. No
pointer or struct padding is hashed. Different digests establish different
fields; equal digests do not prove exact command equality. Command field bytes
are not separately archived, so the offline verifier checks digest format and
frozen instrumentation provenance rather than independently rebuilding those
digests from command lists.

All records carry operation ordinal, actual context event ID, origin, variant,
input size, command count and pruning policy. The existing profile retains
only its first eight context details; those prefixes are checked where
available. The independent sixteen-slot snapshot covers all 103 analyses.

## Results and measurement limits

| Input | Analyses | Exact repeats | Different-command-digest repeats |
| --- | ---: | ---: | ---: |
| dickens | 9 | 2 | 1 |
| mozilla | 10 | 3 | 1 |
| mr | 9 | 3 | 1 |
| nci | 8 | 2 | 1 |
| ooffice | 8 | 2 | 1 |
| osdb | 9 | 3 | 1 |
| reymont | 8 | 2 | 1 |
| samba | 9 | 2 | 1 |
| sao | 8 | 3 | 1 |
| webster | 9 | 2 | 1 |
| x-ray | 8 | 3 | 1 |
| xml | 8 | 2 | 1 |

The repeated records execute **20,379 tree scorer calls**. Their original
baseline/suffix/sparse/clustering diagnostic durations remain in the raw
records and reduced summary. Those durations are not a predicted speedup.

The collector allocates a fixed **4,218,496 requested bytes** before codec
entry, separately from codec heap. Capture, command fingerprinting, finish and
stage recording allocate nothing. Every original analysis, scorer and codec
allocation/free still executes. `codec_requests_skipped: 0` is a source audit
statement, not a measured resource campaign. No RSS, total codec heap, stack
or resource-cap improvement is claimed.

Direct observer work is outside the original context stage timers and is
subtracted from the inner profile total. Outer context events and call wall
times still include it. Snapshot and hashing cache effects cannot be removed
by timestamp subtraction; all normal/profile wall times are diagnostic only.
Ordinary observer branches erase at comptime in the reviewed source; generated
machine code was not audited for that statement.

The final focused runner passes **12/12 tests**: eleven fixtures plus the
import test. It covers canonical layout, complete equality, forced collisions,
context-only changes, null, bounded capacity, proposal fields, nested command
identity, initialization failures and caller-owned lifecycle. Actual valid
operations report no errors. Analysis errors before a ticket is created have
no snapshot failure record, and the tool exits without writing a failed codec
operation; this evidence does not claim complete failure-event capture.

## Retained evidence and verification

`raw.tar.gz` retains the complete frozen source closure, exact fixture bytes,
all final canonical snapshots and profile JSON, source/Git and wire bindings,
build/run receipts, focused logs, executable gzip, record object and scripts.
The first successful capture without command fingerprints is also retained
under `first-capture/`, including its source overlay and raw snapshots. It is
superseded for command identity and contributes no final summary counts.

`archive-bindings.json` binds every raw member by length and SHA256.
`summary.json` is the independent reduction of the final capture.
`verify.py` checks published checksums, archive membership, frozen identities,
all full histogram comparisons, earliest priors, proposal results, event
links, counters and the summary without running a codec:

```sh
python3 /path/to/context-histograms-20261126/verify.py
```

## Next implementation boundary

Prototype sharing complete proposals after actual collection and threshold
handling, using full histogram equality plus the frozen chooser policy.
Retained storage must have explicit ownership and charged memory limits;
changing allocation work must preserve correct OOM/quota classification and
cleanup. Keep all original candidate arbitration and complete current wire
bytes. The earlier zero full-model/command-result hits do not contradict these
histogram repeats.

The candidate still needs cold complete-operation and public-control A/B,
resource caps, native/x86/WASI contracts, at least 3% aggregate throughput gain,
NCI at least 20%, confidence excluding parity and every control at least 0.98x.
Do not translate the 29 repeated records or diagnostic durations into an
accepted performance claim. Preserve the rejected v4/v5/v6 implementations.
