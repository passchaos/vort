# Route-scoped Brotli packed distance reuse, 2026-11-25

The [standard-header cache experiment](../packed-distance-reuse-20261125/README.md)
repaired the full Mozilla q11 row by 25.5% but regressed two controls, one of
which did not use the modified selector. This follow-up preserves the standard
header and localizes the spare expanded tree. Both prototype trees are based
on `261bbba0097d1e10f68f0e48cc26a47793e43bd8`. The baseline comparator is from
[`83bb442c`](../../decode-hotspots-main-20261125/README.md); the intervening
commits only archived evidence.

## Routes and correctness

- The candidate examines the four distance contexts of each block type only
  in the generic `wide10` meta-block wrapper and only if the distance table
  exceeds the inline tier. It selects the new executor if a row references
  two **distinct packed** trees. Auxiliaries and packed rows that only repeat
  the same tree retain their old executor. The route is computed before any
  payload progress.
- The original slot remains in the header. A second slot (stack local to the
  new executor) lives for one meta-block. Two-slot FIFO retains lazy prepared
  lookups on hits without promoting entries or copying tables. On a miss the
  canonical expansion must succeed before a slot or tag is replaced.
- The route/placement control makes the same routing decision, calls a
  separate payload in the same named section, but keeps the original one-slot
  reader. The control excludes the spare and reuse mechanism, not all
  compiler or layout changes.
- `check_route.py` uses a GDB breakpoint on the selected payload. With two
  one-iteration Vort decodes per probe and no warmup, full Mozilla q11 entered
  that payload **8** times (four meta-blocks per decode). Full Mozilla q6,
  1 MiB Mozilla q11 and 64 KiB X-ray q11 had **zero** hits. This is a route
  observation, not a timing result. Both decoders still validated full
  plaintext and buffer guards.
- Two standalone policy tests passed. The native ReleaseSafe decode suite
  passed **252/252**, including a direct one-slot/routed payload comparison
  across bit truncations and output bounds for four fixture families: error,
  bit position, output cursor/suffix, ring and all block switch states.
  The WASI memory/stream gate passed **67/67**; its execution receipt is
  preserved separately. No generated stack/RSS bound is inferred from the
  successful tests.

## Code generation and timing

DWARF shows standard `MinimalCompressedHeader` at **800,520 bytes** for all
three executables. The candidate adds a 3,517-byte isolated section and
512 bytes in ordinary `.text`; the control adds a 2,567-byte isolated section
and 256 bytes in `.text`. Two old wide payload instantiations retain their
2,567/4,123-byte sizes, but the old distance helpers are not byte-identical:
`distancePrefixForDecode` is 2,110/202/2,110 bytes and the ordinary
`readMinimalDistance` is 962/654/1,018 bytes in baseline/candidate/control.
The extra call site and shared core influence optimizer decisions even on
non-routed paths. Do not infer layout isolation from header size alone.

The two comparisons use the same twelve frozen Silesia rows and
[paired process runner](../packed-distance-reuse-20261125/screen.py). Each
variant has its own set of 72 interleaved baseline/variant process pairs,
with two measured and two warmup Vort/libbrotli pairs per child. Labelled
ratios are variant Vort vs baseline Vort, not normalized by libbrotli time.
The reference is pinned libbrotli 1.2.0, and all probes check full output,
guards and unchanged input. Fixed-row intervals resample outer pairs within
row and process order. The host is the same i7-10700K, Linux 6.8.0-79, logical
CPU 15, Zig 0.16.0 ReleaseFast, `x86_64-linux-gnu`, `skylake+pku+sgx`,
`intel_pstate` powersave with turbo enabled. Builds and the initial route
check finished before timing; the outlier route check ran afterwards. This
is a development-host screen, not dedicated acceptance.

### Disposition

**Neither variant is adopted; the small-screen gate already fails.** The
routed cache improves full Mozilla q11 by **17.81%** (1.17805×, fixed-row
95% CI 1.15924–1.19561×), short of the 20% weak-row gate. Its 12-row geomean
is **0.99788×** (95% CI 0.99271–1.00284×). The layout control is **0.98663×**
(95% CI 0.98064–0.99302×), with no q11 target gain. Selected results:

| Row | Routed cache | Route/placement control |
| --- | ---: | ---: |
| Full Mozilla q11 (target) | 1.17805× | 0.99563× |
| Full Mozilla q6 | 0.96604× | 0.98461× |
| 1 MiB Mozilla q11 | 1.01116× | 1.01418× |
| 64 KiB X-ray q11 | 1.00846× | 0.98864× |
| Full Samba q6 | 0.96579× | 0.98385× |
| Full Samba q11 | 0.95322× | 0.95301× |
| Full Ooffice q11 | 0.95453× | 0.98215× |
| Full `mr` q6 | 0.93271× | 0.93840× |

All five candidate controls below 0.98× **bypassed the new payload** in the
candidate executable: the original route audit covers Mozilla q6, and the
post-timing outlier audit covers the other four. The no-cache control also
loses on full Samba q11 and `mr` q6. That makes a direct cost from the
spare on those rows implausible, but does not identify the individual
code layout, address or optimizer decision responsible. All **288** timed
children validated; no full-matrix or dedicated-host adoption run followed.

Before retrying cache reuse, require a stronger non-routed codegen control
(e.g. a separately compiled executor and relocation-normalized baseline
hot symbols) rather than another eligibility threshold. The next low-cost
Deflate screen is to finish the match copy before the existing next-entry
prefetch/refill and inspect the resulting live ranges before timing. That
keeps the bounded tail and ordinary proof surface while targeting the
[measured semantic-loop hotspot](../../decode-hotspots-main-20261125/README.md#where-to-optimize-next).

## Verification and reproduction

The raw archives contain independent baseline samples for each comparison.
From the repository root, verify the saved data without re-running timing:

```sh
epoch="$PWD/docs/performance/br/routed-distance-reuse-20261125"
runner="$PWD/docs/performance/br/packed-distance-reuse-20261125/screen.py"
(cd "$epoch" && sha256sum -c SHA256SUMS)
export PYTHONPATH="$PWD/tools/decode" PYTHONDONTWRITEBYTECODE=1
scratch=$(mktemp -d)
for mode in candidate layout; do
  tar -xzf "$epoch/$mode-rows.tar.gz" -C "$scratch"
  python3 "$runner" verify "$scratch/$mode-raw"
done
for audit in route outliers; do
  tar -xzf "$epoch/$audit.tar.gz" -C "$scratch"
done
python3 "$epoch/verify.py" "$epoch" "$scratch"
```

To replay, use the two patches in separate clean worktrees on `261bbba0`,
restore the fixtures and comparator as in the [mainline refresh](../../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction),
and supply the configured sibling `vail/archive_crypto` dependency (this run
used `vail` revision `43fb07b4`):

```sh
for mode in candidate layout; do
  git worktree add --detach "$scratch/$mode" 261bbba0
  gzip -dc "$epoch/$mode.patch.gz" > "$scratch/$mode.patch"
  git -C "$scratch/$mode" apply "$scratch/$mode.patch"
  (cd "$scratch/$mode" && zig build -j2 --prefix "$scratch/$mode-bin" \
    -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx -Doptimize=ReleaseFast \
    build-decode-compare)
done
python3 "$epoch/check_route.py" --probe "$scratch/candidate-bin/bin/vort-decode-compare" \
  --frozen-manifest "$frozen_manifest" --output "$scratch/route"
for mode in candidate layout; do
  taskset -c 0,15 python3 "$runner" run --output "$scratch/$mode-replay" \
    --frozen-manifest "$frozen_manifest" --baseline "$baseline_probe" \
    --candidate "$scratch/$mode-bin/bin/vort-decode-compare" --patch "$scratch/$mode.patch"
done
```
