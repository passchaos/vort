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

## Result

| reference | min | median | max | Vort faster | Vort slower |
| --- | ---: | ---: | ---: | ---: | ---: |
| libbrotli 1.0.9 (distro, tuned) | 0.747 | 0.957 | 1.466 | 5 | 7 |
| **libbrotli 1.2.0 (local cmake)** | 0.801 | **1.040** | 1.516 | **7** | 5 |

Per-file 1.0.9-vs-1.2.0 comparison is in `brotli-1.2.0-comparison.csv`.

## Why the ratio moved the "right" way — and why it is not a Vort speedup

Vort's own absolute decode speed is unchanged (~890 MiB/s on `xml` in both
runs). The median ratio crossing parity (0.957 -> 1.040) is driven by the
reference base: the generic-cmake 1.2.0 build measures ~5-10% **slower**
absolute MiB/s than the distro-tuned 1.0.9 on every file (0.90-0.97x). So:

- This does **not** show Vort gained performance; nothing in Vort changed.
- It shows the two references are not like-for-like builds. A rigorous
  "current upstream" claim needs 1.2.0 built with the same optimization policy
  as the distro 1.0.9 (or both built identically), which is out of scope here.
- The most defensible statement: against the version-1.2.0 source built with
  standard Release flags, Vort is at or above parity on 7/12 files and its
  near-incompressible leads persist (`sao` 1.516, `x-ray` 1.376).

## Cross-codec contrast on near-incompressible data (unchanged)

The shape of the result is stable across brotli versions: Vort's brotli
decoder leads on long literal-heavy, high-ratio files (`sao`, `x-ray`), the
inverse of zstd where those are its worst rows. That structural contrast holds
regardless of the reference build tuning.

## Scope limits

- Single host (i7-10700K), 20 iterations, one round, no CPU pinning or paired
  interleave; directional evidence, not the section-8 adoption gate.
- Decode one-shot only; no encode, RSS, streaming, or cold/warm split.
- The 1.0.9 CSVs are retained in the full-Silesia package for provenance.
- Measurement only; no production code changed. The build artifacts live under
  `~/Work/brotli/build-vort`, outside this repository.
