# Deflate, Zstd and Brotli gap assessment, 2026-11-03

The industry-best objective remains active. Standard formats, dictionaries and
streaming are broadly implemented, but compression speed, high-quality parsing
and decoder throughput still leave measurable gaps. This assessment preserves
the source and workload scope of each archived comparison. It is not a fresh
measurement of every encoder and decoder at the current Git revision.

The subsequent [command-model lifetime](br/command-model-lifetime.md) epoch
preserves every q8 wire while removing repeated model construction across
preferred and adaptive split candidates. Its separate 39-input matrix records
about 0.72% lower real-input latency, including 2.23% at 64 KiB; small-input
groups remain near neutral and weaker controls remain visible. The direct
current-source reference epoch is 30.09 times Brotli 1.2.0 latency at size
0.99556 times reference. Earlier values below keep their own source epochs;
the internal gains are not multiplied into a synthetic overall ranking.

The further [Zstd local-frontier choice-price](zstd/frontier-choice-price.md)
epoch preserves complete native and reference wires, requested settings and
previous work counts across 82 configurations. Twelve-source 4 KiB group
latencies improve about 4.3–4.4%, and 64/128 KiB groups about 2.3–3.1%, while
individual Dickens/MR/SAO/X-ray rows still regress. Its direct current-source
btultra2 reference time ratios are 3.02637/3.06785 at 64/128 KiB and 4.50305
on three actual 1 MiB inputs, with size ratios 1.00480/1.00514/0.99280. Those
parameters and source epochs stay distinct from the earlier comparisons below;
the complete three-codec objective remains open.

The further [first-price component](zstd/first-price-components.md) epoch
retains all wires and counters while avoiding repeated first-edge LL/ML
decoding. Twelve-source 4 KiB groups improve about 0.65–0.87% and 64 KiB
groups 0.45–0.50%; larger groups are near neutral. Long MR64KiB and random
controls still regress. Its current-source btultra2 reference time ratios are
3.01224/3.06648/4.49712 at 64/128 KiB/1 MiB, with the same respective size
ratios. These are independent timing epochs, not chained prior speedups.

## Compression

Time and compressed-size ratios are Vort/reference; lower is better. Geometric
size summaries do not guarantee an improvement on every input.

| Policy and input scope | Time ratio | Size ratio | Evidence |
| --- | ---: | ---: | --- |
| Deflate level 9 versus libdeflate 1.26 level 12; twelve 4/16/64 KiB prefixes | 1.85–1.92 | 1.0007–1.0124 | [BT optimal encoder](deflate-bt-optimal.md), 2026-10-31 epoch |
| Native Zstd btultra2 versus libzstd 1.6.0; twelve 64/128 KiB prefixes | 3.13–3.18 | 1.0048–1.0051 | [Adaptive matcher](zstd-adaptive-matcher.md), 2026-10-31 epoch |
| Same Zstd policy; three actual 1 MiB multi-block inputs | 4.57 | 0.9928 | Same separate multi-block epoch |
| Brotli q8 generic, actual window 16; twelve 4/16/64 KiB prefixes | 31.35 | 0.99556 | [Adaptive literal count](br/adaptive-literal-count.md), separate final-production 2026-11-03 epoch |
| Brotli q10; twelve 32/64 KiB prefixes | 6.62 / 4.88 | 1.0724 / 1.0758 | [Command/model study](brotli-command-start-model.md), earlier epoch |
| Brotli q11; twelve 32/64 KiB prefixes | 5.20 / 2.32 | 1.0986 / 1.1031 | Same earlier epoch |

The explicit q10/q11 `command_state_max_input_kib=64` opt-in reduces the 64 KiB
XML prefix from 4,556 to 4,093 bytes (q10 size ratio 0.9832, q11 1.0412 versus
the reference) at about 2.5x encode time; the default 8 KiB policy and wires
are unchanged. The Deflate levels have different algorithms and budgets. Zstd's native HQ
parser also differs from upstream despite equivalent requested strategy
controls. These are useful points on the speed/size tradeoff, rather than a
complete matched-quality frontier. Zstd periodic 4 KiB controls retain about
8.17/13.30 times reference time for btopt/btultra2.

Brotli q8 buys about 0.44% smaller average output with roughly thirty times
reference time. Its immediate opportunities are exact context-tree scoring,
remaining full candidate emission and parser/model work. Higher qualities
also need better compressed size. Native Zstd needs persistent matcher/index
lifetime across blocks, larger-input search policies and better entropy
pricing. Deflate needs entropy-aware parsing and split planning across
streaming, dictionaries and larger multi-block inputs.

A later 2026-11-04 Brotli quality epoch supersedes the q10/q11 size ratios for
the measured prefixes. Dictionary-aware optimal parsing, a gated
repcode-aware command-state extension, four-class literal pricing and
recent-distance repacking produce this 64 KiB q11 matrix versus libbrotli
1.0.9:

| File | Size ratio | File | Size ratio |
| --- | ---: | --- | ---: |
| dickens | 1.0115 | samba | 1.0139 |
| webster | 1.0151 | reymont | 1.0252 |
| osdb | 1.0378 | XML | 1.0384 |
| sao | 1.0518 | nci | 1.0541 |
| ooffice | 1.0555 | mr | 1.1201 |
| mozilla | 1.1381 | x-ray | 1.0754 |

At 1 MiB q11 the same path measures 1.0976 (webster), 1.0832 (samba) and
1.1202 (dickens). Static-dictionary coverage matches the reference on webster
(1,449 copies / 13,516 bytes versus 1,482 / 13,202), and recent-distance
repacking converts regular distances into repcodes on binary blocks
(ooffice 1.0639 -> 1.0555, x-ray 1.1645 -> 1.1612, mozilla 1.1473 -> 1.1381).
The remaining binary gap is distance/context block typing and repcode share:
sao's reference emits 3,048 short distances against Vort's 114, and the
reference uses up to nine command and four distance block types where Vort
keeps one. Encode time rises roughly 30-50% on affected blocks. These are
separate source epochs and are not multiplied into the earlier ratios above.

The same epoch also improves the low-latency presets at 64 KiB. q1 now uses
64 KiB stream blocks and a content-gated fragment anchor (six bytes for text,
four for binary), and q0 uses a five-byte text anchor and four-byte binary
anchor with unchanged 16 KiB blocks. Size ratios versus libbrotli 1.0.9:

| File | q0 | q1 | File | q0 | q1 |
| --- | ---: | ---: | --- | ---: | ---: |
| dickens | 1.0208 | 1.0120 | samba | 1.0153 | 1.0099 |
| webster | 1.0382 | 1.0114 | reymont | 1.0376 | 1.0036 |
| XML | 1.1295 | 0.9908 | osdb | 1.2382 | 1.0933 |
| ooffice | 0.9112 | 0.9998 | sao | 0.9110 | 0.9142 |
| mozilla | 0.9649 | 1.0311 | mr | 0.8566 | 1.0092 |
| x-ray | 1.0297 | 1.1522 | nci | 1.2072 | 0.9959 |

q0 beats the reference on ooffice, sao, mozilla, mr and x-ray; q1 beats it on
XML, ooffice, sao and nci. Widening q0 to 64 KiB blocks was rejected because
its one-pass entropy writer regressed text by up to 24%.

### Preset ladder, 2026-11-05

The 2026-11-05 preset work adds bounded optimal parses to q3-q7 (q2 stays
lazy-only to preserve its zero-allocation warm reuse) and entropy feedback to
q8/q9. Vort bytes on 64 KiB prefixes, lower is better:

| File | q2 | q3 | q4 | q5 | q6 | q7 | q8 | q9 | q10 | q11 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| XML | 6,447 | 5,210 | 5,109 | 5,105 | 4,996 | 4,795 | 4,539 | 4,505 | 4,082 | 4,082 |
| dickens | 28,349 | 25,920 | 25,447 | 25,380 | 25,260 | 22,816 | 22,412 | 22,387 | 22,381 | 22,381 |
| webster | 24,565 | 22,657 | 22,279 | 22,232 | 22,157 | 19,906 | 19,574 | 19,556 | 19,548 | 19,548 |
| nci | 6,296 | 4,721 | 4,613 | 4,564 | 4,545 | 4,434 | 4,238 | 4,203 | 3,916 | 3,916 |
| ooffice | 33,288 | 31,763 | 31,592 | 31,388 | 31,057 | 30,651 | 30,647 | 30,648 | 30,644 | 30,639 |
| x-ray | 45,915 | 44,974 | 43,298 | 43,327 | 43,290 | 42,488 | 42,488 | 42,455 | 39,317 | 39,317 |

Against libbrotli 1.0.9 the ladder beats the reference at q3-q9 on every row
shown except q5/q6 XML (1.0446/1.0404). The reference's q10/q11 jump is much
larger than Vort's: x-ray is 1.0868/1.0754 at q10/q11 while q9 is 0.9016, and
XML q10/q11 is 0.9803/1.0384 while q9 is 0.9705. Closing q10/q11 is therefore
about matching the reference's high-quality parser, not the lower presets.

A later 2026-11-05 distance-parameter split re-encoding re-encodes the winning
distance parameter set through the lazy/split path. It lowers q11 `sao` from
47,096 to 46,617 bytes at 64 KiB (size ratio 1.0404) and from 728,703 to
721,932 bytes at 1 MiB (1.0701), and q9 `x-ray` at 64 KiB from 42,475 to
41,180 bytes. The other measured q8/q11 rows are unchanged. This closes part
of the binary distance/block-typing gap but does not yet match the reference's
repcode share or command/distance block-type counts.

## Decompression

The newer [preload-before-refill epoch](industry-decode-current-20261101.md)
supersedes the earlier loop-alignment table for broad one-shot Deflate and
Zstd comparisons. Whole-file Deflate level-6/9 time is 1.4523/1.4417 times
libdeflate; the later eleven-source 1 MiB refresh remains about 1.44 times
reference, with individual ratios 1.29–1.53. This corresponds to roughly
69–70% of reference throughput on the whole-file aggregate.

The latest [Zstd raw mixed-sequence matrix](zstd/raw-mixed-sequences.md)
contains five alternating sweeps over twelve sources, levels 3/9,
64 KiB/1 MiB and one-shot/reusable APIs. Recomputing the median of five
per-source candidate/reference ratios and then the twelve-source geometric
mean from the existing records gives:

| Scope | One-shot level 3 / 9 | Reusable level 3 / 9 |
| --- | ---: | ---: |
| 64 KiB | 1.47955 / 1.47572 | 1.39293 / 1.38780 |
| 1 MiB | 1.44170 / 1.44234 | 1.44988 / 1.44665 |

These ratios correspond to about 68–72% of reference throughput. Mozilla
1 MiB level 3 remains around 1.72 times reference time; XML 64 KiB level 3
is about 2.19 times for one-shot and 2.00 times for reusable. The recomputation
uses the archived `zig-out/zstd-raw-mixed-20261102/matrix-report.json` with
the SHA-256 recorded in the linked report; it does not add a timing epoch.
Earlier internal speedups are not multiplied into these reference ratios.

Brotli's [broad one-shot epoch](industry-decode-current-20261101.md) retains
full-file q6/q11 time ratios 1.2170/1.2251 versus Brotli 1.2.0, with broader
64 KiB/1 MiB/full-file scope ranging about 1.12–1.49. Incremental Deflate's
[compact-table increment](deflate/compact-tables.md) improves its own previous
source; a current zlib-ng streaming comparison is still needed. Performance
above classic zlib on selected rows does not establish the modern streaming
bar.

## Functionality and evidence

The subsequent [Deflate circular staging](deflate/rolling-window.md) epoch fixes
legal capacity/refill failures and empty reservoir ownership while retaining
64 KiB caller storage. Direct final/pristine whole-input incremental latency
falls 33–34% at 64 KiB and 13.8–14.4% at 1 MiB over twelve Silesia sources;
4 KiB input groups remain near neutral. The strict corrected-reference matrix
passes 208 runs with all reader fields and history compared. Dickens, selected
fragmented rows and one-shot MR controls retain measured regressions. These
internal increments do not supply a new libdeflate or zlib-ng ranking; the
one-shot reference epochs above keep their own source identities. The
[prepared distance-parameter pair](br/distance-parameter-pair-20261103.md) now
counts both q8 alternatives from retained command and literal models, emits
only the local winner and skips pairs that lose to the incumbent; twelve
64 KiB Silesia wires stay byte-identical while full candidate emissions fall
24→4, and 256 KiB/1 MiB rows within the 1,048,576-command bound extend the
same reduction with about 6.5% and 8.9% geometric encode-time gains. The next
Brotli q8 targets are counted preparation for the remaining split and HQ
candidate families, preserving the original parameter chooser and strict ties.

The [functional audit](industry-gap-audit.md#current-functionality) records
flush and recovery, dictionaries, incremental I/O, Zstd training/seekable/MT,
and Brotli shared dictionaries/Large Window. The
[prepared standard Zstd decode dictionary](zstd/prepared-decode-dictionary.md)
now validates and reconstructs one entropy snapshot that frames reuse, while
mismatched owners are rejected before entropy work. The
[Deflate block-boundary checkpoint](deflate/block-boundary-checkpoint.md)
exposes a one-shot boundary step and query for raw, zlib, gzip and stored-only
incremental decoders. The
[resumable Brotli compressed header](br/resumable-compressed-header.md)
retains completed sub-parsers and Huffman trees across small input chunks and
now resumes inside the Huffman symbol-length phase; the one-byte
`br/dictionary.bin` probe falls from 2.886 ms to 2.277 ms. A consumed-bits
retry lower bound was rejected because one-byte chunks always clear it. The
[grouped Zstd sequence planner](zstd/repeat-planner-20261103.md) visits only
code-matching FSE states in the repeat DP, uses an O(1) next-state map for
compressed transitions, inlines per-sequence symbol dispatch, skips the repeat
DP above 4,096 sequences, computes the absolute offset code in closed form and
reuses the cached planner for state-dependent large-block re-emission,
deduplicates match-seed anchors, carries prepared final repcodes into commit,
reuses encoder records during re-emission, emits large candidates directly
against the current frame state, scans intra-block matches without segment
dispatch, skips the repeat DP above 2,048 sequences, marks the dictionary hash
segment unlikely, hashes contiguous history seeds directly and reads block
hash lookups from the block, uses long matches for text, a lazy lookahead in
the double-fast engine for extremely repetitive blocks and repeat-offset
eligibility/direct-extra fast paths; the 1 MiB XML level-1 fast encode is 6.60
times faster at
167,595 bytes, 10.6% below the original baseline and 1.2% smaller than libzstd.
The dedicated upstream Zstd decodecorpus gate passes 9 campaigns,
9,900 cases and 5,376 block-stream cases with all 64 sequence-mode
combinations, including raw, RLE and 64 KiB-1 MiB dictionary variants. A
[bounded six-file Silesia q8 screen](br/full-file-q8-20261103.md) finds Vort
1.7% smaller but 3.6 times slower than system libbrotli q8, identifying q8
encode speed as the next concrete Brotli gap. The
[q8 stage profile](br/q8-stage-profile-20261103.md) routes that work by
content: XML is dominated by optimal parsing (63.8%), x-ray by wire emission
(40.7%), and context proposals remain 17–22% across all. The
[table-driven context lookup](br/context-lookup-20261103.md) lowers q8
planned encode time 7.4% geometrically on the same six-file screen with
unchanged wires. The
[q8 perf profile](br/q8-perf-profile-20261103.md) attributes the next gap to
the LZ77 match finder (46% process self time), the distance chooser (5.7%) and
the context group's physical encode (4.0%); a window-sized predecessor ring
was rejected at 2.2% slower, and a counted plain baseline was rejected at 1.0%
slower; tree-score cache growth and a maximum-distance precheck were also
rejected. An
[LSD radix sort](br/distance-radix-sort-20261103.md) for distance frequencies
lowers q8 planned time a further 0.26% on the same screen with unchanged
wires. Finite matcher candidates, parsing states and entropy priors remain
quality limits even where all lengths of an admitted match are considered.

No complete current-source matrix covers compressed size, encoding, decoding,
requested heap and RSS across all levels, full files, cold/warm calls,
dictionary/reusable/streaming APIs and CPUs. Allocator budgets and smaller
scratch tables establish resource contracts; they do not establish a memory
lead over competitors. Native x86-64 timing and Wasm/32-bit correctness checks
also do not establish ARM64 throughput leadership.

The next priorities are Brotli q8 context-tree scoring and candidate output,
Brotli/Zstd HQ speed/size tradeoffs, profitable decoder structural changes,
and symmetric full-file/dictionary/streaming/memory/platform comparisons.
Each completed increment must keep the larger three-codec objective active.
