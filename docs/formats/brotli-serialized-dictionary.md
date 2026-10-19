# Brotli serialized contextual dictionary status

Date: 2026-10-19. Upstream marks `BROTLI_SHARED_DICTIONARY_SERIALIZED` as
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
Vort-encode/libbrotli-decode and libbrotli-encode/Vort-decode cases. The parser
allocates no memory.

## Remaining performance work

Production encode and decode are attached. Encoding currently uses the
complete exhaustive matcher as a correctness oracle and bounded fallback.
Ordinary descriptors use a reusable four-byte candidate index; combined
addresses are computed from the active context without duplicating index data
64 times. Context-varying descriptors generate independent command plans for
LSB6, MSB6, UTF8, and Signed, emit the matching mode in each candidate header,
and retain the smallest complete wire. Multi-block encoding carries the exact
two-byte prefix history into every mode search. Joint optimization with
multi-tree literal entropy contexts remains open. Vort does not promise
stability for upstream's experimental container format.
