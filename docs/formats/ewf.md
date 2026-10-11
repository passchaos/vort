# EWF1 / EnCase E01 forensic images

Vort reads physical-media EWF1/E01 images and writes deterministic single-file
EnCase-6-style images in pure Zig. Segment discovery is deliberately explicit:
the caller supplies all segment byte slices in segment-number order, so the
library never guesses paths or opens `.E02` files implicitly.

The reader supports:

- the 13-byte EWF1 segment header and checked segment numbering;
- 76-byte section descriptors with absolute next offsets and Adler-32;
- `volume`/`disk`/`data` geometry, `sectors`, `table`, mirrored `table2`,
  `hash`, `next`, and `done` sections while safely skipping bounded unknown
  metadata sections;
- early table-contained chunks and modern sectors-before-table layouts;
- EnCase-6 table base offsets and per-entry compressed flag;
- raw chunks with little-endian Adler-32 and zlib-wrapped compressed chunks,
  including padding bytes retained by real EnCase/libewf tables;
- complete-media MD5 verification on whole-image decode;
- bounded whole-image and random-range decode, touching only overlapping
  chunks.

```zig
var image = try vort.parseEwfSegmentsAlloc(
    allocator,
    &.{ e01_bytes, e02_bytes, e03_bytes },
    .{
        .verify_checksums = true,
        .max_sections_per_segment = 1 << 16,
        .max_chunks = 1 << 24,
        .max_chunk_bytes = 16 * 1024 * 1024,
    },
);
defer image.deinit();

const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The writer emits one E01 segment with volume geometry, one or more
sectors/table/table2 groups, a repeated data record, MD5 hash section, and a
terminal done section. `none` stores each chunk with its Adler-32, `zlib`
compresses every chunk, and `auto` chooses compressed data only when smaller.
Input is rounded up to a 512-byte media sector and the tail is zero-filled.
The default chunk is 64 sectors (32 KiB); table grouping remains bounded for
compatibility with older readers.

```zig
const encoded = try vort.encodeEwfAlloc(allocator, raw_media, .{
    .compression = .auto,
    .sectors_per_chunk = 64,
    .max_table_entries = 16375,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-ewf image.E01 image.E02
zig build run -- decode-ewf image.E01 image.raw 1073741824 image.E02
zig build run -- decode-ewf-range image.E01 range.raw 1048576 65536 image.E02
zig build run -- encode-ewf disk.raw image.E01 auto 64
zig build test-ewf
zig build run-ewf-diff
```

The reader does not claim EWF2/Ex01, bzip2-compressed EWF2 chunks, encryption,
logical-evidence L01 trees, or delta/shadow files. Optional error/session and
acquisition-text sections are bounded and skipped but not yet exposed as typed
metadata. The writer currently emits a single segment; callers needing a size-
limited segment set can use the reader immediately but writer-side segmentation
remains follow-up work.

Pinned fixtures were produced by libewf 20260924. One contains mixed zlib/raw
chunks; another contains four explicitly ordered E01--E04 segments. The
differential has libewf inspect and verify every Vort writer mode, export it
byte-exactly, and generates fresh single- and multi-segment images for Vort to
decode in the reverse direction.
