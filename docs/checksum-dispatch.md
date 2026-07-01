# Checksum dispatch plan

Vort dispatches IEEE CRC-32 to a portable slice-by-16 implementation by default.
Architecture-specific paths are available for ARMv8 (CRC32 instructions) and x86
(PCLMULQDQ folding), with the ARM path enabled for dispatch when the CPU feature
is detected. The x86 PCLMUL path is implemented but not yet enabled for dispatch
pending differential validation.

Current status:

- Adler-32: scalar zlib-compatible path.
- IEEE CRC-32: scalar, slice-by-4, slice-by-8, and slice-by-16 portable paths;
  best dispatch selects slice-by-16 on x86, hardware on ARMv8 with CRC feature.
- ARMv8 CRC32 hardware path enabled for dispatch (IEEE CRC-32 natively).
- x86 PCLMULQDQ folding path implemented, not yet validated for dispatch.
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
   builds currently report `portable-ieee-slice16`.
