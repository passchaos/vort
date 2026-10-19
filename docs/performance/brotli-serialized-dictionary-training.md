# Brotli serialized dictionary training baseline

Date: 2026-10-19

## Scope

`brTrainSerializedSharedDictionaryAlloc` is the first deterministic training
baseline for Vort's experimental serialized Brotli dictionaries. It reuses the
bounded generic phrase collector independently for each configured word length,
retains the largest legal power-of-two word bucket, emits one identity-transform
custom dictionary, and validates profitability on held-out samples with the
production Brotli encoder.

This is not a COVER/FastCover-equivalent trainer. General context clustering,
omit/prefix/suffix transform-list learning, and representative corpus
calibration remain future work.

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
