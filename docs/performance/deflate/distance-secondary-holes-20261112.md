# Deflate missing long-distance secondary codes, 2026-11-12

This correction rejects malformed dynamic Deflate streams that previously
could successfully decode a missing long distance code. Valid codes in an
incomplete distance tree remain supported; the tree is not rejected eagerly.

The secondary distance builder allocated suffix ranges but initialized only
slots covered by a real code. The remaining slots were undefined. Its three
semantic consumers checked the slot index and symbol range, but accepted a
zero code width. A preceding block could leave a valid-looking value in a
slot that a later incomplete tree did not populate.

A real public two-block fixture demonstrates the error. The first complete
distance tree initializes all four suffix slots; the second incomplete tree
fills slots 0, 1 and 2 while leaving slot 3 absent. The second block then emits
that missing code. The original Debug decoder returned successful consumption
of 305 bytes and 143 output bytes; ReleaseFast returned 305 and 131. ReleaseSafe
with the recorded seed rejected it, illustrating that undefined contents and
code generation affect the result. This is not a private poisoned-table test.
The independent canonical decoder rejects the missing code at bit 2422.

The builder now clears each newly allocated suffix range to its invalid-code
sentinel before populating real entries. Ordinary/non-overlap/window, rolling
and sink consumers reject zero-width entries as `InvalidHuffmanCode` before
interpreting their distance metadata or consuming the token. Existing symbol
and index checks remain in place.

Six public scenarios check single/two-block valid nine/ten-bit codes and
missing-code rejection. Eighteen direct execution scenarios cover ordinary,
non-overlap, bounded window and sink instances, plus rolling at two nonzero
ring bases. They use real canonical trees, preserve initialized history,
check exact successful consumption/output, error token position, immutable
input and guards outside the complete output capacity. Permitted speculative
stores inside caller capacity retain their existing contract.

Final validation passes:

- Debug, ReleaseSafe, ReleaseFast, 32-bit x86 and actual WASI focused Deflate
  tests: 10/10, comprising two behavior aggregates and eight import tests.
- Direct root Debug/ReleaseSafe/ReleaseFast/actual WASI: 92/92, comprising three
  behavior aggregates and 89 import tests, including repeated public scenarios.
- Full Deflate ReleaseSafe: 738/738.
- All 72 frozen Deflate wires: complete output/count/consumption, input
  immutability and guard smoke against libdeflate 1.26.

The independent canonical replay accepts all four existing-code controls.
zlib 1.2.11 rejects these incomplete trees at the header; that earlier rejection
is a different acceptance contract and does not replace Vort's valid-subset
or token-error checks.

A separate twelve-row functional non-regression pilot retains 96 child events.
Its selected-row speed geometric mean is 1.004717x; the weakest XML 64 KiB L6
row is 0.995362x. All selected rows remain above 0.98x. The pilot and one-call
smoke do not establish a dedicated-host gain or new full-industry ranking.

The functional increment is `d31dc389`. Frozen before/after source, original
successful-malformed results, initial fixture compilation errors, canonical
oracle, completed tests and ordinary-wire observations are retained in the
[evidence packet](distance-secondary-holes-20261112/README.md). Test adapters,
fixture generations and source versions retain their distinct identities.

Preparation-stage range evidence for a future handoff executor must account
for these defined invalid slots. No mapped owner or packed-word executor is
adopted by this correction.
