# Zstd empty members and Brotli final metadata

Functional compatibility and safety evidence, 2026-11-15. The baseline is
`775ed212ebd46489051bd86fce72aa81a2246930`, Zig 0.16.0, Linux x86-64.
This work does not establish throughput, ratio, or memory leadership.
Archived text logs normalize trailing whitespace.

## Defects and resulting behavior

Zstd's `prevalidated_frame` decoder used a data-magic first-byte heuristic
after its cumulative exact output pledge was fulfilled. A data frame can
legitimately produce zero bytes, so that heuristic rejected fragmented empty
members while accepting the same complete frame. It also indexed an empty
buffer during an ordinary `step("", &.{})` poll, causing an out-of-bounds panic.
A truncated empty checksum footer was misreported as `SizeMismatch`. Conversely,
a complete nonempty frame with a known content size and no caller output could
ask for output even after the pledge was fulfilled.

The decoder now admits empty members under all input splits and polls safely.
The complete frame header, after dictionary admission, checks declared content
size against the per-frame and cumulative limits and the remaining exact
pledge. Unknown-size frames continue through block preflight and emission
checks. Raw, RLE, and compressed empty blocks, checksums, truncation recovery,
stopped-frame continuation, standard framing, and magicless framing remain
independently exercised.
When a raw/RLE block proves pending output and the budget is already exhausted,
the decoder now reports the budget error before asking for caller output. This
also covers frames without a declared content size.

Brotli permits a metadata meta-block with `ISLAST=1` and `ISEMPTY=0`. Vort
discarded that final flag and attempted to parse a following block, rejecting
valid streams as truncated or consuming their trailing bytes as another block.
The upstream `empty.compressed.15` (`1a`) and `empty.compressed.16` (`81160058`)
fixtures demonstrate both empty and nonempty final metadata. Metadata completion
now terminates the stream through its ordinary padding and exact-output checks.
The shared parser, one-shot decoders, summary/diagnostics, supported incremental
decoders, and HQ inspection preserve that final flag.

## Independent references and preserved reproductions

- [Zstd old fragmentation output](zstd-pledge_probe.txt) and
  [old empty-poll, checksum and backpressure output](zstd-edge_probe.txt) were
  collected from the baseline source before editing. The matching probe sources
  are preserved alongside those logs. Compile the Huffman object and probe:

  ```sh
  zig build-obj src/zstd_huffman_x2_object.zig -ODebug -femit-bin=/tmp/member-huffman.o
  zig build-exe /tmp/member-huffman.o --dep zstd -Mroot=docs/performance/codec-member-boundaries-20261115/zstd-pledge_probe.zig -Mzstd=src/zstd.zig -ODebug -femit-bin=/tmp/member-pledge-probe
  /tmp/member-pledge-probe
  ```

- [System libzstd 1.4.8 oracle](zstd-oracle-current.json) accepts all 12 standard
  empty-frame FCS/checksum/block-kind combinations. The
  [initial oracle log](zstd-libzstd-oracle.txt) accepts the saved
  standard empty-frame examples, including compressed blocks with and without
  content size and checksum. Known-size compressed fixtures use an independent
  1 KiB window, since a single-segment content size of zero gives a zero block
  maximum. Magicless framing is a separate Vort contract. The old edge probe
  additionally logs a two-byte compressed payload rejected by libzstd 1.4.8;
  that observation is excluded from compatibility evidence.
- [System libbrotli 1.0.9 oracle](brotli-oracle.json) accepts all 18 preserved
  [fixtures](brotli-fixtures): final and nonfinal metadata of lengths
  0, 1, 255, 256, 257, 65535, 65536, and 65537, plus the two upstream fixtures.
  Each record retains the wire hash, reference status, consumed boundary, and
  output length. Upstream's `c/dec/decode.c` handles metadata through
  `METABLOCK_DONE` and terminates when `is_last_metablock` is set.
- [Current target/reference differential](brotli-reference/final-metadata-differential.json)
  independently packs the same length boundaries and feeds all 18 streams to
  both libbrotli and Vort's public decode probe. Reproduce with:

  ```sh
  zig build -Doptimize=ReleaseFast run-br-metadata-diff -- --final-metadata-only
  python3 docs/performance/codec-member-boundaries-20261115/zstd-oracle.py
  ```

## Reproduction gates

`zig build test-codec-member-boundaries` runs the dedicated Zstd and Brotli
regressions. Add `-x86` or `-wasm` to run the same tests on Linux x86-musl or
32-bit WASI. The WASI runner executes the actual Zig test entry point and records
artifact hashes, test filters, imports, and exit codes.

The initial full Zstd suite passed 1,414 of 1,415 tests; its only failure was an
old diagnostic assertion expecting `direct_output` after an exact-length
rejection. Complete-header admission now reports `frame`. That test was moved
out of the facade into `zstd/incremental/decoder_tests.zig` and additionally
requires consumption of only the header, zero output progress, and intact output
sentinels. Its focused Debug rerun passes.

| Verification | Result |
| --- | --- |
| [Full ReleaseFast Zstd suite](zstd-full-releasefast.log) | 1,415/1,415 passed |
| [ReleaseFast Brotli decode, metadata, and public-root suites](br-decode-metadata-releasefast.log) | 223 + 37 + 109 = 369 passed |
| [Native and x86 Debug boundary gates](member-boundaries-debug.log) | 106/106 passed |
| WASI execution in the same boundary log | 23 Brotli + 30 Zstd passed; both test runners exit 0 |
| [Existing Zstd counter contracts](zstd-existing-counters-debug.log) | 20/20 passed |
| [Exact-size header diagnostic contracts](zstd-exact-header-debug.log) | 26/26 passed |
| [All-codec differential campaign](all-codec-differential.log) | 12,495 valid wires, 336,399 truncation cuts, 447,004 mutations; exit 0 |
| [Debug library, CLI, probes, and WASM checks](compile-checks-debug.log) | 381/381 steps, 86/86 tests; exit 0 |
| Independent empty-frame/final-metadata references | 12 Zstd and 18 Brotli fixtures passed |
| [CLI help smoke](cli-help-debug.log) | Exit 0 |

The differential campaign uses seed `0x20261115`, `--deep --max-size=8192`,
and raw Deflate, zlib, gzip, Zstd, and Brotli. Mutated wires may be accepted by
one implementation only; all 10,588 such cases remain explicitly counted, and
output must agree whenever both accept. This is the harness's declared
compatibility contract, not a claim that every acceptance/error classification
matches. [Host and loaded reference identities](host-reference-identity.json)
bind the system zlib 1.2.11, libzstd 1.4.8, and libbrotli 1.0.9 binaries.

An additional `-Doptimize=ReleaseFast check check-wasm` campaign is still
running in the isolated worktree. Its terminal result is not included in the
passed checks above. The current-source Debug check already compiles every
entrypoint in that graph, including the native Store range report that has
required extended optimization time in the additional campaign.

Zig 0.16 can print `failed command:` for a successful step that emitted stderr.
`std/Build/Step/Run.zig` stores nonempty diagnostic stderr even on successful
exit; `lib/compiler/build_runner.zig` renders it regardless of step result and
can append the command context. Thus the source-reverse WASI tests and the
successful full Zstd test log contain that label. The standalone source-reverse
rerun also exits zero. Verification uses the terminal build exit code and final
step/test summary rather than that label alone.

## Next functional work

The primary raw-byte fuzz target and generated Zstd differential campaign still
exercise Vort one-shot decode. Specialized compatibility tools cover some
incremental use but do not combine both input policies, zero exact pledges,
variable empty polls, tiny output, and reuse. The next functional increment
should add a shared bounded incremental fuzz driver whose wire and call schedule
can both be mutated. It should check successful and failed progress, canaries,
resource caps, sticky errors, and reset/continuation against fresh decoders,
then reuse the driver for valid, truncated, and mutated generated frames.
These safety fixes leave the broader functionality and performance leadership
goal active.
