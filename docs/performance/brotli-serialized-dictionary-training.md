# Brotli serialized dictionary training baseline

Date: 2026-10-20

## Scope

`brTrainSerializedSharedDictionaryAlloc` is the first deterministic training
baseline for Vort's experimental serialized Brotli dictionaries. It reuses the
bounded generic phrase collector independently for each configured word length,
plus a Vort-native COVER-class selector using a full segment equal to that word
length. Both retain the largest legal power-of-two bucket, emit an identity-
transform custom dictionary, and validate profitability on held-out samples
with the production Brotli encoder.

This does not claim byte-identical libzstd/libbrotli COVER or FastCover output.
FastCover-style acceleration and representative corpus calibration remain
future work.

## Selection contract

The default selection cost is:

```text
sum(trained held-out Brotli frames) + serialized dictionary bytes
```

The candidate is returned only when this total beats the dictionary-free frame
total by at least `min_savings_bytes`. Deployments that distribute dictionaries
out of band may disable the one-time dictionary charge explicitly. Every
returned result includes both frame totals, the charged bytes, total savings,
word and bucket counts, global/cutoff/clustered context profile, actual cluster
count, heavy-hitter/COVER word profile, selected d-mer/hash-log and evaluated
grid count, selected transform profile/list count, learned stringlet and SHIFT
parameter/transform counts, and a stable content-derived dictionary ID.

## Heavy-hitter and COVER word evidence

Eight training samples and 64 held-out samples share four otherwise
non-repeating 16-byte records. With quality 5 and an eight-word limit, the
default four-configuration grid selects `d=6`, `hash_log=16`, MSB6, and cutoff
32:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 4,608 |
| Optimized COVER-backed held-out frames | 2,416 |
| Serialized contextual dictionary | 266 |
| Charged trained total | 2,682 |
| Total saving | 1,926 (41.8%) |

The regression requires at least a 40% complete-total saving, byte-identical
training across repeated calls, `.cover`, `d=6`, `hash_log=16`, four evaluated
configurations, the selected context metadata, identical stable IDs, and
correct parsing. Disabling optimization retains the original `d=8/hash_log=16`
global COVER result at 2,527 frame bytes plus a 172-byte dictionary, saving
1,909 bytes. Disabling COVER retains the heavy-hitter result at 2,632 frame
bytes plus the same 172-byte dictionary, saving 1,804 bytes. A single held-out
sample with no amortized benefit must return null. Allocation-failure
enumeration covers both builders, and an experimental libbrotli 1.2.0 build
accepts the selected dictionary in both encode/decode directions.

## Two-group context evidence

With the default cutoff candidates 16/32/48, the trainer builds two word lists
for each RFC context mode and compares all contextual candidates with the global dictionary.
A locked LSB6 fixture contains 16 distinct words behind contexts below the
cutoff and 16 behind contexts above it, while each individual word occurs only
once per frame:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 17,344 |
| Contextual dictionary-backed frames | 14,272 |
| Serialized contextual dictionary | 266 |
| Charged trained total | 14,538 |
| Total saving | 2,806 (16.2%) |

The regression requires at least a 15% complete-total saving and verifies that
the selected candidate records MSB6, cutoff 48, a two-entry context
map, stable bytes, and successful decoding.

## Non-contiguous context-cluster evidence

For each RFC literal-context mode, the trainer hashes the next minimum-length
phrase at each training position into one of 64 fixed signature bins. Every
context retains a separately bounded count vector. Deterministic agglomeration
merges the pair with the smallest normalized integer L1 distance; equal costs
use the lowest member contexts. Empty-evidence contexts join the numerically
nearest observed cluster. The algorithm uses fixed stack storage, no floating
point, and no heap allocation. Default cluster-count candidates are 3 and 4;
callers may provide up to eight strictly increasing counts in 2...16.

A locked four-cluster fixture places three eight-word families behind non-
contiguous LSB6 context pairs `{8,32}`, `{16,40}`, and `{24,48}`. A fourth
cluster owns start-of-sample phrases. No single cutoff can reproduce this map:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 4,992 |
| Clustered dictionary-backed frames | 3,584 |
| Serialized dictionary | 454 |
| Charged trained total | 4,038 |
| Total saving | 954 (19.1%) |

The regression requires at least a 15% complete-total saving, selects LSB6 and
four word lists, verifies every non-contiguous pair and cross-group separation,
replays a group-specific dictionary word, and requires repeated public training
to produce byte-identical bytes and IDs.

## Case-transform evidence

Every trained word-list candidate can be reserialized, without retraining, with
the canonical transform family identity/uppercase-first/uppercase-all. Both
forms compete on the held-out wire. A locked fixture trains on four lowercase
16-byte records and validates their uppercase variants:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 4,608 |
| Case-transform dictionary-backed frames | 2,424 |
| Serialized dictionary | 178 |
| Charged trained total | 2,602 |
| Total saving | 2,006 (43.5%) |

The regression requires at least a 40% complete-total saving, verifies that the
case profile wins, checks all three serialized transforms, and retains identity
for corpora where the extra transform address space cannot improve the wire.

## Omit-transform evidence

The same trained word lists also produce an independent family containing
identity, omit-last 1...9, and omit-first 1...9. A combined case+omit family is
evaluated separately so its shifted addresses cannot hide a smaller omit-only
wire. A locked fixture trains four 16-byte records and validates their
12-byte omit-last-four forms:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 3,584 |
| Omit-transform dictionary-backed frames | 2,647 |
| Serialized dictionary | 226 |
| Charged trained total | 2,873 |
| Total saving | 711 (19.8%) |

The regression requires at least a 15% complete-total saving, verifies that the
omit-only profile wins, replays both omit-last and omit-first addresses, and
checks experimental libbrotli interoperability in both directions.

## Learned prefix/suffix evidence

For every global or contextual word-list candidate, the bounded learner builds
a deduplicated word index and scans actual training-corpus matches. It samples
at most a caller-bounded number of positions at a deterministic stride, counts
prefix-only, suffix-only, and observed prefix+suffix shapes, then ranks them by
`occurrences * added bytes` with bytewise deterministic ties. The canonical
table stores non-empty stringlets first and the mandatory empty stringlet last.
The distinct-word index, candidate map, string length, selected transforms, and
sampled positions all have separately validated public limits.
The learned list competes independently on identity, case, omit, and case+omit
base families; strict complete-total comparison keeps the old candidate on a
tie.

A locked fixture trains four standalone and `<word>` 16-byte records, limits
learning to the top one transform, and validates 64 frames containing the
wrapped records:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 5,120 |
| Prefix/suffix dictionary-backed frames | 1,279 |
| Serialized dictionary | 179 |
| Charged trained total | 1,458 |
| Total saving | 3,662 (71.5%) |

The regression requires at least a 70% complete-total saving, verifies two
learned non-empty stringlets and one pair transform, replays the combined
address, and retains identity with zero learned metadata when affixes cannot
improve the wire. The experimental libbrotli matrix checks the learned result
in both encode/decode directions.

## Per-dictionary transform clustering evidence

Contextual candidates may assign different enabled transform profiles to each
dictionary choice. The richest enabled family is prepared once with the
production matcher and scans a caller-bounded, deterministic set of held-out
positions. Every winning address is resolved back to its actual dictionary and
transform kind. Each dictionary then selects the first, smallest profile whose
case/omit/affix capabilities cover its observed demand; dictionaries choosing
the same profile share one serialized transform list. A final complete-wire
comparison can still reject the mixed result. Defaults consider at most four
dictionaries and 65,536 positions; hard ceilings are 16 dictionaries and
1,048,576 positions.

The locked LSB6 fixture trains three 16-byte word families plus a start-of-
sample list. Held-out contexts deliberately reference another group's words as
uppercase, omit-last-four, or identity forms, exercising the preferred/fallback
address ordering. The selected result reuses two transform lists—19-transform
omit and 21-transform case+omit—instead of applying the largest family to all
four dictionaries:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 13,568 |
| Clustered-transform dictionary-backed frames | 7,680 |
| Serialized dictionary | 831 |
| Charged trained total | 8,511 |
| Total saving | 5,057 (37.3%) |

Within the locked LSB6 domain, the uniform case+omit candidate costs 8,770
bytes, so transform clustering saves another 259 bytes after paying for the
second list. The regression requires at least a 35% baseline saving,
byte-identical repeated training, exact 19/21 transform counts, and successful
uppercase, omit, and identity replay. The experimental libbrotli matrix checks
all three payload shapes in both directions.

## Learned UTF-8 SHIFT evidence

The bounded shift learner compares canonical trained words with deterministically
sampled, equal-length held-out slices. It decodes the first scalar using
Brotli's original byte-width masks, derives the smallest signed 16-bit delta,
and accepts it only when byte-exact replay reproduces the complete target.
SHIFT_FIRST and SHIFT_ALL are counted and ranked independently. Selected
triplets carry little-endian parameters while every non-SHIFT transform receives
the required zero parameter entry. The resulting family can be layered over
identity, case, omit, and learned-affix candidates; the transform clusterer
treats shift as a fourth capability bit.

A locked fixture trains four 16-byte words made from eight two-byte UTF-8
scalars. Two held-out words shift only their first scalar and two shift every
scalar, all with signed delta `+1`:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 3,513 |
| SHIFT dictionary-backed frames | 2,624 |
| Serialized dictionary | 184 |
| Charged trained total | 2,808 |
| Total saving | 705 (20.1%) |

The regression requires at least a 20% complete-total saving, one learned
parameter, two learned transforms, exact SHIFT_FIRST/ALL replay, and byte-
identical repeated training. Allocation-failure enumeration covers both the
learner and family builder. The experimental libbrotli matrix validates the
trained dictionary in both directions.
