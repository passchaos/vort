# Brotli serialized dictionary training baseline

Date: 2026-10-20

## Scope

`brTrainSerializedSharedDictionaryAlloc` is the first deterministic training
baseline for Vort's experimental serialized Brotli dictionaries. It reuses the
bounded generic phrase collector independently for each configured word length,
retains the largest legal power-of-two word bucket, emits one identity-transform
custom dictionary, and validates profitability on held-out samples with the
production Brotli encoder.

This is not a COVER/FastCover-equivalent trainer. General context/transform
clustering, SHIFT-family learning, and representative corpus calibration remain
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
word and bucket counts, and a stable content-derived dictionary ID.

## Locked fixture

Eight training samples and 64 held-out samples share four otherwise
non-repeating 16-byte records. With quality 5 and one eight-word bucket:

| Metric | Bytes |
|---|---:|
| Dictionary-free held-out frames | 4,608 |
| Dictionary-backed held-out frames | 2,632 |
| Serialized dictionary | 172 |
| Charged trained total | 2,804 |
| Total saving | 1,804 (39.1%) |

The regression requires at least a 30% complete-total saving, byte-identical
training across repeated calls, identical stable IDs, and correct parsing of
the returned dictionary. A single held-out sample with no amortized benefit
must return null. Allocation-failure enumeration covers the bounded candidate
builder, and an experimental libbrotli 1.2.0 build accepts the trained
dictionary in both encode/decode directions.

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
