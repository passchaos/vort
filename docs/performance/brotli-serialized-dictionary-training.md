# Brotli serialized dictionary training baseline

Date: 2026-10-19

## Scope

`brTrainSerializedSharedDictionaryAlloc` is the first deterministic training
baseline for Vort's experimental serialized Brotli dictionaries. It reuses the
bounded generic phrase collector independently for each configured word length,
retains the largest legal power-of-two word bucket, emits one identity-transform
custom dictionary, and validates profitability on held-out samples with the
production Brotli encoder.

This is not a COVER/FastCover-equivalent trainer. Context-map learning,
transform-list learning, multi-candidate parameter search, and representative
corpus calibration remain future work.

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
