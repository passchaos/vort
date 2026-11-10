//! Preserve original physical run boundaries before output can overwrite source.
const std = @import("std");

fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const first = @intFromPtr(a.ptr);
    const second = @intFromPtr(b.ptr);
    return if (first <= second) second - first < a.len else first - second < b.len;
}

pub const Original = struct {
    chunks: []const []const u8,
    index: usize = 0,
    const Chunk = struct { bytes: []const u8, next_index: usize };
    fn peek(self: *const Original) ?Chunk {
        var index = self.index;
        while (index < self.chunks.len) : (index += 1) {
            if (self.chunks[index].len != 0) return .{ .bytes = self.chunks[index], .next_index = index + 1 };
        }
        return null;
    }
    pub fn next(self: *Original) ?[]const u8 {
        const first = self.peek() orelse return null;
        self.index = first.next_index;
        var length = first.bytes.len;
        while (self.peek()) |candidate| {
            const address = std.math.add(usize, @intFromPtr(first.bytes.ptr), length) catch break;
            if (@intFromPtr(candidate.bytes.ptr) != address) break;
            length = std.math.add(usize, length, candidate.bytes.len) catch break;
            self.index = candidate.next_index;
        }
        return first.bytes.ptr[0..length];
    }
};

const Run = struct { bytes: []const u8 = &.{}, owned: bool = false };

pub const Prepared = struct {
    original: Original,
    runs: ?[]Run = null,
    index: usize = 0,

    /// No-alias calls retain the original zero-copy iterator and allocate no
    /// extra heap. Descriptor-only overlap still captures every run before any
    /// output write; each affected full original run gets its own owned copy.
    pub fn init(allocator: std.mem.Allocator, chunks: []const []const u8, output_allocation: []const u8) std.mem.Allocator.Error!Prepared {
        var prepared: Prepared = .{ .original = .{ .chunks = chunks } };
        var alias = overlaps(std.mem.sliceAsBytes(chunks), output_allocation);
        if (!alias) {
            for (chunks) |chunk| {
                if (overlaps(chunk, output_allocation)) {
                    alias = true;
                    break;
                }
            }
        }
        if (!alias) return prepared;
        var count: usize = 0;
        var original = prepared.original;
        while (original.next() != null) count += 1;
        const runs = try allocator.alloc(Run, count);
        for (runs) |*run| run.* = .{};
        prepared.runs = runs;
        errdefer prepared.deinit(allocator);
        original = prepared.original;
        var index: usize = 0;
        while (original.next()) |bytes| : (index += 1) {
            if (overlaps(bytes, output_allocation)) {
                runs[index] = .{ .bytes = try allocator.dupe(u8, bytes), .owned = true };
            } else runs[index] = .{ .bytes = bytes };
        }
        return prepared;
    }
    pub fn next(self: *Prepared) ?[]const u8 {
        if (self.runs) |runs| {
            if (self.index == runs.len) return null;
            const bytes = runs[self.index].bytes;
            self.index += 1;
            // Copies can be adjacent even when their original runs were not.
            // Captured boundaries are authoritative, never the new addresses.
            return bytes;
        }
        return self.original.next();
    }
    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        if (self.runs) |runs| {
            var index = runs.len;
            while (index != 0) {
                index -= 1;
                if (runs[index].owned) allocator.free(@constCast(runs[index].bytes));
            }
            allocator.free(runs);
        }
        self.* = undefined;
    }
};
