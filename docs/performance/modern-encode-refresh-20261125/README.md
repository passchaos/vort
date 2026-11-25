# Current allocating encoder baseline: 64 KiB / 1 MiB checkpoints, 2026-11-25

This package freezes complete **72-row cohorts at 64 KiB and 1 MiB** at
source `4a9796b01aa0617aace28d2d4ca2c83cb81b409a`: **144 completed conditions**.
The original collector continues its declared **216-row** matrix with actual
full files. Checkpoint manifests deliberately retain `complete=false`; these
numbers do not establish the unfinished full-file cohort, a matched-quality frontier,
streaming/reusable performance, or industry leadership.

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
  encodes at 64 KiB and one at 1 MiB. Each cohort contains **408 measured
  primary pairs**, or **816** over the completed 144 conditions.
- Complete initial wires undergo cross-library decoding. Deflate also checks
  exact compressed consumption and rechecks input SHA after timing. Timed
  loops retain output-length mixes, not a full decode of every timed wire.
  Initial wire SHA/length and policy metadata stay separate from that scope.
- Intel i7-10700K, Linux 6.8.0-79/glibc2.35, probe affinity CPU15, Zig 0.16.0
  ReleaseFast, GNU x86-64, `skylake+pku+sgx`, intel_pstate powersave, turbo on.
  Zstd's raw provenance declares its internal-auto policy; one-core affinity
  is not an independent thread-count audit. No per-codec RSS/heap comparison
  is available. This is a development host, not dedicated acceptance.
- Competitor source revisions, library hashes and GCC11.4 Skylake build flags
  are carried by the frozen reference manifest. Sample metadata verifies
  requested files and runtime versions where exposed; it does not prove every
  loaded dependency's symbol identity. libdeflate reports its pinned-header
  version because that API has no runtime version query.
- Confidence intervals resample raw rounds within each fixed corpus row and
  relative Vort/reference order (2,000 deterministic bootstrap resamples).
  They do not cover other machines, sampling epochs or power policies.

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

The original long collection remains under `/tmp/vort-encode-refresh.0LjGA1/`;
it must be observed through its live process/session before any continuation
attempt. A partial manifest or checkpoint alone does not prove it stopped.
