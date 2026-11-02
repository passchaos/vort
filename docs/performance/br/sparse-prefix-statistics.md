# Sparse complex-prefix statistics, 2026-11-03

This increment targets exact Brotli context-tree scores. Sparse RLE now
validates each nonzero support entry once and carries its code length into
the current run. The first symbol initializes the run before the loop;
subsequent equal adjacent lengths extend it, while a boundary publishes the
completed run and any zero gap. The prior lookahead implementation remains
an explicit differential reference.

The same symbol bounds, strictly increasing order, nonzero-length checks and
complete-support caller contract remain. Symbol 255 advances to the widened
exclusive stop 256. The scorer reads only supplied support entries and has
no allocator, retained state or change to token recurrence. Frequencies,
repeat counters, token count and all optional shape fields remain exact.

The 18-symbol code-length Huffman builder also simplifies stable leaf
insertion. Input symbols are visited in ascending order, so a new equal-weight
symbol is always greater than every existing symbol. Strict weight comparison
retains that order without a second symbol comparison. Full u32 frequencies,
u64 generated sums, leaf-before-parent ties, parent generation order and the
five-bit natural-tree fallback remain unchanged.

## Correctness and work

An independent sparse oracle compares all summary fields with the original
lookahead, dense summary and actual token emission. It decodes those tokens
with the forward repeat recurrence, computes shape independently and checks
caller input preservation. Cases cover every code length 1–15 at every run
size 1–256, all leading zero gaps, exhaustive small mixed alphabets, random
supports, malformed order/duplicates/zero/out-of-range entries, empty inputs,
uninitialized unsupported lengths and allocation-free comptime use.

The Huffman oracle repeatedly selects the globally smallest two nodes using
u128 weights and recovers each leaf depth independently. It shares no sort,
queue or reverse-depth algorithm with production. All 1,881 frequency cases
compare complete 18-entry arrays or over-depth null; 444 cases reach that
fallback. Original tests remain registered.

The selected RLE module passes 15/15 tests each in native Debug, ReleaseSafe
and ReleaseFast. The code-length Huffman module passes 5/5 in all three modes.
Actual 32-bit x86 ReleaseSafe execution also passes 15/15 and 5/5 respectively.
The public prepared-command Wasm gate passes all five steps, preserving frozen
complete output and Zig/Node decoding. CLI help and changed-file formatting
checks pass. Complete family/build outcomes are recorded separately.

The full ReleaseSafe Brotli suite passes 1,522 tests with one skipped out of
1,523 and exit zero. The skipped platform-specific test retains its existing
scope; new sparse and Huffman 32-bit contracts execute separately above.
The final default native/Wasm `check check-wasm` gate passes 212/212 steps
with exit zero. The original long-running build is observed to completion.

The preceding public q8 profile gives source-level work estimates. Across
lazy/optimal scores, MR/Mozilla/Dickens each process respectively
132,109/409,242/40,822 nonzero code lengths. The old loop's run boundaries add
85,754/299,453/32,004 successful repeated entry checks. Removing those reduces
the source-level checks by about 39–44%. This does not measure compiled loads
or ordinary encoding time. Profile-only dense shape recomputation is outside
the proposed production saving.

## Candidate experiments

The first per-entry pending-state loop passed correctness but increased the
synthetic long-run group's complete summary time about 54%. A boundary-carry
inner loop then regressed all five synthetic groups and was rejected. The
selected first-entry initialization version improves short-run, sparse and
alternating groups about 12–17%, while its synthetic long-run control remains
about 28% slower. These are complete summary kernels, not compressor wins.

The independent Huffman microcomparison improves ties, RLE-scale frequencies
and over-depth shapes about 5–6%, while the full-u32 random group is about 9%
slower. Both limitations remain part of the evidence. No weights or depth
limits were narrowed to improve a benchmark.

The initial public screen accidentally overlaps a diagnostic CPU2 profile
with three ordinary processes. Its complete-output and profile checks remain
valid, but that entire timing screen is excluded. Final source builds and
ordinary campaigns are recorded separately and executed sequentially.

## Final public q8 matrix

Baseline source is `beaff2d4`. Independent final executables call the public
q8/generic API with actual window16 and matching Brotli 1.2.0 reference
quality/mode/window. Twelve Silesia sources at 4/16/64 KiB plus random
16/64 KiB and repetitive 64 KiB controls give 39 inputs. Three alternating
outer sweeps verify 234 processes, retaining five timing rounds at three
encodes each. Every complete input and Vort/reference wire identity agrees.

Host: i7-10700K, CPU2, one codec thread. Vort uses Zig 0.16.0 LLVM
ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0 is clean
`558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`. A separate encoder-first loader probe verifies the same
pinned encoder/decoder/common closure; ordinary metadata hashes requested
files without inspecting loaded objects. Vort has a primary warmup and the
reference retains its documented lifecycle. Allocation/free is timed;
file reading, metadata and complete-content validation are outside.

| Real-input scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 0.99417 | 8/12 |
| 16 KiB | 0.99334 | 11/12 |
| 64 KiB | 0.99820 | 8/12 |
| All 36 real inputs | 0.99524 | 27/36 |

The real-input geometric latency reduction is about 0.48%. Weaker rows
remain: XML 64 KiB 1.02382, X-ray 4 KiB 1.01247, SAO 64 KiB 1.01068 and
OOOffice 64 KiB 1.00865. Random 16/64 KiB ratios are 0.95602/0.99961 and
the repetitive control is 0.97923. These point estimates do not establish
universal gains. The [row CSV](sparse-prefix-statistics-20261103.csv)
retains independent medians and median paired ratios, which need not equal
their quotient.

The separate current-source reference epoch records 30.31 times Brotli
encoding latency geometrically, at size 0.99556 times reference. Prior
increment gains and reference epochs are not multiplied into this result.
Nine final diagnostic rounds preserve all 558 event records after excluding
clock fields, including candidate configuration, exact size, selection and
work counts. Profile clocks are mechanism observations only.

Eleven longer alternating pairs, seven encodes per round, verify another
132 processes and preserve all complete wire identities:

| Input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 0.99651 | 0.99072 | 8/11 |
| MR 64 KiB | 0.99854 | 0.99158 | 8/11 |
| Dickens 64 KiB | 0.99995 | 0.99986 | 6/11 |
| Dickens 4 KiB | 0.99380 | 0.99006 | 11/11 |
| NCI 64 KiB | 0.99505 | 0.99194 | 11/11 |
| Repetitive 64 KiB | 1.00547 | 1.00302 | 4/11 |

The longer target medians range from near neutral to about 0.35% faster.
The repetitive control keeps a roughly 0.55% median regression, despite its
earlier matrix point estimate. These separate sweeps demonstrate why the
larger short-kernel improvements must not be presented as whole-call gains.

Seven further alternating pairs verify 56 processes on the matrix's weaker
real rows. Median paired ratios are XML 64 KiB 0.99672, SAO 64 KiB 0.99835,
OOOffice 64 KiB 0.99430 and X-ray 4 KiB 1.01085. The first three matrix
regressions do not persist in that follow-up; X-ray retains about 1.1% slower
latency with only 2/7 wins. The aggregate improvement is modest and has a
clear small-input limitation. No candidate, parser search or quality branch
is disabled to remove that control.

Raw experiments, final source/build identities, microcomparison records and
terminal validation logs are retained under
`zig-out/br-sparse-rle-20261103`. Earlier failed caches, packed tokens, repeat
thresholds and Huffman queues remain rejected under their linked studies.

```sh
python3 zig-out/br-sparse-rle-20261103/matrix-final.py
python3 zig-out/br-sparse-rle-20261103/run-profile-final.py
python3 zig-out/br-sparse-rle-20261103/long-final.py
python3 zig-out/br-sparse-rle-20261103/long-weak-final.py
zig build -j2 test-br -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
zig build test-br-prepared-command-wasm --summary all
```

Execute the four CPU2 scripts sequentially. `build-final.py` records exact
compiler arguments and before/after source hashes; replay against the saved
source archive for this epoch. `archive.py` creates `SHA256SUMS` for binaries,
source, ordinary/profile records, verified inputs and terminal validation logs.

| Binding | SHA-256 |
| --- | --- |
| Baseline benchmark | `69a566fa84c6ea3b0a29be88a4cbfffd2c132733448939ed8809a1ff1f676bd9` |
| Final benchmark | `de5e23b4e6a2586bb618811e8e165f787dd01473b9be2d379ec2d631b09838c3` |
| Final matrix | `a35fa526b76ed3b3c34131a6ec8f89f2e2a507040f3c616ff77b7a3552b49db4` |

The larger Deflate/Zstd/Brotli industry-best objective remains active. A next
larger q8 opportunity is extending one immutable command plan's existing
command-model preparation from its preferred group into adaptive literal and
distance candidates. That work needs separate key, lifetime, resource and
full-output validation; it is not implemented by this score-loop increment.
