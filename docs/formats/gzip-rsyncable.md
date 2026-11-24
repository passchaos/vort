# Rsync-friendly incremental gzip

Set `.raw.rsyncable = true` on `GzipIncrementalFixedEncoder` or
`GzipIncrementalBestEncoder`. The same option is available on the underlying
raw incremental encoders. It is off by default and does not change the wire
format: ordinary gzip readers decode the result without an opt-in.

```zig
var encoder = vort.GzipIncrementalBestEncoder.initWithOptions(allocator, .{
    .raw = .{ .rsyncable = true },
});
defer encoder.deinit();
// Drive step/finish as for any incremental gzip member.
```

This mode hashes the recent content, rather than byte positions, when
choosing a boundary. A cut is eligible after 8 KiB and on a 13-bit hash hit;
`block_len` (32 KiB by default) remains a hard cap. An earlier cap forces a
cut even without a hash hit. Each cut ends the block and emits a byte-aligned
full-flush marker, clearing the match history. CRC-32 and ISIZE still cover
the whole gzip member. The next segment can therefore be decoded independently
from the marker, but that does not validate the skipped part of its gzip
member.

Set the option when initializing or resetting with options, not mid-member.
Rsyncable mode rejects adaptive block sizing, low-entropy block expansion and
lookahead. Input slicing and output backpressure do not select cuts, and a
member reset restarts the fingerprint. Automatic boundaries do not require
callers to withdraw unconsumed input. The unmodified fixed-block policy remains
the default. This mode does not claim GNU gzip's exact byte output or a
particular compressed-size cost on other inputs.

## Command line

```sh
vort encode-gzip-best-file input.bin output.gz --rsyncable
vort encode-gzip-best-file input.bin output.gz fast --rsyncable
```

The flag can appear before or after the optional level or strategy. It selects
bounded-memory incremental encoding, with no whole-file size cap; the output
path is replaced only after the gzip member finishes successfully. The flag
also works with [standard-stream endpoints](gzip-stdio-cli.md#encoding). With
two named paths and no `--rsyncable`, the original one-shot path and its
128 MiB input limit still apply.

## Verification

```sh
zig build run-gzip-rsyncable-diff -- \
  "$HOME/Work/corpora/silesia-20261025/files/nci"
```

The gate compares the plain incremental library path with the rsyncable CLI
at the same default compression level. It also checks that different buffer
sizes in the CLI and library probe produce the same rsyncable basis bytes.
GNU gzip 1.10 decodes every wire, and local rsync 3.2.7
(`-I --no-whole-file --stats`) reconstructs each edited gzip byte-for-byte.

The reference source is the first 4 MiB of Silesia `nci` (SHA-256
`2c98cbb056dfda7d28ef56c612e48a0ae11fb8cf5d23a6918d35c78db1573134`).
Each edit starts at byte 4096: insert `VORT_RSYNCPROBE`, replace the same
number of bytes with that marker, or delete the same number of bytes.

| Edit | Plain gzip bytes | Rsyncable gzip bytes | Plain rsync literal bytes | Rsyncable rsync literal bytes |
| --- | ---: | ---: | ---: | ---: |
| Insertion | 446,980 | 550,376 | 430,880 | 2,792 |
| Replacement | 447,015 | 550,374 | 447,015 | 2,790 |
| Deletion | 447,016 | 550,357 | 430,216 | 2,773 |

On this fixture the edited gzip grows by about 23.1%, while rsync literal bytes
fall by factors of about 154–160. The gate requires at least a fivefold reduction
on all three rows for this fingerprint. As a separate reference point on the
same edits, GNU gzip `-n -6 -c --rsyncable` emits 434,579–434,623 bytes and
requires 3,383–4,823 literal bytes. Vort sends fewer literals here but writes
a larger file. These are fixture-specific size and reuse counts, not throughput
measurements.

The same gate accepts multiple input paths and repeatable `--offset` values.
`--gnu` adds both GNU gzip encodings; `--report-only` disables the reuse floor
without disabling independent decode, byte-for-byte reconstruction, or rsync
byte accounting. See the [cross-corpus receipt](../performance/gzip-rsyncable-edits-20261125/README.md)
for reproduction and the measured limits of reuse on other inputs.

The wide decode gate also executes the encoder contracts: byte-for-byte
partition and reset determinism, independent suffix recovery, unchanged
default behavior, unsupported option rejection before a gzip header is
written, and retry with unused input after a pending large block.
