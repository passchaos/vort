//! Bounded composition of the raw incremental TAR writer and a compressor.

const std = @import("std");
const tar_writer = @import("incremental_writer.zig");
pub const codecs = @import("incremental_compressed_writer/codecs.zig");

pub fn Writer(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        tar: tar_writer.Writer,
        encoder: Codec.State,
        bridge: []u8,
        bridge_start: usize = 0,
        bridge_len: usize = 0,
        phase: Phase = .active,
        pending_entry_done: bool = false,
        tar_done: bool = false,
        encoder_finish_called: bool = false,
        total_output: u64 = 0,

        const Self = @This();

        pub const Error = tar_writer.Error || Codec.Error || std.mem.Allocator.Error || error{
            InvalidCompressedTarWriterState,
            CompressedTarWriterPoisoned,
        };

        pub const Options = struct {
            tar: tar_writer.Options = .{},
            encoder: Codec.Options = Codec.default_options,
            raw_bridge_size: usize = 32 * 1024,
            max_compressed_size: u64 = std.math.maxInt(u64),
        };

        pub const Phase = enum { active, done, poisoned };

        pub const Snapshot = struct {
            phase: Phase,
            tar: tar_writer.Writer.Snapshot,
            compressed_output: u64,
            pending_raw_bytes: usize,
            raw_bridge_size: usize,
            pending_entry_done: bool,
            tar_done: bool,
            encoder_finish_called: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
            if (options.raw_bridge_size == 0)
                return error.InvalidCompressedTarWriterState;
            var encoder = try Codec.init(allocator, options.encoder);
            errdefer Codec.deinit(&encoder);
            const bridge = try allocator.alloc(u8, options.raw_bridge_size);
            return .{
                .allocator = allocator,
                .options = options,
                .tar = tar_writer.Writer.initWithOptions(allocator, options.tar),
                .encoder = encoder,
                .bridge = bridge,
            };
        }

        pub fn deinit(self: *Self) void {
            self.tar.deinit();
            Codec.deinit(&self.encoder);
            self.allocator.free(self.bridge);
            self.* = undefined;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .tar = self.tar.snapshot(),
                .compressed_output = self.total_output,
                .pending_raw_bytes = self.bridge_len - self.bridge_start,
                .raw_bridge_size = self.bridge.len,
                .pending_entry_done = self.pending_entry_done,
                .tar_done = self.tar_done,
                .encoder_finish_called = self.encoder_finish_called,
            };
        }

        pub fn beginEntry(self: *Self, entry: tar_writer.EntryOptions) Error!void {
            if (self.phase == .poisoned) return error.CompressedTarWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.tar_done)
                return error.InvalidCompressedTarWriterState;
            try self.tar.beginEntry(entry);
        }

        pub fn finishEntry(self: *Self) Error!void {
            if (self.phase == .poisoned) return error.CompressedTarWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.tar_done)
                return error.InvalidCompressedTarWriterState;
            try self.tar.finishEntry();
        }

        pub fn finishArchive(self: *Self) Error!void {
            if (self.phase == .poisoned) return error.CompressedTarWriterPoisoned;
            if (self.phase != .active or self.pending_entry_done or self.tar_done)
                return error.InvalidCompressedTarWriterState;
            try self.tar.finishArchive();
        }

        pub fn step(
            self: *Self,
            input: []const u8,
            output: []u8,
        ) Error!tar_writer.StepResult {
            if (self.phase == .poisoned) return error.CompressedTarWriterPoisoned;
            return self.stepInner(input, output) catch |err| {
                self.phase = .poisoned;
                return err;
            };
        }

        fn stepInner(
            self: *Self,
            input: []const u8,
            output: []u8,
        ) Error!tar_writer.StepResult {
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
                        return error.InvalidCompressedTarWriterState;
                    if (self.bridge_start != self.bridge_len) {
                        if (stepped.status != .need_output or
                            (stepped.progress.input_read == 0 and
                                stepped.progress.output_written == 0))
                            return error.InvalidCompressedTarWriterState;
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
                        if (!self.tar_done or !self.encoder_finish_called)
                            return error.InvalidCompressedTarWriterState;
                        self.phase = .done;
                        return result(input_read, output_written, .done);
                    },
                    .need_input => {},
                }

                if (self.pending_entry_done) {
                    self.pending_entry_done = false;
                    return result(input_read, output_written, .entry_done);
                }
                if (self.tar_done) {
                    if (!self.encoder_finish_called) {
                        try Codec.finish(&self.encoder);
                        self.encoder_finish_called = true;
                        continue;
                    }
                    return error.InvalidCompressedTarWriterState;
                }
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);

                const raw = try self.tar.step(input[input_read..], self.bridge);
                input_read += raw.input_read;
                self.bridge_start = 0;
                self.bridge_len = raw.output_written;
                switch (raw.status) {
                    .entry_done => self.pending_entry_done = true,
                    .done => self.tar_done = true,
                    .need_input => if (self.bridge_len == 0) {
                        return result(input_read, output_written, .need_input);
                    },
                    .need_output => if (self.bridge_len == 0)
                        return error.InvalidCompressedTarWriterState,
                }
                if (self.bridge_len != 0 or self.pending_entry_done or self.tar_done)
                    continue;
            }
        }

        fn encoderStep(self: *Self, input: []const u8, output: []u8) Error!@import("../core.zig").StepResult {
            const remaining_limit = self.options.max_compressed_size -| self.total_output;
            const allowed: usize = @intCast(@min(
                @as(u64, output.len),
                remaining_limit,
            ));
            const stepped = try Codec.step(&self.encoder, input, output[0..allowed]);
            self.total_output = std.math.add(
                u64,
                self.total_output,
                stepped.progress.output_written,
            ) catch return error.IntegerOverflow;
            std.debug.assert(self.total_output <= self.options.max_compressed_size);
            return stepped;
        }

        fn needOutputStatus(self: *const Self) Error!tar_writer.Status {
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
            status: tar_writer.Status,
        ) tar_writer.StepResult {
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
pub const LzmaWriter = Writer(codecs.Lzma);
pub const XzWriter = Writer(codecs.Xz);
pub const Lz4Writer = Writer(codecs.Lz4);
pub const ZstandardWriter = Writer(codecs.Zstandard);
pub const LzopWriter = Writer(codecs.Lzop);

test {
    _ = @import("incremental_compressed_writer_tests.zig");
}
