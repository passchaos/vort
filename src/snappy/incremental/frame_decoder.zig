const std = @import("std");
const core = @import("../../core.zig");

/// Build a caller-owned incremental Snappy framed-stream decoder. The codec
/// interface keeps framing state separate from raw-block/checksum policy.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        phase: Phase = .header,
        header: [4]u8 = undefined,
        header_len: usize = 0,
        chunk_type: u8 = 0,
        chunk_len: usize = 0,
        chunk: std.ArrayList(u8) = .empty,
        decoded: std.ArrayList(u8) = .empty,
        decoded_offset: usize = 0,
        saw_identifier: bool = false,
        input_finished: bool = false,
        total_output: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_chunk_payload_len: usize = 0x00ff_ffff,
            max_output_len: usize = std.math.maxInt(usize),
        };
        pub const Phase = enum { header, payload, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            header_received: usize,
            chunk_payload_received: usize,
            chunk_payload_expected: usize,
            output_written: usize,
            payload_remaining: usize,
            saw_identifier: bool,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn deinit(self: *Self) void {
            self.chunk.deinit(self.allocator);
            self.decoded.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const allocator = self.allocator;
            const options = self.options;
            var chunk = self.chunk;
            var decoded = self.decoded;
            chunk.clearRetainingCapacity();
            decoded.clearRetainingCapacity();
            self.* = .{ .allocator = allocator, .options = options, .chunk = chunk, .decoded = decoded };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .header_received = self.header_len,
                .chunk_payload_received = self.chunk.items.len,
                .chunk_payload_expected = self.chunk_len,
                .output_written = self.total_output,
                .payload_remaining = self.decoded.items.len - self.decoded_offset,
                .saw_identifier = self.saw_identifier,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .header_received = snap.header_received,
                .output_written = snap.output_written,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }

        /// Snappy has no terminal marker; a chunk boundary or a data chunk
        /// waiting to drain is a valid input end position.
        pub fn finish(self: *Self) Error!void {
            if (!self.saw_identifier or self.phase == .payload or self.header_len != 0) {
                self.recordError(self.phase, error.TruncatedFrame);
                return error.TruncatedFrame;
            }
            self.input_finished = true;
            if (self.phase == .header) self.phase = .done;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.phase == .done) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return .{ .status = .done };
            }
            if (self.input_finished and input.len != 0) return self.fail(self.phase, error.TrailingData);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.phase == .output) {
                    const remaining = self.decoded.items[self.decoded_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.decoded_offset += n;
                    output_written += n;
                    self.total_output += n;
                    if (self.decoded_offset != self.decoded.items.len) return result(input_read, output_written, .need_output);
                    self.decoded.clearRetainingCapacity();
                    self.decoded_offset = 0;
                    self.phase = .header;
                    if (self.input_finished) {
                        self.phase = .done;
                        return result(input_read, output_written, .done);
                    }
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (self.phase == .header) {
                    const n = @min(4 - self.header_len, input.len - input_read);
                    @memcpy(self.header[self.header_len..][0..n], input[input_read..][0..n]);
                    self.header_len += n;
                    input_read += n;
                    if (self.header_len != 4) return result(input_read, output_written, .need_input);
                    self.chunk_type = self.header[0];
                    self.chunk_len = Codec.readChunkLen(self.header[1..4]);
                    self.header_len = 0;
                    if (self.chunk_len > self.options.max_chunk_payload_len) return self.fail(.header, error.OutputLimitExceeded);
                    self.chunk.clearRetainingCapacity();
                    try self.chunk.ensureTotalCapacity(self.allocator, self.chunk_len);
                    self.phase = .payload;
                }
                if (self.phase == .payload) {
                    const n = @min(self.chunk_len - self.chunk.items.len, input.len - input_read);
                    try self.chunk.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    if (self.chunk.items.len != self.chunk_len) return result(input_read, output_written, .need_input);
                    self.processChunk() catch |err| return self.fail(.payload, err);
                    if (self.phase == .output) continue;
                    self.phase = .header;
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                }
            }
        }

        fn processChunk(self: *Self) Error!void {
            const payload = self.chunk.items;
            switch (self.chunk_type) {
                Codec.stream_identifier_chunk_type => {
                    if (!std.mem.eql(u8, payload, Codec.stream_identifier_payload)) return error.InvalidMagic;
                    self.saw_identifier = true;
                },
                Codec.compressed_data_chunk_type, Codec.uncompressed_data_chunk_type => {
                    if (!self.saw_identifier) return error.InvalidMagic;
                    if (payload.len < 4) return error.TruncatedFrame;
                    self.decoded.clearRetainingCapacity();
                    if (self.chunk_type == Codec.uncompressed_data_chunk_type) {
                        if (payload.len - 4 > Codec.max_uncompressed_chunk_len) return error.CorruptFrame;
                        try self.reserveOutput(payload.len - 4);
                        try Codec.verifyChecksum(payload[4..], std.mem.readInt(u32, payload[0..4], .little));
                        try self.decoded.appendSlice(self.allocator, payload[4..]);
                    } else {
                        const compressed = payload[4..];
                        const decoded_len = try Codec.decodedCompressedSize(compressed);
                        if (decoded_len > Codec.max_uncompressed_chunk_len) return error.CorruptFrame;
                        try self.reserveOutput(decoded_len);
                        try self.decoded.resize(self.allocator, decoded_len);
                        if (try Codec.decodeCompressed(compressed, self.decoded.items) != decoded_len) return error.SizeMismatch;
                        try Codec.verifyChecksum(self.decoded.items, std.mem.readInt(u32, payload[0..4], .little));
                    }
                    self.phase = .output;
                },
                else => {
                    if (self.chunk_type < Codec.min_skippable_chunk_type) return error.UnsupportedSnappyFeature;
                    if (!self.saw_identifier) return error.InvalidMagic;
                },
            }
        }
        fn reserveOutput(self: *Self, n: usize) Error!void {
            const total = std.math.add(usize, self.total_output, n) catch return error.IntegerOverflow;
            if (total > self.options.max_output_len) return error.OutputLimitExceeded;
            try self.decoded.ensureTotalCapacity(self.allocator, n);
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.recordError(phase, err);
            return err;
        }
        fn recordError(self: *Self, phase: Phase, err: Error) void {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
