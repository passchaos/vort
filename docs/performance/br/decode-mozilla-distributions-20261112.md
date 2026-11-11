# Mozilla decode distributions and semantic screens, 2026-11-12

This round records the actual shared-dispatch routes, independent logical
payload counts and two rejected semantic-kernel screens. It adopts the
counter tool and bounded per-meta-block diagnostic API. It does not adopt
either acceleration candidate or update the complete industry comparison.

The fixed producer wires and libbrotli 1.2.0 binary are reused from the modern
decode corpus. Counter discovery uses the clean `21952b95` source; per-block
discovery uses its frozen diagnostic overlay. Every diagnostic proves complete
output against plain bytes. The [evidence package](decode-mozilla-distributions-20261112/README.md)
retains exact source, binaries, arguments, raw streams and separate epochs.

## Actual decoded-byte and command weighting

The per-block API executes the same prepared dispatcher as ordinary decoding,
then independently replays each compressed payload. Replay must agree on input
bit position, distance ring and all retained history bytes. Routes identify
the top-level invoked executor rather than guessed inner specializations.

| Mozilla row / actual route | Blocks | Decoded bytes | Commands | Share of row commands |
| --- | ---: | ---: | ---: | ---: |
| Full q11 / external auxiliary postfix | 2 | 3,145,728 | 51,087 | 1.35% |
| Full q11 / wide10 generic | 7 | 48,074,752 | 3,719,747 | 98.65% |
| 1 MiB q11 / external auxiliary postfix | 1 | 1,048,576 | 20,296 | 100% |
| Full q6 / external auxiliary zero postfix | 2 | 3,014,656 | 36,055 | 1.04% |
| Full q6 / wide9 literal | 2 | 4,165,632 | 176,611 | 5.11% |
| Full q6 / wide10 generic | 6 | 44,040,192 | 3,242,842 | 93.85% |

The two complete files contain 51,220,480 plain bytes each. Full q11 command
density is 0.07362 per byte, compared with 0.01936 in the 1 MiB row: about
3.80x. The large q11 blocks use `NPOSTFIX=3`; most have `NDIRECT=16`, while two
have zero direct codes. Full q6 uses `NPOSTFIX=0, NDIRECT=0` throughout.
Therefore a 0/0-only distance optimization does not repair the q11 cliff.

## Whole-stream logical counters

| Row | Commands | Zero insert | Implicit + short applied copies | Regular applied copies |
| --- | ---: | ---: | ---: | ---: |
| Full q11 | 3,770,834 | 28.30% | 54.24% | 44.82% |
| 1 MiB q11 | 20,296 | 54.49% | 51.42% | 47.03% |
| Full q6 | 3,455,508 | 26.68% | 44.97% | 55.03% |

Zero insert uses all commands as denominator. Distance shares use applied
copies, whose count differs from commands by 1/1/8 across these rows. Direct
copy shares are 0.93%/1.55%/0%. Copy-length command histograms include terminal
commands whose insert reaches the end before their copy is applied.

Full q11 has 16.87% of command copy shapes in 2–3 bytes, 41.91% in 4–7 and
28.38% in 8–15; full q6 has 10.71%/40.39%/34.81% in those ranges. All emitted
q11 literals use signed context; all q6 literals use UTF-8 context. Emitted
mode counts alone do not prove that unused header modes are uniform.
Per-block sums and maxima agree with every common whole-summary field.

## Rejected complete-operation screens

Each screen has four interleaved baseline/candidate process pairs for each
row. Each child preserves two measured AB/BA pairs and two warmup pairs
against the same reference. Source hashes and compiler-free boundary snapshots
are checked before and after. Ratios below are baseline/candidate Vort median
batch speedups, geometrically averaged over the four process pairs.

| Candidate | Full q11 | 1 MiB q11 control | Full q6 |
| --- | ---: | ---: | ---: |
| Semantic roots + fixed uniform context/postfix + committed distance phase | 0.990488x | 0.992974x | 0.960493x |
| Same candidate with explicit noinline cold root fallbacks | 0.988713x | 1.000549x | 0.959690x |
| Adopted shared dispatcher/diagnostics, with acceleration removed | 1.011659x | 1.000031x | 1.003146x |

The acceleration variants are negative on the declared target. The shared
dispatcher control is near parity with noisy process-pair samples; it is a
functional diagnostic increment, not a throughput improvement claim. No
screen is a complete 72-row or dedicated-host acceptance gate.

The shared-dispatch screen's original manifest records base revision
`53c49311` while its full source digest binds the diagnostic content later
committed as `6539890e`. The archive preserves the original label and verifies
all 2,062 registered files against that matching immutable content; it does
not treat the screen as clean-source evidence for `53c49311`.

The semantic constructor retains nine-bit roots with two-byte slots, embeds
no-extra command lengths/context and uses staged compact fallback for other
commands. Block switches maintain stable command/distance lookup planes.
Uniform context and postfix are selected once per meta-block; mixed contexts
retain generic calculation. Distance decode/classification/ring commit share
a phase, preserving implicit/short/static-dictionary and truncation behavior.
The two 256-tree planes require 524,288 bytes of lookup storage in addition
to caller and header storage. Neither implementation is adopted.

## Codegen evidence and validation scope

The original candidate's p3/signed payload is 5,658 text bytes with 9,864-byte
stack subtraction, versus 2,567/312 in the baseline generic payload. Cold
command resolution inlined `HuffmanTable(704).init` and large PrefixCode
temporaries into the payload. Static natural-loop counts also show more call,
branch and explicit stack-access sites, including cold branches. They are not
dynamic execution, spill-frequency or cycle counts; the large frame is not
all register spills. The current helpers were inlined, so there is no evidence
of an added hot 24-byte aggregate ABI return.

Explicit noinline command/distance/literal hole fallbacks reduce the p3/signed
payload to 4,477 text bytes and 408-byte stack subtraction. The second screen
still fails to improve the full operation. Remaining live reader/lookup/command
fields and the four-pointer distance cache deserve measurement-driven review;
smaller stack alone does not prove faster execution.

The semantic helper passes Debug/ReleaseSafe 26-test focused gates, including
all 704 command symbols, context invariants, extra-bit boundaries and mapped
root truncation. The complete original payload differential passes 23 tests
in both modes: packed tiers through index 255, every short payload-bit/output
boundary, modes 0–3 and mixed modes, postfix/direct strata, implicit-static
references, dictionary and literal long fallback. The noinline variant passes
its 23-test ReleaseSafe gate. These proofs have separate test-source epochs
and do not retroactively bind the earlier measurement sources.

The adopted diagnostic API passes its 23-test native and actual wasm32-WASI
contract gates, public WASI consumers, and all 72 frozen Brotli wire
correctness/executability rows. The small smoke batches do not supply a
throughput ratchet. It owns bounded discovery output, records, two parsed headers
and a replay window; those allocations and its instrumented stage clocks do
not characterize production Into heap or competitor throughput. See the
[API contract](meta-block-diagnostics.md) and the counter tool's
[usage](../../../tools/br/decode_mozilla/README.md).

The next structural experiment should reduce hot-loop live state and keep
cold expansion separate. A compact active context-map representation may
replace four cached root pointers, but it needs whole-operation and explicit
control evidence before adoption. The full industry-best goal remains unmet;
the complete modern comparison continues to route Deflate, Zstd and Brotli
work alongside this Mozilla investigation.
