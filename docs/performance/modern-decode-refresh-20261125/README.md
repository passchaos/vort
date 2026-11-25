# Current-source matched decode baseline, 2026-11-25

This development-host measurement fixes Vort at
`06d8086d3a21c3784f048fbe7ad201ba8e94b10e`. It is a profiling baseline, not a
performance acceptance gate, an encoding comparison, or a claim of industry
leadership. No codec source changed in this evidence increment.

## Results

All 72 fixed cold conditions per codec are included. Throughput is computed
from all measured pairs with equal weight per corpus row. Confidence intervals
resample measured pairs within each row and AB/BA stratum; they do not cover
other hosts, corpora, or power policies.

| Matched cold API | Vort MiB/s | Reference MiB/s | Vort / reference | Fixed-row 95% CI |
| --- | ---: | ---: | ---: | ---: |
| Raw Deflate / libdeflate 1.26 | 884.70 | 1,286.83 | **68.75%** | 68.65%–68.86% |
| Zstd / libzstd 1.6.0 | 1,118.48 | 1,415.46 | **79.02%** | 78.89%–79.15% |
| Brotli / libbrotli 1.2.0 | 391.57 | 470.95 | **83.15%** | 82.74%–83.60% |

| Cold throughput ratio | 64 KiB | 1 MiB | Full file |
| --- | ---: | ---: | ---: |
| Raw Deflate | 66.13% | 70.33% | 69.87% |
| Zstd | 80.39% | 77.83% | 78.86% |
| Brotli | 78.72% | 92.63% | 78.83% |

Zstd's matched prepared pair (`NativeFrameDecoder.decodeIntoSlice` and a
retained `ZSTD_DCtx`) reached **81.00%** on its additional 72 rows. The
Deflate prepared label applies only to the retained reference decompressor:
Vort still calls its one-shot facade, and the **68.53%** ratio is not a matched
prepared comparison. This probe has no matched prepared Brotli route.

The weakest cold rows are `mr` 64 KiB L9 for Deflate (**60.00%**), `mozilla`
1 MiB L3 for Zstd (**60.40%**), and full `mozilla` q11 for Brotli (**48.41%**).
Start profiling with the Deflate row (largest aggregate gap) and the Brotli
row (largest individual cliff). The earlier
[2026-11-12 epoch](../modern-decode-refresh-20261112.md) remains historical;
small cross-epoch shifts cannot be attributed to codec changes alone.

### Memory scope

Cold whole-child RSS medians were 7,992 KiB (Deflate), 8,568 KiB (Zstd), and
10,488 KiB (Brotli) across their respective size matrices. The maxima were
240,504, 239,480 and 242,976 KiB. Each child runs **both** sides: this records
probe/process scale including buffers, loaded libraries, and validation, not
codec-only heap or a Vort/reference memory ratio. Per-side RSS requires an
isolated memory experiment.

## Measurement contract and provenance

- 12 complete Silesia files plus their 64 KiB and 1 MiB prefixes; two producer
  levels per codec (Deflate L6/L9, Zstd L3/L19, Brotli q6/q11). The 216 encoded
  fixtures and 36 plain buffers are the same frozen bytes as in the
  [original epoch](../modern-decode-current-20261111/README.md). All lengths
  and hashes, including full local corpus files, were checked before timing.
- 360 isolated rows: 216 matched cold, 72 matched Zstd prepared, 72 Deflate
  reference-only prepared. Each has two warmup and six measured AB/BA pairs.
  Batches use 100, 20, and 1 iterations at 64 KiB, 1 MiB and full size. No
  samples were trimmed. One-shot state creation inside each selected API is
  timed; file I/O, library loading, allocations of caller buffers, and full
  final output validation are outside the timed batches.
- Output lengths are checked every iteration, full plaintext and guard bytes
  every batch. Exact compressed consumption is checked on both Deflate APIs;
  the chosen Zstd and Brotli one-shot APIs do not expose it.
- Intel i7-10700K, single-threaded children pinned to logical CPU 15 (SMT
  sibling 7), Linux 6.8.0-79-generic, Zig 0.16.0 ReleaseFast,
  `x86_64-linux-gnu`, `skylake+pku+sgx`. `intel_pstate`, `powersave`, turbo
  enabled. Compilation completed before sampling. The two host snapshots
  bracket the run but do not establish absence of per-batch interference.
- The same five reference library binaries and build provenance are preserved
  in the original archive; the new manifest binds their relocated absolute
  paths and checked hashes. Actual loaded library closures are recorded per
  row. Vort source-registry SHA-256:
  `de82b98194ea1a60b12c05f47fe3995105f3aa97938156f523665b517ecc79c2`.
  Measured executable SHA-256:
  `37ddb127efa5b484414ff59745a188e19d836c48706a7167c2665212d934a105`.

The timing runner completed all rows and wrote the summary and CSV. A separate
shell footer had a Python formatting syntax error after the run; the archived
manifest, raw rows, and resulting summaries were then independently validated
without rerunning or replacing any timing samples.

## Artifacts and reproduction

`manifest.json.gz`, `probe.gz`, `raw-rows.tar.gz`, `summary.json`,
`matrix.csv.gz`, `matrix.log.gz` and `build.log.gz` preserve the original bytes
for each listed artifact. The raw archive retains every row JSON, RSS sidecar and
stderr file (all empty). Probe stdout is retained as structured JSON within
those rows, not byte-for-byte stdout text. `aggregate.json` is derived by
`verify.py` from all measured pairs. The full corpus and wires are not stored
in Git.

Offline validation (from the measured revision's harness):

```sh
epoch=docs/performance/modern-decode-refresh-20261125
(cd "$epoch" && sha256sum -c SHA256SUMS)
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/tools/decode" \
  python3 "$epoch/verify.py" "$epoch"
```

To reproduce the timings, use the measured source revision, recover the
verified frozen fixtures (or reproduce them from the original epoch), and
bind them to the archived executable or a fresh ReleaseFast build:

```sh
epoch="$PWD/docs/performance/modern-decode-refresh-20261125"
original="$PWD/docs/performance/modern-decode-current-20261111"
scratch=$(mktemp -d)
git worktree add --detach "$scratch/source" 06d8086d3a21c3784f048fbe7ad201ba8e94b10e
cd "$scratch/source"
mkdir -p "$scratch/references" "$scratch/matrix"
tar -xzf "$original/reference-libraries.tar.gz" -C "$scratch/references"
gzip -dc "$epoch/probe.gz" > "$scratch/probe"
chmod +x "$scratch/probe"
# Build instead with: zig build -j3 -Dtarget=x86_64-linux-gnu \
#   -Dcpu=skylake+pku+sgx -Doptimize=ReleaseFast build-decode-compare
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/tools/decode" \
  python3 "$epoch/prepare.py" --template "$original/manifest.json" \
  --references "$scratch/references" --fixtures "$frozen_fixture_dir" \
  --corpus "$silesia_dir" --probe "$scratch/probe" --output "$scratch/matrix"
env -u LD_LIBRARY_PATH PYTHONDONTWRITEBYTECODE=1 taskset -c 0,15 \
  python3 tools/decode/matrix.py --probe "$scratch/probe" \
  --references "$scratch/matrix/references.json" --corpus "$silesia_dir" \
  --out-dir "$scratch/matrix" --cpu 15 --target-cpu skylake+pku+sgx \
  --sizes 65536,1048576,full --lifecycles cold,prepared --rounds 6 --warmup 2 \
  --bootstrap 2000 --iterations-64k 100 --iterations-1m 20 --iterations-full 1
```
