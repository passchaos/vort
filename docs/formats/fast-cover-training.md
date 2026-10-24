# FastCover dictionary training

Vort provides a Zig-native FastCover history selector, reusable frequency
preparation, bounded parameter optimization and full Zstd dictionary training.
The algorithm uses sampled hashed d-mer frequencies, distinct-bucket sliding
segment scores, frequency clearing and cyclic epochs. Candidate segments stay
inside caller-provided sample boundaries. That intentional boundary rule and
native tie handling do not promise byte-identical libzstd output.

## History selection

```zig
const history = try vort.dictionary.trainFastCoverAlloc(allocator, samples, .{
    .target_size = 1024,
    .segment_size = 64,
    .dmer_size = 8,
    .hash_log = 16,
    .acceleration = 2,
    .max_working_memory = 32 * 1024 * 1024,
});
defer allocator.free(history);
```

`FastCoverTrainOptions` accepts d-mer widths 6/8, hash logs 1...31 and
acceleration 1...10. Segment size is at least the d-mer width and at most the
target; its default is `min(target_size, 64)`. The target and
`max_dictionary_size` bound selected raw history. They do not force padding
or an exact result length. Zero target with empty input and zero resource
limits requires no heap allocation. Invalid scalar settings remain errors.

Acceleration changes actual frequency sampling stride. Frequency collection
uses only positions with eight readable bytes, while the d=6 hash consumes
six significant bytes. Selection can use valid six-byte tails inside a sample.
The active window counts are 32-bit, so large segments do not wrap a 16-bit
counter.

`PreparedFastCover.init(allocator, samples, options)` borrows sample descriptors
and bytes until re-preparation or deinit. `trainAlloc(allocator, options)`
reuses the same d/f/acceleration group and restores mutable tables for each
candidate. `fork` copies prepared frequencies for independent workers without
rescanning the corpus. `reset` retains capacity. Outputs are exact-size,
separately owned slices freed through the original caller allocator.

Requested memory checks include retained preparation, temporary selection
storage, growth overlap and the actual returned result while it coexists with
scratch. A conservative planning estimate does not reject a smaller actual
result that fits. `FastCoverTrainProfile` reports real hashes, skips, windows,
epochs, frequency clears/restores, preparation reuse/forks and byte peaks.

## Parameter optimization

`trainOptimizedFastCoverAlloc` accepts explicit training and selector sample
partitions. `trainOptimizedFastCoverSplitAlloc` and `splitFastCoverSamples`
use an integer `FastCoverSplitPoint`; the default is 3/4, while 1/1 explicitly
reuses all samples for both roles. A separate held-out partition is needed for
an unbiased quality measurement.

`FastCoverOptimizeOptions` controls d-mer/hash/acceleration grids, explicit
segment sizes or an automatic endpoint ladder, candidate/scoring limits,
corpus/sample limits, worker count and optional dictionary shrinking. Equal
charged scores favor smaller dictionaries, then original enumeration order.
Zero shrink regression tolerance permits no cost increase against the best
full candidate. Shrink comparisons span the complete parameter grid.

Candidates in a d/f/acceleration group reuse frequency preparation. Parallel
workers have private mutable tables and managed scorer state. Allocator
callbacks and the shared whole-operation budget are locked; results reduce in
stable order after joins. Spawn or stack-budget constraints can reduce worker
count while preserving complete candidate evaluation and final output.

The optimizer's `max_working_memory` covers allocator-owned heap plus requested
native worker-stack reservations. Profiles separate
`peak_allocator_owned_bytes`, `thread_stack_reservation_peak` and the combined
peak. Caller execution state and OS/allocator bootstrap overhead are excluded;
the budget is not an RSS limit. Platforms without supported native threading
use the serial implementation.

Custom codec scoring uses `fast_cover_optimize.trainAllocWithScorerFactory`.
Each scorer receives the operation allocator, owns its scratch until deinit,
and scores raw history with candidate options. Optional `accepts` filters
content that cannot be finalized, and ordered profile merging occurs after
all workers finish. A failed candidate cannot be silently skipped as though
optimization completed.

## Full Zstd dictionaries

```zig
const trained = try vort.zstdTrainFastCoverStandardDictionaryAlloc(
    allocator,
    samples,
    .{ .target_size = 1024, .hash_log = 16, .acceleration = 2 },
    73,
);
defer trained.deinit(allocator);
```

Standard APIs reuse the existing corpus-specific Huffman/FSE/repcodes
finalizer. Selected history must contain at least eight bytes. A direct
underfilled result is `InvalidDictionaryTraining`; standard optimizers filter
unusable candidates before scoring. Dictionary IDs must be nonzero.

The raw target policy is preserved: standard entropy metadata adds a variable
header beyond selected history. Compare serialized sizes explicitly when
matching a full-dictionary byte budget against libzstd.

Acceleration chooses the finalizer's training-sample prefix by percentages
`100/50/34/25/20/17/14/13/11/10`, using exact floor arithmetic on sample count.
A zero count generates complete prior tables; it does not restore all samples.
Selector samples only select parameters and score frames. They do not enter
final entropy training.

Direct and ordinary optimized APIs train repcodes. Codec-aware optimization
uses the same `candidate_repcodes` policy for candidates and the returned
winner, so charged scores exactly match the serialized dictionary and actual
selector frames. Profile variants return the same dictionary while recording
frequency/selection/finalization/search work and stage times. Caller-owned
profiles accumulate until reset.

The CLI supplies thin direct and optimized workflows:

```sh
vort train-zstd-fastcover-dictionary output.dict 1024 73 sample1 sample2 sample3 sample4 sample5 --hash-log=16 --accel=2
vort optimize-zstd-fastcover-dictionary output.dict 1024 73 sample1 sample2 sample3 sample4 sample5 sample6 sample7 sample8 --threads=2 --shrink
```

Both validate options and corpus bounds before training, then publish a complete
standard dictionary only after success. CLI flags mirror the public library;
selection and entropy logic remain in the library.
