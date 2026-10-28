# Zstd sampled ML endpoint pricing reuses the enumerated symbol

The sampled ML range loop already knows the match-length symbol for each lower
and upper endpoint. The retained implementation passes that symbol to a
private inlined pricing helper instead of classifying the same length again.
The helper still validates literal length first, verifies its private ML-range
precondition in Debug, validates the offset and evaluates the original price
sum. The public `sequencePrice` remains unchanged.

Only the sampled range endpoints use this specialization. The first maximum
length, short exhaustive loop and complete-length mode retain their original
classification. Candidate order, duplicate lengths, exact repeat selectors,
price-budget admission, checked node costs, row tags and spill continuation
remain unchanged. In particular, upper length 66 stays code 39 even when a
higher requested minimum would otherwise exclude it; that existing private
Context behavior is preserved. No storage or allocator request is added.

The implementation is saved in `8819c178`. Its [evidence package](data/zstd-known-ml-20261029/)
includes the preceding ordinary CPU samples, all independent timing epochs,
frozen current pricing/edge references and portable contract tests.

## Current ordinary hotspot

Ordinary-only CPU-2 sampling at the `e654641d` baseline uses Zig 0.16.0 LLVM
ReleaseFast/Skylake with frame pointers and 1999 Hz user CPU samples. Mozilla
4 KiB btultra2 runs eight encodes; Dickens 4 KiB btopt runs 256. Both execute
zero diagnostic encodes, keep identical repeated wires and pass native decode.

| Global user-period share | Mozilla btultra2 | Dickens btopt |
| --- | ---: | ---: |
| Edge extension | 51.11% | 19.85% |
| Inline price calculation within extension | 20.00% | 6.39% |
| ML classification within price calculation | 6.71% | 1.24% |
| Row-tag insertion | 28.52% | 24.47% |

The shares use raw IP periods over the entire recording, with current symbol
addresses; the pricing rows are subsets of extension. They include different
classes of edge visits and are not a forecast of removable cost. Sampling
skid, short runs and background scheduling limit precision.

## Timing evidence

Both ordinary timing binaries are freshly compiled from the same baseline,
differing only by the sampled known-symbol helper and calls. Two balanced
AB/BA rounds use Silesia 4096-byte prefixes, window log 15, block maximum 32768
and checksums on CPU 2 with non-FP ReleaseFast/Skylake. Input preparation,
caller release, decode and a separate independent profiled encode are outside
the ordinary allocating-encode timer.

| Input | btopt candidate/baseline median time | btultra2 candidate/baseline median time |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.9703 | 0.7846 |
| Mozilla 4 KiB | 0.9741 | 0.9992 |
| MR 4 KiB | 0.9878 | 0.9108 |

The three btopt configurations improve in both rounds by roughly 1%-3%.
Dickens btultra2's second baseline call rises from 19.910 to 30.453 ms; MR's
first baseline is 36.272 versus 29.943 ms later. Those aggregates are therefore
not claimed as stable 9%-22% gains. Mozilla btultra2 is near parity. All 24
ordinary encodes and 48 native decodes preserve complete wires and profiles.

The first independent larger/trained one-round matrix has direct compilation
overlap with CPU 2. Its full raw results remain archived for correctness and
timing transparency, but it is excluded from stable performance conclusions.
For example, Mozilla btopt's baseline ordinary call is 121.785 ms while its
subsequent independent profile call is 84.838 ms. Its 0.6508 time ratio does
not establish a 35% encoder speedup.

A second two-round larger/trained matrix reuses the exact same binaries and
source. The agent requested a restricted affinity for its existing compiler
subtree, without terminating work. Later children were observed outside that
set, so complete isolation was not established. Background snapshots did not
observe a high-CPU process leader on CPU 2 during this follow-up, but snapshots
are limited observations. The correction and affinity records are retained;
this remains an exploratory run with background compilation.

| Input | btopt candidate/baseline median time | btultra2 candidate/baseline median time |
| --- | ---: | ---: |
| Dickens 16 KiB | 0.9696 | 0.9982 |
| Mozilla 16 KiB | 0.9849 | 1.0009 |
| Trained dictionary input 8 KiB | 0.9774 | 0.9836 |

The three btopt configurations improve in both follow-up rounds by about
1.5%-3%; trained btultra2 improves about 1.6%, while the other btultra2 rows
are near parity with mixed directions. This evidence supports a modest
increment without statistical-significance, clean-host or industry-best claims.
Every epoch keeps complete wires, profiles and heap peaks identical, including
78/87 actual dictionary references. Across the three epochs, 60 ordinary
encodes and 120 native decodes pass, and local libzstd independently decodes
all 60 wire artifacts with the appropriate dictionary.

## Validation and generated code

The private known-ML extension is 766 bytes; the original general extension
remains 962 bytes, and candidate enumeration grows from 622 to 628 bytes.
The two paths are explicit compile-time specializations, avoiding a per-edge
optional cache or dynamic pricing mode. The code-size increase is retained
as part of the tradeoff; requested heap and price counts do not decrease.

Frozen current scalar pricing validates seven models at every LL and ML lower/
upper endpoint, repeat/direct offsets and long-offset penalties, including the
maximum valid price of 71,424. Frozen edge comparisons cover complete node/tag
tables, profile, every quota prefix, errors, checked overflow, aliases and
spill behavior with both layouts, widths 1/8/16 and tagged/fallback contexts.
The old helper defaults remain compatible; the new tests select their own
frozen reference and entropy model explicitly.

Native Debug/ReleaseFast, x86 Debug and actual wasm32-wasi each pass 7/7
specialized checks. Current HQ/search/incremental gates pass 395/395 and ZIP
Zstd streaming checks pass 81/81. Bidirectional references pass 52 HQ and
41 expanded-search groups. Final source identity and validation records remain
separate from the measured prototype; the helper's added documentation comments
are the only source difference after those reference campaigns.
The broader build check completes with exit code zero. Evidence integrity and
formatting checks also pass; earlier full-library test epochs remain separate.

Continue reducing edge materialization and state-transition work, broaden
full-file ratio/speed/memory comparisons and preserve all ten requested formats
in the long-term optimization objective.
