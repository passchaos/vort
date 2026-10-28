# Zstd HQ sampled ML interval tail stop

Sampled HQ parsing stops walking ML symbol intervals once their lower bound
reaches the candidate's maximum match length. The standard ML lower bounds
strictly increase and each upper bound is at least its lower bound. All later
intervals therefore fail both original strict `< maximum` tests. The maximum
length was already processed as the first sampled edge.

The change removes unsuccessful loop iterations while keeping admitted edges
in the original order, including duplicates and all upper endpoints. In
particular, an upper endpoint can be eligible when its lower endpoint is at
or below the exhaustive cutoff; the implementation keeps that behavior.
Complete enumeration, prices, checked node costs, insertion, spill handling,
profile counters and price-budget admission are unchanged. No additional
allocation or persistent state is required.

## Measurement

The preceding [ordinary CPU sampling](zstd-prepared-pricing-screen.md#ordinary-only-follow-up-sampling)
identified the ML loop and its conditions as 8.73% of Mozilla btultra2 and
16.13% of Dickens btopt sampled periods, excluding admitted pricing/insertion.
That footprint motivated this change; it was not a predicted speedup.

The [timing evidence](data/zstd-ml-tail-20261028/) compares
`bdae5ce7128e30fee20e20e16612844a818cf1ff` with a candidate differing by the
single tail-stop line. CPU 2, Intel i7-10700K, Zig 0.16.0 LLVM ReleaseFast and
Skylake code generation are recorded. This timing binary uses ordinary frame
pointer defaults, distinct from the earlier sampling binary. Two balanced
AB/BA rounds use Silesia 4096-byte prefixes, window log 15, block maximum
32768, checksums and no dictionary.

Ordinary allocating encode is timed independently. Input setup, output free,
decode, writing and hashing, and the subsequent diagnostic-profile encode
are outside its interval. Each process makes one ordinary call without an
explicit warm-up. Raw clocks, background processes and exact source/input/
binary/wire identities remain available.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens | 0.9375 | 0.9069 |
| Mozilla | 0.9307 | 0.9498 |
| MR | 0.8761 | 0.8489 |

Each cell divides median candidate time by median baseline time. Every
configuration improves in both rounds; observed elapsed-time reductions are
5.0%-15.1%. All 24 ordinary encodes and 48 native decodes pass, complete wires
and every profile field match, and independent libzstd 1.6.0 decodes all 24
wire artifacts. Candidate function code grows from 2064 to 2074 bytes.

A separate one-round CPU-2 epoch uses Mozilla 16 KiB and an 8 KiB input with
the previously trained 4096-byte standard dictionary, at window log 17 and
block maximum 16384. The unchanged large-input runner prepares/parses input
and dictionary before timing; its independent diagnostic encode follows the
ordinary call. Both versions use the same ReleaseFast/Skylake flags.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Mozilla 16 KiB | 0.9233 | 0.9134 |
| Trained dictionary input 8 KiB | 0.9180 | 0.9385 |

All eight ordinary encodes and sixteen native decodes pass, full wires and
profiles agree, and independent libzstd also decodes all eight wires with the
appropriate dictionary. The dictionary configurations preserve 78/87 actual
references and one parsing pass with no refinement. This epoch remains
separate from the earlier two-round 4 KiB matrix.

## Validation

The retained implementation is saved in `cf33bfa0`. Four independent contract
groups compare public `candidate` calls against the exact frozen `bdae5ce7`
search-edge module. Tests cover both predecessor layouts and widths 1/8/16,
all ML lower/upper neighbors, repeat aliases, zero literals, direct offsets,
and the existing boundaries outside a requested higher minimum. Every finite
quota is checked at an actual ordered admission prefix. Complete nodes,
profiles, admitted/refused budgets and error precedence agree, including
invalid-symbol preparation, exact/overflowing costs, saturated counters,
whole-block predecessors and bounded complete spill continuation.

Small cases compare all rows; large cases allocate real backing storage and
compare every possible sampled endpoint and adjacent guards, using width one
to keep test storage below 64 MiB. The frozen module's SHA-256 is
`6fc3e666e3e43e817fad5abe6aa481c1cad10aaee36f9c284db80f26618e6383`.
The implementation adds a test registration and explanatory comment after
the timing prototype; its runtime change remains the single tail stop.

The independent snapshot passes 8/8 checks in native Debug, native ReleaseFast
and actual x86-linux Debug. After main-tree registration, standalone native
Debug/ReleaseFast and executed wasm32-wasi each pass 9/9. Current-source
HQ/search/parallel-incremental tests pass 369/369. Versioned bidirectional
interop with matching local libzstd 1.6.0 and the system reference passes 52 HQ
groups and 41 expanded-search groups, including old-wire freezes, dictionaries,
refinement and budget behavior. Exact outputs, source hashes and terminal
records are retained in the evidence package.

The broader build check completes all 210 steps with exit code zero, followed
by a successful cached check on the final registered test source. Formatting
and evidence integrity checks also pass. The previous full-library test
epochs are separate; this increment records its own focused and build gates.

These are bounded exploratory observations on small real prefixes and
background scheduling. They do not establish general compressor throughput,
statistical significance or industry-best performance. The complete
deflate/zstd/brotli/lz4/xz/zip/rar/tar/bzip2/snappy objective remains active.
