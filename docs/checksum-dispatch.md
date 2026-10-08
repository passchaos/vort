# Checksum dispatch plan

Vort dispatches IEEE CRC-32 to a portable slice-by-32 implementation by default.
Validated hardware paths are selected for ARMv8 CRC32 and x86 PCLMULQDQ when
their target features are available. Generic AArch64, x86 without PCLMUL, and
other targets retain the portable fallback.

Current status:

- Adler-32: scalar zlib-compatible path.
- IEEE CRC-32: scalar, slice-by-4, slice-by-8, slice-by-16, and slice-by-32 portable paths;
  best dispatch selects slice-by-32 unless a validated hardware path is active.
- ARMv8 CRC32 instructions are enabled for one-shot and incremental IEEE CRC-32
  when the target exposes the `crc` feature.
- x86 PCLMULQDQ folding path implemented and independently tested before dispatch.
- CRC-32C: scalar, portable slice-by-8 and slice-by-16 fallbacks, and x86
  SSE4.2 hardware path when available.

Architecture-specific IEEE CRC-32 work must preserve identical output to
`std.hash.crc.Crc32IsoHdlc` and Vort's scalar reference. Candidate paths:

- ARMv8 CRC32 instructions for IEEE CRC-32 on AArch64 targets that expose the
  CRC feature.
- x86 PCLMUL folding for IEEE CRC-32. This is distinct from SSE4.2 CRC32C and
  must be validated against the scalar/slice paths before dispatch.

Required gates before enabling an architecture-specific IEEE path:

1. Runtime or target-feature detection that distinguishes IEEE CRC-32 from
   CRC-32C instructions. `run-cpu-features` now reports
   `ieee_crc32_pclmul_candidate` separately from SSE4.2 CRC32C, and
   reports ARM CRC32 feature availability as `arm_crc32`.
2. Unit tests comparing scalar, portable fast, and architecture-specific output
   over empty, tiny, aligned, unaligned, and multi-KiB buffers.
3. `run-checksum-diff` and `run-checksum-zlib-diff` must both pass.
4. `run-cpu-features` must report the selected IEEE path explicitly; portable
   builds report `portable-ieee-slice32`, while feature-enabled AArch64 builds
   report the hardware path.

The AArch64 path was enabled after exhaustive differential coverage over every
length `0...8192`, sixteen starting offsets, and split incremental updates. Five
CPU-0 ReleaseFast checksum samples over a repeatedly perturbed 1 MiB input put
`crc32-best` at a median 18,103 MiB/s versus 3,926 MiB/s for slice-by-32, a
`4.61x` improvement with identical digest mixes.

## Block checksum composition

`adler32Combine(left, right, right_len)`, `crc32Combine(left, right, right_len)`,
and `crc32cCombine(left, right, right_len)` compose already-finalized per-block
digests into a whole-stream digest. Adler-32 uses the zlib-compatible modular
sum formula, while the CRC helpers use GF(2) operators for the reflected CRC
polynomials. These helpers are intended for indexed, blocked, or parallel paths
that can validate chunks independently without rereading all payload bytes for a
final checksum. Unit tests cover empty, tiny, large, and associative multi-block
combinations against one-shot Adler-32, CRC-32, and CRC-32C hashes.
