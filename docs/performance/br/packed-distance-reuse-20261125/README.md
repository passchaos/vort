# Brotli packed distance tree reuse, 2026-11-25

The [mainline cold decode profile](../../decode-hotspots-main-20261125/README.md)
placed packed distance tree construction inside the full Mozilla q11 hotspot.
This increment measures actual expansion churn, then screens one bounded
reuse policy. The two experiment worktrees start at
`89fc362552660f428b6ad950314b81ed7a0bea48`. The timed baseline reuses the
hotspot comparator built at `83bb442c`; the intervening commit changed only
documentation. Both use the
[frozen Silesia inputs and libbrotli 1.2.0](../../modern-decode-refresh-20261125/README.md).

## Actual expansion churn

The instrumented ReleaseFast probe calls Vort `decodeStreamInto` exactly
once per wire. It separately calls `BrotliDecoderDecompress`; both outputs
must match the complete frozen plaintext. The counters observe successful
standard-header `distancePrefixForDecode` selections and actual packed
expansions; they do not count other distance readers or implicit distances.
Each shadow cache resets with the standard parsed header. The one-slot
shadow agrees with actual expansions in every meta-block. Two/four-slot
misses are predictions over the same requests, **not measurements of timing**.

| Mozilla wire | All selector requests | Packed requests | Actual expansions | Two-slot FIFO / LRU misses | Four-slot FIFO / LRU misses |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full q11 | 2,114,490 | 324,514 | 48,367 | 311 / 293 | 228 / 211 |
| Full q6 | 2,339,076 | 1,755,908 | 1,112 | 1,048 / 1,046 | 1,046 / 1,046 |
| 1 MiB q11 | 0 | 0 | 0 | 0 / 0 | 0 / 0 |

Full q11's wide10 generic meta-blocks 3 and 7 account for 32,726 and 15,563
expansions, respectively (zero-based indices). The two-slot LRU predicts
eliminating **99.39%** of q11 expansions; two more slots would save only
82 additional expansions. The q6 control already hits its single slot for
more than 99.93% of packed requests, so extra cost on the hit path matters.
The 1 MiB q11 control uses `external_auxiliary_postfix`, which bypasses this
selector; zero is not an absence of distance codes. The executed counts are
distinct from the earlier replay's lazy prepared-lookup build counts.

The exact diagnostic patch, three raw per-block reports, original commands
and hash-check receipt are under `trace/`. The diagnostic used Zig 0.16.0
`-O ReleaseFast -mcpu=native`, CPU affinity `4,12`, and no wall timings. The
original run completed all three decodes before a Python 3.10 hash-helper
error in the footer; the corrected hash pass verified the existing reports
without replacing them. `verify_trace.py` reconciles the archived hashes and
counter totals offline.

## Timed two-slot prototype

Keep the most recently used tag first. A hit returns the existing expanded
slot and reuses its lazy lookup. A second-slot hit promotes its tag; a miss
builds in a separate cold helper and evicts the least-recently used slot.
The packed key is valid only for this parsed meta-block; both tags are
invalidated on reparse. No pointer escapes the current distance read.
This is limited to the standard header; the Large Window cache is unchanged.

One extra expanded tree is 3,752 bytes. DWARF records a **3,760-byte**
standard-header increase (800,520 → 804,280 bytes); the probe's `.text`
grows by 256 bytes. `distancePrefixForDecode` shrinks from 2,110 to 193 bytes
with a separate 2,099-byte cold expansion symbol. These are static sizes,
not an isolated RSS or a whole-process stack measurement.

### Timing protocol

Twelve Silesia rows use cold `brDecodeStreamInto`; the baseline and candidate
have the same frozen compressed bytes, original host, caller-buffer contract
and libbrotli 1.2.0 validation. Each row has six interleaved process pairs,
three in each baseline/candidate order; row order is shuffled per sweep.
Each child records two warmup and two measured Vort/libbrotli AB/BA pairs.
The comparison is the geometric mean of **baseline Vort / candidate Vort**
batch medians in each outer pair. It is not normalized by reference times.
The interval bootstraps within each fixed row and process order (4,000
resamples); it does not measure variation across hosts. Input sizes, bytes,
hashes and sample order are retained in the raw manifest. All batches check
full decoded bytes, guards and unmodified compressed input.

Intel i7-10700K, Linux 6.8.0-79, one thread on logical CPU 15, Zig 0.16.0
ReleaseFast, `x86_64-linux-gnu`, `skylake+pku+sgx`; `intel_pstate` `powersave`,
turbo on. The probe builds and trace finished before timing. Host process
snapshots are retained, but do not establish isolation. This is a
development-host candidate screen, not a dedicated-host ratchet.

### Disposition

**Do not adopt this prototype.** The full Mozilla q11 target improves
**1.25499×** (95% CI **1.24557–1.26662×**). The twelve-row geomean is
**1.02823×** (95% CI **1.02314–1.03327×**), short of the 1.03× scope gate.
Two of eleven controls are below the 0.98× floor. Every row below is
candidate over baseline, not Vort over libbrotli:

| Key row | Speedup | Fixed-row 95% CI |
| --- | ---: | ---: |
| Full Mozilla q11 | 1.25499× | 1.24557–1.26662× |
| Full Mozilla q6 | 1.00640× | 0.99633–1.01714× |
| 1 MiB Mozilla q11 | **0.97512×** | 0.96333–0.98716× |
| 64 KiB X-ray q11 | **0.97837×** | 0.97168–0.98568× |

All 144 children (72 outer pairs) matched the frozen output and passed the
probe checks. The candidate also passed its standalone cache test, 250 native
ReleaseSafe decode tests and all 67 WASI memory/stream contract tests. That
establishes the tested correctness, not an adoption decision or a peak-memory
bound. All twelve point estimates and intervals are in `screen-summary.json`.

A candidate that reuses the cache **only** in the packed wide10 generic
executor should leave the existing header allocation and non-packed/auxiliary
routes unchanged. Compare this with a routed layout-only control; the 1 MiB
control bypasses the measured selector, so its loss cannot be explained by
extra cache probes in that helper. Re-screen the 12 rows, then expand to the
full matrix and run resource and dedicated-host gates before adopting.

## Reproduction

Extract and verify existing evidence without executing either codec:

```sh
epoch="$PWD/docs/performance/br/packed-distance-reuse-20261125"
(cd "$epoch" && sha256sum -c SHA256SUMS)
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/tools/decode"
python3 "$epoch/verify_trace.py" "$epoch/trace"
scratch=$(mktemp -d)
tar -xzf "$epoch/timed-rows.tar.gz" -C "$scratch"
python3 "$epoch/screen.py" verify "$scratch/screen-raw"
```

To repeat, restore the same frozen files and libraries as in the
[matched refresh](../../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction).
Apply each patch to its own clean worktree at the revision above. For the
trace, restore the extracted mainline hotspot manifest with local paths:

```sh
gzip -dc "$epoch/trace/distance-reuse-trace.patch.gz" | git -C "$scratch/trace" apply -
bash "$epoch/trace/run.sh" "$scratch/trace" "$scratch/fresh-trace" \
  "$hotspot_manifest" "$frozen_fixture_dir" "$brotli_reference_dir"
```

For the timed candidate build, preserve the configured
`../vail/archive_crypto` dependency (`vail` at `43fb07b4` in this run), then use:

```sh
gzip -dc "$epoch/two-slot.patch.gz" > "$scratch/two-slot.patch"
git -C "$scratch/two-slot" apply "$scratch/two-slot.patch"
(cd "$scratch/two-slot" && zig build -j2 --prefix "$scratch/install" \
  -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx -Doptimize=ReleaseFast \
  build-decode-compare)
taskset -c 0,15 python3 "$epoch/screen.py" run \
  --output "$scratch/trial" --frozen-manifest "$frozen_manifest" \
  --baseline "$baseline_probe" --candidate "$scratch/install/bin/vort-decode-compare" \
  --patch "$scratch/two-slot.patch"
```

`$baseline_probe` is the verified comparator from the matched refresh. Run
from the baseline checkout with `PYTHONPATH` pointing to its `tools/decode`.
A freshly collected timing run is not expected to reproduce the stored
nanoseconds, only the experiment design and correctness checks.
