# Deflate public generic semantic contracts, 2026-11-12

This functional increment establishes malformed and boundary witnesses through
the public generic semantic entry before further decoder optimization. It adds
27 caller-buffer scenarios and two direct `root.decodeRawDeflate` calls. It does
not change production decode behavior or claim a throughput improvement.

The earlier test named `semantic non-overlap full-output loop matches public
decode` directly exercises the private aligned function, but its public call
uses a small literal alphabet that selects the compact nine-bit decoder. Its
name is insufficient evidence of public generic dispatch. The existing real
OSDB test establishes generic secondary success, without malformed or short
output cases.

The new test reuses the exact OSDB header and independently writes new token
bodies. It explicitly checks a complete LL tree with maximum width 14, distance
width 9, more than one distance symbol, no RLE258 selection, successful semantic
initialization, no input/output overlap, and the private public-selector result
of 11 bits. Padded short bodies also prove the actual first-iteration input and
16-byte output headroom. Native production uses `linear_entry.aligned`; WASI
uses its portable entry with the same five-false linear core.

Coverage includes secondary length success, initial distance-one and distance-
32768 `InvalidMatch`, fast-loop `OutputTooSmall`, true insufficient capacity,
0–15-byte destinations, and a long body whose last 1–4 bytes are removed after
real fast iterations. A separately generated complete LL10 tree and incomplete
distance tree exercise a missing distance primary code as `InvalidHuffmanCode`.
The latter is a Vort acceptance/error contract, not a claim that reference
decoders accept that incomplete tree.

Every public call checks 64-byte input/output guards and input immutability.
Success checks exact output and prefix consumption despite trailing padding.
Existing speculative stores inside the whole output capacity remain allowed;
the tests do not require rollback of error output or unused scratch bytes.

Validation of the frozen source overlay passes:

- Deflate filtered Debug, ReleaseSafe, 32-bit x86 ReleaseSafe and actual WASI:
  8/8 each, containing one behavioral aggregate and seven import tests.
- Direct library root Debug, ReleaseSafe and actual WASI: 90/90 each, containing
  the two behavioral aggregates and 88 import tests.
- Complete Deflate ReleaseSafe suite: 734/734.
- Independent Python/zlib 1.2.11 oracle: eight real-header scenarios, including
  full output hashes, bad history and tail truncation.

These counts do not represent 90 separate new behavioral tests. The source,
commands, exact logs, executable identities, and independent oracle are bound
in the [proof archive](public-linear-contracts-20261112/README.md). The oracle
rerun is a later explicitly recorded verification, not a reconstruction of an
earlier tool's stdout bytes.

The [fresh reymont profile](reymont-profile-20261112/README.md) separately binds
the pre-test `8adfb3ba` source and frozen compare executable. Profile clocks are
diagnostic and are excluded from candidate A/B comparisons. New test adapters
are not backdated into that timing source epoch.
