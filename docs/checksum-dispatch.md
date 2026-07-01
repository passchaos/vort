# Checksum dispatch plan

Vort currently dispatches IEEE CRC-32 to a portable slice-by-8 implementation.
This is intentionally separate from the x86 SSE4.2 `crc32` instruction, which
computes CRC-32C/Castagnoli rather than the gzip/zlib IEEE polynomial.

Current status:

- Adler-32: scalar zlib-compatible path.
- IEEE CRC-32: scalar, slice-by-4, slice-by-8, and slice-by-16 portable paths;
  best dispatch selects slice-by-16.
- CRC-32C: scalar, portable slice-by-8 fallback, and x86 SSE4.2 hardware path
  when available.

Architecture-specific IEEE CRC-32 work must preserve identical output to
`std.hash.crc.Crc32IsoHdlc` and Vort's scalar reference. Candidate paths:

- ARMv8 CRC32 instructions for IEEE CRC-32 on AArch64 targets that expose the
  CRC feature.
- x86 PCLMUL folding for IEEE CRC-32. This is distinct from SSE4.2 CRC32C and
  must be validated against the scalar/slice paths before dispatch.

Required gates before enabling an architecture-specific IEEE path:

1. Runtime or target-feature detection that distinguishes IEEE CRC-32 from
   CRC-32C instructions.
2. Unit tests comparing scalar, portable fast, and architecture-specific output
   over empty, tiny, aligned, unaligned, and multi-KiB buffers.
3. `run-checksum-diff` and `run-checksum-zlib-diff` must both pass.
4. `run-cpu-features` must report the selected IEEE path explicitly; portable
   builds currently report `portable-ieee-slice16`.
