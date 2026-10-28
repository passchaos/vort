# Zstd per-choice row tag reuse screen

The retained row-tag encoder at `9433c9bb` was sampled again through ordinary
public encoding with `control_profile=null`. CPU 2, Zig 0.16.0 LLVM ReleaseFast,
Skylake with frame pointers and 1999 Hz user CPU samples were used. Mozilla
4 KiB btultra2 runs eight encodes; Dickens 4 KiB btopt runs 256. Both return
exit code zero, all repeated wires agree and native decode passes.

| Global self share | Mozilla btultra2 | Dickens btopt |
| --- | ---: | ---: |
| Row-tag insertion | 35.85% | 26.71% |
| Edge extension | 31.16% | 14.40% |
| Sequence pricing | 15.60% | 5.63% |
| Candidate enumeration | 10.08% | 10.23% |
| Match length | 2.14% | 15.11% |

Within insertion, candidate tag arithmetic accounts for 3.04%/1.57% of global
periods. Exact/final `less` comparisons including field loads account for
12.28%/7.63%. Within extension, pricing call setup/return contributes
4.11%/1.65%; profile updates contribute zero in these unprofiled calls.
These are recomputed global shares, distinct from symbol-local annotate
percentages. The new fractions must not be treated as absolute speed changes
relative to earlier sampling epochs.

## Prepared tag experiment

For each sequence offset choice, resulting repeat offsets stay fixed and its
pending literal length is zero. The prototype computes their row tag once,
then passes it into exact insertion for every candidate length. The private
`insertPrepared` shares the old collision checks and movement; its Debug
assertion requires the supplied tag to match the candidate's full key.
Generic insertion still computes its own tag, and unindexed contexts retain
their old path. All length visits, price admissions and error precedence stay
unchanged; no storage is added.

The [evidence package](data/zstd-prepared-row-tag-20261029/) preserves separate
sampling and ordinary timing binaries. Both timing variants are rebuilt from
the same current snapshot using non-FP ReleaseFast/Skylake and the same runner.
Two balanced AB/BA rounds use Dickens/Mozilla/MR 4 KiB, btopt/btultra2,
window log 15 and checksums. Ordinary allocating encode is timed; input setup,
returned frame release, decode and the separate profiled encode are outside
the timer. Every wire and complete profile agrees in 24 encodes/48 native
decodes; libzstd 1.6.0 independently decodes all 24 wire artifacts.

| Input / strategy | Candidate / baseline median time | Paired round 0 / 1 |
| --- | ---: | ---: |
| Dickens btopt | 1.3461 | 1.7123 / 0.9748 |
| Dickens btultra2 | 0.9691 | 0.9540 / 0.9848 |
| Mozilla btopt | 1.1637 | 1.3466 / 0.9805 |
| Mozilla btultra2 | 0.9750 | 0.9770 / 0.9730 |
| MR btopt | 0.9726 | 0.9821 / 0.9627 |
| MR btultra2 | 0.9698 | 0.9654 / 0.9745 |

The middle column is median candidate time divided by median baseline time.
Four configurations improve in both rounds. Dickens/Mozilla btopt have large
first-round candidate delays and a small second-round improvement. These
short exploratory measurements do not establish a general benefit; the
candidate remains archived and is not adopted from this screen. No extra
round was added to seek a favorable aggregate.

Frozen current row-tag and edge modules independently verify prepared values,
all key/non-key fields, collisions, arbitrary rows, alias arguments, complete
tables and profiles, each finite quota prefix, malformed symbol/cost errors
and the unindexed fallback. Native Debug/ReleaseFast and actual x86 Debug each
pass 9/9 tests. This snapshot does not add a production API or current-source
Wasm/build claim.

Generated code moves the tag multiplication to candidate enumeration and
shrinks insertion from 1031/1050 to 943/966 bytes, while candidate enumeration
grows from 622 to 690 bytes. Hash computation is a small part of remaining
ordinary work. Sequence pricing and edge/node materialization are larger
measured targets. Continue screening those costs against exact behavior and
full ordinary encoding; the complete ten-format goal remains active.
