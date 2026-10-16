//! Bounded composition of an incremental decompressor and raw TAR reader.

const std = @import("std");
const tar_reader = @import("incremental_reader.zig");
pub const codecs = @import("../archive_stream/incremental_decoder_codecs.zig");

pub fn Reader(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        decoder: Codec.State,
        tar: tar_reader.Reader,
        bridge: []u8,
        bridge_start: usize = 0,
        bridge_len: usize = 0,
        phase: Phase = .decoding,
        finish_requested: bool = false,
        decoder_finish_called: bool = false,
        decoder_done: bool = false,
        tar_done: bool = false,
        total_input: u64 = 0,
        total_decoded: u64 = 0,
        total_output: u64 = 0,

        const Self = @This();

        pub const Error = Codec.Error || tar_reader.Error || std.mem.Allocator.Error || error{
            InvalidCompressedTarReaderState,
            NonZeroTarTrailer,
            CompressedTarReaderPoisoned,
        };

        pub const Options = struct {
            tar: tar_reader.Options = .{},
            decoder: Codec.Options = Codec.default_options,
            decoded_bridge_size: usize = 32 * 1024,
            max_decoded_size: u64 = std.math.maxInt(u64),
        };

        pub const Phase = enum {
            decoding,
            done,
            poisoned,
        };

        pub const Snapshot = struct {
            phase: Phase,
            input_read: u64,
            output_written: u64,
            decoded_bytes: u64,
            pending_decoded_bytes: usize,
            decoded_bridge_size: usize,
            finish_requested: bool,
            decoder_done: bool,
            tar_done: bool,
            tar: tar_reader.Reader.Snapshot,
        };

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
            if (options.decoded_bridge_size == 0)
                return error.InvalidCompressedTarReaderState;
            var decoder = try Codec.init(allocator, options.decoder);
            errdefer Codec.deinit(&decoder);
            const bridge = try allocator.alloc(u8, options.decoded_bridge_size);
            return .{
                .allocator = allocator,
                .options = options,
                .decoder = decoder,
                .tar = tar_reader.Reader.initWithOptions(allocator, options.tar),
                .bridge = bridge,
            };
        }

        pub fn deinit(self: *Self) void {
            Codec.deinit(&self.decoder);
            self.tar.deinit();
            self.allocator.free(self.bridge);
            self.* = undefined;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .decoded_bytes = self.total_decoded,
                .pending_decoded_bytes = self.bridge_len - self.bridge_start,
                .decoded_bridge_size = self.bridge.len,
                .finish_requested = self.finish_requested,
                .decoder_done = self.decoder_done,
                .tar_done = self.tar_done,
                .tar = self.tar.snapshot(),
            };
        }

        pub fn currentEntry(self: *const Self) ?tar_reader.EntryInfo {
            return self.tar.currentEntry();
        }

        /// Records compressed EOF. Continue calling `step("", output)` until
        /// `.done`; pending decompressor and TAR output remain resumable.
        pub fn finish(self: *Self) Error!void {
            if (self.phase == .poisoned) return error.CompressedTarReaderPoisoned;
            if (self.phase == .done) return;
            self.finish_requested = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!tar_reader.StepResult {
            if (self.phase == .poisoned) return error.CompressedTarReaderPoisoned;
            if (self.finish_requested and input.len != 0) return error.TrailingData;
            return self.stepInner(input, output) catch |err| {
                self.phase = .poisoned;
                return err;
            };
        }

        fn stepInner(self: *Self, input: []const u8, output: []u8) Error!tar_reader.StepResult {
            if (self.phase == .done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.bridge_start != self.bridge_len) {
                    if (self.tar_done) {
                        for (self.bridge[self.bridge_start..self.bridge_len]) |byte|
                            if (byte != 0) return error.NonZeroTarTrailer;
                        self.clearBridge();
                        continue;
                    }
                    const tar_step = try self.tar.step(
                        self.bridge[self.bridge_start..self.bridge_len],
                        output[output_written..],
                    );
                    self.bridge_start += tar_step.input_read;
                    output_written += tar_step.output_written;
                    self.total_output = std.math.add(
                        u64,
                        self.total_output,
                        tar_step.output_written,
                    ) catch return error.IntegerOverflow;
                    if (self.bridge_start == self.bridge_len) self.clearBridge();
                    switch (tar_step.status) {
                        .entry_header => return result(input_read, output_written, .entry_header),
                        .entry_done => return result(input_read, output_written, .entry_done),
                        .done => {
                            self.tar_done = true;
                            continue;
                        },
                        .need_output => return result(input_read, output_written, .need_output),
                        .need_input => {
                            if (self.bridge_start != self.bridge_len)
                                return error.InvalidCompressedTarReaderState;
                            continue;
                        },
                    }
                }

                if (self.decoder_done) {
                    if (!self.tar_done) {
                        try self.tar.finish();
                        self.tar_done = true;
                    }
                    self.phase = .done;
                    return result(input_read, output_written, .done);
                }

                const decoder_step = try Codec.step(
                    &self.decoder,
                    input[input_read..],
                    self.bridge,
                );
                input_read += decoder_step.progress.input_read;
                self.total_input = std.math.add(
                    u64,
                    self.total_input,
                    decoder_step.progress.input_read,
                ) catch return error.IntegerOverflow;
                self.bridge_start = 0;
                self.bridge_len = decoder_step.progress.output_written;
                self.total_decoded = std.math.add(
                    u64,
                    self.total_decoded,
                    decoder_step.progress.output_written,
                ) catch return error.IntegerOverflow;
                if (self.total_decoded > self.options.max_decoded_size)
                    return error.OutputLimitExceeded;
                if (self.bridge_len != 0) continue;

                switch (decoder_step.status) {
                    .done => {
                        self.decoder_done = true;
                        continue;
                    },
                    .need_output => return error.InvalidCompressedTarReaderState,
                    .need_input => {
                        if (input_read != input.len) {
                            if (decoder_step.progress.input_read == 0)
                                return error.InvalidCompressedTarReaderState;
                            continue;
                        }
                        if (!self.finish_requested)
                            return result(input_read, output_written, .need_input);
                        if (!self.decoder_finish_called) {
                            try Codec.finish(&self.decoder);
                            self.decoder_finish_called = true;
                            continue;
                        }
                        return error.TruncatedFrame;
                    },
                }
            }
        }

        fn clearBridge(self: *Self) void {
            self.bridge_start = 0;
            self.bridge_len = 0;
        }

        fn result(
            input_read: usize,
            output_written: usize,
            status: tar_reader.Status,
        ) tar_reader.StepResult {
            return .{
                .input_read = input_read,
                .output_written = output_written,
                .status = status,
            };
        }
    };
}

pub const GzipReader = Reader(codecs.Gzip);
pub const Bzip2Reader = Reader(codecs.Bzip2);
pub const BrotliReader = Reader(codecs.Brotli);
pub const CompressZReader = Reader(codecs.CompressZ);
pub const LzmaReader = Reader(codecs.Lzma);
pub const XzReader = Reader(codecs.Xz);
pub const Lz4Reader = Reader(codecs.Lz4);
pub const Lz4LegacyReader = Reader(codecs.Lz4Legacy);
pub const LzfReader = Reader(codecs.Lzf);
pub const LzipReader = Reader(codecs.Lzip);
pub const ZstandardReader = Reader(codecs.Zstandard);
pub const LzopReader = Reader(codecs.Lzop);

test {
    _ = @import("incremental_compressed_reader_tests.zig");
}
