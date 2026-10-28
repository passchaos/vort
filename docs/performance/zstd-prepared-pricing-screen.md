# Zstd HQ prepared sequence pricing: withdrawn experiments

Two exact per-choice pricing prototypes were screened against the retained
`bdae5ce7128e30fee20e20e16612844a818cf1ff` encoder. Neither provides enough
ordinary real-input benefit to adopt. Production retains the existing
`EntropyModel.sequencePrice` and search-edge implementation. The
[evidence package](data/zstd-prepared-pricing-20261028/) preserves both
experiments separately, including source overlays, original commands, input
and wire bytes, full profiles, tests, assembly and source/binary identities.

For one offset choice, literal length, offset symbol and entropy model stay
fixed while candidate match lengths vary. The prototypes compute their fixed
LL/OF contribution once, then add each ML price. The first prototype retains
an optional `u32` base and checks it for every edge. The second peels the
original first edge: minimum length for complete enumeration, maximum length
for sampled enumeration. It returns a plain `u32` base for later edges and
shares node completion without a per-edge optional check.

Both admit each edge through the original price budget before preparation or
symbol validation, then record the original profile updates. The first edge
validates LL, ML and OF in their original order. Subsequent edges validate ML;
the previously validated LL/OF values and immutable model remain unchanged.
The public pricing oracle stays byte-identical. Candidate order, duplicate
lengths, ties, checked node costs and spill continuation are preserved. No
table, heap cache or additional model lifetime is introduced.

## Ordinary encoding screen

Each prototype has its own two balanced AB/BA rounds on CPU 2, Intel
i7-10700K, Zig 0.16.0, LLVM ReleaseFast and Skylake code generation. Inputs are
the first 4096 bytes of Silesia Dickens, Mozilla and MR. Requested window log
is 15, block maximum is 32768, checksum is enabled and no dictionary is used
in these timed calls. Input setup, decode, output writes, hashing and the
subsequent independent diagnostic encode are outside the ordinary interval.
Each process makes one ordinary call without an explicit warm-up. Background
process observations are retained; this is a bounded exploratory screen.

Values are median candidate time divided by median baseline time across the
two rounds; each round's paired ratio is also retained in the raw results.
Values below one mean less time. The separate prototype epochs should each
be assessed against their own baseline runs.

| Input | Strategy | Optional base | Peeled first edge |
| --- | --- | ---: | ---: |
| Dickens | btopt | 0.9940 | 0.9957 |
| Dickens | btultra2 | 1.0324 | 1.0193 |
| Mozilla | btopt | 1.0638 | 0.9894 |
| Mozilla | btultra2 | 1.0823 | 1.0058 |
| MR | btopt | 1.0293 | 1.0138 |
| MR | btultra2 | 1.0364 | 0.9942 |

Five optional-base configurations regress in both rounds. Peeling removes
most of that regression, but the resulting changes remain small and mixed:
Mozilla btopt improves about 1%, while Dickens btultra2 and MR btopt regress
in both rounds. No extra rounds were added to search for a favorable result.
These measurements do not establish a production speedup, statistical
significance or competitor leadership.

## Correctness and generated code

Each prototype passes three Debug pricing/admission checks and 133 existing
ReleaseFast HQ/search/lazy2/canonical tests. The pricing oracle comparison
covers predefined, dictionary, previous-block, refined and zero-price models,
LL/ML/OF boundaries and the btopt long-offset penalty. A zero-budget check
rejects before invalid-literal preparation and preserves nodes/profile state.
Existing HQ/search tests also exercise complete/whole enumeration, finite
quotas, dictionaries, refinement and frame safeguards.

Each screen completes 24 ordinary encodes and 48 native decodes. Complete
wire bytes and every profile field agree across baseline/candidate and rounds.
The parent independently checks all 24 wire/profile pairs across the two
experiments, binary hashes and baseline source against the recorded Git
revision. Timed dictionary, larger-block, independent reference-decoder and
platform sweeps were not added for these withdrawn prototypes.

The original `extend` is 425 bytes. Optional-base `extend` grows to 735 bytes;
peeled `extendPrepared` is 539 bytes. Initialization is 446 bytes in both,
and public `sequencePrice` remains 420 bytes. LLVM inlines peeled
`extendFirst` and `finishNode`; `extendPrepared` calls only `state.insert`.
Thus an extra node-completion call does not explain the remaining result.

Next sample ordinary HQ encoding again and choose a different measured source
of work before changing more pricing or row-insertion control flow. Continue
matched competitor, corpus and dictionary coverage as well. The full
deflate/zstd/brotli/lz4/xz/zip/rar/tar/bzip2/snappy goal remains active.
