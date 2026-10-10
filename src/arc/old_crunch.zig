const std = @import("std");
const core = @import("../core.zig");
const rle = @import("rle.zig");

pub const Error = core.Error || rle.Error || std.mem.Allocator.Error || error{InvalidArcCrunchStream};
pub const Mode = enum { method_5, method_6, method_7 };

const table_size = 4096;
const no_predecessor: u16 = 0xffff;

const Entry = struct {
    used: bool = false,
    follower: u8 = 0,
    next: u16 = 0,
    predecessor: u16 = no_predecessor,
};

const Model = struct {
    entries: [table_size]Entry = @splat(.{}),
    literal_codes: [256]u16 = @splat(0),
    remaining: usize = table_size - 256,
    mode: Mode,

    fn init(mode: Mode) Model {
        var self = Model{ .mode = mode };
        for (0..256) |byte| self.literal_codes[byte] = self.add(no_predecessor, @intCast(byte));
        return self;
    }

    fn add(self: *Model, predecessor: u16, follower: u8) u16 {
        var local = self.hash(predecessor, follower);
        if (self.entries[local].used) {
            while (self.entries[local].next != 0) local = self.entries[local].next;
            var candidate = (local + 101) & 0x0fff;
            while (self.entries[candidate].used) candidate = (candidate + 1) & 0x0fff;
            self.entries[local].next = @intCast(candidate);
            local = candidate;
        }
        self.entries[local] = .{
            .used = true,
            .follower = follower,
            .predecessor = predecessor,
        };
        return @intCast(local);
    }

    fn update(self: *Model, predecessor: u16, follower: u8) void {
        if (self.remaining == 0) return;
        _ = self.add(predecessor, follower);
        self.remaining -= 1;
    }

    fn hash(self: *const Model, predecessor: u16, follower: u8) usize {
        return switch (self.mode) {
            .method_5, .method_6 => blk: {
                var value: u32 = ((@as(u32, predecessor) + follower) | 0x0800) & 0xffff;
                value *%= value;
                break :blk @intCast((value >> 6) & 0x0fff);
            },
            .method_7 => @intCast(
                ((@as(u32, predecessor) + follower) & 0xffff) *% 15073 & 0x0fff,
            ),
        };
    }
};

const CodeReader = struct {
    input: []const u8,
    code_index: usize = 0,

    fn count(self: *const CodeReader) Error!usize {
        if (self.input.len % 3 == 1) return error.TruncatedFrame;
        return self.input.len / 3 * 2 + @intFromBool(self.input.len % 3 == 2);
    }

    fn next(self: *CodeReader) Error!?u16 {
        const total = try self.count();
        if (self.code_index == total) return null;
        const start = self.code_index / 2 * 3;
        const code = if (self.code_index % 2 == 0)
            (@as(u16, self.input[start]) << 4) | (self.input[start + 1] >> 4)
        else
            (@as(u16, self.input[start + 1] & 0x0f) << 8) | self.input[start + 2];
        self.code_index += 1;
        return code;
    }
};

const Emitter = struct {
    output: []u8,
    use_rle: bool,
    offset: usize = 0,
    rle_decoder: rle.Decoder = .{},

    fn emit(self: *Emitter, byte: u8) Error!void {
        if (self.use_rle) {
            try self.rle_decoder.feed(byte, self.output);
        } else {
            if (self.offset == self.output.len) return error.OutputTooSmall;
            self.output[self.offset] = byte;
            self.offset += 1;
        }
    }

    fn finish(self: *Emitter) Error!void {
        if (self.use_rle)
            try self.rle_decoder.finish(self.output.len)
        else if (self.offset != self.output.len)
            return error.SizeMismatch;
    }
};

pub fn decodeInto(input: []const u8, output: []u8, mode: Mode) Error!void {
    if (input.len == 0) {
        if (output.len != 0) return error.SizeMismatch;
        return;
    }
    var model = Model.init(mode);
    var reader = CodeReader{ .input = input };
    var emitter = Emitter{ .output = output, .use_rle = mode != .method_5 };
    var stack: [table_size]u8 = undefined;
    const first = (try reader.next()) orelse return error.TruncatedFrame;
    if (!model.entries[first].used) return error.InvalidArcCrunchStream;
    var old_code = first;
    var final_byte = model.entries[first].follower;
    try emitter.emit(final_byte);

    while (try reader.next()) |new_code| {
        var code = new_code;
        var stack_len: usize = 0;
        if (!model.entries[code].used) {
            code = old_code;
            stack[stack_len] = final_byte;
            stack_len += 1;
        }
        var iterations: usize = 0;
        while (model.entries[code].predecessor != no_predecessor) {
            if (!model.entries[code].used or stack_len == stack.len or iterations > table_size)
                return error.InvalidArcCrunchStream;
            stack[stack_len] = model.entries[code].follower;
            stack_len += 1;
            code = model.entries[code].predecessor;
            iterations += 1;
        }
        if (!model.entries[code].used) return error.InvalidArcCrunchStream;
        final_byte = model.entries[code].follower;
        stack[stack_len] = final_byte;
        stack_len += 1;
        while (stack_len != 0) {
            stack_len -= 1;
            try emitter.emit(stack[stack_len]);
        }
        model.update(old_code, final_byte);
        old_code = new_code;
    }
    try emitter.finish();
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, mode: Mode) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, mode);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    mode: Mode,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    const source = if (mode == .method_5)
        try allocator.dupe(u8, input)
    else
        try rle.encodeAlloc(allocator, input);
    defer allocator.free(source);
    if (source.len == 0) return 0;
    var model = Model.init(mode);
    var codes: std.ArrayList(u16) = .empty;
    defer codes.deinit(allocator);
    for (source, 0..) |byte, index| {
        try codes.append(allocator, model.literal_codes[byte]);
        if (index != 0) model.update(model.literal_codes[source[index - 1]], byte);
    }
    var index: usize = 0;
    while (index < codes.items.len) {
        const first = codes.items[index];
        try output.append(allocator, @truncate(first >> 4));
        if (index + 1 < codes.items.len) {
            const second = codes.items[index + 1];
            try output.append(allocator, @truncate((first << 4) | (second >> 8)));
            try output.append(allocator, @truncate(second));
            index += 2;
        } else {
            try output.append(allocator, @truncate(first << 4));
            index += 1;
        }
    }
    return output.items.len - start;
}

test "ARC old Crunch methods 5 6 and 7 round trip literal streams" {
    const input = ("old ARC Crunch payload\n" ** 128) ++ ([_]u8{ 0x90, 0, 1 } ** 32);
    inline for (std.meta.tags(Mode)) |mode| {
        const encoded = try encodeAlloc(std.testing.allocator, input, mode);
        defer std.testing.allocator.free(encoded);
        var decoded: [input.len]u8 = undefined;
        try decodeInto(encoded, &decoded, mode);
        try std.testing.expectEqualSlices(u8, input, &decoded);
    }
}

test "ARC old Crunch rejects truncation and invalid codes" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{0}, &output, .method_5));
    try std.testing.expectError(
        error.InvalidArcCrunchStream,
        decodeInto(&.{ 0xff, 0xf0 }, &output, .method_5),
    );
}
