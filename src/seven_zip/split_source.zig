//! Ordered byte-concatenation source for standard split 7z volumes.
//!
//! 7-Zip volumes are physical slices of one logical archive; internal offsets
//! remain absolute in the concatenated byte stream. These adapters own only
//! copied descriptors and prefix bases. Payload bytes and callback contexts are
//! borrowed from the caller.

const std = @import("std");
const source_mod = @import("source.zig");

pub const Error = source_mod.Error || error{
    Invalid7zVolumeSet,
    OutputLimitExceeded,
    IntegerOverflow,
    PartSourceReadFailed,
};

pub const Options = struct {
    max_archive_size: u64 = std.math.maxInt(u64),
    max_parts: usize = std.math.maxInt(u32),
    require_uniform_part_size: bool = true,
};

pub const PartSource = struct {
    context: *anyopaque,
    part_lengths: []const u64,
    read_at: *const fn (
        context: *anyopaque,
        part_index: usize,
        offset: u64,
        output: []u8,
    ) error{PartSourceReadFailed}!usize,
};

const Layout = struct {
    bases: []u64,
    total_len: u64,
};

fn buildLayout(
    allocator: std.mem.Allocator,
    lengths: []const u64,
    options: Options,
) (Error || std.mem.Allocator.Error)!Layout {
    if (lengths.len < 2) return error.Invalid7zVolumeSet;
    if (lengths.len > options.max_parts) return error.OutputLimitExceeded;
    const bases = try allocator.alloc(u64, lengths.len);
    errdefer allocator.free(bases);
    const standard_len = lengths[0];
    if (standard_len == 0) return error.Invalid7zVolumeSet;
    var total: u64 = 0;
    for (lengths, bases, 0..) |part_len, *base, index| {
        if (part_len == 0) return error.Invalid7zVolumeSet;
        if (options.require_uniform_part_size) {
            if (index + 1 < lengths.len and part_len != standard_len)
                return error.Invalid7zVolumeSet;
            if (index + 1 == lengths.len and part_len > standard_len)
                return error.Invalid7zVolumeSet;
        }
        base.* = total;
        total = std.math.add(u64, total, part_len) catch return error.IntegerOverflow;
        if (total > options.max_archive_size) return error.OutputLimitExceeded;
    }
    return .{ .bases = bases, .total_len = total };
}

fn partForOffset(bases: []const u64, offset: u64) usize {
    std.debug.assert(offset >= bases[0]);
    var low: usize = 0;
    var high = bases.len;
    while (low + 1 < high) {
        const middle = low + (high - low) / 2;
        if (bases[middle] <= offset)
            low = middle
        else
            high = middle;
    }
    return low;
}

pub const SliceStream = struct {
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    bases: []u64,
    total_len: u64,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        ordered_parts: []const []const u8,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!SliceStream {
        const parts = try allocator.dupe([]const u8, ordered_parts);
        errdefer allocator.free(parts);
        const lengths = try allocator.alloc(u64, parts.len);
        defer allocator.free(lengths);
        for (parts, lengths) |part, *length| length.* = part.len;
        const layout = try buildLayout(allocator, lengths, options);
        return .{
            .allocator = allocator,
            .parts = parts,
            .bases = layout.bases,
            .total_len = layout.total_len,
        };
    }

    pub fn deinit(self: *SliceStream) void {
        self.allocator.free(self.parts);
        self.allocator.free(self.bases);
        self.* = undefined;
    }

    pub fn source(self: *SliceStream) source_mod.Source {
        return .{ .context = self, .len = self.total_len, .read_at = readAt };
    }

    pub fn readAt(
        raw_context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *SliceStream = @ptrCast(@alignCast(raw_context));
        if (offset > self.total_len) return error.SourceReadFailed;
        const available_u64 = self.total_len - offset;
        const available = std.math.cast(usize, @min(available_u64, output.len)) orelse
            return error.SourceReadFailed;
        if (available == 0) return 0;
        var part_index = partForOffset(self.bases, offset);
        var absolute = offset;
        var written: usize = 0;
        while (written < available) : (part_index += 1) {
            if (part_index >= self.parts.len) return error.SourceReadFailed;
            const local_u64 = absolute - self.bases[part_index];
            const local = std.math.cast(usize, local_u64) orelse
                return error.SourceReadFailed;
            const take = @min(available - written, self.parts[part_index].len - local);
            if (take == 0) return error.SourceReadFailed;
            @memcpy(output[written..][0..take], self.parts[part_index][local..][0..take]);
            written += take;
            absolute += take;
        }
        return written;
    }
};

pub const SourceStream = struct {
    allocator: std.mem.Allocator,
    part_source: PartSource,
    part_lengths: []u64,
    bases: []u64,
    total_len: u64,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        source_value: PartSource,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!SourceStream {
        const part_lengths = try allocator.dupe(u64, source_value.part_lengths);
        errdefer allocator.free(part_lengths);
        const layout = try buildLayout(allocator, part_lengths, options);
        var part_source = source_value;
        part_source.part_lengths = part_lengths;
        return .{
            .allocator = allocator,
            .part_source = part_source,
            .part_lengths = part_lengths,
            .bases = layout.bases,
            .total_len = layout.total_len,
        };
    }

    pub fn deinit(self: *SourceStream) void {
        self.allocator.free(self.part_lengths);
        self.allocator.free(self.bases);
        self.* = undefined;
    }

    pub fn source(self: *SourceStream) source_mod.Source {
        return .{ .context = self, .len = self.total_len, .read_at = readAt };
    }

    pub fn readAt(
        raw_context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *SourceStream = @ptrCast(@alignCast(raw_context));
        if (offset > self.total_len) return error.SourceReadFailed;
        const available_u64 = self.total_len - offset;
        const available = std.math.cast(usize, @min(available_u64, output.len)) orelse
            return error.SourceReadFailed;
        if (available == 0) return 0;
        var part_index = partForOffset(self.bases, offset);
        var absolute = offset;
        var written: usize = 0;
        while (written < available) : (part_index += 1) {
            if (part_index >= self.part_lengths.len) return error.SourceReadFailed;
            const local = absolute - self.bases[part_index];
            const remaining = self.part_lengths[part_index] - local;
            const take = std.math.cast(usize, @min(remaining, available - written)) orelse
                return error.SourceReadFailed;
            if (take == 0) return error.SourceReadFailed;
            var part_written: usize = 0;
            while (part_written < take) {
                const amount = self.part_source.read_at(
                    self.part_source.context,
                    part_index,
                    local + part_written,
                    output[written + part_written ..][0 .. take - part_written],
                ) catch return error.SourceReadFailed;
                if (amount == 0 or amount > take - part_written)
                    return error.SourceReadFailed;
                part_written += amount;
            }
            written += take;
            absolute += take;
        }
        return written;
    }
};

test "7z split slice and callback streams cross every volume boundary" {
    const bytes = "0123456789abcdefghijklmnopqrstuvwxyz";
    const parts = [_][]const u8{ bytes[0..8], bytes[8..16], bytes[16..24], bytes[24..32], bytes[32..] };
    var slices = try SliceStream.initAlloc(std.testing.allocator, &parts, .{});
    defer slices.deinit();
    var output: [bytes.len]u8 = undefined;
    try slices.source().readExact(0, &output);
    try std.testing.expectEqualSlices(u8, bytes, &output);

    const Context = struct {
        parts: []const []const u8,
        max_chunk: usize,

        fn readAt(
            raw_context: *anyopaque,
            part_index: usize,
            offset: u64,
            destination: []u8,
        ) error{PartSourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw_context));
            if (part_index >= self.parts.len) return error.PartSourceReadFailed;
            const start = std.math.cast(usize, offset) orelse return error.PartSourceReadFailed;
            if (start >= self.parts[part_index].len) return 0;
            const count = @min(
                destination.len,
                @min(self.max_chunk, self.parts[part_index].len - start),
            );
            @memcpy(destination[0..count], self.parts[part_index][start..][0..count]);
            return count;
        }
    };
    const lengths = [_]u64{ 8, 8, 8, 8, 4 };
    var context = Context{ .parts = &parts, .max_chunk = 2 };
    var callback = try SourceStream.initAlloc(std.testing.allocator, .{
        .context = &context,
        .part_lengths = &lengths,
        .read_at = Context.readAt,
    }, .{});
    defer callback.deinit();
    @memset(&output, 0);
    try callback.source().readExact(0, &output);
    try std.testing.expectEqualSlices(u8, bytes, &output);
}

test "7z split source validates geometry limits and allocation failures" {
    const valid = [_][]const u8{ "1234", "5678", "9" };
    try std.testing.expectError(
        error.Invalid7zVolumeSet,
        SliceStream.initAlloc(std.testing.allocator, valid[0..1], .{}),
    );
    const uneven = [_][]const u8{ "1234", "567", "8" };
    try std.testing.expectError(
        error.Invalid7zVolumeSet,
        SliceStream.initAlloc(std.testing.allocator, &uneven, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        SliceStream.initAlloc(std.testing.allocator, &valid, .{ .max_archive_size = 8 }),
    );
    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator, parts: []const []const u8) !void {
            var stream = try SliceStream.initAlloc(allocator, parts, .{});
            stream.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{&valid},
    );

    const Context = struct {
        parts: []const []const u8,

        fn readAt(
            raw_context: *anyopaque,
            part_index: usize,
            offset: u64,
            output: []u8,
        ) error{PartSourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw_context));
            if (part_index >= self.parts.len) return error.PartSourceReadFailed;
            const start = std.math.cast(usize, offset) orelse return error.PartSourceReadFailed;
            if (start >= self.parts[part_index].len) return 0;
            const count = @min(output.len, self.parts[part_index].len - start);
            @memcpy(output[0..count], self.parts[part_index][start..][0..count]);
            return count;
        }
    };
    var context = Context{ .parts = &valid };
    const lengths = [_]u64{ 4, 4, 1 };
    const CallbackFailureTest = struct {
        fn run(allocator: std.mem.Allocator, source: PartSource) !void {
            var stream = try SourceStream.initAlloc(allocator, source, .{});
            stream.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        CallbackFailureTest.run,
        .{PartSource{
            .context = &context,
            .part_lengths = &lengths,
            .read_at = Context.readAt,
        }},
    );
}
