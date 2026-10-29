# Zstd natural-aligned node40 screen

This package records a rejected recheck of the Zstd HQ 40-byte DP node against
clean baseline `c2b69ebeeb97e7391fe5769d84d29833cc957a4d`.

Unlike the earlier source-less node40 experiment, this candidate used a normal
aligned struct. DP-local repeats and distance were `u32`; predecessor position
and slot were encoded in one ordinary `u32` as `position << 8 | slot`. Public
parameters, Plan state, records and persistent encoder repeats stayed wide.

- `source-overlay.tar.xz`: complete candidate HQ parser directory.
- `mozilla-4096`: exact early-stop input.
- `pilot.py`: eight alternating AB/BA sweeps for btopt and btultra2.
- `pilot-comparison.json`: sixteen samples per side and strategy with commands.
- `summary.json`: condensed time, memory and decision.
- `identities.txt`: baseline, compiler, CPU, binaries, reference and input.
- `validation.txt`: functional and rollback boundary.
- `SHA256SUMS`: integrity manifest.

Replay by extracting the overlay over a clean baseline archive, linking the
sibling `vail` checkout, building independent ReleaseFast baseline/candidate
`vort-zstd-encode-bench` executables, updating their paths in `pilot.py`, and
running on an otherwise idle logical CPU 2.
