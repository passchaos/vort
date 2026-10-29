# Brotli ranked Huffman evidence

This directory freezes the ordinary and mechanism evidence for letting an
already ranked `PrefixAlphabet` drive the bounded two-queue Huffman builder
directly.

- `formal-ab.tar.xz`: 216 JSON and 216 CSV process reports for three
  AB/BA/AB sweeps over 12 Silesia files at 4/16/64 KiB.
- `pilot-ab.tar.xz`: the preliminary three-input 64 KiB campaign.
- `formal-comparison.json` and `pilot-comparison.json`: all raw command
  invocations plus the 15-sample-per-side median reductions.
- `profile-*.json` and `profile-*-gate.json`: paired three-input q8 mechanism
  profiles and independent topology/timing audits.
- `inputs.tar.xz`: exact 36 input prefixes.
- `source-overlay.tar.xz`: the three changed source/test files relative to
  baseline `761da0dd`.
- `formal.py`, `pilot.py`, `audit.py`, `commands.txt`, `identities.txt` and
  `SHA256SUMS`: reproduction, identity and independent audit material.

The ordinary benchmark is uninstrumented. Each process performs five
Vort/reference alternating rounds; each timing sample contains three Vort
encodes, and every case/side reduction uses all 15 Vort samples. Instrumented
profile time is used only to explain mechanism, never as ordinary throughput.

The pinned upstream study source is Brotli 1.2.0 development commit
`558fc647`. Vort adopts its useful invariant of merging an ordered leaf queue
with a naturally ordered parent queue, while retaining Vort's existing rank
tie policy, `u64` weights, length-limited package-merge fallback, deterministic
wire and explicit resource contracts.
