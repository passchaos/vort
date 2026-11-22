# Brotli inherited fixed-record candidate prototype, 2026-11-20

The ordinary one-shot q11 quality core already retains the complete
same-options q10 winner. Both qualities then regenerate the quality-independent
fixed-record candidate over the same input, format, window, metadata,
distance-search and literal-context settings. The isolated prototype skips
the second record plan, command construction, distance refinement and wire
generation. It retains the current independent lazy/model/context/split work;
full removal of q11's recursive q10 operation remains a larger architecture
task.

The production patch is one condition and two explanatory lines. It has not
been applied to the mainline or accepted as a performance improvement.
Current legacy, HQ, dictionary and chunked/incremental routes remain controls.

Clean native before/after comparison passes all 95 rows: 60 q11 record targets
and 35 controls, with complete wire identity, normal/exact decoding, exact-peak
cap success, peak-minus-one refusal and zero actual allocator final-live bytes.
Identical prototype-only counters show target plan/generator entries decreasing
from two to one, 21–31 fewer allocation attempts and 296,624–2,389,734 fewer
cumulative requested allocation bytes. All target peaks remain unchanged.
These generator counters do not count lower-level physical wire emissions.

The native libbrotli 1.0.9 oracle verifies 91 rows with full consumption. Four
external-dictionary rows use attached native decoding and before/after wire
identity. x86 and WASI each execute a separate 12-row portability matrix;
every wire hash matches the native reference and 108 native replay receipts
verify their content. This portable scope is smaller than the native 95-row
matrix. Backing OOM indices zero, one and two preserve cleanup and retry.

[Frozen evidence](data/brotli-q11-record-covered-20261120/) retains clean and
instrumented results, scope boundaries, portability summaries, source patch
and replay tooling. The subsequent 60-row acceptance attempt used the current
Huffman functional repair, matching ReleaseFast record objects, synthetic
record targets, original Silesia controls and q0--q3 controls. Two CPU2 epochs
stopped after 52 and 133 pairs under the original environment guard. A CPU6
attempt stopped during calibration, with no formal samples. No complete clean
15-sweep epoch exists, so the improvement bar was not evaluated and the patch
remains unadopted. Partial epochs are retained without pooling or ratio
selection. All temporary tool-runtime thread affinities were restored and
verified; the GDM process was never modified.

[Stopped acceptance evidence](data/brotli-q11-record-acceptance-20261120/)
retains each epoch, preparation/resource checks, source/build identity and
restoration receipts. Adoption requires a future stable paired end-to-end
matrix meeting the repository thresholds. No throughput, peak-memory reduction
or industry-leadership claim is made.
