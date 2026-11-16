# Brotli decode against current libbrotli 1.2.0 (full Silesia), 2026-11-16

## Why this package exists

The earlier full-Silesia brotli numbers used the distro **libbrotli 1.0.9
(2016)**, so the READMEs called the observed Vort leads provisional pending a
current-library check. This package closes that gap using libbrotli **1.2.0**
built locally from `~/Work/brotli` (source version confirmed in
`c/common/version.h`), loaded through the reference bench's runtime
`--libbrotli-*` override (added this session).

## Build and identity caveat — read before interpreting

- The 1.2.0 libraries were built with a generic `cmake
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON` into an out-of-tree
  `build-vort/` directory. They are **not** built with the distribution's
  LTO/native/`-march` tuning that the installed 1.0.9 package carries.
- SHA-256 of the three built libraries (reproducible for this exact build):
  - libbrotlicommon.so.1.2.0 `3e05a68c…c4307739`
  - libbrotlidec.so.1.2.0    `3acf4597…f07c0469`
  - libbrotlienc.so.1.2.0    `aaa556ba…4a2f95bb`
- Consequently the absolute reference throughput here is **build-dependent**,
  and a different (better-tuned) 1.2.0 build could shift the ratios. Treat the
  cross-version direction as more reliable than the exact magnitude.

## Result (two 1.2.0 builds; the tuned one is the honest reference)

Two local 1.2.0 builds were measured so the build-policy effect is visible:

| reference | build | median | min | max | Vort faster |
| --- | --- | ---: | ---: | ---: | ---: |
| libbrotli 1.0.9 | distro (LTO/native tuned) | 0.957 | 0.747 | 1.466 | 5/12 |
| libbrotli 1.2.0 | generic `Release` cmake | 1.040 | 0.801 | 1.516 | 7/12 |
| **libbrotli 1.2.0** | **`-O3 -march=native -flto`** | **1.017** | 0.790 | 1.462 | **7/12** |

Per-file tables: `brotli-1.2.0-comparison.csv` (generic) and
`brotli-1.2.0-tuned-comparison.csv` (tuned, preferred).

The tuned build is the fair comparison because it applies the same class of
optimization the distro uses. Against it, Vort sits just above parity on the
median (1.017) and is faster on 7/12 files — a smaller edge than the 1.040 the
generic build suggested. The earlier generic-only number was therefore mildly
optimistic and is retained only to show the build-policy sensitivity.

## What the data supports

- Vort's own absolute decode speed is unchanged across all runs (~890 MiB/s on
  `xml`); only the reference base moves with its build flags.
- Against a fairly-tuned current libbrotli 1.2.0, Vort is **roughly at parity**
  overall, with a structural advantage on near-incompressible literal-heavy
  files (`sao` 1.462, `x-ray` 1.323) and a persistent weak spot on `mr`
  (0.790). The 7/12 split is stable across both 1.2.0 builds.
- The cross-codec contrast holds: these same high-ratio files are zstd's worst
  rows, while they are brotli's best for Vort.

## Why no hard "faster than current upstream" claim

The tuned build still may not match the exact distro policy (linker, specific
- march, PGO), and the run is a single-host diagnostic without CPU pinning or
paired interleaving. "Roughly at parity with current libbrotli on decode,
stronger on near-incompressible inputs" is the defensible statement; it is not
the section-8 adoption-gate evidence.

## Scope limits

- Single host (i7-10700K), 20 iterations, one round, no CPU pinning or paired
  interleave; directional evidence, not the section-8 adoption gate.
- Decode one-shot only; no encode, RSS, streaming, or cold/warm split.
- The 1.0.9 CSVs are retained in the full-Silesia package for provenance.
- Measurement only; no production code changed. The build artifacts live under
  `~/Work/brotli/build-vort`, outside this repository.
