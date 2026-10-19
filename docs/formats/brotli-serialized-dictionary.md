# Brotli serialized contextual dictionary status

Date: 2026-10-19. Upstream marks `BROTLI_SHARED_DICTIONARY_SERIALIZED` as
experimental and “do not use”. Vort therefore separates stable parsing and
semantic validation from production codec attachment.

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
and replay a custom dictionary address. Address resolution follows the decoder
order: selected context dictionary first, then remaining dictionaries in ID
order. Custom replay covers identity, omit-first/last 1...9, uppercase-first/
all, SHIFT_FIRST, SHIFT_ALL, arbitrary prefix/suffix stringlets, and byte-exact
UTF-8 shift behavior.

`findLongestCustom` is the allocation-free exhaustive correctness matcher for
custom-only dictionary combinations. It returns the same context-relative
combined address consumed by `resolveCustom`; production indexing can use it
as an oracle.

The encoded bytes must remain alive and unchanged while the parsed view or any
nested word/transform slice is used.

```zig
const dictionary = try vort.brParseSerializedSharedDictionary(encoded);
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
prefix borrowing. The parser allocates no memory.

## Remaining codec work

Production `BrotliSharedDictionary` still attaches RAW prefixes only. The next
increment must replace exhaustive matching with context-aware indexes and
thread the parsed descriptor
through every one-shot, chunked, incremental, summary, and progressive decode
surface. Until that lands, Vort does not claim serialized contextual dictionary
encoding or decoding interoperability.
