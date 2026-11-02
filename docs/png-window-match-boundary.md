# PNG window match boundary, 2026-11-02

The resumable semantic window fast loop reserved 258 destination bytes, the
maximum match length. One iteration can first retire two paired-literal
entries, adding four bytes, before processing the match. With only 258-260
bytes left, a valid long match then raised OutputTooSmall instead of pausing.

Window fast loops now require 262 bytes, including those literals. Smaller
windows use the existing transactional tail: it commits available literals,
restores the exact unconsumed match cursor, returns need_output, and resumes
after the owner makes space. Full-output error behavior and match validation
remain unchanged. No buffer size or allocator request grows.

`deflate/semantic/window_boundary_tests.zig` exercises ordinary and non-overlap
windows across capacities 258-266 using the existing independently accepted
long-code vector. It checks the committed prefix, guards, logical bit cursor,
complete resumed output and final reader position against checked decoding.
Before the fix, the new test fails with OutputTooSmall.

A second owning test uses four stored blocks filling the 256 KiB history to
258 bytes before its end, followed by paired literals and a 257-byte match.
This valid 6560x10 RGBA PNG payload also fails before the fix and passes after.
The same PNG is independently accepted by zlib, image-png and libpng with every
decoded pixel verified, and imx's public tests cover single/split IDAT and
strict/no-Adler owning/decodeInto paths.

Relevant validation: 25 semantic/PNG tests, 97 windowed/export tests, and 40
focused imx tests pass. Thirty real-corpus pixel buffers (15 images under both
checksum policies) match the independent normalized raster hashes. CPU-13
ten-round complete-corpus A/B is approximately unchanged: strict geomean
1.00094x and paired aggregate 1.00166x; no-Adler geomean 0.99938x and paired
aggregate 0.99621x. This fixes valid-stream acceptance and is not a throughput
leadership claim. x86_64 compiles the semantic/PNG gate separately.

Full proof and fixture provenance are in imx's
`docs/evidence/png-window-match-boundary/`; run artifacts are under
`/nav_env/Temp/imx-png-window-boundary-20261102/`.
