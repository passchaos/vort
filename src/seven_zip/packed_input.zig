//! Packed-stream access shared by borrowed and random-access 7z archives.

const std = @import("std");
const core = @import("../core.zig");
const source_mod = @import("source.zig");
const streams_mod = @import("streams.zig");

pub const Error = core.Error || source_mod.Error || error{Invalid7zArchive};

const signature_header_size: u64 = 32;

pub const Loaded = struct {
    bytes: []const u8,
    owned: ?[]u8 = null,

    pub fn deinit(self: Loaded, allocator: std.mem.Allocator) void {
        if (self.owned) |bytes| allocator.free(bytes);
    }
};

pub const Input = union(enum) {
    borrowed: Borrowed,
    random: Random,

    const Borrowed = struct {
        bytes: []const u8,
        packed_limit: u64,
        max_packed_stream_size: usize,
    };

    const Random = struct {
        source: source_mod.Source,
        packed_limit: u64,
        max_packed_stream_size: usize,
    };

    pub fn fromBytes(
        bytes: []const u8,
        packed_limit: usize,
        max_packed_stream_size: usize,
    ) Input {
        return .{ .borrowed = .{
            .bytes = bytes,
            .packed_limit = packed_limit,
            .max_packed_stream_size = max_packed_stream_size,
        } };
    }

    pub fn fromSource(
        source: source_mod.Source,
        packed_limit: u64,
        max_packed_stream_size: usize,
    ) Input {
        return .{ .random = .{
            .source = source,
            .packed_limit = packed_limit,
            .max_packed_stream_size = max_packed_stream_size,
        } };
    }

    pub fn withLimit(self: Input, packed_limit: u64) Input {
        return switch (self) {
            .borrowed => |value| .{ .borrowed = .{
                .bytes = value.bytes,
                .packed_limit = packed_limit,
                .max_packed_stream_size = value.max_packed_stream_size,
            } },
            .random => |value| .{ .random = .{
                .source = value.source,
                .packed_limit = packed_limit,
                .max_packed_stream_size = value.max_packed_stream_size,
            } },
        };
    }

    pub fn packedLimit(self: Input) u64 {
        return switch (self) {
            .borrowed => |value| value.packed_limit,
            .random => |value| value.packed_limit,
        };
    }

    pub fn archiveLen(self: Input) u64 {
        return switch (self) {
            .borrowed => |value| value.bytes.len,
            .random => |value| value.source.len,
        };
    }

    pub fn validateStreams(self: Input, streams: *const streams_mod.Streams) Error!void {
        var end = std.math.add(u64, signature_header_size, streams.pack_position) catch
            return error.IntegerOverflow;
        for (streams.pack_sizes) |size|
            end = std.math.add(u64, end, size) catch return error.IntegerOverflow;
        if (end > self.packedLimit() or end > self.archiveLen())
            return error.Invalid7zArchive;
    }

    pub fn load(
        self: Input,
        allocator: std.mem.Allocator,
        streams: *const streams_mod.Streams,
        index: usize,
    ) (Error || std.mem.Allocator.Error)!Loaded {
        const range = try packRange(self, streams, index);
        return switch (self) {
            .borrowed => |value| borrowed: {
                const size = std.math.cast(usize, range.size) orelse
                    return error.OutputLimitExceeded;
                if (size > value.max_packed_stream_size)
                    return error.OutputLimitExceeded;
                const start = std.math.cast(usize, range.start) orelse
                    return error.Invalid7zArchive;
                const end = std.math.cast(usize, range.end) orelse
                    return error.Invalid7zArchive;
                break :borrowed .{ .bytes = value.bytes[start..end] };
            },
            .random => |value| random: {
                const size = std.math.cast(usize, range.size) orelse
                    return error.OutputLimitExceeded;
                if (size > value.max_packed_stream_size)
                    return error.OutputLimitExceeded;
                const bytes = try allocator.alloc(u8, size);
                errdefer allocator.free(bytes);
                try value.source.readExact(range.start, bytes);
                break :random .{ .bytes = bytes, .owned = bytes };
            },
        };
    }
};

pub const Range = struct {
    start: u64,
    size: u64,
    end: u64,
};

pub fn packRange(
    input: Input,
    streams: *const streams_mod.Streams,
    index: usize,
) Error!Range {
    if (index >= streams.pack_sizes.len) return error.Invalid7zArchive;
    var relative = streams.pack_position;
    for (streams.pack_sizes[0..index]) |size|
        relative = std.math.add(u64, relative, size) catch return error.IntegerOverflow;
    const start = std.math.add(u64, signature_header_size, relative) catch
        return error.IntegerOverflow;
    const size = streams.pack_sizes[index];
    const end = std.math.add(u64, start, size) catch return error.IntegerOverflow;
    if (end > input.packedLimit() or end > input.archiveLen())
        return error.Invalid7zArchive;
    return .{ .start = start, .size = size, .end = end };
}
