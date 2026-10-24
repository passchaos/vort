# FastCover functionality and training baseline

Date: 2026-10-24. Source and tools revision: `a11bfd6c`.

The Zig-native FastCover selector, reusable preparation, bounded parameter
optimizer, full Zstd dictionary finalizer and CLI are implemented. This closes
the FastCover functional roadmap slice. The measurements below show substantial
remaining training-time and charged-output gaps; they do not establish
industry-best performance.

## Public behavior and validation

The [API contract](../formats/fast-cover-training.md) describes sampled d-mer
frequencies, sample-boundary-safe segment selection, cyclic epochs, preparation
reuse, stable parallel reduction, shrink decisions and managed codec scoring.
Whole-operation memory limits include live requested heap, growth overlap,
returned dictionaries and requested native worker stacks. They are not RSS
limits. Standard dictionary targets bound raw history; entropy headers add
serialized bytes. Acceleration selects a strict training-only sample prefix
for finalization, including a valid zero-length prefix.

Final validation passed:

- 45/45 FastCover contracts in both Debug and ReleaseFast, with independent
  slow selection oracles, exact/below memory limits, allocator failure paths,
  prepared ownership and parallel resource checks.
- 822/822 complete Zstd ReleaseFast tests and all 138 build-check steps.
- [402 independent functional groups](data/fast-cover-functional-x86-20261024.json):
  154 Vort workflows, 220 successful upstream raw/full-dictionary reverse
  cases, one recorded upstream rejection, 21 invalid/resource cases, an empty
  raw result, zero-prefix finalization and four uniform-corpus cases.
  Seven corpus families exercise d=6/8, hash logs, acceleration, preparation,
  direct/optimized/codec-aware training, split, shrinking and serial/parallel
  output. Standard dictionaries are inspected and Vort frames decoded by
  libzstd; trained-history references are also checked explicitly.
- [Final CLI evidence](data/fast-cover-cli-x86-20261024.json): six successful
  standard dictionaries, 38 invalid calls preserving an existing output,
  help, zero-prefix finalization and legal default d-grid selection with k=6/7.
  Thin checks include 23 actual allocator failure points, mapped writer failure,
  balanced allocation accounting and byte-exact public optimizer comparison.

The archived functional and measurement reports each match 90 source/tool
hashes at integration. CLI evidence matches 15 source hashes and the final
Debug executable. The JSON records preserve original report hashes, binary,
compiler, reference helper/library/header hashes, command lines and corpus
sample hashes.

Vort intentionally keeps selected segments within sample boundaries and does
not promise byte-identical libzstd FastCover dictionaries. On ten identical
256-byte samples, upstream d=6/8 at acceleration 1/10 rejects the corpus with
`Src size is incorrect`. Vort selects six bytes for d=6 and rejects standard
finalization below eight history bytes; d=8 selects eight bytes and produces a
valid full dictionary. The reference rejection remains recorded.

## Measurement protocol

[Raw measurements](data/fast-cover-measurement-x86-20261024.json) were collected
on Intel Core i7-10700K, Linux x86-64, Zig 0.16.0 ReleaseFast, system libzstd
1.4.8 with matching 1.4.8 ZDICT headers and a C ABI helper. Competing builds
were paused. Each family has 64 training, eight selector and eight held-out
samples from fixed public synthetic generators. Held-out samples never select
the winner. These families are not a real-file corpus or an ARM64 measurement.

The timing campaign runs one warmup and three rounds. Each Vort round retains
the first call and two repeated calls in the same process. The tables use
repeated-call medians. The report also retains every duration, preparation
time and first-call medians. First calls do not imply hardware-cold caches.
Caller profiles are disabled in measured calls. Input I/O, output validation
and frame encoding are outside trainer timing. Upstream timing covers ZDICT
selection plus standard finalization, excluding sample concatenation and
validation.

Settings for the direct Vort baseline are raw target 512, segment 64, d=6,
hash log 12, acceleration 1 and a fixed nonzero dictionary ID. Upstream uses
the corresponding k/d/f/acceleration with serialized capacity N. The raw and
prepared Vort stages do not produce full standard dictionaries, so their times
must not be ranked against upstream full training.

| Family | Vort raw ms | Vort prepared selection ms | Vort full training ms | Upstream full training ms at N |
| --- | ---: | ---: | ---: | ---: |
| Text | 0.340229 | 0.255671 | 3892.544364 | 0.288171 |
| JSON | 0.348780 | 0.239139 | 6398.940599 | 0.277062 |
| Source | 0.421941 | 0.320055 | 7772.887249 | 0.298632 |
| Log | 0.356857 | 0.262634 | 5400.700905 | 0.347957 |
| Binary | 0.359268 | 0.263613 | 686.740093 | 1.208318 |
| Small | 0.056635 | 0.040382 | 21.044056 | 0.080358 |
| Repetitive | 0.326397 | 0.245904 | 8868.699661 | 0.253797 |

Prepared selection excludes preparation. Its total with preparation is
recorded separately. The repetitive family has a 0.376477 ms median across
all preparation-plus-selection calls, while full training remains about
8.87 seconds. The large gap occurs after raw history selection; standard
entropy/repcode finalization is the next profiling target.

## Charged held-out output

Charged output counts one serialized dictionary plus all eight held-out frames
at each of levels 1 and 3. Vort uses its public encoder and upstream uses
libzstd. These are dictionary-plus-encoder outcomes; they do not isolate the
history selector's quality from encoder differences.

The matched-capacity experiment first takes the already-generated Vort full
dictionary length N, then trains upstream with capacity N. The fixed-budget
experiment gives both implementations a serialized maximum of 1024 bytes.
Vort chooses among raw targets 256/512/768 using charged selector output;
all seven winners choose 256. Upstream trains at capacity 1024. Vort's chosen
serialized dictionaries are 384...409 bytes, while upstream uses 1024. A
shared upper bound does not mean equal actual dictionary size.

| Family | Matched N | Vort/upstream charged bytes at N | Vort difference at N | Vort/upstream charged bytes, 1024-byte budget | Vort difference at budget |
| --- | ---: | ---: | ---: | ---: | ---: |
| Text | 652 | 4392 / 1909 | +130.07% | 4080 / 2252 | +81.17% |
| JSON | 655 | 3317 / 2898 | +14.46% | 3061 / 3265 | -6.25% |
| Source | 664 | 3993 / 2798 | +42.71% | 3897 / 2999 | +29.94% |
| Log | 661 | 3925 / 2420 | +62.19% | 3653 / 2820 | +29.54% |
| Binary | 640 | 12140 / 11396 | +6.53% | 11838 / 11770 | +0.58% |
| Small | 656 | 1410 / 1201 | +17.40% | 1211 / 1575 | -23.11% |
| Repetitive | 647 | 2105 / 1413 | +48.97% | 1849 / 1790 | +3.30% |

Lower charged bytes are better. Vort loses all seven matched-capacity rows and
five fixed-budget rows. JSON and small-payload budget wins do not establish a
general quality lead. Complete training remains slower in every row.

## Reproduction and next work

The permanent functional driver is `zig build run-fast-cover-diff -- ...` and
the narrow contract gate is `zig build test-fast-cover`. The archived JSON
contains the exact prepared-corpus, helper, probe and compiler commands used
for this baseline. The Python driver's `--measure --validated-report ...
--rounds 3` mode separates the measured campaign from functional validation.
Finish all builds before timing a campaign.

Remaining functionality priorities are XZ/LZMA presets and match-finder controls
and fuller Brotli/Zstd HQ modeling. Subsequent performance work should profile
standard dictionary finalization, improve the weakest text/log/source costs,
and measure current public APIs against current versioned competitors on
shared real corpora, including throughput, ratio, requested memory and RSS on
x86-64 and ARM64. This completed functional increment does not complete the
long-term industry-best objective.
