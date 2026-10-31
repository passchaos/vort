# Brotli complete-command cost-model study

The default q10/q11 parser previously uses generic fixed and separable modeled LZ77 proposals. Those proxies omit literal contexts, joint insert/copy command symbols and path-dependent recent distances. This study tests complete command endpoints priced from an ordinary writer model, using the local Brotli reference design as an algorithm guide. All measured parser variants remain isolated; none is adopted into the default encoder.

## Algorithm and interoperability

The reference is Brotli commit `558fc647cdaf391228d614ca85f711e02e4e583b`. Its HQ parser uses literal prefix costs, a command-start queue, increasing-length match frontiers, minimum useful-length bounds and long-match policies. The Vort prototype retains exact command/distance representations through the writer. A finite entropy prior for unseen symbols permits alternatives missing from the seed tree without replacing observed singleton zero-bit costs.

A real 32 KiB Dickens candidate exposed a split-planner bug: it reconstructed canonical symbols while the writer retained exact choices. The adopted `symbol_projection` module derives both split histograms and distance ordinals from the same resolver and repeat ring as emission. The bounded prepared cache and fast emitter now retain exact command/distance selections for complete standard `(0,15)` frames with no metadata. Model capture, final wire state, temporal splits and Large Window retain their existing eligibility rules. Seven permanent named contracts cover explicit code zero, regular/short aliases, terminal commands, multi-type adaptive distance splits, cold/warm codebooks, large-command fallback, static/compound cache effects, changed keys, caller guards and allocation failures.

## Ordinary timing epoch

CPU: Intel Core i7-10700K, logical CPU2. Zig 0.16.0, ReleaseFast, `x86_64-linux-gnu`, `skylake+pku+sgx`. There are two serial sweeps with reversed variant order and one measured encode per process. Input loading, warm encode, decoding, determinism checks, SHA256 and freeing output are outside the timed interval. 756 processes produce 54 configurations: all twelve Silesia 32/64 KiB prefixes at q10/q11 plus six control configurations. This epoch compares against the same frozen Vort baseline; it contains no competitor throughput timing.

Ratios below are geometric means across all twelve real prefixes. A time ratio below one is faster; a wire-size ratio below one is smaller.

| Quality / input | One start, lazy model: time / size | Two starts, lazy model: time / size | Priced lazy model: time / size | Exact cache: time / size |
| --- | --- | --- | --- | --- |
| q10 / 32 KiB | 1.492481 / 0.979471 | 1.916587 / 0.977757 | 1.999322 / 0.976774 | 1.986873 / 0.976774 |
| q10 / 64 KiB | 1.608939 / 0.965854 | 2.172689 / 0.965129 | 2.248503 / 0.964335 | 2.247858 / 0.964335 |
| q11 / 32 KiB | 1.422465 / 0.979931 | 1.871997 / 0.978334 | 1.926061 / 0.977391 | 1.915347 / 0.977391 |
| q11 / 64 KiB | 1.523730 / 0.965861 | 1.982668 / 0.965137 | 2.029411 / 0.964343 | 2.046771 / 0.964343 |

Direct lazy-model seeding removes the generic fixed/model parser proposal, but the complete-command work still costs more than the baseline. The fastest variant lowers real-file size by about 2.0–3.4% while taking 1.42–1.61x the time. Exact prepared caching has no consistent material end-to-end gain over its priced parent. Control aggregates take 11.94–16.16x baseline time for the direct-lazy variants; baseline candidates can exit after finding no useful matches, while the new parser still performs work. These regressions prevent default adoption.

The earlier native-queue, entropy-prior, compact-layout and price-cache epochs retain independent raw reports. Their time ratios are not multiplied with this epoch or with dated upstream Brotli comparisons. Prefix results do not establish full-file quality or industry leadership.

## Full-family verification findings

The first complete ReleaseFast Brotli family run reported 1490 passes, one skip and six failures. The identical six failures were reproduced in the frozen pre-fix source with Debug. The original far-history fixture was valid: its 261-byte opaque tail has zero near matches and no admitted literal candidate, while direct augmentation produces an insert of 3 bytes followed by a 258-byte copy at distance 65539. The incremental writer incorrectly placed far search inside the near/literal admission gate. Far-search eligibility now admits that path independently, retaining complete-wire selection. The unchanged far-distance, history, expiry, one-shot/reuse/incremental contracts pass Debug and ReleaseFast (29 tests each).

Five stale tests assumed that match-free input always selected a stored frame or that dictionary-training baselines were stored. The stored-fast-exit test now uses the existing opaque no-three-byte-repeat fixture. The literal-only dictionary test checks zero LZ77 and static-dictionary copies without fixing the entropy representation. Training tests independently encode and decode every held-out frame and account for actual baseline/frame/dictionary bytes. For the three fixtures, real baselines are 3982/3193/4403 bytes, compared with the stale 4608/3584/5120 values; trained frames and dictionaries remain 2424+178, 2647+226 and 1279+179. Their actual total savings are 1380/320/2945 bytes. These are fixture accounting values, not broad training-performance claims. The five-test Debug subset passes 34/34 including imports. The fresh complete ReleaseFast family gate passes 1496/1497 tests with one skip and no failures; native/WASI checks pass 212/212 build steps. Both exits were observed before the final graph timing epoch.

## Remaining algorithm work

The matcher already produces increasing-length evidence, but the first parser prototypes repeatedly expand covered short lengths for different distances. Two independent follow-ups test a new-length frontier heuristic and a nonnegative minimum-cost bound. Frontier pruning changes candidate coverage and may alter quality. The minimum-cost bound only omits edges that cannot strictly improve the current single-cache-node parser; finite evaluation quotas use the original path. These follow-ups must pass their independent graph/equality oracles and ordinary full-encoder measurements before adoption. Long-match index maintenance, shared matching evidence across passes, entropy convergence and default no-match work remain separate work.

## Final graph and reference epoch

After final family/platform validation, a separate seven-side epoch compares frozen baseline, current live source, exact cached lazy-model parser, frontier, single-start frontier, minimum-bound and pinned Brotli 1.2.0. The same 54 configurations use two alternating serial sweeps, one measured encode per process, on logical CPU2: 756 completed processes. The pinned C harness includes output allocation in encode timing, and excludes loading, startup encode/decode, equality, output writing and freeing. Every reference process verifies API versions, actual encoder/decoder/common paths and their hashes. Native and reference outputs were independently guarded-decoded before timing; every measured wire is checked against its saved SHA.

| Quality / input | Frontier: time / size vs baseline | Single-start frontier: time / size | Minimum bound: time / size |
| --- | --- | --- | --- |
| q10 / 32 KiB | 1.610643 / 0.976745 | 1.152448 / 0.979983 | 1.816800 / 0.976774 |
| q10 / 64 KiB | 1.808037 / 0.964306 | 1.231768 / 0.966300 | 2.057088 / 0.964335 |
| q11 / 32 KiB | 1.562257 / 0.977355 | 1.106948 / 0.980463 | 1.766705 / 0.977391 |
| q11 / 64 KiB | 1.677065 / 0.964314 | 1.207944 / 0.966308 | 1.890414 / 0.964343 |

Minimum-bound results preserve all 56 exact cached-parser wires. Its real-file time falls about 7.4–7.9% versus that same-epoch parent; it still takes 1.77–2.06x baseline time. The frontier cuts roughly 18% of its parent time while changing output size by less than 0.01% in these real-file aggregates. A single start removes more graph work, but still takes 1.11–1.23x baseline time at size 0.980/0.966. Its control time geomean is 11.918541x and controls keep baseline wire size; minimum-bound control time is 16.173761x. None meets the pre-recorded adoption criteria. These effects show that removing graph work helps, but the current cost-model/entropy pipeline still adds too much total work.

Current live output hashes remain exactly equal to the frozen baseline on all 56 q10/q11 real/control cases. Same-epoch live time ratios on real groups are 0.997135–1.000967. No throughput gain is assigned to the adopted exactness/far-search fixes.

| Current source / Brotli 1.2.0 | Encode time | Compressed size |
| --- | ---: | ---: |
| q10 / 32 KiB | 6.616182 | 1.072352 |
| q10 / 64 KiB | 4.882923 | 1.075770 |
| q11 / 32 KiB | 5.195849 | 1.098585 |
| q11 / 64 KiB | 2.318273 | 1.103076 |

These are geometric means across all twelve Silesia prefixes. Current q10 takes 6.62x/4.88x reference time at 32/64 KiB, with 7.24%/7.58% larger output. q11 takes 5.20x/2.32x reference time, with 9.86%/10.31% larger output. This directly measured epoch supersedes no older corpus or full-file results; the earlier six-file histogram epoch remains separately scoped. No factors are multiplied across epochs. Reference requested heap/RSS is not measured here.

## Next implementation boundary

Prioritize the existing fixed command/distance split literal-candidate group. It currently rebuilds symbol trees/extras and serializes a full wire for each literal variant. Retain an immutable symbol entropy plan plus winner/scratch literal plans, use the existing header writer for complete exact bit counting, preserve candidate order and equal-size selection, and emit only the group winner. Include window/metadata/metablock headers, distance shape, simple/complex trees, block switches, context-map RLE/MTF, implicit distance omission, payload/extras and final alignment. Start with at most eight existing variants and input up to 64 KiB; add no new candidate combinations. The current unsplit Prepared objects do not represent this split-plan boundary. This remains an unmeasured implementation direction, not a claimed speedup.

## Whole-encoder requested heap

A separate untimed ordinary public-API probe wraps only the encoder allocator with the existing WorkingAllocator. The same 54 configurations across six native sides produce 324 successful encodes. Input loading, decoding, hashing and report storage use the backing allocator directly. Every saved wire matches its ordinary golden SHA; all caller-freed outputs leave zero live requested bytes. Source/binary hashes remain unchanged and match the timing roots. The independent reducer reparses all 324 raw stdout records, checks saved wires/cleanup and serial intervals, and recomputes summaries.

| Input size | Baseline/live median peak, bytes | Single-start frontier median peak, bytes | Single-start frontier geometric peak ratio |
| --- | ---: | ---: | ---: |
| 32 KiB | 2,399,686.0 | 5,818,469.5 | 2.451769 |
| 64 KiB | 4,293,053.5 | 10,664,770.5 | 2.539061 |

q10/q11 have the same peaks for these cases. Baseline and current live peaks agree for every configuration. The cached/frontier/minimum-bound real-file peak ratios are about 2.46 at32KiB and2.55 at64KiB; the single-start frontier remains2.45/2.54, with worst ratios above3.0. The earlier compact-node prototype lowers its parser workspace independently, but this final priced/frontier bridge still uses104-byte nodes; a combined compact/frontier runtime was not measured. These are live requested encoder bytes including the returned wire, excluding allocator bookkeeping, internal remap transients and RSS. The upstream C encoder requested heap is not measured.

All parser candidates fail the recorded CPU/control and memory adoption criteria. The adopted exactness/far-only fixes preserve standard one-shot complete outputs and requested heap in this matrix. Full-file, streaming/dictionary, text/font and broader architecture performance remain separate work.

## Evidence

Evidence is archived under `data/brotli-command-start-model-20261031/`. Timing reports, raw stdout, source/binary/input hashes, ordinary harnesses, guarded reference decodes and independent reduction checks remain distinct from named correctness/platform tests. Live validation and subsequent frontier/minimum-bound outcomes are recorded there after their terminal exits.
