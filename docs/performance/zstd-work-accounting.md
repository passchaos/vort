# Zstd production and diagnostic work accounting

Date: 2026-10-25. Baseline production: `e4bfdd63`, after the
[paired-anchor diagnostic experiment](zstd-paired-anchor-experiment.md).
The industry-best functionality/performance objective remains open.

Inspection of the previous encoder found that stopping profile export did
not eliminate the shared cost-cache function's Work updates. This increment
makes pure work accounting a compile-time specialization of that internal
pipeline. Normal unindexed multi encoding uses the untracked type; the
diagnostic profile uses the tracked type. Candidate admission, pricing,
certificate refresh, hash pairing and final emission keep their existing
rules. No encoder option or runtime flag is introduced.

## State and behavior

Existing `Cache(Codec)` and `Cache(Codec, mode)` factories still select tracked
behavior. New `CacheWithAccounting` factories accept a comptime boolean,
which the internal multi driver supplies from its existing `profile_work`
parameter. The winner's inner exact cache uses that same choice.

For untracked types, exact Work, winner Work and the diagnostic certificate
age occupy no storage. Their updates, bucket selection, maxima and statistical
comparisons are excluded at compile time. The age is not a cutoff or refresh
input. The actual certificate, frequency snapshot, Huffman tree, lower bound
and costs remain present. Reference callbacks still execute when a test Codec
provides them, even if their feedback is not stored.

Histogram `scanned_bytes` and `update_count` remain checked state. Their
overflow admission, invalid-cut handling, range/frequency mutations and header
error ordering are unchanged. This increment does not use a bounded internal
lifetime as a reason to weaken generic caller-state checks.

| Compiled target | Tracked cache sizeof | Untracked cache sizeof | Difference |
| --- | ---: | ---: | ---: |
| Native x86-64 | 6032 B | 5568 B | 464 B |
| x86-linux-musl | 5980 B | 5516 B | 464 B |

These measured values describe the cost-cache object, excluding input,
other stack frames, allocator bookkeeping and process RSS. Removing fields
does not establish a whole-process memory ranking. An initial mixed-target
probe invocation was corrected to apply the x86 target to both modules; only
the successful final probe supplies the 32-bit dimensions.

## Independent semantic checks

The accounting filter passes 11/11 in native Debug, native ReleaseFast and
actual x86 ReleaseFast. It compares complete returned success/error values,
external Codec callback logs, Prepared values, histogram state, tree entries,
certificate contents and finder winners across the two types. It never reads
untracked Work fields to invent feedback. Cases cover shadow/prune, equal-cost
longer matches, support changes, null/raw/RLE/small fallbacks, header failure,
histogram overflow atomicity and callback side effects. Tracked wrapper/type
compatibility and u64 saturation remain separately checked.
The complete native ReleaseFast Zstd family passes 1102/1102.

The production Codec has no reference callback. Generic test Codecs retain
their observable callbacks in both modes. Verification callbacks and pure
statistical comparisons are different contracts; removing feedback is not
permission to remove external side effects.

The pinned old/new ReleaseFast public executables confirm the different
instantiations in the actual unindexed multi caller. The old function has
twenty-one static saturating Work update sites and two bucket-selection
`lzcnt` sites; neither category remains in the new function. Checked histogram
addition/overflow branches, counter commits, certificate data/flags and the
actual pricing path remain. This is evidence of removing those statistics,
not a claim that all integer updates or safety accounting are absent. The
function's machine-code size falls by 1000 bytes in this build; size is not
presented as a performance, total-stack or RSS measurement.

## Public encoder and diagnostic evidence

The newly captured fourteen-input old-production control contains five
alternating Vort/reference rounds per row. Inputs are frozen 64 KiB prefixes,
the full level-3 policy is unchanged, and the competitor is the explicit local
libzstd 1.6.0 file from checkout `01b7154f`. CPU8, i7-10700K, ReleaseFast and
target `skylake+pku+sgx` provenance are retained with source/executable/input
identities. No compiler process is observed in that control.

The new fourteen-row five-round control preserves all Vort and reference
frame lengths/hashes and settings, with a geometric version throughput ratio
of 1.01083x. Its XML/source medians are 579.800/223.357ms, while MR measures
517.008ms versus the old 501.420ms (0.96985x). These small point differences
receive no statistical-significance claim. The new/reference throughput
geometric ratio is 0.00393447x, with zero throughput wins. Compression sizes
remain 310,437/328,241 total bytes, with thirteen smaller Vort frames. Requested
reference-file identity does not verify the complete loader dependency closure.

The initial negative MR point triggered an additional control: three version
process pairs alternate old/new order, with five Vort/reference rounds for each
of MR, XML and source per process. Every pair preserves frame identities and
observes no compiler processes. The median of the three process medians is:

| Input | Old process-median median | New process-median median | Version point ratio |
| --- | ---: | ---: | ---: |
| MR | 503.652 ms | 497.533 ms | 1.01230x |
| XML | 596.637 ms | 579.964 ms | 1.02875x |
| Source code | 228.248 ms | 223.257 ms | 1.02236x |

All nine input/process-pair point comparisons favor the new version. These
supplemental controls support a modest local improvement; they do not erase
the earlier MR result or establish confidence intervals, all-platform speed
or a broad stable ranking. The measured cache-object reduction and cleaner
separation from diagnostics are independent of the throughput conclusion.

The public tracked diagnostic retains every XML/MR work field and exact
candidate hash, including its original tracked cache size. Its elapsed values
are excluded from normal-encoder comparisons. Independent old/new Vort-only
XML probes have identical 2,561,185-byte requested-heap peaks and all 282
allocation/free events, same output and zero live bytes after caller release.
Tiny backing-OOM cleanup passes. A Git HEAD transition during candidate build
records a source-identical commit, rather than a rebuild or a change to the
tested code. No RSS or resource-probe duration is used for ranking.

The complete native Zstd family passes 1102/1102 and all build checks pass
172/172. Broader levels, streaming, 1 MiB, ARM64 and symmetric competitor
memory evidence remain separate work.

After pulling with rebase, the accounting filter passes 11/11 again with
unchanged source manifests. CLI help passes its seven-step build/run check.
The [evidence package](data/zstd-work-accounting-20261025/artifact-manifest.json)
retains the complete original screen, supplemental process controls, verified
raw rounds/settings/output identities, unchanged tracked diagnostics, source
and ELF reviews, state dimensions, heap events and final verification.
