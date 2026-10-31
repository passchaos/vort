# Literal entropy without LZ copies

Planned Brotli encoders now consider entropy-coded literals when the matcher
finds no backward copies. Previously that condition immediately selected
stored output in the ordinary quality path and several legacy/reusable paths,
even for a small alphabet. The existing Brotli command writer already supports
an insertion-only terminal command, so the new path uses the same writer and
complete compressed/stored arbitration as copy-bearing plans.

The behavior covers ordinary q2–q11, general incremental/chunked policies,
legacy fast/balanced/ratio calls, reusable owned/scratch/caller-buffer calls,
fixed-scratch planning and an unused shared dictionary. Dedicated q0/q1 paths
keep their own existing policy. Inputs shorter than five bytes preserve stored
output. All failures still propagate through the caller allocator and total
working-memory transaction; a resource refusal is not converted into stored
success.

## Bounded admission

Unconditionally running the existing context/split search was rejected. It
preserved real-file output and gave large no-copy compression gains, but q10
on a 4 KiB near-uniform no-three-byte-repeat input took 61.67 times the old
stored shortcut's time. The broader 15-case random group measured `6.451378`.

The retained `literal_entropy_policy.zig` evaluates the complete input's exact
one-tree Huffman payload length and literal-tree description length. It admits
new context/split work only when those bits plus a 64-bit command/framing
reserve are below the raw eight-bit payload. This is an explicit search budget,
not a lower bound on every possible context model or the exact framing cost of
every facade. Accepted candidates still compete using full wire length.

The policy uses the same deterministic prefix-length and complex-prefix bit
counter as the production writer, with no additional heap allocation in the
current paths. Independent tests compare it against reference code lengths,
check strict reserve boundaries and deterministic repeats, and verify the
zero-allocation path with a failing allocator.

A separate three-way 16-configuration screen compares stored baseline,
unconditional literal search and the retained budget at qualities 2/8/10/11:

| Group | Unconditional / baseline time | Budget / baseline time |
| --- | ---: | ---: |
| Four small-alphabet 32 KiB cases | `5.086495` | `5.140671` |
| Twelve near-uniform 4/32/64 KiB cases | `9.485033` | `1.026016` |

The small-alphabet group keeps exactly the same wires under both candidates,
with a size geomean `0.564105`. The budget keeps all random outputs equal to
the baseline stored wire. It intentionally excludes some small-input context
gains: a q3 B8,2 chunked fixture remains 75 bytes, while unconditional search
could produce 67. This tradeoff is retained explicitly rather than claiming
all context models were searched.

## Compression witnesses and resources

The main regression fixture is lexicographic FKM de Bruijn `B(32,3)`, 32,768
bytes drawn from symbols 0–31 with no repeated three-byte anchors. Independent
tests prove that no three-byte LZ match can occur. The baseline public q8/q10/q11
wire is 32,772 bytes; the retained ordinary candidate is 17,859 bytes, 45.51%
smaller. At q10/q11 the chunked/incremental fixture becomes
`32781 -> 18876`. Legacy fast/balanced becomes `32772 -> 20495` and ratio
becomes `32772 -> 18395`. Reusable owned/scratch/guarded caller-buffer calls,
fixed scratch and a nonmatching RAW dictionary retain these gains.

These inputs demonstrate a behavior gap independently of compression on
repetitive data. Text/font relabelings, other small alphabets, near-uniform
opaque input, windows 10/16, empty/tiny values and q11's q10-size inheritance
are included. Real-file and seeded no-three-byte-repeat random campaigns
remain separate from the witness corpus.

Independent moving-allocation accounting measures requested peak at
691,105 bytes for q3 B16,2, 1,754,479 for q10 B32,3 and 715,356 for q11 font.
The exact peak cap emits the same complete wire; peak-minus-one refuses with
`WorkingMemoryLimitExceeded`, leaks no live bytes and does not silently fall
back. Public owned and incremental allocation-failure enumeration passes.
Ratio profiling and ordinary ratio output remain identical for the witness.

The retained public contracts execute 28/28 in native Debug/ReleaseFast and
actual wasm32-wasi ReleaseFast. The independent seven-part public baseline
comparison also passes under the retained budget. Full LZ77 Debug/ReleaseFast
suites pass 95/95, including the separately retained model-window validation
fix. The final `zig build -j2 test-br-total-memory check check-wasm --summary all`
gate exits 0 at 215/215 build steps and 68/68 total-memory runtime tests; CLI
help also exits 0. Compile checks do not imply that every repository runtime
test executed. The final formal campaign is recorded separately below.

## Final ordinary-call campaign

Four serial AB/BA sweeps produce 352 records over 44 configurations. The groups
are kept separate so no size improvement is used to hide a latency regression.

| Group | Configurations | Budget / baseline time | Budget / baseline size |
| --- | ---: | ---: | ---: |
| Six Silesia files, q10/q11, 32/64 KiB | 24 | `0.997357` | `1.000000` |
| B32,3 32 KiB, q2/q4/q8/q10/q11 | 5 | `5.484688` | `0.563544` |
| Near-uniform no-three-byte-repeat, 4/32/64 KiB | 15 | `1.039592` | `1.000000` |

Real-file and random complete wires remain identical to baseline. The near-
uniform group pays for the new admission calculation: the q2/q4 4 KiB points
are `1.159791/1.188860`, while q10 random 4/32/64 KiB points are
`1.029093/1.013719/1.017465`. These small-call regressions are retained. The
real-file `0.997357` point is evidence of no substantial measured shift in
this epoch, not a statistical throughput win.

Low-entropy input is doing compression where the baseline only copied a stored
block. q2 produces 20,506 bytes (`1.133626` time ratio), q4 18,395
(`6.489189`), and q8/q10/q11 17,859 (`6.048264/10.254798/10.877809`). Their
combined compressed-size reduction is 43.65%; q8/q10/q11 reduce this input by
45.51%. The large speed ratios compare actual entropy search against the
previous stored shortcut, not equivalent compression work.

An explicit libbrotli 1.2.0 decoder validates 88 baseline/final exports and their
destination guards over all 44 configurations, bound to the 352 final timed
signatures. Native reference one-shot encodes of the B32,3 witness use the same
quality, generic mode and actual window16:

| Quality | Vort bytes | Reference bytes | Vort / reference size |
| --- | ---: | ---: | ---: |
| q2 | 20,506 | 20,508 | `0.999902` |
| q4 | 18,395 | 17,099 | `1.075794` |
| q8 | 17,859 | 11,801 | `1.513346` |
| q10 | 17,859 | 15,985 | `1.117235` |
| q11 | 17,859 | 15,976 | `1.117864` |

Reference output sizes are not monotonic across these quality settings on this
witness. These are verified complete-wire sizes, not a compression-speed
comparison. The substantial remaining q8 gap is retained; the new behavior
closes the stored-only gap without establishing best-ratio results.

## Evidence and next work

All measurements use Zig 0.16.0 LLVM ReleaseFast, Linux x86-64/Skylake and an
Intel i7-10700K with one timed codec process on CPU 2. The ordinary runner uses
a startup encode/decode and one timed allocating encode, then full-wire
comparison/free outside timing. Controlled campaigns run without concurrent
codec tests or compilation. Reference artifacts come from local Brotli 1.2.0,
commit `558fc647cdaf391228d614ca85f711e02e4e583b`, built with GCC
`-O3 -DNDEBUG -march=native`. Explicit reference decodes verify plaintext and
output guards, with actual decoder/common dependency paths checked.

[The evidence package](data/brotli-literal-entropy-20261030/) retains the
unconditional negative result, budget screen, final raw campaigns, public and
policy contracts, immutable fixtures, source identities, actual Wasm modules,
reference/output wires and an independent reducer. The rejected full-window
and duplicate-command experiments are maintained
[separately](brotli-wide-modeled-screen.md).

Next ratio work should reduce the cost of context discovery on insertion-only
streams and explore budgeted context proposals for globally uniform but
context-predictable input. Native Brotli command/distance pricing remains a
separate source of the measured real-file size gap. The full deflate/zstd/brotli
goal remains active.
