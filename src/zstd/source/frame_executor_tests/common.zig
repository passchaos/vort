const std = @import("std");

pub const block_common = @import("../compressed_block_tests/common.zig");
pub const frame_executor = @import("../frame_executor.zig");
pub const history_workspace = @import("../../decode/history_workspace.zig");
pub const source_frame = @import("../frame.zig");
pub const source_input = @import("../input.zig");
pub const byte_source = @import("../../../io/source.zig");

pub const TrackingSource = block_common.TrackingSource;
pub const decodeHex = block_common.decodeHex;
pub const expectHistoryEqual = block_common.expectHistoryEqual;
pub const expectGuard = block_common.expectGuard;

pub const all_fse_raw_hex = block_common.all_fse_raw_hex;
pub const numbered_json_hex = block_common.numbered_json_hex;
pub const predefined_repeat_hex = block_common.predefined_repeat_hex;

const data_magic: u32 = 0xfd2f_b528;

pub const BlockKind = enum { raw, rle, compressed };

pub const Fixture = struct {
    storage: [4096]u8 = @splat(0),
    len: usize = 0,

    pub fn bytes(self: *const Fixture) []const u8 {
        return self.storage[0..self.len];
    }

    pub fn appendByte(self: *Fixture, value: u8) void {
        self.storage[self.len] = value;
        self.len += 1;
    }

    pub fn appendRepeat(self: *Fixture, value: u8, len: usize) void {
        @memset(self.storage[self.len..][0..len], value);
        self.len += len;
    }

    pub fn appendSlice(self: *Fixture, input: []const u8) void {
        @memcpy(self.storage[self.len..][0..input.len], input);
        self.len += input.len;
    }

    pub fn appendLittle(self: *Fixture, value: u64, len: usize) void {
        for (0..len) |index|
            self.appendByte(@truncate(value >> @intCast(index * 8)));
    }
};

fn dictionaryFieldLen(descriptor: u8) usize {
    return switch (descriptor & 0x03) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
}

fn contentSizeFieldLen(descriptor: u8) usize {
    const single_segment = (descriptor & 0x20) != 0;
    const flag = descriptor >> 6;
    return if (single_segment or flag != 0)
        @as(usize, 1) << @intCast(flag)
    else
        0;
}

/// Append a standard-magic data frame header. `window_descriptor` is written
/// only for non-single-segment descriptors. The content-size field length is
/// derived from the descriptor and encoded canonically.
pub fn appendHeader(
    fixture: *Fixture,
    descriptor: u8,
    window_descriptor: ?u8,
    dictionary_id: u32,
    content_size: ?u64,
) void {
    fixture.appendLittle(data_magic, 4);
    fixture.appendByte(descriptor);
    if ((descriptor & 0x20) == 0) {
        const window = window_descriptor orelse @panic("window descriptor required");
        fixture.appendByte(window);
    }
    const dictionary_len = dictionaryFieldLen(descriptor);
    fixture.appendLittle(dictionary_id, dictionary_len);
    const content_len = contentSizeFieldLen(descriptor);
    if (content_len != 0) {
        const value = content_size orelse @panic("content size required");
        switch (content_len) {
            1 => fixture.appendByte(@intCast(value)),
            2 => fixture.appendLittle(value - 256, 2),
            4 => fixture.appendLittle(value, 4),
            8 => fixture.appendLittle(value, 8),
            else => unreachable,
        }
    }
}

pub fn appendBlockHeader(
    fixture: *Fixture,
    kind: BlockKind,
    declared_len: usize,
    last: bool,
) void {
    const kind_bits: u2 = switch (kind) {
        .raw => 0,
        .rle => 1,
        .compressed => 2,
    };
    const encoded = (@as(u64, declared_len) << 3) |
        (@as(u64, kind_bits) << 1) | @intFromBool(last);
    fixture.appendLittle(encoded, 3);
}

pub fn appendRawBlock(
    fixture: *Fixture,
    payload: []const u8,
    last: bool,
) void {
    appendBlockHeader(fixture, .raw, payload.len, last);
    fixture.appendSlice(payload);
}

pub fn appendRleBlock(
    fixture: *Fixture,
    value: u8,
    declared_len: usize,
    last: bool,
) void {
    appendBlockHeader(fixture, .rle, declared_len, last);
    fixture.appendByte(value);
}

pub fn appendChecksum(fixture: *Fixture, decoded: []const u8) void {
    const hash: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
    fixture.appendLittle(hash, 4);
}

pub fn limits() frame_executor.Limits {
    return .{};
}

/// Stable-address test harness. `init` must be called on caller storage that
/// is not moved afterwards because the executor borrows `state` and `history`.
pub fn Runner(comptime Support: type) type {
    return struct {
        const Self = @This();
        const Executor = frame_executor.Executor(
            Support.HuffmanCodec,
            Support.SequenceCodec,
        );

        allocator: std.mem.Allocator,
        source: TrackingSource = undefined,
        frame: source_frame.DataFrameLayout = undefined,
        state: Support.State = undefined,
        history: history_workspace.Binding = undefined,
        executor: Executor = undefined,
        history_storage: []u8 = &.{},
        staging_guard: []u8 = &.{},
        literal_guard: []u8 = &.{},
        sequence_guard: []u8 = &.{},
        output: std.ArrayList(u8) = .empty,
        chunk: usize = 256,

        pub fn init(
            self: *Self,
            allocator: std.mem.Allocator,
            bytes: []const u8,
            initial_state: Support.State,
            dictionary: []const u8,
            dictionary_id: u32,
            exec_limits: frame_executor.Limits,
            page_len: usize,
            chunk: usize,
        ) !void {
            return self.initWithFormat(
                .standard,
                allocator,
                bytes,
                initial_state,
                dictionary,
                dictionary_id,
                exec_limits,
                page_len,
                chunk,
            );
        }

        pub fn initWithFormat(
            self: *Self,
            format: source_frame.FrameFormat,
            allocator: std.mem.Allocator,
            bytes: []const u8,
            initial_state: Support.State,
            dictionary: []const u8,
            dictionary_id: u32,
            exec_limits: frame_executor.Limits,
            page_len: usize,
            chunk: usize,
        ) !void {
            self.* = .{ .allocator = allocator, .chunk = chunk };
            errdefer self.deinit();

            self.source = .{ .bytes = bytes };
            const available = try source_input.Range.init(
                self.source.source(),
                0,
                @intCast(bytes.len),
            );
            self.frame = try source_frame.parseDataFrameHeader(available, format);
            const history_len = try history_workspace.requiredLen(
                self.frame.header.window_size,
                dictionary.len,
            );
            self.history_storage = try allocator.alloc(u8, history_len);
            @memset(self.history_storage, 0xa7);
            self.history = try history_workspace.Binding.init(self.history_storage);
            try self.history.beginFrame(
                self.frame.header.window_size,
                dictionary.len,
            );

            const block_max = self.frame.header.block_size_max;
            self.staging_guard = try allocator.alloc(u8, block_max + 2);
            @memset(self.staging_guard, 0xd8);
            self.staging_guard[0] = 0x51;
            self.staging_guard[self.staging_guard.len - 1] = 0xae;

            self.literal_guard = try allocator.alloc(u8, page_len + 2);
            @memset(self.literal_guard, 0x73);
            self.literal_guard[0] = 0x39;
            self.literal_guard[self.literal_guard.len - 1] = 0xc6;

            self.sequence_guard = try allocator.alloc(u8, page_len + 2);
            @memset(self.sequence_guard, 0x94);
            self.sequence_guard[0] = 0x2a;
            self.sequence_guard[self.sequence_guard.len - 1] = 0xd5;

            self.state = initial_state;
            self.executor = try Executor.init(
                self.frame,
                &self.state,
                &self.history,
                dictionary,
                dictionary_id,
                self.staging_guard[1 .. self.staging_guard.len - 1],
                self.literal_guard[1 .. self.literal_guard.len - 1],
                self.sequence_guard[1 .. self.sequence_guard.len - 1],
                exec_limits,
            );
        }

        pub fn deinit(self: *Self) void {
            if (self.history_storage.len != 0) {
                self.allocator.free(self.history_storage);
                self.history_storage = &.{};
            }
            if (self.staging_guard.len != 0) {
                self.allocator.free(self.staging_guard);
                self.staging_guard = &.{};
            }
            if (self.literal_guard.len != 0) {
                self.allocator.free(self.literal_guard);
                self.literal_guard = &.{};
            }
            if (self.sequence_guard.len != 0) {
                self.allocator.free(self.sequence_guard);
                self.sequence_guard = &.{};
            }
            self.output.deinit(self.allocator);
            self.output = .empty;
        }

        /// Drive one phase transition. Returns true once the frame footer has
        /// been validated.
        pub fn step(self: *Self) !bool {
            switch (self.executor.snapshot().phase) {
                .drain => {
                    var buffer: [512]u8 = undefined;
                    const amount = @min(self.chunk, buffer.len);
                    const result = try self.executor.drain(buffer[0..amount]);
                    try self.output.appendSlice(
                        self.allocator,
                        buffer[0..result.written],
                    );
                    return self.executor.snapshot().phase == .done;
                },
                .done => return true,
                else => {
                    try self.executor.execute();
                    return self.executor.snapshot().phase == .done;
                },
            }
        }

        pub fn run(self: *Self) !void {
            while (!try self.step()) {}
        }

        pub fn expectGuards(self: *const Self) !void {
            try expectGuard(self.staging_guard, 0x51, 0xae);
            try expectGuard(self.literal_guard, 0x39, 0xc6);
            try expectGuard(self.sequence_guard, 0x2a, 0xd5);
        }

        /// Compare retained history with an independent shadow ring built from
        /// the expected output.
        pub fn expectHistory(self: *Self, expected: []const u8, dictionary_len: usize) !void {
            const shadow_storage = try self.allocator.alloc(
                u8,
                self.history_storage.len,
            );
            defer self.allocator.free(shadow_storage);
            @memset(shadow_storage, 0xa7);
            var shadow = try history_workspace.Binding.init(shadow_storage);
            try shadow.beginFrame(self.frame.header.window_size, dictionary_len);
            shadow.append(expected);
            try expectHistoryEqual(shadow, self.history);
        }
    };
}
