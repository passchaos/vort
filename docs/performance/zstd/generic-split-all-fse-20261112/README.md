# Zstd generic split all-FSE reader screens, 2026-11-12

This package preserves three completed whole-operation screens against the
frozen `093d5b9c2793e31a5c23c0913af66ef0c22a5ac5` baseline: a reader with
known compressed modes, a grouped reader with a noinline boundary, and the
grouped inline reader. **None was adopted.** The fourth source epoch is a
later guarded correctness proof only; it was not benchmarked and has no
performance result.

The change keeps the generic split layout's private 128 KiB literal buffer,
four-stream Huffman work, existing literal/match copies, and admission
thresholds. The first variant removes per-sequence LL/OF/ML mode dispatch
when the owner already knows all resolved modes are compressed. Later variants
group already-bounded field reads and retain checked fallback behavior.

## Exact observed results

The statistic is `baseline_time/candidate_time`: the geometric mean of four
ratios of child medians of the two measured Vort batch durations. Values above
one mean the candidate was faster in that screen. Reference durations and
warmups are preserved but are not used to normalize this statistic.

| Sao level-3 row | Mode only | Grouped noinline | Grouped inline |
| --- | ---: | ---: | ---: |
| 64 KiB cold | 1.0059510856470946 | 1.008655922903579 | 0.9848641752675072 |
| 64 KiB prepared | 1.0034519862996287 | 1.00574061379095 | 0.9998082823329265 |
| 1 MiB cold | 1.00281427985266 | 1.091795831241793 | 1.1207942166364528 |
| 1 MiB prepared | 1.0066642104736079 | 1.0951204434726731 | 1.1196465214560416 |
| Full cold | 0.9965717823683027 | 1.0961949814098972 | 1.1381056827036526 |
| Full prepared | 0.9969214336542043 | 1.0928367702807285 | 1.1165250934596642 |

[results.json](results.json) independently derives all 72 process-pair ratios
and 18 geometric means from original measured pairs. The original summaries,
screen logs, and events agree exactly. Mode-only is near parity; grouped
noinline improves the large rows by about 9–10%, and inline by about 12–14%.
These results do not meet the 20% target-row improvement bar and lack a full
matrix and dedicated-host acceptance campaign. The inline 64 KiB cold row has
large process-pair variation, including ratios 0.8171 and 1.1636. No fixed-host
confidence interval, corpus ratchet, codec-heap result, or industry-ranking
claim is made.

## Schedule and retained manifest scope

Each screen contains **48 successful child events across six rows**: three
sizes and both cold/prepared lifecycles, four interleaved process pairs per row.
Baseline/candidate ordering alternates AB/BA across those process pairs. Each
child preserves two warmup and two measured Vort/reference pairs, giving
**96 warmup and 96 measured pairs per screen**, 144 children across all three
versions.

The original manifests retain the full 216-fixture/cold-task schema and their
default iteration map `100/20/1`. The exact runners override the selected Sao
level-3 tasks to cold and prepared, with **100 iterations at 64 KiB, 100 at
1 MiB, and 10 for full input**. This override is explicit in archived runner
source and raw probe output; it is not silently rewritten into a full-matrix
manifest. A full acceptance matrix was not run.

Cold calls compare `decodeFrameInto` and `ZSTD_decompress`; prepared calls
compare retained `NativeFrameDecoder.decodeIntoSlice` and retained
`ZSTD_decompressDCtx`. Input/output counts, full output, 64-byte alignment and
guards, input immutability, selected reference mapping, and balanced samples
are retained in every full JSON report. These selected Zstd APIs do not expose
exact consumed input counts, so exact-consumption coverage remains false.

Runs were single threaded on CPU 15, ReleaseFast Zig 0.16.0, x86_64 Linux GNU,
`skylake+pku+sgx`, against Zstd 1.6.0. The i7-10700K development host used
`intel_pstate`, `powersave`, and enabled turbo. No compiler was observed before
or after a child; snapshots do not prove exclusive CPU use or timed-batch
overlap. The producer checked each child return code before publishing its
event; events themselves do not include a separate return-code field.

## Sources and proof epochs

| Epoch | Source identity | Measured executable SHA-256 |
| --- | --- | --- |
| Baseline | Reused complete 2,062-file `093d5b9c` registry | `2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14` |
| Mode-only timing | Baseline plus exact two-file `source/` overlay; 2,063 registry files | `e82fce7adbeb65df55599e22bba59a9b171389c77fb25e26a35b31ca66628f34` |
| Grouped noinline timing | Exact three-file `group-source/` overlay; 2,064 files | `46e9a9f95519bd422dfa5268911e89856fc69013a643913bae3414b9f0e77642` |
| Grouped inline timing | Exact three-file `inline-source/` overlay; 2,064 files | `52906617c95f9b23adeed423349bb9ba240d58ddfc7e11601fd545b357f24160` |
| Guarded proof only | Separate `guarded-proof-source/`; never timed | No measured executable or speed result assigned |

The first reader's Debug/ReleaseSafe oracle passed 13/13 aggregate tests. Its
source was frozen after adding the test adapter; that root differs from the
earlier mode-only timing root even though its reader helper is byte-identical.
Grouped and inline versions also retained 13/13 ReleaseSafe proof. Tests are
correctness evidence, not speed samples.

The original short `extraTransactions`, explicit repcode failures, and short
error fixtures use checked fallback. Normalized chains and real fixture
truncation chains can contain grouped paths, but there were no branch-hit
counters or dedicated group-fast error transaction witnesses. The package does
not claim those chains never reach fast errors, or that the original 13/13
proves every group-fast error and overflow transaction.

Static review found no hard-constraint mismatch in validated public wire
mappings, but found a private mapped-metadata gap: a 33-bit OF field could pass
the old total-width gate and violate `Group.read`'s 32-bit assertion. The
preserved before ReleaseSafe run used the original inline helper with extended
tests and ended **exit 1, 12 pass / 1 crash**. It is excluded from successful
proof and performance samples.

The later proof-only helper uses a u16 aggregate, per-extra width guards,
nonterminal state-width guards, and original checked fallback. The extended
tests cover long-suffix `InvalidMatch` and final-end progress, x86 arithmetic
failure, and private widths 33/64/65/255. Native Debug, native ReleaseSafe, and
x86-linux-gnu ReleaseSafe each passed **13/13, exit 0**. Deterministic
predicates and static review support these witnesses; explicit internal
branch-hit counters remain absent. This later helper has not been benchmarked
or adopted, and the earlier 12–14% timing is not assigned to it.

`inline-audit.json` is the main agent's derived summary of read-only audit
messages, SHA `9f52b41398ab92ac953326047a15b941361a10f0ce2493a682acca3e8ebdfb8c`.
`inline-reviewer-transcript.json` preserves the earlier audit message exactly,
SHA `b13dc6c3108b84d4da7251395da3cf257f8ecda24bb86a725925d30a8b91589c`;
it is a message transcript created at the main agent's request, not a copied
pre-existing agent file or a new audit run. Its then-live source statement
belongs to the original inline review time. Both artifacts retain their own
authorship and scope.

## Diagnostic perf capture

`sao-profile.tar.gz` preserves the original full-Sao level-3 perf.data, command,
execution receipt, source/fixture manifest, probe stdout/stderr, and reports.
It samples `cycles:u` at 499 Hz with `dwarf,65528`, using ten decodes per side,
six measured pairs, and two warmup pairs. The capture is the complete child:
startup, Vort/reference work, and validation are included. Profile durations
are excluded from all screen comparisons.

The successful `symbols-physical.txt` report has **806 samples, period
7,570,719,030, and zero reported lost samples**, with empty saved report stderr.
Its physical symbol percentages describe the whole sampled child, not all
Vort public decode time. The captured 65,528-byte stack cannot by itself prove
complete ancestry across 128 KiB split frames. A complete public-root
denominator and codec-only heap accounting are unavailable.

The earlier failed inline report is retained as `symbols.txt`, only an
85-byte preface without sample statistics. It is explicitly excluded. Its
separate stderr and return-code artifact were not saved; the package does not
invent them or attach the successful report's stderr to that attempt.

## Exact archive inventory

| File | Contents |
| --- | --- |
| `screen-raw.tar.gz`, `group-screen-raw.tar.gz`, `inline-screen-raw.tar.gz` | 153 exact members each: full manifests, 48 event JSON/stdout/stderr sets, event list, and six original summaries. |
| `timing-source-overlays.tar.gz` | Eight exact files for the three measured candidate source overlays. |
| `candidate-binaries.tar.gz` | Exact candidate-compare, group-compare, and inline-compare binaries. |
| `sao-profile.tar.gz` | All nine original profile files, including complete perf.data and excluded initial report prefix. |
| `runners-logs.tar.gz` | Exact screen runners, build/screen/Safe logs, inline freeze, and main independent statistics. |
| `runner-dependencies.tar.gz` | Exact imported pilot, matrix/evidence/fixtures modules, pilot seed manifest, and prior manifest. Their original absolute-path dependency is recorded rather than omitted. |
| `reader-v1-proof.tar.gz` | Original oracle receipt, source hashes, successful logs, compiler-failure logs, and frozen proof/pre-inline sources. |
| `guarded-proof-only.tar.gz` | Fourth unmeasured epoch: before/after sources, original crash, three final proof logs, receipt, main-derived audit and reviewer transcript. |
| `results.json`, `independent-stats.json` | Independently computed readable results and exact main-authored statistical audit. |
| `guarded-proof-receipt.json`, `inline-audit.json`, `inline-reviewer-transcript.json` | Exact readable copies for scope and proof review. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Raw member origins/hashes, independent offline validator, validation receipt, and complete checksum inventory. |

GNU tar members are lexicographically sorted regular files with uid/gid/mtime
zero, empty owner names, and modes 0644/0755. Gzip has level 9, empty filename,
and mtime zero. Original source/log/JSON bytes stay unchanged inside archives,
including whitespace and original line endings. Large plain/wire data is
reused using exact archived fixture metadata.

The baseline source and binary are reused by SHA from
`br/decode-mozilla-distributions-20261112`, and the reference Zstd shared
library from `modern-decode-current-20261111/reference-libraries.tar.gz`.
Subsequent documentation commits do not replace the frozen `093d5b9c` epoch.

## Offline verification

From this directory in the repository:

```sh
sha256sum -c SHA256SUMS
python3 verify.py
```

The independent standard-library verifier reconstructs all three measured
source registries from the exact reused baseline and frozen overlays. It
checks source/probe/reference bindings, complete JSON equality to original
stdout, fixture/count/guard validation metadata, schedule/order, all 72 ratios
and 18 means, original/derived summaries, the four proof epochs, and profile
scope. It runs no compiler, codec, benchmark, or perf command.

To compare retained originals and all baseline Git blobs:

```sh
python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

When relocating this directory, supply `--baseline-package` pointing to the
existing Brotli distribution package and `--reference-archive` pointing to the
existing modern reference tar. To reproduce an experiment later, restore a
separate baseline checkout, apply the chosen frozen overlay, and use the exact
archived executable and runner/dependency bytes. The archived runners use the
recorded absolute paths; adjust only a derived copy and record a new epoch.
Do not change frozen manifests to resume with current candidate/proof source.
