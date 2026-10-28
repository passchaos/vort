# Zstd row-tag node comparisons check cost before tie fields

Row-tag insertion now makes its existing unsigned cost decision explicit
before evaluating the rest of `state.less`. When costs differ, cost alone
determines acceptance. Equal costs still use every original literal/repeat,
match-length, offset, distance and predecessor tiebreak in the original order.
The duplicate-key scan, selected replacement slot, sentinel rules, shifts and
tag synchronization are unchanged. This is not an early worst-node rejection:
the final comparison still occurs only after the complete required key scan.
The implementation is saved in `52eccf45`.

The mathematical identity is exact for all unsigned costs:
`!less(candidate, old)` equals `candidate.cost > old.cost ||
(candidate.cost == old.cost && !less(candidate, old))`. Making that branch
explicit lets LLVM avoid loading unrelated node fields when costs differ.
The two native insertion specializations shrink from 1031/1050 to 704/707
bytes. No new storage or change to price admission, candidate order, profile
counters, sequence planning or wire bytes is introduced.

## Ordinary encoding measurements

The [evidence package](data/zstd-cost-first-20261029/) retains the current
`7adf8393` baseline and an isolated cost-first candidate. Two CPU-2 AB/BA
rounds use Silesia 4096-byte prefixes, btopt/btultra2, window log 15, block
maximum 32768 and checksums. Zig 0.16.0 LLVM ReleaseFast/Skylake and both fresh
binary identities are recorded. Ordinary allocating encode is timed; input
setup, caller frame release, decode and separate diagnostic encode are outside
the interval. The generated code is inspected in those non-FP binaries.

| Input | btopt candidate/baseline median time | btultra2 candidate/baseline median time |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.9543 | 1.0847 |
| Mozilla 4 KiB | 0.9026 | 0.8975 |
| MR 4 KiB | 0.9508 | 0.9281 |

The ratios divide median candidate time by median baseline time. Five
configurations improve in both rounds by 4.6%-10.2%. Dickens btultra2 has
paired ratios 0.9494/1.2229, including one substantially slower candidate call.
Its aggregate is not presented as a speedup, and the cause of that delay is
not established. Original raw clocks and background activity remain frozen;
no favorable additional 4 KiB round was added.

A separate one-round campaign includes Dickens 16 KiB, Mozilla 16 KiB and the
trained 4096-byte standard dictionary with its 8 KiB input. It uses the same
source variants and an unchanged large-input runner with window log 17 and
block maximum 16384, balancing baseline/candidate order across configurations.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens 16 KiB | 0.9617 | 0.8473 |
| Mozilla 16 KiB | 0.8944 | 0.8962 |
| Trained dictionary input 8 KiB | 0.9435 | 0.8889 |

All six larger configurations improve in this single round, by 3.8%-15.3%.
Across both epochs, 36 ordinary encodes and 72 native decodes pass, with
identical complete wires, every profile field and requested heap peaks.
Independent libzstd 1.6.0 decodes all 36 wire artifacts with the appropriate
dictionary. Actual dictionary references remain 78/87. These limited
background-loaded observations do not establish statistical significance,
general throughput or industry-best speed; the small delayed call is preserved.

## Exactness and retained alternative

The small frozen-reference suite checks costs 0, 1, 2^63, max-1 and max, with
below/equal/above cases, every tie field, distinct colliding keys and exact
first-slot duplicates. It compares complete nodes/tags and return values with
the untouched baseline, including arbitrary rows, sentinels and actual
row-element alias arguments. All 256-tag collision fixtures and 24,576 random
insertions also run through both implementations. The suite has no sorted-row
precondition and creates no production allocations.

An independent private edge-borrowing alternative is archived separately. It
keeps public `candidate` arguments by value but borrows the stable local node
and choice into synchronous `extend`. Its six-configuration screen shows five
small two-round improvements of about 1%-4%; Dickens btultra2 is near parity
with mixed rounds. Its frozen edge, alias, quota and error contracts pass
7/7 on native Debug/ReleaseFast and x86 Debug. It is not combined with the
retained cost-first kernel, so the measured effects remain attributable.

The registered current cost contract passes 4/4 on native Debug/ReleaseFast,
actual x86 Debug and executed wasm32-wasi. Existing HQ/search/incremental
gates pass 389/389, and versioned bidirectional references pass 52 HQ plus
41 expanded-search groups. The broader build check exits zero. The exact
source/contracts, terminal results, reference campaigns and executable WASI
image are retained separately from the timing prototypes.

Continue matched ratio/speed/memory measurements on broader corpora and
reduce remaining edge materialization and state-transition work. The full
deflate/zstd/brotli/lz4/xz/zip/rar/tar/bzip2/snappy objective remains active.
