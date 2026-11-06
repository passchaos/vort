//! Logical coordinates over borrowed split parts or on-demand file reads.
const std = @import("std");
const core = @import("../../core.zig");
const records = @import("../records.zig");
pub const Count = core.StreamCount;
pub const count = core.stream_count;
pub const Error = records.Error || error{
    InvalidZipArchive,
    InvalidZipDiskOrder,
    OutputLimitExceeded,
    IntegerOverflow,
    RangeOutOfBounds,
    PartSourceReadFailed,
};

pub const PartSource = struct {
    context: *anyopaque,
    part_lengths: []const Count,
    read_at: *const fn (
        context: *anyopaque,
        disk: usize,
        offset: Count,
        output: []u8,
    ) error{PartSourceReadFailed}!usize,
};

pub const Backing = union(enum) {
    slices: []const []const u8,
    callback: PartSource,
};

pub const Source = struct {
    backing: Backing,
    bases: []const Count,
    total_len: Count,

    pub fn partCount(self: Source) usize {
        return switch (self.backing) {
            .slices => |parts| parts.len,
            .callback => |source| source.part_lengths.len,
        };
    }

    pub fn partLen(self: Source, disk: usize) Count {
        return switch (self.backing) {
            .slices => |parts| count.fromLocal(parts[disk].len),
            .callback => |source| source.part_lengths[disk],
        };
    }

    pub fn readPartExact(
        self: Source,
        disk: usize,
        offset: Count,
        output: []u8,
    ) Error!void {
        if (disk >= self.partCount()) return error.InvalidZipDiskOrder;
        _ = try checkedEnd(offset, count.fromLocal(output.len), self.partLen(disk));
        return switch (self.backing) {
            .slices => |parts| {
                // A slice-backed part has a physical usize length; only after
                // bounding this part-relative coordinate may it become an index.
                const local: usize = @intCast(offset);
                @memcpy(output, parts[disk][local..][0..output.len]);
            },
            .callback => |source| {
                var written: usize = 0;
                while (written < output.len) {
                    const amount = try source.read_at(
                        source.context,
                        disk,
                        try count.addLocal(offset, written),
                        output[written..],
                    );
                    if (amount == 0 or amount > output.len - written)
                        return error.InvalidZipArchive;
                    written += amount;
                }
            },
        };
    }

    pub fn copyExact(self: Source, offset: Count, output: []u8) Error!void {
        _ = try checkedEnd(offset, count.fromLocal(output.len), self.total_len);
        if (output.len == 0) return;
        var disk = self.diskForOffset(offset);
        var absolute = offset;
        var written: usize = 0;
        while (written < output.len) : (disk += 1) {
            if (disk >= self.partCount()) return error.InvalidZipArchive;
            const local = absolute - self.bases[disk];
            const part_len = self.partLen(disk);
            if (local >= part_len) return error.InvalidZipArchive;
            const take = count.bounded(part_len - local, output.len - written);
            if (take == 0) return error.InvalidZipArchive;
            try self.readPartExact(disk, local, output[written..][0..take]);
            written += take;
            try count.advance(&absolute, take);
        }
    }

    pub fn readInt(self: Source, comptime T: type, offset: Count) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.copyExact(offset, &bytes);
        return std.mem.readInt(T, &bytes, .little);
    }

    pub fn diskOffset(self: Source, disk: usize, offset: Count) Error!Count {
        if (disk >= self.partCount() or offset >= self.partLen(disk))
            return error.InvalidZipDiskOrder;
        return checkedAdd(self.bases[disk], offset);
    }

    pub fn diskForOffset(self: Source, offset: Count) usize {
        std.debug.assert(offset < self.total_len);
        var low: usize = 0;
        var high: usize = self.bases.len;
        while (low + 1 < high) {
            const middle = low + (high - low) / 2;
            if (self.bases[middle] <= offset)
                low = middle
            else
                high = middle;
        }
        return low;
    }
};

pub fn backingPartCount(backing: Backing) usize {
    return switch (backing) {
        .slices => |parts| parts.len,
        .callback => |source| source.part_lengths.len,
    };
}

pub fn backingPartLen(backing: Backing, disk: usize) Count {
    return switch (backing) {
        .slices => |parts| count.fromLocal(parts[disk].len),
        .callback => |source| source.part_lengths[disk],
    };
}

pub fn checkedAdd(a: Count, b: Count) error{IntegerOverflow}!Count {
    return count.add(a, b);
}

pub fn checkedEnd(start: Count, len: Count, limit: Count) Error!Count {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}
