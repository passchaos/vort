//! Bounded composition of the raw incremental CPIO writer and a compressor.

const std = @import("std");
const core = @import("../core.zig");
const cpio_writer = @import("incremental_writer.zig");
pub const codecs = @import("../archive_stream/incremental_encoder_codecs.zig");

pub fn Writer(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        cpio: cpio_writer.Writer,
        encoder: Codec.State,
        bridge: []u8,
        bridge_start: usize = 0,
        bridge_len: usize = 0,
        phase: Phase = .active,
        pending_entry_done: bool = false,
        cpio_done: bool = false,
        encoder_finish_called: bool = false,
        total_output: u64 = 0,

        const Self = @This();

        pub const Error = cpio_writer.Error || Codec.Error || std.mem.Allocator.Error || error{
            InvalidCompressedCpioWriterState,
            CompressedCpioWriterPoisoned,
        };

        pub const Options = struct {
            cpio: cpio_writer.Options = .{},
            encoder: Codec.Options = Codec.default_options,
            raw_bridge_size: usize = 32 * 1024,
            max_compressed_size: u64 = std.math.maxInt(u64),
        };

        pub const Phase = enum { active, done, poisoned };

        pub const Snapshot = struct {
            phase: Phase,
            cpio: cpio_writer.Writer.Snapshot,
            compressed_output: u64,
            pending_raw_bytes: usize,
            raw_bridge_size: usize,
            pending_entry_done: bool,
            cpio_done: bool,
            encoder_finish_called: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
            if (options.raw_bridge_size == 0)
                return error.InvalidCompressedCpioWriterState;
            var cpio = try cpio_writer.Writer.initWithOptions(allocator, options.cpio);
            errdefer cpio.deinit();
            var encoder = try Codec.init(allocator, options.encoder);
            errdefer Codec.deinit(&encoder);
            const bridge = try allocator.alloc(u8, options.raw_bridge_size);
            return .{
                .allocator = allocator,
                .options = options,
                .cpio = cpio,
                .encoder = encoder,
                .bridge = bridge,
            };
        }

        pub fn deinit(self: *Self) void {
            self.cpio.deinit();
            Codec.deinit(&self.encoder);
            self.allocator.free(self.bridge);
            self.* = undefined;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .cpio = self.cpio.snapshot(),
                .compressed_output = self.total_output,
                .pending_raw_bytes = self.bridge_len - self.bridge_start,
                .raw_bridge_size = self.bridge.len,
                .pending_entry_done = self.pending_entry_done,
                .cpio_done = self.cpio_done,
                .encoder_finish_called = self.encoder_finish_called,
            };
        }

        pub fn beginEntry(self: *Self, entry: cpio_writer.EntryOptions) Error!void {
            if (self.phase == .poisoned) return error.CompressedCpioWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.cpio_done)
                return error.InvalidCompressedCpioWriterState;
            try self.cpio.beginEntry(entry);
        }

        pub fn finishEntry(self: *Self) Error!void {
            if (self.phase == .poisoned) return error.CompressedCpioWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.cpio_done)
                return error.InvalidCompressedCpioWriterState;
            try self.cpio.finishEntry();
        }

        pub fn finishArchive(self: *Self) Error!void {
            if (self.phase == .poisoned) return error.CompressedCpioWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.cpio_done)
                return error.InvalidCompressedCpioWriterState;
            try self.cpio.finishArchive();
        }

        pub fn step(
            self: *Self,
            input: []const u8,
            output: []u8,
        ) Error!cpio_writer.StepResult {
            if (self.phase == .poisoned) return error.CompressedCpioWriterPoisoned;
            return self.stepInner(input, output) catch |err| {
                self.phase = .poisoned;
                return err;
            };
        }

        fn stepInner(
            self: *Self,
            input: []const u8,
            output: []u8,
        ) Error!cpio_writer.StepResult {
            if (self.phase == .done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.bridge_start != self.bridge_len) {
                    const stepped = try self.encoderStep(
                        self.bridge[self.bridge_start..self.bridge_len],
                        output[output_written..],
                    );
                    self.bridge_start += stepped.progress.input_read;
                    output_written += stepped.progress.output_written;
                    if (self.bridge_start == self.bridge_len) self.clearBridge();
                    if (stepped.status == .done)
                        return error.InvalidCompressedCpioWriterState;
                    if (self.bridge_start != self.bridge_len) {
                        if (stepped.status != .need_output or
                            (stepped.progress.input_read == 0 and
                                stepped.progress.output_written == 0))
                        {
                            return error.InvalidCompressedCpioWriterState;
                        }
                        return result(input_read, output_written, .need_output);
                    }
                    if (stepped.status == .need_output)
                        return result(input_read, output_written, try self.needOutputStatus());
                    if (self.pending_entry_done) {
                        self.pending_entry_done = false;
                        return result(input_read, output_written, .entry_done);
                    }
                    continue;
                }

                const drained = try self.encoderStep("", output[output_written..]);
                output_written += drained.progress.output_written;
                switch (drained.status) {
                    .need_output => return result(
                        input_read,
                        output_written,
                        try self.needOutputStatus(),
                    ),
                    .done => {
                        if (!self.cpio_done or !self.encoder_finish_called)
                            return error.InvalidCompressedCpioWriterState;
                        self.phase = .done;
                        return result(input_read, output_written, .done);
                    },
                    .need_input => {},
                }

                if (self.pending_entry_done) {
                    self.pending_entry_done = false;
                    return result(input_read, output_written, .entry_done);
                }
                if (self.cpio_done) {
                    if (!self.encoder_finish_called) {
                        try Codec.finish(&self.encoder);
                        self.encoder_finish_called = true;
                        continue;
                    }
                    return error.InvalidCompressedCpioWriterState;
                }
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);

                const raw = try self.cpio.step(input[input_read..], self.bridge);
                input_read += raw.input_read;
                self.bridge_start = 0;
                self.bridge_len = raw.output_written;
                switch (raw.status) {
                    .entry_done => self.pending_entry_done = true,
                    .done => self.cpio_done = true,
                    .need_input => if (self.bridge_len == 0)
                        return result(input_read, output_written, .need_input),
                    .need_output => if (self.bridge_len == 0)
                        return error.InvalidCompressedCpioWriterState,
                }
                if (self.bridge_len != 0 or self.pending_entry_done or self.cpio_done)
                    continue;
            }
        }

        fn encoderStep(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            const remaining_limit = self.options.max_compressed_size -| self.total_output;
            const allowed: usize = @intCast(@min(@as(u64, output.len), remaining_limit));
            const stepped = try Codec.step(&self.encoder, input, output[0..allowed]);
            self.total_output = std.math.add(
                u64,
                self.total_output,
                stepped.progress.output_written,
            ) catch return error.IntegerOverflow;
            std.debug.assert(self.total_output <= self.options.max_compressed_size);
            return stepped;
        }

        fn needOutputStatus(self: *const Self) Error!cpio_writer.Status {
            if (self.total_output == self.options.max_compressed_size)
                return error.OutputLimitExceeded;
            return .need_output;
        }

        fn clearBridge(self: *Self) void {
            self.bridge_start = 0;
            self.bridge_len = 0;
        }

        fn result(
            input_read: usize,
            output_written: usize,
            status: cpio_writer.Status,
        ) cpio_writer.StepResult {
            return .{
                .input_read = input_read,
                .output_written = output_written,
                .status = status,
            };
        }
    };
}

pub const GzipWriter = Writer(codecs.Gzip);
pub const Bzip2Writer = Writer(codecs.Bzip2);
pub const BrotliWriter = Writer(codecs.Brotli);
pub const CompressZWriter = Writer(codecs.CompressZ);
pub const LzmaWriter = Writer(codecs.Lzma);
pub const XzWriter = Writer(codecs.Xz);
pub const Lz4Writer = Writer(codecs.Lz4);
pub const Lz4LegacyWriter = Writer(codecs.Lz4Legacy);
pub const LzfWriter = Writer(codecs.Lzf);
pub const LzipWriter = Writer(codecs.Lzip);
pub const ZstandardWriter = Writer(codecs.Zstandard);
pub const LzopWriter = Writer(codecs.Lzop);
