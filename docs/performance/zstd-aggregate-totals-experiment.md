# Zstd incremental total-frequency experiment

Date: 2026-10-25. Baseline production: `6b262754`, after
[work-accounting separation](zstd-work-accounting.md). The industry-best
functionality and performance objective remains incomplete.

This experiment attempted to avoid the per-query four-stream frequency merge
by maintaining a 256-symbol aggregate as stream bytes entered or left the
current cut. It preserved outputs and passed correctness tests, but its public
encoder result did not justify adding another approximately 1 KiB of state.
The implementation has been withdrawn; production source is restored to the
baseline. Candidate implementation/test files are archived as text for
reproduction and are not compiled as part of the library.

## Implementation and verification scope

The candidate stored u32 aggregate frequencies, an active-symbol count and an
initialization flag. Controlled histogram initialization enabled it; each
existing stream addition/removal updated the aggregate and zero crossings.
The original four-stream total methods remained independent. Candidate cost
preparation copied the owned aggregate after one successful cut update, or
used the existing merge if the summary was not initialized. Full Prepared
frequency validation and certificate analysis were preserved.

During stream repartition, bytes may enter their new stream before leaving
their old stream. The temporary aggregate can therefore reach old plus new
regenerated length, at most 262144. u32 preserves that intermediate state;
clamping to a single block size would be incorrect. After the complete update,
the aggregate equals the sum of the four stream rows. Cut and work-counter
admission errors occur before mutation, while header errors retain the newly
updated cut exactly once.

The candidate's focused tests passed 13/13 in native Debug, native ReleaseFast
and actual x86 ReleaseFast. Tests compared physical prefix/tail byte counts,
four-stream rows, aggregates, active counts, owned snapshots and the complete
Prepared/cost results. They covered tiny exhaustive cuts, random transitions,
one/four-stream boundaries, 128 KiB, temporary 2N counts, zero crossings,
same-address reinitialization, invalid-cut/counter overflow atomicity,
uninitialized-state fallback and injected header failures. These passes
validate the candidate's tested behavior; they do not establish the quality of
every future aggregate design.

Compiled cache object sizes increased:

| Target | Previous tracked/untracked | Candidate tracked/untracked | Added bytes |
| --- | ---: | ---: | ---: |
| Native x86-64 | 6032 / 5568 | 7072 / 6608 | 1040 |
| x86-linux-musl | 5980 / 5516 | 7012 / 6548 | 1032 |

These are object sizeof values, not heap, process RSS or total stack. No
competitor memory ranking was measured.

## Full-path measurements and rejection

Measurements use frozen 64 KiB inputs on an i7-10700K, ReleaseFast, target
`skylake+pku+sgx`, CPU8 and Zig 0.16.0. The public encoder compares the same
full level-3 policy against the explicit local libzstd 1.6.0 file from checkout
`01b7154f`. Each old/new executable process contains five alternating
Vort/reference rounds per input. Source, input, executable and requested
reference-file identities remain unchanged, and compiler observations are
zero. The file identity does not prove complete loader dependency closure.

| Input | Old public median | Candidate median | Version point ratio |
| --- | ---: | ---: | ---: |
| XML | 571.960 ms | 581.149 ms | 0.98419x |
| MR | 494.025 ms | 494.485 ms | 0.99907x |
| Source code | 221.186 ms | 233.971 ms | 0.94536x |

The fourteen-row throughput geometric version ratio is **0.988277x**. Four
median point estimates improve and ten decline. All Vort and reference frame
lengths/hashes and settings remain unchanged; both sample reports pass the
independent gate with seventy raw rounds. Small differences receive no
statistical-significance claim, and this result is not an all-level/platform
ranking. It provides no evidence that this particular default implementation
improves the required public throughput.

A separate tracked candidate-stage control uses three alternating version
process pairs. Its XML/MR/source median point ratios are 1.00906x, 1.00580x
and 1.01113x. All previous work fields and block hashes remain identical,
excluding the explicitly changed cache object size. The net timings do not
show a worthwhile benefit after including the additional per-byte maintenance.
The source work reduction does not establish a CPU-time attribution, and the stage
points are not substituted for the unfavorable public result.

The candidate is rejected because the measured public benefit is absent while
state and update complexity increase. No new default aggregate, allocation,
level policy or quality limit is retained. The source files are restored byte
for byte to `6b262754`, and the final change consists of experimental evidence.
No complete candidate-family/build or resource campaign is claimed: rejection
occurred after the narrow correctness and full-path performance evidence.
The restored production literal-cost filter passes 19/19. Its source manifest
matches the baseline; these checks verify restoration rather than promote the
rejected candidate to a completed runtime feature.

The [evidence package](data/zstd-aggregate-totals-20261025/artifact-manifest.json)
retains commands, source manifests, candidate text files, old/new raw samples,
diagnostic work data, object sizes and the restoration check. These data can
guide a different future approach; they do not rule out all incremental
histogram or certificate designs.

The next investigation targets the complete Brotli q8 candidate pipeline,
whose current documented encoding gap is much larger than these small Zstd
preparation differences. Existing legacy-fast stage tools do not measure that
q8 pipeline. The archived read-only plan describes a candidate cost report for
frozen Mozilla/source inputs, with unchanged lazy/optimal searches and full
wire arbitration. No such profile or Brotli optimization is claimed completed
by this experiment.
