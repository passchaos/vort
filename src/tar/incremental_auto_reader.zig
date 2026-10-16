//! Small-prefix automatic dispatch for raw and compressed incremental TAR.

const std = @import("std");
const lzma = @import("../lzma.zig");
const lzop = @import("../lzop.zig");
const archive = @import("archive.zig");
const tar_reader = @import("incremental_reader.zig");
const compressed_reader = @import("incremental_compressed_reader.zig");
const codecs = compressed_reader.codecs;

pub const Format = enum {
    raw_tar,
    gzip,
    bzip2,
    brotli,
    compress_z,
    lzma,
    xz,
    lz4,
    lz4_legacy,
    lzip,
    lzf,
    zstandard,
    lzop,
};

pub const AmbiguousFallback = enum {
    reject,
    brotli,
    raw_tar,
};

pub const Options = struct {
    tar: tar_reader.Options = .{},
    decoded_bridge_size: usize = 32 * 1024,
    max_decoded_size: u64 = std.math.maxInt(u64),
    max_input_size: u64 = std.math.maxInt(u64),
    max_skippable_frames: usize = 1024 * 1024,
    ambiguous_fallback: AmbiguousFallback = .brotli,
    gzip: codecs.Gzip.Options = codecs.Gzip.default_options,
    bzip2: codecs.Bzip2.Options = codecs.Bzip2.default_options,
    brotli: codecs.Brotli.Options = codecs.Brotli.default_options,
    compress_z: codecs.CompressZ.Options = codecs.CompressZ.default_options,
    lzma: codecs.Lzma.Options = codecs.Lzma.default_options,
    xz: codecs.Xz.Options = codecs.Xz.default_options,
    lz4: codecs.Lz4.Options = codecs.Lz4.default_options,
    lz4_legacy: codecs.Lz4Legacy.Options = codecs.Lz4Legacy.default_options,
    lzip: codecs.Lzip.Options = codecs.Lzip.default_options,
    lzf: codecs.Lzf.Options = codecs.Lzf.default_options,
    zstandard: codecs.Zstandard.Options = codecs.Zstandard.default_options,
    lzop: codecs.Lzop.Options = codecs.Lzop.default_options,
};

pub const Phase = enum {
    prefix,
    skippable,
    active,
    done,
    poisoned,
};

pub const Error = tar_reader.Error ||
    compressed_reader.GzipReader.Error ||
    compressed_reader.Bzip2Reader.Error ||
    compressed_reader.BrotliReader.Error ||
    compressed_reader.CompressZReader.Error ||
    compressed_reader.LzmaReader.Error ||
    compressed_reader.XzReader.Error ||
    compressed_reader.Lz4Reader.Error ||
    compressed_reader.Lz4LegacyReader.Error ||
    compressed_reader.LzipReader.Error ||
    compressed_reader.LzfReader.Error ||
    compressed_reader.ZstandardReader.Error ||
    compressed_reader.LzopReader.Error ||
    std.mem.Allocator.Error || error{
    UnknownTarCompression,
    InvalidTarAutoReaderState,
    TooManySkippableFrames,
    TarAutoReaderPoisoned,
};

const prefix_capacity: usize = 512;
const skippable_header_size: usize = 8;

const Active = union(Format) {
    raw_tar: *tar_reader.Reader,
    gzip: *compressed_reader.GzipReader,
    bzip2: *compressed_reader.Bzip2Reader,
    brotli: *compressed_reader.BrotliReader,
    compress_z: *compressed_reader.CompressZReader,
    lzma: *compressed_reader.LzmaReader,
    xz: *compressed_reader.XzReader,
    lz4: *compressed_reader.Lz4Reader,
    lz4_legacy: *compressed_reader.Lz4LegacyReader,
    lzip: *compressed_reader.LzipReader,
    lzf: *compressed_reader.LzfReader,
    zstandard: *compressed_reader.ZstandardReader,
    lzop: *compressed_reader.LzopReader,

    fn deinit(self: *Active, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |reader| {
                reader.deinit();
                allocator.destroy(reader);
            },
        }
        self.* = undefined;
    }

    fn step(
        self: *Active,
        input: []const u8,
        output: []u8,
    ) Error!tar_reader.StepResult {
        return switch (self.*) {
            inline else => |reader| reader.step(input, output),
        };
    }

    fn finish(self: *Active) Error!void {
        return switch (self.*) {
            inline else => |reader| reader.finish(),
        };
    }

    fn currentEntry(self: *const Active) ?tar_reader.EntryInfo {
        return switch (self.*) {
            inline else => |reader| reader.currentEntry(),
        };
    }
};

pub const Reader = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .prefix,
    prefix: [prefix_capacity]u8 = undefined,
    prefix_len: usize = 0,
    prefix_offset: usize = 0,
    skip_remaining: usize = 0,
    skipped_frames: usize = 0,
    skipped_bytes: u64 = 0,
    active: ?Active = null,
    format: ?Format = null,
    finish_requested: bool = false,
    active_finish_called: bool = false,
    total_input: u64 = 0,
    total_output: u64 = 0,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        format: ?Format,
        input_read: u64,
        output_written: u64,
        buffered_prefix: usize,
        skipped_frames: usize,
        skipped_bytes: u64,
        skippable_bytes_remaining: usize,
        finish_requested: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Self) void {
        if (self.active) |*active| active.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .format = self.format,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_prefix = self.prefix_len - self.prefix_offset,
            .skipped_frames = self.skipped_frames,
            .skipped_bytes = self.skipped_bytes,
            .skippable_bytes_remaining = self.skip_remaining,
            .finish_requested = self.finish_requested,
        };
    }

    pub fn detectedFormat(self: *const Self) ?Format {
        return self.format;
    }

    pub fn currentEntry(self: *const Self) ?tar_reader.EntryInfo {
        return if (self.active) |*active| active.currentEntry() else null;
    }

    pub fn finish(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.TarAutoReaderPoisoned;
        if (self.phase == .done) return;
        self.finish_requested = true;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!tar_reader.StepResult {
        if (self.phase == .poisoned) return error.TarAutoReaderPoisoned;
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
        while (true) switch (self.phase) {
            .prefix => {
                const take = @min(prefix_capacity - self.prefix_len, input.len - input_read);
                @memcpy(
                    self.prefix[self.prefix_len..][0..take],
                    input[input_read..][0..take],
                );
                self.prefix_len += take;
                input_read += take;
                try self.recordInput(take);
                const force = self.finish_requested and input_read == input.len;
                if (self.prefix_len != prefix_capacity and !force)
                    return result(input_read, output_written, .need_input);
                if (try self.probePrefix(force)) continue;
                return result(input_read, output_written, .need_input);
            },
            .skippable => {
                const take = @min(self.skip_remaining, input.len - input_read);
                self.skip_remaining -= take;
                input_read += take;
                try self.recordInput(take);
                self.skipped_bytes = std.math.add(u64, self.skipped_bytes, take) catch
                    return error.IntegerOverflow;
                if (self.skip_remaining != 0) {
                    if (self.finish_requested) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                self.phase = .prefix;
            },
            .active => {
                if (self.prefix_offset != self.prefix_len) {
                    const stepped = try self.active.?.step(
                        self.prefix[self.prefix_offset..self.prefix_len],
                        output[output_written..],
                    );
                    self.prefix_offset += stepped.input_read;
                    try self.recordOutput(stepped.output_written);
                    output_written += stepped.output_written;
                    if (stepped.status == .done and self.prefix_offset != self.prefix_len)
                        return error.TrailingData;
                    if (self.prefix_offset == self.prefix_len) {
                        self.prefix_len = 0;
                        self.prefix_offset = 0;
                    }
                    switch (stepped.status) {
                        .entry_header => return result(input_read, output_written, .entry_header),
                        .entry_done => return result(input_read, output_written, .entry_done),
                        .done => {
                            self.phase = .done;
                            return result(input_read, output_written, .done);
                        },
                        .need_output => return result(input_read, output_written, .need_output),
                        .need_input => {
                            if (self.prefix_offset != self.prefix_len)
                                return error.InvalidTarAutoReaderState;
                            continue;
                        },
                    }
                }

                const stepped = try self.active.?.step(
                    input[input_read..],
                    output[output_written..],
                );
                input_read += stepped.input_read;
                try self.recordInput(stepped.input_read);
                output_written += stepped.output_written;
                try self.recordOutput(stepped.output_written);
                switch (stepped.status) {
                    .entry_header => return result(input_read, output_written, .entry_header),
                    .entry_done => return result(input_read, output_written, .entry_done),
                    .done => {
                        self.phase = .done;
                        return result(input_read, output_written, .done);
                    },
                    .need_output => return result(input_read, output_written, .need_output),
                    .need_input => {
                        if (input_read != input.len) {
                            if (stepped.input_read == 0 and stepped.output_written == 0)
                                return error.InvalidTarAutoReaderState;
                            continue;
                        }
                        if (!self.finish_requested)
                            return result(input_read, output_written, .need_input);
                        if (!self.active_finish_called) {
                            try self.active.?.finish();
                            self.active_finish_called = true;
                            continue;
                        }
                        return error.TruncatedFrame;
                    },
                }
            },
            .done, .poisoned => unreachable,
        };
    }

    /// Returns true after changing phase or consuming a complete skippable
    /// prefix, false only when more prefix bytes are required.
    fn probePrefix(self: *Self, force: bool) Error!bool {
        if (self.prefix_len == prefix_capacity) {
            const block = self.prefix[0..prefix_capacity];
            if (archive.allZero(block) or rawHeaderValid(block)) {
                try self.activate(.raw_tar);
                return true;
            }
        }
        if (self.prefix_len >= skippable_header_size and isSkippableMagic(self.prefix[0..4])) {
            try self.consumeSkippablePrefix();
            return true;
        }
        if (self.prefix_len == prefix_capacity) {
            const block = self.prefix[0..prefix_capacity];
            if (detectMagic(block)) |format| {
                try self.activate(format);
                return true;
            }
            if (looksLikeLzmaTar(block)) {
                try self.activate(.lzma);
                return true;
            }
            try self.activateFallback();
            return true;
        }
        if (!force) return false;
        if (self.prefix_len == 0) {
            try self.activate(.raw_tar);
            return true;
        }
        if (detectMagic(self.prefix[0..self.prefix_len])) |format| {
            try self.activate(format);
            return true;
        }
        if (looksLikeLzmaTar(self.prefix[0..self.prefix_len])) {
            try self.activate(.lzma);
            return true;
        }
        try self.activateFallback();
        return true;
    }

    fn consumeSkippablePrefix(self: *Self) Error!void {
        if (self.skipped_frames == self.options.max_skippable_frames)
            return error.TooManySkippableFrames;
        const payload_len: usize = std.mem.readInt(u32, self.prefix[4..8], .little);
        const frame_len = std.math.add(usize, skippable_header_size, payload_len) catch
            return error.IntegerOverflow;
        self.skipped_frames += 1;
        if (frame_len <= self.prefix_len) {
            self.skipped_bytes = std.math.add(u64, self.skipped_bytes, frame_len) catch
                return error.IntegerOverflow;
            const remaining = self.prefix_len - frame_len;
            std.mem.copyForwards(u8, self.prefix[0..remaining], self.prefix[frame_len..self.prefix_len]);
            self.prefix_len = remaining;
            self.prefix_offset = 0;
            self.phase = .prefix;
            return;
        }
        self.skipped_bytes = std.math.add(u64, self.skipped_bytes, self.prefix_len) catch
            return error.IntegerOverflow;
        self.skip_remaining = frame_len - self.prefix_len;
        self.prefix_len = 0;
        self.prefix_offset = 0;
        self.phase = .skippable;
    }

    fn activateFallback(self: *Self) Error!void {
        switch (self.options.ambiguous_fallback) {
            .reject => return error.UnknownTarCompression,
            .brotli => try self.activate(.brotli),
            .raw_tar => try self.activate(.raw_tar),
        }
    }

    fn activate(self: *Self, format: Format) Error!void {
        if (self.active != null) return error.InvalidTarAutoReaderState;
        const prepared: Active = switch (format) {
            .raw_tar => .{ .raw_tar = try self.createRaw() },
            .gzip => .{ .gzip = try self.createCompressed(
                compressed_reader.GzipReader,
                self.options.gzip,
            ) },
            .bzip2 => .{ .bzip2 = try self.createCompressed(
                compressed_reader.Bzip2Reader,
                self.options.bzip2,
            ) },
            .brotli => .{ .brotli = try self.createCompressed(
                compressed_reader.BrotliReader,
                self.options.brotli,
            ) },
            .compress_z => .{ .compress_z = try self.createCompressed(
                compressed_reader.CompressZReader,
                self.options.compress_z,
            ) },
            .lzma => .{ .lzma = try self.createCompressed(
                compressed_reader.LzmaReader,
                self.options.lzma,
            ) },
            .xz => .{ .xz = try self.createCompressed(
                compressed_reader.XzReader,
                self.options.xz,
            ) },
            .lz4 => .{ .lz4 = try self.createCompressed(
                compressed_reader.Lz4Reader,
                self.options.lz4,
            ) },
            .lz4_legacy => .{ .lz4_legacy = try self.createCompressed(
                compressed_reader.Lz4LegacyReader,
                self.options.lz4_legacy,
            ) },
            .lzip => .{ .lzip = try self.createCompressed(
                compressed_reader.LzipReader,
                self.options.lzip,
            ) },
            .lzf => .{ .lzf = try self.createCompressed(
                compressed_reader.LzfReader,
                self.options.lzf,
            ) },
            .zstandard => .{ .zstandard = try self.createCompressed(
                compressed_reader.ZstandardReader,
                self.options.zstandard,
            ) },
            .lzop => .{ .lzop = try self.createCompressed(
                compressed_reader.LzopReader,
                self.options.lzop,
            ) },
        };
        self.active = prepared;
        self.format = format;
        self.prefix_offset = 0;
        self.active_finish_called = false;
        self.phase = .active;
    }

    fn createRaw(self: *Self) Error!*tar_reader.Reader {
        const reader = try self.allocator.create(tar_reader.Reader);
        reader.* = tar_reader.Reader.initWithOptions(self.allocator, self.options.tar);
        return reader;
    }

    fn createCompressed(
        self: *Self,
        comptime ReaderType: type,
        decoder_options: anytype,
    ) Error!*ReaderType {
        const reader = try self.allocator.create(ReaderType);
        errdefer self.allocator.destroy(reader);
        reader.* = try ReaderType.initWithOptions(self.allocator, .{
            .tar = self.options.tar,
            .decoder = decoder_options,
            .decoded_bridge_size = self.options.decoded_bridge_size,
            .max_decoded_size = self.options.max_decoded_size,
        });
        return reader;
    }

    fn recordInput(self: *Self, count: usize) Error!void {
        self.total_input = std.math.add(u64, self.total_input, count) catch
            return error.IntegerOverflow;
        if (self.total_input > self.options.max_input_size)
            return error.OutputLimitExceeded;
    }

    fn recordOutput(self: *Self, count: usize) Error!void {
        self.total_output = std.math.add(u64, self.total_output, count) catch
            return error.IntegerOverflow;
    }
};

fn detectMagic(bytes: []const u8) ?Format {
    if (bytes.len >= 2 and bytes[0] == 0x1f and bytes[1] == 0x8b) return .gzip;
    if (bytes.len >= 2 and bytes[0] == 0x1f and bytes[1] == 0x9d) return .compress_z;
    if (bytes.len >= 3 and std.mem.eql(u8, bytes[0..3], "BZh")) return .bzip2;
    if (bytes.len >= 6 and std.mem.eql(u8, bytes[0..6], &.{ 0xfd, '7', 'z', 'X', 'Z', 0 }))
        return .xz;
    if (bytes.len >= 4) {
        const magic = std.mem.readInt(u32, bytes[0..4], .little);
        if (magic == 0x184d_2204) return .lz4;
        if (magic == 0x184c_2102) return .lz4_legacy;
        if (magic == 0xfd2f_b528) return .zstandard;
        if (std.mem.eql(u8, bytes[0..4], "LZIP")) return .lzip;
    }
    if (bytes.len >= 2 and std.mem.eql(u8, bytes[0..2], "ZV")) return .lzf;
    if (bytes.len >= lzop.header_magic.len and
        std.mem.eql(u8, bytes[0..lzop.header_magic.len], &lzop.header_magic))
        return .lzop;
    return null;
}

fn looksLikeLzmaTar(bytes: []const u8) bool {
    const header = lzma.parseHeader(bytes) catch return false;
    const size = header.uncompressed_size orelse return true;
    return size >= 2 * 512 and size % 512 == 0;
}

fn rawHeaderValid(block: []const u8) bool {
    archive.validateChecksum(block) catch return false;
    return true;
}

fn isSkippableMagic(bytes: []const u8) bool {
    const magic = std.mem.readInt(u32, bytes[0..4], .little);
    return magic >= 0x184d_2a50 and magic <= 0x184d_2a5f;
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

test {
    _ = @import("incremental_auto_reader_tests.zig");
}
