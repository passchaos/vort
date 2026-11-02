# Ring-aware PNG semantic window, 2026-11-02

`decodePngRingZlibImageWithOptions` now uses the ring-aware specialization of
the existing semantic window for the exported 128 KiB ring capacity. Other
caller-selected capacities retain the old sink prototype. Ordinary linear
decoder instantiations keep their existing behavior.

The ring loop shares paired-literal, RLE258, single-distance and non-overlap
kernels. Its writable limit and lap origin are explicit; wrapped-source
matches use a nearby split/replay helper. At a boundary it commits one checked
token before resuming the fast loop. Stored, fixed and dynamic blocks use the
same ring; valid compact-only trees no longer trigger a whole-stream restart.
`write_pos == total_written % ring_len` remains true at every committed step.

RLE speculative final stores must use the writable limit, not the allocation
end: those differ when the front of the ring still contains live history.
The new guarded tests cover every remaining span from 262 to 320 bytes and
position-zero previous-lap history. Other tests cover wrapped/overlapping
source matches, repeated laps, fixed/stored blocks and the existing valid
long-Huffman PNG. No heap allocation is added by this decoder.

Native ring/semantic/PNG tests pass 41; the windowed/export gate passes 97.
The broad no-NEON baseline has two encoder-dependent failures, recorded
separately; the new fixed-block test uses zlib's independent stream to verify
decoding. The no-NEON decoder-only gate passes 11/11; the broad gate passes
39/41 with exactly those two baseline failures. x86_64 compiles the core gate.
The imx owner passes 43 focused
tests, thirty full pixel buffers, 244 malformed/split-input parity checks,
and unchanged requested heap peak/total/count for all fifteen corpus rasters
under both Adler policies.

imx enables the product route only on measured AArch64 shapes. Long literal
codes (>=14) with deep distance codes (>=12) keep the contiguous owner. Seven
calibrated CPU-13 public-API rounds show Exoplanet/text-screenshot speedups of
about 3-4%, while Kodak17 stays flat. Complete-corpus ten-round aggregate gains
are about 0.3% strict and 0.5% ignored-Adler. Other targets remain pending
performance evidence. Detailed source, controls and samples are in imx's
`docs/evidence/png-ring-window/` and `/nav_env/Temp/imx-png-ring-window-20261102/`.
