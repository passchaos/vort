# Brotli standard-writer stack isolation

The public command-plan writer now calls the ordinary 79-symbol implementation
through a dedicated `noinline` specialization. Large Window, wide-distance and
adaptive-split branches return from the small dispatcher before the standard
writer's fixed scratch frame is entered.

This is a structural resource change only. The internal writer, candidate
ordering, entropy planning, allocation policy, requested-memory ledger and
wire arbitration are unchanged.

## Compiled Wasm frames

The baseline is clean `3d2ffb7b`. Separate Debug `wasm32-wasi` artifacts were
built from independent source archives with the same Zig compiler and 8 MiB
configured stack.

| Function | Baseline frame | Candidate frame |
| --- | ---: | ---: |
| public `encodeCommandPlanWithOptionsWrite` dispatcher | `2,166,384` | `448` |
| new standard-writer specialization | included in dispatcher | `2,165,968` |
| Large Window dispatcher | `400` | `400` |
| adaptive Large Window body | `3,425,488` | `3,425,488` |
| ordinary Large Window body | `2,230,176` | `2,230,176` |
| HQ meta-block caller | `164,032` | `164,032` |

The dispatcher is below the 4 KiB structural gate. Neither Large Window body
grew, and the standard path merely moves its existing frame behind one call
boundary.

## Real stack witnesses

The unchanged public Debug Wasm gate exercises q0/q11 total-memory contracts,
standard and Large Window whole-block modes, and complete-length HQ cases.

- At 8 MiB, baseline and candidate both pass.
- At 6 MiB, baseline and candidate both pass.
- At 5.5 MiB, the candidate passes all public checks; the baseline traps in
  `encodeCommandPlanWithLargeWindowWriteBody` through the large-writer chain.
- At 5 MiB and 4 MiB, the candidate itself traps in the HQ parser before the
  writer boundary. The change therefore does not claim a general sub-5.5 MiB
  Brotli stack requirement.

This same-witness boundary demonstrates a real stack reduction while retaining
the existing 8 MiB default for safety.

## Wire and ordinary performance

A native dual-module oracle compares baseline and candidate bytes for 32
quality-10/11 combinations: standard/Large Window, bounded/whole-block,
sampled/complete lengths, and two inputs. Every wire matches.

The q8 ordinary matrix uses all twelve Silesia files at 4, 16 and 64 KiB,
three AB/BA/AB process sweeps and fifteen samples per case/side.

| Scope | Candidate / baseline time |
| --- | ---: |
| all 36 | `1.000995` |
| 4 KiB | `0.999970` |
| 16 KiB | `0.999774` |
| 64 KiB | `1.003243` |

Sweep ratios are `1.000092`, `1.002403` and `0.998926`. All wire/settings
signatures match. The ordinary standard path stays within the pre-registered
0.3% aggregate and 0.5% sweep gates.

For 32 KiB source input, quality 10 and 11 each use fifteen samples per side:

| Quality | Candidate / baseline median |
| ---: | ---: |
| 10 | `1.003165` |
| 11 | `1.004443` |

Both remain below the 0.5% call-boundary gate and preserve complete
wire/settings identity.

## Validation boundary

The ReleaseFast Large Window Wasm gate passes with zero imports, q10/q11 wire
CRC identity and unchanged requested-heap peaks. Native Large Window, focused
HQ and x86 gates also pass. Debug `test-br-large-window-wasm` is not used as a
success claim: at baseline and candidate it retains WASI imports while its
Node harness requires an empty import list. The correct ReleaseFast target and
the separate public Debug WASI gate cover the two intended configurations.

Raw A/B reports, frame data, stack-witness identities, source overlay and
replay commands are retained in
[`data/brotli-standard-writer-stack-20261030/`](data/brotli-standard-writer-stack-20261030/).
