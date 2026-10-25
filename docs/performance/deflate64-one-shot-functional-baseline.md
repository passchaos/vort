# Deflate64 one-shot full-match functional baseline

Date: 2026-10-25. Baseline: `06d8909c`. The long-term industry-best functionality
and performance objective remains incomplete.

The compressed incremental encoder covers Deflate64's full distance and length
range, while one-shot raw encoding and ZIP writing previously used a separate
u16-token planner limited to distance65535 and length258. This increment reuses
the bounded matcher and fixed-block emitter for one-shot encoding. It removes
that full-match discrepancy without changing explicit stored APIs, output bound
or transactional Into/Append behavior.

## Shared core, borrowed input and whole-stream selection

Public `EncodeOptions` keeps max_chain128 and nice_length128 defaults. Nice is
now u32 and permits0...65538;0...2 retain stopping after the first eligible match,
rather than disabling matching. Values above65538 fail before allocation. Zero
max_chain produces no matches, but fixed literal coding can still be smaller
than stored; explicit no-compression output uses the stored APIs.

`one_shot.zig` borrows input in128KiB chunks and each preceding64KiB history.
The published stream matcher/emitter are reused unchanged: actual distances
through65536, lengths through65538, code285 plus16-bit extension and258 through
code284. Fixed blocks keep a continuous bit reservoir and one final padding.
No complete input clone, retained token plan, copied history or per-chunk encoded
candidate is allocated. Two passes reuse a393216-byte hash-index payload.

The first pass computes the complete fixed-stream cost. Only a fixed candidate
strictly smaller than the original global stored representation gets an exact
output allocation; ties/larger candidates use original global stored segmentation.
Consequently the old `encodedBound(n)=n+5*max(1,ceil(n/65535))` remains valid.
Independent stored chunks per128KiB would add headers and could exceed that
bound, so the encoder does not use mixed per-chunk stored fallbacks here.

Planning uses private u128 bit/byte costs. Every literal uses at most9 bits;
every match token uses at most9 times its consumed bytes, and each fixed block
adds10 header/EOB bits. Total bits are at most`9*n+10*ceil(n/131072)`, below2^68
for everyusize32/64 input geometry. Checked accumulation therefore has ample
range without approximate costs or match limits. Quotient/remainder ceiling
avoids a`bits+7` overflow. Candidate size compares with stored in the wide
domain, and only a strict winner converts to usize for allocation.

An initial candidate used the existing BitCount/ceilBytes helper, narrowing the
losing fixed result to usize too early. On a narrow target that could reject a
fixed candidate larger thanusize even though stored output still fits. The
review caught this theoretical boundary; the final privateu128 comparator fixes
it. Initial passing wire/test/full-check evidence retains its own source epoch
and is not relabeled as final. Numeric tests cover a36-billion-bit losing
candidate, ties, rounded bytes and usize/u128 maxima without physically allocating
huge input. These arithmetic tests are not a huge-file performance measurement.

`encodeInto` completes an owned encoded result before checking/copying caller
output. `encodeAppend` completes encoding before resizing its destination.
Thus allocation failure, too-small output and input/output aliases preserve
existing publication rules. The explicit stored functions, encodedBound and
Into/Append bodies remain byte-identical to the baseline. ZIP one-shot method9
already calls this public API and gains the same full-range matcher.

## Independent correctness and ownership

Final native Debug, native ReleaseFast and actual32-bit x86 Deflate64 suites
pass99/99 under stable fullsrc/tools/build snapshots. The count is lower than
the previous183 because the dedicated core no longer imports the old generic
LZ77 planner and its transitive tests; Deflate64's old codec contracts and new
full-range/transaction contracts are retained.

An independent bit-by-bit fixed/stored inspector reads actual encoder output,
checks code285 length65538, code284 length258 and distance31 value65536, and
reconstructs stream boundaries. It does not use the new match classifier.
Decoder round trips cover empty/tiny/structured/random/repetitive and multi-chunk
input. All-fixed incremental output with the same128KiB geometry provides a
complete-wire oracle whenever it beats stored; otherwise the original global
stored output must match byte-for-byte.

The tests cover more than two128KiB input chunks, maximum match values, input
and output preservation, exact/below caller capacity, overlapping Into, moving
Append input alias, every actual encoder and destination allocation failure,
invalidnice admission before allocation and literal-only arbitration. A prior
QA assumption that max_chain0 always selects stored was corrected: repeated
8-bit literals can beat stored, while a separate deterministic random fixture
proves genuine global stored fallback. No production policy was changed to fit
that test assumption.

Pure candidateGeometry tests cover0/1/7/8/9/10/15/16/17 bits, byte rounding and
ties, maxusize boundaries,36e9 bits versus a32-bit-representable stored size,
and u128max. Winner-only narrowing is therefore exercised directly, without
fake slices or impossible input allocation.

The initial ZIP focused suite passes44/44 on native Debug/x86 ReleaseFast,
including the existing incremental/error/encryption contracts and three new
one-shot cases. Actual repeatedR65539 produces six compressed bytes with independently
checked fixed codes/CRC/descriptor. Random64KiB plus duplicate compresses below
75% in ZIP64 and round-trips. Invalidnice preserves ZIP Append's pointer,
capacity and prefix. Initial complete ZIP/codec tests pass1992/1992 and global
checks176/176; those initial corrected pricing runs retain their separate
source epoch. The finalu128-price complete ZIP/codec suite also passes1992/1992
under stable complete source snapshots. The final global check passes176/176
and CLI help7/7 after the wide-price correction.

## Actual external wire verification

The public fixture tool now emits schema v2: eight deterministic inputs with
stream raw and known/unknown ZIP at two quota schedules, plus one-shot raw and
one-shot known-size ZIP. One-shot artifacts use null pattern/progress, without
fabricated streaming counters. A300000-byte periodic input verifies at least
three actual compressed fixed blocks and retained cross-block matching.

Independent Python token parsing validates complete contents, fixed/stored/
dynamic token geometry, maximum lengths/distances, ZIP metadata/descriptors/CRC
and one-shot payload size<=the original bound. Python zipfile reads metadata
only; UnZip6.00 advertising USE_DEFLATE64 tests/extracts full members.
Final native and x86 tool runs each pass7/7 steps,48 artifacts,64 members
and90 recorded commands. All48 artifact/progress/input manifest fields are
identical across targets. Its complete manifest matches the initial candidate's actual bytes,
progress and inputs exactly; theu128 correction does not change these wires.
The reference executable/version and source/input/output/probe hashes are retained.

One-shot boundary artifacts come from the public encoder, not manual tokens.
Long repeated65539 input emits6 bytes;70003 repeated bytes emit10. A65536-byte
random prefix plus its duplicate emits69098 bytes and an actual65536-distance
match. The300000-byte periodic input emits67 bytes across three fixed blocks.
These are functionality/encoded-size fixtures, not a competitor throughput or
compression-ratio ranking. The widened search and wire construction can change
adaptive bytes; explicit stored output remains unchanged.

## Same-default old/new size and allocator observations

A separate old/current public probe encodes the same seven frozen inputs using
defaultchain128/nice128. It verifies round trips, input hashes and full output
hashes. Allocation counts and total requested bytes describe all allocator
requests during the call, not simultaneous peak, stack, retained RSS or a
cross-library memory comparison. The final pricing correction preserves these
emit decisions; source epochs and executable identities are kept separate.

| Input | Old encoded bytes | New encoded bytes | Old/new allocation requests | Old/new total requested bytes |
| --- | ---: | ---: | ---: | ---: |
| Empty | 2 | 2 | 3 / 1 | 131203 / 2 |
| Tiny16 | 18 | 18 | 5 / 3 | 131379 / 393234 |
| Pattern12079 | 201 | 53 | 7 / 3 | 205181 / 393269 |
| Binary16387 | 16392 | 16392 | 13 / 3 | 411649 / 409608 |
| Repeated70003 | 614 | 10 | 7 / 3 | 438364 / 393226 |
| Repeated65539 | 576 | 6 | 7 / 3 | 420406 / 393222 |
| Random65536 + duplicate | 131087 | 69098 | 14 / 3 | 1984031 / 462314 |

The fixed index eliminates whole token-plan growth but costs more total requested
memory on small/tiny pattern inputs. This material tradeoff is retained; the
change does not establish uniformly lower memory. Empty input avoids the matcher
entirely. Tiny-input index sizing/fast paths are future optimization work.

The [evidence package](data/deflate64-one-shot-20261025/artifact-manifest.json)
retains initial/final source epochs, numeric boundary
finding and proof, exact independent tests, old/new sizes, reference identities
and final handoff checks. Dynamic Huffman, preset dictionaries, match-profitability,
ratio/speed tuning and broad corpus/platform/streaming memory leadership remain
open. Snapshot cloning or a new public resource quota is not introduced here.
