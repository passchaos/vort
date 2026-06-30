const std = @import("std");
const checksum = @import("checksum.zig");
const core = @import("core.zig");

pub const Error = core.Error;
pub const FrameInfo = core.FrameInfo;
pub const Progress = core.Progress;
pub const StepResult = core.StepResult;

pub const magic = [_]u8{ 'V', 'O', 'R', 'T' };
pub const current_version: u8 = 0;
pub const header_len: usize = 32;
pub const max_chunk_len: usize = std.math.maxInt(u32);

const flags_none: u8 = 0;

/// Header-only capacity calculation for the bootstrap store frame.
pub fn encodedSize(input_len: usize) Error!usize {
    return std.math.add(usize, header_len, input_len) catch error.IntegerOverflow;
}

/// Encode a native Vort store frame. This deliberately performs no compression;
/// it validates the frame plumbing, size accounting, and checksum contract that
/// later compressed blocks will reuse.
pub fn encode(input: []const u8, output: []u8) Error!usize {
    const required = try encodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;
    if (input.len > std.math.maxInt(u64)) return error.IntegerOverflow;

    writeHeader(output[0..header_len], .{
        .version = current_version,
        .flags = flags_none,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(input.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(output[header_len..required], input);
    return required;
}

/// Allocate and encode a store frame. The caller owns the returned slice.
pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try encodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encode(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn decode(input: []const u8, output: []u8) Error!usize {
    const info = try parseHeader(input);
    if (info.uncompressed_size != info.stored_size) return error.CorruptFrame;
    const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    if (output.len < payload_len) return error.OutputTooSmall;

    const payload = input[header_len..total_len];
    if (checksum.crc32(payload) != info.checksum) return error.ChecksumMismatch;
    @memcpy(output[0..payload_len], payload);
    return payload_len;
}

/// Allocate and decode a store frame. The caller owns the returned slice.
pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const info = try parseHeader(input);
    const output_len = std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
    const out = try allocator.alloc(u8, output_len);
    errdefer allocator.free(out);
    const written = try decode(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn parseHeader(input: []const u8) Error!FrameInfo {
    if (input.len < header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &magic)) return error.InvalidMagic;
    const version = input[4];
    if (version != current_version) return error.UnsupportedVersion;
    const flags = input[5];
    if (flags != flags_none) return error.CorruptFrame;
    if (input[6] != 0 or input[7] != 0) return error.CorruptFrame;

    return .{
        .version = version,
        .flags = flags,
        .uncompressed_size = std.mem.readInt(u64, input[8..16], .little),
        .stored_size = std.mem.readInt(u64, input[16..24], .little),
        .checksum = std.mem.readInt(u32, input[24..28], .little),
    };
}

fn writeHeader(header: []u8, info: FrameInfo) void {
    std.debug.assert(header.len >= header_len);
    @memcpy(header[0..4], &magic);
    header[4] = info.version;
    header[5] = info.flags;
    header[6] = 0;
    header[7] = 0;
    std.mem.writeInt(u64, header[8..16], info.uncompressed_size, .little);
    std.mem.writeInt(u64, header[16..24], info.stored_size, .little);
    std.mem.writeInt(u32, header[24..28], info.checksum, .little);
    std.mem.writeInt(u32, header[28..32], 0, .little);
}

/// Bounded-buffer streaming encoder for one store frame.
pub const Encoder = struct {
    input: []const u8,
    phase: Phase = .header,
    offset: usize = 0,
    header: [header_len]u8 = undefined,

    const Phase = enum { header, payload, done };

    pub fn init(input: []const u8) Encoder {
        var self = Encoder{ .input = input };
        writeHeader(&self.header, .{
            .version = current_version,
            .flags = flags_none,
            .uncompressed_size = @intCast(input.len),
            .stored_size = @intCast(input.len),
            .checksum = checksum.crc32(input),
        });
        return self;
    }

    pub fn step(self: *Encoder, output: []u8) StepResult {
        if (self.phase == .done) return .{ .status = .done };
        if (output.len == 0) return .{ .status = .need_output };

        var written: usize = 0;
        while (written < output.len) {
            switch (self.phase) {
                .header => {
                    const remaining = self.header[self.offset..];
                    const n = @min(output.len - written, remaining.len);
                    @memcpy(output[written..][0..n], remaining[0..n]);
                    written += n;
                    self.offset += n;
                    if (self.offset == self.header.len) {
                        self.phase = .payload;
                        self.offset = 0;
                    } else break;
                },
                .payload => {
                    const remaining = self.input[self.offset..];
                    const n = @min(output.len - written, remaining.len);
                    @memcpy(output[written..][0..n], remaining[0..n]);
                    written += n;
                    self.offset += n;
                    if (self.offset == self.input.len) {
                        self.phase = .done;
                        self.offset = 0;
                        break;
                    } else break;
                },
                .done => break,
            }
        }
        return .{
            .progress = .{ .output_written = written },
            .status = if (self.phase == .done) .done else .need_output,
        };
    }
};

/// Bounded-buffer streaming decoder for one complete input frame. The input is
/// provided up-front while output may be drained across multiple calls.
pub const Decoder = struct {
    payload: []const u8 = &.{},
    checksum_value: u32 = 0,
    offset: usize = 0,
    verified: bool = false,
    done: bool = false,

    pub fn init(frame: []const u8) Error!Decoder {
        const info = try parseHeader(frame);
        if (info.uncompressed_size != info.stored_size) return error.CorruptFrame;
        const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
        const total_len = try encodedSize(payload_len);
        if (frame.len < total_len) return error.TruncatedFrame;
        return .{
            .payload = frame[header_len..total_len],
            .checksum_value = info.checksum,
        };
    }

    pub fn step(self: *Decoder, output: []u8) Error!StepResult {
        if (self.done) return .{ .status = .done };
        if (!self.verified) {
            if (checksum.crc32(self.payload) != self.checksum_value) return error.ChecksumMismatch;
            self.verified = true;
        }
        if (output.len == 0) return .{ .status = .need_output };

        const remaining = self.payload[self.offset..];
        const n = @min(output.len, remaining.len);
        @memcpy(output[0..n], remaining[0..n]);
        self.offset += n;
        if (self.offset == self.payload.len) self.done = true;
        return .{
            .progress = .{ .input_read = if (self.done) header_len + self.payload.len else 0, .output_written = n },
            .status = if (self.done) .done else .need_output,
        };
    }
};

test "store frame round trips edge and representative inputs" {
    const cases = [_][]const u8{
        "",
        "a",
        "hello vort",
        "The quick brown fox jumps over the lazy dog" ** 16,
    };
    for (cases) |case| {
        const encoded = try encodeAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "store header exposes size and checksum metadata" {
    const input = "metadata contract";
    var encoded: [128]u8 = undefined;
    const written = try encode(input, &encoded);
    const info = try parseHeader(encoded[0..written]);
    try std.testing.expectEqual(current_version, info.version);
    try std.testing.expectEqual(@as(u64, input.len), info.uncompressed_size);
    try std.testing.expectEqual(@as(u64, input.len), info.stored_size);
    try std.testing.expectEqual(checksum.crc32(input), info.checksum);
}

test "store frame reports malformed and corrupt data" {
    try std.testing.expectError(error.TruncatedFrame, parseHeader("short"));

    var encoded: [128]u8 = undefined;
    const written = try encode("payload", &encoded);

    encoded[0] = 'X';
    try std.testing.expectError(error.InvalidMagic, parseHeader(encoded[0..written]));
    encoded[0] = 'V';

    encoded[4] = current_version + 1;
    try std.testing.expectError(error.UnsupportedVersion, parseHeader(encoded[0..written]));
    encoded[4] = current_version;

    encoded[header_len] ^= 0xff;
    var out: [16]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decode(encoded[0..written], &out));
}

test "store frame checks output capacity and truncation" {
    var encoded: [128]u8 = undefined;
    const written = try encode("payload", &encoded);
    var short_out: [3]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decode(encoded[0..written], &short_out));
    try std.testing.expectError(error.TruncatedFrame, decode(encoded[0 .. written - 1], encoded[0..16]));
}

test "streaming encoder and decoder handle tiny output buffers" {
    const input = "chunked store streaming validates progress accounting";
    var encoder = Encoder.init(input);
    var encoded: [256]u8 = undefined;
    var encoded_len: usize = 0;
    while (true) {
        var scratch: [5]u8 = undefined;
        const step_result = encoder.step(&scratch);
        @memcpy(encoded[encoded_len..][0..step_result.progress.output_written], scratch[0..step_result.progress.output_written]);
        encoded_len += step_result.progress.output_written;
        if (step_result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, step_result.status);
    }

    var decoder = try Decoder.init(encoded[0..encoded_len]);
    var decoded: [input.len]u8 = undefined;
    var decoded_len: usize = 0;
    while (true) {
        var scratch: [7]u8 = undefined;
        const step_result = try decoder.step(&scratch);
        @memcpy(decoded[decoded_len..][0..step_result.progress.output_written], scratch[0..step_result.progress.output_written]);
        decoded_len += step_result.progress.output_written;
        if (step_result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, step_result.status);
    }
    try std.testing.expectEqualSlices(u8, input, decoded[0..decoded_len]);
}
