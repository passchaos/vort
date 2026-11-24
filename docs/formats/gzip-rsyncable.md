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

## Verification

```sh
zig build -Doptimize=ReleaseFast run-gzip-rsyncable-diff -- \
  "$HOME/Work/corpora/silesia-20261025/files/nci"
```

The gate compares Vort's plain and rsyncable incremental encodes of the first
4 MiB of `nci`, before and after inserting `VORT_RSYNCPROBE` at byte 4096. GNU
gzip 1.10 independently decodes every wire. Local rsync 3.2.7
(`-I --no-whole-file --stats`) reconstructs the edited gzip file byte-for-byte.
On this fixture the edited wire grows from 446,980 to 550,376 bytes (+23.1%),
while literal bytes transferred fall from 430,880 to 2,792. These are
workflow-specific wire and reuse counts, not a throughput comparison.

The wide decode gate also executes the encoder contracts: byte-for-byte
partition and reset determinism, independent suffix recovery, unchanged
default behavior, unsupported option rejection before a gzip header is
written, and retry with unused input after a pending large block.
