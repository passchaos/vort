//! Bounded incremental inverse filters for XZ/7z linear coder chains.

const std = @import("std");
const filters = @import("filters.zig");

pub const Error = filters.Error || std.mem.Allocator.Error;

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    stages: [3]Stage = undefined,
    stage_count: usize = 0,
    scratch_a: std.ArrayList(u8) = .empty,
    scratch_b: std.ArrayList(u8) = .empty,
    finished: bool = false,

    pub fn init(allocator: std.mem.Allocator, chain: []const filters.Filter) Error!Decoder {
        try filters.validateChain(chain);
        var result = Decoder{ .allocator = allocator, .stage_count = chain.len };
        var initialized: usize = 0;
        errdefer for (result.stages[0..initialized]) |*stage| stage.deinit(allocator);
        for (chain, 0..) |filter, index| {
            result.stages[index] = Stage.init(filter);
            initialized += 1;
        }
        return result;
    }

    pub fn deinit(self: *Decoder) void {
        for (self.stages[0..self.stage_count]) |*stage| stage.deinit(self.allocator);
        self.scratch_a.deinit(self.allocator);
        self.scratch_b.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn push(
        self: *Decoder,
        input: []const u8,
        finish: bool,
        output: *std.ArrayList(u8),
    ) Error!void {
        if (self.finished) {
            if (input.len != 0 or !finish) return error.InvalidXzHeader;
            return;
        }
        if (self.stage_count == 0) {
            try output.appendSlice(self.allocator, input);
            self.finished = finish;
            return;
        }

        var current = input;
        for (self.stages[0..self.stage_count], 0..) |*stage, index| {
            const target = if (index & 1 == 0) &self.scratch_a else &self.scratch_b;
            target.clearRetainingCapacity();
            try stage.push(self.allocator, current, finish, false, target);
            current = target.items;
        }
        try output.appendSlice(self.allocator, current);
        self.finished = finish;
    }
};

/// Bounded incremental forward filters. The filter order is the same as
/// `filters.encodeChain`, matching the order exposed by 7z writer options.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    stages: [3]Stage = undefined,
    stage_count: usize = 0,
    scratch_a: std.ArrayList(u8) = .empty,
    scratch_b: std.ArrayList(u8) = .empty,
    finished: bool = false,

    pub fn init(allocator: std.mem.Allocator, chain: []const filters.Filter) Error!Encoder {
        try filters.validateChain(chain);
        var result = Encoder{ .allocator = allocator, .stage_count = chain.len };
        var initialized: usize = 0;
        errdefer for (result.stages[0..initialized]) |*stage| stage.deinit(allocator);
        for (chain, 0..) |filter, index| {
            result.stages[index] = Stage.init(filter);
            initialized += 1;
        }
        return result;
    }

    pub fn deinit(self: *Encoder) void {
        for (self.stages[0..self.stage_count]) |*stage| stage.deinit(self.allocator);
        self.scratch_a.deinit(self.allocator);
        self.scratch_b.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn push(
        self: *Encoder,
        input: []const u8,
        finish: bool,
        output: *std.ArrayList(u8),
    ) Error!void {
        if (self.finished) {
            if (input.len != 0 or !finish) return error.InvalidXzHeader;
            return;
        }
        if (self.stage_count == 0) {
            try output.appendSlice(self.allocator, input);
            self.finished = finish;
            return;
        }

        var current = input;
        for (self.stages[0..self.stage_count], 0..) |*stage, index| {
            const target = if (index & 1 == 0) &self.scratch_a else &self.scratch_b;
            target.clearRetainingCapacity();
            try stage.push(self.allocator, current, finish, true, target);
            current = target.items;
        }
        try output.appendSlice(self.allocator, current);
        self.finished = finish;
    }
};

const Stage = union(enum) {
    delta: Delta,
    bcj: Bcj,

    fn init(filter: filters.Filter) Stage {
        return switch (filter.kind) {
            .delta => .{ .delta = .{ .distance = @intCast(filter.parameter) } },
            else => .{ .bcj = Bcj.init(filter) },
        };
    }

    fn deinit(self: *Stage, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .delta => {},
            .bcj => |*state| state.deinit(allocator),
        }
    }

    fn push(
        self: *Stage,
        allocator: std.mem.Allocator,
        input: []const u8,
        finish: bool,
        encode: bool,
        output: *std.ArrayList(u8),
    ) Error!void {
        switch (self.*) {
            .delta => |*state| try state.push(allocator, input, encode, output),
            .bcj => |*state| try state.push(allocator, input, finish, encode, output),
        }
    }
};

const Delta = struct {
    history: [256]u8 = @splat(0),
    distance: u9,
    position: u8 = 0,

    fn push(
        self: *Delta,
        allocator: std.mem.Allocator,
        input: []const u8,
        encode: bool,
        output: *std.ArrayList(u8),
    ) !void {
        try output.ensureUnusedCapacity(allocator, input.len);
        for (input) |source| {
            const prior = self.history[self.position +% @as(u8, @truncate(self.distance))];
            const transformed = if (encode) source -% prior else source +% prior;
            self.history[self.position] = if (encode) source else transformed;
            self.position -%= 1;
            output.appendAssumeCapacity(transformed);
        }
    }
};

const Bcj = struct {
    filter: filters.Filter,
    original: std.ArrayList(u8) = .empty,
    work: std.ArrayList(u8) = .empty,
    window_start: u64 = 0,
    emitted: u64 = 0,

    fn init(filter: filters.Filter) Bcj {
        return .{ .filter = filter };
    }

    fn deinit(self: *Bcj, allocator: std.mem.Allocator) void {
        self.original.deinit(allocator);
        self.work.deinit(allocator);
    }

    fn push(
        self: *Bcj,
        allocator: std.mem.Allocator,
        input: []const u8,
        finish: bool,
        encode: bool,
        output: *std.ArrayList(u8),
    ) Error!void {
        try self.original.appendSlice(allocator, input);
        const available_end = std.math.add(
            u64,
            self.window_start,
            self.original.items.len,
        ) catch return error.InvalidXzHeader;
        const retain = tailBytes(self.filter.kind);
        const safe_end = if (finish)
            available_end
        else
            available_end -| retain;
        if (safe_end <= self.emitted) return;

        try self.work.resize(allocator, self.original.items.len);
        @memcpy(self.work.items, self.original.items);
        var adjusted = self.filter;
        adjusted.parameter +%= @truncate(self.window_start);
        if (encode)
            filters.encodeChain(self.work.items, &.{adjusted})
        else
            filters.decodeChain(self.work.items, &.{adjusted});
        const output_start = std.math.cast(usize, self.emitted - self.window_start) orelse
            return error.InvalidXzHeader;
        const output_end = std.math.cast(usize, safe_end - self.window_start) orelse
            return error.InvalidXzHeader;
        try output.appendSlice(allocator, self.work.items[output_start..output_end]);
        self.emitted = safe_end;

        const lookbehind = tailBytes(self.filter.kind);
        var keep_start = self.emitted -| lookbehind;
        const alignment = alignmentBytes(self.filter.kind);
        keep_start &= ~(@as(u64, alignment) - 1);
        if (keep_start > self.window_start) {
            const remove = std.math.cast(usize, keep_start - self.window_start) orelse
                return error.InvalidXzHeader;
            const remaining = self.original.items.len - remove;
            std.mem.copyForwards(
                u8,
                self.original.items[0..remaining],
                self.original.items[remove..],
            );
            self.original.items.len = remaining;
            self.window_start = keep_start;
        }
        if (finish) {
            self.original.clearRetainingCapacity();
            self.window_start = self.emitted;
        }
    }
};

fn tailBytes(kind: filters.Kind) u64 {
    return switch (kind) {
        .x86 => 8,
        .powerpc, .arm, .sparc, .arm64 => 8,
        .ia64 => 32,
        .arm_thumb => 8,
        .riscv => 16,
        .delta => 0,
    };
}

fn alignmentBytes(kind: filters.Kind) u8 {
    return switch (kind) {
        .x86 => 1,
        .powerpc, .arm, .sparc, .arm64 => 4,
        .ia64 => 16,
        .arm_thumb, .riscv => 2,
        .delta => 1,
    };
}

test "incremental XZ filters match one-shot across every split" {
    const cases = [_]struct {
        filter: filters.Filter,
        input: []const u8,
    }{
        .{ .filter = try filters.Filter.delta(4), .input = "delta-state-0123456789" ** 16 },
        .{ .filter = filters.Filter.x86(0x1000), .input = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 32 },
        .{ .filter = try filters.Filter.powerpc(0x1000), .input = "\x48\x00\x00\x01\x4b\xff\xff\xfd" ** 32 },
        .{ .filter = try filters.Filter.ia64(0x1000), .input = "\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ** 32 },
        .{ .filter = try filters.Filter.arm(0x1000), .input = "\x04\x00\x00\xeb\xfc\xff\xff\xeb" ** 32 },
        .{ .filter = try filters.Filter.armThumb(0x1000), .input = "\x00\xf0\x00\xf8\xff\xf7\xff\xff" ** 32 },
        .{ .filter = try filters.Filter.sparc(0x1000), .input = "\x40\x00\x00\x00\x7f\xff\xff\xff" ** 32 },
        .{ .filter = try filters.Filter.arm64(0x1000), .input = "\x00\x00\x00\x94\x00\x00\x00\x90" ** 32 },
        .{ .filter = try filters.Filter.riscv(0x1000), .input = "\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00" ** 32 },
    };
    for (cases) |case| {
        const encoded = try std.testing.allocator.dupe(u8, case.input);
        defer std.testing.allocator.free(encoded);
        filters.encodeChain(encoded, &.{case.filter});
        for (1..18) |chunk_size| {
            var decoder = try Decoder.init(std.testing.allocator, &.{case.filter});
            defer decoder.deinit();
            var decoded: std.ArrayList(u8) = .empty;
            defer decoded.deinit(std.testing.allocator);
            var offset: usize = 0;
            while (offset < encoded.len) {
                const end = @min(encoded.len, offset + chunk_size);
                try decoder.push(encoded[offset..end], false, &decoded);
                offset = end;
            }
            try decoder.push("", true, &decoded);
            try std.testing.expectEqualSlices(u8, case.input, decoded.items);
        }
    }
}

test "incremental XZ forward filters match one-shot across every split" {
    const cases = [_]struct {
        filter: filters.Filter,
        input: []const u8,
    }{
        .{ .filter = try filters.Filter.delta(4), .input = "delta-state-0123456789" ** 16 },
        .{ .filter = filters.Filter.x86(0x1000), .input = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 32 },
        .{ .filter = try filters.Filter.powerpc(0x1000), .input = "\x48\x00\x00\x01\x4b\xff\xff\xfd" ** 32 },
        .{ .filter = try filters.Filter.ia64(0x1000), .input = "\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ** 32 },
        .{ .filter = try filters.Filter.arm(0x1000), .input = "\x04\x00\x00\xeb\xfc\xff\xff\xeb" ** 32 },
        .{ .filter = try filters.Filter.armThumb(0x1000), .input = "\x00\xf0\x00\xf8\xff\xf7\xff\xff" ** 32 },
        .{ .filter = try filters.Filter.sparc(0x1000), .input = "\x40\x00\x00\x00\x7f\xff\xff\xff" ** 32 },
        .{ .filter = try filters.Filter.arm64(0x1000), .input = "\x00\x00\x00\x94\x00\x00\x00\x90" ** 32 },
        .{ .filter = try filters.Filter.riscv(0x1000), .input = "\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00" ** 32 },
    };
    for (cases) |case| {
        const expected = try std.testing.allocator.dupe(u8, case.input);
        defer std.testing.allocator.free(expected);
        filters.encodeChain(expected, &.{case.filter});
        for (1..18) |chunk_size| {
            var encoder = try Encoder.init(std.testing.allocator, &.{case.filter});
            defer encoder.deinit();
            var encoded: std.ArrayList(u8) = .empty;
            defer encoded.deinit(std.testing.allocator);
            var offset: usize = 0;
            while (offset < case.input.len) {
                const end = @min(case.input.len, offset + chunk_size);
                try encoder.push(case.input[offset..end], false, &encoded);
                offset = end;
            }
            try encoder.push("", true, &encoded);
            try std.testing.expectEqualSlices(u8, expected, encoded.items);
        }
    }
}

test "incremental XZ filter chains reverse encoder order and release OOM" {
    const encode_chain = [_]filters.Filter{
        filters.Filter.x86(0x1000),
        try filters.Filter.delta(4),
    };
    const decode_chain = [_]filters.Filter{ encode_chain[1], encode_chain[0] };
    const input = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 64;
    const encoded = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(encoded);
    filters.encodeChain(encoded, &encode_chain);

    const FailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            payload: []const u8,
            expected: []const u8,
            chain: []const filters.Filter,
        ) !void {
            var decoder = try Decoder.init(allocator, chain);
            defer decoder.deinit();
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            var offset: usize = 0;
            while (offset < payload.len) {
                const end = @min(payload.len, offset + 11);
                try decoder.push(payload[offset..end], false, &output);
                offset = end;
            }
            try decoder.push("", true, &output);
            try std.testing.expectEqualSlices(u8, expected, output.items);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ encoded, input, &decode_chain },
    );
}
