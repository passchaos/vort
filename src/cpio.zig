const archive = @import("cpio/archive.zig");
const compressed = @import("cpio/compressed.zig");
const incremental_writer = @import("cpio/incremental_writer.zig");
const incremental_writer_tests = @import("cpio/incremental_writer_tests.zig");
const writer = @import("cpio/writer.zig");

pub const Error = archive.Error || writer.Error || compressed.Error || incremental_writer.Error;
pub const Format = archive.Format;
pub const Kind = archive.Kind;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const byteSum = archive.byteSum;
pub const isSafePath = archive.isSafePath;
pub const Compression = compressed.Compression;
pub const CompressedEncodeOptions = compressed.EncodeOptions;
pub const OwnedArchive = compressed.OwnedArchive;
pub const detectCompression = compressed.detect;
pub const encodeCompressedAlloc = compressed.encodeAlloc;
pub const encodeCompressedAppend = compressed.encodeAppend;
pub const decodeCompressedAlloc = compressed.decodeAlloc;
pub const decodeAutoAlloc = compressed.decodeAutoAlloc;
pub const IncrementalWriter = incremental_writer.Writer;
pub const IncrementalWriterOptions = incremental_writer.Options;
pub const IncrementalWriterEntryOptions = incremental_writer.EntryOptions;
pub const IncrementalWriterPhase = incremental_writer.Phase;
pub const IncrementalWriterStatus = incremental_writer.Status;
pub const IncrementalWriterStepResult = incremental_writer.StepResult;

test {
    _ = archive;
    _ = compressed;
    _ = incremental_writer;
    _ = incremental_writer_tests;
    _ = writer;
}
