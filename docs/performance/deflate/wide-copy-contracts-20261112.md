# Deflate complete wide-copy contract, 2026-11-12

The `copyWide` kernel declared lengths 3..258, but lengths 3..15 skipped its
word loop and underflowed `length - 16`. A direct ReleaseSafe scalar-oracle
test reproduced an integer-overflow abort on its first three-byte case.
Existing direct tests exercised `copy`, without testing `copyWide`.

The correction preserves the complete length contract: short spans use the
existing exact copy, and lengths at least 16 use the original wide loop. A
separate validated `copyWideAtLeast16` boundary serves the existing production
call, whose preceding short-copy and destination guards already imply length
at least 17. No distance, source or destination guard is removed. This is an
internal kernel contract repair, not a newly observed public wire failure.

Initial placement of the short fallback changed generic-loop register and
stack layout. That source and binary remain separate in the evidence. The
final boundary moves the fallback out of that hot invocation, restoring its
296-byte local stack reservation. Generated wide-loop entry/tail instructions
still differ from the original binary, so machine-code equivalence is not
claimed.

The final independent byte-copy oracle covers 73,728 full-facade cases and
69,984 validated-core cases: all supported lengths, sixteen source and
destination offsets, and adjacent disjoint intervals in both address orders.
Every call uses exact-length slices and checks the entire backing buffers and
unchanged source. Overlapping source/destination is outside the contract.

Final Debug, ReleaseSafe, 32-bit x86 ReleaseSafe and actual WASI each pass the
143,712-scenario aggregate. Complete Deflate ReleaseSafe passes 736/736. All
72 frozen Deflate wires also pass a one-call full-output, exact-consumption,
input-immutability and guard smoke against libdeflate 1.26. Smoke timings are
excluded from performance conclusions.

A separate twelve-row functional non-regression pilot preserves 96 successful
child events. Its selected-row throughput ratio is 1.003628x; every row remains
above 0.98x, with the weakest nci 1 MiB L9 row at 0.984859x. This development-host
screen is not a full 72-row or dedicated-host performance-gain acceptance.
The complete modern-reference ranking is unchanged.

The production/test increment is `fe75d21f`. Frozen before, initial correction
and final-boundary source epochs, raw logs, executables, static inspection and
the pilot/smoke results are preserved in the
[proof archive](wide-copy-contracts-20261112/README.md).
