# Zstd HQ repeat-key comparison

HQ beam-state insertion now compares the format's three repeat offsets as
three `usize` words. The existing finite-cost and literal-length guards remain
ahead of these comparisons. Array elements have no padding, so word equality
is equivalent to the former complete byte-slice equality on both 32-bit and
64-bit targets. The module asserts the fixed three-word key at compile time.
Replacement, stable tie ordering, search depth, sampled lengths, prices and
admission budgets retain their existing behavior. No cache or allocation is
added.

The trigger was a two-second CPU-clock sample of the long-running library
Debug test. It attributed 65.37% of samples to `mem.eqlBytes` through HQ
`state.insert`. That sample identifies a hot path; it is not an encoder
benchmark or proof of which individual test was running.

## Ordinary encoding screen

The [evidence package](data/zstd-repeat-key-comparison-20261028/) preserves
baseline `b04a9019`, the single-comparison candidate, source and executable
hashes, exact compilation/measurement commands, raw rounds, complete wires,
and assembly. Runs use Zig 0.16.0 LLVM ReleaseFast, `-mcpu=skylake`, Intel
i7-10700K, one encoder thread pinned to CPU 2. Two existing library test/build
jobs remained active during measurement; these are exploratory observations.

Three deterministic synthetic corpora cover periodic text, varied structured
records and pseudorandom bytes at 1/4 KiB, using btopt and btultra2. Requested
window log is 14, block maximum 16 KiB, and content checksum is enabled. Each
configuration has one untimed profiled encode before one timed ordinary encode
per round. Five rounds reverse baseline/candidate order on odd rounds. Timing
includes the allocating encode API; output free, profiling, hashing, decoding
and filesystem writes are outside the interval.

| Strategy | Corpus | 1 KiB candidate/baseline time | 4 KiB candidate/baseline time |
| --- | --- | ---: | ---: |
| btopt | periodic | 0.3919 | 0.3754 |
| btopt | structured | 0.3606 | 0.3590 |
| btopt | random | 0.9416 | 0.8988 |
| btultra2 | periodic | 0.3452 | 0.3490 |
| btultra2 | structured | 0.2880 | 0.2871 |
| btultra2 | random | 0.9070 | 0.8541 |

For structured 4 KiB btultra2, median ordinary encoding changes from
1169.869 ms to 335.906 ms. Its two passes produce 13,052,491 match transitions
in both versions. The two native insert specializations shrink from 943/945
to 577 bytes and use direct comparisons. All 120 ordinary encodes and 240
native decodes pass. Full wire bytes, input identity and diagnostic strategy,
HQ/refinement passes, depth/nice and transition counts match across variants
and rounds. Random inputs also execute the HQ parser despite zero match
transitions. The first baseline round is sometimes slower; all raw rounds
remain available. These small corpora and background activity do not establish
general gains or superiority over libzstd.

The earlier comparator-only screen covers equal keys, first/middle/last-word
differences and each word's highest bit. Median nanoseconds per comparison are
25.798/6.617/6.010 in Debug and 2.275/1.246/1.307 in ReleaseFast for generic
equality/short-circuit equality/XOR equality. This screen guided the ordinary
encoding experiment; it does not substitute for it.

## Deferred row-pruning variant

A complete `less(candidate, worst)` check before duplicate scanning preserves
the existing sorted-row policy: a candidate that cannot beat the worst node
cannot improve any existing equal-key node. Finite costs also remain eligible
against vacant sentinels. Search admission and transition accounting occur
before insertion, and budgets do not charge repeat-key comparisons.

Three further AB/BA sweeps retain every wire and profile count, but regress
periodic cases by 9.5-14.8% relative to the direct-comparison candidate.
Structured 4 KiB ratios improve to 0.6639/0.5677 for btopt/btultra2. The
additional comparison grows insert code to 944/970 bytes. This variant is
archived and is excluded from production; selective use needs separate
ordinary-call evidence.

## Validation and next work

The reference-insertion contract freezes the former slice equality and
replacement/sorting algorithm. It compares return values and every node field
after 12,288 deterministic insertions, plus explicit cost/literal extremes,
all three repeat-word boundaries, duplicate improvements/rejections, sentinel
ties and row ordering. Node and WholeNode layouts and widths 1/8/16 are covered.
Native and actual 32-bit x86 Debug tests pass; native ReleaseFast and actual
Node-executed wasm32-wasi tests also pass. Current HQ/search/incremental/ZIP
contracts pass 357/357. Interoperability passes 52 HQ, 41 search and 171
incremental cases against local libzstd 1.6.0 and system 1.4.8, preserving the
56/8 frozen legacy rows for f95c3446/97c4ad99. The earlier full-library Debug
run passes 5007 tests with two skips; its executable predates this key change.
Detailed command outcomes and still-running gates remain separate in the
validation record.

Reproduction starts at `b04a9019`, applies the measured source diff, builds the
shared Huffman object and two runners with the archived module arguments, then
runs `run_screen.py` with local output/cache paths. The final source adds only
the fixed-key assertion, formatting/comments and reference-test registration
to the measured comparison. A fresh run is a separate measurement epoch.
Next measure real files, trained dictionaries, 16/64/128 KiB blocks and other
architectures, then target the remaining HQ transition count. The complete
ten-format optimization goal remains active.

The [real-file and raw-dictionary follow-up](zstd-repeat-key-real-corpus.md)
records three CPU-4 rounds of Dickens/Mozilla/MR 4/16 KiB prefixes and an actual
dictionary reference, with unchanged wires and full profiles. It also records
two withdrawn Brotli interval-memo layouts whose component benefit did not
establish a useful ordinary-encoder improvement.

The [large-block and trained-dictionary verification](zstd-large-trained-key-verification.md)
extends the retained comparison to 64/128 KiB inputs and a libzstd-trained
4096-byte standard dictionary, with complete output/profile equality. A
first-slot shortcut is validated for equivalence but withdrawn after measured
periodic regressions.
