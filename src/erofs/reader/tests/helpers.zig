const std = @import("std");
const source_module = @import("../../../io/source.zig");
const sink_module = @import("../../../io/sink.zig");
const writer = @import("../../writer.zig");

pub const Input = struct {
    bytes: []const u8,
    max_request: usize = 0,
    fail_from_offset: ?u64 = null,
    pub fn source(self: *Input) source_module.Source {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 31 };
    }
    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *Input = @ptrCast(@alignCast(raw));
        self.max_request = @max(self.max_request, output.len);
        if (self.fail_from_offset) |start| if (offset >= start) return error.SourceReadFailed;
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const size = @min(7, @min(output.len, self.bytes.len - start));
        @memcpy(output[0..size], self.bytes[start..][0..size]);
        return size;
    }
};

pub const Counting = struct {
    calls: usize = 0,
    max_request: usize = 0,
    length: u64 = 0,
    finished: bool = false,
    fail_after: ?usize = null,
    fail_finish: bool = false,
    expected: ?[]const u8 = null,
    generated: bool = false,

    pub fn sink(self: *Counting) sink_module.Sink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen, .max_write_size = 4096 };
    }
    fn writeAt(raw: *anyopaque, offset: u64, bytes: []const u8) error{SinkWriteFailed}!usize {
        const self: *Counting = @ptrCast(@alignCast(raw));
        if (self.fail_after) |limit| if (self.calls >= limit) return error.SinkWriteFailed;
        const end = std.math.add(u64, offset, bytes.len) catch return error.SinkWriteFailed;
        if (self.expected) |expected| {
            if (end > expected.len) return error.SinkWriteFailed;
            if (!std.mem.eql(u8, expected[@intCast(offset)..@intCast(end)], bytes)) return error.SinkWriteFailed;
        }
        if (self.generated) for (bytes, 0..) |byte, index| {
            if (byte != pattern(offset + index)) return error.SinkWriteFailed;
        };
        self.calls += 1;
        self.max_request = @max(self.max_request, bytes.len);
        self.length = @max(self.length, end);
        return bytes.len;
    }
    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *Counting = @ptrCast(@alignCast(raw));
        if (self.fail_finish) return error.SinkWriteFailed;
        self.length = length;
        self.finished = true;
    }
};

pub fn pattern(position: u64) u8 {
    return @truncate(position *% 17);
}

pub const VirtualStored = struct {
    metadata: [4096]u8 = @splat(0),
    length: u64 = 0,
    max_read: usize = 0,

    pub fn source(self: *VirtualStored) source_module.Source {
        return .{ .context = self, .len = self.length, .read_at = readAt };
    }
    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *VirtualStored = @ptrCast(@alignCast(raw));
        self.max_read = @max(self.max_read, output.len);
        const end = std.math.add(u64, offset, output.len) catch return error.SourceReadFailed;
        if (end > self.length) return error.SourceReadFailed;
        var position: usize = 0;
        if (offset < self.metadata.len) {
            const count = @min(output.len, self.metadata.len - @as(usize, @intCast(offset)));
            @memcpy(output[0..count], self.metadata[@intCast(offset)..][0..count]);
            position = count;
        }
        for (output[position..], position..) |*byte, index| byte.* = pattern(offset + index - self.metadata.len);
        return output.len;
    }
    fn capture(raw: *anyopaque, offset: u64, bytes: []const u8) error{SinkWriteFailed}!usize {
        const self: *VirtualStored = @ptrCast(@alignCast(raw));
        if (offset < self.metadata.len) {
            const count = @min(bytes.len, self.metadata.len - @as(usize, @intCast(offset)));
            @memcpy(self.metadata[@intCast(offset)..][0..count], bytes[0..count]);
        }
        return bytes.len;
    }
    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *VirtualStored = @ptrCast(@alignCast(raw));
        self.length = length;
    }
};

pub fn virtualStored(allocator: std.mem.Allocator, size: usize) !VirtualStored {
    const Generated = struct {
        fn readAt(raw: *anyopaque, offset: u64, bytes: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            for (bytes, 0..) |*byte, index| byte.* = pattern(offset + index);
            return bytes.len;
        }
    };
    var result = VirtualStored{};
    const source = source_module.Source{ .context = &result, .len = size, .read_at = Generated.readAt };
    const sink = sink_module.Sink{ .context = &result, .write_at = VirtualStored.capture, .set_len = VirtualStored.setLen };
    _ = try writer.encodeToSink(allocator, &.{.{ .path = "large", .source = source }}, .{}, sink, .{ .max_working_memory = 64 * 1024 });
    return result;
}
