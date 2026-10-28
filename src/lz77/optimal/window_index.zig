//! Exact finite-history predecessor and ordinal storage for reverse parsing.
const std = @import("std");
const storage = @import("storage.zig");
const policy = @import("prefix_jumps.zig");

pub const empty = std.math.maxInt(u32);
pub const history = 32768;
pub const lookahead = 258;
pub const table_size = 32768;
pub const default_chunk = 128 * 1024;
pub const minimum_input = 256 * 1024;

pub fn Index(comptime hashAt: anytype) type {
    return struct {
        const Self = @This();
        const Sample = struct { position: u32, previous: u32 = empty };

        input: []const u8,
        chunk: usize,
        first: std.ArrayList(u32) = .empty,
        head: std.ArrayList(u32) = .empty,
        previous: std.ArrayList(u32) = .empty,
        raw_ranks: std.ArrayList(u16) = .empty,
        prefix_ranks: std.ArrayList(u16) = .empty,
        samples: std.ArrayList(Sample) = .empty,
        base: usize = 0,
        end: usize = 0,
        core: ?usize = null,
        ranked: bool = false,

        pub fn init(allocator: std.mem.Allocator, input: []const u8, chunk: usize) !Self {
            if (chunk == 0 or input.len > empty) return error.InvalidBlockPlan;
            const span = std.math.add(usize, chunk, history + lookahead) catch return error.InvalidBlockPlan;
            var self: Self = .{ .input = input, .chunk = chunk };
            errdefer self.deinit(allocator);
            try storage.resizeFresh(&self.first, allocator, table_size);
            try storage.resizeFresh(&self.head, allocator, table_size);
            try storage.resizeFresh(&self.previous, allocator, @min(input.len, span));
            @memset(self.first.items, empty);
            @memset(self.head.items, empty);

            const count = (if (input.len >= 1024) @as(usize, 256) else 0) +
                (if (input.len >= 8192) @as(usize, 64) else 0);
            try storage.resizeFresh(&self.samples, allocator, count);
            for (self.samples.items, 0..) |*sample, i| {
                const ordinal = if (i < 256) i else i - 256;
                sample.* = .{ .position = @intCast(policy.samplePosition(input.len, ordinal)) };
            }
            std.mem.sort(Sample, self.samples.items, {}, struct {
                fn less(_: void, a: Sample, b: Sample) bool {
                    return a.position < b.position;
                }
            }.less);

            // One forward pass captures the original whole-input policy
            // samples. Sampling never rebuilds a window or changes policy.
            var sample_i: usize = 0;
            for (0..input.len) |position| {
                const hash = hashAt(input, position) orelse continue;
                const previous = self.head.items[hash];
                if (self.first.items[hash] == empty) self.first.items[hash] = @intCast(position);
                self.head.items[hash] = @intCast(position);
                while (sample_i < count and self.samples.items[sample_i].position == position) : (sample_i += 1)
                    self.samples.items[sample_i].previous = previous;
            }
            std.debug.assert(sample_i == count);
            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.first.deinit(allocator);
            self.head.deinit(allocator);
            self.previous.deinit(allocator);
            self.raw_ranks.deinit(allocator);
            self.prefix_ranks.deinit(allocator);
            self.samples.deinit(allocator);
        }

        pub fn view(self: *Self) View {
            return .{ .owner = self, .len = self.input.len };
        }

        fn prepare(self: *Self, position: usize) void {
            std.debug.assert(position < self.input.len);
            const core = position / self.chunk * self.chunk;
            if (self.core == core) return;
            self.core = core;
            self.base = core -| history;
            self.end = @min(self.input.len, core +| self.chunk +| lookahead);
            const expired: u32 = if (self.base == 0) empty else @intCast(self.base - 1);
            for (self.head.items, self.first.items) |*head, first|
                head.* = if (first < self.base) expired else empty;

            for (self.base..self.end) |absolute| {
                const slot = absolute - self.base;
                self.previous.items[slot] = empty;
                if (self.ranked) {
                    self.raw_ranks.items[slot] = 0;
                    self.prefix_ranks.items[slot] = 0;
                }
                const hash = hashAt(self.input, absolute) orelse continue;
                const previous = self.head.items[hash];
                self.previous.items[slot] = previous;
                self.head.items[hash] = @intCast(absolute);
                if (!self.ranked) continue;
                // Unknown earlier nodes are expired for every core position.
                // A common ordinal offset cancels within the live history.
                self.raw_ranks.items[slot] = if (previous != empty and previous >= self.base)
                    self.raw_ranks.items[previous - self.base] +% 1
                else
                    1;
                const prefix = std.mem.readInt(u24, self.input[absolute..][0..3], .little);
                var last = previous;
                var prefix_rank: u16 = 1;
                while (last != empty and last >= self.base) {
                    const candidate: usize = last;
                    if (absolute - candidate > history) break;
                    if (std.mem.readInt(u24, self.input[candidate..][0..3], .little) == prefix) {
                        prefix_rank = self.prefix_ranks.items[candidate - self.base] +% 1;
                        break;
                    }
                    last = self.previous.items[candidate - self.base];
                }
                self.prefix_ranks.items[slot] = prefix_rank;
            }
        }

        pub const View = struct {
            owner: *Self,
            len: usize,

            pub fn activate(self: View, allocator: std.mem.Allocator, ranked: bool) !void {
                if (!ranked or self.owner.ranked) return;
                try storage.resizeFresh(&self.owner.raw_ranks, allocator, self.owner.previous.items.len);
                try storage.resizeFresh(&self.owner.prefix_ranks, allocator, self.owner.previous.items.len);
                self.owner.ranked = true;
                self.owner.core = null;
            }

            pub inline fn prepare(self: View, position: usize) void {
                if (self.needsPrepare(position)) self.owner.prepare(position);
            }

            pub inline fn needsPrepare(self: View, position: usize) bool {
                const core = self.owner.core orelse return true;
                return position < core or position - core >= self.owner.chunk;
            }

            pub fn snapshot(self: View) ReadView {
                return .{
                    .previous_bias = @intFromPtr(self.owner.previous.items.ptr) -% (self.owner.base *% @sizeOf(u32)),
                    .raw_bias = @intFromPtr(self.owner.raw_ranks.items.ptr) -% (self.owner.base *% @sizeOf(u16)),
                    .prefix_bias = @intFromPtr(self.owner.prefix_ranks.items.ptr) -% (self.owner.base *% @sizeOf(u16)),
                    .base = self.owner.base,
                    .end = self.owner.end,
                    .core = self.owner.core orelse self.len,
                    .len = self.len,
                };
            }

            pub inline fn get(self: View, position: usize) u32 {
                std.debug.assert(position >= self.owner.base and position < self.owner.end);
                return self.owner.previous.items[position - self.owner.base];
            }

            pub fn sample(self: View, position: usize) u32 {
                var lo: usize = 0;
                var hi = self.owner.samples.items.len;
                while (lo < hi) {
                    const mid = lo + (hi - lo) / 2;
                    const value = self.owner.samples.items[mid];
                    if (value.position == position) return value.previous;
                    if (value.position < position) lo = mid + 1 else hi = mid;
                }
                unreachable;
            }

            pub inline fn rawCount(self: View, position: usize, candidate: usize) usize {
                std.debug.assert(candidate < position and position - candidate <= history and candidate >= self.owner.base);
                return self.owner.raw_ranks.items[position - self.owner.base] -%
                    self.owner.raw_ranks.items[candidate - self.owner.base];
            }

            pub inline fn prefixCount(self: View, position: usize, candidate: usize) usize {
                std.debug.assert(candidate < position and position - candidate <= history and candidate >= self.owner.base);
                return self.owner.prefix_ranks.items[position - self.owner.base] -%
                    self.owner.prefix_ranks.items[candidate - self.owner.base];
            }

            pub fn bytes(self: View) usize {
                const self_index = self.owner;
                return (self_index.first.items.len + self_index.head.items.len + self_index.previous.items.len) * @sizeOf(u32) +
                    (self_index.raw_ranks.items.len + self_index.prefix_ranks.items.len) * @sizeOf(u16) +
                    self_index.samples.items.len * @sizeOf(Sample);
            }
        };

        /// The parser reads one immutable set of pointers between rebuilds.
        /// Keeping it separate avoids repeated mutable-owner field loads.
        pub const ReadView = struct {
            // Biases remain integers. A pointer is formed only after adding
            // an in-window absolute position, yielding the original owned
            // array address. Modular arithmetic also covers 32-bit positions.
            previous_bias: usize,
            raw_bias: usize,
            prefix_bias: usize,
            base: usize,
            end: usize,
            core: usize,
            len: usize,

            pub inline fn get(self: ReadView, position: usize) u32 {
                std.debug.assert(position >= self.base and position < self.end);
                const pointer: *const u32 = @ptrFromInt(self.previous_bias +% (position *% @sizeOf(u32)));
                return pointer.*;
            }

            pub inline fn rawCount(self: ReadView, position: usize, candidate: usize) usize {
                std.debug.assert(candidate < position and position - candidate <= history and candidate >= self.base);
                const current: *const u16 = @ptrFromInt(self.raw_bias +% (position *% @sizeOf(u16)));
                const previous: *const u16 = @ptrFromInt(self.raw_bias +% (candidate *% @sizeOf(u16)));
                return current.* -% previous.*;
            }

            pub inline fn prefixCount(self: ReadView, position: usize, candidate: usize) usize {
                std.debug.assert(candidate < position and position - candidate <= history and candidate >= self.base);
                const current: *const u16 = @ptrFromInt(self.prefix_bias +% (position *% @sizeOf(u16)));
                const previous: *const u16 = @ptrFromInt(self.prefix_bias +% (candidate *% @sizeOf(u16)));
                return current.* -% previous.*;
            }
        };
    };
}
