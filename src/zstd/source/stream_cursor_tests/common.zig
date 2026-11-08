const std = @import("std");

pub const block_common = @import("../compressed_block_tests/common.zig");
pub const core = @import("../../../core.zig");
pub const frame_executor = @import("../frame_executor.zig");
pub const history_workspace = @import("../../decode/history_workspace.zig");
pub const source_frame = @import("../frame.zig");
pub const source_input = @import("../input.zig");
pub const stream_cursor = @import("../stream_cursor.zig");
pub const byte_source = @import("../../../io/source.zig");

pub const decodeHex = block_common.decodeHex;
pub const all_fse_raw_hex = block_common.all_fse_raw_hex;
pub const numbered_json_hex = block_common.numbered_json_hex;
pub const predefined_repeat_hex = block_common.predefined_repeat_hex;
pub const rle_literals_frame = block_common.rle_literals_frame;
pub const zero_sequence_frame = block_common.zero_sequence_frame;

pub const Mode = enum { normal, zero, excessive, fail };

pub const Span = struct {
    offset: u64,
    len: u64,
};

pub const TrackingSource = struct {
    bytes: []const u8,
    mode: Mode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    forbidden_read: bool = false,

    pub fn source(self: *TrackingSource) byte_source.Source {
        return .{
            .context = self,
            .len = @intCast(self.bytes.len),
            .read_at = readAt,
        };
    }

    pub fn clearFault(self: *TrackingSource) void {
        self.mode = .normal;
        self.fault_call = null;
    }

    fn readAt(
        raw: *anyopaque,
        absolute: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        if (self.fault_call == null or self.fault_call.? == self.calls) {
            switch (self.mode) {
                .normal => {},
                .zero => return 0,
                .excessive => return output.len + 1,
                .fail => return error.SourceReadFailed,
            }
        }
        const offset = std.math.cast(usize, absolute) orelse
            return error.SourceReadFailed;
        const request_end = std.math.add(usize, offset, output.len) catch
            return error.SourceReadFailed;
        for (self.forbidden) |span| {
            const span_end = std.math.add(u64, span.offset, span.len) catch
                return error.SourceReadFailed;
            if (@as(u64, absolute) < span_end and span.offset < request_end) {
                self.forbidden_read = true;
                return error.SourceReadFailed;
            }
        }
        if (offset >= self.bytes.len) return 0;
        const amount = @min(output.len, self.bytes.len - offset);
        @memcpy(output[0..amount], self.bytes[offset..][0..amount]);
        self.bytes_returned += amount;
        return amount;
    }
};

pub const Fixture = struct {
    storage: [8192]u8 = @splat(0),
    len: usize = 0,

    pub fn bytes(self: *const Fixture) []const u8 {
        return self.storage[0..self.len];
    }

    pub fn appendByte(self: *Fixture, value: u8) void {
        self.storage[self.len] = value;
        self.len += 1;
    }

    pub fn appendSlice(self: *Fixture, input: []const u8) void {
        @memcpy(self.storage[self.len..][0..input.len], input);
        self.len += input.len;
    }

    pub fn appendRepeat(self: *Fixture, value: u8, len: usize) void {
        @memset(self.storage[self.len..][0..len], value);
        self.len += len;
    }

    pub fn appendLittle(self: *Fixture, value: u64, len: usize) void {
        for (0..len) |index|
            self.appendByte(@truncate(value >> @intCast(index * 8)));
    }
};

const data_magic: u32 = 0xfd2f_b528;
const skippable_magic_min: u32 = 0x184d_2a50;

pub fn appendDataHeader(
    fixture: *Fixture,
    descriptor: u8,
    window_descriptor: ?u8,
    content_size: ?u64,
) void {
    fixture.appendLittle(data_magic, 4);
    fixture.appendByte(descriptor);
    if ((descriptor & 0x20) == 0) {
        const window = window_descriptor orelse @panic("window required");
        fixture.appendByte(window);
    }
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

pub fn appendMagiclessHeader(
    fixture: *Fixture,
    descriptor: u8,
    window_descriptor: ?u8,
    content_size: ?u64,
) void {
    const start = fixture.len;
    appendDataHeader(fixture, descriptor, window_descriptor, content_size);
    const header = fixture.storage[start..fixture.len];
    std.mem.copyForwards(u8, header[0 .. header.len - 4], header[4..]);
    fixture.len -= 4;
}

fn contentSizeFieldLen(descriptor: u8) usize {
    const single_segment = (descriptor & 0x20) != 0;
    const flag = descriptor >> 6;
    return if (single_segment or flag != 0)
        @as(usize, 1) << @intCast(flag)
    else
        0;
}

pub fn appendBlockHeader(
    fixture: *Fixture,
    kind: u2,
    declared_len: usize,
    last: bool,
) void {
    const encoded = (@as(u64, declared_len) << 3) |
        (@as(u64, kind) << 1) | @intFromBool(last);
    fixture.appendLittle(encoded, 3);
}

pub fn appendRawBlock(fixture: *Fixture, payload: []const u8, last: bool) void {
    appendBlockHeader(fixture, 0, payload.len, last);
    fixture.appendSlice(payload);
}

pub fn appendRleBlock(
    fixture: *Fixture,
    value: u8,
    declared_len: usize,
    last: bool,
) void {
    appendBlockHeader(fixture, 1, declared_len, last);
    fixture.appendByte(value);
}

pub fn appendChecksum(fixture: *Fixture, decoded: []const u8) void {
    const hash: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
    fixture.appendLittle(hash, 4);
}

/// Append one complete skippable frame. Returns its absolute start offset.
pub fn appendSkippable(
    fixture: *Fixture,
    id: u4,
    payload: []const u8,
) usize {
    const start = fixture.len;
    fixture.appendLittle(skippable_magic_min + @as(u32, id), 4);
    fixture.appendLittle(payload.len, 4);
    fixture.appendSlice(payload);
    return start;
}

pub fn appendFrame(fixture: *Fixture, bytes: []const u8) usize {
    const start = fixture.len;
    fixture.appendSlice(bytes);
    return start;
}

pub fn streamRange(source: *TrackingSource) !source_input.Range {
    return source_input.Range.init(source.source(), 0, @intCast(source.bytes.len));
}

/// Execute one data element from a stream cursor into `out` and return the
/// exact frame end offset. The caller provides fresh frame-local state;
/// history storage is reused across frames.
pub fn decodeDataFrame(
    comptime Support: type,
    allocator: std.mem.Allocator,
    frame: source_frame.DataFrameLayout,
    history_storage: []u8,
    out: *std.ArrayList(u8),
    page_len: usize,
    chunk: usize,
) !u64 {
    const window = try core.stream_count.toLocal(frame.header.window_size);
    if (history_storage.len < window) return error.TestUnexpectedResult;
    var history = try history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, 0);

    const staging = try allocator.alloc(u8, frame.header.block_size_max);
    defer allocator.free(staging);
    const literal_page = try allocator.alloc(u8, page_len);
    defer allocator.free(literal_page);
    const sequence_page = try allocator.alloc(u8, page_len);
    defer allocator.free(sequence_page);

    var state: Support.State = Support.initialState();
    var executor = try frame_executor.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        frame,
        &state,
        &history,
        &.{},
        0,
        staging,
        literal_page,
        sequence_page,
        .{},
    );

    while (executor.snapshot().phase != .done) {
        switch (executor.snapshot().phase) {
            .drain => {
                var buffer: [512]u8 = undefined;
                const amount = @min(chunk, buffer.len);
                const result = try executor.drain(buffer[0..amount]);
                try out.appendSlice(allocator, buffer[0..result.written]);
            },
            else => try executor.execute(),
        }
    }
    return executor.frameEndOffset();
}
