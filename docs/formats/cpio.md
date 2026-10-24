# CPIO archive support

Vort provides a dependency-free pure Zig CPIO reader and deterministic writer.
It covers the header families still encountered in Unix backups, package
payloads, firmware images, and Linux initramfs files:

- SVR4 `newc` (`070701`);
- SVR4 CRC (`070702`), with unsigned byte-sum validation;
- POSIX old ASCII/ODC (`070707`);
- old binary in both little- and big-endian byte order.

The parser handles each format's actual alignment rules: `newc` and CRC names
and data are aligned to four bytes, old binary names and data are aligned to
two bytes, and ODC has no padding. Binary 32-bit values use the historical
high-word-first pair of archive-endian 16-bit words.

## Library API

`parseCpioArchive` returns borrowed entry metadata including file kind, mode,
inode, ownership, link count, timestamp, device numbers, stored size, checksum,
header/data offsets, and path-safety classification. Regular-file data and
symbolic-link targets can be extracted into caller-owned buffers or through
bounded allocation APIs.

`CpioIncrementalReader` parses the same five formats from arbitrarily
fragmented caller input and streams each stored payload directly into caller
output. It emits explicit `entry_header` and `entry_done` events, retains only
the fixed header and current pathname, reports exact input/output progress,
validates name/data alignment plus CRC byte sums, and requires the physical EOF
to be confirmed with `finish()` after `TRAILER!!!`. Post-trailer record padding
is accepted only when every byte is zero. Format changes inside one archive,
missing trailers and truncated fields/data are rejected.

Reader options independently bound retained control/path bytes, entry count,
per-entry output, total output, and consumed archive bytes. `reset()` reuses
the retained pathname allocation across independent archives. Streaming emits
the stored payload attached to each physical member; unlike the seekable
one-shot facade, it does not look ahead to replay a later hard-link payload for
an earlier zero-sized member. Inode, device and link-count metadata are exposed
so callers can reconstruct such groups without hidden buffering.

For concatenated raw CPIO and initramfs-style layouts,
`CpioIncrementalSequenceReader` enables the raw reader's default-off
`stop_after_trailer` mode and returns an `archive_done` event without consuming
the following bytes. It accepts leading, inter-archive, and trailing zero
padding; each completed archive reports its index, format, global byte offset,
wire size, entry count, and output size. Archive count, aggregate padding,
total input, total output, and each underlying archive remain independently
bounded. Adjacent archives may use different newc/CRC/ODC/binary formats.

`CpioIncrementalMixedReader` extends those boundaries across raw CPIO plus
gzip, Bzip2, Brotli, LZMA-Alone, XZ, modern LZ4, Zstandard, EOF-marked LZF,
lzip, and LZOP, as well as externally bounded Unix compress and legacy LZ4. It
tracks physical caller input separately from logical member consumption,
copies bounded decoder lookahead into a replay queue at `archive_done`, and
feeds that suffix into the next 14-byte format probe before requesting new
caller bytes. Per-member format, global offset, encoded size, entry/output
counts, recovered-suffix size, and any declared size are exposed. Before the
reader starts a non-padding member, `setNextMemberInputSize` can declare its
exact encoded size, excluding inter-member zero padding. The auto reader then
leaves later caller bytes unconsumed, treats the declared boundary as physical
EOF, and verifies that a self-delimiting decoder did not finish early. The
declaration is required for legacy LZ4 and Unix compress because neither wire
format has an end marker; it is optional but enforceable for every other
format. It remains valid when physical input has ended but bounded replay
still contains later members. Direct `CpioIncrementalAutoReader` users can set
the same pristine-member contract with `setMemberInputSize`.

`encodeCpioAlloc`, `encodeCpioAppend`, and `encodeCpioInto` write any of the
five exposed variants (`newc`, `crc`, `odc`, `binary_little`, or
`binary_big`). Writers support regular files, directories, symbolic links,
block/character devices, FIFOs, and sockets. Output is deterministic and by
default padded to a conventional 512-byte record boundary; callers may select
a different record size or disable final record padding.

`CpioIncrementalWriter` provides the same five formats without retaining entry
payloads or already-emitted archive bytes. `beginEntry` copies the header and
pathname into a bounded control buffer; `step` then copies caller input
directly to caller output with exact progress accounting. `finishEntry` emits
format alignment, and `finishArchive` emits `TRAILER!!!` plus the configured
record padding. The surface reports `entry_done`, applies output backpressure,
and limits entry count, control bytes, per-entry bytes, total input, and total
archive output. Explicit inode/link-count fields also allow callers to describe
hard-link groups.

Every CPIO header carries its data size before the payload, so incremental
entries require a known `size`. SVR4 CRC additionally carries the byte sum in
that header: non-empty CRC entries therefore provide `checksum` to
`beginEntry`, and the writer recomputes and verifies it while streaming. The
historical zero-checksum GNU symlink convention remains accepted.

The parser requires:

- valid fixed-width hexadecimal, octal, or binary fields;
- a nonempty NUL-terminated pathname with no embedded NUL;
- checked header, name, data, and alignment extents;
- zero alignment and post-trailer padding;
- a zero-sized `TRAILER!!!` record;
- zero data sizes for directories and special files;
- CRC byte-sum equality when extracting CRC-format data.

GNU cpio writes a zero CRC for symbolic-link target bytes. Vort accepts this
historical convention and verifies nonzero symlink checksums. Unsafe archived
paths remain visible as metadata with `safe_path = false`; the deterministic
writer rejects absolute, empty-component, dot, parent, NUL-containing, and
reserved trailer names. The library and example CLI never choose an output
filesystem path from archive metadata.

Hard-link inode/link-count metadata is preserved. For newc/CRC archives that
store data only on the final member of an inode group, bounded extraction
resolves earlier zero-sized members to that payload; genuinely empty hard-link
groups remain empty. Device creation and ownership restoration are
intentionally outside the library's byte-extraction API.

## Compressed CPIO

The same public facade supports automatic bounded composition with all existing
Vort stream codecs:

- gzip, Bzip2, Brotli, Unix `compress`, and LZMA-Alone;
- XZ, LZ4 frame, lzip, LZF `ZV`, Zstandard, and LZOP.

`encodeCompressedCpioAlloc` builds the selected CPIO header format before
compression. `decodeAutoCpioAlloc` detects or bounded-probes the wrapper,
returns the owned decompressed bytes, and parses them with the ordinary CPIO
reader. This keeps container semantics in the CPIO modules and compression in
the existing public codec implementations.

Bounded streaming composition is also available in both directions for gzip,
Bzip2, Brotli, Unix `compress`, LZMA-Alone, XZ, modern and legacy LZ4, lzip,
LZF `ZV`, Zstandard, and LZOP. The named
`Cpio*IncrementalReader` types connect each incremental decoder to the raw CPIO
reader through one caller-sized decoded bridge. They retain the raw entry
events and metadata, require compressed EOF through `finish()`, and enforce
separate decoded-stream and CPIO limits. `Cpio*IncrementalWriter` types connect
the raw writer to the corresponding encoder through a caller-sized raw bridge,
delay `entry_done` until the encoder has consumed the whole CPIO member, and
bound total compressed output.

For member-oriented containers, explicit compressed readers expose
`trailingInput()`: bytes accepted into decoder lookahead but proven to follow a
configured first-stream boundary. Gzip can instead leave suffix bytes directly
unconsumed with `allow_trailing_data`; Bzip2, LZMA-Alone, XZ and Zstandard use
their first-stream/end-marker options and borrowed trailing windows. The
reported cumulative `input_read` remains physical accepted input, while
`input_read - trailingInput().len` is the exact logical member boundary. A
decoder that reaches `.done` while still publishing output now retains that
terminal state until the CPIO bridge drains, rather than re-entering the codec.
LZF with an explicit EOF marker, lzip, and LZOP also expose default-off
first-stream stops that leave following caller bytes unconsumed.

All codec lifecycle adapters live in the shared `archive_stream` layer used by
both TAR and CPIO; container state and wire policy remain in their respective
modules. The CPIO raw-format option therefore composes independently with all
twelve outer codecs. CRC entries still declare their byte sum before
`beginEntry`, exactly as on the raw incremental writer.

`CpioIncrementalAutoReader` adds bounded dispatch over those explicit reader
types. Old-binary and ASCII CPIO magics activate raw parsing after only two or
six bytes; signed wrappers activate as soon as their complete magic is
available. A fixed 14-byte maximum probe validates the LZMA-Alone property,
supported dictionary range, optional content size, and the range coder's
required zero initialization byte. Remaining no-magic input defaults to
Brotli, while `ambiguous_fallback` can reject it or route it to raw CPIO for
applications with different framing knowledge. LZ4/Zstandard
skippable frames are discarded incrementally under frame-count and total-input
limits before probing the following data frame. The detected format, skipped
frame accounting, active entry metadata, exact progress, decoded limit and all
underlying codec/container limits remain observable.

## CLI

```sh
zig build run -- create-cpio-file output.cpio payload.bin input.bin newc none
zig build run -- create-cpio-file output.cpio.xz payload.bin input.bin newc xz
zig build run -- list-cpio-file output.cpio.xz
zig build run -- extract-cpio-file output.cpio.xz payload.bin decoded.bin 1048576
```

The header argument is `newc`, `crc`, `odc`, `bin`, or `bin-be`. The optional
compression argument is `none`, `gzip`, `bzip2`, `brotli`, `compress-z`,
`lzma`, `xz`, `lz4`, `lzip`, `lzf`, `zstd`, or `lzop`.

## Differential validation

`tools/cpio/diff.py` verifies all five Vort writers with GNU cpio, requires the
one-byte and micro-buffer incremental writer schedules to be byte-identical to
the one-shot writer for every format, and runs the incremental reader over
both schedules for all five Vort formats plus all four formats GNU cpio can
create on the host. It also checks directory and symlink metadata, exercises
all twelve wrapper choices, and rejects corrupt CRC data, truncated headers,
and nonzero bytes after the trailer:

The same gate runs one-byte and micro-buffer incremental compressed readers and
writers for all twelve outer codecs, including legacy LZ4. Independent Python/
system encoders currently provide eight reader directions, while independent
decoders validate nine writer directions on the development host; unavailable
`compress`, lzip, LZF, or LZOP tools are reported through the counters rather
than silently claimed.

Automatic incremental dispatch covers five raw header archives, all twelve
one-shot raw/wrapper choices plus legacy LZ4, and the same eight independently
encoded wrapper directions (`incremental_auto_reader_cases=18`,
`incremental_auto_reader_external=8`).

The sequence differential concatenates all five Vort formats and all four
GNU-produced formats with varying zero padding under one-byte and micro
schedules (`incremental_sequence_reader_cases=2`,
`incremental_sequence_reader_external=1`).

Mixed-member unit validation concatenates raw CPIO plus twelve compressed
formats, including explicitly sized Vort Unix-compress and legacy-LZ4 output,
under one-byte and 64 KiB schedules with limit, boundary-error, and exhaustive
OOM coverage. The differential concatenates Vort raw/gzip/Bzip2/Brotli/
Unix-compress/LZMA/XZ/modern+legacy-LZ4/Zstd/lzip/LZOP output and an
independently encoded available subset under one-byte and micro schedules
(`incremental_mixed_reader_cases=2`,
`incremental_mixed_reader_external=1`).

```sh
python3 tools/cpio/diff.py --cli path/to/vort --cpio /usr/bin/cpio
zig build run-cpio-diff -- --cpio /usr/bin/cpio
```

Future functionality can add one-shot hard-link writer controls, HP-UX
device-number variants, and afio's extended ODC header without changing the
current entry or compression APIs.
