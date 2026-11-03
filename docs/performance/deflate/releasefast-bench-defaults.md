# ReleaseFast defaults for checksum and decode-stage benches, 2026-11-03

`bench-checksum` and `run-deflate-decode-stage-report` previously compiled
both the `vort` module and the executable with the standard `optimize` option,
which defaults to Debug. Their throughput columns were therefore unoptimized
samples: the stage report showed Adler-32 at about 594 MiB/s and structured
caller-buffer raw inflate at about 1,078 MiB/s.

Both steps now compile the library module and executable with `ReleaseFast` by
default. The same host measures:

| Measurement | Debug default | ReleaseFast default |
| --- | ---: | ---: |
| Adler-32 (1 MiB) | 594 MiB/s | 34.9–37.9 GiB/s |
| CRC-32 best (1 MiB) | 3.1 GiB/s | 29.6 GiB/s |
| Structured raw inflate into caller buffer | 1,078 MiB/s | 7,129 MiB/s |
| Structured zlib into caller buffer | 391 MiB/s | 6,477 MiB/s |
| Stored raw inflate into caller buffer | 46,975 MiB/s | 55,056 MiB/s |

The ReleaseFast stage report keeps its existing separation of raw, zlib and
gzip alloc/exact/into paths, wrapper and checksum rows, and stored controls.
These rows remain diagnostic; they are not a competitor ranking or a
whole-file benchmark.
