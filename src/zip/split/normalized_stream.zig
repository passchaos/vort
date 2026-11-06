//! Sparse single-disk view over explicitly ordered split ZIP parts.
//!
//! The stream owns only copied slice descriptors, disk bases, and small
//! metadata patches. Archive payload bytes remain borrowed from the caller.

const std = @import("std");
const source_module = @import("source.zig");
const plan_module = @import("plan.zig");
const Count = source_module.Count;
const count = source_module.count;
const Source = source_module.Source;
const Patch = plan_module.Patch;
const buildPlan = plan_module.buildPlan;
const InitError = plan_module.InitError;
pub const Error = source_module.Error;
pub const PartSource = source_module.PartSource;
pub const Options = plan_module.Options;

/// Borrowed multi-slice ZIP bytes exposed as a logically normalized single-
/// disk byte stream. The caller-owned part payloads must outlive this value;
/// the outer slice descriptor array is copied during initialization.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    bases: []Count,
    patches: std.ArrayList(Patch),
    total_len: Count,
    first_record_offset: Count,

    const Self = @This();

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        ordered_parts: []const []const u8,
        options: Options,
    ) InitError!Self {
        const parts = try allocator.alloc([]const u8, ordered_parts.len);
        errdefer allocator.free(parts);
        @memcpy(parts, ordered_parts);
        var plan = try buildPlan(allocator, .{ .slices = parts }, options);
        errdefer plan.deinit(allocator);
        return .{
            .allocator = allocator,
            .parts = parts,
            .bases = plan.bases,
            .patches = plan.patches,
            .total_len = plan.total_len,
            .first_record_offset = plan.first_record_offset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patches.deinit(self.allocator);
        self.allocator.free(self.bases);
        self.allocator.free(self.parts);
        self.* = undefined;
    }

    pub fn len(self: *const Self) Count {
        return self.total_len;
    }

    pub fn firstRecordOffset(self: *const Self) Count {
        return self.first_record_offset;
    }

    pub fn patchCount(self: *const Self) usize {
        return self.patches.items.len;
    }

    /// Reads normalized bytes at an absolute virtual archive offset.
    pub fn readAt(self: *const Self, offset: Count, output: []u8) Error!usize {
        const source: Source = .{
            .backing = .{ .slices = self.parts },
            .bases = self.bases,
            .total_len = self.total_len,
        };
        return readNormalized(source, self.patches.items, offset, output);
    }
};

/// Sparse normalized stream backed by caller-defined on-demand part reads.
/// The callback context and the underlying parts must outlive this value; the
/// part-length descriptor array is copied during initialization.
pub const SourceStream = struct {
    allocator: std.mem.Allocator,
    source: PartSource,
    part_lengths: []Count,
    bases: []Count,
    patches: std.ArrayList(Patch),
    total_len: Count,
    first_record_offset: Count,

    const Self = @This();

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        source_value: PartSource,
        options: Options,
    ) InitError!Self {
        const part_lengths = try allocator.dupe(Count, source_value.part_lengths);
        errdefer allocator.free(part_lengths);
        var source = source_value;
        source.part_lengths = part_lengths;
        var plan = try buildPlan(allocator, .{ .callback = source }, options);
        errdefer plan.deinit(allocator);
        return .{
            .allocator = allocator,
            .source = source,
            .part_lengths = part_lengths,
            .bases = plan.bases,
            .patches = plan.patches,
            .total_len = plan.total_len,
            .first_record_offset = plan.first_record_offset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patches.deinit(self.allocator);
        self.allocator.free(self.bases);
        self.allocator.free(self.part_lengths);
        self.* = undefined;
    }

    pub fn len(self: *const Self) Count {
        return self.total_len;
    }

    pub fn firstRecordOffset(self: *const Self) Count {
        return self.first_record_offset;
    }

    pub fn patchCount(self: *const Self) usize {
        return self.patches.items.len;
    }

    pub fn readAt(self: *const Self, offset: Count, output: []u8) Error!usize {
        const source: Source = .{
            .backing = .{ .callback = self.source },
            .bases = self.bases,
            .total_len = self.total_len,
        };
        return readNormalized(source, self.patches.items, offset, output);
    }
};

fn firstPatchEndingAfter(patches: []const Patch, offset: Count) usize {
    var low: usize = 0;
    var high = patches.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const metadata_patch = patches[middle];
        if ((metadata_patch.end() catch unreachable) <= offset)
            low = middle + 1
        else
            high = middle;
    }
    return low;
}

fn readNormalized(source: Source, patches: []const Patch, offset: Count, output: []u8) Error!usize {
    if (offset > source.total_len) return error.RangeOutOfBounds;
    const written = count.bounded(source.total_len - offset, output.len);
    if (written == 0) return 0;
    try source.copyExact(offset, output[0..written]);
    const read_end = try count.addLocal(offset, written);
    const first_patch = firstPatchEndingAfter(patches, offset);
    for (patches[first_patch..]) |metadata_patch| {
        const patch_end = try metadata_patch.end();
        if (metadata_patch.offset >= read_end) break;
        const overlap_start = @max(offset, metadata_patch.offset);
        const overlap_end = @min(read_end, patch_end);
        // The overlap is bounded by a local read buffer and an eight-byte
        // metadata patch. Narrow only these bounded differences.
        const source_start: usize = @intCast(overlap_start - metadata_patch.offset);
        const target_start: usize = @intCast(overlap_start - offset);
        const overlap_len: usize = @intCast(overlap_end - overlap_start);
        @memcpy(
            output[target_start..][0..overlap_len],
            metadata_patch.bytes[source_start..][0..overlap_len],
        );
    }
    return written;
}

test {
    _ = @import("wide_normalized_tests.zig");
}
