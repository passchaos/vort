# Deflate checked completed-match codegen screen, 2026-11-12

The prototype is rejected before performance A/B. A checked u32 descriptor
can represent length 3..258 and distance 1..32768 in 25 bits. Values outside
those ranges retain the original full-width scalar fallback, preserving
private outlier behavior and the existing error/reader/copy boundaries.

The intended benefit was one carried copy value across next-entry
preload/refill. Machine code materializes the descriptor, but also retains
scalar length and distance and adds tag/payload pointers. The descriptor and
tag occupy stack slots; the intended reduction in live state is not achieved.
No compiler barrier, forced assembly or alternative unchecked truncation is
introduced to make the result appear favorable.

The matched baseline already includes the final wide-copy functional boundary:

| Static generic aligned scope | Baseline | Prototype |
| --- | ---: | ---: |
| Symbol bytes | 3,669 | 4,001 |
| Local stack reservation | 296 | 328 |
| Instruction lines including padding | 896 | 969 |
| Whole ELF text bytes | 927,961 | 928,473 |

Baseline SHA is `e8377941...`; candidate SHA is `ff60e8d1...`. Whole-symbol
negative-rbp references 131→128 do not establish fewer dynamic spills. These
are static measurements with original CPU0 nm/objdump files, not throughput,
retired instructions or dynamic path counts.

The helper's two ReleaseSafe tests cover all 8,388,608 legal combinations.
Filtered public/private-fallback ReleaseSafe passes 11 aggregate/import tests;
complete Deflate passes 739/739; the ReleaseFast compare build passes 7/7.
Successful correctness does not establish the intended architectural benefit.
No codec benchmark or profile was run for this prototype, and none is adopted.

The [archive](completed-match-codegen-20261112/README.md) preserves exact sources,
patch, baseline/candidate executables, raw test/build/static-inspection output,
the producer-defined dependency registry and scope. The mainline remains on
the original Huffman entry/refill layouts. A future handoff design must prove
that it reduces carried state while retaining checked fallback and output/error
contracts before another whole-operation campaign.
