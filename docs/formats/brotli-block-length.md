# Brotli one-shot meta-block length

`PlannedEncodeOptions.block_len` selects the one-shot planned encoder's
meta-block target. Zero keeps the quality/level default: 16 KiB for q0,
32 KiB for q6/q7/q11, and 64 KiB otherwise. The chunked
`PlannedStreamChunksOptions.block_len` already exposed the same control.

## Semantics

- A non-zero value must be at least 16 KiB. Non-HQ encoding is limited to
  64 KiB; HQ may select up to its own 16 MiB target.
- The value applies to the quality-scheduled one-shot planned API and its
  append/into forms. A non-zero value on a legacy one-shot level routes
  through the chunked meta-block core; zero keeps the historical wire. The
  chunked `PlannedStreamChunksOptions.block_len` exposes the same control
  directly.
- q0/q1 matching remains fragment-local. A larger fragment lets the fixed-hash
  parser see more of the input, at the cost of fragment latency and a less
  homogeneous one-pass entropy model.
- Defaults and existing wires are unchanged when `block_len` is zero.
- The CLI exposes `--block-len=BYTES` for `encode-br-file`,
  `encode-br-stream-file` and `encode-br-hex`; the HQ-specific
  `--hq-block-len` remains separate.

## Measured trade-off

On the twelve Silesia 64 KiB/1 MiB prefixes at q0, a 64 KiB target versus the
16 KiB default gives a `0.9710` size geometric mean, but the effect is
content-dependent: `osdb` falls to `0.753...0.755`, `nci.64k` to `0.877`,
`xml.64k` to `0.913` and `x-ray` to `0.920...0.951`, while `dickens` grows
`1.086...1.120`, `webster` `1.067...1.103` and `samba.64k` `1.108`. The
64 KiB target is therefore opt-in, not a default change. A 32 KiB target is
worse overall (`1.0180` geometric mean).

## Validation

Tests cover the 16 KiB lower bound, the non-HQ 64 KiB upper bound, a 64 KiB q0
wire that differs from the default, decode of both wires, and a legacy
fast-level 64 KiB target that routes through the chunked core and stays
within its bound. The complete Brotli suite remains the broader control. No
performance or RSS claim follows from the option itself.
