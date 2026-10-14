const std = @import("std");
const core = @import("../../../core.zig");

/// Incremental zlib wrapper around the fixed-Huffman raw-DEFLATE stream core.
/// Header, optional DICTID, Adler-32 footer, flush and caller I/O accounting are
/// all owned here; the raw core remains usable independently.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        raw: Codec.RawEncoder,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        adler: Codec.Adler32 = Codec.Adler32.init(),
        header_written: bool = false,
        footer_written: bool = false,
        finishing: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        stream_input: usize = 0,
        stream_output: usize = 0,
        stream_count: usize = 0,
        dictionary: []const u8 = &.{},

        const Self = @This();
        pub const Error = Codec.Error;
        pub const ParamsError = Codec.ParamsError;
        pub const supports_runtime_params = Codec.RawEncoder.supports_runtime_params;
        pub const Options = struct { raw: Codec.RawOptions = .{} };
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            stream_input: usize,
            stream_output: usize,
            pending_output: usize,
            pending_bits: u3,
            active_params: ?Codec.Params,
            requested_params: ?Codec.Params,
            params_boundary_pending: bool,
            params_change_count: usize,
            stored_only: bool,
            flushing: bool,
            stream_count: usize,
            stream_index: usize,
            finishing: bool,
            done: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options, .raw = Codec.RawEncoder.initWithOptions(allocator, options.raw) };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: usize) Self {
            return .{ .allocator = allocator, .options = options, .raw = Codec.RawEncoder.initExactSize(allocator, options.raw, expected_input_len) };
        }
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Options, dictionary: []const u8) Self {
            return .{ .allocator = allocator, .options = options, .raw = Codec.RawEncoder.initWithDictionary(allocator, options.raw, dictionary), .dictionary = dictionary };
        }
        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Options, expected_input_len: usize, dictionary: []const u8) Self {
            return .{ .allocator = allocator, .options = options, .raw = Codec.RawEncoder.initExactSizeWithDictionary(allocator, options.raw, expected_input_len, dictionary), .dictionary = dictionary };
        }
        pub fn deinit(self: *Self) void {
            self.raw.deinit();
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            self.stream_input = 0;
            self.stream_output = 0;
            self.stream_count = 0;
            self.raw.reset();
            self.options.raw.compression = self.raw.options.compression;
            self.resetWrapper();
        }
        fn resetWrapper(self: *Self) void {
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.adler = Codec.Adler32.init();
            self.header_written = false;
            self.footer_written = false;
            self.finishing = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
        }
        /// Start another independently wrapped zlib stream after the prior
        /// stream has been fully drained. Concatenation is a container-level
        /// convention (not an RFC 1950 single-stream feature), matching the
        /// library's concatenated zlib decoders.
        pub fn nextStream(self: *Self, options: Options, dictionary: []const u8) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            self.options = options;
            self.dictionary = dictionary;
            self.raw.resetWithOptions(options.raw);
            self.raw.resetDictionary(dictionary);
            self.resetWrapper();
        }
        pub fn nextStreamExactSize(self: *Self, options: Options, dictionary: []const u8, expected_input_len: usize) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            self.options = options;
            self.dictionary = dictionary;
            self.raw.resetWithOptions(options.raw);
            self.raw.resetExactSizeDictionary(expected_input_len, dictionary);
            self.resetWrapper();
        }
        pub fn snapshot(self: *const Self) Snapshot {
            const raw_snapshot = self.raw.snapshot();
            return .{
                .input_read = self.stream_input,
                .output_written = self.stream_output,
                .stream_input = self.total_input,
                .stream_output = self.total_output,
                .pending_output = std.math.add(usize, self.pending.items.len - self.pending_offset, raw_snapshot.pending_output) catch std.math.maxInt(usize),
                .pending_bits = raw_snapshot.pending_bits,
                .active_params = raw_snapshot.active_params,
                .requested_params = raw_snapshot.requested_params,
                .params_boundary_pending = raw_snapshot.params_boundary_pending,
                .params_change_count = raw_snapshot.params_change_count,
                .stored_only = raw_snapshot.stored_only,
                .flushing = raw_snapshot.flushing,
                .stream_count = self.stream_count,
                .stream_index = if (self.done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        /// Request zlib-compatible compression parameters for subsequent raw
        /// DEFLATE blocks without resetting the wrapper checksum or history.
        pub fn requestParams(self: *Self, params: Codec.Params) ParamsError!void {
            try self.raw.requestParams(params);
        }
        /// End and publish the accepted input as a non-final DEFLATE block
        /// without byte alignment. The zlib checksum and dictionary history
        /// remain active for subsequent input.
        pub fn blockFlush(self: *Self) void {
            if (!self.finishing and !self.done) self.raw.blockFlush();
        }
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.raw.flush();
        }
        /// Publish all accepted input at a byte boundary and reset the raw
        /// DEFLATE match history, matching zlib's Z_FULL_FLUSH semantics while
        /// keeping this RFC 1950 stream and its Adler-32 state open.
        pub fn fullFlush(self: *Self) void {
            if (!self.finishing and !self.done) self.raw.fullFlush();
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
            self.raw.finish();
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.raw.snapshot().flushing) and input.len != 0) return error.TrailingData;
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output += n;
                    self.stream_output += n;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (!self.header_written) {
                    try Codec.RawEncoder.validateOptions(self.raw.options);
                    try Codec.writeHeader(self.allocator, &self.pending, self.dictionary);
                    self.header_written = true;
                    continue;
                }

                var raw_scratch: [4096]u8 = undefined;
                const raw_result = try self.raw.step(input[input_read..], &raw_scratch);
                if (raw_result.progress.input_read != 0) {
                    const accepted = input[input_read..][0..raw_result.progress.input_read];
                    self.adler.update(accepted);
                    input_read += accepted.len;
                    self.total_input += accepted.len;
                    self.stream_input += accepted.len;
                }
                if (raw_result.progress.output_written != 0) {
                    try self.pending.appendSlice(self.allocator, raw_scratch[0..raw_result.progress.output_written]);
                    continue;
                }
                if (raw_result.status == .need_output) continue;
                if (raw_result.status == .done and !self.footer_written) {
                    try Codec.writeFooter(self.allocator, &self.pending, self.adler.digest());
                    self.footer_written = true;
                    continue;
                }
                if (raw_result.status == .done) {
                    self.stream_count += 1;
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
