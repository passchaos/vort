# Brotli serialized contextual dictionary status

Date: 2026-10-20. Upstream marks `BROTLI_SHARED_DICTIONARY_SERIALIZED` as
experimental and “do not use”. Vort therefore keeps its strict parser and
borrowed attachment explicit rather than implying a stable wire contract.

## Implemented

`brParseSerializedSharedDictionary` returns a borrowed, zero-copy
`BrotliSerializedSharedDictionary` view. It validates:

- the `0x91 0x00` magic and bounded 32-bit prefix varint;
- the optional RAW prefix;
- zero through 64 word lists, including every 4...31-byte size bucket and its
  complete power-of-two word data;
- zero through 64 transform lists, prefix/suffix stringlets, transform
  triplets, optional shift parameters, and exact termination;
- one through 64 word/transform combinations;
- the optional 64-entry contextual dictionary map; and
- exact input consumption with no accepted trailing bytes.

The view can select a dictionary from a caller-supplied RFC literal context
and replay a complete dictionary address. Address resolution follows the
decoder order: selected context dictionary first, then remaining dictionaries
in ID order. Word and transform choices may independently select custom or
RFC built-in tables. Custom replay covers identity, omit-first/last 1...9,
uppercase-first/all, SHIFT_FIRST, SHIFT_ALL, arbitrary prefix/suffix
stringlets, and byte-exact UTF-8 shift behavior.

`findLongestCustom` remains the compact custom-only oracle. `findLongest`
exhaustively covers independently mixed built-in/custom word and transform
tables and returns the same context-relative combined address consumed by
`resolve`.

The encoded bytes must remain alive and unchanged while the parsed view or any
nested word/transform slice is used.

`BrotliSerializedSharedDictionarySpec` is the borrowed construction model.
`brSerializedSharedDictionaryEncodedSize`,
`brSerializeSharedDictionaryInto`, `brSerializeSharedDictionaryAppend`, and
`brSerializeSharedDictionaryAlloc` validate the complete specification before
writing a canonical container. Word lists provide exact 4...31-byte bucket
bits and concatenated word bytes; transform lists provide the serialized
stringlet table, transform triplets, and optional SHIFT parameters. Dictionary
choices may independently select custom or RFC built-in word/transform tables.

```zig
const dictionary = try vort.brParseSerializedSharedDictionary(encoded);
const decode_options = vort.BrotliDecodeOptions{
    .shared_dictionary = .{ .serialized = &dictionary },
};
const dictionary_id = try dictionary.dictionaryForContext(context);
_ = dictionary_id;

var transformed: [576]u8 = undefined;
const word = try dictionary.resolveCustom(
    context,
    copy_len,
    dictionary_address,
    &transformed,
);

const rebuilt = try vort.brSerializeSharedDictionaryAlloc(allocator, .{
    .raw_prefix = raw_prefix,
    .word_lists = word_lists,
    .transform_lists = transform_lists,
    .dictionaries = dictionary_choices,
    .context_map = &context_map,
});
defer allocator.free(rebuilt);
```

## Validation

Unit coverage includes a two-dictionary context split, local/contextual/
cross-dictionary match addresses, all 23 transform kinds, ASCII and multi-byte
UTF-8 shift, the complete prefix/suffix stringlet ID domain, transforms whose
source word is longer than their output, every truncation of a valid contextual
fixture, invalid context IDs, bad magic, trailing bytes, and embedded RAW
prefix borrowing. Mixed custom/built-in word and transform combinations are
also replayed. Production decode tests cover one-shot allocation, caller-owned
output, atomic append, chunk joining, summary replay, caller-history
progressive decode, allocator-owned progressive decode, serialized RAW-prefix
distance shifting, and history-selected context maps. Encoder tests cover
one-shot, reusable, chunked, incremental, q0 cross-block context retention,
and complete address replay. An experimental libbrotli 1.2.0 build passes both
Vort-encode/libbrotli-decode and libbrotli-encode/Vort-decode cases. The
contextual differential dictionary is produced through the public builder, and
five additional bidirectional pairs use identity, case-transform,
omit-transform, learned-prefix/suffix, and non-contiguous-context-cluster
trainer results. Three more payloads exercise both directions of one clustered
multi-transform-list result, and one learned UTF-8 SHIFT_FIRST/ALL dictionary
adds the final pair (`serialized_cases=22`).
Builder tests cover deterministic parse/serialize round trips, built-in/custom
mixed choices, all output ownership forms, varint boundaries, invalid size
buckets/transforms/context IDs, atomic caller output, and allocation failure.
The parser allocates no memory.

`brTrainSerializedSharedDictionaryAlloc` trains identity-transform word lists
from caller-supplied training samples. Each word length compares one bounded
heavy-hitter collection with an optional Vort-native COVER-class selection
whose full segment size equals the word length. COVER output is reordered from
history-tail priority to low Brotli word addresses. Each emitted bucket is the
largest legal power of two within the configured limits. The default bounded
grid evaluates `d={6,8}` and `hash_log={12,16}` through actual complete Brotli
wire cost; results report the winning pair and evaluated count. When context training is enabled, it trains two word lists
on each side of caller-selected context cutoffs for LSB6, MSB6, UTF8, and
Signed. It also hashes the next minimum-length phrase into a fixed 64-bin
signature per context and uses normalized integer L1 agglomeration to learn
arbitrary non-contiguous maps, with 3/4 clusters by default. Public options
bound the RFC mode, cutoff, and cluster-count lists, per-context signature
positions, and training positions per group. Every cutoff/mode and cluster-count/mode candidate
competes with the global dictionary. Held-out samples are encoded both without
and with every candidate; the function returns null unless the best actual
complete Brotli frame total, plus the serialized dictionary by default, meets
`min_savings_bytes`.
The owned result reports frame totals, charged dictionary bytes, word/bucket
counts, total savings, context profile/cluster count, learned
stringlet/transform counts, and a stable content-derived `DictionaryId`. The
trainer reuses Vort's bounded deterministic
phrase collector, then indexes each candidate's trained words and learns
prefix-only, suffix-only, and observed prefix+suffix identity transforms from
deterministically sampled corpus matches. Ranked transforms are reserialized
independently with identity, case, omit-first/last, and combined case+omit base
families before the same complete-wire arbitration. A bounded shift learner
infers signed 16-bit parameters from equal-width source/held-out sequences,
verifies them through the byte-exact SHIFT_FIRST/ALL replay, and appends the
ranked transforms to every existing family before the same arbitration. For contextual
candidates, the richest enabled family acts as one held-out matcher oracle.
Actual winning transform kinds are attributed to their resolved dictionary;
each dictionary selects the smallest enabled capability profile covering that
demand, and equal profiles reuse one transform list. The resulting mixed
candidate is accepted only through the same complete-wire comparison.

## Remaining performance work

Production encode and decode are attached. Encoding currently uses the
complete exhaustive matcher as a correctness oracle and bounded fallback.
Ordinary descriptors use a reusable four-byte candidate index; combined
addresses are computed from the active context without duplicating index data
64 times. Context-varying descriptors generate independent command plans for
LSB6, MSB6, UTF8, and Signed, emit the matching mode in each candidate header,
and retain the smallest complete wire. Multi-block encoding carries the exact
two-byte prefix history into every mode search. Within each address-stable
mode, the encoder additionally arbitrates single-tree, suffix, bounded-16-tree,
and complete clustered literal-context candidates. A locked joint fixture
shrinks from 627 to 523 bytes while retaining custom dictionary copies. Vort
does not promise stability for upstream's experimental container format.
The trainer is deterministic and complete-wire validated, with bounded multi-
cutoff two-group maps, arbitrary non-contiguous context clustering, and bounded
prefix/suffix stringlet, SHIFT parameter, and per-dictionary transform-profile
learning. COVER-class fixed-word selection and actual-wire parameter grids are
available; FastCover-style acceleration, wider calibration, and broad corpus
evidence remain open. The builder also remains available for fully explicit
caller-owned specifications.
The repository-owned four-category trainer report currently records zero
charged winners and zero regressions (`16,054 -> 16,054` aggregate), making
real-corpus profitability an explicit tracked gap.
