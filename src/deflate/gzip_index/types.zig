const std = @import("std");
const core = @import("../../core.zig");
const source = @import("../../io/source.zig");
const restart = @import("../incremental/block_restart.zig");
const overlaps = @import("../decoder/output_alias.zig").overlaps;

pub const Count = core.StreamCount;
pub const Error = core.Error || source.Error;
pub const Source = source.Source;

pub const Workspace = struct {
    history: []u8,
    input_page: []u8,
    discard: []u8,

    pub fn validate(self: Workspace, window_size: usize) Error!void {
        if (self.history.len < window_size or self.input_page.len == 0 or self.discard.len == 0)
            return error.OutputTooSmall;
    }
};

pub const Options = struct {
    /// Minimum plaintext distance between checkpoints in one member.
    checkpoint_spacing: Count = 1 << 20,
    max_output_len: Count = std.math.maxInt(Count),
    max_members: Count = std.math.maxInt(Count),
    max_header_metadata_len: usize = 1 << 20,
    /// Accept an all-zero suffix after at least one validated member.
    /// Padding does not contribute to any member's indexed extent.
    allow_trailing_zero_padding: bool = false,
};

pub const Entry = struct {
    boundary: union(enum) {
        member: struct { compressed_offset: Count, decoded_offset: Count },
        block: restart.Point,
    },
    /// Byte after the member's validated gzip footer.
    compressed_end: Count,
    decoded_end: Count,

    pub fn compressedOffset(self: Entry) Count {
        return switch (self.boundary) {
            .member => |start| start.compressed_offset,
            .block => |point| point.position.compressed_byte_offset,
        };
    }

    pub fn decodedOffset(self: Entry) Count {
        return switch (self.boundary) {
            .member => |start| start.decoded_offset,
            .block => |point| point.position.decoded_offset,
        };
    }
};

pub const Progress = struct {
    output_written: usize = 0,
    next_decoded_offset: Count,
};

pub const Outcome = union(enum) {
    complete: Progress,
    failed: struct { err: Error, progress: Progress },
};

pub fn rangeEnd(decoded_size: Count, offset: Count, length: usize) Error!Count {
    if (offset > decoded_size or length > decoded_size - offset) return error.RangeOutOfBounds;
    return core.stream_count.addLocal(offset, length);
}

pub fn entryBytes(entries: []const Entry) Error![]const u8 {
    const len = std.math.mul(usize, entries.len, @sizeOf(Entry)) catch return error.IntegerOverflow;
    return @as([*]const u8, @ptrCast(entries.ptr))[0..len];
}

pub fn validateDisjoint(regions: []const []const u8) Error!void {
    for (regions, 0..) |left, i| {
        for (regions[i + 1 ..]) |right| {
            if (overlaps(left, right)) return error.InvalidBlockPlan;
        }
    }
}
