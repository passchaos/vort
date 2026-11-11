# Incremental dictionary seeding and provision

Raw Deflate and Deflate64 seed the final format window of a temporary
dictionary into caller-owned history. The dictionary source is borrowed only
until that copy finishes. `initWithDictionary` and `seedDictionary` support
exact, forward and backward history/source overlap with memmove semantics.
Raw seeding does not read a discarded dictionary prefix and does not allocate
an input-sized snapshot.

`seedDictionary` now returns `Error!void`. Callers must handle the checked
operation, normally with `try decoder.seedDictionary(dictionary)`. The
existing fallible `initWithDictionary` signature is unchanged.

Before writing, seed validates the following invariants:

- An active semantic generation returns `InvalidStreamState`, including for
  an empty dictionary. Its scratch, workspace, receiver and pending output
  remain unchanged.
- A compact pending match with remaining bytes must keep at least its match
  distance in the new history. A zero/invalid distance or insufficient seed
  returns `InvalidStreamState` without replacing the old history or token.
  The caller can provide a sufficient seed and continue the same match.
- The actual writer `history[0..min(history.len, dictionary.len)]` must be
  disjoint from the complete public receiver. A conflict returns
  `InvalidBlockPlan` before copying or recording diagnostics.

Sufficient compact pending-match seeds remain supported. A zero-remaining
match, partial header, stored payload, symbol parsing and completed stream
do not introduce a blanket state restriction. Later new matches still pass
their normal history checks. This preserves stopped-state seeding while
avoiding any new check in the symbol/match hot loop.

The source may borrow receiver bytes, including metadata that will change
after seeding: the copy consumes the old source before `history_len` and
`history_pos` are updated. Source bytes in an attached workspace or inactive
second history window are also allowed; seeding does not initialize that
workspace or write the second window.

Only the actual history write prefix participates in seed destination
admission. A receiver residing solely in the unused history tail does not
conflict with this copy. The later `step` contract still requires independent
receiver/history storage before decoding can continue; seed does not waive
that persistent storage rule.

Zlib `provideDictionary` first checks a complete unresolved FDICT request
and the unfinished-input state. It admits the actual seed destination before
hashing or error recording, hashes the complete dictionary for DICTID, then
copies only the required suffix. Request clearing, phase publication and
diagnostic clearing happen after successful checked seeding. Ordinary ID
mismatch retains the request and history for a correct retry.

Automatic wrapper provision protects its complete outer receiver in addition
to the child. Temporary sources may still borrow child or outer receiver
bytes; their hash and copy finish before metadata publication. Overrides are
not cached for reset or later members, and their storage may be reused for
output after provision returns.

Configured zlib dictionaries and dictionary sets keep their separate
long-lived contract across reset and later members. The
[step-borrow contract](deflate-incremental-step-borrows.md) protects their full
bytes and descriptors. An override's temporary source must not be subjected
to those permanent-reader restrictions.

Admission lives in `src/deflate/incremental/decoder/dictionary_borrows.zig`.
Independent tests under `src/deflate/incremental/tests/dictionary_borrows/`
use RFC fixed dictionary-only matches verified with Python zlib, complete
state rejection snapshots and independent retries.
