# Zstd levels 1-2 speed-first policy, 2026-11-16

## Decision

The default zstd level 1 was quality-first: a multi-candidate adaptive split
ladder that calls `std.Thread.spawn` up to three times per encode and runs the
bounded-optimal native parser for each candidate. On a 128 KiB `dickens`
prefix it measured **7.56 MiB/s at 50,404 bytes** versus libzstd 1.6.0 level 1
at **316.8 MiB/s and 56,148 bytes**.

The user chose to align levels 1-2 with the industry speed-first preset
semantics: one fast-compressed primary frame, no adaptive ladder and no
per-call threads. The quality ladder remains at level 3 and above.

## Prototype change (not merged)

A prototype set `selection = .fast_compressed` for levels 1-2 in
`encodeFrameWithLevelAndOptionsAllocUnbudgeted` and
`LevelFrameEncoder.encodeScratchUnbudgeted` and encoded one primary frame.
The measurements below are from that prototype. It is **not merged**: the
full `test-zstd` run reports ten failures that pin the old level-1/2 adaptive
ladder or legacy level wires, and the reusable level encoder produced a
different fast frame from the one-shot encoder (window derivation differs,
357 versus 314 bytes). The semantic change needs a dedicated migration
increment that updates those tests and makes the reusable and one-shot window
policy identical.

## Result (128 KiB dickens prefix, `run-zstd-encode-bench`)

| row | vort bytes | size/ref | Vort MiB/s | libzstd 1.6.0 MiB/s |
| --- | ---: | ---: | ---: | ---: |
| level 1 auto (before) | 50,404 | 0.8977 | 7.56 | 316.79 |
| level 1 fast (after) | 63,414 | 1.1294 | **77.11** | 314.68 |
| level 2 auto (before) | 50,325 | 0.9333 | 1.58 | 259.83 |
| level 2 fast (after) | 63,414 | 1.1760 | **76.02** | 260.05 |
| level 3 ladder (unchanged) | 50,325 | 0.9708 | 3.65 | 193.97 |

Level 1 is 10.2x faster and level 2 48x faster than their previous policies.
The tradeoff is explicit: the fast frame is 13-18% larger than libzstd's
level-1/2 output, and the fast encoder itself is still about 4.1x slower than
libzstd. Improving fast-encoder ratio and speed is the next encoder target.

The level-3+ ladder remains ratio-first and very slow (3.65 MiB/s here); its
per-call `std.Thread.spawn` also remains an architecture-rule violation to fix
in a separate increment.

## Validation

- The bench decodes every produced frame with both libzstd and Vort and
  verifies byte equality before reporting.
- Full `test-zstd` on the prototype: 1420/1430 passed, 10 failed (the old
  level-1/2 policy/golden-wire tests). The encode bench gate also failed on a
  level-1 size bound. The reusable prefix/stable-output suites passed 238/238
  before the window-consistency mismatch was isolated.

## Scope limits

One host, one 128 KiB prefix, `iterations=1`, `rounds=3`. This is a policy
increment, not a fast-encoder quality/speed claim; the ratio gap to libzstd
level 1 is recorded, not hidden.
