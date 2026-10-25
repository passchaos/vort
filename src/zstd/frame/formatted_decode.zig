const std = @import("std");

/// Publication helpers receive the codec's full size and entropy decoders.
/// Only decoded bytes are staged: compressed frames and dictionaries remain
/// borrowed, which also makes input/output aliasing safe during publication.
pub fn owned(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, options: Codec.Options) Codec.Error![]u8 {
    const size = try Codec.size(frame, options);
    return ownedSized(Codec, allocator, frame, options, size);
}

fn ownedSized(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, options: Codec.Options, size: usize) Codec.Error![]u8 {
    const decoded = try allocator.alloc(u8, size);
    errdefer allocator.free(decoded);
    const written = try Codec.decode(frame, decoded, options);
    if (written != size) return error.SizeMismatch;
    return decoded;
}

pub fn into(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, output: []u8, options: Codec.Options) Codec.Error!usize {
    const size = try Codec.size(frame, options);
    if (output.len < size) return error.OutputTooSmall;
    const decoded = try ownedSized(Codec, allocator, frame, options, size);
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn append(comptime Codec: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, options: Codec.Options) Codec.Error!usize {
    const decoded = try owned(Codec, allocator, frame, options);
    defer allocator.free(decoded);
    try out.appendSlice(allocator, decoded);
    return decoded.len;
}
