//! Operation-owned input/dictionary snapshots for direct full append. Slice
//! descriptors and the parsed dictionary view are automatic storage; copied
//! backing bytes use the operation allocator and remain charged until decode.
const std = @import("std");
const shared = @import("../shared_dictionary.zig");
const serialized = @import("../serialized_dictionary.zig");
pub const Error = std.mem.Allocator.Error || error{ IntegerOverflow, CorruptFrame };

pub const Protected = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    input_storage: ?[]u8 = null,
    raw: [shared.max_raw_prefixes][]const u8 = undefined,
    raw_len: usize = 0,
    raw_storage: ?[]u8 = null,
    serialized_view: ?serialized.Dictionary = null,
    serialized_storage: ?[]u8 = null,

    pub fn dictionary(self: *const Protected) shared.Dictionary {
        return .{
            .raw_prefixes = self.raw[0..self.raw_len],
            .serialized = if (self.serialized_view) |*view| view else null,
        };
    }

    pub fn deinit(self: *Protected) void {
        if (self.serialized_storage) |bytes| self.allocator.free(bytes);
        if (self.raw_storage) |bytes| self.allocator.free(bytes);
        if (self.input_storage) |bytes| self.allocator.free(bytes);
        self.* = undefined;
    }
};

/// Dispatch only aliased legacy calls through protection; ordinary default
/// append retains its established decoder path and allocator lifecycle.
pub fn needed(allocation: []const u8, source: []const u8, dictionary: shared.Dictionary) bool {
    if (overlaps(allocation, source)) return true;
    // Let the ordinary format validator reject invalid descriptor counts.
    if (dictionary.raw_prefixes.len > shared.max_raw_prefixes) return false;
    if (overlaps(allocation, std.mem.sliceAsBytes(dictionary.raw_prefixes))) return true;
    for (dictionary.raw_prefixes) |prefix| if (overlaps(allocation, prefix)) return true;
    if (dictionary.serialized) |view| {
        if (overlaps(allocation, std.mem.asBytes(view)) or overlaps(allocation, view.encoded)) return true;
    }
    return false;
}

pub fn protect(allocator: std.mem.Allocator, allocation: []const u8, source: []const u8, dictionary: shared.Dictionary) Error!Protected {
    var result: Protected = .{ .allocator = allocator, .source = source, .raw_len = dictionary.raw_prefixes.len };
    errdefer result.deinit();
    std.debug.assert(result.raw_len <= result.raw.len);
    @memcpy(result.raw[0..result.raw_len], dictionary.raw_prefixes);
    if (overlaps(allocation, source)) {
        result.input_storage = try allocator.dupe(u8, source);
        result.source = result.input_storage.?;
    }
    var raw_bytes: usize = 0;
    for (result.raw[0..result.raw_len]) |prefix| {
        if (overlaps(allocation, prefix)) raw_bytes = std.math.add(usize, raw_bytes, prefix.len) catch return error.IntegerOverflow;
    }
    if (raw_bytes != 0) {
        result.raw_storage = try allocator.alloc(u8, raw_bytes);
        var offset: usize = 0;
        for (result.raw[0..result.raw_len]) |*prefix| {
            if (!overlaps(allocation, prefix.*)) continue;
            const copy = result.raw_storage.?[offset..][0..prefix.len];
            @memcpy(copy, prefix.*);
            prefix.* = copy;
            offset += copy.len;
        }
    }
    if (dictionary.serialized) |view| {
        result.serialized_view = view.*;
        if (overlaps(allocation, view.encoded)) {
            result.serialized_storage = try allocator.dupe(u8, view.encoded);
            result.serialized_view = serialized.parse(result.serialized_storage.?) catch |err| switch (err) {
                error.IntegerOverflow => return error.IntegerOverflow,
                else => return error.CorruptFrame,
            };
        }
    }
    return result;
}

/// Compare half-open ranges without adding lengths to addresses.
pub fn overlaps(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const l = @intFromPtr(left.ptr);
    const r = @intFromPtr(right.ptr);
    return if (l <= r) r - l < left.len else l - r < right.len;
}
