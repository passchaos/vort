# Brotli wide10 payload live-state audit, 2026-11-14

Status: static audit plus one measured prototype that was reverted for a
lifetime safety reason. No production source changed on main. The audit
identifies why payload frames are large and records which state-reduction
ideas are safe versus blocked.

## Frame anatomy (generic wide10 payload, ReleaseFast skylake)

Baseline `processWideExternalLiteralLookupCompressedPayloadNative`:

- Text 4,123 bytes; frame 312 bytes (six pushes + `sub $0x138`).
- 41 distinct rbp-relative stack slots, 124 stack accesses.
- Hottest slots (`-0x38`, `-0x48`, `-0x50`, `-0x58`) are shared temporaries
  for the `DecodedBrotliDistance` aggregate, reader state and the match-copy
  setup, reloaded around each `call`.

State that must stay live across the whole command iteration:

| State | Why it cannot be dropped |
| --- | --- |
| `fast_bit_reader.Reader` (5 fields incl. u64 reservoir) | every symbol stages bits; refill happens mid-command |
| `output_cursor`, `meta_block_end`, output slice | bounds for literals, distance window and match copy |
| `last_distances[4]` ring | short symbols 0..15 resolve against it each match |
| literal context pair (`previous`, `second_previous`) | needed per literal byte across block runs |
| `literal_lookup_ptr` and active context map | 10-bit literal decode every insert |
| header block states (literal/command/distance) | switch checks on every symbol |
| `transformed_dictionary_word[64]` | out-of-window dictionary copy scratch |

The 10-bit auxiliary payload is even larger (frame 472 B, 247 stack
accesses) because it additionally carries active command/distance lookup
pointers and the context-three tree index.

## Scratch relocation prototype: promising codegen, unsafe lifetime

Hypothesis: the 64-byte `transformed_dictionary_word` buffer is live for the
entire loop but used by only 0.262% of applied copies on mozilla full q11
(9,898 static-dictionary copies of 3,770,833). Moving it inside
`minimalStaticDictionaryWord` should remove it from the payload frame.

Measured codegen after relocation:

| Metric | Baseline | Prototype |
| --- | ---: | ---: |
| Payload frame | 312 B | 248 B (-21%) |
| Stack accesses | 124 | 112 |
| Distinct stack slots | 41 | 38 |
| Payload text | 4,123 B | 2,408 B (-42%) |

The frame reduction is real and large. But the prototype fails correctness:
`static_dictionary.transform` returns either an embedded `const` slice
(transform index 0) or a slice of the caller-provided scratch buffer. With
scratch moved into the callee, the non-zero-transform return is a dangling
slice; the payload copies it only after return. The focused dictionary test
caught this (`307/308 pass, 1 fail`), so the branch was reverted and no A/B
was run. A safe version needs one of:

1. The callee copies transformed bytes directly into the output buffer
   (changes the dictionary-copy call contract and its bounds handling).
2. A caller-owned scratch whose address is passed only on the cold
   dictionary branch — but that keeps the 64 bytes reserved in the frame,
   giving no frame reduction.
3. Splitting transform-zero (embedded slice, no scratch) from the other
   transforms so only the transformed case needs scratch, then materializing
   that case through a dedicated cold helper that writes into output.

Option 3 is the only path that preserves both the frame win and the
lifetime guarantee; it is a contract-level redesign of the dictionary
stage, not a localized edit.

## What the audit rules out and what remains

- Register pressure is dominated by reader reservoir + output/ring state
  that is genuinely live across every command; it cannot be shortened
  without changing the bit-reader or match-copy contract.
- The scratch buffer is the one large (64-byte) piece of loop-live state
  whose liveness is artificial, but removing it safely requires the
  transform-stage redesign above.
- The hot/cold call split already failed because it duplicated decode
  logic without touching this state; the evidence here explains why: no
  call-boundary change shrinks the 248-488 B of genuinely live state.

## Next candidate

Redesign the static-dictionary transform path so transformed words are
written into the output by a noinline cold helper (option 3), keeping
transform-zero as a borrowed embedded slice. Then re-measure the payload
frame and run the standard paired A/B with the 0.98x control floor. Treat
this as a separate, fully tested increment; do not combine it with any
distance-decode layout change.
