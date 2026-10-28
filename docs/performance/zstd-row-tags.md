# Zstd HQ exact state-key tag index

HQ DP rows now keep sixteen one-byte tags beside their nodes. A tag summarizes
pending literal length and all three repeat offsets. Vector comparison finds
the slots whose tags agree; the encoder visits those slots in original order
and still compares every complete key. Collisions only cause extra comparisons.
No tag match alone selects or replaces a node.

The row's tags move with nodes during insertion. Initialization includes the
default sentinel fields and the initial root. Candidate rejection, sentinel
rules, all tie fields and predecessor movement retain the original insertion
behavior, including arbitrary row-element candidate arguments. Match search,
prices, budget admission, selected sequences and complete output are unchanged.
The auxiliary array lives within one DP plan and is reset with every row table;
it adds no global state or retained frame state.

## Ordinary encoder screen

The [evidence package](data/zstd-row-tags-20261029/) compares the codec at
`93926461` with a separate candidate that changes only DP/tagged insertion.
Two balanced AB/BA rounds run Silesia 4 KiB prefixes on CPU 2, Intel i7-10700K,
Zig 0.16.0 LLVM ReleaseFast/Skylake, window log 15 and block maximum 32768.
The ordinary allocating API is timed without diagnostic profiles. Input
preparation, caller output free, decode, hashing and the subsequent independent
profile encode are outside the interval. Background activity and exact binary,
source, input and output identities are retained.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.8804 | 0.7413 |
| Mozilla 4 KiB | 0.8435 | 0.5936 |
| MR 4 KiB | 0.8732 | 0.7140 |

Each cell divides median candidate time by median baseline time. All six
configurations improve in both rounds, with observed reductions of 12%-41%.
MR btultra2's first baseline call is slower than its second, so the raw paired
values remain available. These bounded short-prefix measurements do not prove
statistical significance, general throughput or competitor leadership.

All 24 ordinary encodes and 48 native decodes pass. Full wire bytes and every
profile field except the increased working-memory peak agree. Independent
libzstd 1.6.0 decodes all 24 wire artifacts exactly. The tag index reads its
own sixteen bytes, without reading beyond the three-word repeat key or node
boundaries. Hash collisions always fall back to the original full comparisons.

A separate one-round CPU-2 campaign uses Mozilla 16 KiB and the existing
8192-byte input with its trained 4096-byte standard dictionary, at window log
17 and block maximum 16384. It uses the unchanged large-input runner; input
and dictionary preparation are outside the ordinary timer, followed by an
independent diagnostic encode. Both binaries use the same ReleaseFast/Skylake
flags and differ only by the tag-index candidate.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Mozilla 16 KiB | 0.7812 | 0.5137 |
| Trained dictionary input 8 KiB | 0.8760 | 0.7047 |

All eight ordinary encodes and sixteen native decodes pass, with exact wire
and non-memory profile agreement. The peak increases by 65,552 bytes for all
four configurations, and actual dictionary references remain 78/87. Local
libzstd also decodes all eight wires with the appropriate dictionary. This
single-round result is distinct from the earlier two-round 4 KiB screen and
retains its background compiler load.

## Resource tradeoff

The auxiliary storage adds exactly sixteen requested heap bytes per allocated
DP row, independent of target word size and beam width. Bounded parsing adds
`16 * (min(block_len,4096)+1)` bytes when the parser is used; whole-block mode
adds `16 * (block_len+1)`. Empty and sub-minimum blocks retain their earlier
early return without tag allocation. The 4 KiB screen's peak increases by
65,552 bytes; a whole 128 KiB table requires an additional 2,097,168 bytes.

This allocation uses the caller's working allocator and is included in the
checked preflight. A budget that previously fit exactly must now include those
bytes. Failure is reported before allocating when preflight exceeds the cap;
allocation failures release all earlier storage. The original node layout and
result ownership remain unchanged. The change establishes a measured
speed/memory tradeoff and does not claim a memory improvement.

Continue broader corpus, dictionary, platform and matched-reference measurement,
and reduce remaining HQ transition work. The complete ten-format optimization
goal remains active.

The retained source is saved in `85c03b1a`. Its grouped contracts verify all
256 tags, collision order, high key/tie bits, arbitrary rows, alias candidates
and synchronized shifts, plus 24,576 random insertions. Frozen DP and edge
comparisons cover both layouts, widths 1/8/16, sampled/complete lengths,
dictionary/history, quota prefixes, exact/insufficient resource budgets and
the optional unindexed edge path. Public preflight rejects the old exact cap
and accepts the new exact cap for the same plan.

Snapshot tests pass 14/14 in native Debug/ReleaseFast and actual x86 Debug.
After registration, native Debug, x86 Debug and executed wasm32-wasi each pass
15/15. Current HQ/search/incremental gates pass 385/385, ZIP Zstd streaming
contracts pass 81/81, and versioned bidirectional references pass 52 HQ and
41 expanded-search groups. The common-HQ benchmark gate passes all 24 rows
and its CLI, parameter, dictionary and level-zero negative checks. The final
build check exits zero. Source snapshots, terminal records and an executable
WASI image are retained in the evidence package.
