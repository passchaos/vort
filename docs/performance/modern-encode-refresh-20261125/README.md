# Current allocating encoder baseline: complete 216-condition matrix, 2026-11-25

The original collector has completed **216/216 conditions** at source
`4a9796b01aa0617aace28d2d4ca2c83cb81b409a`: twelve Silesia files, six declared
policies, and 64 KiB / 1 MiB / actual full-file inputs. Root observed collector
session **92621 exit 0**; the complete manifest retains `complete=true`.
All **1,224 measured primary pairs** and **432 separate Deflate warmup rounds**
are retained. This is an **observational/nonquiet development-host epoch**:
parallel validation, builds and resource operations occurred during collection.
No rows or outliers are removed. Completion does not establish a matched-quality
frontier, warmed/prepared/streaming performance, RSS, or industry leadership.

The original 64 KiB and through-1 MiB checkpoint files remain byte-identical,
including their `complete=false` manifests and original CI seed assignments.
Those incomplete manifests describe their historical checkpoints; the separate
full archive and full summary describe the completed matrix.

All twelve Silesia sources are included in each policy below. Ratios are
Vort/reference. Throughput uses every measured raw paired round, with equal
weight per corpus row; encoded-size ratios use complete initial validated
wires. Higher speed ratios and lower size ratios are better.

| Policy and reference | Throughput ratio | Fixed-row 95% CI | Encoded-size ratio |
| --- | ---: | ---: | ---: |
| Raw Deflate L6 / libdeflate 1.26 L6 | 0.39837x | 0.39605–0.40090x | 1.0064x |
| Raw Deflate L9 / libdeflate 1.26 L12 | 0.52638x | 0.52406–0.52863x | 1.0124x |
| Zstd public L3 / libzstd 1.6.0 L3 | 0.09814x | 0.09764–0.09867x | 0.9677x |
| Zstd public L19 / libzstd 1.6.0 L19 | 0.66500x | 0.66149–0.66829x | 1.0951x |
| Brotli q8, generic/window16 / libbrotli 1.2.0 q8 | 0.01363x | 0.01354–0.01373x | 0.9439x |
| Brotli q11, command-state cap8 KiB, generic/window16 / libbrotli q11 | 0.27483x | 0.27380–0.27584x | 1.0612x |

The first table is the original 64 KiB checkpoint. At **1 MiB**, the same
policies and twelve complete corpus prefixes give:

| Policy and reference | Throughput ratio | Fixed-row 95% CI | Encoded-size ratio |
| --- | ---: | ---: | ---: |
| Raw Deflate L6 / libdeflate 1.26 L6 | 0.38189x | 0.37982–0.38393x | 1.0130x |
| Raw Deflate L9 / libdeflate 1.26 L12 | 0.15748x | 0.15660–0.15835x | 1.0045x |
| Zstd public L3 / libzstd 1.6.0 L3 | 0.08173x | 0.08130–0.08218x | 1.0259x |
| Zstd public L19 / libzstd 1.6.0 L19 | 0.47871x | 0.47509–0.48233x | 1.1840x |
| Brotli q8, generic/window16 / libbrotli 1.2.0 q8 | 0.06099x | 0.06052–0.06147x | 0.9881x |
| Brotli q11, command-state cap8 KiB, generic/window16 / libbrotli q11 | 0.30491x | 0.30420–0.30565x | 1.0472x |

## Actual full-file cohort

Each policy below includes all twelve complete Silesia files. These rows are
from the same frozen source and collector, without restarting or replacing its
sampling. Ratios remain Vort/reference; the fixed-row CIs describe within-row
raw-round resampling and do not cover parallel workload or cross-epoch effects.

| Policy and reference | Throughput ratio | Fixed-row 95% CI | Encoded-size ratio |
| --- | ---: | ---: | ---: |
| Raw Deflate L6 / libdeflate 1.26 L6 | 0.36821x | 0.36692–0.36945x | 1.0200x |
| Raw Deflate L9 / libdeflate 1.26 L12 | 0.14751x | 0.14716–0.14784x | 1.0052x |
| Zstd public L3 / libzstd 1.6.0 L3 | 0.07767x | 0.07725–0.07807x | 1.0661x |
| Zstd public L19 / libzstd 1.6.0 L19 | 0.37842x | 0.37724–0.37963x | 1.3349x |
| Brotli q8, generic/window16 / libbrotli 1.2.0 q8 | 0.06435x | 0.06419–0.06451x | 0.9953x |
| Brotli q11, cap8 KiB, generic/window16 / libbrotli 1.2.0 q11 | 0.91872x | 0.91673–0.92062x | 1.1077x |

For example, full-file Brotli q11 approaches reference throughput while its
output is geometrically 10.77% larger. Full-file Deflate L9 stays near L12 size
but at 14.75% of its throughput; Zstd L19 output is 33.49% larger. These declared
preset tradeoffs do not establish equal-quality competitiveness or leadership.

The reference gaps remain material at 1 MiB: Deflate L9 is near reference L12
size but only 15.75% of its throughput; Zstd L19 is 18.40% larger on average;
Brotli q8 spends about 16.40 times reference time for 1.19% smaller output.
These are current scoped preset observations, not claims of equal quality or
attribution to the encoder contract fix.

Deflate levels differ on the HQ comparison; equal numeric settings would not
establish identical algorithms. Zstd compares public product presets, not
common-HQ strategy controls. Brotli verifies actual quality/mode/window
matching; the Vort q11 work cap is explicit, while q8 uses the current quality
schedule sentinel. The two quality points are not equivalent compression
frontiers. Small cross-epoch changes cannot be attributed to codec code alone.

## Measurement and verification scope

- Ordinary allocating calls on both sides include state creation, encoding,
  owned-output allocation/shrink and freeing. Deflate libdeflate initialization
  now occurs inside each timed call; the legacy minimum/reuse protocol is not
  mixed into these samples. The zlib 1.2.11 third participant is retained in
  the Deflate raw reports, but the primary ratios use libdeflate.
- Deflate has six measured and six separate warmup rounds, retaining all six
  permutations of its three participants. Zstd has six alternating paired
  rounds. Brotli retains all five alternating paired rounds and an untimed
  encode before every timed Vort/reference batch. Each batch uses three
  encodes at 64 KiB and one at 1 MiB/full size. Each cohort contains **408
  measured primary pairs**, or **1,224** over all 216 conditions. Deflate's
  72 cases retain **432 warmup rounds**, each with all three participants.
- Complete initial wires undergo cross-library decoding. Deflate also checks
  exact compressed consumption and rechecks input SHA after timing. Timed
  loops retain output-length mixes, not a full decode of every timed wire.
  Initial wire SHA/length and policy metadata stay separate from that scope.
- Intel i7-10700K, Linux 6.8.0-79/glibc2.35, probe affinity CPU15, Zig 0.16.0
  ReleaseFast, GNU x86-64, `skylake+pku+sgx`, intel_pstate powersave, turbo on.
  Zstd's raw provenance declares its internal-auto policy; one-core affinity
  is not an independent thread-count audit. No per-codec RSS/heap comparison
  is available. This is a development host, not dedicated acceptance. The
  complete `validation-activity.jsonl.gz` preserves all 57 recorded activities
  at the archival snapshot; `activity-scope.json` binds its bytes and UTC range.
  These observations do not locate interference inside individual timed
  batches. The full matrix is explicitly nonquiet/observational.
- Competitor source revisions, library hashes and GCC11.4 Skylake build flags
  are carried by the frozen reference manifest. Sample metadata verifies
  requested files and runtime versions where exposed; it does not prove every
  loaded dependency's symbol identity. libdeflate reports its pinned-header
  version because that API has no runtime version query.
- Confidence intervals resample raw rounds within each fixed corpus row and
  relative Vort/reference order (2,000 deterministic bootstrap resamples).
  They do not cover other machines, sampling epochs or power policies.

The measured source is **4a9796b0**, not the later
**e083531a6fb5572f77349bdb190972f67ebda732** source. Between them,
`7c37c2913dee33fc47ffc9351bf6521690a3a07c` repaired Brotli complex fixed
block-length trees. `source-lineage.json` and `after-epoch-fixed-length.patch.gz`
preserve that distinction. Later functional validation and modeled-DP
experiments cannot relabel the source of this original matrix.

The largest measured speed cost here is q8. The current q8 pipeline can run
four optimal proposals after the lazy seed, with additional context/split
families. The existing command-model lifetime reuse is already present.
The next diagnostic should count actual physical losing wires and duplicated
entropy planning with the **same explicit window16** options. The default
q8 profile uses a null window and may select a different candidate graph;
its historical counts must not be substituted for this workload.

## Artifacts and reproduction

`raw-64k.tar.gz` preserves the original 72-condition checkpoint.
`raw-through-1m.tar.gz` preserves every JSON/CSV/stdout/stderr file and the
initial host snapshot through 144 conditions, including byte-identical copies
of those 72 original reports. Both retain the full planned task list; no
unfinished full-file condition is promoted to complete.
`raw-full.tar.gz` preserves the entire completed `matrix/` directory, including
all 216 JSON/CSV/stdout/stderr records, final manifest/summary and host snapshots.
`summary-full.json` is the byte-identical collector summary; `aggregate-full.json`
recomputes all eighteen twelve-row groups with the existing raw paired method.
Its contents match Root's separately generated full aggregate. Full group seed
indices differ from the old checkpoint group sets, so the old published CIs
remain preserved independently.
The three executable gzip files retain exact measured binaries.
`summary-64k.json` is the collector's complete cohort reduction;
`aggregate-64k.json` adds the original paired intervals. The corresponding
`summary-through-1m.json` / `aggregate-through-1m.json` include both cohorts.
The bootstrap assigns seeds by sorted group index; added groups can slightly
change a regenerated 64 KiB interval, so its published original remains tied
to the original archive and seed assignment. Build logs retain
their actual result: the first combined build failed to find zlib for the
explicit GNU target, and the separately saved linked/post-rebase builds
completed after declaration translation and explicit search paths were fixed.

`source-4a9796b0.tar.gz` preserves all **2,970** source/build/tool files from the
measured manifest, checked against their original hashes. The three `.gz` probes
decompress to the exact original manifest ELF hashes; `probe-identities.json`
records this without executing them. `matrix.log.gz`, the complete parallel
activity log and `collector-exit-receipt.json` retain terminal and activity
provenance. The receipt records Root's actual exit observation and does not
infer success from silence or merely from an existing manifest.

The verifier now loads exact measured-source `sample_gate.py` and its
`zstd_common_parameters.py` dependency from `validation_deps/`, with content
hashes checked against both `validation-dependencies.json` and the capture's
source manifest. It no longer imports the current checkout's tools. Original
replay source copies are retained there. Replaying metadata and statistics
does not execute codecs or require the original `/tmp` corpus/library paths.

Offline validation (no codec execution and no temporary corpus required):

```sh
epoch="$PWD/docs/performance/modern-encode-refresh-20261125"
(cd "$epoch" && sha256sum -c SHA256SUMS)
scratch=$(mktemp -d)
tar -xzf "$epoch/raw-64k.tar.gz" -C "$scratch"
PYTHONDONTWRITEBYTECODE=1 python3 "$epoch/verify.py" \
  "$scratch/checkpoint-64k" --allow-partial --output "$scratch/aggregate.json"
cmp "$scratch/aggregate.json" "$epoch/aggregate-64k.json"
tar -xzf "$epoch/raw-through-1m.tar.gz" -C "$scratch"
PYTHONDONTWRITEBYTECODE=1 taskset -c 0 python3 "$epoch/verify.py" \
  "$scratch/checkpoint-through-1m" --allow-partial --output "$scratch/through-1m.json"
cmp "$scratch/through-1m.json" "$epoch/aggregate-through-1m.json"
tar -xzf "$epoch/raw-full.tar.gz" -C "$scratch"
PYTHONDONTWRITEBYTECODE=1 taskset -c 0 python3 "$epoch/verify.py" \
  "$scratch/matrix" --output "$scratch/full.json"
cmp "$scratch/full.json" "$epoch/aggregate-full.json"
```

To collect the declared full matrix again, restore source at the revision
above, the frozen plain Silesia files/reference libraries from the
[decode baseline](../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction),
and build the three tools as in the [encoder contract note](../encoder-evidence-contracts-20261125.md).
Use a relocated full fixture manifest and an output directory outside the
clean source worktree:

```sh
PYTHONDONTWRITEBYTECODE=1 taskset -c 0,15 python3 "$epoch/collect.py" \
  --checkout "$source_worktree" --frozen-manifest "$frozen_manifest" \
  --bin-dir "$probe_dir" --output "$scratch/matrix"
```

The original complete collection remains under `/tmp/vort-encode-refresh.0LjGA1/`.
Its terminal exit was observed before this archival replay. No collection,
codec, ELF, test, build or throughput benchmark was executed during archival.
`offline-replay-receipt.json` records a second complete replay in an independent
migrated package directory, with the original repository/tools absent from its
import path. Loader dependency identity remains unverified where the original
reports say so; archival completion does not upgrade that status.
