//! Ordered split/multi-disk ZIP normalization.
//!
//! ZIP offsets are relative to the disk named beside each record. The sparse
//! stream validates those coordinates and overlays only normalized metadata;
//! the compatibility helper materializes that same view for the ordinary
//! borrowed `Archive` parser.

const std = @import("std");
const normalized_stream = @import("split/normalized_stream.zig");

pub const Error = normalized_stream.Error;
pub const Options = normalized_stream.Options;
pub const NormalizedStream = normalized_stream.Stream;
pub const PartSource = normalized_stream.PartSource;
pub const NormalizedSourceStream = normalized_stream.SourceStream;

pub fn normalizeAlloc(
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    options: Options,
) (Error || std.mem.Allocator.Error)![]u8 {
    var stream = try NormalizedStream.initAlloc(allocator, parts, options);
    defer stream.deinit();
    const output = try allocator.alloc(u8, stream.len());
    errdefer allocator.free(output);
    if (try stream.readAt(0, output) != output.len)
        return error.InvalidZipArchive;
    return output;
}
