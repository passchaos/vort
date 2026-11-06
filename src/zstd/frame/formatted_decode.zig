const std = @import("std");
const budget = @import("../decode/budget.zig");

/// Publication helpers receive the codec's full size and entropy decoders.
/// Only decoded bytes are staged: compressed frames and dictionaries remain
/// borrowed, which also makes input/output aliasing safe during publication.
pub fn owned(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, options: Codec.Options) Codec.Error![]u8 {
    const size = try Codec.size(frame, options);
    var entry = try budget.Entry.init(allocator, options);
    defer entry.deinit();
    const decoded = ownedSized(Codec, entry.allocator(), frame, entry.forward(options), size) catch |err|
        return @errorCast(entry.mapError(err));
    errdefer entry.allocator().free(decoded);
    try entry.releaseOwned(decoded.len);
    return decoded;
}

/// Allocate a temporary result inside an already established policy scope.
/// Publication and allocation ownership remain with that outer scope.
pub fn ownedSized(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, options: Codec.Options, size: usize) Codec.Error![]u8 {
    const decoded = try allocator.alloc(u8, size);
    errdefer allocator.free(decoded);
    const written = try Codec.decode(frame, decoded, options);
    if (written != size) return error.SizeMismatch;
    return decoded;
}

pub fn into(comptime Codec: type, allocator: std.mem.Allocator, frame: []const u8, output: []u8, options: Codec.Options) Codec.Error!usize {
    const size = try Codec.size(frame, options);
    if (output.len < size) return error.OutputTooSmall;
    var entry = try budget.Entry.init(allocator, options);
    defer entry.deinit();
    const decoded = ownedSized(Codec, entry.allocator(), frame, entry.forward(options), size) catch |err|
        return @errorCast(entry.mapError(err));
    defer entry.allocator().free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn append(comptime Codec: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, options: Codec.Options) Codec.Error!usize {
    const size = try Codec.size(frame, options);
    var entry = try budget.Entry.initExisting(allocator, options, out.capacity);
    defer entry.deinit();
    var publication = try budget.AppendScope.initCharged(entry.lease, allocator, out);
    defer publication.deinit();
    const decoded = ownedSized(Codec, entry.allocator(), frame, entry.forward(options), size) catch |err|
        return @errorCast(entry.mapError(err));
    defer entry.allocator().free(decoded);
    try publication.append(decoded);
    return decoded.len;
}
